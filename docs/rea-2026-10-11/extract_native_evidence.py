from pathlib import Path
import hashlib,json,re,struct
import capstone,pefile
out=Path('docs/rea-2026-10-11');out.mkdir(exist_ok=True)
exe=Path('D:/Projects/reference/Rich6/rich6.exe');raw=exe.read_bytes();pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True;md.skipdata=True
text=next(s for s in pe.sections if s.Name.startswith(b'.text'));ins=list(md.disasm(text.get_data(),base+text.VirtualAddress))
callers={};memrefs={};immrefs={}
for i in ins:
 if i.id==0:continue
 for op in i.operands:
  if op.type==capstone.CS_OP_IMM:
   immrefs.setdefault(op.imm,[]).append(i.address)
   if i.mnemonic=='call':callers.setdefault(op.imm,[]).append(i.address)
  if op.type==capstone.CS_OP_MEM and not op.mem.base and not op.mem.index:
   memrefs.setdefault(op.mem.disp,[]).append(i.address)
strings=[]
for sec in pe.sections:
 for m in re.finditer(rb'[\x20-\x7e]{6,}',sec.get_data()):
  value=m.group().decode('ascii');va=base+sec.VirtualAddress+m.start()
  if re.search(r'Pet_|Card_|Event_|Player_|Casino|casino|lotto|Lotto|date|Date|Initvar|\bmonth',value):
   strings.append({'va':hex(va),'value':value,'references':[hex(x) for x in immrefs.get(va,[])]})
(out/'native-seeds.json').write_text(json.dumps({'sha256':hashlib.sha256(raw).hexdigest(),'strings':strings,'calls':{hex(k):[hex(x) for x in v] for k,v in callers.items()},'absolute_memory_references':{hex(k):[hex(x) for x in v] for k,v in memrefs.items()}},ensure_ascii=False,indent=2),encoding='utf-8')
regions={'status_accessors':(0x435f80,0x436140),'building_lookup_and_change':(0x41ce10,0x41d3d0),'price_street_adjust':(0x42ead0,0x42ebc0),'clear_vehicle':(0x428950,0x428c90),'random_range':(0x405130,0x405190),'card_combination':(0x41ee80,0x41f1a0),'pet_database':(0x433000,0x434050),'player_card_inventory':(0x434a00,0x435160),'player_pet_inventory':(0x435630,0x435f80)}
manifest={'tool':'Capstone 5.0.7 + pefile 2024.8.26, static disassembly, not REA deep analysis','binary':str(exe),'sha256':hashlib.sha256(raw).hexdigest(),'image_base':hex(base),'regions':{}}
for name,(a,b) in regions.items():
 payload=pe.get_data(a-base,b-a);lines=[f'; Static VA region {a:#x}..{b:#x}, may include adjacent helpers. Not original source.','; Binary SHA256 '+manifest['sha256']]
 for i in md.disasm(payload,a):lines.append(f'{i.address:08x}: {i.bytes.hex():24} {i.mnemonic:8} {i.op_str}')
 path=out/(name+'.asm.txt');path.write_text('\n'.join(lines)+'\n',encoding='utf-8');manifest['regions'][name]={'start':hex(a),'end_exclusive':hex(b),'file_offset':pe.get_offset_from_rva(a-base),'bytes_sha256':hashlib.sha256(payload).hexdigest(),'file':path.name}
(out/'native-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Instruction count',len(ins));print('Seeds',len(strings));print('Saved',len(regions),'native regions')
for s in strings:
 if re.search(r'Pet_|casino|lotto|Card_Yin|Card_Bao|Player_Sleep',s['value'],re.I):print(s)
