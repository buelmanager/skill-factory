export const meta = {
  name: 'milestone-dryrun',
  description: 'Dry-run roadmap milestones through WORKFLOW.md, auto-fix CONFIRMED major+ doc issues, catalog anticipated dev issues',
  phases: [
    { title: 'Find', detail: '5-lens validation per milestone (read-only)' },
    { title: 'Dedup', detail: 'merge doc findings across milestones' },
    { title: 'Verify', detail: 'adversarial skeptic per finding, with fallback' },
    { title: 'Fix', detail: 'autonomous minimal edits, K=2 converge / max 3 rounds' },
    { title: 'Report', detail: 'per-milestone docs/dev/dryrun/<MID>.md' },
  ],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const { milestones, repoRoot, ts, branch } = A
const M = A.model // optional GLOBAL override (e.g. 'sonnet') — forces ONE model on every agent to conserve limits
// Per-role model (CLAUDE.md §4: delegated units never inherit the parent/Fable — always set model explicitly).
// opus = hard-judgment roles (find lenses, adversarial verify); sonnet = mechanical (dedup, fix-edit, report).
// A GLOBAL override (A.model) wins over the role default when set. Unknown role → sonnet ("애매하면 sonnet").
const mo = (o, def = 'sonnet') => ({ ...o, model: M || def })
log(`milestone-dryrun: ${milestones.length} milestones — ${milestones.join(', ')}${M ? ` (model=${M} forced)` : ' (find/verify=opus, dedup/fix/report=sonnet)'}`)

// ---------------- shared context + schema ----------------
const sharedFor = (MID) => `
DEV-PROCESS DOCUMENT under test: ${repoRoot}/docs/dev/WORKFLOW.md.
Goal: if an agent runs milestone **${MID}** by following WORKFLOW.md, do they hit doc problems (gaps, blockers, contradictions, unrunnable steps, task-type misfit)? AND what real-development issues will bite when ${MID} is actually implemented?
Read (absolute): ${repoRoot}/docs/dev/WORKFLOW.md, README.md, SESSION-CLOSE.md, PROGRESS.md; ${repoRoot}/docs/roadmap.md (find the ${MID} task list + 리스크 + Exit); ${repoRoot}/CLAUDE.md; ~/.claude/skills/dev-handoff/regen-progress.mjs (validator behavior); and ${repoRoot}/docs/*-spec.md / NFR sources relevant to ${MID} for lens ⑤.
Be concrete and adversarial. Every doc finding names the exact WORKFLOW.md step/line and the exact ${MID} moment it bites. Prefer few real findings over many speculative ones.`

const FINDINGS_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    findings: { type: 'array', items: { type: 'object', additionalProperties: false,
      properties: {
        title: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
        category: { type: 'string', enum: ['reference', 'dryrun-gap', 'consistency', 'task-type-fit'] },
        location: { type: 'string' }, problem: { type: 'string' }, trigger: { type: 'string' }, evidence: { type: 'string' },
      }, required: ['title', 'severity', 'category', 'location', 'problem', 'trigger', 'evidence'] } },
    devIssues: { type: 'array', items: { type: 'object', additionalProperties: false,
      properties: {
        task: { type: 'string', description: '<MID>.T<n> or "milestone"' },
        risk_type: { type: 'string', enum: ['perf', 'security', 'correctness', 'integration'] },
        issue: { type: 'string' }, trigger: { type: 'string' },
        expected_response: { type: 'string', description: 'test-first? design constraint?' },
        severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
      }, required: ['task', 'risk_type', 'issue', 'trigger', 'expected_response', 'severity'] } },
  },
  required: ['findings', 'devIssues'],
}

