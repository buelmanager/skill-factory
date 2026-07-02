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
