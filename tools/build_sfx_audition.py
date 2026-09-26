#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 `docs/sfx-audition.html` —— 152 个音效 / 18 首 BGM / 12 角色对白 / 卡片 / 宠物的**试听标注页**。

为什么要这一页：原版把「音效 id → 播放时机」编进了代码，数据层查不到；
探针法（标记音替换）能覆盖到"能跑到的事件"，但 152 个 id 里还有 120 多个
靠机器推不出语义 —— 需要人耳。这一页就是给人耳用的：

  * 顺序连播（空格暂停 / ↑↓ 切条），支持"只看待确认"（默认开启）
  * 每行一个「实际用途」输入框，自动存 localStorage
  * 一键导出 JSON（我拿到后回填 `game/data/rules/sfx.json` 并接线）

页面数据是**内联**的（file:// 下 fetch 会被 CORS 拦），素材用相对路径引 `../game/assets/audio/`。

预标注来源 = `game/data/rules/sfx.json`（人工 + 实测），**不是**写在本脚本里的，
所以回填后重跑本脚本，已确认的条目会自动从「待确认」里消失。

用法：
    python tools/build_sfx_audition.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VM = os.path.join(ROOT, "game", "assets", "audio", "voice_map.json")
SFX = os.path.join(ROOT, "game", "data", "rules", "sfx.json")
OUT = os.path.join(ROOT, "docs", "sfx-audition.html")


def load_effect_preset():
    """从 game/data/rules/sfx.json 读「音效 id → (用途, 置信度)」和两条否证说明。"""
    preset = {}
    disproved = {}
    if not os.path.exists(SFX):
        print("  ! 找不到 %s（预标注为空）" % SFX)
        return preset, disproved
    with open(SFX, encoding="utf-8") as fh:
        d = json.load(fh)
    for k, v in (d.get("effects") or {}).items():
        if isinstance(v, dict) and v.get("label"):
            preset[str(k)] = (str(v["label"]), str(v.get("conf", "人工")))
    disproved = {str(k): str(v) for k, v in (d.get("_disproved") or {}).items()}
    print("  预标注 %d 条音效（来自 %s）" % (len(preset), os.path.relpath(SFX, ROOT)))
    return preset, disproved


PRESET, DISPROVED = load_effect_preset()

# BGM 的实测归属（docs/sfx-map.md §7.2/§7.3）：菜单/大厅 m01001，对局 7 张图全是 m01009
BGM_PRESET = {
    "m01001": ("BGM·主菜单 / 大厅【实测】", "实测"),
    "m01009": ("BGM·对局（7 张地图全一样）【实测】", "实测"),
}

TEMPLATE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>大富翁6 音效试听标注台</title>
<style>
:root{
  --bg:#12141a; --panel:#1b1e26; --panel2:#22262f; --line:#2e3340;
  --fg:#e8eaf0; --dim:#9aa2b1; --accent:#e0b34a; --ok:#4bbf7a; --warn:#d98a3c; --bad:#c25a5a;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
  font:14px/1.6 "Microsoft YaHei","PingFang SC",system-ui,sans-serif}
