// dashboard.mjs — zero-dependency
export function parseProgress(md) {
  const lines = md.split('\n');
  const status = { blocker: null, nextAction: null, latestHandoff: null };
  for (const l of lines) {
    let m;
    if ((m = l.match(/^-\s*막힘\s*:\s*(.+?)\s*$/))) status.blocker = clean(m[1]);
    else if ((m = l.match(/^-\s*최신 핸드오프\s*:\s*(.+?)\s*$/))) status.latestHandoff = clean(m[1]);
    else if ((m = l.match(/^-\s*다음 액션\s*:\s*(.+?)\s*$/))) status.nextAction = clean(m[1]);
  }
  const rollup = [];
  const tasks = {};
  let section = null;      // '롤업' | '태스크'
  let currentMilestone = null;
  for (const l of lines) {
    if (/^##\s*1\./.test(l)) { section = 'rollup'; continue; }
    if (/^##\s*2\./.test(l)) { section = 'tasks'; continue; }
    if (/^##\s/.test(l)) { section = null; continue; }
    const ms = l.match(/^###\s*(\S+)/);
    if (ms) { currentMilestone = ms[1]; tasks[currentMilestone] = []; continue; }
    const cells = parseRow(l);
    if (!cells) continue;
    if (section === 'rollup') {
      const [id, st, dt] = cells;
      if (id === '그룹' || /^-+$/.test(id)) continue;
      const dm = (dt || '').match(/(\d+)\s*\/\s*(\d+)/);
      rollup.push({ id, status: st, done: dm ? +dm[1] : 0, total: dm ? +dm[2] : 0 });
    } else if (section === 'tasks' && currentMilestone) {
      const [id, st, handoff] = cells;
      if (id === 'ID' || /^-+$/.test(id)) continue;
      tasks[currentMilestone].push({ id, status: st, handoff: handoff || '' });
    }
  }
  return { status, rollup, tasks };
}

export function parseSession(md, filename) {
  const fm = md.match(/^---\n([\s\S]*?)\n---/);
  const body = fm ? md.slice(fm[0].length) : md;
  const block = fm ? fm[1] : '';
  const get = (k) => {
    const m = block.match(new RegExp('^' + k + '\\s*:\\s*(.+)$', 'm'));
    return m ? m[1].trim() : null;
  };
  const arr = (k) => {
    const raw = get(k);
    if (!raw) return [];
    const inner = raw.replace(/^\[|\]$/g, '').trim();
    return inner ? inner.split(',').map(s => s.trim()).filter(Boolean) : [];
  };
  const statusAfter = {};
  const saRaw = get('status_after');
  if (saRaw) {
    const inner = saRaw.replace(/^\{|\}$/g, '');
    for (const pair of inner.split(',')) {
      const m = pair.match(/([^:]+):\s*(\S+)/);
      if (m) statusAfter[m[1].trim()] = m[2].trim();
    }
  }
  const nextRaw = get('next_action');
  const nextAction = nextRaw ? nextRaw.replace(/^"|"$/g, '') : null;
  const titleM = body.match(/^#\s+(.+)$/m);
  return {
    session: get('session'),
    milestones: arr('milestones'),
    tasksTouched: arr('tasks_touched'),
    statusAfter,
    nextAction,
    meta: get('meta') === 'true',
    title: titleM ? titleM[1].trim() : filename,
    filename,
  };
}

function parseRow(line) {
  if (!/^\s*\|/.test(line)) return null;
  const cells = line.split('|').slice(1, -1).map(c => c.trim());
  return cells.length ? cells : null;
}
function clean(s) { return s.replace(/\s+$/, '').trim() || null; }

const STATUS_CLASS = {
  todo: 'todo', doing: 'doing', blocked: 'blocked',
  review: 'review', done: 'done', cut: 'cut',
};

export function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

export function renderDashboard({ project, generatedAt, progress, sessions }) {
  const e = escapeHtml;
  const totals = progress.rollup.reduce((a, r) => {
    a.done += r.done; a.total += r.total; return a;
  }, { done: 0, total: 0 });
  const pct = totals.total ? Math.round((totals.done / totals.total) * 100) : 0;

  const mileCards = progress.rollup.map(r => {
    const w = r.total ? Math.round((r.done / r.total) * 100) : 0;
    return `<div class="mile"><div class="h"><span class="id">${e(r.id)}</span>`
      + `<span class="chip s-${STATUS_CLASS[r.status] || 'todo'}">${e(r.status)}</span></div>`
      + `<div class="bar"><i style="width:${w}%"></i></div>`
      + `<div class="ft"><span>${r.done}/${r.total}</span></div></div>`;
  }).join('');

  const taskGrids = Object.entries(progress.tasks).map(([mid, list]) => {
    const cells = list.map(t => {
      const cls = STATUS_CLASS[t.status] || 'todo';
      const tid = t.id.split('.').pop();
      return `<div class="cell c-${cls}">${e(tid)}<span class="tip">${e(t.id)} · ${e(t.status)}</span></div>`;
    }).join('');
    return `<div class="tgrp"><div class="th"><span>${e(mid)}</span></div><div class="cells">${cells}</div></div>`;
  }).join('');

  const timeline = sessions.map(s => {
    const chips = (s.milestones || []).map(m => `<span class="chip s-doing">${e(m)}</span>`).join('');
    return `<div class="ev${s.meta ? ' meta' : ''}"><div class="d">${e(s.session)}${s.meta ? ' · meta' : ''}</div>`
      + `<div class="t">${e(s.title)}</div>`
      + `<div class="m">${e(s.nextAction || '')}</div><div class="tags">${chips}</div></div>`;
  }).join('');

  const st = progress.status;
  return `<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${e(project)} — Progress Dashboard</title>
<style>${STYLES}</style></head>
<body><div class="wrap">
<header class="top"><h1>${e(project)} · 진행 대시보드</h1>
<div class="gen">generated ${e(generatedAt)} · from docs/dev/PROGRESS.md</div></header>
<div class="status">
<div class="card blk"><div class="k">막힘</div><div class="v">${e(st.blocker || '—')}</div></div>
<div class="card next"><div class="k">다음 액션</div><div class="v">${e(st.nextAction || '—')}</div></div>
<div class="card"><div class="k">최신 핸드오프</div><div class="v">${e(st.latestHandoff || '—')}</div></div>
</div>
<div class="overall"><div class="ring" style="--p:${pct}"><b>${pct}%</b></div>
<div class="meta"><div class="big">${totals.done}/${totals.total} tasks done</div></div></div>
<h2 class="sec">마일스톤 롤업</h2><div class="miles">${mileCards}</div>
<h2 class="sec">태스크 상태 그리드</h2><div class="tasks">${taskGrids}</div>
<h2 class="sec">최근 세션</h2><div class="tl">${timeline}</div>
<footer><span>project-genesis · dashboard.mjs</span></footer>
</div></body></html>`;
}

const STYLES = `
:root{--bg:#0d1117;--panel:#161b22;--line:#2d333b;--tx:#e6edf3;--dim:#8b949e;
--todo:#30363d;--doing:#1f6feb;--blocked:#da3633;--review:#a371f7;--done:#2ea043;--cut:#484f58;--accent:#e3b341}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);
font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:14px}
.wrap{max-width:1120px;margin:0 auto;padding:32px 24px 64px}
.top{display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px;border-bottom:1px solid var(--line);padding-bottom:16px}
.top h1{font-size:20px;margin:0}.gen{font-size:12px;color:var(--dim);font-family:monospace}
.status{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:24px 0}
.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.card .k{font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:var(--dim);margin-bottom:6px}
.card .v{font-family:monospace;font-size:13px;word-break:break-word}
.card.blk .v{color:#ff7b72}.card.next .v{color:#79c0ff}
.sec{font-size:13px;text-transform:uppercase;letter-spacing:1px;color:var(--dim);margin:34px 0 14px}
.overall{display:flex;align-items:center;gap:20px;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:18px 20px}
.ring{--p:0;width:74px;height:74px;border-radius:50%;background:conic-gradient(var(--done) calc(var(--p)*1%),var(--todo) 0);display:grid;place-items:center;position:relative}
.ring::before{content:'';position:absolute;inset:8px;border-radius:50%;background:var(--panel)}
.ring b{position:relative;font-family:monospace}
.miles{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}
.mile{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px}
.mile .h{display:flex;justify-content:space-between;margin-bottom:8px}.mile .id{font-family:monospace;font-weight:600}
.bar{height:7px;border-radius:6px;background:var(--todo);overflow:hidden;margin-bottom:8px}
.bar>i{display:block;height:100%;background:var(--done)}
.ft{display:flex;justify-content:space-between;font-family:monospace;font-size:11px;color:var(--dim)}
.chip{font-family:monospace;font-size:10px;padding:1px 7px;border-radius:5px;text-transform:uppercase}
.s-todo{background:#21262d;color:#8b949e}.s-doing{background:#132d5c;color:#79c0ff}
.s-blocked{background:#3d1a1a;color:#ff7b72}.s-review{background:#2a1f45;color:#d2a8ff}
.s-done{background:#12331f;color:#56d364}.s-cut{background:#22262c;color:#6e7681;text-decoration:line-through}
.tasks{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:16px}
.tgrp{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.tgrp .th{font-family:monospace;font-size:12px;color:var(--dim);margin-bottom:10px}
.cells{display:flex;flex-wrap:wrap;gap:5px}
.cell{width:26px;height:26px;border-radius:5px;display:grid;place-items:center;font-family:monospace;font-size:9px;font-weight:700;position:relative;color:#0d1117}
.c-todo{background:var(--todo);color:#6e7681}.c-doing{background:var(--doing)}.c-blocked{background:var(--blocked)}
.c-review{background:var(--review)}.c-done{background:var(--done)}.c-cut{background:var(--cut);color:#6e7681}
.cell .tip{visibility:hidden;position:absolute;bottom:130%;left:50%;transform:translateX(-50%);background:#000;color:#fff;font-size:11px;padding:3px 7px;border-radius:5px;white-space:nowrap;z-index:9}
.cell:hover .tip{visibility:visible}
.tl{border-left:2px solid var(--line);margin-left:8px;padding-left:22px}
.ev{position:relative;padding-bottom:18px}
.ev::before{content:'';position:absolute;left:-29px;top:3px;width:11px;height:11px;border-radius:50%;background:var(--panel);border:2px solid var(--doing)}
.ev.meta::before{border-color:var(--dim)}
.ev .d{font-family:monospace;font-size:12px;color:var(--dim)}.ev .t{margin:2px 0 3px}.ev .m{font-family:monospace;font-size:12px;color:var(--dim)}
.tags{margin-top:4px;display:flex;gap:6px;flex-wrap:wrap}
footer{margin-top:44px;border-top:1px solid var(--line);padding-top:14px;font-family:monospace;font-size:11px;color:var(--dim)}`;

// ---- CLI ----
import { readFileSync as _read, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { join as _join, basename, dirname } from 'node:path';

function main(argv) {
  const [progressPath, sessionsDir, outPath] = argv;
  if (!progressPath || !outPath) {
    console.error('usage: node dashboard.mjs <progressPath> <sessionsDir> <outPath>');
    process.exit(1);
  }
  const progress = parseProgress(_read(progressPath, 'utf8'));
  let sessions = [];
  try {
    sessions = readdirSync(sessionsDir)
      .filter(f => f.endsWith('.md'))
      .sort().reverse()
      .map(f => parseSession(_read(_join(sessionsDir, f), 'utf8'), f));
  } catch { /* no sessions dir yet */ }
  const project = basename(process.cwd());
  const html = renderDashboard({ project, generatedAt: new Date().toISOString().slice(0, 16).replace('T', ' '), progress, sessions });
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, html);
  console.log('dashboard written:', outPath);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
