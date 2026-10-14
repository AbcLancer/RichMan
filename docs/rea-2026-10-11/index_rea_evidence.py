"""Index retained records; do not promote decompiler guesses into facts."""
import json, hashlib
from pathlib import Path

out = Path(__file__).parent
rows = []
for file in sorted(out.glob('rea-function-*.json')):
    value = json.loads(file.read_text(encoding='utf-8-sig'))
    if value.get('isError'):
        error = json.loads(value['content'][0]['text'])['error']
        rows.append(dict(file=file.name,status='unavailable',reason=error))
        continue
    record = value.get('structuredContent')
    if record is None:
        record = json.loads(next(c['text'] for c in value['content'] if c['type']=='text'))
    record = record.get('result',record)
    normalized = record['normalized_result']
    rows.append(dict(file=file.name,status='observed-static',evidence_id=record['evidence_id'],procedure=normalized['procedure'],limitations=record.get('limitations',[]),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),pseudocode_file=file.with_suffix('.c').name))
initial = json.loads((out/'rea-pet-skill-function.json').read_text(encoding='utf-8-sig'))['data']
(out/'rea-pet-skill-function.c').write_text(initial['normalized_result']['pseudocode'].replace('\r',''),encoding='utf-8')
rows.append(dict(file='rea-pet-skill-function.json',status='observed-static',evidence_id=initial['evidence_id'],procedure=initial['normalized_result']['procedure'],limitations=initial.get('limitations',[]),sha256=hashlib.sha256((out/'rea-pet-skill-function.json').read_bytes()).hexdigest(),pseudocode_file='rea-pet-skill-function.c'))
(out/'rea-evidence-index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
print('Successful static function records',sum(r['status']=='observed-static' for r in rows))
print('Unavailable requests',sum(r['status']=='unavailable' for r in rows))
