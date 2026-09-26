"""Reproducible original scene/actor conversion. No guessed map geometry.

R6SM: exe 409d60/40a050. CVD: 4074d0/407550/407ba0/408660/408a70.
Output uses a tiny explicit binary mesh format, read by original_mesh.gd.
"""
from pathlib import Path
import json, struct, re, hashlib
import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation
from r6_scene_assets import Reader, read_scene
from r6_map_verified import parse, ground_uv

ROOT=Path(__file__).resolve().parents[1]
SAMPLES=ROOT/'samples'
OUT=ROOT/'game/assets/original'
MAPS=['aiji','china','island','japan','paris','space','train']
REPORT={'maps':{},'actors':{},'warnings':[]}

def dump(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,ensure_ascii=False,indent=1),encoding='utf-8')

def texture(folder,name):
    if not name:return ''
    search=folder.parent if folder.name=='anim' else folder
    files={p.name.lower():p for p in search.rglob('*') if p.is_file()}
    src=files.get(name.replace('\\','/').split('/')[-1].lower())
    if src is None and name.lower()=='小喷泉.tga':src=files.get('小喷泉-动画.tga')
    if src is None:
        REPORT['warnings'].append('Missing texture: '+str(folder)+' / '+name);return ''
    dst=OUT/'textures'/(hashlib.sha1(src.read_bytes()).hexdigest()[:16]+'.png')
    dst.parent.mkdir(parents=True,exist_ok=True)
    if not dst.exists():Image.open(src).convert('RGBA').save(dst)
    return 'res://'+dst.relative_to(ROOT/'game').as_posix()

def mesh_file(path,frames,uv,surfaces,times=None,clips=None):
    frames=np.asarray(frames,dtype='<f4');nf,nv,_=frames.shape
    path.parent.mkdir(parents=True,exist_ok=True)
    # All coordinates are already converted to Godot; winding disabled in material.
    with path.open('wb') as f:
        f.write(struct.pack('<4sIII',b'R6V1',nf,nv,len(surfaces)))
        f.write(np.asarray(uv,dtype='<f4').tobytes())
        f.write(frames.tobytes())
        for s in surfaces:
            ix=np.asarray(s['indices'],dtype='<i4').reshape(-1)
            f.write(struct.pack('<I',len(ix)));f.write(ix.tobytes())
    meta=dict(mesh='res://'+path.relative_to(ROOT/'game').as_posix(),
              surfaces=[{'texture':s['texture']} for s in surfaces],
              times=list(map(float,times)) if times is not None else [0],clips=clips or {})
    return meta

EVENTS={1:('platform','传送平台'),2:('cardshop','卡片商店'),3:('hospital','医院'),4:('cardpt','卡片点'),5:('tvnews','电视台'),6:('labar','拉霸'),7:('capital','市政府'),8:('pethouse','精灵屋'),9:('game_a','游戏点A'),10:('game_b','游戏点B'),11:('coupon5','点券5'),12:('coupon10','点券10'),13:('coupon20','点券20'),14:('coupon30','点券30'),15:('coupon50','点券50'),16:('casino','乐透')}