header{position:sticky;top:0;z-index:20;background:linear-gradient(#1b1e26,#181b22);
  border-bottom:1px solid var(--line);padding:10px 16px}
h1{margin:0 0 6px;font-size:17px;letter-spacing:.5px}
h1 small{color:var(--dim);font-weight:400;font-size:12px;margin-left:8px}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
button{background:var(--panel2);color:var(--fg);border:1px solid var(--line);
  border-radius:6px;padding:5px 12px;cursor:pointer;font-size:13px}
button:hover{border-color:var(--accent)}
button.primary{background:var(--accent);color:#20180a;border-color:var(--accent);font-weight:600}
button.on{background:#2f4a38;border-color:var(--ok)}
input[type=text]{background:#0e1015;color:var(--fg);border:1px solid var(--line);
  border-radius:5px;padding:4px 8px;width:100%;font:13px/1.5 inherit}
input[type=text]:focus{outline:none;border-color:var(--accent)}
select{background:var(--panel2);color:var(--fg);border:1px solid var(--line);
  border-radius:6px;padding:5px 8px}
.now{color:var(--accent);font-weight:600}
.count{color:var(--dim);font-size:12px}
nav{display:flex;gap:4px;flex-wrap:wrap;margin-top:8px}
nav a{color:var(--dim);text-decoration:none;border:1px solid var(--line);
  border-radius:14px;padding:2px 12px;font-size:12px}
nav a:hover{color:var(--fg);border-color:var(--accent)}
main{padding:12px 16px 80px;max-width:1400px}
section{margin:22px 0 0}
section>h2{font-size:15px;margin:0 0 8px;padding-bottom:6px;border-bottom:1px solid var(--line);
  display:flex;align-items:center;gap:10px}
section>h2 .tag{font-size:11px;color:var(--dim);font-weight:400}
table{width:100%;border-collapse:collapse}
th,td{padding:5px 8px;border-bottom:1px solid #23262e;text-align:left;vertical-align:middle}
th{color:var(--dim);font-weight:400;font-size:12px;position:sticky;top:0;background:var(--bg)}
tr.row{cursor:pointer}
tr.row:hover{background:#1e222b}
tr.row.playing{background:#2a2415;box-shadow:inset 3px 0 0 var(--accent)}
td.id{font-family:Consolas,monospace;color:var(--dim);width:78px}
td.kind{width:52px}
td.dur{width:70px;color:var(--dim);font-family:Consolas,monospace}
td.play{width:38px}
td.say{width:44%;}
.badge{display:inline-block;border-radius:10px;padding:0 8px;font-size:11px;line-height:18px;
  border:1px solid;white-space:nowrap}
.b-实测{color:var(--ok);border-color:#2f4a38}
.b-人工{color:#7fb2ff;border-color:#2c3f5c}
.b-推断{color:var(--warn);border-color:#4a3c26}
.b-未知{color:var(--bad);border-color:#4a2c2c}
.pill{display:inline-block;background:#252932;border-radius:4px;padding:0 6px;
  font-size:11px;color:var(--dim);margin-left:6px}
.play-btn{background:transparent;border:none;color:var(--accent);font-size:15px;
  cursor:pointer;padding:0 4px}
.play-btn:hover{color:#fff}
footer{position:fixed;bottom:0;left:0;right:0;background:#181b22;border-top:1px solid var(--line);
  padding:8px 16px;display:flex;gap:12px;align-items:center;font-size:13px}
.progress{flex:1;height:6px;background:#252932;border-radius:3px;overflow:hidden}
.progress i{display:block;height:100%;background:var(--accent);width:0}
.hint{color:var(--dim);font-size:12px}
</style>
</head>
<body>
<header>
  <h1>大富翁6 音效试听标注台
    <small>共 <span id="total"></span> 条 · 点行即播 · 空格暂停 · ↑/↓ 切条 · 标注自动存本机</small></h1>
  <div class="bar">
    <button id="btn-seq" class="primary">▶ 顺序连播</button>
    <button id="btn-un" class="on">只看待确认</button>
    <button id="btn-stop">■ 停止</button>
    <select id="scope">
      <option value="all">全部</option>
      <option value="effect">音效（__N_EFFECT__）</option>
      <option value="music">BGM（__N_MUSIC__）</option>
      <option value="role">角色对白（__N_ROLE__）</option>
      <option value="card">卡片名（__N_CARD__）</option>
      <option value="pet">宠物（__N_PET__）</option>
    </select>
    <button id="btn-export" class="primary">⬇ 导出标注 JSON</button>
    <button id="btn-import">⬆ 导入标注 JSON</button>
    <input type="file" id="file" accept=".json" style="display:none">
    <span class="count">已标注 <b id="done">0</b></span>
  </div>
  <nav id="nav"></nav>
  <p class="hint" id="disproved"></p>
</header>

<main id="main"></main>

<footer>
  <span class="now" id="now">—</span>
  <div class="progress"><i id="bar"></i></div>
  <span class="hint" id="pos"></span>
</footer>

<script>
const VOICE_MAP = __VOICE_MAP__;
const PRESET = __PRESET__;
const BGM_PRESET = __BGM_PRESET__;
const DISPROVED = __DISPROVED__;
const ROOT = "../game/assets/audio/";

const el = id => document.getElementById(id);
const audio = new Audio();
audio.preload = "none";
let items = [];      // {key,label,src,sub,kind,dur,conf}
// 默认打开就把"还需要人耳确认的"挑出来，否则 617 条里 468 条是已知的，白听
let idx = -1, seq = false, onlyUn = true, scope = "all";

function build(){
  items = [];
  // 1. 音效
  const eff = VOICE_MAP.effects || {};
  Object.keys(eff).sort().forEach(k => {
    const e = eff[k];
    const p = PRESET[k] || ["", "未知"];
    items.push({ key:"effect/"+k, sec:"音效 effect/"+k+".wav", id:k,
      label:p[0], conf:p[1], kind:e.kind, dur:e.dur!=null?e.dur.toFixed(2)+"s":"",
      src:ROOT+"effect/"+k+".wav", input:"" });
  });
  // 2. BGM
  (VOICE_MAP.music||[]).forEach(t => {
    const bp = BGM_PRESET[t] || ["", "未知"];
    items.push({ key:"music/"+t, sec:"BGM "+t, id:t,
      label:bp[0], conf:bp[1], kind:"BGM", dur:"", src:ROOT+"music/"+t+".mp3", input:"" });
  });
  // 3. 角色对白
  (VOICE_MAP.roles||[]).forEach(r => {
    Object.keys(r.lines||{}).forEach(k => {
      const L = r.lines[k];
      items.push({ key:"role/"+r.dir+"/"+k, sec:"角色对白 · "+r.name+" ("+r.dir+")",
        id:r.name+" "+k.padStart(2,"0"), label:L.label, conf:"权威", kind:"对白", dur:"",
        src:ROOT+"voice/"+r.dir+"/"+(9+r.idx)*100+parseInt(k)+".wav", input:"" });
    });
  });
  // 4. 卡片名（默认用角色 1，可在表格里换角色）
  (VOICE_MAP.cards||[]).forEach(c => {
    items.push({ key:"card/"+c.num, sec:"卡片名 card/"+String(c.num).padStart(2,"0")+".wav",
      id:String(c.num).padStart(2,"0"), label:c.name+(c.reply?"（有『回』话）":""), conf:"权威",
      kind:"卡名", dur:"", src:ROOT+"voice/role1/card/"+String(c.num).padStart(2,"0")+".wav",
      input:"", cardNum:c.num });
  });
  // 5. 宠物
  (VOICE_MAP.pets||[]).forEach(p => {
    Object.keys(p.lines||{}).forEach(n => {
      items.push({ key:"pet/"+p.dir+"/"+n, sec:"宠物 · "+p.name+" ("+p.dir+")",
        id:String(n).padStart(2,"0"), label:p.lines[n], conf:"权威", kind:"宠物", dur:"",
        src:ROOT+"voice/pet/"+p.dir+"/"+String(n).padStart(2,"0")+".wav", input:"" });
    });
  });
}

const SAVED = JSON.parse(localStorage.getItem("r6sfx")||"{}");

function render(){
  const main = el("main");
  main.innerHTML = "";
  el("nav").innerHTML = "";
  const list = items.filter(keep);
  const header = document.createElement("div");
  header.className = "count";
  header.textContent = "当前范围 " + list.length + " 条"
    + (onlyUn ? "（只看待确认）" : "");
  main.appendChild(header);

  let curTable = null;
  list.forEach(it => {
    if(!curTable || curTable.dataset.sec !== it.sec){
      const a=document.createElement("a");
      a.href="javascript:void(0)"; a.textContent=it.sec;
      a.onclick=()=>{ const r=document.querySelector('[data-sec="'+CSS.escape(it.sec)+'"]');
        if(r) r.scrollIntoView({block:"start"}); };
      el("nav").appendChild(a);

      const h=document.createElement("h2");
      h.dataset.sec=it.sec;
      h.innerHTML = "<span>"+it.sec+"</span>";
      const all=document.createElement("button");
      all.textContent="▶ 本组连播"; all.className="play-btn";
      all.style.fontSize="12px";
      all.onclick=ev=>{ ev.stopPropagation();
        const grp=items.filter(x=>x.sec===it.sec);
        playFrom(items.indexOf(grp[0]), grp); };
      h.appendChild(all);
      main.appendChild(h);

      curTable = document.createElement("table");
      curTable.dataset.sec = it.sec;
      curTable.innerHTML = "<thead><tr><th>播放</th><th>id</th><th>类型</th><th>时长</th>"
        + "<th>我的标注 / 原版真相</th><th>你听到的实际用途（填这里）</th></tr></thead>";
      main.appendChild(curTable);
    }
    const tr = document.createElement("tr");
    tr.className="row"; tr.dataset.key=it.key; it.tr=tr;
    tr.innerHTML =
      '<td class="play"><button class="play-btn">▶</button></td>'
      +'<td class="id">'+it.id+'</td>'
      +'<td class="kind">'+(it.kind||"")+'</td>'
      +'<td class="dur">'+(it.dur||"")+'</td>'
      +'<td class="say"><span class="badge b-'+(it.conf||"未知")+'">'+(it.conf||"未知")+'</span>'
        + (it.label?('&nbsp;'+it.label):'') + '</td>'
      +'<td><input type="text" placeholder="听到什么就写什么，例如：骰子滚动 / 买地成功 / 破产"></td>';
    tr.querySelector("input").value = SAVED[it.key] || "";
    tr.querySelector("input").addEventListener("input", e=>{
      SAVED[it.key]=e.target.value; persist();
    });
    tr.onclick = e => { if(e.target.tagName!=="INPUT") playOne(items.indexOf(it)); };
    curTable.appendChild(tr);
  });
  updateCount();
}

// 范围 + 「只看待确认」的统一过滤
// "待确认" = 还没人工填过，且不是已经【权威】/【实测】/【人工】确定了用途的条目
function keep(it){
  if(onlyUn && ((SAVED[it.key]||"").trim()
      || it.conf==="权威" || it.conf==="实测" || it.conf==="人工")) return false;
  return byScope(it);
}
function byScope(it){
  return scope==="all" ? true
      : scope==="effect" ? it.key.startsWith("effect/")
      : scope==="music" ? it.key.startsWith("music/")
      : scope==="role" ? it.key.startsWith("role/")
      : scope==="card" ? it.key.startsWith("card/")
      : it.key.startsWith("pet/");
}
// 顺序连播只听范围，不管"有没有人工标注过"
function byScopeCur(it){ return byScope(it); }

function persist(){ localStorage.setItem("r6sfx", JSON.stringify(SAVED)); updateCount(); }
// 「已标注」= 人工输入过的 + 预标注里已经定了用途的（权威 / 实测 / 人工）
function updateCount(){
  const n = items.filter(it => (SAVED[it.key] && SAVED[it.key].trim())
      || it.conf==="权威" || it.conf==="实测" || it.conf==="人工").length;
  el("done").textContent = n; el("total").textContent = items.length;
}

function playOne(i){ setIdx(i); audio.src=items[i].src; audio.play().catch(()=>{}); }
function setIdx(i){
  if(items[idx] && items[idx].tr) items[idx].tr.classList.remove("playing");
  idx=i;
  const it=items[idx]; if(!it) return;
  if(it.tr){ it.tr.classList.add("playing");
    if(!it.tr.dataset.noscroll) it.tr.scrollIntoView({block:"center",behavior:"smooth"}); }
  el("now").textContent = it.sec + "  " + (it.label?("— "+it.label):"");
  el("pos").textContent = (idx+1)+" / "+items.length;
  el("bar").style.width = ((idx+1)/items.length*100).toFixed(1)+"%";
}
let queue=null;
function playFrom(start, list){
  queue = list || items; 
  const i = queue.findIndex(x=>x===items[start]);
  queue.pos = i<0?0:i; seq=true; el("btn-seq").classList.add("on"); step();
}
function step(){
  if(!queue){ queue=items; queue.pos=0; }
  if(queue.pos>=queue.length){ stop(); return; }
  const it=queue[queue.pos++];
  playOne(items.indexOf(it));
}
audio.onended = ()=>{ if(seq) setTimeout(step, 900); };

function stop(){ seq=false; audio.pause(); el("btn-seq").classList.remove("on"); }

el("btn-seq").onclick = ()=>{
  if(seq){ stop(); return; }
  const list = items.filter(byScopeCur);
  playFrom(items.indexOf(list[0]), list);
};
el("btn-stop").onclick = stop;
el("scope").onchange = e=>{ scope=e.target.value; render(); };
el("btn-un").onclick = e=>{ onlyUn=!onlyUn; e.target.classList.toggle("on",onlyUn); render(); };

el("btn-export").onclick = ()=>{
  const out = { _note:"大富翁6 音效标注（人工填写）", effect:{}, music:{}, role:{}, card:{}, pet:{} };
  items.forEach(it=>{
    const v=(SAVED[it.key]||"").trim(); if(!v) return;
    const p=it.key.split("/");
    if(p[0]==="effect") out.effect[p[1]]=v;
    else if(p[0]==="music") out.music[p[1]]=v;
    else if(p[0]==="role") out.role[p[1]+"/"+p[2]]=v;
    else if(p[0]==="card") out.card[p[1]]=v;
    else if(p[0]==="pet") out.pet[p[1]+"/"+p[2]]=v;
  });
  const blob=new Blob([JSON.stringify(out,null,1)],{type:"application/json"});
  const a=document.createElement("a");
  a.href=URL.createObjectURL(blob); a.download="r6-sfx-labels.json"; a.click();
};
el("btn-import").onclick = ()=>el("file").click();
el("file").onchange = ev=>{
  const f=ev.target.files[0]; if(!f) return;
  const r=new FileReader();
  r.onload=()=>{ try{
    const d=JSON.parse(r.result);
    Object.entries(d.effect||{}).forEach(([k,v])=>SAVED["effect/"+k]=v);
    Object.entries(d.music||{}).forEach(([k,v])=>SAVED["music/"+k]=v);
    Object.entries(d.role||{}).forEach(([k,v])=>SAVED["role/"+k]=v);
    Object.entries(d.card||{}).forEach(([k,v])=>SAVED["card/"+k]=v);
    Object.entries(d.pet||{}).forEach(([k,v])=>SAVED["pet/"+k]=v);
    persist(); render();
  }catch(e){ alert("JSON 解析失败："+e); } };
  r.readAsText(f);
};
document.addEventListener("keydown", e=>{
  if(e.target.tagName==="INPUT") return;
  if(e.code==="Space"){ e.preventDefault(); audio.paused?audio.play():audio.pause(); }
  else if(e.code==="ArrowDown"){ e.preventDefault();
    const l=items.filter(byScopeCur); const i=l.findIndex(x=>x===items[idx]);
    playOne(items.indexOf(l[Math.min(l.length-1,i+1)])); }
  else if(e.code==="ArrowUp"){ e.preventDefault();
    const l=items.filter(byScopeCur); const i=l.findIndex(x=>x===items[idx]);
    playOne(items.indexOf(l[Math.max(0,i-1)])); }
});

build(); render();

// 已经把「曾被自动推断、后被老板试听否证」的条目摘出来了 —— 写在页面上提醒别再用
(function(){
  const keys = Object.keys(DISPROVED);
  if(!keys.length) return;
  const box = el("disproved");
  box.innerHTML = "⚠️ 已否证的自动推断（不要再当线索）："
    + keys.map(k => "「"+k+"」").join("、");
  box.title = keys.map(k => k+" —— "+DISPROVED[k]).join("\n\n");
})();
</script>
</body>
</html>
"""


def scoped_list(items, scope):
    return items


def main():
    vm = json.load(open(VM, encoding="utf-8"))
    n_eff = len(vm.get("effects", {}))
    n_mus = len(vm.get("music", []))
    n_role = sum(len(r.get("lines", {})) for r in vm.get("roles", []))
    n_card = len(vm.get("cards", []))
    n_pet = sum(len(p.get("lines", {})) for p in vm.get("pets", []))
    html = (TEMPLATE
            .replace("__VOICE_MAP__", json.dumps(vm, ensure_ascii=False))
            .replace("__PRESET__", json.dumps(PRESET, ensure_ascii=False))
            .replace("__BGM_PRESET__", json.dumps(BGM_PRESET, ensure_ascii=False))
            .replace("__DISPROVED__", json.dumps(DISPROVED, ensure_ascii=False))
            .replace("__N_EFFECT__", str(n_eff))
            .replace("__N_MUSIC__", str(n_mus))
            .replace("__N_ROLE__", str(n_role))
            .replace("__N_CARD__", str(n_card))
            .replace("__N_PET__", str(n_pet)))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    n = n_eff + n_mus + n_role + n_card + n_pet
    print(f"已生成 {OUT}")
    print(f"  条目总数 {n}（音效 {n_eff} / BGM {n_mus}"
          f" / 对白 {n_role} / 卡片 {n_card} / 宠物 {n_pet}）")
    print(f"  文件大小 {os.path.getsize(OUT)/1024:.0f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
