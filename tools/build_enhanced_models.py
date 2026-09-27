"""Seam-aware PN triangle refinement of original animated characters.

R6V2 adds per-frame normals after the position frames. Originals are untouched.
The same barycentric samples are used for every animation frame; welded motion
trajectories share normals across UV seams. Sharp/open edges stay straight.
"""
from pathlib import Path
import argparse, hashlib, json, struct
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
OUT = GAME / 'assets/enhanced'

def read_mesh(path):
    data = path.read_bytes()
    magic, nf, nv, ns = struct.unpack_from('<4sIII', data)
    assert magic == b'R6V1'
    offset = 16
    uv = np.frombuffer(data, '<f4', nv * 2, offset).reshape(nv, 2).copy()
    offset += nv * 8
    frames = np.frombuffer(data, '<f4', nf * nv * 3, offset).reshape(nf, nv, 3).copy()
    offset += nf * nv * 12
    surfaces = []
    for _ in range(ns):
        count, = struct.unpack_from('<I', data, offset)
        offset += 4
        surfaces.append(np.frombuffer(data, '<i4', count, offset).reshape(-1, 3).copy())
        offset += count * 4
    assert offset == len(data)
    return frames, uv, surfaces

def unit(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)

def weld(frames):
    # Do not weld separate animated objects that only coincide in one pose.
    ids, table = [], {}
    for vertex in range(frames.shape[1]):
        key = hashlib.sha1(np.round(frames[:, vertex], 5).tobytes()).digest()
        ids.append(table.setdefault(key, len(table)))
    return np.array(ids), len(table)

def normals(frames, faces, welded, count):
    result = np.zeros((len(frames), count, 3), np.float32)
    p = frames[:, faces]
    # Godot imported triangle winding is clockwise.
    face_normals = np.cross(p[:, :, 2] - p[:, :, 0], p[:, :, 1] - p[:, :, 0])
    for corner in range(3):
        for frame in range(len(frames)):
            np.add.at(result[frame], welded[faces[:, corner]], face_normals[frame])
    return unit(result)[:, welded], unit(face_normals)

def refine(frames, uv, surfaces, divisions=4, strength=0.65):
    faces = np.concatenate(surfaces)
    welded, count = weld(frames)
    n, face_n = normals(frames, faces, welded, count)
    edges = {}
    for ti, face in enumerate(faces):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            key = tuple(sorted((int(welded[face[a]]), int(welded[face[b]]))))
            edges.setdefault(key, []).append(ti)
    curved = {}
    for key, neighbours in edges.items():
        # Creases determined from all source poses, not just a lucky frame.
        curved[key] = len(neighbours) == 2 and bool(np.min(np.sum(
            face_n[:, neighbours[0]] * face_n[:, neighbours[1]], axis=-1)) > 0.5)
    vertices, texcoords, weights, tris, lookup = [], [], [], [], {}
    for ti, face in enumerate(faces):
        grid = {}
        for i in range(divisions + 1):
            for j in range(divisions + 1 - i):
                bary = np.array([divisions - i - j, i, j])
                # Reuse source-edge samples. UV seams remain distinct, positions agree.
                key = tuple(sorted((int(face[k]), int(bary[k])) for k in range(3) if bary[k]))
                if key not in lookup:
                    lookup[key] = len(vertices)
                    vertices.append(ti)
                    weights.append(bary / divisions)
                    texcoords.append((uv[face] * (bary / divisions)[:, None]).sum(0))
                grid[i, j] = lookup[key]
        local = []
        for i in range(divisions):
            for j in range(divisions - i):
                local.append([grid[i, j], grid[i + 1, j], grid[i, j + 1]])
                if i + j < divisions - 1:
                    local.append([grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]])
        tris.extend(local)
    bary = np.array(weights, np.float32)
    sample_faces = np.array(vertices)
    output = np.empty((len(frames), len(vertices), 3), np.float32)
    for fi, frame in enumerate(frames):
        p = frame[faces]
        ns = n[fi, faces]
        controls = {}
        for a, b in ((0, 1), (1, 0), (1, 2), (2, 1), (2, 0), (0, 2)):
            delta = p[:, b] - p[:, a]
            gate = np.array([curved[tuple(sorted((int(welded[f[a]]), int(welded[f[b]]))))] for f in faces])
            controls[a, b] = (2 * p[:, a] + p[:, b] -
                np.sum(delta * ns[:, a], axis=-1)[:, None] * ns[:, a] * gate[:, None]) / 3
        e = sum(controls.values()) / 6
        center = e + (e - p.mean(1)) / 2
        b = bary
        patch = np.zeros((len(vertices), 3), np.float32)
        linear = np.zeros_like(patch)
        for a in range(3):
            patch += b[:, a, None] ** 3 * p[sample_faces, a]
            linear += b[:, a, None] * p[sample_faces, a]
        for (a, c), control in controls.items():
            patch += 3 * b[:, a, None] ** 2 * b[:, c, None] * control[sample_faces]
        patch += 6 * np.prod(b, axis=-1)[:, None] * center[sample_faces]
        output[fi] = linear + strength * (patch - linear)
    tris = np.array(tris, '<i4')
    out_surfaces = []
    offset = 0
    for s in surfaces:
        count_triangles = len(s) * divisions ** 2
        out_surfaces.append(tris[offset:offset + count_triangles])
        offset += count_triangles
    new_welded, new_count = weld(output)
    out_normals, _ = normals(output, tris, new_welded, new_count)
    assert np.isfinite(output).all() and np.isfinite(out_normals).all()
    # Every original vertex must remain unchanged, in every pose.
    for out_id, (ti, b) in enumerate(zip(sample_faces, bary)):
        if np.max(b) == 1:
            assert np.allclose(output[:, out_id], frames[:, faces[ti, np.argmax(b)]], atol=1e-5)
    return output, np.array(texcoords, '<f4'), out_surfaces, out_normals