// ---------------- Phase 1: Find (per milestone × lens, read-only) ----------------
phase('Find')
const LENSES = ['reference', 'dryrun', 'consistency', 'taskfit', 'devissues']
const lensPrompt = (MID, lens) => sharedFor(MID) + ({
  reference: `\nLENS ① REFERENCE INTEGRITY: every command/skill/task-ID/link/gate WORKFLOW.md names for ${MID} — exists / runnable AT THE POINT ${MID} invokes it / matches roadmap+PROGRESS? Report broken/unrunnable/mismatched. Put doc problems in findings; leave devIssues [].`,
  dryrun: `\nLENS ② VIRTUAL DRY-RUN: walk ${MID} task-by-task via WORKFLOW.md "매 세션"+"마일스톤 하나 흐름". Log every stuck/confused/gap. Address decision vs code tasks, chicken-and-egg tooling, "am I done" signal. findings only; devIssues [].`,
  consistency: `\nLENS ③ CROSS-DOC: WORKFLOW vs roadmap/PROGRESS/SESSION-CLOSE/README/CLAUDE §6/§7 for ${MID}. Quote both sides of each contradiction. findings only; devIssues [].`,
  taskfit: `\nLENS ④ TASK-TYPE FIT: does the code-centric loop (writing-plans→TDD→SDD→Task: trailer→done-evidence) fit ${MID}'s task types (decision/scaffold/config/deploy/infra)? Read regen-progress.mjs done-evidence rule. findings only; devIssues [].`,
  devissues: `\nLENS ⑤ ANTICIPATED DEV ISSUES (NOT auto-fixed — catalog only): when ${MID} is really implemented, what perf/security/correctness/integration risks bite? Derive from roadmap 리스크, engineering specs, NFR (60fps, ≤3s, ±1% area, ≤300ms, cross-tenant isolation), domain rules. Put these in devIssues; leave findings [].`,
})[lens]

const found = await parallel(milestones.flatMap((MID) => LENSES.map((lens) => () =>
  agent(lensPrompt(MID, lens), mo({ label: `find:${MID}:${lens}`, phase: 'Find', schema: FINDINGS_SCHEMA }, 'opus'))
    .then((r) => ({ MID, lens, r })))))

const perMilestone = {}
for (const MID of milestones) perMilestone[MID] = { docFindings: [], devIssues: [] }
for (const item of found.filter(Boolean)) {
  perMilestone[item.MID].docFindings.push(...(item.r.findings || []).map((f) => ({ ...f, MID: item.MID })))
  perMilestone[item.MID].devIssues.push(...(item.r.devIssues || []))
}

// ---------------- Phase 2: Dedup doc findings globally ----------------
phase('Dedup')
const allDoc = milestones.flatMap((MID) => perMilestone[MID].docFindings)
log(`${allDoc.length} raw doc findings across ${milestones.length} milestones`)
const DEDUP_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { unique: { type: 'array', items: { type: 'object', additionalProperties: false,
    properties: {
      id: { type: 'string' }, title: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
      category: { type: 'string' }, location: { type: 'string' }, problem: { type: 'string' }, trigger: { type: 'string' },
      evidence: { type: 'string' }, affects: { type: 'string', description: 'which milestone(s) reported it' },
    }, required: ['id', 'title', 'severity', 'category', 'location', 'problem', 'trigger', 'evidence', 'affects'] } } },
  required: ['unique'],
}
const uniqueDoc = allDoc.length ? (await agent(
  `Merge duplicate/near-duplicate doc findings into canonical items (union evidence, keep highest severity, note reporting milestones in "affects"). Preserve every DISTINCT issue. Assign ids F1,F2,…. Many are milestone-independent (WORKFLOW.md properties) so expect heavy overlap.\n\nRAW (JSON):\n${JSON.stringify(allDoc, null, 2)}`,
  mo({ label: 'dedup', phase: 'Dedup', schema: DEDUP_SCHEMA }, 'sonnet'))).unique : []
log(`${uniqueDoc.length} unique doc findings after dedup`)

