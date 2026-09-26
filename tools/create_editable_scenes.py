"""Create Godot map scenes once; NEVER overwrite hand-edited scenes.
Requires build_original_scenes.py first. Coordinates are board units.
"""
from pathlib import Path
import json, re
ROOT=Path(__file__).resolve().parents[1]

def vec(p):return 'Vector3('+', '.join(format(float(v),'.9g') for v in p)+')'
def label(s):return re.sub(r'[^\w\u4e00-\u9fff-]', '_', s)

def main():
    out=ROOT/'game/scenes/maps';out.mkdir(parents=True,exist_ok=True)
    catalog={}
    for src in sorted((ROOT/'game/assets/original/scenes').glob('*/scene.json')):
        name=src.parent.name;data=json.loads(src.read_text(encoding='utf-8'));dst=out/(name+'.tscn')
        rows=['[gd_scene load_steps=2 format=3]',
              '[ext_resource type="Script" path="res://scripts/ui/original_mesh.gd" id="1_mesh"]',
              '[node name="OriginalScene" type="Node3D"]',
              '[node name="Environment" type="Node3D" parent="."]',
              '[node name="Animations" type="Node3D" parent="."]']
        entries=[]
        def emit(item,parent,offset,index):
            mesh_name=label(str(item.get('name','mesh')))+'__'+str(index)
            path=parent+'/'+mesh_name
            rows.extend([f'[node name="{mesh_name}" type="MeshInstance3D" parent="{parent}"]',
                         'position = '+vec([a-b for a,b in zip(item['pivot'],offset)]),
                         'script = ExtResource("1_mesh")',
                         'definition_path = '+json.dumps(item['definition'],ensure_ascii=False)])
            entries.append(dict(node=path,original_name=item.get('name'),source=item.get('source'),
                                definition=item['definition'],pivot=item['pivot']))
        for i,item in enumerate(data['meshes']):emit(item,'Environment',[0,0,0],i)
        groups={}
        for item in data['animations']:
            key=Path(item['source']).stem;groups.setdefault(key,[]).append(item)
        for key,items in groups.items():
            center=[sum(it['pivot'][j] for it in items)/len(items) for j in range(3)]
            group=label(key)
            rows.extend([f'[node name="{group}" type="Node3D" parent="Animations"]','position = '+vec(center)])
            for i,item in enumerate(items):emit(item,'Animations/'+group,center,i)
        catalog[name]=entries
        if dst.exists():print('Preserved:',dst.name)
        else:dst.write_text('\n\n'.join(rows)+'\n',encoding='utf-8');print('Created:',dst.name)
    target=ROOT/'docs/original-readable/scene-recovery/object-catalog.json'
    target.write_text(json.dumps(catalog,ensure_ascii=False,indent=1),encoding='utf-8')

if __name__=='__main__':main()
