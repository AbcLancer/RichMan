"""Read-only extraction of Rich6's native card dispatch table and code regions.

These are disassembly regions, not recovered source scripts. Slot 0x224 also
contains AI target selection routines; do not mistake it for a UI permission table.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

import capstone
import pefile


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', default='D:/Projects/reference/Rich6/rich6.exe')
    ap.add_argument('--out', default='docs/original-readable/cards-native')
    args = ap.parse_args()
    exe = Path(args.exe)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    pe = pefile.PE(str(exe))
    base = pe.OPTIONAL_HEADER.ImageBase
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.skipdata = True

    def code(a, b):
        return list(md.disasm(pe.get_data(a - base, b - a), a))

    def save(name, a, b):
        (out / name).write_text(
            f'; VA region {a:#x}..{b:#x}, may include adjacent helpers.\n'
            + '\n'.join(f'{i.address:08x}: {i.mnemonic:8} {i.op_str}' for i in code(a, b))
            + '\n', encoding='utf-8')

    names = Path('docs/original-readable/installation/config/Card.txt').read_text(encoding='utf-8-sig').splitlines()[1:43]
    entries = {i: {'index': i, 'name': names[i]} for i in range(42)}
    pushed = None
    active = None
    for ins in code(0x422270, 0x422b00):
        if ins.mnemonic == 'push' and re.fullmatch(r'(0x[0-9a-f]+|[0-9]+)', ins.op_str):
            pushed = int(ins.op_str, 0)
        if ins.mnemonic == 'call' and ins.op_str == '0x41f040':
            active = pushed
        match = re.fullmatch(r'dword ptr \[eax \+ (0x[0-9a-f]+)\], (0x[0-9a-f]+)', ins.op_str)
        if ins.mnemonic == 'mov' and match and active in entries:
            slot, address = int(match[1], 0), int(match[2], 0)
            if slot in (0x21c, 0x220, 0x224):
                entries[active][f'slot_{slot:x}'] = f'0x{address:08x}'
    assert all('slot_21c' in e and 'slot_224' in e for e in entries.values())
    addresses = sorted({int(v, 16) for e in entries.values() for k, v in e.items() if k.startswith('slot_')})
    for e in entries.values():
        for slot in ('slot_21c', 'slot_220', 'slot_224'):
            if slot not in e:
                continue
            a = int(e[slot], 16)
            later = [x for x in addresses if x > a]
            b = min(later[0] if later else a + 0x400, a + 0x2000)
            save(f'{e["index"] + 1:02d}_{slot}_{a:08x}.asm.txt', a, b)
    save('dispatch_00422270.asm.txt', 0x422270, 0x422b00)
    helpers = {
        'building_level_change': (0x41e110, 0x41e390),
        'missile_queue_and_damage': (0x428660, 0x428950),
        'player_spatial_query': (0x43a6a0, 0x43a880),
        'damage_and_hospital': (0x434350, 0x434400),
        'status_replace': (0x435f80, 0x436030),
        'hospital_state': (0x436a10, 0x436c00),
        'card_config_parser': (0x41ab20, 0x41b700),
    }
    for name, (a, b) in helpers.items():
        save(name + '.asm.txt', a, b)
    manifest = {'exe': str(exe), 'sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                'dispatch': '0x00422270', 'slots': {'21c': 'effect handler',
                '220': 'supplemental callback', '224': 'condition / AI selection; purpose varies'},
                'cards': list(entries.values())}
    (out / 'dispatch.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    rows = ['|序号|卡片|效果函数|条件 / AI 选点函数|', '|---|---|---|---|']
    for e in entries.values():
        rows.append(f'|{e["index"] + 1}|{e["name"]}|{e["slot_21c"]}|{e["slot_224"]}|')
    (out / '卡片函数索引.md').write_text('# 原版 42 张卡片函数索引\n\n'
        '由 rich6.exe 原生登记函数读取；并非原始脚本源码。每个汇编文件记录虚拟地址和提取范围。\n'
        '0x224 槽中包含电脑玩家自动选点逻辑，不能全部当成人类玩家的使用条件。\n\n'
        + '\n'.join(rows) + '\n', encoding='utf-8')
    print(f'Extracted {len(entries)} native card entries into {out}')


if __name__ == '__main__':
    main()