// ---------------- Phase 3: Adversarial verify + fallback (no silent drop) ----------------
phase('Verify')
const VERIFY_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    id: { type: 'string' }, verdict: { type: 'string', enum: ['CONFIRMED', 'PLAUSIBLE', 'REFUTED'] },
    corrected_severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
    reasoning: { type: 'string' }, mitigation: { type: 'string' }, fix_hint: { type: 'string' },
    code_rooted: { type: 'boolean', description: 'true if the real fix is in code/validator, not a doc' },
  },
  required: ['id', 'verdict', 'corrected_severity', 'reasoning', 'mitigation', 'fix_hint', 'code_rooted'],
}
const verifyPrompt = (f, attempt) => `Adversarially VERIFY this doc finding. Default posture: try to REFUTE. READ the actual cited files (and regen-progress.mjs if about validator behavior) — do not reason from memory. REFUTED if a plain reading or a mitigation elsewhere resolves it. CONFIRMED only if it genuinely bites. PLAUSIBLE if real but conditional/minor. Correct the severity. Set code_rooted=true if the proper fix is in code/validator (then it is report-only, never auto-fixed).${attempt > 1 ? ' Return ONLY the required JSON fields — keep reasoning under 60 words.' : ''}\n\nFINDING (JSON):\n${JSON.stringify(f, null, 2)}`

async function verifyWithFallback(f) {
  for (const attempt of [1, 2]) {
    const v = await agent(verifyPrompt(f, attempt), mo({ label: `verify:${f.id}${attempt > 1 ? ':retry' : ''}`, phase: 'Verify', schema: VERIFY_SCHEMA }, 'opus')).catch(() => null)
    if (v) return { ...f, ...v }
  }
  return { ...f, verdict: 'UNVERIFIED', corrected_severity: f.severity, reasoning: 'verify failed after retry — reported unverified (not silently dropped)', mitigation: 'none', fix_hint: '', code_rooted: false }
}
const verified = await parallel(uniqueDoc.map((f) => () => verifyWithFallback(f)))

// ---------------- Phase 4: Autonomous fix loop (K=2 converge / max 3 rounds) ----------------
phase('Fix')
const FIX_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { applied: { type: 'boolean' }, file: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' }, note: { type: 'string' } },
  required: ['applied', 'file', 'before', 'after', 'note'],
}
const isFixable = (v) => v.verdict === 'CONFIRMED' && ['major', 'blocker'].includes(v.corrected_severity) && !v.code_rooted
let fixList = verified.filter(isFixable)
const reportOnly = verified.filter((v) => !isFixable(v))
const fixed = []
const K = 2, MAX_ROUNDS = 3
let emptyStreak = 0
let roundsRun = 0
for (let round = 1; round <= MAX_ROUNDS && emptyStreak < K; round++) {
  roundsRun = round
  if (!fixList.length) { emptyStreak++; log(`Fix round ${round}: nothing to fix (streak ${emptyStreak}/${K})`); continue }
  for (const f of fixList) { // sequential — shared docs/dev/*.md, avoid write races
    const res = await agent(
      `Apply a MINIMAL, surgical edit that resolves this CONFIRMED ${f.corrected_severity} doc finding. ONLY edit files under ${repoRoot}/docs/dev/*.md (whitelist — freeze will block anything else). Do not rewrite sections; add the least text that fixes it. Then STATE the exact before→after.\n\nFinding + fix_hint:\n${JSON.stringify(f, null, 2)}`,
      mo({ label: `fix:${f.id}`, phase: 'Fix', schema: FIX_SCHEMA }, 'sonnet')).catch(() => null)
    if (res && res.applied) fixed.push({ ...f, fix: res })
  }
  // Re-validate exactly the audited milestones. Fixes touch shared docs/dev/*.md, so any
  // audited milestone may be affected. NEVER derive this from the free-text `affects` field
  // (it is prose, not a list of IDs — splitting it spawns garbage lenses → runaway).
  const affected = milestones
  const re = await parallel(affected.flatMap((MID) => ['reference', 'dryrun', 'consistency', 'taskfit'].map((lens) => () =>
    agent(lensPrompt(MID, lens), mo({ label: `re:${MID}:${lens}`, phase: 'Fix', schema: FINDINGS_SCHEMA }, 'opus'))
      .then((r) => (r.findings || []).map((x) => ({ ...x, MID }))).catch(() => []))))
  const reFindings = re.flat().filter((x) => ['major', 'blocker'].includes(x.severity)).slice(0, 12) // hard cap: runaway guard
  const reVerified = await parallel(reFindings.map((f, i) => () => verifyWithFallback({ ...f, id: `R${round}-${i}` })))
  const newMajor = reVerified.filter(isFixable)
  if (!newMajor.length) { emptyStreak++; log(`Fix round ${round}: 0 new major↑ (streak ${emptyStreak}/${K})`) }
  else { emptyStreak = 0; fixList = newMajor; log(`Fix round ${round}: ${newMajor.length} new major↑ → next round`) }
}
const converge = { rounds: roundsRun, emptyStreak, unverifiedCount: verified.filter((v) => v.verdict === 'UNVERIFIED').length }

