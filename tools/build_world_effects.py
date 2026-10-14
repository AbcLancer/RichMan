"""Reuse original CVD animations, GBF blend rules and pet sprite sequences.

Run with the project's local Python. Sources remain untouched.
"""
from pathlib import Path
import json
import re
import numpy as np
from PIL import Image
from build_original_scenes import cvd_exports, OUT, ROOT, SAMPLES, REPORT


def main():
    folder = OUT / 'effects'
    folder.mkdir(parents=True, exist_ok=True)
    manifest = {'effects': {}, 'pets': {}, 'textures': {}, 'source': 'Original gamedata.pck'}
    readable = ROOT / 'docs/original-readable/world-effects'
    readable.mkdir(parents=True, exist_ok=True)
    for name in ['wudi', 'feidan_exp', 'hedan', 'gaijian', 'chaichu', 'qiongshen', 'tushen', 'pk_pet']:
        parts = []
        for source in (SAMPLES / 'effect1' / name).glob('*.cvd'):
            parts.extend(cvd_exports(source, lambda p: np.asarray(p) * .025, folder / name))
        for part in parts:
            material_path = (ROOT / part['source']).with_suffix('.gbf')
            material_text = material_path.read_text(encoding='gbk') if material_path.exists() else ''
            part['additive'] = bool(re.search(r'SrcBlend\s*=\s*ONE\s*;', material_text))
            part['effect_material'] = True
            if not part['additive']:
                for surface in part['surfaces']:
                    surface['alpha_mode'] = 'alpha'
            # Instance placement restores each source mesh's pivot under one origin.
            Path(ROOT / 'game' / part['definition'][6:]).write_text(json.dumps(part, ensure_ascii=False, indent=2), encoding='utf-8')
        manifest['effects'][name] = parts
        for source in (SAMPLES / 'effect1' / name).glob('*.gbf'):
            (readable / f'{name}-{source.stem}.gbf.txt').write_text(source.read_text(encoding='gbk'), encoding='utf-8')
        for source in (SAMPLES / 'effect1' / name).glob('*.gae'):
            data = source.read_bytes()
            refs = [b.decode('gbk', errors='replace') for b in re.findall(rb'[^\x00\r\n]{1,160}\.(?:CVD|cvd|par|PAR)', data)]
            (readable / f'{name}-{source.stem}.gae.json').write_text(json.dumps({'source': str(source.relative_to(ROOT)), 'bytes': len(data), 'resource_references': refs, 'note': 'References recovered; particle timing is not fully decoded.'}, ensure_ascii=False, indent=2), encoding='utf-8')
    pets = json.loads((ROOT / 'game/data/rules/pets.json').read_text(encoding='utf-8'))['pets']
    for pet in pets:
        pet_id = pet['id']
        sequences = {}
        for action, numbers in [('fly', range(20, 24)), ('cast', range(30, 34))]:
            paths = []
            for number in numbers:
                src = SAMPLES / 'uitex/pet' / pet_id / f'{number}.tga'
                dst = folder / 'pets' / pet_id / f'{number}.png'
                dst.parent.mkdir(parents=True, exist_ok=True)
                Image.open(src).convert('RGBA').save(dst)
                paths.append('res://' + dst.relative_to(ROOT / 'game').as_posix())
            sequences[action] = paths
        manifest['pets'][pet_id] = sequences
    gold = next(p for p in (SAMPLES / 'roadobj/gold').glob('*.tga') if Image.open(p).size == (32, 32))
    textures = {'coin': gold, 'smoke': SAMPLES / 'effects/smoke_1.tga', 'ring': SAMPLES / 'effect1/wudi/guanhuan.tga', 'spark': SAMPLES / 'effects/star.tga', 'flash': SAMPLES / 'effects/flash.tga'}
    for name, src in textures.items():
        dst = folder / f'{name}.png'
        Image.open(src).convert('RGBA').save(dst)
        manifest['textures'][name] = 'res://' + dst.relative_to(ROOT / 'game').as_posix()
    manifest['notes'] = {'verified': 'CVD geometry and animation tracks; ONE/ONE additive blend in GBF; native 20..23 fly and 30..33 cast sprites.', 'inferred': 'Pet playback rate and flight offsets; coin trajectories; smoke atlas playback/emission. GAE/PAR controller timings are not fully recovered.'}
    (folder / 'index.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (readable / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Recovered', len(pets), 'pet animation pairs and', sum(len(p) for p in manifest['effects'].values()), 'CVD effect meshes')
    print('Texture warnings:', REPORT['warnings'])


if __name__ == '__main__':
    main()
