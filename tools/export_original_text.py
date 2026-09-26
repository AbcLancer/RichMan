"""Export original text directly from the installation/PCK, with provenance.

No inferred code, binary string dumps, or reconstructed gameplay is called a script.
Run: python tools/export_original_text.py --source D:/Projects/reference/Rich6
"""
import argparse
from collections import Counter
import difflib
import hashlib
import json
from pathlib import Path
import re

from r6pck import read_entries

TEXT_EXT = {'.txt', '.ini', '.cfg', '.gbf', '.gst', '.tst', '.ani', '.lua', '.js', '.scr'}


def decode(raw):
    for encoding in ('utf-8-sig', 'gbk'):
        try:
            return raw.decode(encoding), encoding
        except UnicodeDecodeError:
            pass
    raise ValueError('Unknown text encoding; do not silently replace characters')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--out', type=Path, default=Path('docs/original-readable'))
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    records, texts, rejected = [], {}, []

    def save(name, raw, origin):
        path = out / name
        if not path.resolve().is_relative_to(out):
            raise ValueError('Unsafe archive path')
        try:
            text, encoding = decode(raw)
        except ValueError as error:
            rejected.append({'name': name, 'reason': str(error)})
            return
        if '\x00' in text or any(ord(c) < 32 and c not in '\t\r\n\x1a' for c in text):
            rejected.append({'name': name, 'reason': 'Contains binary control characters'})
            return
        # Old installation files use CR CR LF. Normalize line endings only.
        text = text.replace('\r\r\n', '\n').replace('\r\n', '\n').replace('\r', '\n')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8', newline='')
        assert path.read_text(encoding='utf-8') == text
        records.append(dict(output=name, source=origin, encoding=encoding,
                            bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()))
        texts[name] = text

    pack = args.source / 'gamedata.pck'
    _, entries = read_entries(pack)
    ext_counts = Counter(Path(e['name']).suffix.lower() for e in entries)
    # Audit every entry by content as well as suffix, to catch plain scripts
    # hidden behind an unfamiliar extension.
    with pack.open('rb') as stream:
        for e in entries:
            stream.seek(e['offset'])
            raw = stream.read(e['size'])
            assert len(raw) == e['size']
            candidate = Path(e['name']).suffix.lower() in TEXT_EXT
            if not candidate and raw and b'\0' not in raw:
                try:
                    t, _ = decode(raw)
                    candidate = all(ord(c) >= 32 or c in '\t\r\n\x1a' for c in t)
                except ValueError:
                    pass
            if candidate:
                save('archive/' + e['name'], raw,
                     dict(file=str(pack), entry=e['name'], offset=e['offset']))
    for source in sorted((args.source / 'config').rglob('*')):
        if source.is_file() and source.suffix.lower() in TEXT_EXT:
            save('installation/' + source.relative_to(args.source).as_posix(),
                 source.read_bytes(), dict(file=str(source)))

    # Differences are evidence, not proof of which resource the executable loads.
    diffs = []
    for name, text in sorted(texts.items()):
        if not name.startswith('installation/config/scene/'):
            continue
        counterpart = 'archive/' + name.removeprefix('installation/config/')
        found = next((n for n in texts if n.lower() == counterpart.lower()), None)
        if found and texts[found] != text:
            diffs.extend(difflib.unified_diff(texts[found].splitlines(True), text.splitlines(True),
                                           fromfile=found, tofile=name))
    (out / 'scene-config-differences.diff').write_text(''.join(diffs), encoding='utf-8')

    # Executable references are only leads for later disassembly, not source code.
    refs = ['# Executable string references (NOT scripts or decompiled code)', '']
    for exe in ('rich6.exe', 'rich6_t.exe'):
        raw = (args.source / exe).read_bytes()
        refs.append(f'## {exe}, SHA256 {hashlib.sha256(raw).hexdigest()}')
        for m in re.finditer(rb'[\x20-\x7e]{5,}', raw):
            s = m.group().decode('ascii')
            if re.search(r'route|bblock|\.r6[ms]|\.txt|script|lua|python', s, re.I):
                refs.append(f'0x{m.start():08X}  {s}')
        refs.append('')
    (out / 'executable-references.txt').write_text('\n'.join(refs), encoding='utf-8')
    manifest = dict(archive_entries=len(entries), archive_extensions=dict(ext_counts),
                    exported=len(records), rejected=rejected, files=records)
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    lines = ['# 原版明文文件完整索引', '', '仅转码与统一换行；未补写逻辑。来源和原始字节 SHA256 见 manifest.json。', '',
             '| 文件 | 原始编码 | 原始字节数 |', '|---|---|---|']
    for r in records:
        lines.append(f"| [{r['output']}]({r['output']}) | {r['encoding']} | {r['bytes']} |")
    (out / 'INDEX.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(dict(archive_entries=len(entries), exported=len(records), rejected=rejected,
                         by_origin=dict(Counter(r['output'].split('/')[0] for r in records))), ensure_ascii=True))


if __name__ == '__main__':
    main()
