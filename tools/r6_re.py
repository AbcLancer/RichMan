#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""r6_re —— 原版 `rich6.exe` 的**定点**逆向脚手架（capstone + pefile）。

## 先说清楚「能不能看到原版逻辑全貌」

**不能。** 依据（都是实测，不是推测）：

1. 包内（`gamedata.pck` 2143 个条目）**没有脚本**：无 `.lua` / `.js` / 字节码；
   唯一的「脚本」是 `gfxscript/*.gbf`，那是**渲染着色器**，不含玩法逻辑。
   → 所以「原本的脚本逻辑」这个东西在原版里**根本不以可读形式存在**。
2. `rich6.exe` 是 2002 年的原生 x86 PE（688 KB，4 节、未加壳），
   **没有 PDB / DWARF、没有 RTTI（`??` 计数 = 0）、没有导出表**。
   → 没有函数名、没有类名、没有类型信息，全是裸机器码。
3. 已有的 `docs/original-readable/disassembly/rich6.asm.txt` 是**线性扫描**产物：
   把 .text 从头到尾当指令解，没有函数边界、没有交叉引用 → 只能读，不能追逻辑。

**能做的**是**定点恢复**：拿一个确定的线索（字符串地址 / 魔数 / 已知调用点），
顺着 call/imm 引用图反查「谁用了它」，再人工读那几十行汇编。
另一个 AI 恢复的 6 个地图算法（`docs/original-readable/map-recovery/`）就是这么来的：
`0x42C250` 读地产块、`0x42C080` 读曲线道路、`0x4030C0` 曲线求值、
`0x42BC40` 格间行走、`0x42B670` 空地中心、`0x42EE10` 小地图变换。

本工具就是给这条路用的：**建立「数据 ↔ 代码」的引用索引**，把「定点」变成可重复的操作。

## 用法

    python tools/r6_re.py info                     # 节表 + 函数个数估算
    python tools/r6_re.py strs [--filter card]     # .rdata 可打印字符串（含 VA）
    python tools/r6_re.py xref 0x9DF4C             # 谁引用了这个地址（字符串/全局变量）
    python tools/r6_re.py calls                    # 被 call 最多的目标（＝热门函数）

Windows 上用仓库 venv 的 python 跑（需要 capstone / pefile）：
    .workbuddy/venv/Scripts/python.exe tools/r6_re.py info
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from collections import Counter, defaultdict

import pefile
from capstone import CS_ARCH_X86, CS_MODE_32, Cs
from capstone.x86 import X86_OP_IMM, X86_OP_MEM, X86_REG_ESP, X86_REG_EBP

EXE = os.environ.get("R6_EXE", r"F:\游戏\Rich6\rich6.exe")

# 只认这些指令的立即数操作数当作「引用」：避免把普通算术常量误报成地址。
# 位置也要对：push/mov/lea 的 imm，且值落在某个节的 VA 区间内。
_ADDR_INSN = {"push", "mov", "lea", "cmp", "test", "and", "or"}


