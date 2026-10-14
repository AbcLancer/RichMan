"""Index retained REA records, preserving actual resolved procedure addresses."""
import hashlib
import json
from pathlib import Path

folder = Path(__file__).parent
target = Path('D:/Projects/reference/Rich6/rich6.exe')
records = []
for file in sorted(folder.glob('rea-function-*.json')):
    result = json.loads(file.read_text(encoding='utf-8-sig'))
    if result.get('isError'):
        continue
    record = result.get('structuredContent')
    if record is None:
        record = json.loads(next(c['text'] for c in result['content'] if c['type'] == 'text'))
    record = record.get('result', record)
    records.append({
        'requested_address': file.stem.removeprefix('rea-function-'),
        'evidence_id': record.get('evidence_id'),
        'actual_procedure': record.get('normalized_result', {}).get('procedure'),
        'result_file': file.name,
        'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
    })
index = {
    'target': target.as_posix(),
    'target_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'provider': 'REA owned stdio session / installed Ghidra',
    'evidence_scope': 'static decompilation; supplementary raw PE disassembly explicitly identified',
    'records': records,
}
(folder / 'evidence-index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'{len(records)} retained static REA records')
