"""Export the twelve actual Role.txt ownership markers, using verified R6HS UVs."""
from build_original_scenes import ROOT, OUT, SAMPLES, read_scene, mesh_file, texture, dump
import json
import numpy as np

roles=json.loads((ROOT/'game/data/rules/roles.json').read_text(encoding='utf-8'))['roles']
folder=SAMPLES/'actor/rolemark'
for role in roles:
    key=role['marker'];meshes,_=read_scene(folder/(key+'.pol'))
    assert len(meshes)==1
    m=meshes[0];p=m['positions'].copy()
    # Board plot parent represents one original 100-unit cell.
    center=(p.min(0)+p.max(0))*.5
    p[:,0]-=center[0];p[:,2]-=center[2];p[:,1]-=p[:,1].min()
    p/=100.0
    uv=m['uv'].copy();uv[:,1]=1-uv[:,1]
    surfaces=[dict(texture=texture(folder,s['texture']),indices=s['indices']) for s in m['surfaces']]
    info=mesh_file(OUT/'markers'/(key+'.r6v'),[p],uv,surfaces)
    info.update(pivot=[0,0,0],role=role['n'],source=str(folder/(key+'.pol')))
    dump(OUT/'markers'/(key+'.json'),info)
print('Exported 12 original ownership markers')
