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

function parseRow(line) {
  if (!/^\s*\|/.test(line)) return null;
  const cells = line.split('|').slice(1, -1).map(c => c.trim());
  return cells.length ? cells : null;
}
function clean(s) { return s.replace(/\s+$/, '').trim() || null; }