// ---------------- Phase 5: Per-milestone reports ----------------
phase('Report')
const reports = {}
await parallel(milestones.map((MID) => () => {
  const mFixed = fixed.filter((f) => (f.affects || f.MID || '').includes(MID))
  const mReport = reportOnly.filter((f) => (f.affects || f.MID || '').includes(MID))
  const mDev = perMilestone[MID].devIssues
  const prompt = [
    `Write the dry-run report for milestone ${MID} to ${repoRoot}/docs/dev/dryrun/${MID}.md using the Write tool (create the docs/dev/dryrun/ directory first if needed).`,
    `Follow EXACTLY this Markdown structure, filling each section from the DATA below. Write in Korean, concise.`,
    ``,
    `# Dry-run: ${MID}`,
    `> 생성: ${ts} · 브랜치 ${branch} · 수렴: ${converge.rounds}라운드(연속무발견 ${converge.emptyStreak}) · 미검증 ${converge.unverifiedCount}건`,
    ``,
    `## 1. 문서 이슈`,
    `### 1a. 자동수정됨 (CONFIRMED · major↑)   ← 각 항목: [id] 제목 — 위치 · 발견 · 근거 · 적용수정(before→after) · 재검증`,
    `### 1b. 리포트만 (PLAUSIBLE · minor · nit · UNVERIFIED · 코드뿌리)   ← 각 항목: [id] 제목 — 판정 · 제안픽스(미적용) · 왜 자동수정 안 함`,
    ``,
    `## 2. 예상 개발 이슈 (실개발 대응 — 자동수정 없음)`,
    `> writing-plans가 이 섹션을 테스트-먼저 목록·설계 제약으로 반영한다.`,
    `각 이슈: 태스크 | 유형(perf/security/correctness/integration) | 이슈 · 트리거 · 예상대응 · 심각도`,
    ``,
    `## 3. 검증 게이트 리마인더   ← roadmap Exit / 하드게이트(A1 ≤3s·±1% / A3 ≤300ms / A2 ±2%) 중 ${MID} 해당분`,
    ``,
    `## 4. 수렴 메타   ← 라운드 수 · 미검증 항목 · 남은 reportOnly 개수(${mReport.length})`,
    ``,
    `DATA (JSON):`,
    `자동수정 = ${JSON.stringify(mFixed)}`,
    `리포트만 = ${JSON.stringify(mReport)}`,
    `예상개발이슈 = ${JSON.stringify(mDev)}`,
  ].join('\n')
  return agent(prompt, mo({ label: `report:${MID}`, phase: 'Report' }, 'sonnet'))
    .then(() => { reports[MID] = `docs/dev/dryrun/${MID}.md` }).catch(() => {})
}))

return { perMilestone, fixed, reportOnly, reports, converge }
