"""Static x86 disassembly with focused map-loader excerpts. No executable patching.

Requires pefile and capstone. Linear sweep can interpret embedded data as code;
only manually traced functions in map-functions.asm.txt are used as evidence.
"""
from pathlib import Path
import argparse
import hashlib
import capstone
import pefile

FUNCTIONS = {
    'map_path': (0x47ee40, 0x47ee6f),
    'map_load': (0x418840, 0x418b9f),
    'map_tables': (0x42c7a0, 0x42ca32),
    'streets_read': (0x42c470, 0x42c609),
    'blocks_read': (0x42c250, 0x42c470),
    'curve_and_roads_read': (0x42c080, 0x42c24d),
    'bezier_evaluate': (0x402f20, 0x402fdd),
    'curve_evaluate': (0x4030c0, 0x403178),
    'road_distance_to_parameter': (0x42bc40, 0x42bd03),
    'plot_center_and_corner': (0x42b630, 0x42b73f),
    'world_to_minimap': (0x42ee10, 0x42ee5a),
    'minimap_markers': (0x446460, 0x4465a8),
    'minimap_widget_size': (0x446bc5, 0x446be8),
}


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--exe',type=Path,default=Path('D:/Projects/reference/Rich6/rich6.exe'))
    a=ap.parse_args()
    p=pefile.PE(str(a.exe));base=p.OPTIONAL_HEADER.ImageBase
    md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.skipdata=True
    out=Path(__file__).resolve().parents[1]/'docs/original-readable/disassembly'
    out.mkdir(exist_ok=True)
    header=f'; {a.exe}\n; SHA256 {hashlib.sha256(a.exe.read_bytes()).hexdigest()}\n; Image base {base:#x}; addresses below are VA, not file offsets.\n'
    def lines(raw,address):
        return '\n'.join(f'{va:08x}: {m:8} {op}' for va,_,m,op in md.disasm_lite(raw,address))+'\n'
    sections=[header+'; Linear sweep: embedded data may appear as instructions.\n']
    for s in p.sections:
        if s.Characteristics & 0x20000000:
            sections.append(lines(s.get_data(),base+s.VirtualAddress))
    (out/'rich6.asm.txt').write_text('\n'.join(sections),encoding='utf-8')
    focused=[header]
    for name,(start,end) in FUNCTIONS.items():
        focused.append(f'\n; {name} (analyst-assigned name)\n'+lines(p.get_data(start-base,end-start),start))
    (out/'map-functions.asm.txt').write_text('\n'.join(focused),encoding='utf-8')
    print('Wrote full linear sweep and 13 focused function ranges:',out)


if __name__=='__main__':main()