def layout(name):
    data=parse(SAMPLES/'scene'/name/(name+'.r6m'))
    if name=='aiji':affine,_=ground_uv(SAMPLES/'scene/aiji/aiji.pol')
    else:
        pts=np.array([r['position'] for r in data['roads']])[:,[0,2]]
        center=(pts.min(0)+pts.max(0))/2;scale=0.85/np.ptp(pts,axis=0).max()
        affine=np.array([[scale,0],[0,-scale],[.5-center[0]*scale,.5+center[1]*scale]])
    sy=float(np.sqrt(abs(np.linalg.det(affine[:2])))*200)
    base=float(np.median([r['position'][1] for r in data['roads']]))
    def world(pos):
        p=np.asarray(pos);uv=np.stack([p[...,0],p[...,2],np.ones(p.shape[:-1])],axis=-1)@affine
        return np.stack([(uv[...,0]-.5)*200,(p[...,1]-base)*sy,(.5-uv[...,1])*200],axis=-1)
    def board(p):return world(p)[[0,2]].tolist()
    d=dict(_source='Original R6MP records + executable Bezier evaluation',_board_size=200,
           ground_affine=affine.tolist(),height_origin=base,world_scale=sy,
           fog_color=list(struct.unpack_from('<3f',(SAMPLES/'scene'/name/(name+'.r6m')).read_bytes(),8)),roads=data['roads'],minimap=data['minimap'],tiles=[],knots=[],blocks=[])
    for k in data['knots']:d['knots'].append(dict(incoming=board(k[:3]),outgoing=board(k[3:6]),point=board(k[6:9]),height=[float(world(k[j:j+3])[1]) for j in (0,3,6)],length=k[9]))
    for b in data['blocks']:
        m=np.array(b['matrix']);o=board(m[3,:3]);axes=[(np.array(board(m[3,:3]+m[i,:3]*100))-o).tolist() for i in (0,2)]
        d['blocks'].append(dict(width=b['width'],depth=b['depth'],origin=o,axes=axes,height=float(world(m[3,:3])[1])))
    mp=ROOT/'game/data/maps'/(name+'.json');game=json.loads(mp.read_text(encoding='utf-8'))
    game.update(_source=d['_source'],streets=data['streets'],tile_count=len(data['roads']),tiles=[])
    game.pop('plots_per_street',None);counts={}
    for r in data['roads']:
        x,y,z=world(r['position']);d['tiles'].append(dict(i=r['index'],x=x,y=y,z=z))
        t=dict(i=r['index'],original_kind=r['kind'],original_block=r['block'],original_cell=r['cell'])
        if r['block']>=0:
            sid=r['street'];ordinal=counts.get(sid,0);counts[sid]=ordinal+1
            t.update(kind='plot',street=data['streets'][sid],street_index=sid,plot_in_street=ordinal,plot_key=f"{r['block']}:{r['cell']}")
        else:
            eid,label=EVENTS.get(r['kind'],('unknown','原版事件'));t.update(kind='event',event=eid,name=label)
        game['tiles'].append(t)
    dump(mp,game);dump(mp.with_name(name+'_tilepos.json'),d)
    return data,world

def read_cvd(path):
    r=Reader(path.read_bytes());magic,n=r.take('4sI');assert magic==b'cvdf',(path,magic)
    def node():
        has,=r.take('B');d={'children':[]}
        if has:
            tracks=[]
            for stride in (11,11,15):
                count,=r.take('I');assert count<10000
                typ=r.take('B')[0] if count else 0
                tracks.append(r.array('<f4',count*stride).reshape(count,stride))
            scale,=r.take('f');nf,nv=r.take('2I');assert nf<10000 and nv<100000
            v=r.array('<f4',nf*nv*8).reshape(nf,nv,8)
            times=r.array('<f4',nf);nm,=r.take('I');assert nm<1000
            surfaces=[]
            for _ in range(nm):
                flag=r.take('B');r.take('5I');tex=r.take('64s')[0].split(b'\0')[0].decode('gbk')
                nt,=r.take('I');ix=r.array('<u2',nt*3);assert not len(ix) or ix.max()<nv
                surfaces.append(dict(texture=tex,indices=ix))
            matrix=np.array(r.take('16f')).reshape(4,4)
            d.update(tracks=tracks,scale=scale,vertices=v,times=times,surfaces=surfaces,matrix=matrix)
        count,=r.take('I');assert count<1000
        d['children']=[node() for _ in range(count)]
        return d
    nodes=[node() for _ in range(n)]
    assert r.p==len(r.data),(path,r.p,len(r.data))
    return nodes

def track_at(track,t,default):
    if not len(track):return np.array(default,dtype=float)
    return np.array([np.interp(t,track[:,0],track[:,i]) for i in range(2,len(default)+2)])

def cvd_exports(path,world,outdir):
    nodes=read_cvd(path);result=[]
    # CVD exporter is Z-up; original loader applies X=-90 degrees at its root.
    root=Rotation.from_euler('x',-90,degrees=True).as_matrix()
    def matrix(d,t):
        m=np.eye(4)
        if 'tracks' not in d:return m
        tr,ro,sc=d['tracks'];q=track_at(ro,t,[0,0,0,1]);q[3]*=-1
        r=Rotation.from_quat(q).as_matrix() if np.linalg.norm(q)>1e-8 else np.eye(3)
        s=track_at(sc,t,[1,1,1,0,0,0,1]);sq=s[3:7]
        sr=Rotation.from_quat(sq).as_matrix() if np.linalg.norm(sq)>1e-8 else np.eye(3)
        m[:3,:3]=r@sr@np.diag(s[:3]*d['scale'])@sr.T
        m[:3,3]=track_at(tr,t,[0,0,0]);return m
    def walk(d,parents):
        if 'vertices' in d:
            frames=[]
            for v,t in zip(d['vertices'],d['times']):
                m=np.eye(4)
                for parent in parents+[d]:m=m@matrix(parent,float(t))
                p=v[:,5:]@m[:3,:3].T+m[:3,3];frames.append(world(p@root.T))
            surfaces=[dict(texture=texture(path.parent,s['texture']),indices=s['indices']) for s in d['surfaces'] if len(s['indices'])]
            if surfaces:
                uv=d['vertices'][0,:,:2].copy();uv[:,1]=1-uv[:,1]
                dst=outdir/(path.stem.lower()+'_'+str(len(result))+'.r6v')
                result.append(mesh_file(dst,frames,uv,surfaces,d['times']))
        for c in d['children']:walk(c,parents+[d])
    for d in nodes:walk(d,[])
    return result

