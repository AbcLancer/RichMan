"""Independent remake profile: crease-aware Loop surfaces and original animation.

Unlike the faithful PN overlay, this changes existing vertices too, producing a
rounder silhouette. UV seams share geometric stencils across all animation poses.
"""
from pathlib import Path
import hashlib, json
import numpy as np
from build_enhanced_models import ROOT, GAME, read_mesh, weld, normals, unit, write

OUT = GAME / 'assets/remade'

def loop_step(frames, uv, surfaces, strength=0.72):
    faces = np.concatenate(surfaces)
    welded, count = weld(frames)
    representatives = np.zeros(count, np.int32)
    for vi, wi in enumerate(welded):
        representatives[wi] = vi
    original = frames[:, representatives]
    wf = welded[faces]
    _, fn = normals(frames[:1], faces, welded, count)
    edges, neighbours = {}, [set() for _ in range(count)]
    for ti, f in enumerate(wf):
        for a, b, c in [(0,1,2),(1,2,0),(2,0,1)]:
            i,j,k = int(f[a]),int(f[b]),int(f[c])
            if i==j:continue
            edge = tuple(sorted((i,j)))
            edges.setdefault(edge, []).append((ti,k))
            neighbours[i].add(j);neighbours[j].add(i)
    sharp = {}
    crease_neighbours = [set() for _ in range(count)]
    for edge, adjacent in edges.items():
        hard = len(adjacent)!=2 or float(np.dot(fn[0,adjacent[0][0]],fn[0,adjacent[1][0]])) < 0.34
        sharp[edge] = hard
        if hard:
            i,j=edge;crease_neighbours[i].add(j);crease_neighbours[j].add(i)
    updated = original.copy()
    for i, adjacent in enumerate(neighbours):
        if len(crease_neighbours[i]) > 2 or not adjacent:continue
        if len(crease_neighbours[i]) == 2:
            stencil = original[:,i]*.75 + original[:,list(crease_neighbours[i])].sum(1)*.125
        elif len(crease_neighbours[i]) == 1:
            continue
        else:
            n=len(adjacent);beta=3/16 if n==3 else 3/(8*n)
            stencil=original[:,i]*(1-n*beta)+original[:,list(adjacent)].sum(1)*beta
        updated[:,i]=original[:,i]+strength*(stencil-original[:,i])
    output = [updated[:,wi] for wi in welded]
    out_uv = list(uv)
    uv_edges = {}
    def midpoint(a,b):
        uv_key=tuple(sorted((int(a),int(b))))
        if uv_key in uv_edges:return uv_edges[uv_key]
        edge=tuple(sorted((int(welded[a]),int(welded[b]))))
        linear=(frames[:,a]+frames[:,b])*.5
        adjacent=edges.get(edge,[])
        if len(adjacent)==2 and not sharp[edge]:
            smooth=original[:,list(edge)].sum(1)*.375+original[:,[adjacent[0][1],adjacent[1][1]]].sum(1)*.125
            position=linear+strength*(smooth-linear)
        else:position=linear
        result=len(output);output.append(position);out_uv.append((uv[a]+uv[b])*.5)
        uv_edges[uv_key]=result
        return result
    out_surfaces=[]
    for surface in surfaces:
        triangles=[]
        for a,b,c in surface:
            ab,bc,ca=midpoint(a,b),midpoint(b,c),midpoint(c,a)
            triangles.extend([(a,ab,ca),(b,bc,ab),(c,ca,bc),(ab,bc,ca)])
        out_surfaces.append(np.array(triangles,'<i4'))
    return np.stack(output,axis=1),np.array(out_uv,'<f4'),out_surfaces

def main():
    manifest_path=OUT/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    manifest.setdefault('meshes',{});manifest.setdefault('mesh_hashes',{})
    report={}
    for role in range(1,13):
        source=GAME/f'assets/original/actors/role{role}.r6v'
        frames,uv,surfaces=read_mesh(source)
        original_nv=frames.shape[1];original_tri=sum(len(x) for x in surfaces)
        for _ in range(2):frames,uv,surfaces=loop_step(frames,uv,surfaces)
        welded,count=weld(frames)
        ns,_=normals(frames,np.concatenate(surfaces),welded,count)
        assert np.isfinite(frames).all() and np.isfinite(ns).all()
        target=OUT/f'actors/role{role}.r6v';write(target,frames,uv,surfaces,ns)
        key='res://'+source.relative_to(GAME).as_posix()
        manifest['meshes'][key]='res://'+target.relative_to(GAME).as_posix()
        manifest['mesh_hashes'][key]=hashlib.md5(source.read_bytes()).hexdigest()
        report[str(role)]=dict(vertices_before=original_nv,vertices_after=frames.shape[1],
            triangles_before=original_tri,triangles_after=sum(len(x) for x in surfaces),frames=len(frames))
        print('REMADE',role,report[str(role)],flush=True)
    # Faceted marker shapes stay faceted, with explicit geometric normals.
    for source in (GAME/'assets/original/markers').glob('*.r6v'):
        frames,uv,surfaces=read_mesh(source)
        faces=np.concatenate(surfaces);p=frames[:,faces]
        face_n=unit(np.cross(p[:,:,2]-p[:,:,0],p[:,:,1]-p[:,:,0]))
        # Split triangle corners so gemstone facets do not average into a blob.
        expanded=frames[:,faces.reshape(-1)];ns=np.repeat(face_n,3,axis=1)
        new_uv=uv[faces.reshape(-1)];out_surfaces=[];offset=0
        for surface in surfaces:
            out_surfaces.append(np.arange(offset,offset+surface.size,dtype='<i4').reshape(-1,3));offset+=surface.size
        target=OUT/'markers'/source.name;write(target,expanded,new_uv,out_surfaces,ns)
        key='res://'+source.relative_to(GAME).as_posix()
        manifest['meshes'][key]='res://'+target.relative_to(GAME).as_posix()
        manifest['mesh_hashes'][key]=hashlib.md5(source.read_bytes()).hexdigest()
    # Reuse the existing enhanced environment meshes; this profile gives them
    # independent texture/material assets rather than regenerating duplicate data.
    enhanced=json.loads((GAME/'assets/enhanced/manifest.json').read_text(encoding='utf-8'))
    for key,value in enhanced.get('meshes',{}).items():
        if '/scenes/' in key:
            manifest['meshes'][key]=value
            manifest['mesh_hashes'][key]=enhanced.get('mesh_hashes',{}).get(key,'')
    OUT.mkdir(parents=True,exist_ok=True)
    manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'models-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

if __name__=='__main__':main()
