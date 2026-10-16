#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按 VA 范围反汇编 rich6.exe（Capstone），并把「PUSH 立即数」标出来。

用途：Ghidra 有时不把某段代码识别成函数（比如被跳转表/尾调用进入的），
这时 `DecompileAt.java` 会报「不在任何已知函数内」。本脚本绕过函数概念，
**直接按地址范围线性反汇编**，专门用来看「卡效果注册表」这类
`PUSH 参数 / PUSH 函数地址 / CALL 注册` 的连续序列。

用法:
  python tools/r6_disasm_range.py <起始VA> <结束VA> [--base 0x400000]

例子（卡效果注册区）:
  python tools/r6_disasm_range.py 0x422700 0x422a00
"""
import sys, struct

EXE = 'D:/Projects/reference/Rich6/rich6.exe'


def load_sections(path):
    import pefile
    pe = pefile.PE(path, fast_load=True)
    base = pe.OPTIONAL_HEADER.ImageBase
    secs = []
    for s in pe.sections:
        secs.append((s.Name.rstrip(b'\0').decode('ascii', 'replace'),
                     base + s.VirtualAddress, s.PointerToRawData, s.SizeOfRawData))
    return base, secs


def va_to_off(va, base, secs):
    for nm, sva, raw, sz in secs:
        if sva <= va < sva + sz:
            return raw + (va - sva)
    return None


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    start = int(sys.argv[1], 0)
    end = int(sys.argv[2], 0)
    base, secs = load_sections(EXE)
    off = va_to_off(start, base, secs)
    if off is None:
        print(f"{start:#x} 不在任何节里")
        return 1
    data = open(EXE, 'rb').read()[off:off + (end - start)]

    try:
        from capstone import Cs, CS_ARCH_X86, CS_MODE_32
    except ImportError:
        print("没有 capstone（用 .workbuddy/venv 里的 python）")
        return 1
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    print(f"# 反汇编 {start:#x} .. {end:#x}  （{len(data)} 字节）\n")

    for ins in md.disasm(data, start):
        txt = f"{ins.mnemonic:<8}{ins.op_str}"
        mark = ""
        if ins.mnemonic == "push" and ins.op_str.startswith("0x"):
            v = int(ins.op_str, 16)
            if 0x401000 <= v < 0x500000:
                mark = "   ← ★ 代码地址（疑似效果函数）"
            else:
                mark = f"   (= {v})"
        if ins.mnemonic == "call":
            mark = mark or "   ← 调用"
        print(f"{ins.address:#010x}  {ins.bytes.hex():<20} {txt}{mark}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