def write(path, frames, uv, surfaces, ns):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('wb') as f:
        f.write(struct.pack('<4sIII', b'R6V2', len(frames), frames.shape[1], len(surfaces)))
        f.write(uv.astype('<f4').tobytes())
        f.write(frames.astype('<f4').tobytes())
        f.write(ns.astype('<f4').tobytes())
        for surface in surfaces:
            f.write(struct.pack('<I', surface.size))
            f.write(surface.astype('<i4').tobytes())

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--divisions', type=int, default=4, choices=[2, 4])
    parser.add_argument('--environment', action='store_true', help='Refine organic scenery animation too')
    args = parser.parse_args()
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    manifest.setdefault('meshes', {})
    report = {}
    jobs = []
    if not args.environment:
        jobs = [(str(role), GAME / f'assets/original/actors/role{role}.r6v',
            OUT / f'actors/role{role}.r6v', args.divisions) for role in range(1, 13)]
    else:
        organic = {'munaiyi', 'goutoubing', 'kaogu', 'haiou', 'laoying', 'xianhe',
            'haitun', 'jingyu', 'niu', 'shu', 'yeshu', 'longdeng', 'liyufan'}
        for name in ['aiji', 'china', 'island', 'japan', 'paris', 'space', 'train']:
            scene = json.loads((GAME / f'assets/original/scenes/{name}/scene.json').read_text(encoding='utf-8'))
            for item in scene['animations']:
                if Path(item['source'].replace('\\', '/')).stem not in organic:
                    continue
                path = GAME / item['mesh'][6:]
                key = path.relative_to(GAME / 'assets/original/scenes').as_posix()
                jobs.append((key, path, OUT / 'scenery' / key, 2))
    for key, path, target, divisions in jobs:
        frames, uv, surfaces = read_mesh(path)
        hi, huv, hs, hn = refine(frames, uv, surfaces, divisions)
        write(target, hi, huv, hs, hn)
        manifest['meshes']['res://' + path.relative_to(GAME).as_posix()] = 'res://' + target.relative_to(GAME).as_posix()
        report[key] = dict(frames=len(frames), vertices_before=frames.shape[1], vertices_after=hi.shape[1],
            triangles_before=sum(len(x) for x in surfaces), triangles_after=sum(len(x) for x in hs),
            bytes=target.stat().st_size)
        print(f'{key}: {report[key]}', flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    if manifest_path.exists():
        latest = json.loads(manifest_path.read_text(encoding='utf-8'))
        latest.setdefault('meshes', {}).update(manifest['meshes'])
        manifest = latest
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    report_name = 'scenery-report.json' if args.environment else 'models-report.json'
    (OUT / report_name).write_text(json.dumps(report, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