class Image:
    """把 PE 摊平成「VA → 字节」的虚拟镜像，方便按 VA 取码 / 取数据。"""

    def __init__(self, path: str):
        self.pe = pefile.PE(path, fast_load=True)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.sections = []          # [(name, va, vsize, rawlen, is_code)]
        self.raw_map = []           # [(raw_start, raw_end, va)] 用于**文件偏移 → VA**
        self._blobs = []            # [(va_start, va_end, bytes)]
        for s in self.pe.sections:
            name = s.Name.rstrip(b"\x00").decode("latin1")
            va = self.base + s.VirtualAddress
            data = s.get_data()
            vsize = max(s.Misc_VirtualSize, len(data))
            code = bool(s.Characteristics & 0x20)      # IMAGE_SCN_CNT_CODE
            self.sections.append((name, va, vsize, len(data), code))
            self.raw_map.append((s.PointerToRawData, s.PointerToRawData + len(data), va))
            if data:
                self._blobs.append((va, va + len(data), data))
        self.code_lo, self.code_hi = self._code_range()

    def _code_range(self) -> tuple[int, int]:
        lo, hi = None, None
        for name, va, vsize, rawlen, code in self.sections:
            if code:
                lo = va if lo is None else min(lo, va)
                hi = va + (rawlen or vsize) if hi is None else max(hi, va + (rawlen or vsize))
        return (lo or 0, hi or 0)

    def read(self, va: int, n: int) -> bytes:
        for a, b, d in self._blobs:
            if a <= va < b:
                off = va - a
                return d[off:off + n]
        return b""

    def in_image(self, va: int) -> bool:
        return any(a <= va < b for a, b, _ in self._blobs)

    def section_of(self, va: int) -> str:
        for name, sva, vsize, rawlen, _ in self.sections:
            if sva <= va < sva + max(vsize, rawlen):
                return name
        return "?"

    def off_to_va(self, off: int) -> int | None:
        """文件偏移 → VA。

        ⚠️ `docs/original-readable/executable-references.txt` 里那串
        `0x0009DF4C config/card.txt` 是**文件偏移**，不是 VA（exe 才 688 KB，
        而 VA 空间从 0x401000 起）。用它查 xref 前必须先换算。
        """
        for a, b, va in self.raw_map:
            if a <= off < b:
                return va + (off - a)
        return None

    def va_to_off(self, va: int) -> int | None:
        for s in self.pe.sections:
            sva = self.base + s.VirtualAddress
            if sva <= va < sva + max(s.Misc_VirtualSize, len(s.get_data())):
                return s.PointerToRawData + (va - sva)
        return None


def _md() -> Cs:
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.detail = True
    return md


def disasm_all(img: Image, md: Cs):
    """线性扫 .text，产出 (va, insn) 序列。"""
    lo, hi = img.code_lo, img.code_hi
    code = img.read(lo, hi - lo)
    if not code:
        return
    for insn in md.disasm(code, lo):
        yield insn.address, insn


def is_probable_addr(img: Image, v: int) -> str:
    """这个立即数看起来像不像一个数据地址？（排除小常量 / 栈偏移）"""
    if v < 0x400000 or v > 0x800000:
        return ""
    if not img.in_image(v):
        return ""
    return img.section_of(v)


def cmd_info(img: Image) -> None:
    print(f"EXE   : {EXE}")
    print(f"ImageBase = {img.base:#x}   .text = {img.code_lo:#x}..{img.code_hi:#x} "
          f"({img.code_hi - img.code_lo} B)")
    print(f"{'name':10} {'VA':>10} {'vsize':>9} {'raw':>8}  kind")
    for name, va, vsize, rawlen, code in img.sections:
        print(f"{name:10} {va:#10x} {vsize:9d} {rawlen:8d}  {'CODE' if code else 'data'}")

    md = _md()
    calls: Counter[int] = Counter()
    n = 0
    for _va, insn in disasm_all(img, md):
        n += 1
        if insn.mnemonic in ("call", "jmp") and insn.operands:
            op = insn.operands[0]
            if op.type == X86_OP_IMM and img.code_lo <= op.imm < img.code_hi:
                calls[op.imm] += 1
    print(f"\n线性扫描解得指令 {n} 条；不同的 call/jmp 目标 {len(calls)} 个"
          f"（≈ 函数个数下界，线性扫描会把内联数据当指令，所以只是估算）")
    print("被 call 次数最多的 15 个（多半是 malloc/memcpy/字符串操作等运行时）：")
    for va, c in calls.most_common(15):
        print(f"  {va:#010x}  ×{c}")


def cmd_strs(img: Image, flt: str | None) -> None:
    """把 .rdata/.data 里的可打印字符串连同 VA 打出来 —— 这就是「线索表」。"""
    pat = re.compile(rb"[\x20-\x7e]{4,}")
    for name, va, vsize, rawlen, code in img.sections:
        if code:
            continue
        data = img.read(va, rawlen or vsize)
        for m in pat.finditer(data):
            s = m.group().decode("latin1")
            if flt and flt.lower() not in s.lower():
                continue
            print(f"{va + m.start():#010x}  {s}")


