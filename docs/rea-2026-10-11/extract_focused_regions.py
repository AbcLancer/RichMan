"""Read-only follow-up regions; fixed instruction boundaries, no engine claims."""
from pathlib import Path
import json, hashlib
import capstone, pefile

out = Path(__file__).parent
pe = pefile.PE('D:/Projects/reference/Rich6/rich6.exe')
base = pe.OPTIONAL_HEADER.ImageBase
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
manifest = json.loads((out / 'native-manifest.json').read_text(encoding='utf-8'))
regions = {
    'pet_energy_tables': (0x432bf0, 0x432f80),
    'pet_initialization_decay': (0x431ea0, 0x432120),
    'street_price_mutation': (0x42e990, 0x42ead0),
    'street_price_clamp': (0x42aea0, 0x42aed0),
    'lottery_ui_entry': (0x44d4c0, 0x44dd00),
    'player_action_permissions': (0x4362b0, 0x436570),
}
for name, (start, end) in regions.items():
    raw = pe.get_data(start-base, end-start)
    file = out / (name + '.asm.txt')
    file.write_text('\n'.join(f'{i.address:08x}: {i.bytes.hex():24} {i.mnemonic:8} {i.op_str}' for i in cs.disasm(raw, start))+'\n', encoding='utf-8')
    manifest['regions'][name] = dict(start=hex(start), end_exclusive=hex(end), file_offset=pe.get_offset_from_rva(start-base), bytes_sha256=hashlib.sha256(raw).hexdigest(), file=file.name)
(out / 'native-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print('Saved', len(regions), 'focused regions')
