"""把原版「场景配置」并进 game/data/maps/<map>.json。

权威来源（安装目录外置配置，rich6.exe 里有 `config/scene/%s/%s.txt` 的路径串）：
    docs/original-readable/installation/config/scene/<map>/<Name>.txt

同时把资源包内的旧副本读进来做对照（`scene/<map>/<map>.txt`，buildinfo 常与
外置不一致，例如埃及包内写 `1 1 1`、外置写 `1 0 0`），两者都记进 `scene_config`。

这一行是本次关键：
    //和体力相关参数----每走一步消耗体力，每秒恢复体力，自己走所需要最小体力值，玩家最大体力值
    20  7  240  600
体力是**地图级**参数（太空关是 `0 0 10 5000`），所以放地图 JSON 而不是 rules。
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / 'docs/original-readable/installation/config/scene'
ARCHIVE = ROOT / 'docs/original-readable/archive/scene'
MAPS = ROOT / 'game/data/maps'

## 路面物体中文名 → samples/roadobj 下的目录名（13 种，见 Egypt/China/Space 配置）
ROAD_ITEM_KEYS = {
    '卡片': 'card', '戒指': 'crystal', '汉堡': 'hanbao', '神仙蛋': 'petegg',
    '强盗': 'robber', '炸弹人': 'bomb', '小偷': 'thief', '隔毁': 'block',
    '地雷': 'mine', '财神': 'caishen', '福神': 'fushen',
    '衰神': 'shuaishen', '穷神': 'qiongshen',
}


def _lines(path: Path):
    txt = path.read_text(encoding='utf-8-sig', errors='replace')
    return [ln.rstrip() for ln in txt.replace('\r\n', '\n').split('\n')]


def parse_scene(path: Path) -> dict:
    """按 `//标签` + 紧跟数据行的排版切段。原版就是这种朴素格式。"""
    ls = _lines(path)
    tags = []          # [(标签, [数据行...])]
    cur = None
    for ln in ls:
        if ln.startswith('//'):
            cur = [ln[2:].strip(), []]
            tags.append(cur)
        elif ln.strip() and cur is not None:
            cur[1].append(ln.strip())
    out = {'_source': str(path.relative_to(ROOT)).replace('\\', '/')}
    for tag, data in tags:
        head = tag.split('\t')[0].split(',')[0].strip()
        if head == 'buildinfo' and data:
            parts = re.split(r'\s+', data[0])
            if len(parts) >= 6:
                out['build_flags'] = {parts[i]: int(parts[i + 1]) for i in range(0, 6, 2)}
        elif '虚拟公司' in head and data:
            comps = []
            for row in data:
                c = re.split(r'\s+', row)
                if len(c) >= 3:
                    comps.append({'name': c[0], 'capital': int(float(c[1])),
                                  'shares': int(float(c[2]))})
            out['virtual_companies'] = comps
        elif '标志位置' in head and data:
            # 形如 `hospital  458.0  -160.0  72.0`：首个 token 是名字，后面才是坐标
            v = re.split(r'\s+', data[0])
            if not re.match(r'^-?\d', v[0]):
                v = v[1:]
            out['hospital'] = [float(v[0]), float(v[1]), float(v[2])]
        elif '简要描述' in head and data:
            out['display_name'] = data[0]
        elif '任务' in head and data:
            out['mission'] = ''.join(data).strip()
        elif '默认角度' in head and data:
            v = re.split(r'\s+', data[0])
            out['camera'] = {'yaw': float(v[0]), 'height': float(v[1]), 'distance': float(v[2])}
        elif '体力相关参数' in head and data:
            v = re.split(r'\s+', data[0])
            out['stamina'] = {'step_cost': float(v[0]), 'regen_per_sec': float(v[1]),
                              'min_to_start': float(v[2]), 'max': float(v[3])}
        elif '路面物体的种类数' in head and data:
            out['road_item_kinds'] = int(float(data[0]))
        elif head in ROAD_ITEM_KEYS and data:
            out.setdefault('road_items', {})[ROAD_ITEM_KEYS[head]] = int(float(data[0]))
    return out


def main() -> None:
    for d in sorted(INSTALL.iterdir()):
        if not d.is_dir():
            continue
        name = d.name
        txts = list(d.glob('*.txt'))
        if not txts:
            continue
        # 优先取与目录同名的配置文件（train/ 下同时有 Street.txt 和 Train.txt）
        same = [p for p in txts if p.stem.lower() == name.lower()]
        install = parse_scene((same or txts)[0])
        # 资源包内的旧副本（对照用；改名前缀 aiji→Aiji，用大小写不敏感匹配）
        archive = None
        ad = ARCHIVE / name
        if ad.is_dir():
            cs = [p for p in ad.glob('*.txt')
                  if p.stem.lower() in (name.lower(), 'street', 'scene')]
            if cs:
                archive = parse_scene(cs[0])
        mp = MAPS / ('%s.json' % name)
        if not mp.exists():
            print('%-9s 跳过（无 %s）' % (name, mp.name))
            continue
        data = json.loads(mp.read_text(encoding='utf-8'))
        data['stamina'] = install.get('stamina', {})
        data['road_items'] = install.get('road_items', {})
        data['road_item_kinds'] = install.get('road_item_kinds', 0)
        data['mission'] = install.get('mission', '')
        data['scene_config'] = {
            '_source': install['_source'],
            'build_flags_install': install.get('build_flags', {}),
            'build_flags_pack': (archive or {}).get('build_flags', {}),
            'camera': install.get('camera', {}),
            'hospital': install.get('hospital', []),
        }
        # build_flags 采用**安装目录外置配置**（exe 引用的是 config/scene/...）——
        # 埃及因此变成「只能建工业」，与原版任务描述一致（见 docs/decision-log.md）。
        if install.get('build_flags'):
            data['build_flags'] = install['build_flags']
        if install.get('display_name'):
            data['display_name'] = install['display_name']
        if install.get('hospital'):
            data.setdefault('landmarks', {})['hospital'] = install['hospital']
        mp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
        st = data['stamina']
        print('%-9s 体力=%s 物体=%d 类 build=%s (包内=%s)' % (
            name, st, len(data['road_items']), data['build_flags'],
            (archive or {}).get('build_flags', '?')))


if __name__ == '__main__':
    main()
