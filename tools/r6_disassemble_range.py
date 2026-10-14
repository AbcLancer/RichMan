"""Read-only original EXE disassembly for a named address range."""
import sys
import pefile
import capstone

pe = pefile.PE(r"D:\Projects\reference\Rich6\rich6.exe")
base = pe.OPTIONAL_HEADER.ImageBase
start = int(sys.argv[1], 0)
end = int(sys.argv[2], 0)
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
md.skipdata = True
for ins in md.disasm(pe.get_data(start - base, end - start), start):
    print(f"{ins.address:08x}: {ins.mnemonic:8} {ins.op_str}")
