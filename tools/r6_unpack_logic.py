# -*- coding: utf-8 -*-
"""
r6_unpack_logic.py —— 把《大富翁6》资源包里的「逻辑向」资产解成人类可读形式并**另存**，
供以后逐条对照（老板 2026-09-26 要求：「解包一下逻辑的部分……另存到文件中方便对照」）。

分类与处理
----------
  文本类  .txt .gbf .ani .gst .tst
      → 自动判编码（UTF-8 / GBK），另存为 **UTF-8**，目录结构照搬。
        · .gbf  = DirectX8 风格的渲染状态脚本（纯文本）
        · .tst  = 逐张贴图的采样设置（goal / wrap_u / wrap_v / mipmap / detail / div_w / div_h）
        · .ani  = 动画脚本（纯文本）
        · .gst  = 材质/混合状态（纯文本）
  二进制类  .gae .par .r6s .r6m .tft .a_q .cvd .cvdf .ion .pol .max
      → 写一份 `<name>.dump.txt`：识别的 magic / 头部字段 / 可提取字符串
        （ASCII 串 + UTF-16LE 串）/ 头部 hexdump。**不改动原文件**。

产物
----
  docs/orig-logic/<原相对路径>            文本类（UTF-8）
  docs/orig-logic/<原相对路径>.dump.txt   二进制类
  docs/orig-logic/INDEX.md                人读索引（按类别分组）
  docs/orig-logic/index.json              机读索引（来源 / 大小 / 类型 / 编码 / magic / 摘要 / .tst 键值）

用法
----
  python tools/r6_unpack_logic.py                  # 全量（文本 + 二进制）
  python tools/r6_unpack_logic.py --text-only      # 只要文本类
  python tools/r6_unpack_logic.py --ext .tst .gbf  # 只要指定扩展名
  python tools/r6_unpack_logic.py --list           # 只列清单，不落盘
  python tools/r6_unpack_logic.py --src samples --out docs/orig-logic
"""

import argparse
import json
import os
import re
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEXT_EXT = {".txt", ".gbf", ".ani", ".gst", ".tst"}
# 默认处理：结构/参数类二进制（真正的「逻辑」）
BIN_EXT = {".gae", ".par", ".tft", ".r6s", ".r6m", ".r6s_", ".ion"}
# 美术向（体积大或已有专用解析器）→ 只在 --all 时处理
ART_EXT = {".pol", ".max", ".a_q", ".cvd", ".cvdf"}

# 认识的 magic（前 4 字节 → 说明）
MAGIC = {
    b"R6HS": ("R6HS", "3D 网格（地形/建筑），见 tools/r6pol.py"),
    b"R6SM": ("R6SM", "场景网格/地形块"),
    b"R6MP": ("R6MP", "地图数据（棋盘/相机/灯光，见 docs/original-visual-reference.md 附录 A）"),
    b"IDP2": ("IDP2", "角色骨骼网格（tris.a_q）"),
    b"cvdf": ("cvdf", "角色/物体动画曲线"),
    b"TNFT": ("TNFT", "点阵字体表"),
    b"sgpar": ("sgpar", "粒子系统参数"),
    b"\xd0\xcf\x11\xe0": ("OLE2", "复合文档（.max = 3ds Max 源文件）"),
}

HEX_CAP = 256          # 头部 hexdump 上限（字节）
STR_CAP = 400          # 单文件最多抽多少条字符串
BIG = 512 * 1024       # 超过这个大小就不再逐字节扫字符串（只取头部）

# 跨文件「引用」提取（binary dump 之外单独聚合，见 refs.md）
REFS = [
    ("音效 id", re.compile(rb"EFFECT[\\/](\d{1,3})\.wav", re.I)),
    ("引用的源文件", re.compile(rb"[A-Za-z0-9_\-]{1,24}\.(?:cvd|gae|par|tga|wav)", re.I)),
    ("原开发机路径", re.compile(rb"[A-Za-z]:\\[^\x00\r\n]{4,140}")),
]


# ------------------------------------------------------------------ 基础

def read_bytes(p):
    with open(p, "rb") as f:
        return f.read()


