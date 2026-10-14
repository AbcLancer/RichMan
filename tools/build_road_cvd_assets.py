"""Export every usable original animated roadside pickup from unpacked CVD files."""
from pathlib import Path
import json
import numpy as np
from build_original_scenes import cvd_exports, OUT, ROOT, SAMPLES

def main():
    target = OUT / 'road_items'
    index = {}
    sources = {
        'caishen': 'model.cvd', 'card': 'model.cvd',
        'crystal': 'jiezhi.cvd', 'dianjuan': '得点券动画.cvd',
        'fushen': 'model.cvd', 'hanbao': 'model.cvd',
        'petegg': 'model.cvd', 'qiongshen': 'model.cvd',
        'robber': '1.cvd', 'shuaishen': 'model.cvd',
        'thief': '1.cvd',
    }
    for name, filename in sources.items():
        source = SAMPLES / 'roadobj' / name / filename
        folder = target / name
        parts = cvd_exports(source, lambda p: np.asarray(p) * .036, folder)
        index[name] = parts
    target.mkdir(parents=True, exist_ok=True)
    (target / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding='utf-8')
    print({key: len(parts) for key, parts in index.items()})

if __name__ == '__main__':
    main()
