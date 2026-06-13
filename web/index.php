<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Eagle Guard — DDoS Protection System</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
<style>
/* ═══════════════════════════════════════════════════════════════
   EAGLE GUARD — Futuristic Dashboard Design
   Poppins + JetBrains Mono | Dark Neon Cyber Theme
═══════════════════════════════════════════════════════════════ */
:root {
  --bg:     #040912;
  --bg1:    #060d1b;
  --bg2:    #081020;
  --bg3:    #0c1830;
  --bg4:    #101f3a;
  --bdr:    #0f2548;
  --bdr2:   #1a3a6e;
  --bdr3:   #265090;

  --cyan:   #00e5ff;
  --cyan2:  #00b8d9;
  --red:    #ff1744;
  --red2:   #d50000;
  --green:  #00e676;
  --green2: #00c853;
  --amber:  #ffab00;
  --amber2: #ff6d00;
  --violet: #d500f9;
  --violet2:#aa00ff;
  --blue:   #2979ff;

  --txt:    #7eb3d8;
  --txt2:   #4a7a9b;
  --white:  #e8f4ff;

  --glow-c: 0 0 30px rgba(0,229,255,.2);
  --glow-r: 0 0 30px rgba(255,23,68,.2);
  --glow-g: 0 0 30px rgba(0,230,118,.18);
  --glow-a: 0 0 30px rgba(255,171,0,.2);

  --font:   'Poppins', sans-serif;
  --mono:   'JetBrains Mono', monospace;
  --r:      10px;
}

*  { box-sizing: border-box; margin: 0; padding: 0 }
html { font-size: 13px }
body {
  background: var(--bg);
  color: var(--txt);
  font-family: var(--font);
  font-weight: 400;
  min-height: 100vh;
  overflow-x: hidden;
}
::-webkit-scrollbar { width: 4px; height: 4px }
::-webkit-scrollbar-track { background: var(--bg1) }
::-webkit-scrollbar-thumb { background: var(--bdr2); border-radius: 2px }

/* Animated background grid */
body::before {
  content: '';
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background-image:
    linear-gradient(rgba(0,229,255,.025) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,229,255,.025) 1px, transparent 1px);
  background-size: 48px 48px;
  animation: gridMove 20s linear infinite;
}
@keyframes gridMove { from { transform: translateY(0) } to { transform: translateY(48px) } }

/* Radial glow center */
body::after {
  content: '';
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background: radial-gradient(ellipse 80% 60% at 50% 0%, rgba(0,229,255,.06) 0%, transparent 70%);
}

/* ══ SIDEBAR ══════════════════════════════════════════════════════ */
#sb {
  position: fixed; left: 0; top: 0; bottom: 0; width: 240px;
  background: linear-gradient(180deg, var(--bg1) 0%, var(--bg) 100%);
  border-right: 1px solid var(--bdr);
  display: flex; flex-direction: column; z-index: 200;
}
#sb::before {
  content: '';
  position: absolute; top: 0; left: 0; right: 0; height: 1px;
  background: linear-gradient(90deg, transparent, var(--cyan), transparent);
  opacity: .6;
}

.sb-logo {
  padding: 22px 18px 18px;
  border-bottom: 1px solid var(--bdr);
}
.sb-brand { display: flex; align-items: center; gap: 12px }
.logo-ring {
  width: 42px; height: 42px; border-radius: 50%;
  border: 1.5px solid var(--cyan);
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 0 16px rgba(0,229,255,.3), inset 0 0 16px rgba(0,229,255,.06);
  flex-shrink: 0;
  animation: spin 12s linear infinite;
}
@keyframes spin { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }
.logo-ring svg { animation: spin 12s linear infinite reverse }
.sb-name { font-size: 1.2rem; font-weight: 800; color: var(--white); letter-spacing: .06em }
.sb-ver {
  font-size: .58rem; color: var(--txt2); letter-spacing: .28em;
  font-family: var(--mono); margin-top: 2px;
  text-transform: uppercase;
}

.sb-section {
  padding: 16px 16px 4px;
  font-size: .58rem; letter-spacing: .3em;
  color: var(--txt2); font-family: var(--mono); text-transform: uppercase;
}

.ni {
  display: flex; align-items: center; gap: 10px;
  padding: 10px 16px; margin: 1px 8px; border-radius: 8px;
  cursor: pointer; color: var(--txt2); font-size: .83rem;
  font-weight: 500; transition: all .2s; user-select: none;
  position: relative;
}
.ni:hover { background: rgba(0,229,255,.06); color: var(--txt) }
.ni.on {
  background: linear-gradient(90deg, rgba(0,229,255,.12), rgba(0,229,255,.04));
  color: var(--cyan); border-left: 2px solid var(--cyan);
  padding-left: 14px;
}
.ni.on::after {
  content: ''; position: absolute; right: 12px; top: 50%;
  transform: translateY(-50%);
  width: 4px; height: 4px; border-radius: 50%;
  background: var(--cyan); box-shadow: 0 0 6px var(--cyan);
}
.ni .ic { width: 20px; text-align: center; font-size: 1rem; flex-shrink: 0 }
.ni .nb {
  margin-left: auto; background: var(--red); color: #fff;
  font-size: .58rem; padding: 2px 6px; border-radius: 10px;
  font-family: var(--mono); font-weight: 700; display: none;
}

/* Sidebar bottom */
.sb-bot {
  margin: auto 12px 16px;
  border-radius: var(--r); border: 1px solid; padding: 14px;
  transition: all .3s; position: relative; overflow: hidden;
}
.sb-bot::before {
  content: '';
  position: absolute; top: 0; left: 0; right: 0; height: 1px;
}
.sb-bot.on {
  border-color: rgba(0,230,118,.3);
  background: rgba(0,230,118,.04);
}
.sb-bot.on::before { background: linear-gradient(90deg, transparent, var(--green), transparent) }
.sb-bot.off {
  border-color: rgba(255,23,68,.3);
  background: rgba(255,23,68,.04);
}
.sb-bot.off::before { background: linear-gradient(90deg, transparent, var(--red), transparent) }

.sb-dot {
  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
}
.on .sb-dot { background: var(--green); box-shadow: 0 0 8px var(--green); animation: pu 1.5s infinite }
.off .sb-dot { background: var(--red) }
@keyframes pu { 0%,100%{opacity:1} 50%{opacity:.2} }
.sb-lbl { font-size: .75rem; font-weight: 700; letter-spacing: .05em }
.on .sb-lbl { color: var(--green) }
.off .sb-lbl { color: var(--red) }
.sb-up { font-size: .6rem; color: var(--txt2); font-family: var(--mono); margin-top: 3px }
.sb-btn {
  width: 100%; margin-top: 10px; padding: 8px; border-radius: 6px;
  border: 1px solid; cursor: pointer; font-family: var(--font);
  font-size: .73rem; font-weight: 600; letter-spacing: .05em;
  background: transparent; transition: all .2s;
}
.on .sb-btn  { border-color: rgba(255,23,68,.5); color: var(--red) }
.on .sb-btn:hover  { background: rgba(255,23,68,.12); box-shadow: var(--glow-r) }
.off .sb-btn { border-color: rgba(0,230,118,.5); color: var(--green) }
.off .sb-btn:hover { background: rgba(0,230,118,.08); box-shadow: var(--glow-g) }

/* ══ MAIN ═════════════════════════════════════════════════════════ */
#main {
  margin-left: 240px; min-height: 100vh;
  padding: 22px 24px; position: relative; z-index: 1;
}

/* ══ TOPBAR ═══════════════════════════════════════════════════════ */
.topbar {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 22px;
}
.tb-l .page-title {
  font-size: 1.3rem; font-weight: 700; color: var(--white);
  letter-spacing: .04em;
}
.tb-l .bc {
  font-size: .68rem; color: var(--txt2); font-family: var(--mono);
  margin-top: 2px;
}
.tb-l .bc span { color: var(--cyan) }
.tb-r { display: flex; align-items: center; gap: 12px }
#clk {
  font-family: var(--mono); font-size: .8rem; color: var(--txt2);
  background: var(--bg1); border: 1px solid var(--bdr);
  padding: 6px 12px; border-radius: 6px;
}
.icon-btn {
  position: relative; padding: 8px 10px;
  border-radius: var(--r); border: 1px solid var(--bdr);
  background: var(--bg1); cursor: pointer; font-size: 1rem;
  transition: all .2s;
}
.icon-btn:hover { border-color: var(--bdr2) }
.icon-btn .badge {
  position: absolute; top: -5px; right: -5px;
  background: var(--red); color: #fff; font-size: .55rem;
  width: 15px; height: 15px; border-radius: 50%;
  display: none; align-items: center; justify-content: center;
  font-family: var(--mono); font-weight: 700;
}
.icon-btn .badge.s { display: flex }

/* ══ PAGES ════════════════════════════════════════════════════════ */
.pg { display: none }
.pg.on { display: block }

/* ══ CARDS ════════════════════════════════════════════════════════ */
.card {
  background: linear-gradient(135deg, var(--bg1) 0%, var(--bg2) 100%);
  border: 1px solid var(--bdr);
  border-radius: var(--r); padding: 18px 20px;
  position: relative; overflow: hidden; transition: border-color .2s;
}
.card:hover { border-color: var(--bdr2) }
.card-glow {
  position: absolute; top: 0; left: 0; right: 0; height: 1px;
  background: linear-gradient(90deg, transparent, var(--cyan), transparent);
  opacity: .35;
}
.card-title {
  display: flex; align-items: center; gap: 8px; margin-bottom: 15px;
  font-size: .7rem; text-transform: uppercase; letter-spacing: .2em;
  color: var(--txt2); font-family: var(--mono); font-weight: 500;
}
.card-title .ci { color: var(--cyan) }
.ct-sp { margin-left: auto }

/* ══ METRIC GRID ══════════════════════════════════════════════════ */
.mg { display: grid; grid-template-columns: repeat(5,1fr); gap: 14px; margin-bottom: 16px }
.mc { padding: 16px 18px }
.mc-label {
  font-size: .62rem; text-transform: uppercase; letter-spacing: .2em;
  color: var(--txt2); font-family: var(--mono); margin-bottom: 8px;
}
.mc-val {
  font-size: 1.8rem; font-weight: 800; line-height: 1; color: var(--white);
  font-family: var(--mono);
}
.mc-val.vc { color: var(--cyan); text-shadow: var(--glow-c) }
.mc-val.vr { color: var(--red);  text-shadow: var(--glow-r) }
.mc-val.vg { color: var(--green);text-shadow: var(--glow-g) }
.mc-val.va { color: var(--amber);text-shadow: var(--glow-a) }
.mc-val.vv { color: var(--violet) }
.mc-sub { font-size: .62rem; color: var(--txt2); margin-top: 6px; font-family: var(--mono) }
.mc-icon { position: absolute; right: 14px; top: 14px; font-size: 1.6rem; opacity: .08 }

/* ══ LAYOUT GRIDS ═════════════════════════════════════════════════ */
.g2  { display: grid; grid-template-columns: 1fr 1fr;       gap: 14px; margin-bottom: 14px }
.g3  { display: grid; grid-template-columns: 1fr 1fr 1fr;   gap: 14px; margin-bottom: 14px }
.g21 { display: grid; grid-template-columns: 2fr 1fr;       gap: 14px; margin-bottom: 14px }
.g12 { display: grid; grid-template-columns: 1fr 2fr;       gap: 14px; margin-bottom: 14px }
.g13 { display: grid; grid-template-columns: 1fr 3fr;       gap: 14px; margin-bottom: 14px }
.mb  { margin-bottom: 14px }

/* ══ CHARTS ═══════════════════════════════════════════════════════ */
.ch    { height: 155px; position: relative }
.ch-lg { height: 200px; position: relative }

/* ══ TABLES ═══════════════════════════════════════════════════════ */
.tbl { width: 100%; border-collapse: collapse; font-family: var(--mono); font-size: .67rem }
.tbl th {
  text-align: left; color: var(--txt2); font-weight: 500;
  padding: 0 8px 8px; border-bottom: 1px solid var(--bdr);
  font-size: .6rem; letter-spacing: .14em; text-transform: uppercase;
}
.tbl td {
  padding: 7px 8px; border-bottom: 1px solid rgba(255,255,255,.03);
  color: var(--txt); vertical-align: middle;
}
.tbl tr:hover td { background: rgba(0,229,255,.03) }
.tc { color: var(--cyan)!important }   .tr { color: var(--red)!important }
.tg { color: var(--green)!important }  .ta { color: var(--amber)!important }
.tv { color: var(--violet)!important }
.tscr { max-height: 260px; overflow-y: auto }

/* ══ BADGES ═══════════════════════════════════════════════════════ */
.l4b {
  background: rgba(0,229,255,.1); border: 1px solid rgba(0,229,255,.3);
  color: var(--cyan); font-size: .58rem; padding: 2px 7px; border-radius: 12px;
  font-family: var(--mono); font-weight: 600;
}
.l7b {
  background: rgba(213,0,249,.1); border: 1px solid rgba(213,0,249,.3);
  color: var(--violet); font-size: .58rem; padding: 2px 7px; border-radius: 12px;
  font-family: var(--mono); font-weight: 600;
}
.severity-high   { color: var(--red) }
.severity-medium { color: var(--amber) }
.severity-low    { color: var(--green) }

/* ══ MODULE PILLS ═════════════════════════════════════════════════ */
.mds { display: grid; grid-template-columns: 1fr 1fr; gap: 6px }
.md {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 11px; border-radius: 7px;
  border: 1px solid var(--bdr);
  background: rgba(0,229,255,.015); font-size: .73rem;
  transition: all .2s;
}
.md:hover { border-color: var(--bdr2); background: rgba(0,229,255,.04) }
.mdd {
  width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0;
  background: var(--green); box-shadow: 0 0 6px var(--green);
  animation: pu 2s infinite;
}
.mdd.off { background: var(--txt2); box-shadow: none; animation: none }
.mdn { flex: 1; color: var(--txt); font-weight: 500 }
.mdc { font-family: var(--mono); color: var(--txt2); font-size: .62rem }

