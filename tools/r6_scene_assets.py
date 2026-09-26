"""Read R6HS/R6SM mesh records and material quadtrees (exe 0x409d60, 0x40a050).
UV precedes normals and position, never follows the position.
"""
from pathlib import Path
import struct
import numpy as np


class Reader:
    def __init__(self, data, offset=0):
        self.data,self.p=data,offset
    def take(self,fmt):
        out=struct.unpack_from('<'+fmt,self.data,self.p)
        self.p+=struct.calcsize('<'+fmt)
        return out
    def array(self,dtype,count):
        out=np.frombuffer(self.data,dtype=dtype,count=count,offset=self.p).copy()
        self.p+=out.nbytes
        return out
    def tree(self):
        n,=self.take('I');assert n<1000000
        ix=self.array('<u2',n*3).reshape(-1,3)
        self.take('3I6f')
        children=self.take('4I')
        assert all(v in (0,1) for v in children), (self.p,children)
        parts=[ix]
        for flag in children:
            if flag:parts.append(self.tree())
        return np.concatenate(parts)
    def mesh(self,version=100):
        name=self.take('32s')[0].split(b'\0')[0].decode('gbk',errors='replace')
        matrix=np.array(self.take('16f')).reshape(4,4)
        flag,=self.take('I');sphere=self.take('4f')
        fmt=self.take('I')[0] if version>=200 else 0x13
        nv,=self.take('I');assert nv<1000000
        stride=8 if fmt&2 else 6
        raw=self.array('<f4',nv*stride).reshape(nv,stride)
        pos=raw[:,-3:];uv=raw[:,:2]
        nm,=self.take('I');assert nm<1000
        surfaces=[]
        for i in range(nm):
            flags=self.take('I5I')
            texture=self.take('64s')[0].split(b'\0')[0].decode('gbk',errors='replace')
            ix=self.tree()
            assert ix.size==0 or ix.max()<nv,(name,nv,ix.max())
            surfaces.append(dict(texture=texture,indices=ix,flags=flags))
        return dict(name=name,matrix=matrix,positions=pos,uv=uv,surfaces=surfaces,flags=flag,sphere=sphere)


def read_scene(path):
    r=Reader(Path(path).read_bytes())
    magic,version=r.take('4sI')
    if magic==b'R6HS':return [r.mesh(version)],r
    assert magic==b'R6SM'
    _,n=r.take('2I')
    meshes=[r.mesh(version) for _ in range(n)]
    return meshes,r


if __name__=='__main__':
    for name in ['aiji','china','island','japan','paris','space','train']:
        path=Path('samples/scene')/name/(name+'.r6s')
        try:
            meshes,r=read_scene(path)
            print(name,len(meshes),'verts',sum(len(m['positions']) for m in meshes),'end',r.p,'/',len(r.data))
        except Exception as e:print(name,type(e).__name__,str(e))
