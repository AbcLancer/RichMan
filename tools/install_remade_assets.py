"""Assemble the independent profile from local painted art, keeping source alpha.
Run after build_remade_models.py. No network/API calls; source assets stay intact.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
OUT = GAME / 'assets/remade'

def main():
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text('utf-8'))
    enhanced = json.loads((GAME / 'assets/enhanced/manifest.json').read_text('utf-8'))
    for field in ('textures', 'source_hashes', 'texture_sizes'):
        manifest[field] = dict(enhanced.get(field, {}))
    for role in range(1, 13):
        definition = json.loads((GAME / f'assets/original/actors/role{role}.json').read_text('utf-8'))
        source = definition['surfaces'][0]['texture']
        original = GAME / source.removeprefix('res://')
        old = Image.open(original).convert('RGBA')
        painted = Image.open(OUT / f'art/actors/role{role}.png').convert('RGBA')
        painted = painted.resize((1024, 1024), Image.Resampling.LANCZOS)
        painted.putalpha(old.getchannel('A').resize(painted.size, Image.Resampling.BILINEAR))
        target = OUT / f'textures/role{role}.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        painted.save(target)
        manifest['textures'][source] = 'res://' + target.relative_to(GAME).as_posix()
        manifest['source_hashes'][source] = hashlib.md5(original.read_bytes()).hexdigest()
        manifest['texture_sizes'][source] = list(old.size)
    # Mirrored edges make the repeating detail textures continuous at tile borders.
    for name in ('grass', 'sand', 'stone', 'wood'):
        tile = Image.open(OUT / f'art/materials/{name}.png').convert('RGB')
        tile = tile.resize((512, 512), Image.Resampling.LANCZOS)
        periodic = Image.new('RGB', (1024, 1024))
        periodic.paste(tile, (0, 0))
        periodic.paste(ImageOps.mirror(tile), (512, 0))
        periodic.paste(ImageOps.flip(tile), (0, 512))
        periodic.paste(ImageOps.flip(ImageOps.mirror(tile)), (512, 512))
        target = OUT / f'materials/{name}.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        periodic.save(target)
    manifest['profile'] = 'remade-v1'
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print('Installed 12 painted actor atlases + 4 seamless environment detail materials')

if __name__ == '__main__':
    main()
