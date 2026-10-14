"""Retain narrow static evidence; never modify the original executable."""
from pathlib import Path
import hashlib
import json
import struct
import capstone
import pefile

out = Path(__file__).resolve().parent
exe = Path('D:/Projects/reference/Rich6/rich6.exe')
raw = exe.read_bytes()
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
md.skipdata = True
regions = {
    'hud_render': (0x447740, 0x447823),
    'human_feed_command': (0x43b672, 0x43b6f1),
    'pet_texture_loader': (0x432470, 0x43270e),
    'growth_increment': (0x4361b0, 0x436228),
}
manifest = {'binary': str(exe), 'sha256': hashlib.sha256(raw).hexdigest(),
            'authority': 'static shipped-artifact, not runtime observation',
            'regions': {}, 'functions': [], 'card_food': []}
for name, (start, end) in regions.items():
    data = pe.get_data(start-base, end-start)
    lines = [f'; {name}: VA {start:#x}..{end:#x} (end exclusive)',
             '; Original EXE SHA256 '+manifest['sha256']]
    lines += [f'{i.address:08x}: {i.bytes.hex():24} {i.mnemonic:8} {i.op_str}'
              for i in md.disasm(data, start)]
    path = out / ('deep-'+name+'.asm.txt')
    path.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    manifest['regions'][name] = {'start': hex(start), 'end_exclusive': hex(end),
        'file_offset': pe.get_offset_from_rva(start-base), 'file': path.name,
        'bytes_sha256': hashlib.sha256(data).hexdigest()}
addresses = ['0x4321b0', '0x432470', '0x432830', '0x432910', '0x432930',
             '0x4329d0', '0x41e460', '0x41c612', '0x432410', '0x432d60',
             '0x447c75', '0x447d20', '0x44f1a7', '0x44ea48', '0x4361dc',
             '0x433d52', '0x434167', '0x423b90']
for address in addresses:
    path = out / ('rea-function-'+address+'.json')
    result = json.loads(path.read_text(encoding='utf-8'))
    record = result.get('structuredContent')
    if not record:
        record = json.loads(next(c['text'] for c in result['content'] if c['type']=='text'))
    record = record.get('result', record)
    normalized = record['normalized_result']
    manifest['functions'].append({'requested': address, 'evidence_id': record['evidence_id'],
        'resolved': normalized['procedure']['address'], 'body': normalized['procedure']['body'],
        'file': path.name, 'pseudocode_file': 'rea-function-'+address+'.c'})
root = out.parents[1]
cards = json.loads((root/'game/assets/card/index.json').read_text(encoding='utf-8'))['cards']
for path in sorted(Path('D:/Projects/reference/Rich6/mainmenu/cardset').glob('*/card.crd')):
    data = path.read_bytes()
    count = struct.unpack_from('<I', data, 36)[0]
    assert count == len(cards) == 42
    values = [struct.unpack_from('<i', data, 40+i*0x240+0x224)[0] for i in range(count)]
    assert values == [c['badge'] for c in cards]
    manifest['card_food'].append({'path': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
        'header_bytes': 40, 'record_bytes': 576, 'food_offset': 548,
        'values': [{'id': c['id'], 'energy': v} for c, v in zip(cards, values)]})
(out/'deep-pet-evidence-index.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Retained {len(regions)} static ranges, {len(addresses)} function dossiers, {len(manifest["card_food"])} card tables')