def scenes():
    for name in MAPS:
        data,world=layout(name);folder=SAMPLES/'scene'/name;outdir=OUT/'scenes'/name
        meshes,_=read_scene(folder/(name+'.r6s'));items=[]
        for i,m in enumerate(meshes):
            p=m['positions'];mat=m['matrix'];p=p@mat[:3,:3]+mat[3,:3]
            surfaces=[dict(texture=texture(folder,s['texture']),indices=s['indices']) for s in m['surfaces'] if len(s['indices'])]
            if not surfaces:continue
            uv=m['uv'].copy();uv[:,1]=1-uv[:,1]
            item=mesh_file(outdir/(str(i)+'.r6v'),[world(p)],uv,surfaces);item['name']=m['name'];items.append(item)
        anim=[];listing=folder/'anim/allanim.txt'
        if listing.exists():
            files={p.name.lower():p for p in listing.parent.iterdir()}
            for line in listing.read_text(encoding='gbk').splitlines()[1:]:
                words=line.split()
                if not words:continue
                src=files.get(words[0].lower())
                if not src:continue
                if src.suffix.lower()=='.gae':
                    # The mesh keeps its world-space tracks; GAE orchestration remains separate.
                    src=files.get(src.stem.lower()+'.cvd')
                if not src:continue
                try:anim+=cvd_exports(src,world,outdir)
                except (AssertionError,ValueError,struct.error) as exc:REPORT['warnings'].append(str(src)+': '+str(exc))
        dump(outdir/'scene.json',dict(meshes=items,animations=anim))
        REPORT['maps'][name]=dict(meshes=len(items),animations=len(anim),roads=len(data['roads']))
        print(name,REPORT['maps'][name],flush=True)

def actors():
    for i in range(1,13):
        folder=SAMPLES/'actor'/('role'+format(i,'x'));b=(folder/'tris.a_q').read_bytes();h=struct.unpack_from('<17i',b)
        sw,sh,fs,ns,nv,nst,nt,ncmd,nf,oskin,ost,otri,oframe,ocmd,oend=h[2:]
        skin=b[oskin:oskin+64].split(b'\0')[0].decode('gbk')
        st=np.frombuffer(b,'<i2',nst*2,ost).reshape(-1,2)/[sw,sh]
        st[:,1]=1-st[:,1]
        tri=np.frombuffer(b,'<u2',nt*6,otri).reshape(-1,6)
        # Split only UV seams; preserve vertex animation correspondence.
        pairs=np.stack([tri[:,:3].reshape(-1),tri[:,3:].reshape(-1)],axis=1)
        unique,ix=np.unique(pairs,axis=0,return_inverse=True);frames=[];clips={}
        for f in range(nf):
            off=oframe+f*fs;scale=np.array(struct.unpack_from('<3f',b,off));trans=np.array(struct.unpack_from('<3f',b,off+12))
            label=b[off+24:off+40].split(b'\0')[0].decode('ascii',errors='replace').lower()
            key=re.sub(r'[\d_]+$','',label);clips.setdefault(key,[]).append(f)
            p=np.frombuffer(b,'u1',nv*4,off+40).reshape(-1,4)[:,:3]*scale+trans
            frames.append(p[unique[:,0]]*.025)
        meta=mesh_file(OUT/'actors'/('role'+str(i)+'.r6v'),frames,st[unique[:,1]],
                       [dict(texture=texture(folder,skin),indices=ix)],np.arange(nf)/12,clips)
        dump(OUT/'actors'/('role'+str(i)+'.json'),meta);REPORT['actors'][str(i)]=dict(frames=nf,clips=list(clips))
    print('12 actors exported',flush=True)

if __name__=='__main__':
    scenes();actors();dump(ROOT/'docs/original-readable/scene-recovery/manifest.json',REPORT)
