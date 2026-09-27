"""Reproducible local SR in character -> world -> UI order.

Uses the official Real-ESRGAN NCNN executable. PNG inputs/outputs are copied,
never overwritten. Alpha is reconstructed from the original, not inferred by
the neural model. Low-frequency color changes are removed and restoration is
blended with Lanczos to protect small lettering and the original art.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, time
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
OUT = GAME / 'assets/enhanced'
WORK = ROOT / '.workbuddy/texture-quality'
PAD = 12
REVISION = 'sr-v1-color-alpha-safe'

def phase(path, actor_textures):
    relative = path.relative_to(GAME).as_posix()
    if relative in actor_textures:
        return 'characters'
    if any(part in path.parts for part in ('original', 'buildings', 'terrain', 'decals', 'roadobj', 'markers')):
        return 'world'
    return 'ui'

def digest(image):
    return hashlib.sha1(REVISION.encode() + str(image.size).encode() + image.tobytes()).hexdigest()[:20]

def prepare(image, destination, wrap):
    rgba = np.asarray(image)
    rgb = rgba[:, :, :3].copy()
    alpha = rgba[:, :, 3]
    visible = alpha > 16
    if visible.any() and not visible.all():
        indices = distance_transform_edt(~visible, return_distances=False, return_indices=True)
        rgb[~visible] = rgb[indices[0][~visible], indices[1][~visible]]
    rgb = np.pad(rgb, ((PAD, PAD), (PAD, PAD), (0, 0)), mode='wrap' if wrap else 'edge')
    Image.fromarray(rgb).save(destination)

def finish(source, inferred, destination, kind):
    width, height = source.size
    size = (width * 4, height * 4)
    inferred = inferred.convert('RGB').crop((PAD * 4, PAD * 4, (PAD + width) * 4, (PAD + height) * 4))
    assert inferred.size == size
    base = source.convert('RGB').resize(size, Image.Resampling.LANCZOS)
    base_array = np.asarray(base, dtype=np.float32)
    sr = np.asarray(inferred, dtype=np.float32)
    # Remove low-frequency brightness/chroma shifts from the inferred image.
    smooth_sr = np.asarray(inferred.filter(ImageFilter.GaussianBlur(6)), dtype=np.float32)
    smooth_base = np.asarray(base.filter(ImageFilter.GaussianBlur(6)), dtype=np.float32)
    strength = {'characters': 0.65, 'world': 0.60, 'ui': 0.50}[kind]
    result = np.clip(base_array + strength * (sr - base_array - smooth_sr + smooth_base), 0, 255).astype(np.uint8)
    image = Image.fromarray(result).convert('RGBA')
    image.putalpha(source.getchannel('A').resize(size, Image.Resampling.LANCZOS))
    # Keep 1024px ground textures at 2048 rather than allocating 4096 per map.
    if max(size) > 2048:
        factor = 2048 / max(size)
        image = image.resize((round(size[0] * factor), round(size[1] * factor)), Image.Resampling.LANCZOS)
    image.save(destination)
    return image.size

def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tool', type=Path, default=ROOT / '.tools/quality/realesrgan/realesrgan-ncnn-vulkan.exe')
    parser.add_argument('--phase', choices=['characters', 'world', 'ui', 'all'], default='all')
    parser.add_argument('--gpu', default='0')
    args = parser.parse_args()
    assert args.tool.exists(), 'Install the official Real-ESRGAN NCNN portable binary first.'
    actor_textures = set()
    for p in (GAME / 'assets/original/actors').glob('*.json'):
        for s in json.loads(p.read_text(encoding='utf-8'))['surfaces']:
            actor_textures.add(s['texture'][6:])
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    manifest.setdefault('textures', {})
    manifest.setdefault('texture_sizes', {})
    report_path = OUT / 'textures-report.json'
    report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
    all_paths = sorted(p for p in (GAME / 'assets').rglob('*.png') if 'enhanced' not in p.parts and 'fonts' not in p.parts)
    phases = ['characters', 'world', 'ui'] if args.phase == 'all' else [args.phase]
    for kind in phases:
        jobs = {}
        for path in all_paths:
            if phase(path, actor_textures) != kind:
                continue
            image = Image.open(path).convert('RGBA')
            key = digest(image)
            entry = jobs.setdefault(key, dict(image=image, paths=[], target=OUT / 'textures' / (key + '.png')))
            entry['paths'].append(path)
        model = 'realesrgan-x4plus' if kind == 'world' else 'realesrgan-x4plus-anime' if kind == 'characters' else 'realesr-animevideov3'
        input_dir, output_dir = WORK / kind / 'input', WORK / kind / 'output'
        input_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)
        missing = []
        for key, entry in jobs.items():
            if entry['target'].exists():
                continue
            if not (output_dir / (key + '.png')).exists():
                prepare(entry['image'], input_dir / (key + '.png'), kind != 'ui')
                missing.append(key)
        print(f'{kind}: {len(jobs)} unique textures, {len(missing)} SR jobs', flush=True)
        start = time.time()
        if missing:
            log = WORK / (kind + '.log')
            with log.open('w', encoding='utf-8') as stream:
                command = [str(args.tool.resolve()), '-i', str(input_dir), '-o', str(output_dir),
                    '-n', model, '-m', str(args.tool.parent.resolve() / 'models'), '-s', '4',
                    '-g', args.gpu, '-t', '128', '-j', '1:2:2', '-f', 'png']
                result = subprocess.run(command, stdout=stream, stderr=stream)
                assert result.returncode == 0, f'SR failed; see {log}'
        for key, entry in jobs.items():
            target = entry['target']
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                size = finish(entry['image'], Image.open(output_dir / (key + '.png')), target, kind)
            else:
                size = Image.open(target).size
            for original in entry['paths']:
                path = 'res://' + original.relative_to(GAME).as_posix()
                manifest['textures'][path] = 'res://' + target.relative_to(GAME).as_posix()
                manifest['texture_sizes'][path] = list(entry['image'].size)
        report[kind] = dict(unique_textures=len(jobs), source_files=sum(len(e['paths']) for e in jobs.values()),
            seconds=round(time.time() - start, 2), model=model, revision=REVISION)
        if manifest_path.exists():
            latest = json.loads(manifest_path.read_text(encoding='utf-8'))
            manifest['meshes'] = latest.get('meshes', {})
        atomic_json(manifest_path, manifest)
        atomic_json(report_path, report)
        print(f'{kind} COMPLETE: {report[kind]}', flush=True)

if __name__ == '__main__':
    main()
