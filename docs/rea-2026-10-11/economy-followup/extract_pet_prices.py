"""Read-only PE table, identified by REA 433510. Update only audited price fields."""
import hashlib
import json
from pathlib import Path
import struct
import pefile

root = Path(__file__).resolve().parents[3]
target = Path('D:/Projects/reference/Rich6/rich6.exe')
pe = pefile.PE(str(target))
# Native IDs 2..10 follow the nine records in Pet.txt.
ids = ['qiongshen', 'hutu', 'emo', 'caishen', 'tushen', 'jingling', 'huaxian', 'dushen', 'guaishou']
prices = {}
for native_id, pet in enumerate(ids, 2):
    entries = []
    for level in range(1, 5):
        address = 0x49e860 + (native_id * 4 + level) * 4
        amount = struct.unpack('<i', pe.get_data(address - pe.OPTIONAL_HEADER.ImageBase, 4))[0] * 4
        entries.append({'level': level, 'address': hex(address), 'price': amount})
    prices[pet] = {'native_type': native_id, 'levels': entries}
evidence = {'target_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'method': '433510: table[type*4+level] << 2; 433540 creates level=1 stock', 'pets': prices}
(Path(__file__).parent / 'pet-prices-native.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf-8')
path = root / 'game/data/rules/pets.json'
data = json.loads(path.read_text(encoding='utf-8'))
for pet in data['pets']:
    pet['buy_price'] = prices[pet['id']]['levels'][0]['price']
    pet['buy_price_source'] = 'REA 433510; 49e860 table[type*4+1]*4; 2026-10-12'
data['_inferred']['buy_price'] = '九种一星售价由原版433510和只读PE表逐种核验，独立于技能消耗。'
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print({key: value['levels'][0]['price'] for key, value in prices.items()})