def decode_text(b):
    """返回 (文本, 编码名)。优先 UTF-8，失败退 GBK。"""
    for enc in ("utf-8", "gbk", "latin1"):
        try:
            return b.decode(enc), enc
        except UnicodeDecodeError:
            continue
    return b.decode("latin1", "replace"), "latin1"


def detect_magic(b):
    for mg, (name, desc) in MAGIC.items():
        if b[:len(mg)] == mg:
            return name, desc
    return "", ""


def _useful_ascii(s):
    """过滤二进制噪声：要求足够长且字母数字占比够。"""
    if len(s) < 4:
        return False
    alnum = sum(1 for c in s if c.isalnum())
    return alnum >= 3


def _useful_utf16(s):
    """过滤「可打印 ASCII 表」伪串：UTF-16 真串要么含非 ASCII（中文），要么短。"""
    return (any(ord(c) > 127 for c in s)) or len(s) <= 30


def extract_strings(b, cap=STR_CAP):
    """抽 ASCII 串与 UTF-16LE 串（各自 >= 4 个可打印字符），带噪声过滤。"""
    out = []
    lim = b[: BIG] if len(b) > BIG else b
    for m in re.finditer(rb"[\x20-\x7e]{4,}", lim):
        s = m.group().decode("ascii", "replace")
        if _useful_ascii(s):
            out.append(("ascii", m.start(), s))
        if len(out) >= cap:
            return out
    for m in re.finditer(rb"(?:[\x20-\x7e]\x00){4,}", lim):
        s = m.group().decode("utf-16-le", "replace")
        if _useful_utf16(s):
            out.append(("utf16le", m.start(), s))
        if len(out) >= cap:
            break
    return out


def hexdump(b, n=HEX_CAP):
    lines = []
    for i in range(0, min(len(b), n), 16):
        chunk = b[i:i + 16]
        hx = " ".join("%02x" % c for c in chunk)
        asc = "".join(chr(c) if 32 <= c < 127 else "." for c in chunk)
        lines.append("  %06x  %-47s  |%s|" % (i, hx, asc))
    if len(b) > n:
        lines.append("  ... 共 %d 字节，其余省略" % len(b))
    return "\n".join(lines)


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0] if o + 4 <= len(b) else None


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0] if o + 4 <= len(b) else None


# ------------------------------------------------------------------ 各格式头部

def header_fields(ext, b):
    """按已知格式解出头部关键字段，返回 [(名字, 值)]。解不出的返回 []。"""
    f = []
    if ext in (".r6s", ".r6m") and len(b) >= 8:
        f.append(("版本", u32(b, 4)))
        if ext == ".r6s" and len(b) >= 24:
            f.append(("对象名", b[16:24].split(b"\0")[0].decode("latin1", "replace")))
    elif ext == ".tft" and len(b) >= 12:
        f.append(("版本", u32(b, 4)))
        f.append(("字高", u32(b, 8)))
    elif ext == ".a_q" and len(b) >= 8:
        f.append(("版本", u32(b, 4)))
    elif ext == ".gae" and len(b) >= 16:
        # 头部：u32 版本 / f32 常量 / u32 未定 / u32 未定，随后是 NUL 结尾的节点名表（首项 "root"）
        f.append(("版本", u32(b, 0)))
        f.append(("f32@4", f32(b, 4)))
        f.append(("u32@8（未定）", u32(b, 8)))
        f.append(("u32@12（未定）", u32(b, 12)))
        f.append(("首节点名", b[16:64].split(b"\0")[0].decode("latin1", "replace")))
    elif ext == ".par" and len(b) >= 12:
        f.append(("版本", u32(b, 4)))
    elif ext == ".ion":
        f.append(("内容", "0 字节（占位文件）"))
    return f


def tst_pairs(text):
    """解析 .tst 的 [key] = [val] 键值。"""
    d = {}
    for m in re.finditer(r"\[([^\]]+)\]\s*=\s*\[([^\]]*)\]", text):
        d[m.group(1).strip()] = m.group(2).strip()
    return d


# ------------------------------------------------------------------ 摘要

