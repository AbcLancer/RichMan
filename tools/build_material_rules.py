"""Retain continuous original alpha, distinguish it from binary cutout foliage."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
rules = {}
for path in (GAME / 'assets/original/textures').glob('*.png'):
    alpha = np.asarray(Image.open(path).convert('RGBA'))[:, :, 3]
    visible = alpha > 8
    partial = (alpha > 8) & (alpha < 247)
    fraction = float(partial.sum() / max(visible.sum(), 1))
    mean = float(alpha[visible].mean() / 255) if visible.any() else 0
    mode = 'alpha' if fraction > 0.35 and mean < 0.93 else 'cutout' if (alpha < 255).any() else 'opaque'
    rules['res://' + path.relative_to(GAME).as_posix()] = dict(mode=mode,
        alpha_min=int(alpha.min()), alpha_max=int(alpha.max()), partial_fraction=round(fraction, 4))
out = GAME / 'data/render/materials.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(rules, indent=2), encoding='utf-8')
print('Material modes:', {kind:sum(v['mode']==kind for v in rules.values()) for kind in ['opaque','cutout','alpha']})