def cmd_xref(img: Image, target: int) -> None:
    """列出引用了 target 这个地址的指令。

    只做**保守**判定：操作数形如 `push imm32` / `mov reg, imm32` / `lea reg, [imm32]`
    且 imm 落在镜像内。原版是 MSVC 的非 PIE 可执行文件，字符串/全局变量都是绝对
    立即数寻址，所以这一招抓得到。
    """
    md = _md()
    hits = []
    for va, insn in disasm_all(img, md):
        if insn.mnemonic not in _ADDR_INSN:
            continue
        for op in insn.operands:
            v = None
            if op.type == X86_OP_IMM:
                v = op.imm
            elif op.type == X86_OP_MEM:
                # [imm32] / [reg + imm32]
                if op.mem.base == 0 and op.mem.index == 0:
                    v = op.mem.disp
                elif op.mem.base not in (X86_REG_ESP, X86_REG_EBP):
                    v = None
                else:
                    v = None
            if v == target:
                hits.append((va, f"{insn.mnemonic} {insn.op_str}"))
    print(f"引用 {target:#x}（{img.section_of(target)}）的指令：{len(hits)} 条")
    for va, txt in hits:
        print(f"  {va:#010x}  {txt}")


def cmd_calls(img: Image) -> None:
    md = _md()
    callers: dict[int, list[int]] = defaultdict(list)
    for va, insn in disasm_all(img, md):
        if insn.mnemonic == "call" and insn.operands:
            op = insn.operands[0]
            if op.type == X86_OP_IMM:
                callers[op.imm].append(va)
    print(f"共 {len(callers)} 个直接 call 目标")
    for tgt in sorted(callers):
        if tgt < img.code_lo or tgt >= img.code_hi:
            continue
        cs = callers[tgt]
        print(f"  {tgt:#010x}  被 {len(cs)} 处调用，前 6 个调用点："
              + ", ".join(f"{c:#x}" for c in cs[:6]))


def cmd_dis(img: Image, start: int, count: int) -> None:
    """从 start 反汇编 count 条指令（给人读的那种）。"""
    md = _md()
    for i, insn in enumerate(md.disasm(img.read(start, count * 8), start)):
        if i >= count:
            break
        b = " ".join(f"{x:02x}" for x in insn.bytes)
        print(f"{insn.address:#010x}  {b:<24} {insn.mnemonic:<7} {insn.op_str}")


def main() -> int:
    global EXE
    ap = argparse.ArgumentParser(description="rich6.exe 定点逆向脚手架")
    ap.add_argument("cmd", choices=["info", "strs", "xref", "calls", "dis"])
    ap.add_argument("--n", type=int, default=80, help="dis 的指令条数")
    ap.add_argument("target", nargs="?",
                    help="xref 的目标：VA 写成 0x49xxxx；文件偏移写 off:0x9DF4C")
    ap.add_argument("--filter", "-f", default=None, help="strs 的关键词过滤")
    ap.add_argument("--exe", default=EXE)
    args = ap.parse_args()

    EXE = args.exe
    exe = EXE
    if not os.path.exists(exe):
        print(f"找不到原版 exe：{exe}\n（用 R6_EXE 环境变量或 --exe 指定）")
        return 2

    img = Image(exe)
    if args.cmd == "info":
        cmd_info(img)
    elif args.cmd == "strs":
        cmd_strs(img, args.filter)
    elif args.cmd == "xref":
        if not args.target:
            print("xref 需要目标 VA")
            return 2
        t = args.target
        if t.startswith("off:"):
            off = int(t[4:], 0)
            va = img.off_to_va(off)
            if va is None:
                print(f"文件偏移 {off:#x} 不在任何节里")
                return 2
            print(f"文件偏移 {off:#x} → VA {va:#x}（{img.section_of(va)}）")
            cmd_xref(img, va)
        else:
            cmd_xref(img, int(t, 0))
    elif args.cmd == "calls":
        cmd_calls(img)
    elif args.cmd == "dis":
        if not args.target:
            print("dis 需要起始 VA")
            return 2
        cmd_dis(img, int(args.target, 0), args.n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
