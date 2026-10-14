"""Export original parachute geometry using the existing CVD reader."""
import json
import numpy as np
from build_original_scenes import cvd_exports, OUT, SAMPLES, REPORT

if __name__ == '__main__':
    folder = OUT / 'entry'
    parts = cvd_exports(SAMPLES / 'roadobj/san/san.cvd', lambda p: np.asarray(p) * .036, folder)
    (folder / 'index.json').write_text(json.dumps({'parts': parts, 'source': 'samples/roadobj/san/san.cvd', 'notes': 'Original static canopy and ropes. Entry descent and sway timing are reconstructed.'}, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Parachute parts:', len(parts), 'warnings:', REPORT['warnings'])