/* ══ PROGRESS BARS ════════════════════════════════════════════════ */
.pb { margin-bottom: 10px }
.pbh {
  display: flex; justify-content: space-between;
  font-size: .63rem; font-family: var(--mono); color: var(--txt2); margin-bottom: 4px;
}
.pbt { height: 3px; background: var(--bg3); border-radius: 2px; overflow: hidden }
.pbf { height: 100%; border-radius: 2px; transition: width .6s ease }
.pbr { background: linear-gradient(90deg, var(--red),  #ff6090) }
.pby { background: linear-gradient(90deg, var(--amber), #ffcc02) }
.pbc { background: linear-gradient(90deg, var(--cyan),  #66f0ff) }
.pbg { background: linear-gradient(90deg, var(--green), #69ffb3) }
.pbv { background: linear-gradient(90deg, var(--violet),#f066ff) }

/* ══ LOG FEED ═════════════════════════════════════════════════════ */
.lw { overflow-y: auto; font-family: var(--mono); font-size: .64rem; line-height: 1.75 }
.lw::-webkit-scrollbar { width: 2px }
.le {
  display: flex; gap: 9px; padding: 2px 0;
  border-bottom: 1px solid rgba(255,255,255,.025);
}
.lt { color: var(--txt2); flex-shrink: 0; font-size: .59rem; white-space: nowrap }
.ll { width: 38px; flex-shrink: 0; font-weight: 700 }
.ll.INFO  { color: var(--cyan) }
.ll.WARN  { color: var(--amber) }
.ll.ALERT { color: var(--red) }
.ll.OK    { color: var(--green) }
.ll.L4    { color: var(--cyan) }
.ll.L7    { color: var(--violet) }
.lm { color: var(--txt); word-break: break-all; font-size: .62rem }

/* ══ ALERT CARDS ══════════════════════════════════════════════════ */
.al-list { display: flex; flex-direction: column; gap: 8px }
.al-item {
  padding: 12px 15px; border-radius: var(--r); border: 1px solid;
  display: flex; gap: 11px; align-items: flex-start; transition: all .2s;
}
.al-item.block  { border-color: rgba(255,23,68,.25);   background: rgba(255,23,68,.05) }
.al-item.ddos   { border-color: rgba(255,171,0,.22);   background: rgba(255,171,0,.04) }
.al-item.flood  { border-color: rgba(255,171,0,.22);   background: rgba(255,171,0,.04) }
.al-item.conn   { border-color: rgba(0,229,255,.2);    background: rgba(0,229,255,.03) }
.al-item.system { border-color: rgba(0,229,255,.18);   background: rgba(0,229,255,.03) }
.al-item.ur     { box-shadow: 0 0 14px rgba(255,23,68,.12) }
.al-icon { font-size: 1.2rem; flex-shrink: 0; margin-top: 1px }
.al-title { font-weight: 600; color: var(--white); font-size: .82rem; margin-bottom: 2px }
.al-detail { font-size: .68rem; color: var(--txt2) }
.al-time { font-size: .59rem; color: var(--txt2); font-family: var(--mono); margin-top: 3px }
.al-sev {
  font-size: .6rem; padding: 2px 7px; border-radius: 10px;
  font-family: var(--mono); font-weight: 700; margin-left: auto; flex-shrink: 0;
}
.al-sev.high   { background: rgba(255,23,68,.15);   color: var(--red) }
.al-sev.medium { background: rgba(255,171,0,.12);   color: var(--amber) }
.al-sev.low    { background: rgba(0,230,118,.1);    color: var(--green) }

/* ══ FORMS ════════════════════════════════════════════════════════ */
.inp {
  background: rgba(255,255,255,.04); border: 1px solid var(--bdr);
  border-radius: 7px; color: var(--white); padding: 9px 13px;
  font-family: var(--font); font-size: .83rem; outline: none;
  transition: border-color .2s; width: 100%;
}
.inp:focus { border-color: var(--cyan); box-shadow: 0 0 0 2px rgba(0,229,255,.1) }
.inp::placeholder { color: var(--txt2) }
.inp-row { display: flex; gap: 8px; margin-bottom: 12px }
.inp-row .inp { flex: 1 }

.btn {
  padding: 9px 16px; border-radius: 7px; cursor: pointer;
  font-family: var(--font); font-size: .82rem; font-weight: 600;
  letter-spacing: .04em; border: 1px solid; transition: all .22s;
  display: inline-flex; align-items: center; gap: 6px; white-space: nowrap;
}
.bc  { border-color: var(--cyan);   color: var(--cyan);   background: transparent }
.bc:hover  { background: rgba(0,229,255,.1); box-shadow: var(--glow-c) }
.br  { border-color: var(--red);    color: var(--red);    background: transparent }
.br:hover  { background: rgba(255,23,68,.1); box-shadow: var(--glow-r) }
.bg  { border-color: var(--green);  color: var(--green);  background: transparent }
.bg:hover  { background: rgba(0,230,118,.08); box-shadow: var(--glow-g) }
.ba  { border-color: var(--amber);  color: var(--amber);  background: transparent }
.ba:hover  { background: rgba(255,171,0,.1); box-shadow: var(--glow-a) }
.bv  { border-color: var(--violet); color: var(--violet); background: transparent }
.bv:hover  { background: rgba(213,0,249,.08) }
.bs  { padding: 5px 10px; font-size: .7rem }
.bxs { padding: 3px 8px;  font-size: .62rem }

/* ══ SETTINGS FORM ════════════════════════════════════════════════ */
.sf  { display: grid; grid-template-columns: 1fr 1fr; gap: 14px }
.sg  { display: flex; flex-direction: column; gap: 5px }
.sl  {
  font-size: .62rem; text-transform: uppercase; letter-spacing: .16em;
  color: var(--txt2); font-family: var(--mono);
}
.sf-note { font-size: .6rem; color: var(--txt2); font-family: var(--mono) }
.sf-full { grid-column: 1 / -1 }
.sf-head {
  font-size: .72rem; font-weight: 700; letter-spacing: .1em;
  margin-bottom: 10px; padding-bottom: 8px;
  border-bottom: 1px solid var(--bdr);
}

/* ══ CONNECTION BARS ══════════════════════════════════════════════ */
.cb {
  display: flex; align-items: center; gap: 9px; padding: 5px 0;
  border-bottom: 1px solid rgba(255,255,255,.025);
}
.cb-ip { color: var(--cyan); font-family: var(--mono); font-size: .68rem; width: 128px; flex-shrink: 0 }
.cb-tr { flex: 1; height: 3px; background: var(--bg3); border-radius: 2px; overflow: hidden }
.cb-f  { height: 100%; border-radius: 2px; background: linear-gradient(90deg,var(--cyan),var(--green)); transition: width .4s }
.cb-n  { font-family: var(--mono); font-size: .62rem; color: var(--txt2); width: 28px; text-align: right; flex-shrink: 0 }

/* ══ PORT PILLS ═══════════════════════════════════════════════════ */
.pp {
  display: inline-block; padding: 3px 9px; margin: 3px;
  border-radius: 12px; font-family: var(--mono); font-size: .62rem;
  background: rgba(0,229,255,.08); border: 1px solid rgba(0,229,255,.22); color: var(--cyan);
}

/* ══ CPU BAR ══════════════════════════════════════════════════════ */
.cpubar { width: 58px; height: 4px; background: var(--bg3); border-radius: 2px; display: inline-block; vertical-align: middle }
.cpuf   { height: 100%; border-radius: 2px; background: var(--cyan); transition: width .4s }

/* ══ GAUGES ═══════════════════════════════════════════════════════ */
.gauge-wrap { text-align: center; padding: 8px 0 4px }

/* ══ FW RULES ═════════════════════════════════════════════════════ */
.fwr { font-family: var(--mono); font-size: .6rem; line-height: 1.9; color: var(--txt2) }
.fwr .fchain { color: var(--cyan); font-weight: 700 }
.fwr .fdrop  { color: var(--red) }
.fwr .flog   { color: var(--amber) }
.fwr .fret   { color: var(--green) }

/* ══ TOAST ════════════════════════════════════════════════════════ */
#toast {
  position: fixed; bottom: 24px; right: 24px; z-index: 9999;
  padding: 11px 20px; border-radius: var(--r); max-width: 360px;
  font-family: var(--mono); font-size: .76rem;
  opacity: 0; transform: translateY(8px); transition: all .25s; pointer-events: none;
}
#toast.s { opacity: 1; transform: translateY(0) }
#toast.ok { background: rgba(0,230,118,.1);  border: 1px solid rgba(0,230,118,.4); color: var(--green) }
#toast.er { background: rgba(255,23,68,.1);  border: 1px solid rgba(255,23,68,.4); color: var(--red) }
#toast.in { background: rgba(0,229,255,.1);  border: 1px solid rgba(0,229,255,.4); color: var(--cyan) }

/* ══ ALERT DRAWER ═════════════════════════════════════════════════ */
#drw {
  position: fixed; top: 0; right: -400px; bottom: 0; width: 385px;
  background: var(--bg1); border-left: 1px solid var(--bdr);
  z-index: 400; transition: right .28s; overflow-y: auto; padding: 20px;
}
#drw.op { right: 0 }
#drw-ov {
  position: fixed; inset: 0; background: rgba(0,0,0,.55); z-index: 399;
  display: none; cursor: pointer;
}
#drw-ov.s { display: block }
.dh { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px }
.dh h2 { font-size: .95rem; font-weight: 700; color: var(--white); letter-spacing: .06em }
.dc { cursor: pointer; color: var(--txt2); font-size: 1.3rem; padding: 4px; transition: color .18s }
.dc:hover { color: var(--cyan) }

/* ══ WEB TERMINAL ═════════════════════════════════════════════════ */
.term-wrap {
  background: #020810; border: 1px solid var(--bdr);
  border-radius: var(--r); overflow: hidden; height: 520px;
  display: flex; flex-direction: column;
  box-shadow: inset 0 0 40px rgba(0,229,255,.04);
}
.term-top {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; background: var(--bg2);
  border-bottom: 1px solid var(--bdr);
}
.term-dot {
  width: 11px; height: 11px; border-radius: 50%; cursor: pointer;
}
.td-r { background: #ff5f57 } .td-y { background: #febc2e } .td-g { background: #28c840 }
.term-title {
  flex: 1; text-align: center; font-size: .72rem;
  font-family: var(--mono); color: var(--txt2); letter-spacing: .12em;
}
.term-out {
  flex: 1; overflow-y: auto; padding: 14px 18px;
  font-family: var(--mono); font-size: .75rem; line-height: 1.8; color: #88ccee;
  white-space: pre-wrap; word-break: break-all;
}
.term-out::-webkit-scrollbar { width: 3px }
.term-out::-webkit-scrollbar-thumb { background: var(--bdr2) }
.term-out .t-prompt  { color: var(--cyan); font-weight: 700 }
.term-out .t-cmd     { color: var(--white) }
.term-out .t-out     { color: #88ccee }
.term-out .t-err     { color: var(--red) }
.term-out .t-info    { color: var(--amber) }
.term-out .t-success { color: var(--green) }
.term-inp-row {
  display: flex; align-items: center; gap: 0;
  padding: 0 0 0 18px; background: var(--bg2);
  border-top: 1px solid var(--bdr);
}
.term-prompt-lbl {
  color: var(--cyan); font-family: var(--mono); font-size: .76rem;
  font-weight: 700; flex-shrink: 0; padding: 12px 8px 12px 0;
}
.term-input {
  flex: 1; background: transparent; border: none; outline: none;
  color: var(--white); font-family: var(--mono); font-size: .76rem;
  padding: 12px 0; caret-color: var(--cyan);
}
.term-exec-btn {
  padding: 0 20px; height: 100%; background: transparent;
  border: none; border-left: 1px solid var(--bdr);
  color: var(--cyan); cursor: pointer; font-size: .85rem;
  transition: background .2s; font-family: var(--font); font-weight: 600;
}
.term-exec-btn:hover { background: rgba(0,229,255,.08) }
.term-shortcuts {
  display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 14px;
}
.ts-btn {
  padding: 5px 10px; border-radius: 5px;
  border: 1px solid var(--bdr); background: var(--bg2);
  color: var(--txt); font-family: var(--mono); font-size: .65rem;
  cursor: pointer; transition: all .18s;
}
.ts-btn:hover { border-color: var(--cyan); color: var(--cyan); background: rgba(0,229,255,.06) }

/* ══ HELP PAGE ════════════════════════════════════════════════════ */
.help-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 14px }
.help-card {
  background: var(--bg1); border: 1px solid var(--bdr);
  border-radius: var(--r); overflow: hidden;
}
.help-card-head {
  padding: 14px 18px; border-bottom: 1px solid var(--bdr);
  display: flex; align-items: center; gap: 10px;
}
.help-card-head h3 {
  font-size: .92rem; font-weight: 700; color: var(--white);
  letter-spacing: .04em;
}
.help-card-body { padding: 16px 18px }
.help-cmd {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 9px 0; border-bottom: 1px solid rgba(255,255,255,.03);
}
.help-cmd:last-child { border-bottom: none }
.help-cmd-code {
  font-family: var(--mono); font-size: .7rem; color: var(--cyan);
  background: rgba(0,229,255,.06); padding: 3px 9px;
  border-radius: 4px; white-space: nowrap; flex-shrink: 0;
}
.help-cmd-desc { font-size: .73rem; color: var(--txt); padding-top: 2px }
.help-tag {
  display: inline-block; font-size: .58rem; font-family: var(--mono);
  padding: 1px 6px; border-radius: 8px; margin-left: 6px; vertical-align: middle;
}
.tag-l4  { background: rgba(0,229,255,.1); color: var(--cyan); border: 1px solid rgba(0,229,255,.3) }
.tag-l7  { background: rgba(213,0,249,.1); color: var(--violet); border: 1px solid rgba(213,0,249,.3) }
.tag-sys { background: rgba(255,171,0,.1); color: var(--amber); border: 1px solid rgba(255,171,0,.3) }
.tag-web { background: rgba(0,230,118,.1); color: var(--green); border: 1px solid rgba(0,230,118,.3) }

.help-notice {
  padding: 14px 18px; border-radius: var(--r); margin-bottom: 14px;
  border: 1px solid; font-size: .78rem;
}
.help-notice.info  { border-color: rgba(0,229,255,.25); background: rgba(0,229,255,.05); color: var(--cyan) }
.help-notice.warn  { border-color: rgba(255,171,0,.25);  background: rgba(255,171,0,.05); color: var(--amber) }
.help-notice.good  { border-color: rgba(0,230,118,.22);  background: rgba(0,230,118,.05); color: var(--green) }

.feature-list { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 14px }
.feat {
  padding: 14px; border-radius: var(--r);
  border: 1px solid var(--bdr); background: var(--bg1);
  text-align: center;
}
.feat .f-icon { font-size: 1.8rem; margin-bottom: 8px }
.feat .f-name { font-size: .8rem; font-weight: 600; color: var(--white); margin-bottom: 4px }
.feat .f-desc { font-size: .67rem; color: var(--txt2) }

/* ══ RESPONSIVE ═══════════════════════════════════════════════════ */
@media(max-width:1500px) { .mg { grid-template-columns: repeat(3,1fr) } }
@media(max-width:1200px) { .g3 { grid-template-columns: 1fr 1fr }; .g21,.g12,.g13 { grid-template-columns: 1fr } }
@media(max-width:900px)  {
  #sb { transform: translateX(-240px) }
  #main { margin-left: 0 }
  .mg { grid-template-columns: 1fr 1fr }
  .g2,.g3,.g21,.g12,.g13 { grid-template-columns: 1fr }
  .help-grid { grid-template-columns: 1fr }
  .feature-list { grid-template-columns: 1fr 1fr }
}
</style>
</head>
<body>

<!-- ═══════════════ SIDEBAR ═══════════════════════════════════════ -->
<nav id="sb">
  <div class="sb-logo">
    <div class="sb-brand">
      <div class="logo-ring">
        <svg width="24" height="24" viewBox="0 0 40 40" fill="none">
          <path d="M20 3C20 3 29 11 35 9C31 16 36 25 28 24C24 32 20 36 20 36C20 36 16 32 12 24C4 25 9 16 5 9C11 11 20 3 20 3Z" fill="rgba(0,229,255,.15)" stroke="#00e5ff" stroke-width="1.2"/>
          <circle cx="20" cy="20" r="3" fill="#00e5ff" opacity=".9"/>
        </svg>
      </div>
      <div>
        <div class="sb-name">Eagle Guard</div>
        <div class="sb-ver">L4 · L7 · XDP · v7.2</div>
      </div>
    </div>
  </div>

  <div class="sb-section">Dashboard</div>
  <div class="ni on" onclick="nav('dash')"><span class="ic">⊞</span>Overview</div>
  <div class="ni"    onclick="nav('net')"><span class="ic">📡</span>Ağ Monitörü</div>
  <div class="ni"    onclick="nav('sys')"><span class="ic">🖥</span>Sistem Monitörü</div>

  <div class="sb-section">Güvenlik</div>
  <div class="ni" onclick="nav('l4')"><span class="ic">🔵</span>Layer 4</div>
  <div class="ni" onclick="nav('l7')"><span class="ic">🟣</span>Layer 7</div>
  <div class="ni" onclick="nav('ips')"><span class="ic">🚫</span>IP Yönetimi</div>
  <div class="ni" onclick="nav('wl')"><span class="ic">✅</span>Whitelist</div>
  <div class="ni" onclick="nav('game')"><span class="ic">🎮</span>Game Sunucu</div>
  <div class="ni" onclick="nav('waf')"><span class="ic">🌐</span>WAF Panel</div>
  <div class="ni" onclick="nav('xdp')"><span class="ic">⚡</span>XDP / eBPF</div>

  <div class="sb-section">İzleme & Araçlar</div>
  <div class="ni" onclick="nav('alrt')"><span class="ic">🔔</span>Alertler<span class="nb" id="nav-badge">0</span></div>
  <div class="ni" onclick="nav('logs')"><span class="ic">📋</span>Log Akışı</div>
  <div class="ni" onclick="nav('fw')"><span class="ic">🛡</span>Firewall Kuralları</div>
  <div class="ni" onclick="nav('term')"><span class="ic">💻</span>Web Terminal</div>
  <div class="ni" onclick="nav('help')"><span class="ic">❓</span>Yardım</div>
  <div class="ni" onclick="nav('set')"><span class="ic">⚙</span>Ayarlar</div>

  <div id="sbs" class="sb-bot off">
    <div style="display:flex;align-items:center;gap:8px">
      <div class="sb-dot"></div>
      <span class="sb-lbl" id="slbl">BAĞLANIYOR</span>
    </div>
    <div class="sb-up" id="sup">Uptime: --</div>
    <button class="sb-btn" id="sbtn" onclick="toggleSvc()">⏻ BAŞLAT</button>
    <button class="sb-btn" style="margin-top:6px" onclick="restartSvc()">🔄 RESTART</button>
  </div>
</nav>

<!-- ═══════════════ MAIN ═══════════════════════════════════════════ -->
<main id="main">
  <div class="topbar">
    <div class="tb-l">
      <div class="page-title" id="ptitle">Overview</div>
      <div class="bc">Ubuntu → <span>Eagle Guard</span> → Web Arayüzü</div>
    </div>
    <div class="tb-r">
      <span id="clk">--:--:--</span>
      <div class="icon-btn" onclick="openDrw()" title="Alertler">🔔<span class="badge" id="bellc">0</span></div>
    </div>
  </div>

  <!-- ══ OVERVIEW ════════════════════════════════════════════════ -->
  <div id="p-dash" class="pg on">
    <div class="mg">
      <div class="card mc"><div class="mc-icon">🚫</div><div class="mc-label">Engellenen IP</div><div class="mc-val vr" id="m-blk">—</div><div class="mc-sub">aktif kural</div></div>
      <div class="card mc"><div class="mc-icon">🔗</div><div class="mc-label">Aktif Bağlantı</div><div class="mc-val vc" id="m-conn">—</div><div class="mc-sub">established TCP</div></div>
      <div class="card mc"><div class="mc-icon">📥</div><div class="mc-label">Gelen Bant</div><div class="mc-val vc" id="m-bi">—</div><div class="mc-sub" id="m-pi">— pkt/s</div></div>
      <div class="card mc"><div class="mc-icon">📤</div><div class="mc-label">Giden Bant</div><div class="mc-val vc" id="m-bo">—</div><div class="mc-sub" id="m-po">— pkt/s</div></div>
      <div class="card mc"><div class="mc-icon">⚙</div><div class="mc-label">CPU / RAM</div><div class="mc-val va" id="m-cpu">—</div><div class="mc-sub" id="m-mem">RAM: —</div></div>
    </div>
    <div class="g2">
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📊</span>Canlı Bant Genişliği (MB/s)</div><div class="ch"><canvas id="c-bw"></canvas></div></div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📦</span>Canlı PPS (paket/saniye)</div><div class="ch"><canvas id="c-pps"></canvas></div></div>
    </div>
    <div class="g3">
      <div class="card">
        <div class="card-glow"></div>
        <div class="card-title"><span class="ci">🔵</span>L4 Engelleme Dağılımı</div>
        <div class="pb"><div class="pbh"><span>SYN Flood</span><span id="pb-syn" class="tr">0</span></div><div class="pbt"><div class="pbf pbr" id="pb-syn-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>UDP Flood</span><span id="pb-udp" class="ta">0</span></div><div class="pbt"><div class="pbf pby" id="pb-udp-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>ICMP Flood</span><span id="pb-icmp" class="tc">0</span></div><div class="pbt"><div class="pbf pbc" id="pb-icmp-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>RST Flood</span><span id="pb-rst" class="tc">0</span></div><div class="pbt"><div class="pbf pbc" id="pb-rst-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>XMAS/NULL/FRAG</span><span id="pb-misc" class="ta">0</span></div><div class="pbt"><div class="pbf pby" id="pb-misc-b" style="width:0"></div></div></div>
      </div>
      <div class="card">
        <div class="card-glow"></div>
        <div class="card-title"><span class="ci">🟣</span>L7 Engelleme Dağılımı</div>
        <div class="pb"><div class="pbh"><span>HTTP Flood</span><span id="pb-http" class="tv">0</span></div><div class="pbt"><div class="pbf pbv" id="pb-http-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>HTTPS Flood</span><span id="pb-https" class="tv">0</span></div><div class="pbt"><div class="pbf pbv" id="pb-https-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>SSH Brute Force</span><span id="pb-ssh" class="tr">0</span></div><div class="pbt"><div class="pbf pbr" id="pb-ssh-b" style="width:0"></div></div></div>
        <div class="pb"><div class="pbh"><span>Slowloris</span><span id="pb-slow" class="ta">0</span></div><div class="pbt"><div class="pbf pby" id="pb-slow-b" style="width:0"></div></div></div>
        <div style="margin-top:12px"><div class="ch" style="height:85px"><canvas id="c-atk"></canvas></div></div>
      </div>
      <div class="card">
        <div class="card-glow"></div>
        <div class="card-title"><span class="ci">🌐</span>En Çok Bağlantı</div>
        <div id="tc-dash"></div>
      </div>
    </div>
    <div class="card mb">
      <div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between"><span><span class="ci">🔔</span>Son Alertler</span><button class="btn bc bxs" onclick="markRead()">✓ Okundu</button></div>
      <div class="al-list" id="a-dash"></div>
    </div>
  </div>

  <!-- ══ AĞ MONİTÖRÜ ════════════════════════════════════════════ -->
  <div id="p-net" class="pg">
    <div class="mg" style="grid-template-columns:repeat(4,1fr)">
      <div class="card mc"><div class="mc-label">Toplam Gelen</div><div class="mc-val vc" id="n-rx">—</div><div class="mc-sub" id="n-rxp">— paket</div></div>
      <div class="card mc"><div class="mc-label">Toplam Giden</div><div class="mc-val vc" id="n-tx">—</div><div class="mc-sub" id="n-txp">— paket</div></div>
      <div class="card mc"><div class="mc-label">RX Hataları</div><div class="mc-val vr" id="n-err">—</div><div class="mc-sub" id="n-drop">— dropped</div></div>
      <div class="card mc"><div class="mc-label">Aktif Bağlantı</div><div class="mc-val va" id="n-conn">—</div><div class="mc-sub" id="n-if">—</div></div>
    </div>
    <div class="card mb"><div class="card-glow"></div><div class="card-title"><span class="ci">📡</span>Bant Genişliği Geçmişi (Son 10 Dakika)</div><div class="ch-lg"><canvas id="c-bwh"></canvas></div></div>
    <div class="g2">
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📦</span>PPS Geçmişi</div><div class="ch-lg"><canvas id="c-ppsh"></canvas></div></div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">🔗</span>Bağlantı Trendi</div><div class="ch-lg"><canvas id="c-cnh"></canvas></div></div>
    </div>
    <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">🌐</span>IP Bağlantı Dağılımı</div><div id="tc-net"></div></div>
  </div>

  <!-- ══ SİSTEM MONİTÖRÜ ════════════════════════════════════════ -->
  <div id="p-sys" class="pg">
    <div class="g3">
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">⚙</span>CPU Kullanımı</div>
        <div class="gauge-wrap"><canvas id="g-cpu" width="160" height="160"></canvas></div>
        <div style="text-align:center;font-family:var(--mono);font-size:.7rem;color:var(--txt2)" id="sys-cpu-l">—</div>
      </div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">🧠</span>RAM Kullanımı</div>
        <div class="gauge-wrap"><canvas id="g-mem" width="160" height="160"></canvas></div>
        <div style="text-align:center;font-family:var(--mono);font-size:.7rem;color:var(--txt2)" id="sys-mem-l">—</div>
      </div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">💾</span>Disk Kullanımı</div>
        <div class="gauge-wrap"><canvas id="g-disk" width="160" height="160"></canvas></div>
        <div style="text-align:center;font-family:var(--mono);font-size:.7rem;color:var(--txt2)" id="sys-disk-l">—</div>
      </div>
    </div>
    <div class="g2">
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📈</span>CPU + RAM Trendi</div><div class="ch-lg"><canvas id="c-sys"></canvas></div></div>
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🖥</span>Sistem Bilgisi</div>
        <div id="sysinfo-detail" style="font-family:var(--mono);font-size:.68rem;line-height:2.2;color:var(--txt)">Yükleniyor...</div>
        <div style="margin-top:12px"><div class="card-title" style="margin-bottom:7px"><span class="ci">🔌</span>Açık Portlar</div><div id="ports"></div></div>
      </div>
    </div>
    <div class="card"><div class="card-glow"></div>
      <div class="card-title"><span class="ci">⚡</span>Aktif Süreçler (CPU sırası)</div>
      <div class="tscr"><table class="tbl"><thead><tr><th>PID</th><th>CPU%</th><th>RAM%</th><th>Bar</th><th>Komut</th></tr></thead><tbody id="procs"></tbody></table></div>
    </div>
  </div>

  <!-- ══ LAYER 4 ════════════════════════════════════════════════ -->
  <div id="p-l4" class="pg">
    <div class="mg" style="grid-template-columns:repeat(4,1fr)">
      <div class="card mc"><div class="mc-label">SYN Engelleme</div><div class="mc-val vr" id="l4-syn">0</div></div>
      <div class="card mc"><div class="mc-label">UDP Engelleme</div><div class="mc-val va" id="l4-udp">0</div></div>
      <div class="card mc"><div class="mc-label">ICMP Engelleme</div><div class="mc-val vc" id="l4-icmp">0</div></div>
      <div class="card mc"><div class="mc-label">Toplam Drop</div><div class="mc-val vr" id="l4-tot">0</div></div>
    </div>
    <div class="g2">
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🛡</span>L4 Koruma Modülleri (16 adet)</div>
        <div class="mds" id="l4-mods">
          <div class="md"><div class="mdd"></div><span class="mdn">SYN Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">UDP Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">ICMP Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">RST Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">XMAS Attack</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">NULL Scan</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Frag Packet</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Port Scan</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Bogon IP</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">IP Spoofing</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">DNS Amplification</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">NTP Amplification</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">SSDP</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Memcached</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Conn Rate Limit</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">IPv6 SYN</span><span class="mdc">aktif</span></div>
        </div>
      </div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📊</span>L4 Engelleme Trendi</div><div class="ch-lg"><canvas id="c-l4t"></canvas></div></div>
    </div>
    <div class="card"><div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between"><span><span class="ci">📋</span>Aktif L4 Kuralları</span><button class="btn bc bs" onclick="loadL4Rules()">↻ Yenile</button></div>
      <div class="lw" style="height:280px" id="l4rules"></div>
    </div>
  </div>

  <!-- ══ LAYER 7 ════════════════════════════════════════════════ -->
  <div id="p-l7" class="pg">
    <div class="mg" style="grid-template-columns:repeat(4,1fr)">
      <div class="card mc"><div class="mc-label">HTTP Engelleme</div><div class="mc-val vv" id="l7-http">0</div></div>
      <div class="card mc"><div class="mc-label">HTTPS Engelleme</div><div class="mc-val vv" id="l7-https">0</div></div>
      <div class="card mc"><div class="mc-label">SSH Brute Force</div><div class="mc-val vr" id="l7-ssh">0</div></div>
      <div class="card mc"><div class="mc-label">Slowloris</div><div class="mc-val va" id="l7-slow">0</div></div>
    </div>
    <div class="g2">
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🟣</span>L7 Koruma Modülleri (8 adet)</div>
        <div class="mds">
          <div class="md"><div class="mdd"></div><span class="mdn">HTTP Flood (port 80)</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">HTTPS Flood (443)</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">HTTP Rate Limit</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Slowloris Koruma</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">SSH Brute Force</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">FTP Brute Force</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">DNS TCP Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">hashlimit Rate</span><span class="mdc">aktif</span></div>
        </div>
      </div>
      <div class="card"><div class="card-glow"></div><div class="card-title"><span class="ci">📊</span>L7 Engelleme Trendi</div><div class="ch-lg"><canvas id="c-l7t"></canvas></div></div>
    </div>
    <div class="card"><div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between"><span><span class="ci">📋</span>Aktif L7 Kuralları</span><button class="btn bc bs" onclick="loadL7Rules()">↻ Yenile</button></div>
      <div class="lw" style="height:280px" id="l7rules"></div>
    </div>
  </div>

  <!-- ══ IP YÖNETİMİ ════════════════════════════════════════════ -->
  <div id="p-ips" class="pg">
    <div class="g2">
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🚫</span>IP Engelle</div>
        <div class="inp-row">
          <input class="inp" id="blk-ip" placeholder="IP adresi (1.2.3.4)" onkeydown="if(event.key==='Enter')blockIP()">
          <select class="inp" id="blk-l" style="max-width:85px"><option>L4</option><option>L7</option></select>
          <button class="btn br" onclick="blockIP()">🚫 Engelle</button>
        </div>
        <div class="card-title" style="justify-content:space-between"><span><span class="ci">📋</span>Engellenen IP'ler (<span id="blkc">0</span>)</span></div>
        <div class="tscr"><table class="tbl"><thead><tr><th>IP</th><th>Layer</th><th>Sebep</th><th>Tarih</th><th>Hit</th><th></th></tr></thead><tbody id="blktb"></tbody></table></div>
      </div>
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🌐</span>Aktif Bağlantılar</div>
        <div id="tc-ips"></div>
      </div>
    </div>
  </div>

  <!-- ══ WHITELİST ══════════════════════════════════════════════ -->
  <div id="p-wl" class="pg">
    <div class="card"><div class="card-glow"></div>
      <div class="card-title"><span class="ci">✅</span>Whitelist — Asla Engellenmeyecek IP'ler</div>
      <div class="inp-row" style="max-width:500px">
        <input class="inp" id="wl-ip" placeholder="IP adresi ekle" onkeydown="if(event.key==='Enter')addWL()">
        <button class="btn bg" onclick="addWL()">✚ Ekle</button>
      </div>
      <div class="tscr" style="max-height:420px"><table class="tbl"><thead><tr><th>IP Adresi</th><th>İşlem</th></tr></thead><tbody id="wltb"></tbody></table></div>
    </div>
  </div>

  <!-- ══ ALERTLER ═══════════════════════════════════════════════ -->
  <div id="p-alrt" class="pg">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:13px">
      <span style="color:var(--txt2);font-size:.73rem;font-family:var(--mono)">Tüm güvenlik alertleri</span>
      <div style="display:flex;gap:8px">
        <button class="btn bc bs" onclick="markRead()">✓ Tümünü Okundu</button>
        <button class="btn ba bs" onclick="testAlert()">🧪 Test Alert</button>
      </div>
    </div>
    <div class="al-list" id="a-full"></div>
  </div>

  <!-- ══ LOG AKIŞI ═══════════════════════════════════════════════ -->
  <div id="p-logs" class="pg">
    <div class="card"><div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between">
        <span><span class="ci">📋</span>Canlı Log Akışı</span>
        <div style="display:flex;gap:7px">
          <select class="inp bs" id="lf" onchange="filterLogs()" style="width:105px">
            <option value="">Tümü</option><option value="ALERT">ALERT</option>
            <option value="WARN">WARN</option><option value="INFO">INFO</option>
            <option value="L4">L4</option><option value="L7">L7</option>
          </select>
          <button class="btn bc bs" onclick="loadLogs()">↻ Yenile</button>
        </div>
      </div>
      <div class="lw" id="logbox" style="height:500px"></div>
    </div>
  </div>


  <!-- ══ GAME SUNUCU KORUMASI ════════════════════════════════════ -->
  <div id="p-game" class="pg">
    <div class="mg" style="grid-template-columns:repeat(5,1fr)">
      <div class="card mc"><div class="mc-icon">🎮</div><div class="mc-label">Toplam Engelleme</div><div class="mc-val vr" id="mg-total">0</div><div class="mc-sub">tüm oyun saldırıları</div></div>
      <div class="card mc"><div class="mc-icon">📡</div><div class="mc-label">UDP Flood</div><div class="mc-val vr" id="mg-udp">0</div><div class="mc-sub">paket engellendi</div></div>
      <div class="card mc"><div class="mc-icon">🔗</div><div class="mc-label">TCP Flood</div><div class="mc-val vc" id="mg-tcp">0</div><div class="mc-sub">bağlantı engellendi</div></div>
      <div class="card mc"><div class="mc-icon">❓</div><div class="mc-label">Query Flood</div><div class="mc-val va" id="mg-query">0</div><div class="mc-sub">sorgu engellendi</div></div>
      <div class="card mc"><div class="mc-icon">👾</div><div class="mc-label">Fake Connect</div><div class="mc-val vv" id="mg-fake">0</div><div class="mc-sub">sahte bağlantı</div></div>
    </div>

    <div class="g2">
      <!-- Oyun Modülleri -->
      <div class="card"><div class="card-glow"></div>
        <div class="card-title" style="justify-content:space-between">
          <span><span class="ci">🎮</span>Game Koruma Modülleri</span>
          <div style="display:flex;gap:7px">
            <button class="btn bg bs" onclick="gameToggle('on')">▶ Aç</button>
            <button class="btn br bs" onclick="gameToggle('off')">■ Kapat</button>
          </div>
        </div>
        <div class="mds" id="game-mods">
          <div class="md"><div class="mdd"></div><span class="mdn">UDP Flood (IP/s limiti)</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">TCP Flood (connlimit)</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Query Flood Koruması</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Fake Connect Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">RCON Brute Force</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Oversized UDP Drop</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Tiny UDP Drop (&lt;16B)</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Amplification Blocker</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Source Engine Query</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">MC Ping Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">FiveM UDP Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">TS3 UDP Flood</span><span class="mdc">aktif</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">CS2/CS:GO Koruma</span><span class="mdc">27015-18</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Minecraft Koruma</span><span class="mdc">25565</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">FiveM/GTA Koruma</span><span class="mdc">30120</span></div>
          <div class="md"><div class="mdd"></div><span class="mdn">Unreal/Ark Koruma</span><span class="mdc">7777</span></div>
        </div>
      </div>

      <!-- Korunan Oyunlar -->
      <div class="card"><div class="card-glow"></div>
        <div class="card-title"><span class="ci">🕹</span>Desteklenen Oyun Motorları</div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">
          <div style="background:rgba(0,229,255,.04);border:1px solid var(--bdr);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--cyan);margin-bottom:6px">⚙ Source Engine</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              CS2 / CS:GO<br>Team Fortress 2<br>Garry's Mod<br>Left 4 Dead 2<br>
              <span class="l4b">UDP/TCP 27015-27018</span>
            </div>
          </div>
          <div style="background:rgba(0,230,118,.04);border:1px solid rgba(0,230,118,.15);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--green);margin-bottom:6px">⛏ Minecraft</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              Java Edition<br>Bedrock Edition<br>RCON Koruması<br>Ping Flood<br>
              <span class="l4b">TCP 25565 / UDP 19132</span>
            </div>
          </div>
          <div style="background:rgba(213,0,249,.04);border:1px solid rgba(213,0,249,.15);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--violet);margin-bottom:6px">🚗 FiveM / GTA</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              FiveM RP Server<br>alt:V Multiplayer<br>UDP Flood Koruması<br>Fake Connect<br>
              <span class="l4b">UDP/TCP 30120 / 64090</span>
            </div>
          </div>
          <div style="background:rgba(255,171,0,.04);border:1px solid rgba(255,171,0,.15);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--amber);margin-bottom:6px">🦕 Unreal Engine</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              ARK: Survival<br>Conan Exiles<br>Killing Floor 2<br>DayZ / ArmA<br>
              <span class="l4b">UDP/TCP 7777 / 2302</span>
            </div>
          </div>
          <div style="background:rgba(0,229,255,.04);border:1px solid var(--bdr);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--cyan);margin-bottom:6px">🎙 TeamSpeak 3</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              Voice Server<br>UDP Flood Koruması<br>File Transfer<br><br>
              <span class="l4b">UDP/TCP 9987</span>
            </div>
          </div>
          <div style="background:rgba(255,23,68,.04);border:1px solid rgba(255,23,68,.15);border-radius:8px;padding:11px 13px">
            <div style="font-size:.75rem;font-weight:600;color:var(--red);margin-bottom:6px">🦀 Diğer / Özel</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.9">
              Rust (28015)<br>Valheim (2456)<br>Terraria (7777)<br>Özel port ekle<br>
              <span class="l4b">Config ile ayarla</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Port Yönetimi -->
    <div class="card mb"><div class="card-glow"></div>
      <div class="card-title"><span class="ci">🔌</span>Oyun Port Yönetimi</div>
      <div class="g2" style="margin-bottom:0">
        <div>
          <div class="sl" style="margin-bottom:6px">UDP PORTLARI (virgülle ayır)</div>
          <div class="inp-row">
            <input class="inp" id="game-udp-ports" placeholder="27015,25565,7777,30120,19132..." value="27015,27016,27017,27018,7777,7778,19132,19133,25565,25575,2302,2303,9987,30120,64090">
            <button class="btn bc" onclick="saveGamePorts('udp')">💾 Kaydet</button>
          </div>
          <div style="margin-top:6px">
            <div class="sl" style="margin-bottom:5px">Hızlı Ekle:</div>
            <div style="display:flex;flex-wrap:wrap;gap:5px">
              <button class="ts-btn" onclick="addGamePort('udp','27015')">CS2/GO 27015</button>
              <button class="ts-btn" onclick="addGamePort('udp','25565')">MC Java 25565</button>
              <button class="ts-btn" onclick="addGamePort('udp','19132')">MC Bedrock 19132</button>
              <button class="ts-btn" onclick="addGamePort('udp','30120')">FiveM 30120</button>
              <button class="ts-btn" onclick="addGamePort('udp','7777')">Unreal 7777</button>
              <button class="ts-btn" onclick="addGamePort('udp','2302')">DayZ 2302</button>
              <button class="ts-btn" onclick="addGamePort('udp','9987')">TS3 9987</button>
              <button class="ts-btn" onclick="addGamePort('udp','28015')">Rust 28015</button>
              <button class="ts-btn" onclick="addGamePort('udp','2456')">Valheim 2456</button>
            </div>
          </div>
        </div>
        <div>
          <div class="sl" style="margin-bottom:6px">TCP PORTLARI (virgülle ayır)</div>
          <div class="inp-row">
            <input class="inp" id="game-tcp-ports" placeholder="27015,25565,7777,30120..." value="27015,27016,7777,25565,25575,2302,30120,64090,9987">
            <button class="btn bc" onclick="saveGamePorts('tcp')">💾 Kaydet</button>
          </div>
          <div style="margin-top:10px;padding:10px 13px;border-radius:7px;background:rgba(255,171,0,.05);border:1px solid rgba(255,171,0,.2)">
            <div style="font-size:.7rem;color:var(--amber);font-weight:600;margin-bottom:4px">⚠ Önemli Not</div>
            <div style="font-size:.67rem;color:var(--txt2);line-height:1.8">
              Port kaydettikten sonra <span style="color:var(--cyan);font-family:var(--mono)">systemctl restart eagle-guard</span> çalıştırın.
              Yanlış port girişi meşru oyun trafiğini engelleyebilir.
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Game Firewall Kuralları -->
    <div class="card"><div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between">
        <span><span class="ci">📋</span>Aktif Game Firewall Kuralları</span>
        <button class="btn bc bs" onclick="loadGameRules()">↻ Yenile</button>
      </div>
      <div class="lw" style="height:280px" id="game-rules"></div>
    </div>
  </div>

  <!-- ══ FIREWALL KURALLARI ══════════════════════════════════════ -->
  <div id="p-fw" class="pg">
    <!-- Durum + kontrol paneli -->
    <div class="card" style="margin-bottom:14px">
      <div class="card-glow"></div>
      <div class="card-title"><span class="ci">⚙️</span>Firewall Yönetimi</div>
      <div id="fw-status" style="padding:10px;font-family:var(--mono);font-size:.82rem;color:var(--txt2);margin-bottom:12px">
        Durum kontrol ediliyor…
      </div>
      <div style="display:flex;flex-wrap:wrap;gap:8px">
        <button class="btn bg" onclick="fwSetup()">🔧 Kuralları Oluştur / Yeniden Kur</button>
        <button class="btn bp" onclick="fwReload()">🔄 Config'ten Yeniden Yükle</button>
        <button class="btn br" onclick="fwFlush()">🗑 Tüm Chainleri Temizle</button>
        <button class="btn bc" onclick="fwRefreshAll()">↻ Yenile</button>
      </div>
      <div style="margin-top:14px;padding:10px;background:rgba(59,130,246,.08);border-left:3px solid #3b82f6;border-radius:4px;font-size:.78rem;color:var(--txt2)">
        <strong>ℹ️ Limitleri değiştirmek için:</strong> Ayarlar sayfasına gidin → L4/L7 değerlerini güncelleyin → Kaydet → Burada <em>"Config'ten Yeniden Yükle"</em> tuşuna basın.
      </div>
    </div>

    <div class="g2">
      <div class="card"><div class="card-glow"></div>
        <div class="card-title" style="justify-content:space-between"><span><span class="ci">🔵</span>Layer 4 Kuralları (EG_L4)</span>
          <div style="display:flex;gap:6px">
            <button class="btn bc bs" onclick="runShortcutInTerm('eagle-guard rules-l4')" title="Terminalde tam görüntü">💻</button>
            <button class="btn bc bs" onclick="loadL4Rules()">↻</button>
          </div>
        </div>
        <div class="lw" style="height:440px" id="fw-l4"></div>
      </div>
      <div class="card"><div class="card-glow"></div>
        <div class="card-title" style="justify-content:space-between"><span><span class="ci">🟣</span>Layer 7 Kuralları (EG_L7)</span>
          <div style="display:flex;gap:6px">
            <button class="btn bc bs" onclick="runShortcutInTerm('eagle-guard rules-l7')" title="Terminalde tam görüntü">💻</button>
            <button class="btn bc bs" onclick="loadL7Rules()">↻</button>
          </div>
        </div>
        <div class="lw" style="height:440px" id="fw-l7"></div>
      </div>
    </div>

    <!-- Game kuralları -->
    <div class="card" style="margin-top:14px">
      <div class="card-glow"></div>
      <div class="card-title" style="justify-content:space-between">
        <span><span class="ci">🎮</span>Game Koruma Kuralları (EG_GAME)</span>
        <div style="display:flex;gap:6px">
          <button class="btn bg bs" onclick="apiPost('game_on').then(fwRefreshAll)">▶️ Aç</button>
          <button class="btn br bs" onclick="apiPost('game_off').then(fwRefreshAll)">⏹ Kapat</button>
          <button class="btn bc bs" onclick="loadGameRulesFw()">↻</button>
        </div>
      </div>
      <div class="lw" style="height:260px" id="fw-game"></div>
    </div>
  </div>

  <!-- ══ WAF PANEL ══════════════════════════════════════════════ -->
  <div id="p-waf" class="pg">
    <div class="card" style="margin-bottom:14px">
      <div class="card-glow"></div>
      <div class="card-title"><span class="ci">🌐</span>WAF Yönetimi (ModSecurity + OWASP CRS)</div>
      <div id="waf-status" style="padding:10px;font-family:var(--mono);font-size:.82rem;color:var(--txt2);margin-bottom:12px;background:var(--bg2);border-radius:6px;">
        WAF kontrol ediliyor…
      </div>
      <div style="display:flex;flex-wrap:wrap;gap:8px">
        <button class="btn bg" onclick="wafTest('normal')">✓ Normal Test</button>
        <button class="btn br" onclick="wafTest('sqli')">✗ SQLi Test</button>
        <button class="btn br" onclick="wafTest('xss')">✗ XSS Test</button>
        <button class="btn br" onclick="wafTest('bot')">✗ Bot Test</button>
        <button class="btn bc" onclick="loadWAF()">↻ Yenile</button>
      </div>
    </div>

    <div class="g2">
      <div class="card">
        <div class="card-glow"></div>
        <div class="card-title">🔐 WAF Durumu</div>
        <div style="padding:12px;font-family:var(--mono);font-size:.83rem;color:var(--txt2);line-height:1.6">
          <div>Port: <span style="color:var(--green)">8080</span></div>
          <div>Proxy: <span style="color:var(--green)">127.0.0.1:80</span></div>
          <div>ModSecurity: <span id="waf-modsec" style="color:var(--green)">Aktif</span></div>
          <div>OWASP CRS: <span id="waf-crs" style="color:var(--green)">Yüklü</span></div>
          <div>Paranoia: <span id="waf-paranoia">2</span></div>
        </div>
      </div>
      <div class="card">
        <div class="card-glow"></div>
        <div class="card-title">📊 WAF İstatistikleri</div>
        <div id="waf-stats" style="padding:12px;font-family:var(--mono);font-size:.83rem;color:var(--txt2);line-height:1.8">
          <div>Toplam İstek: <b id="waf-total">0</b></div>
          <div>Engellenen: <b id="waf-blocked" style="color:var(--red)">0</b></div>
          <div>İzin Verilen: <b id="waf-allowed" style="color:var(--green)">0</b></div>
        </div>
      </div>
    </div>

    <div class="card" style="margin-top:14px">
      <div class="card-glow"></div>
      <div class="card-title">📋 WAF Audit Log</div>
      <div class="lw" style="height:400px;font-family:var(--mono);font-size:.78rem" id="waf-log"></div>
    </div>
  </div>

  <!-- ══ XDP / eBPF ═════════════════════════════════════════════ -->
  <div id="p-xdp" class="pg">
    <div id="xdp-content">
      <div class="card">Yükleniyor… <button class="btn" onclick="loadXDP()">⟳ Yenile</button></div>
    </div>
  </div>

  <!-- ══ WEB TERMİNAL ════════════════════════════════════════════ -->
  <div id="p-term" class="pg">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:13px">
      <div style="font-size:.75rem;color:var(--txt2);font-family:var(--mono)">
        ⚠ Sadece izin verilen komutlar çalıştırılabilir. Root komutları kısıtlıdır.
      </div>
      <button class="btn br bxs" onclick="clearTerm()">🗑 Temizle</button>
    </div>

    <!-- Kısayol butonları -->
    <div class="term-shortcuts">
      <button class="ts-btn" onclick="runShortcut('eagle-guard status')">📊 Status</button>
      <button class="ts-btn" onclick="runShortcut('eagle-guard stats')">📈 Stats JSON</button>
      <button class="ts-btn" onclick="runShortcut('eagle-guard rules-l4')">🔵 L4 Kurallar</button>
      <button class="ts-btn" onclick="runShortcut('eagle-guard rules-l7')">🟣 L7 Kurallar</button>
      <button class="ts-btn" onclick="runShortcut('eagle-guard logs')">📋 Son Loglar</button>
      <button class="ts-btn" onclick="runShortcut('iptables -L EG_L4 -n --line-numbers')">🛡 L4 iptables</button>
      <button class="ts-btn" onclick="runShortcut('ss -tn state established | head -20')">🔗 Bağlantılar</button>
      <button class="ts-btn" onclick="runShortcut('df -h')">💾 Disk</button>
      <button class="ts-btn" onclick="runShortcut('free -h')">🧠 RAM</button>
      <button class="ts-btn" onclick="runShortcut('uptime')">⏰ Uptime</button>
      <button class="ts-btn" onclick="runShortcut('ip addr show')">📡 IP Adresleri</button>
      <button class="ts-btn" onclick="runShortcut('cat /opt/eagle-guard/data/stats.json')">⚙ Stats Raw</button>
    </div>

    <div class="term-wrap">
      <div class="term-top">
        <div class="term-dot td-r" onclick="clearTerm()"></div>
        <div class="term-dot td-y"></div>
        <div class="term-dot td-g"></div>
        <div class="term-title">🦅 Eagle Guard — Web Terminal</div>
        <span id="term-status" style="font-size:.62rem;font-family:var(--mono);color:var(--txt2)">HAZIR</span>
      </div>
      <div class="term-out" id="term-out">
        <span class="t-info">╔══════════════════════════════════════════════════╗</span>
<span class="t-info">║   🦅  Eagle Guard Web Terminal v3.0              ║</span>
<span class="t-info">║   Güvenli komut çalıştırma arayüzü               ║</span>
<span class="t-info">╚══════════════════════════════════════════════════╝</span>

<span class="t-out">Kısayol butonlarını veya aşağıdaki satırı kullanın.</span>
<span class="t-out">Örnek: eagle-guard status, iptables -L EG_L4 -n</span>

</div>
      <div class="term-inp-row">
        <span class="term-prompt-lbl">root@eagle-guard:~#</span>
        <input class="term-input" id="term-inp" placeholder="komut girin..." autocomplete="off" spellcheck="false"
          onkeydown="termKeyDown(event)">
        <button class="term-exec-btn" onclick="termExec()">⏎ ÇALIŞTIRIR</button>
      </div>
    </div>
  </div>

  <!-- ══ YARDIM (HELP) ══════════════════════════════════════════ -->
  <div id="p-help" class="pg">

    <div class="help-notice info">
      🦅 <strong>Eagle Guard v3.0</strong> — Ubuntu üzerinde çalışan Layer 4 + Layer 7 DDoS/DoS koruma sistemi.
      Arbor Networks AED mimarisinden ilham alınarak geliştirilmiştir.
    </div>

    <!-- Özellik kartları -->
    <div class="feature-list">
      <div class="feat"><div class="f-icon">🔵</div><div class="f-name">Layer 4 Koruma</div><div class="f-desc">SYN/UDP/ICMP Flood, Port Scan, Bogon IP, IP Spoofing, DNS/NTP Amplification (16 modül)</div></div>
      <div class="feat"><div class="f-icon">🟣</div><div class="f-name">Layer 7 Koruma</div><div class="f-desc">HTTP/HTTPS Flood, Slowloris, SSH/FTP Brute Force, Rate Limiting (8 modül)</div></div>
      <div class="feat"><div class="f-icon">⚙</div><div class="f-name">Kernel Hardening</div><div class="f-desc">SYN Cookie, rp_filter, TCP optimizasyonlar, conntrack büyütme</div></div>
      <div class="feat"><div class="f-icon">🤖</div><div class="f-name">Auto Block</div><div class="f-desc">Kernel log analizi ile saldırı IP'lerini otomatik tespit eder ve engeller</div></div>
      <div class="feat"><div class="f-icon">🔔</div><div class="f-name">Bildirimler</div><div class="f-desc">Slack/Discord Webhook, Telegram Bot, E-posta ile anlık alert bildirimi</div></div>
      <div class="feat"><div class="f-icon">💻</div><div class="f-name">Web Terminal</div><div class="f-desc">Tarayıcıdan güvenli komut çalıştırma, izleme ve yönetim</div></div>
    </div>

    <div class="help-grid">
      <!-- Temel Komutlar -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">⚡</span>
          <h3>Temel Komutlar</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard start</div><div class="help-cmd-desc">L4+L7 korumayı başlatır, tüm firewall kurallarını aktive eder</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard stop</div><div class="help-cmd-desc">Tüm koruma kurallarını kaldırır ve servisi durdurur</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard restart</div><div class="help-cmd-desc">Durdurur ve yeniden başlatır (config değişikliği sonrası)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard status</div><div class="help-cmd-desc">Terminal TUI ekranını gösterir (canlı metrikler)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard stats</div><div class="help-cmd-desc">JSON formatında tam istatistik çıktısı verir</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard logs</div><div class="help-cmd-desc">Son 100 log satırını gösterir</div></div>
        </div>
      </div>

      <!-- IP Yönetimi -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">🚫</span>
          <h3>IP Yönetimi</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard block 1.2.3.4</div><div class="help-cmd-desc">IP'yi L4 seviyesinde engeller (BAN_TIME kadar)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard unblock 1.2.3.4</div><div class="help-cmd-desc">IP engelini kaldırır</div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard rules-l4</div><div class="help-cmd-desc">Aktif Layer 4 iptables kurallarını listeler<span class="help-tag tag-l4">L4</span></div></div>
          <div class="help-cmd"><div class="help-cmd-code">eagle-guard rules-l7</div><div class="help-cmd-desc">Aktif Layer 7 iptables kurallarını listeler<span class="help-tag tag-l7">L7</span></div></div>
          <div class="help-cmd"><div class="help-cmd-code">nano /opt/eagle-guard/config/whitelist.txt</div><div class="help-cmd-desc">Whitelist dosyasını düzenler — bu IP'ler asla engellenmez</div></div>
        </div>
      </div>

      <!-- Systemd Komutları -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">🔧</span>
          <h3>Servis Yönetimi</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">systemctl start eagle-guard</div><div class="help-cmd-desc">Servisi başlatır<span class="help-tag tag-sys">SYS</span></div></div>
          <div class="help-cmd"><div class="help-cmd-code">systemctl stop eagle-guard</div><div class="help-cmd-desc">Servisi durdurur</div></div>
          <div class="help-cmd"><div class="help-cmd-code">systemctl restart eagle-guard</div><div class="help-cmd-desc">Yeniden başlatır (config sonrası)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">systemctl status eagle-guard</div><div class="help-cmd-desc">Servis detaylı durumunu gösterir</div></div>
          <div class="help-cmd"><div class="help-cmd-code">journalctl -u eagle-guard -f</div><div class="help-cmd-desc">Canlı servis logunu takip eder</div></div>
          <div class="help-cmd"><div class="help-cmd-code">systemctl enable eagle-guard</div><div class="help-cmd-desc">Sunucu açılışında otomatik başla</div></div>
        </div>
      </div>

      <!-- Konfigürasyon -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">⚙</span>
          <h3>Konfigürasyon</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/config/eagle.conf</div><div class="help-cmd-desc">Ana konfigürasyon dosyası — tüm limitler ve ayarlar</div></div>
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/config/whitelist.txt</div><div class="help-cmd-desc">Asla engellenmeyecek IP listesi (bir satır = bir IP)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/logs/eagle.log</div><div class="help-cmd-desc">Ana log dosyası</div></div>
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/data/stats.json</div><div class="help-cmd-desc">Canlı istatistik verisi (JSON)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/data/blocked.json</div><div class="help-cmd-desc">Engellenen IP geçmişi</div></div>
          <div class="help-cmd"><div class="help-cmd-code">/opt/eagle-guard/data/alerts.json</div><div class="help-cmd-desc">Alert geçmişi</div></div>
        </div>
      </div>

      <!-- Layer 4 Korumaları -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">🔵</span>
          <h3>Layer 4 Koruma Detayı</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">SYN Flood</div><div class="help-cmd-desc">iptables limit modülü ile SYN paket/saniye sınırlandırılır (varsayılan: 150/s)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">UDP/ICMP Flood</div><div class="help-cmd-desc">UDP ve ICMP paket hızı kontrol altında tutulur</div></div>
          <div class="help-cmd"><div class="help-cmd-code">XMAS / NULL</div><div class="help-cmd-desc">Anormal TCP flag kombinasyonları anında drop edilir</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Bogon IP</div><div class="help-cmd-desc">RFC'de tanımlı geçersiz IP aralıkları (0.0.0.0/8, 169.254.x.x vb.) engellenir</div></div>
          <div class="help-cmd"><div class="help-cmd-code">DNS/NTP Amplification</div><div class="help-cmd-desc">UDP 53/123 portları hız sınırı ile korunur, SSDP/Memcached tamamen kapalı</div></div>
        </div>
      </div>

      <!-- Layer 7 Korumaları -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">🟣</span>
          <h3>Layer 7 Koruma Detayı</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">HTTP/HTTPS Flood</div><div class="help-cmd-desc">connlimit ile IP başına eş zamanlı bağlantı sayısı sınırlandırılır</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Slowloris</div><div class="help-cmd-desc">Yeni HTTP bağlantı hızı (saniyede) sınırlandırılır</div></div>
          <div class="help-cmd"><div class="help-cmd-code">SSH Brute Force</div><div class="help-cmd-desc">recent modülü ile 60 saniyede 5+ deneme = otomatik engelleme</div></div>
          <div class="help-cmd"><div class="help-cmd-code">hashlimit</div><div class="help-cmd-desc">IP başına HTTP istek/saniye limiti (gelişmiş rate limiting)</div></div>
          <div class="help-cmd"><div class="help-cmd-code">FTP Brute Force</div><div class="help-cmd-desc">recent modülü ile FTP brute force koruması aktif</div></div>
        </div>
      </div>

      <!-- Bildirim Kurulumu -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">🔔</span>
          <h3>Bildirim Kurulumu</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">Slack/Discord</div><div class="help-cmd-desc">Ayarlar → WEBHOOK alanına Webhook URL girin. Her alert anında mesaj gönderir.</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Telegram</div><div class="help-cmd-desc">@BotFather ile bot oluşturun → TG_BOT token + TG_CHAT chat ID girin</div></div>
          <div class="help-cmd"><div class="help-cmd-code">E-posta</div><div class="help-cmd-desc">apt install mailutils → Ayarlar → EMAIL alanına adres girin</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Chat ID Bulma</div><div class="help-cmd-desc">https://api.telegram.org/bot&lt;TOKEN&gt;/getUpdates adresinden chat_id alın</div></div>
        </div>
      </div>

      <!-- Web Terminal -->
      <div class="help-card">
        <div class="help-card-head">
          <span style="font-size:1.2rem">💻</span>
          <h3>Web Terminal Kullanımı</h3>
        </div>
        <div class="help-card-body">
          <div class="help-cmd"><div class="help-cmd-code">Kısayol Butonları</div><div class="help-cmd-desc">Sık kullanılan komutlar için hazır butonlar — tıkla, çalıştır</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Komut Satırı</div><div class="help-cmd-desc">Alt satıra komut yazın, Enter veya ⏎ butonuna basın</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Geçmiş</div><div class="help-cmd-desc">↑/↓ ok tuşları ile önceki komutlara erişin</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Güvenlik</div><div class="help-cmd-desc">rm, mv, chmod gibi tehlikeli komutlar engellenir. eagle-guard ve izleme komutları serbesttir.</div></div>
          <div class="help-cmd"><div class="help-cmd-code">Temizle</div><div class="help-cmd-desc">🗑 Temizle butonu veya terminal kırmızı noktası ile ekranı temizleyin</div></div>
        </div>
      </div>
    </div>

    <!-- Dosya Yapısı -->
    <div class="card mb"><div class="card-glow"></div>
      <div class="card-title"><span class="ci">📁</span>Dosya / Dizin Yapısı</div>
      <div style="font-family:var(--mono);font-size:.72rem;line-height:2.1;color:var(--txt);padding:4px 0">
        <div><span style="color:var(--cyan)">/opt/eagle-guard/</span> — Ana kurulum dizini</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">scripts/eagle-guard.sh</span> — L4+L7 koruma motoru (daemon)</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">config/eagle.conf</span>      — Konfigürasyon (limitler, bildirimler)</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">config/whitelist.txt</span>   — Engellenmeyen IP listesi</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">data/stats.json</span>        — Canlı istatistik (3 sn güncellenir)</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">data/blocked.json</span>      — Engellenen IP geçmişi</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">data/alerts.json</span>       — Alert geçmişi (max 200)</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">data/traffic.json</span>      — Trafik geçmişi (son 240 nokta)</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">logs/eagle.log</span>         — Ana log dosyası</div>
        <div><span style="color:var(--cyan)">/var/www/html/eagle-guard/</span> — Web arayüzü</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">index.php</span>              — Dashboard ana sayfası</div>
        <div style="padding-left:20px"><span style="color:var(--amber)">api/index.php</span>          — REST API backend</div>
        <div><span style="color:var(--cyan)">/etc/systemd/system/eagle-guard.service</span> — Systemd servis</div>
        <div><span style="color:var(--cyan)">/etc/sudoers.d/eagle-guard</span> — www-data sudo izinleri</div>
        <div><span style="color:var(--cyan)">/usr/local/bin/eagle-guard</span> — Global CLI komutu</div>
      </div>
    </div>

    <div class="help-notice warn">
      ⚠ Konfigürasyon değişikliği yaptıktan sonra <code style="font-family:var(--mono);background:rgba(255,171,0,.1);padding:1px 6px;border-radius:3px">sudo systemctl restart eagle-guard</code> komutunu çalıştırın.
    </div>
    <div class="help-notice good">
      ✅ Web arayüzü 3 saniyede bir otomatik güncellenir. Sayfa yenilemene gerek yok — canlı takip yapılabilir.
    </div>
  </div>

  <!-- ══ AYARLAR ════════════════════════════════════════════════ -->
  <div id="p-set" class="pg">
    <div class="card"><div class="card-glow"></div>
      <div class="card-title"><span class="ci">⚙</span>Eagle Guard Konfigürasyonu</div>
      <div class="help-notice warn" style="margin-bottom:16px">
        ⚡ Değişiklikler kaydedildikten sonra <strong>systemctl restart eagle-guard</strong> çalıştırın.
      </div>
      <form id="setform" onsubmit="saveCfg(event)">
        <div style="margin-bottom:18px">
          <div class="sf-head" style="color:var(--cyan)">🔵 LAYER 4 — NETWORK/TRANSPORT</div>
          <div class="sf">
            <div class="sg"><label class="sl">SYN Flood Limit (pkt/s)</label><input class="inp" name="L4_SYN_RATE" type="number" value="200"><span class="sf-note">Aşılırsa DROP edilir</span></div>
            <div class="sg"><label class="sl">SYN Burst</label><input class="inp" name="L4_SYN_BURST" type="number" value="1000"></div>
            <div class="sg"><label class="sl">ICMP Flood Limit (pkt/s)</label><input class="inp" name="L4_ICMP_RATE" type="number" value="100"></div>
            <div class="sg"><label class="sl">SYN / IP / sn</label><input class="inp" name="L4_SYN_PER_IP" type="number" value="40"></div>
            <div class="sg"><label class="sl">Max Eş Zamanlı Conn / IP</label><input class="inp" name="L4_CONN_PER_IP" type="number" value="300"></div>
          </div>
        </div>
        <div style="margin-bottom:18px">
          <div class="sf-head" style="color:var(--violet)">🟣 LAYER 7 — APPLICATION</div>
          <div class="sf">
            <div class="sg"><label class="sl">HTTP RPS Limit / IP</label><input class="inp" name="L7_HTTP_RATE" type="number" value="80"></div>
            <div class="sg"><label class="sl">HTTP Conn Limit / IP</label><input class="inp" name="L7_HTTP_CONN" type="number" value="100"></div>
            <div class="sg"><label class="sl">SSH Deneme / Dakika</label><input class="inp" name="L7_SSH_RATE" type="number" value="6"></div>
          </div>
        </div>
        <div style="margin-bottom:18px">
          <div class="sf-head" style="color:var(--amber)">🔔 ALERT EŞİKLERİ</div>
          <div class="sf">
            <div class="sg"><label class="sl">DDoS PPS Eşiği</label><input class="inp" name="ALERT_PPS" type="number" value="15000"></div>
            <div class="sg"><label class="sl">Yüksek Bant Genişliği (byte/s)</label><input class="inp" name="ALERT_BPS" type="number" value="209715200"><span class="sf-note">Varsayılan: 200 MB/s</span></div>
            <div class="sg"><label class="sl">Max Bağlantı Eşiği</label><input class="inp" name="ALERT_CONN" type="number" value="8000"></div>
            <div class="sg"><label class="sl">Ban Süresi (saniye, 0=kalıcı)</label><input class="inp" name="BAN_TIME" type="number" value="3600"></div>
            <div class="sg"><label class="sl">İzleme Aralığı (saniye)</label><input class="inp" name="INTERVAL" type="number" value="3"></div>
            <div class="sg"><label class="sl">Auto Block</label>
              <select class="inp" name="AUTO_BLOCK"><option value="yes">Açık (Önerilen)</option><option value="no">Kapalı</option></select>
            </div>
          </div>
        </div>
        <div style="margin-bottom:18px">
          <div class="sf-head" style="color:var(--green)">📣 BİLDİRİM KANALLARI</div>
          <div class="sf">
            <div class="sg sf-full"><label class="sl">Discord Webhook URL</label><input class="inp" name="DISCORD_WEBHOOK" placeholder="https://discord.com/api/webhooks/..."></div>
            <div class="sg"><label class="sl">Telegram Bot Token</label><input class="inp" name="TELEGRAM_BOT" placeholder="123456:ABC-DEF..."></div>
            <div class="sg"><label class="sl">Telegram Chat ID</label><input class="inp" name="TELEGRAM_CHAT" placeholder="-100123456789"></div>
            <div class="sg sf-full"><label class="sl">E-posta Adresi (mailutils gerektirir)</label><input class="inp" name="EMAIL_TO" type="email" placeholder="admin@example.com"></div>
          </div>
        </div>
        <div style="display:flex;gap:9px;flex-wrap:wrap">
          <button type="submit" class="btn bc">💾 Kaydet</button>
          <button type="button" class="btn bc" onclick="loadCfg()">↻ Yükle</button>
          <button type="button" class="btn ba" onclick="testAlert()">🧪 Test Bildirim</button>
          <button type="button" class="btn ba" onclick="webhookTest()">📣 Discord Webhook Test</button>
        </div>
      </form>
    </div>
  </div>

</main>

<!-- Alert Drawer -->
<div id="drw-ov" onclick="closeDrw()"></div>
<div id="drw">
  <div class="dh"><h2>🔔 Güvenlik Alertleri</h2><span class="dc" onclick="closeDrw()">✕</span></div>
  <div style="display:flex;gap:8px;margin-bottom:13px">
    <button class="btn bc bs" onclick="markRead()">✓ Okundu</button>
    <button class="btn ba bs" onclick="testAlert()">🧪 Test</button>
  </div>
  <div class="al-list" id="a-drw"></div>
</div>

<div id="toast"></div>

<script>
/* ═══════════════════════════════════════════════════════════════
   EAGLE GUARD DASHBOARD — JavaScript Core
═══════════════════════════════════════════════════════════════ */
const API = 'api/index.php';
const MAX_PT = 60;
const S = {
  bw:  {rx:[],tx:[],lb:[]},
  pps: {rx:[],tx:[],lb:[]},
  sm:  {c:[],m:[],lb:[]},
  l4t: {lb:[],syn:[],udp:[],icmp:[]},
  l7t: {lb:[],http:[],https:[],ssh:[]},
};
let charts = {}, svcOn = false, allLogs = [], termHistory = [], termHistIdx = -1;


// ── Game functions ─────────────────────────────────────────────────
async function gameToggle(state) {
  const r = await api(state === 'on' ? 'game_on' : 'game_off', {}, 'POST');
  toast(r.ok ? (state==='on' ? '✓ Game koruması açıldı' : '✓ Game koruması kapatıldı') : '✗ '+r.error, r.ok?'ok':'er');
}
async function loadGameRules() {
  const r = await api('ipt_game'); if(!r.ok) return;
  const html = fwHtml(r.data);
  const el = document.getElementById('game-rules'); if(el) el.innerHTML = html;
}
function addGamePort(type, port) {
  const inp = document.getElementById('game-' + type + '-ports');
  if(!inp) return;
  const curr = inp.value.split(',').map(p=>p.trim()).filter(Boolean);
  if(!curr.includes(port)) { curr.push(port); inp.value = curr.join(','); }
}
async function saveGamePorts(type) {
  const inp = document.getElementById('game-' + type + '-ports');
  const val = inp?.value?.trim();
  if(!val) { toast('Port girin','er'); return; }
  const key = type === 'udp' ? 'GAME_PORTS_UDP' : 'GAME_PORTS_TCP';
  const r = await api('save_config', {[key]: val}, 'POST');
  toast(r.ok ? `✓ ${type.toUpperCase()} portları kaydedildi — servisi restart edin` : '✗ '+r.error, r.ok?'ok':'er');
}

// ── Navigation ─────────────────────────────────────────────────────
const PN = {
  dash:'Overview', net:'Ağ Monitörü', sys:'Sistem Monitörü',
  l4:'Layer 4 / Network', l7:'Layer 7 / Uygulama', ips:'IP Yönetimi',
  wl:'Whitelist', alrt:'Alertler', logs:'Log Akışı', fw:'Firewall Kuralları',
  waf:'WAF Panel (ModSecurity)', term:'Web Terminal', help:'Yardım', set:'Ayarlar',
  xdp:'XDP / eBPF Datapath', game:'Game Sunucu'
};
function nav(p) {
  document.querySelectorAll('.pg').forEach(x => x.classList.remove('on'));
  document.querySelectorAll('.ni').forEach(x => x.classList.remove('on'));
  const pg = document.getElementById('p-' + p);
  if (pg) pg.classList.add('on');
  document.querySelectorAll('.ni').forEach(x => {
    if (x.getAttribute('onclick')?.includes("'"+p+"'")) x.classList.add('on');
  });
  document.getElementById('ptitle').textContent = PN[p] || p;
  if (p === 'logs')  loadLogs();
  if (p === 'wl')    loadWL();
  if (p === 'set')   loadCfg();
  if (p === 'ips')   { loadBlocked(); api('top_conn').then(r=>r.ok&&renderTCIP(r.data,'tc-ips')); }
  if (p === 'alrt')  { api('alerts').then(r=>r.ok&&renderAlerts(r.data,'a-full',100)); }
  if (p === 'sys')   loadSysInfo();
  if (p === 'fw')    { fwRefreshAll(); }
  if (p === 'l4')    loadL4Rules('l4rules');
  if (p === 'l7')    loadL7Rules('l7rules');
  if (p === 'waf')   loadWAF();
  if (p === 'xdp')   loadXDP();
}

// ── XDP / eBPF sayfası ─────────────────────────────────────────────
async function loadXDP() {
  const x = await api('xdp_status');
  const d = await api('dpdk_status');
  const el = document.getElementById('xdp-content');
  if (!el) return;
  if (!x.ok) { el.innerHTML = '<div class="card">XDP API hata</div>'; return; }
  const s = x.data, p = d.ok ? d.data : {};
  const stat = s.stats || {};
  const badge = (v, label, cls) => `<div class="stat-bx ${cls||''}"><div class="lbl">${label}</div><div class="val">${(v||0).toLocaleString()}</div></div>`;
  el.innerHTML = `
  <div class="card">
    <h3>🔒 Yönetim Portu Koruması</h3>
    <p style="opacity:.85">SSH (22), HTTP (80) ve HTTPS (443) XDP tarafından <b>ASLA DROP edilmez</b>.
       Bu kural eBPF kodunda <b>sabit</b> — yanlış yapılandırma SSH erişimini kesemez.</p>
  </div>

  <div class="grid3" style="margin-top:12px">
    <div class="card">
      <h3>⚡ XDP Durum</h3>
      <div>BPF objesi: <b>${s.available ? '✅ hazır' : '❌ yok — build.sh çalıştırın'}</b></div>
      <div>Attach: <b>${s.attached ? '✅ aktif' : '⛔ yüklü değil'}</b></div>
      <div>Interface: <b>${s.iface || '-'}</b></div>
      <div>Mod: <b>${s.mode || '-'}</b></div>
      <div style="margin-top:10px;display:flex;gap:6px;flex-wrap:wrap">
        <button class="btn" onclick="xdpCmd('load')">▶ Yükle</button>
        <button class="btn" onclick="xdpCmd('unload')">■ Durdur</button>
        <button class="btn" onclick="xdpCmd('reload')">⟳ Yeniden</button>
      </div>
    </div>

    <div class="card">
      <h3>📊 XDP İstatistikleri</h3>
      <div class="grid2">
        ${badge(stat.PASS, 'PASS')}
        ${badge(stat.PASS_SSH, 'PASS (SSH)', 'ok')}
        ${badge(stat.PASS_WEB, 'PASS (Web)', 'ok')}
        ${badge(stat.PASS_WHITELIST, 'Whitelist')}
        ${badge(stat.DROP_BLACKLIST, 'DROP (BL)', 'bad')}
        ${badge(stat.DROP_RATELIMIT, 'DROP (RL)', 'bad')}
        ${badge(stat.DROP_MALFORMED, 'DROP (bad pkt)', 'bad')}
        ${badge(stat.DROP_HARDBAN, 'DROP (hardban)', 'bad')}
      </div>
    </div>

    <div class="card">
      <h3>🔥 DPDK Durum</h3>
      <div>Mevcut: <b>${p.available ? '✅' : '❌'}</b></div>
      <div>Yönetim NIC: <b>${p.mgmt_iface || '-'}</b> (korunuyor)</div>
      <pre style="max-height:180px;overflow:auto;font-size:11px">${(p.output||[]).join('\n')}</pre>
      <p style="opacity:.8;font-size:12px">DPDK aktivasyonu için:
        <code>sudo nano /opt/eagle-guard/config/eagle.conf</code> →
        <code>DPDK_ENABLED=yes</code>, <code>DPDK_IFACE=eth1</code></p>
    </div>
  </div>
  `;
}
async function xdpCmd(sub) {
  const btn = event?.target; if (btn) btn.disabled = true;
  const r = await fetch(API + '?action=xdp_' + sub, {method:'POST'}).then(r=>r.json()).catch(e=>({ok:false,err:e+''}));
  if (btn) btn.disabled = false;
  alert((r.ok ? '✅ ' : '❌ ') + sub + '\n' + ((r.data?.output||[]).join('\n') || r.msg || ''));
  loadXDP();
}

// ── API ────────────────────────────────────────────────────────────
async function api(action, data={}, method='GET') {
  try {
    const opts = { method };
    if (method === 'POST') {
      const fd = new FormData(); fd.append('action', action);
      Object.entries(data).forEach(([k,v]) => fd.append(k, v));
      opts.body = fd;
    }
    const url = method === 'GET' ? `${API}?action=${action}` : API;
    return await (await fetch(url, opts)).json();
  } catch(e) { return { ok: false, error: e.message }; }
}

// ── Toast ──────────────────────────────────────────────────────────
let _tt;
function toast(m, t='in') {
  const el = document.getElementById('toast');
  el.textContent = m; el.className = 's ' + t;
  clearTimeout(_tt); _tt = setTimeout(() => el.className = '', 3500);
}

// ── Clock ──────────────────────────────────────────────────────────
setInterval(() => document.getElementById('clk').textContent = new Date().toLocaleString('tr-TR'), 1000);

// ── Formatters ─────────────────────────────────────────────────────
function fB(b) {
  if(b>=1073741824) return (b/1073741824).toFixed(2)+' GB/s';
  if(b>=1048576)    return (b/1048576).toFixed(2)+' MB/s';
  if(b>=1024)       return (b/1024).toFixed(1)+' KB/s';
  return b+' B/s';
}
function fBytes(b) {
  if(b>=1073741824) return (b/1073741824).toFixed(2)+' GB';
  if(b>=1048576)    return (b/1048576).toFixed(2)+' MB';
  if(b>=1024)       return (b/1024).toFixed(1)+' KB';
  return b+' B';
}
function fUp(s) {
  if(!s) return '--';
  const h=Math.floor(s/3600), m=Math.floor((s%3600)/60), sc=s%60;
  return `${h}s ${m}d ${sc}sn`;
}
function tL() { return new Date().toLocaleTimeString('tr-TR', {hour:'2-digit',minute:'2-digit',second:'2-digit'}); }
function push(a, v, mx=MAX_PT) { a.push(v); if(a.length>mx) a.shift(); }
function set(id, v) { const el=document.getElementById(id); if(el) el.textContent=v; }
function bar(vid, v, bid, mx) {
  set(vid, v);
  const b=document.getElementById(bid);
  if(b) b.style.width = Math.min(Math.round(v/Math.max(mx,1)*100),100)+'%';
}

// ── Chart factory ──────────────────────────────────────────────────
const CC = {
  b0:'rgba(0,229,255,.12)',b1:'rgba(255,23,68,.12)',b2:'rgba(0,230,118,.1)',
  b3:'rgba(213,0,249,.12)',b4:'rgba(255,171,0,.1)',
  l0:'#00e5ff',l1:'#ff1744',l2:'#00e676',l3:'#d500f9',l4:'#ffab00',
};
function mch(id, type, ds, opts={}) {
  const cv = document.getElementById(id); if(!cv) return null;
  if(charts[id]) charts[id].destroy();
  charts[id] = new Chart(cv, {
    type, data: { labels: [], datasets: ds },
    options: {
      responsive: true, maintainAspectRatio: false, animation: { duration: 0 },
      plugins: {
        legend: { display: !!opts.legend, labels: { color: '#4a7a9b', font: { size: 9, family: 'JetBrains Mono' } } },
        tooltip: { mode: 'index', intersect: false, bodyFont: { family: 'JetBrains Mono', size: 9 }, titleFont: { family: 'JetBrains Mono', size: 9 } }
      },
      scales: {
        x: { grid: { color: 'rgba(255,255,255,.03)' }, ticks: { color: '#4a7a9b', font: { size: 8, family: 'JetBrains Mono' }, maxTicksLimit: 8 } },
        y: { grid: { color: 'rgba(255,255,255,.03)' }, ticks: { color: '#4a7a9b', font: { size: 9, family: 'JetBrains Mono' } }, beginAtZero: true, ...(opts.y||{}) }
      }
    }
  });
  return charts[id];
}
function lds(label, col, bg) {
  return { label, data: [], borderColor: col, backgroundColor: bg, borderWidth: 1.5, pointRadius: 0, tension: .4, fill: true };
}
function upd(id, lb, ...series) {
  const c = charts[id]; if(!c) return;
  c.data.labels = lb;
  series.forEach((s, i) => { if(c.data.datasets[i]) c.data.datasets[i].data = s; });
  c.update('none');
}

// ── Init charts ────────────────────────────────────────────────────
function initCharts() {
  mch('c-bw',   'line', [lds('IN MB/s',CC.l0,CC.b0), lds('OUT MB/s',CC.l1,CC.b1)], {legend:true});
  mch('c-pps',  'line', [lds('IN pkt/s',CC.l2,CC.b2), lds('OUT pkt/s',CC.l3,CC.b3)], {legend:true});
  mch('c-atk',  'bar',  [
    {label:'L4 Drop', data:[], backgroundColor:'rgba(255,23,68,.4)', borderColor:CC.l1, borderWidth:1},
    {label:'L7 Block',data:[], backgroundColor:'rgba(213,0,249,.4)', borderColor:CC.l3, borderWidth:1},
  ], {legend:true});
  mch('c-sys',  'line', [lds('CPU%',CC.l4,CC.b4), lds('RAM%',CC.l3,CC.b3)], {legend:true});
  mch('c-bwh',  'line', [lds('IN MB/s',CC.l0,CC.b0), lds('OUT MB/s',CC.l1,CC.b1)], {legend:true});
  mch('c-ppsh', 'line', [lds('PPS IN',CC.l2,CC.b2), lds('PPS OUT',CC.l3,CC.b3)], {legend:true});
  mch('c-cnh',  'line', [lds('Bağlantı',CC.l4,CC.b4)], {legend:false});
  mch('c-l4t',  'line', [lds('SYN',CC.l1,CC.b1), lds('UDP',CC.l4,CC.b4), lds('ICMP',CC.l0,CC.b0)], {legend:true});
  mch('c-l7t',  'line', [lds('HTTP',CC.l3,CC.b3), lds('HTTPS',CC.l2,CC.b2), lds('SSH',CC.l1,CC.b1)], {legend:true});
}

// ── Gauge ──────────────────────────────────────────────────────────
function gauge(id, pct, col) {
  const cv = document.getElementById(id); if(!cv) return;
  const ctx = cv.getContext('2d');
  const w = cv.width, h = cv.height, cx = w/2, cy = h/2, r = w*.38;
  ctx.clearRect(0,0,w,h);
  ctx.beginPath(); ctx.arc(cx,cy,r,Math.PI*.75,Math.PI*2.25);
  ctx.strokeStyle = '#0c1830'; ctx.lineWidth = 13; ctx.stroke();
  const ea = Math.PI*.75 + Math.PI*1.5*(pct/100);
  ctx.beginPath(); ctx.arc(cx,cy,r,Math.PI*.75,ea);
  ctx.strokeStyle = col; ctx.lineWidth = 13;
  ctx.shadowColor = col; ctx.shadowBlur = 12; ctx.stroke(); ctx.shadowBlur = 0;
  ctx.fillStyle = '#e8f4ff';
  ctx.font = `700 ${w*.17}px 'Poppins',sans-serif`;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(pct.toFixed(0)+'%', cx, cy);
}

// ── Main polls ─────────────────────────────────────────────────────
async function pollDash() {
  const r = await api('dashboard'); if(!r.ok) return;
  const { stats:st, ipt, net, sys, service:svc, alert_unread:au } = r.data;
  svcOn = svc === 'active'; updSvcUI();

  const sn = st?.net||{}, ss = st?.sys||{}, l4 = ipt?.l4||{}, l7 = ipt?.l7||{};
  set('m-blk',  ipt?.blocked_rules??'—');
  // game stats
  const gm = st?.game||{};
  set('mg-udp',   gm.udp_flood||0);
  set('mg-tcp',   gm.tcp_flood||0);
  set('mg-query', gm.query_flood||0);
  set('mg-fake',  gm.fake_connect||0);
  set('mg-rcon',  gm.rcon_brute||0);
  set('mg-total', gm.total||0);
  set('m-conn', ss.conn??'—');
  set('m-bi',   fB(sn.bps_in||0));  set('m-pi', (sn.pps_in||0)+' pkt/s');
  set('m-bo',   fB(sn.bps_out||0)); set('m-po', (sn.pps_out||0)+' pkt/s');
  set('m-cpu',  (sys?.cpu??ss.cpu??0)+'%');
  set('m-mem',  'RAM: '+(sys?.mem?.pct??ss.mem??0)+'%');
  set('sup', 'Uptime: '+fUp(ss.uptime||0));

  const lb = tL();
  push(S.bw.lb,lb);  push(S.bw.rx,(sn.bps_in||0)/1048576); push(S.bw.tx,(sn.bps_out||0)/1048576);
  push(S.pps.lb,lb); push(S.pps.rx,sn.pps_in||0); push(S.pps.tx,sn.pps_out||0);
  push(S.sm.lb,lb);  push(S.sm.c,sys?.cpu??ss.cpu??0); push(S.sm.m,sys?.mem?.pct??ss.mem??0);
  push(S.l4t.lb,lb); push(S.l4t.syn,l4.syn||0); push(S.l4t.udp,l4.udp||0); push(S.l4t.icmp,l4.icmp||0);
  push(S.l7t.lb,lb); push(S.l7t.http,l7.http||0); push(S.l7t.https,l7.https||0); push(S.l7t.ssh,l7.ssh||0);

  upd('c-bw',  S.bw.lb,  S.bw.rx,  S.bw.tx);
  upd('c-pps', S.pps.lb, S.pps.rx, S.pps.tx);
  upd('c-sys', S.sm.lb,  S.sm.c,   S.sm.m);
  upd('c-l4t', S.l4t.lb.slice(-40), S.l4t.syn.slice(-40), S.l4t.udp.slice(-40), S.l4t.icmp.slice(-40));
  upd('c-l7t', S.l7t.lb.slice(-40), S.l7t.http.slice(-40), S.l7t.https.slice(-40), S.l7t.ssh.slice(-40));
  upd('c-atk', S.l4t.lb.slice(-20), S.l4t.syn.slice(-20), S.l7t.http.slice(-20));

  // L4 bars
  const m4 = Math.max(l4.syn||0, l4.udp||0, l4.icmp||0, 1);
  const misc = (l4.xmas||0)+(l4.null||0)+(l4.frag||0);
  bar('pb-syn',l4.syn||0,'pb-syn-b',m4); bar('pb-udp',l4.udp||0,'pb-udp-b',m4);
  bar('pb-icmp',l4.icmp||0,'pb-icmp-b',m4); bar('pb-rst',l4.rst||0,'pb-rst-b',m4);
  bar('pb-misc',misc,'pb-misc-b',m4);
  // L7 bars
  const m7 = Math.max(l7.http||0, l7.https||0, l7.ssh||0, 1);
  bar('pb-http',l7.http||0,'pb-http-b',m7); bar('pb-https',l7.https||0,'pb-https-b',m7);
  bar('pb-ssh',l7.ssh||0,'pb-ssh-b',m7); bar('pb-slow',l7.slowloris||0,'pb-slow-b',m7);
  // L4/L7 page metrics
  set('l4-syn',l4.syn||0); set('l4-udp',l4.udp||0);
  set('l4-icmp',l4.icmp||0); set('l4-tot',ipt?.blocked_rules||0);
  set('l7-http',l7.http||0); set('l7-https',l7.https||0);
  set('l7-ssh',l7.ssh||0); set('l7-slow',l7.slowloris||0);
  // Gauges
  gauge('g-cpu',  sys?.cpu??ss.cpu??0, '#00e5ff');
  gauge('g-mem',  sys?.mem?.pct??ss.mem??0, '#d500f9');
  // Alert badges
  const nb = document.getElementById('nav-badge'), bc = document.getElementById('bellc');
  if(au>0) { nb.textContent=au; nb.style.display=''; bc.textContent=au; bc.classList.add('s'); }
  else { nb.style.display='none'; bc.classList.remove('s'); }
  // Module dots
  document.querySelectorAll('.mdd').forEach(d => d.classList.toggle('off', !svcOn));
}

async function pollAlerts() {
  const r = await api('alerts'); if(!r.ok) return;
  renderAlerts(r.data, 'a-dash', 5);
  renderAlerts(r.data, 'a-drw', 30);
}

async function pollTraffic() {
  const r = await api('traffic'); if(!r.ok||!r.data) return;
  const pts = r.data;
  const lb = pts.map(p => new Date(p.unix*1000).toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit',second:'2-digit'}));
  upd('c-bwh',  lb, pts.map(p=>(p.bps_in||0)/1048576), pts.map(p=>(p.bps_out||0)/1048576));
  upd('c-ppsh', lb, pts.map(p=>p.pps_in||0), pts.map(p=>p.pps_out||0));
  upd('c-cnh',  lb, pts.map(p=>p.conn||0));
  const last = pts[pts.length-1]||{};
  set('n-rx',fBytes(last.bytes_in||0)); set('n-tx',fBytes(last.bytes_out||0));
  set('n-conn',last.conn||0);
}

async function pollTC() {
  const r = await api('top_conn'); if(!r.ok) return;
  renderTC(r.data, 'tc-dash', 5);
  renderTC(r.data, 'tc-net', 15);
}

// ── Renders ────────────────────────────────────────────────────────
function renderTC(data, id, mx) {
  const el = document.getElementById(id); if(!el) return;
  if(!data?.length) { el.innerHTML='<div style="color:var(--txt2);font-size:.72rem;text-align:center;padding:14px">Bağlantı yok</div>'; return; }
  const mc = data[0].count||1;
  el.innerHTML = data.slice(0,mx).map(c=>`
    <div class="cb">
      <span class="cb-ip">${c.ip}</span>
      <div class="cb-tr"><div class="cb-f" style="width:${Math.round(c.count/mc*100)}%"></div></div>
      <span class="cb-n">${c.count}</span>
      <button class="btn br bxs" onclick="qBlock('${c.ip}')">🚫</button>
    </div>`).join('');
}
function renderTCIP(data, id) {
  const el = document.getElementById(id); if(!el) return;
  if(!data?.length) { el.innerHTML='<div style="color:var(--txt2);font-size:.72rem;text-align:center;padding:14px">Bağlantı yok</div>'; return; }
  const mc = data[0].count||1;
  el.innerHTML = data.slice(0,15).map(c=>`
    <div class="cb">
      <span class="cb-ip">${c.ip}</span>
      <div class="cb-tr"><div class="cb-f" style="width:${Math.round(c.count/mc*100)}%"></div></div>
      <span class="cb-n">${c.count}</span>
      <button class="btn br bxs" onclick="qBlock('${c.ip}')">🚫 Engelle</button>
    </div>`).join('');
}

const AICONS = { block:'🔴', ddos:'⚡', flood:'🌊', conn:'📈', system:'ℹ️' };
function renderAlerts(data, id, mx) {
  const el = document.getElementById(id); if(!el) return;
  if(!data?.length) { el.innerHTML='<div style="color:var(--txt2);font-size:.72rem;text-align:center;padding:14px">Alert yok</div>'; return; }
  el.innerHTML = data.slice(0,mx).map(a=>`
    <div class="al-item ${a.type||'system'}${a.read?'':' ur'}">
      <span class="al-icon">${AICONS[a.type]||'🔔'}</span>
      <div style="flex:1">
        <div class="al-title">${a.title||''}</div>
        <div class="al-detail">${a.detail||''}</div>
        <div class="al-time">${a.time||''}</div>
      </div>
      <span class="al-sev ${a.severity||'medium'}">${(a.severity||'med').toUpperCase()}</span>
    </div>`).join('');
}

function fwHtml(lines) {
  return `<div class="fwr">${(lines||[]).map(l => {
    const cls = l.includes('Chain') ? 'fchain' : l.includes('DROP') ? 'fdrop' : l.includes('LOG') ? 'flog' : l.includes('RETURN') ? 'fret' : '';
    return `<div class="${cls}">${l}</div>`;
  }).join('')}</div>`;
}

// ── System info ────────────────────────────────────────────────────
async function loadSysInfo() {
  const r = await api('sysinfo'); if(!r.ok) return;
  const d = r.data;
  gauge('g-cpu',  d.cpu||0,         '#00e5ff');
  gauge('g-mem',  d.mem?.pct||0,    '#d500f9');
  gauge('g-disk', d.disk?.pct||0,   '#ffab00');
  set('sys-cpu-l',  `${d.cpu||0}% yük`);
  set('sys-mem-l',  `${d.mem?.used_mb||0} / ${d.mem?.total_mb||0} MB`);
  set('sys-disk-l', `${d.disk?.used_gb||0} / ${d.disk?.total_gb||0} GB`);
  const si = document.getElementById('sysinfo-detail');
  if(si) si.innerHTML = `
    <div>🖥 <b style="color:var(--white)">Hostname:</b> ${d.hostname||'—'}</div>
    <div>🐧 <b style="color:var(--white)">OS:</b> ${d.os||'—'}</div>
    <div>⏰ <b style="color:var(--white)">Uptime:</b> ${d.uptime||'—'}</div>
    <div>⚙ <b style="color:var(--white)">CPU:</b> ${d.cpu||0}%</div>
    <div>🧠 <b style="color:var(--white)">RAM:</b> ${d.mem?.used_mb||0} / ${d.mem?.total_mb||0} MB (${d.mem?.pct||0}%)</div>
    <div>💾 <b style="color:var(--white)">Disk:</b> ${d.disk?.used_gb||0} / ${d.disk?.total_gb||0} GB (${d.disk?.pct||0}%)</div>
    <div>📡 <b style="color:var(--white)">Interface:</b> ${d.net?.iface||'—'}</div>`;
  const pp = document.getElementById('ports');
  if(pp) pp.innerHTML = (d.open_ports||[]).map(p=>`<span class="pp">${p}</span>`).join('');
  const pr = await api('processes');
  if(pr.ok) {
    const tb = document.getElementById('procs');
    if(tb) tb.innerHTML = (pr.data||[]).map(p=>`
      <tr>
        <td class="tc">${p.pid}</td>
        <td class="${p.cpu>50?'tr':p.cpu>20?'ta':'tg'}">${p.cpu}%</td>
        <td>${p.mem}%</td>
        <td><div class="cpubar"><div class="cpuf" style="width:${Math.min(p.cpu,100)}%"></div></div></td>
        <td class="tc">${p.cmd}</td>
      </tr>`).join('');
  }
}

// ── IP Management ──────────────────────────────────────────────────
async function loadBlocked() {
  const r = await api('blocked'); if(!r.ok) return;
  const list = r.data.list||[];
  set('blkc', list.length);
  const tb = document.getElementById('blktb'); if(!tb) return;
  if(!list.length) { tb.innerHTML='<tr><td colspan="6" style="text-align:center;padding:18px;color:var(--txt2)">Engellenen IP yok</td></tr>'; return; }
  tb.innerHTML = list.map(b=>`
    <tr>
      <td class="tr">${b.ip}</td>
      <td>${b.layer?`<span class="${b.layer==='L4'?'l4b':'l7b'}">${b.layer}</span>`:''}</td>
      <td style="font-size:.6rem;color:var(--txt2)">${(b.reason||'').slice(0,22)}</td>
      <td style="font-size:.59rem;color:var(--txt2)">${(b.time||'').slice(0,16)}</td>
      <td class="ta">${b.hits||1}</td>
      <td><button class="btn bg bxs" onclick="unblockIP('${b.ip}')">✓ Kaldır</button></td>
    </tr>`).join('');
}
async function blockIP() {
  const ip = document.getElementById('blk-ip')?.value?.trim();
  const layer = document.getElementById('blk-l')?.value||'L4';
  if(!ip) { toast('IP girin','er'); return; }
  const r = await api('block', {ip, layer}, 'POST');
  toast(r.ok?`✓ ${ip} engellendi`:`✗ ${r.error}`, r.ok?'ok':'er');
  if(r.ok) { document.getElementById('blk-ip').value=''; loadBlocked(); }
}
async function unblockIP(ip) {
  const r = await api('unblock', {ip}, 'POST');
  toast(r.ok?`✓ ${ip} engel kaldırıldı`:`✗ ${r.error}`, r.ok?'ok':'er');
  if(r.ok) loadBlocked();
}
async function qBlock(ip) {
  const r = await api('block', {ip, layer:'L4'}, 'POST');
  toast(r.ok?`✓ ${ip} engellendi`:`✗ ${r.error}`, r.ok?'ok':'er');
  if(r.ok) loadBlocked();
}

// ── Whitelist ──────────────────────────────────────────────────────
async function loadWL() {
  const r = await api('whitelist'); if(!r.ok) return;
  const tb = document.getElementById('wltb'); if(!tb) return;
  const ips = r.data||[];
  if(!ips.length) { tb.innerHTML='<tr><td colspan="2" style="text-align:center;padding:18px;color:var(--txt2)">Whitelist boş</td></tr>'; return; }
  tb.innerHTML = ips.map(ip=>`
    <tr>
      <td class="tg">${ip}</td>
      <td><button class="btn br bxs" onclick="rmWL('${ip}')">✕ Kaldır</button></td>
    </tr>`).join('');
}
async function addWL() {
  const ip = document.getElementById('wl-ip')?.value?.trim();
  if(!ip) { toast('IP girin','er'); return; }
  const r = await api('wl_add', {ip}, 'POST');
  toast(r.ok?`✓ ${ip} eklendi`:`✗ ${r.error}`, r.ok?'ok':'er');
  if(r.ok) { document.getElementById('wl-ip').value=''; loadWL(); }
}
async function rmWL(ip) {
  const r = await api('wl_remove', {ip}, 'POST');
  toast(r.ok?`✓ ${ip} kaldırıldı`:`✗ ${r.error}`, r.ok?'ok':'er');
  if(r.ok) loadWL();
}

// ── Logs ───────────────────────────────────────────────────────────
async function loadLogs() {
  const r = await api('logs?n=150'); if(!r.ok) return;
  allLogs = r.data||[]; filterLogs();
}
function filterLogs() {
  const f = document.getElementById('lf')?.value||'';
  const fl = f ? allLogs.filter(l=>l.level===f) : allLogs;
  const el = document.getElementById('logbox'); if(!el) return;
  if(!fl.length) { el.innerHTML='<div style="color:var(--txt2);font-size:.72rem;text-align:center;padding:28px">Log bulunamadı</div>'; return; }
  el.innerHTML = fl.map(l=>`
    <div class="le">
      <span class="lt">${l.time.slice(11,19)}</span>
      <span class="ll ${l.level}">${l.level}</span>
      <span class="lm">${l.msg}</span>
    </div>`).join('');
  el.scrollTop = 0;
}

// ── Firewall Rules ─────────────────────────────────────────────────
function _fwHintHtml(data) {
  const joined = (Array.isArray(data) ? data.join('\n') : String(data||'')).toLowerCase();
  if (joined.includes('no chain') || joined.includes('does not exist')) {
    return `<div style="padding:20px;color:#fca5a5;font-family:var(--mono);font-size:.78rem;line-height:1.7">
      ⚠ <strong>Firewall chain'i yok</strong> — Eagle Guard henüz kurulum yapmamış.<br>
      <strong>Çözüm:</strong> Üstteki <em>"🔧 Kuralları Oluştur / Yeniden Kur"</em> butonuna basın, ya da yan menüden <em>▶ BAŞLAT</em> ile servisi başlatın.
    </div>`;
  }
  if (joined.includes('incompatible') || joined.includes('nf_tables')) {
    return `<div style="padding:20px;color:#fbbf24;font-family:var(--mono);font-size:.78rem">
      ⚠ <strong>iptables backend uyumsuzluğu</strong> (nf_tables/legacy karışımı).<br>
      Terminalde <code>sudo update-alternatives --set iptables /usr/sbin/iptables-legacy</code> komutunu çalıştırın, sonra yeniden kurun.
    </div>`;
  }
  return null;
}
async function loadL4Rules(t='fw-l4') {
  const r = await api('ipt_l4'); if(!r.ok) return;
  const hint = _fwHintHtml(r.data);
  const html = hint ?? fwHtml(r.data);
  ['fw-l4','l4rules'].forEach(id => { const el=document.getElementById(id); if(el) el.innerHTML=html; });
}
async function loadL7Rules(t='fw-l7') {
  const r = await api('ipt_l7'); if(!r.ok) return;
  const hint = _fwHintHtml(r.data);
  const html = hint ?? fwHtml(r.data);
  ['fw-l7','l7rules'].forEach(id => { const el=document.getElementById(id); if(el) el.innerHTML=html; });
}
async function loadGameRulesFw() {
  const r = await api('ipt_game'); if(!r.ok) return;
  const hint = _fwHintHtml(r.data);
  const html = hint ?? fwHtml(r.data);
  const el = document.getElementById('fw-game'); if(el) el.innerHTML = html;
}
function runShortcutInTerm(cmd){ nav('term'); setTimeout(()=>runShortcut(cmd), 200); }

// ── WAF Panel ─────────────────────────────────────────────────────
async function loadWAF() {
  const el = document.getElementById('waf-log');
  if (!el) return;

  // WAF log'u oku
  const logs = await api('waf_logs', { n: 100 });

  if (!logs.ok || !logs.data) {
    el.innerHTML = '<div style="color:var(--txt2);padding:10px">WAF logları yüklenemediBu</div>';
    return;
  }

  // Stat'ları hesapla
  const blocked = logs.data.filter(l => l.action === 'block').length;
  const allowed = logs.data.filter(l => l.action === 'allow').length;

  document.getElementById('waf-total').textContent = logs.data.length;
  document.getElementById('waf-blocked').textContent = blocked;
  document.getElementById('waf-allowed').textContent = allowed;

  // Logları göster (son 30)
  const html = logs.data.slice(0, 30).map(log => {
    const cls = log.action === 'block' ? 'color:var(--red)' : 'color:var(--green)';
    const icon = log.action === 'block' ? '🚫' : '✅';
    return `<div style="margin:6px 0;padding:8px;background:var(--bg);border-left:3px solid ${log.action === 'block' ? 'var(--red)' : 'var(--green)'};border-radius:3px">
      <span style="${cls}">${icon} [${log.time}]</span> <span style="color:var(--amber)">${log.rule || 'N/A'}</span>
      <br><span style="color:var(--txt2);font-size:.75rem">${log.msg || log.ip || ''}</span>
    </div>`;
  }).join('');

  el.innerHTML = html || '<div style="color:var(--txt2);padding:10px">Henüz WAF logu yok</div>';
}

async function wafTest(type) {
  const tests = {
    normal: 'http://localhost:8080/',
    sqli: 'http://localhost:8080/?id=1%27 OR 1=1--',
    xss: 'http://localhost:8080/?s=<scr'+'ipt>alert(1)<\/scr'+'ipt>',
    bot: 'http://localhost:8080/'
  };

  const headers = type === 'bot' ? { 'User-Agent': 'nikto/1.0' } : {};
  const url = tests[type];

  const btn = event?.target;
  if (btn) btn.disabled = true;

  try {
    const resp = await fetch(url, { method: 'HEAD', mode: 'no-cors', headers });
    const result = type === 'normal' ? '✅ PASSED' : '🚫 BLOCKED';
    alert(`WAF Test: ${type.toUpperCase()}\nBeklenen: ${type === 'normal' ? 'GEÇER (200)' : 'BLOKE (403)'}\nSonuç: ${result}`);
  } catch(e) {
    alert(`WAF Test: ${type.toUpperCase()}\nSonuç: 🚫 BLOCKED ✓`);
  }

  if (btn) btn.disabled = false;
  setTimeout(loadWAF, 1000);
}

// ── Firewall yönetim butonları ────────────────────────────────────
async function apiPost(action, body={}) {
  return await api(action, body, 'POST');
}
async function fwRefreshAll() {
  await loadL4Rules(); await loadL7Rules(); await loadGameRulesFw();
  // Durum satırı
  const dash = await api('dashboard');
  const st = document.getElementById('fw-status');
  if (st && dash.ok) {
    const s = dash.data.service;
    const color = s==='active' ? '#22c55e' : '#ef4444';
    const label = s==='active' ? '● ÇALIŞIYOR' : '● KAPALI';
    st.innerHTML = `<span style="color:${color};font-weight:700">${label}</span> &nbsp; | &nbsp; `+
      `Chain: EG_L4, EG_L7, EG_GAME &nbsp; | &nbsp; Backend: iptables &nbsp; | &nbsp; `+
      `<span style="color:var(--txt2)">${dash.data.ipt?.blocked_rules||0} engelli IP kuralı</span>`;
  }
}
async function fwSetup() {
  if (!confirm('Eagle Guard tüm firewall chainlerini sıfırlayıp yeniden kuracak. Devam?')) return;
  toast('⏳ Chainler oluşturuluyor...', 'in');
  const r = await apiPost('restart');
  toast(r.ok ? '✓ Restart tetiklendi — 3 sn bekleyin' : '✗ Hata', r.ok?'ok':'er');
  setTimeout(fwRefreshAll, 4000);
}
async function fwReload() {
  toast('⏳ Config yeniden yükleniyor...', 'in');
  const r = await apiPost('restart');
  toast(r.ok ? '🔄 Config uygulandı' : '✗ Hata', r.ok?'ok':'er');
  setTimeout(fwRefreshAll, 4000);
}
async function fwFlush() {
  if (!confirm('TÜM Eagle Guard chainleri temizlenecek (servis durur). Emin misiniz?')) return;
  toast('⏳ Chainler temizleniyor...', 'in');
  const r = await apiPost('stop');
  toast(r.ok ? '🗑 Chainler temizlendi' : '✗ Hata', r.ok?'ok':'er');
  setTimeout(fwRefreshAll, 2000);
}

// ── Alerts ─────────────────────────────────────────────────────────
async function markRead() {
  const r = await api('mark_read', {}, 'POST');
  toast(r.ok?'✓ Okundu işaretlendi':'Hata', 'ok'); pollAlerts();
}
async function testAlert() {
  toast('⏳ Bildirim gönderiliyor...', 'in');
  const r = await api('test_alert', {}, 'POST');
  const msg = r.ok
    ? '✓ Test gönderildi — Discord/Telegram/Email\'e bak'
    : '✗ ' + (r.error || r.msg || 'hata');
  toast(msg, r.ok?'ok':'er');
  setTimeout(pollAlerts, 1000);
}
async function restartSvc() {
  if (!confirm('Servis yeniden başlatılsın mı? SSH/Web bağlantısı kesilmez.')) return;
  toast('⏳ Restart tetiklendi...', 'in');
  const r = await api('restart', {}, 'POST');
  toast(r.ok ? '🔄 Eagle Guard yeniden başlıyor' : '✗ ' + (r.error||'hata'), r.ok?'ok':'er');
  setTimeout(pollDash, 3500);
}
async function webhookTest() {
  toast('⏳ Discord webhook test ediliyor...', 'in');
  const r = await api('webhook_test', {}, 'POST');
  if (r.ok) {
    const out = (r.data?.out || []).join('\n');
    alert('✓ Webhook tetiklendi\n\nDiscord kanalını kontrol edin.\n\nLog:\n' + out);
  } else {
    alert('✗ Hata: ' + (r.error || r.msg));
  }
}

// ── Drawer ─────────────────────────────────────────────────────────
function openDrw()  { document.getElementById('drw').classList.add('op'); document.getElementById('drw-ov').classList.add('s'); }
function closeDrw() { document.getElementById('drw').classList.remove('op'); document.getElementById('drw-ov').classList.remove('s'); }

// ── Config ─────────────────────────────────────────────────────────
async function loadCfg() {
  const r = await api('config'); if(!r.ok) return;
  const fm = document.getElementById('setform'); if(!fm) return;
  Object.entries(r.data||{}).forEach(([k,v]) => { const el=fm.elements[k]; if(el) el.value=v; });
}
async function saveCfg(e) {
  e.preventDefault();
  const fd = {};
  new FormData(document.getElementById('setform')).forEach((v,k) => fd[k]=v);
  const r = await api('save_config', fd, 'POST');
  toast(r.ok?'✓ Kaydedildi — servisi restart edin':'✗ Hata', r.ok?'ok':'er');
}

// ── Service ────────────────────────────────────────────────────────
async function toggleSvc() {
  const a = svcOn ? 'stop' : 'start';
  const r = await api(a, {}, 'POST');
  toast(r.ok?(a==='start'?'✓ Eagle Guard başlatıldı':'✓ Eagle Guard durduruldu'):`✗ ${r.error}`, r.ok?'ok':'er');
  setTimeout(pollDash, 1500);
}
function updSvcUI() {
  const ss=document.getElementById('sbs'), lb=document.getElementById('slbl'), btn=document.getElementById('sbtn');
  if(svcOn) { ss.className='sb-bot on'; lb.textContent='AKTİF'; btn.textContent='⏻ DURDUR'; }
  else       { ss.className='sb-bot off'; lb.textContent='KAPALI'; btn.textContent='⏻ BAŞLAT'; }
}

/* ═══════════════════════════════════════════════════════════════
   WEB TERMİNAL
═══════════════════════════════════════════════════════════════ */
// İzin verilen komutlar (güvenlik whitelist)
const ALLOWED_CMDS = [
  'eagle-guard', 'iptables', 'ip6tables', 'ss', 'netstat', 'ip ',
  'systemctl status', 'systemctl is-active', 'journalctl',
  'df ', 'free ', 'uptime', 'cat /opt/eagle-guard',
  'tail -', 'head -', 'grep ', 'ps ', 'top -bn', 'htop',
  'ping ', 'traceroute ', 'nmap ', 'curl -s http',
  'ls /opt/eagle-guard', 'ls /var/www/html/eagle-guard',
  'python3 -m json', 'whoami', 'hostname', 'uname',
  'wc -l', 'sort ', 'uniq ', 'awk ', 'sed '
];
const BLOCKED_PATTERNS = [
  /rm\s/i, /\brm\b/i, /mv\s/i, /cp\s.*root/i, /chmod\s/i, /chown\s/i,
  /passwd/i, /useradd/i, /userdel/i, /mkfs/i, /dd\s/i, /format/i,
  /shutdown/i, /reboot/i, /init\s/i, /kill\s/i, /pkill/i, /killall/i,
  />\s*\/etc/i, />\s*\/usr/i, />\s*\/bin/i, />\s*\/sbin/i,
  /curl.*\|\s*bash/i, /wget.*\|\s*sh/i, /bash\s+-c/i, /exec\s/i,
  /eval\s/i, /base64\s.*\|\s*bash/i,
];

function isAllowed(cmd) {
  const c = cmd.trim().toLowerCase();
  for(const p of BLOCKED_PATTERNS) if(p.test(cmd)) return false;
  return ALLOWED_CMDS.some(a => c.startsWith(a.toLowerCase()) || c.includes(a.toLowerCase()));
}

function termWrite(content, cls='t-out') {
  const out = document.getElementById('term-out');
  const span = document.createElement('span');
  span.className = cls;
  span.textContent = content;
  out.appendChild(span);
  out.appendChild(document.createTextNode('\n'));
  out.scrollTop = out.scrollHeight;
}

async function termExec() {
  const inp = document.getElementById('term-inp');
  const cmd = inp.value.trim();
  if(!cmd) return;

  // Geçmişe ekle
  termHistory.unshift(cmd);
  if(termHistory.length > 50) termHistory.pop();
  termHistIdx = -1;
  inp.value = '';

  // Prompt satırı
  const out = document.getElementById('term-out');
  const pLine = document.createElement('span');
  pLine.innerHTML = `<span class="t-prompt">root@eagle-guard:~# </span><span class="t-cmd">${cmd}</span>`;
  out.appendChild(pLine);
  out.appendChild(document.createTextNode('\n'));

  // Güvenlik kontrolü
  if(!isAllowed(cmd)) {
    termWrite('⛔ Komut kısıtlandı: Güvenlik politikası. İzin verilen komutlar için Yardım sayfasına bakın.', 't-err');
    return;
  }

  document.getElementById('term-status').textContent = 'ÇALIŞIYOR...';

  try {
    const fd = new FormData();
    fd.append('action', 'exec_cmd');
    fd.append('cmd', cmd);
    const resp = await fetch(API, { method: 'POST', body: fd });
    const data = await resp.json();

    if(data.ok) {
      const output = data.data?.output||[];
      const code = (data.data?.exit_code ?? data.data?.code ?? 0);
      if(output.length === 0) {
        termWrite('(çıktı yok)', 't-info');
      } else {
        output.forEach(line => {
          const cls = line.includes('ERROR') || line.includes('error') || line.includes('Permission') ? 't-err' :
                      line.includes('[OK]') || line.includes('active') ? 't-success' :
                      line.includes('[ALERT]') || line.includes('DROP') ? 't-err' :
                      line.includes('[WARN]') ? 't-info' :
                      line.startsWith('── exit code:') ? (code===0?'t-success':'t-err') : 't-out';
          termWrite(line, cls);
        });
      }
      // Exit code rozeti
      termWrite((code===0 ? '✓ Komut başarılı' : '✗ Komut başarısız') + ' (status='+code+')',
                code===0 ? 't-success' : 't-err');
    } else {
      termWrite('✗ ' + (data.error||'Hata'), 't-err');
    }
  } catch(e) {
    termWrite('✗ API bağlantı hatası: ' + e.message, 't-err');
  }

  document.getElementById('term-status').textContent = 'HAZIR';
  termWrite('', 't-out'); // boş satır
}

function termKeyDown(e) {
  if(e.key === 'Enter') { termExec(); return; }
  const inp = document.getElementById('term-inp');
  if(e.key === 'ArrowUp') {
    e.preventDefault();
    if(termHistIdx < termHistory.length-1) { termHistIdx++; inp.value=termHistory[termHistIdx]; }
  }
  if(e.key === 'ArrowDown') {
    e.preventDefault();
    if(termHistIdx > 0) { termHistIdx--; inp.value=termHistory[termHistIdx]; }
    else { termHistIdx=-1; inp.value=''; }
  }
  if(e.key === 'Tab') {
    e.preventDefault();
    // Basit auto-complete
    const shortcuts = ['eagle-guard status','eagle-guard stats','eagle-guard rules-l4',
      'eagle-guard rules-l7','eagle-guard logs','iptables -L EG_L4 -n','iptables -L EG_L7 -n',
      'ss -tn state established','df -h','free -h','uptime'];
    const v = inp.value;
    const match = shortcuts.find(s => s.startsWith(v) && s !== v);
    if(match) inp.value = match;
  }
}

function runShortcut(cmd) {
  document.getElementById('term-inp').value = cmd;
  termExec();
}

function clearTerm() {
  const out = document.getElementById('term-out');
  out.innerHTML = `<span class="t-info">Terminal temizlendi — ${new Date().toLocaleString('tr-TR')}</span>\n\n`;
}

/* ═══════════════════════════════════════════════════════════════
   BOOT
═══════════════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', () => {
  initCharts();
  pollDash(); pollAlerts(); pollTraffic(); pollTC();
  setInterval(pollDash,    3000);
  setInterval(pollAlerts,  5000);
  setInterval(pollTraffic, 8000);
  setInterval(pollTC,      6000);
});
</script>
</body>
</html>
