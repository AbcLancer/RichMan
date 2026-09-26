"""Map extraction grounded in rich6.exe 0x42c7a0/0x42c080/0x4030c0.
Outputs original fields and Bezier-evaluated positions; no image route fitting.
"""
from pathlib import Path
import json
import struct
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/original-readable/map-recovery'


def parse(path):
    b = path.read_bytes()
    assert b[:4] == b'R6MP'
    p = 148
    def take(fmt):
        nonlocal p
        result = struct.unpack_from('<' + fmt, b, p)
        p += struct.calcsize('<' + fmt)
        return result
    ns, = take('I')
    streets = [take('16s')[0].split(b'\0')[0].decode('gbk') for _ in range(ns)]
    nb, = take('I')
    blocks = []
    for i in range(nb):
        offset = p
        matrix = np.array(take('16f')).reshape(4, 4)
        index, width, depth = take('3i')
        assert 0 < width < 100 and 0 < depth < 100
        cells = []
        for j in range(width * depth):
            flags, a, c, d, e, street = take('I4hi')
            # 0x42b670 + 0x42b700: cell center = (col+.5,0,row+.5)*100*M.
            local = np.array([(j % width + .5) * 100, 0, (j // width + .5) * 100, 1])
            center = local @ matrix
            cells.append(dict(index=j, flags=flags, parameters=[a,c,d,e], street=street,
                              position=center[:3].tolist()))
        blocks.append(dict(index=index, offset=offset, width=width, depth=depth,
                           matrix=matrix.tolist(), cells=cells))
    curve_offset = p
    curve_type, closed, nk = take('3I')
    knots = [list(take('10f')) for _ in range(nk)]
    road_offset = p
    nr, = take('I')
    roads = []
    for i in range(nr):
        kind, block, cell, street, sx, sy, t, distance, remaining = take('4i5f')
        assert 0 <= t <= nk
        k = int(t) % nk
        f = t - int(t)
        first, second = np.array(knots[k]), np.array(knots[(k + 1) % nk])
        # 0x4030c0 calls 0x402f20 with knot P,+12 outgoing,next +0 incoming,next P.
        pos = (1-f)**3*first[6:9] + 3*(1-f)**2*f*first[3:6] + 3*(1-f)*f*f*second[:3] + f**3*second[6:9]
        roads.append(dict(index=i, kind=kind, block=block, cell=cell, street=street,
                          scale=[sx,sy], parameter=t, distance=distance, remaining=remaining,
                          position=pos.tolist()))
        if block >= 0:
            assert block < nb and 0 <= cell < len(blocks[block]['cells'])
    after_roads = p
    mini = take('3f3i')
    return dict(minimap=dict(origin=list(mini[:2]), scale=mini[2], swap=mini[3], offset=list(mini[4:])), source=str(path), streets=streets, blocks=blocks, curve_offset=curve_offset,
                curve_type=curve_type, closed=closed, knots=knots, road_offset=road_offset,
                roads=roads, after_roads=after_roads)


def ground_uv(path):
    b = path.read_bytes()
    assert b[:4] == b'R6HS' and struct.unpack_from('<I', b, 4)[0] == 200
    n, = struct.unpack_from('<I', b, 128)
    v = np.array([struct.unpack_from('<2fI3f', b, 132 + i*24) for i in range(n)])
    tex = b.index(b'ditu.tga\0', 132 + n*24)
    nt, = struct.unpack_from('<I', b, tex + 64)
    ix = np.frombuffer(b, dtype='<u2', count=nt*3, offset=tex+68)
    assert ix.max() < n
    used = v[np.unique(ix)]
    basis = np.c_[used[:,3], used[:,5], np.ones(len(used))]
    affine = np.linalg.lstsq(basis, used[:,:2], rcond=None)[0]
    error = float(np.abs(basis @ affine - used[:,:2]).max())
    assert error < 1e-5
    return affine, dict(source=str(path), texture_offset=tex, triangles=nt,
                        vertices=len(used), affine=affine.tolist(), max_uv_error=error)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    data = parse(ROOT / 'samples/scene/aiji/aiji.r6m')
    affine, uv_info = ground_uv(ROOT / 'samples/scene/aiji/aiji.pol')
    data['ground_uv'] = uv_info
    def pixel(pos):
        uv = np.array([pos[0],pos[2],1]) @ affine
        return float(uv[0]*1024), float((1-uv[1])*1024)
    image = Image.open(ROOT/'samples/scene/aiji/ditu.tga').convert('RGB')
    draw = ImageDraw.Draw(image)
    pts = [pixel(r['position']) for r in data['roads']]
    draw.line(pts+[pts[0]], fill='#00ffff', width=2)
    for r, point in zip(data['roads'],pts):
        x,y=point
        draw.ellipse((x-2,y-2,x+2,y+2),fill='blue')
        if r['index']%5==0:draw.text((x+3,y),str(r['index']),fill='white')
        if r['block']>=0:
            cell=data['blocks'][r['block']]['cells'][r['cell']]
            target=pixel(cell['position'])
            draw.line([point,target],fill='#ff5555',width=1)
            x,y=target
            draw.rectangle((x-3,y-3,x+3,y+3),outline='#ff0000',width=2)
    image.save(OUT/'aiji-route-plots-overlay.png')
    mini = data['minimap']
    im = Image.open(ROOT/'game/assets/uitex/subc/m_aiji.png').convert('RGB').resize((1024,512))
    md = ImageDraw.Draw(im)
    mp = []
    for r in data['roads']:
        x,z = np.array(r['position'])[[0,2]]
        q = (np.array([x,z])-mini['origin'])*mini['scale']+mini['offset']
        mp.append(tuple((q+[20,16])*[256/229,128/155]*4))
    md.line(mp+[mp[0]],fill='cyan',width=2)
    im.save(OUT/'aiji-minimap-overlay.png')
    (OUT/'aiji.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    rows=['index\tkind\tblock\tcell\tstreet\tcurve_parameter\tx\ty\tz']
    for r in data['roads']:
        rows.append('\t'.join(map(str,[r[k] for k in ('index','kind','block','cell','street','parameter')]+r['position'])))
    (OUT/'aiji-roads.tsv').write_text('\n'.join(rows),encoding='utf-8')
    # Production layout uses the same UV transform as the evidence overlay.
    def board(pos):
        x,y=pixel(pos)
        return [(x/1024-.5)*200, (y/1024-.5)*200]
    layout=dict(_source='Original R6MP records + executable Bezier evaluation; see docs/original-readable/map-recovery',
                _board_size=200, ground_affine=affine.tolist(), tiles=[], knots=[], roads=data['roads'], blocks=[], minimap=mini)
    for knot in data['knots']:
        layout['knots'].append(dict(incoming=board(knot[:3]),outgoing=board(knot[3:6]),
                                    point=board(knot[6:9]),length=knot[9]))
    for block in data['blocks']:
        matrix=np.array(block['matrix']);origin=board(matrix[3,:3])
        axes=[(np.array(board(matrix[3,:3]+matrix[i,:3]*100))-origin).tolist() for i in (0,2)]
        layout['blocks'].append(dict(width=block['width'],depth=block['depth'],origin=origin,axes=axes))
    # 名字逐条抄自原版 config/Roadevent.txt（1..16），别自己意译：
    #   6 = 拉霸（slot，不是「酒吧」）  8 = 精灵屋（不是「宠物店」）
    #   9/10 = 游戏点A/B（不是「游戏馆」）
    events={1:('platform','传送平台'),2:('cardshop','卡片商店'),3:('hospital','医院'),4:('cardpt','卡片点'),
            5:('tvnews','电视台'),6:('labar','拉霸'),7:('capital','市政府'),8:('pethouse','精灵屋'),
            9:('game_a','游戏点A'),10:('game_b','游戏点B'),11:('coupon5','点券5'),12:('coupon10','点券10'),
            13:('coupon20','点券20'),14:('coupon30','点券30'),15:('coupon50','点券50'),16:('casino','乐透')}
    mp=ROOT/'game/data/maps/aiji.json'
    gameplay=json.loads(mp.read_text(encoding='utf-8'))
    gameplay['_source']=layout['_source'];gameplay['tiles']=[];gameplay['streets']=data['streets']
    gameplay['tile_count']=len(data['roads'])
    gameplay.pop('plots_per_street',None)
    street_counts={}
    for r in data['roads']:
        x,z=board(r['position'])
        layout['tiles'].append(dict(i=r['index'],x=x,z=z))
        t=dict(i=r['index'],original_kind=r['kind'],original_block=r['block'],original_cell=r['cell'])
        if r['block']>=0:
            sid=r['street'];ordinal=street_counts.get(sid,0);street_counts[sid]=ordinal+1
            t.update(kind='plot',street=data['streets'][sid],street_index=sid,plot_in_street=ordinal,
                     plot_key=f"{r['block']}:{r['cell']}")
        else:
            eid,label=events.get(r['kind'],('unknown','原版事件'))
            t.update(kind='event',event=eid,name=label)
        gameplay['tiles'].append(t)
    (ROOT/'game/data/maps/aiji_tilepos.json').write_text(json.dumps(layout,ensure_ascii=False,indent=1),encoding='utf-8')
    mp.write_text(json.dumps(gameplay,ensure_ascii=False,indent=1),encoding='utf-8')
    print('knots',len(data['knots']),'roads',len(data['roads']),'blocks',len(data['blocks']),'ground',uv_info)


if __name__=='__main__':main()