def first_meaningful_line(text):
    for ln in text.splitlines():
        s = ln.strip()
        if s and not s.startswith("//"):
            return s[:110]
    for ln in text.splitlines():
        s = ln.strip()
        if s:
            return s[:110]
    return ""


# ------------------------------------------------------------------ 主流程

def collect(src, exts):
    hits = []
    for dp, dn, fn in os.walk(src):
        for f in fn:
            e = os.path.splitext(f)[1].lower()
            if e in exts:
                hits.append(os.path.join(dp, f))
    hits.sort()
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "samples"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "orig-logic"))
    ap.add_argument("--ext", nargs="*", default=None)
    ap.add_argument("--text-only", action="store_true")
    ap.add_argument("--all", action="store_true", help="连美术向的大件（.pol/.max/.a_q/.cvd/.cvdf）一起 dump")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    src = os.path.abspath(a.src)
    out = os.path.abspath(a.out)
    if a.ext:
        exts = {e if e.startswith(".") else "." + e for e in a.ext}
    elif a.text_only:
        exts = set(TEXT_EXT)
    elif a.all:
        exts = set(TEXT_EXT) | set(BIN_EXT) | set(ART_EXT)
    else:
        exts = set(TEXT_EXT) | set(BIN_EXT)

    # ⚠️ 过滤运行（--ext/--text-only）不得覆盖全量索引 → 索引文件名带后缀
    tag = ""
    if a.ext or a.text_only:
        tag = "__" + "_".join(sorted(e.lstrip(".") for e in exts))

    files = collect(src, exts)
    print("[logic] 源 %s  匹配 %d 个文件（%d 类扩展名）%s"
          % (src, len(files), len(exts), ("  索引后缀 %s" % tag) if tag else ""))
    if a.list:
        for p in files:
            print("  %-56s %9d B" % (os.path.relpath(p, src).replace("\\", "/"),
                                     os.path.getsize(p)))
        return

    os.makedirs(out, exist_ok=True)
    index = []
    refs = {name: {} for name, _ in REFS}   # name -> {值: set(来源)}
    n_text = n_bin = n_skip = 0

    for p in files:
        rel = os.path.relpath(p, src).replace("\\", "/")
        ext = os.path.splitext(p)[1].lower()
        size = os.path.getsize(p)
        b = read_bytes(p)
        magic, magic_desc = detect_magic(b)

        if ext in TEXT_EXT:
            text, enc = decode_text(b)
            dst = os.path.join(out, rel.replace("/", os.sep))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w", encoding="utf-8", newline="") as f:
                f.write(text)
            entry = {
                "src": rel, "out": os.path.relpath(dst, out).replace("\\", "/"),
                "kind": "text", "ext": ext, "bytes": size, "encoding": enc,
                "lines": text.count("\n") + 1,
                "summary": first_meaningful_line(text),
            }
            if ext == ".tst":
                entry["tst"] = tst_pairs(text)
            index.append(entry)
            n_text += 1
        else:
            # ---- 跨文件引用（对原始字节扫，不做截断）----
            for rname, rx in REFS:
                for m in rx.finditer(b):
                    if m.groups():
                        v = m.group(1).decode("latin1", "replace")
                    else:
                        v = m.group(0).decode("latin1", "replace")
                    refs[rname].setdefault(v, set()).add(rel)

            strs = extract_strings(b)
            dst = os.path.join(out, (rel + ".dump.txt").replace("/", os.sep))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w", encoding="utf-8", newline="") as f:
                f.write("# %s\n" % rel)
                f.write("# 大小 %d 字节   magic=%s\n\n" % (size, magic or "(未识别)"))
                if magic_desc:
                    f.write("## magic 说明\n%s\n\n" % magic_desc)
                hf = header_fields(ext, b)
                if hf:
                    f.write("## 头部字段（已解的）\n")
                    for k, v in hf:
                        f.write("  %-10s %s\n" % (k, v))
                    f.write("\n")
                f.write("## 头部 hexdump\n%s\n\n" % hexdump(b))
                f.write("## 可提取字符串（%d 条，%s 截断）\n" % (len(strs), "有" if len(strs) >= STR_CAP else "无"))
                seen = set()
                for kind, off, s in strs:
                    key = (kind, s)
                    if key in seen:
                        continue
                    seen.add(key)
                    f.write("  %-8s @%08x  %s\n" % (kind, off, s))
            entry = {
                "src": rel, "out": os.path.relpath(dst, out).replace("\\", "/"),
                "kind": "binary", "ext": ext, "bytes": size,
                "magic": magic, "magic_desc": magic_desc,
                "strings": len(strs),
                "summary": (strs[0][2][:110] if strs else ""),
            }
            index.append(entry)
            n_bin += 1

    # ---- 索引 ----
    refs_out = {k: {v: sorted(s) for v, s in sorted(d.items())} for k, d in refs.items()}
    with open(os.path.join(out, "index%s.json" % tag), "w", encoding="utf-8") as f:
        json.dump({"count": len(index), "entries": index, "refs": refs_out}, f,
                  ensure_ascii=False, indent=1)

    # ---- 跨文件引用表 ----
    rl = ["# 原版逻辑资产 · 跨文件引用表", "",
          "由 `tools/r6_unpack_logic.py` 从二进制 dump 的原始字节里聚合出来。", ""]
    for rname, d in refs.items():
        rl.append("## %s（%d 种）" % (rname, len(d)))
        rl.append("")
        if not d:
            rl.append("（无）")
            rl.append("")
            continue
        rl.append("| 值 | 出现于 |")
        rl.append("|----|--------|")
        for v, srcs in sorted(d.items()):
            rl.append("| `%s` | %s |" % (v, ", ".join("`%s`" % s for s in srcs)))
        rl.append("")
    with open(os.path.join(out, "refs%s.md" % tag), "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(rl))

    lines = ["# 原版「逻辑」资产解包索引", "",
             "由 `tools/r6_unpack_logic.py` 生成。**只读产物，勿手改**；重跑即覆盖。", "",
             "- 文本类 → 原样另存为 UTF-8（目录结构照搬）",
             "- 二进制类 → `<原路径>.dump.txt`（magic / 头部字段 / 字符串 / 头部 hexdump）",
             "- 跨文件引用（音效 id / 源文件 / 开发机路径）→ `refs.md` + `index.json`",
             "- 人工整理的结论与「还原出的细节」→ 见同目录 **`FINDINGS.md`**", "",
             "统计：文本 %d，二进制 %d，合计 %d。" % (n_text, n_bin, len(index))]
    if tag:
        lines.insert(3, "> ⚠️ 这是按扩展名过滤的**子集索引**，全量见 `INDEX.md`。\n")
    lines.append("")
    for kind, title in (("text", "一、文本类（可直接读）"), ("binary", "二、二进制类（dump）")):
        lines.append("## %s" % title)
        lines.append("")
        lines.append("| 来源 | 类型 | 大小 | 产物 | 摘要 |")
        lines.append("|------|------|------|------|------|")
        for e in index:
            if e["kind"] != kind:
                continue
            extra = ""
            if e.get("tst"):
                z = e["tst"]
                extra = "goal=%s wrap=%s/%s div=%sx%s" % (
                    z.get("goal", "?"), z.get("wrap_u", "?"), z.get("wrap_v", "?"),
                    z.get("div_w", "?"), z.get("div_h", "?"))
            elif e.get("magic"):
                extra = e["magic"]
            s = (e["summary"] or "").replace("|", "/")[:70]
            if extra:
                s = ("%s · %s" % (extra, s))[:100]
            lines.append("| `%s` | `%s` | %.1f KB | `%s` | %s |"
                         % (e["src"], e["ext"], e["bytes"] / 1024.0, e["out"], s))
        lines.append("")
    with open(os.path.join(out, "INDEX%s.md" % tag), "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))

    print("[logic] 文本 %d / 二进制 %d → %s" % (n_text, n_bin, out))
    print("[logic] 索引 %s 与 %s"
          % (os.path.join(out, "INDEX%s.md" % tag), os.path.join(out, "index%s.json" % tag)))
    for rname, d in refs.items():
        print("[logic] 引用「%s」%d 种 → refs%s.md" % (rname, len(d), tag))


if __name__ == "__main__":
    main()
