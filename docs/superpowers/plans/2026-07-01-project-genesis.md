# project-genesis Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `project-genesis` skill — an orchestrator that takes a new project from customer intake → mvp-prd → specs/infra → roadmap → dev-process SSOT → repo skeleton → a static HTML progress dashboard.

**Architecture:** A thin conductor `SKILL.md` drives an 8-phase pipeline. Each doc-generation phase is delegated to a subagent fed a template + upstream artifacts (main context stays lean). Content lives as reference docs + parameterized templates extracted from the reference project (`interior-3d-estimator`). The one piece of real code is a zero-dependency Node script `dashboard.mjs` that parses `docs/dev/PROGRESS.md` + `docs/sessions/*.md` and emits a self-contained HTML dashboard. Existing skills (`brainstorming`, `spec`, `dev-handoff/regen-progress.mjs`) are reused, not reimplemented.

**Tech Stack:** Markdown (skill + templates), Node ≥20 ESM (dashboard.mjs, node:test + node:assert for tests), no third-party dependencies.

## Global Constraints

- Skill authored under `skill-factory/skills/project-genesis/` (git-tracked); installed by copy to `~/.claude/skills/project-genesis/` (matches `dev-lifecycle` pattern). — exact source-of-truth path.
- `dashboard.mjs` MUST be zero-dependency: only Node built-ins (`node:fs`, `node:path`, `node:test`, `node:assert`). No npm install.
- All text originating from `PROGRESS.md` or session files MUST be HTML-escaped before injection into the dashboard (`&`,`<`,`>`,`"`,`'`). — `@html` hardening.
- Dashboard status color language is FIXED (6 states): `todo` grey `#30363d` · `doing` blue `#1f6feb` · `blocked` red `#da3633` · `review` purple `#a371f7` · `done` green `#2ea043` · `cut` grey `#484f58`+strikethrough.
- Reuse `~/.claude/skills/dev-handoff/regen-progress.mjs` for PROGRESS generation/validation; do NOT reimplement it.
- Every template file starts with the fixed header comment (see Task 4, Step 1).
- Reference source for all template extraction: `/Users/chulheewon/development/main_project/interior-3d-estimator/`.
- Doc scope is tiered: universal docs always generated; conditional docs gated by intake flags (see Task 2 `conditional-matrix.md`).

---

## File Structure

```
skill-factory/skills/project-genesis/
  SKILL.md                          # Task 1 — orchestrator
  references/
    intake-interview.md             # Task 2
    intake-brief.md                 # Task 2
    conditional-matrix.md           # Task 2
    dev-process-wiring.md           # Task 3
    templates/
      00-brief.md                   # Task 4
      mvp-prd.md                     # Task 4
      competitive-landscape.md       # Task 4
      architecture.md                # Task 5
      glossary.md                    # Task 5
      data-model.md                  # Task 5
      infra-security-spec.md         # Task 5
      api-spec.md                    # Task 6
      ui-flows.md                    # Task 6
      test-strategy.md               # Task 6
      core-module-spec.md            # Task 6
      CLAUDE.md                      # Task 7
      AGENT.md                       # Task 7
      README.md                      # Task 7
      docs-README.md                 # Task 7
      roadmap.md                     # Task 8
      getting-started.md             # Task 8
      dev-README.md                  # Task 8
      dev-WORKFLOW.md                # Task 8
      dev-SESSION-CLOSE.md           # Task 8
  scripts/
    dashboard.mjs                    # Tasks 9-11
    dashboard.test.mjs               # Tasks 9-11
    fixtures/
      PROGRESS.sample.md             # Task 9
      sessions/
        2026-07-01-100014-boot.md    # Task 10
        2026-07-01-113703-close.md   # Task 10
```

---

## Task 1: Skill skeleton + SKILL.md orchestrator

**Files:**
- Create: `skill-factory/skills/project-genesis/SKILL.md`

**Interfaces:**
- Produces: the skill entrypoint. Later tasks add files under `references/` and `scripts/` that SKILL.md points to by relative path.

- [ ] **Step 1: Create the skill directory tree**

```bash
cd /Users/chulheewon/development/main_project/skill-factory
mkdir -p skills/project-genesis/references/templates skills/project-genesis/scripts/fixtures/sessions
```

- [ ] **Step 2: Write SKILL.md**

Frontmatter + body. Body MUST contain, in order:

1. Frontmatter (exact):
```markdown
---
name: project-genesis
description: Use when starting a brand-new project from scratch — takes customer intake (interview or brief) through mvp-prd, architecture/domain/engineering specs, CLAUDE.md/AGENT.md constitution, roadmap, dev-process SSOT, repo skeleton, and ends by generating a static HTML progress dashboard. For greenfield project initialization up to "ready to code".
---
```
2. `## When to use / not use` — use for greenfield init; not for existing projects mid-development (that's dev-lifecycle), not for single features (brainstorming).
3. `## Phase 0 — Intake (pick a mode)` — ask user: interview mode (→ `references/intake-interview.md`) or brief mode (→ `references/intake-brief.md`). Output: `docs/00-brief.md` + trait flags per `references/conditional-matrix.md`.
4. `## The 8 phases` — a table copied from the design spec §4 (phase # / name / outputs / tier / upstream input).
5. `## Delegation rule` — each doc-generation phase is dispatched to a subagent with (a) the template from `references/templates/`, (b) `docs/00-brief.md` + named upstream docs, (c) generation instructions; the orchestrator recovers only the written path. Cite user's preserving-main-context doctrine.
6. `## Conditional generation` — one line: consult `references/conditional-matrix.md` to decide which Phase 2/3/6 outputs are ON.
7. `## Reuse` — brainstorming/spec for intake exploration; `~/.claude/skills/dev-handoff/regen-progress.mjs` for PROGRESS; never reimplement.
8. `## Phase gates` — after each phase, report written paths to the user and continue; stop if the user wants to edit.
9. `## Phase 7 — Dashboard (finale)` — run `node references/../scripts/dashboard.mjs <progressPath> <sessionsDir> <outPath>` then open the HTML.

- [ ] **Step 3: Verify frontmatter is valid and phases are present**

Run:
```bash
cd /Users/chulheewon/development/main_project/skill-factory
head -5 skills/project-genesis/SKILL.md
grep -c "^## " skills/project-genesis/SKILL.md
```
Expected: frontmatter `name: project-genesis` visible; `grep -c` returns ≥ 8 (the section count).

- [ ] **Step 4: Commit**

```bash
git add skills/project-genesis/SKILL.md
git commit -m "feat(project-genesis): skill skeleton + 8-phase orchestrator SKILL.md"
```

---

## Task 2: Intake references + conditional matrix

**Files:**
- Create: `skill-factory/skills/project-genesis/references/intake-interview.md`
- Create: `skill-factory/skills/project-genesis/references/intake-brief.md`
- Create: `skill-factory/skills/project-genesis/references/conditional-matrix.md`

**Interfaces:**
- Produces: the trait-flag vocabulary consumed by every conditional decision downstream. Flags (exact names): `has_ui`, `has_api`, `has_persistent_data`, `is_multitenant_saas`, `core_risk_modules` (array of module names), `is_monorepo`, `stack` (string).

- [ ] **Step 1: Write `intake-interview.md`**

A question script for interview mode. Sections: `## Goal` (produce `docs/00-brief.md` + flags), `## Ask one at a time` with an ordered question list covering: product one-liner, target user + core value, top 3 riskiest assumptions (→ mvp-prd §0), in/out scope, has UI? has API? persistent data? multi-tenant SaaS? core high-risk modules (→ core-module-spec instances), monorepo vs single app, confirmed stack. `## Output` — write organized answers into `docs/00-brief.md` and record the flag values. Note: delegate open exploration to `superpowers:brainstorming` when the idea is fuzzy.

- [ ] **Step 2: Write `intake-brief.md`**

Brief mode. Sections: `## Goal`, `## Parse` (read the user's pasted brief, extract the same fields/flags as interview mode), `## Gap questions` (only ask for missing flags — do not re-ask what the brief already answers), `## Output` (write `docs/00-brief.md` + flags). Emphasize: brief mode still ends with the identical `00-brief.md` shape as interview mode.

- [ ] **Step 3: Write `conditional-matrix.md`**

The single source for on/off decisions. A table mapping each flag → which template(s) turn ON:

```markdown
| flag (true) | turns ON | phase |
|---|---|---|
| has_ui | templates/ui-flows.md + UI skeleton | 3, 6 |
| has_api | templates/api-spec.md | 3 |
| has_persistent_data | templates/data-model.md | 2 |
| is_multitenant_saas | templates/infra-security-spec.md + RLS/tenancy skeleton | 2, 6 |
| core_risk_modules[each] | one templates/core-module-spec.md instance per module | 3 |
| is_monorepo | monorepo skeleton (else single-app) | 6 |
```
Plus a `## Universal (always)` list: 00-brief, competitive-landscape, mvp-prd, architecture, glossary, test-strategy, CLAUDE.md, AGENT.md, README, docs-README, roadmap, getting-started, dev-README, dev-WORKFLOW, dev-SESSION-CLOSE, PROGRESS, dashboard.
Plus a worked example: "general web app → api-spec+ui-flows+data-model ON, infra-security + core-module-spec OFF."

- [ ] **Step 4: Verify all three files exist and matrix lists every conditional template**

Run:
```bash
cd /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis
ls references/intake-interview.md references/intake-brief.md references/conditional-matrix.md
grep -E "ui-flows|api-spec|data-model|infra-security|core-module" references/conditional-matrix.md
```
Expected: 3 files listed; grep shows all 5 conditional template names.

- [ ] **Step 5: Commit**

```bash
git add references/intake-interview.md references/intake-brief.md references/conditional-matrix.md
git commit -m "feat(project-genesis): intake modes (interview/brief) + conditional matrix"
```

---

## Task 3: dev-process-wiring reference

**Files:**
- Create: `skill-factory/skills/project-genesis/references/dev-process-wiring.md`

**Interfaces:**
- Consumes: existence of `~/.claude/skills/dev-handoff/regen-progress.mjs` (external, already present).
- Produces: the Phase 5 procedure for standing up `docs/dev/` and the initial `PROGRESS.md`.

- [ ] **Step 1: Write `dev-process-wiring.md`**

Sections: `## Goal` (install the dev-process SSOT into the new project). `## Files to place` (from templates: `dev-README.md`→`docs/dev/README.md`, `dev-WORKFLOW.md`→`docs/dev/WORKFLOW.md`, `dev-SESSION-CLOSE.md`→`docs/dev/SESSION-CLOSE.md`). `## Wire regen-progress` — reference the existing `~/.claude/skills/dev-handoff/regen-progress.mjs`; do not copy/rewrite it; call it to generate the initial `docs/dev/PROGRESS.md` from `roadmap.md` (empty/all-todo state). `## Session handoffs` — `docs/sessions/` is written by the `dev-handoff` skill going forward; project-genesis only creates the empty directory. `## Verify` — run `regen-progress.mjs --check` should report a clean start gate.

- [ ] **Step 2: Verify the referenced script path is correct**

Run:
```bash
ls ~/.claude/skills/dev-handoff/regen-progress.mjs
grep -q "regen-progress.mjs" /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis/references/dev-process-wiring.md && echo "REFERENCED"
```
Expected: script path exists; `REFERENCED` printed.

- [ ] **Step 3: Commit**

```bash
git add references/dev-process-wiring.md
git commit -m "feat(project-genesis): dev-process wiring (reuse dev-handoff/regen-progress.mjs)"
```

---

## Task 4: Template header convention + product-tier templates

**Files:**
- Create: `skill-factory/skills/project-genesis/references/templates/00-brief.md`
- Create: `skill-factory/skills/project-genesis/references/templates/mvp-prd.md`
- Create: `skill-factory/skills/project-genesis/references/templates/competitive-landscape.md`

**Interfaces:**
- Produces: the template header convention (reused by Tasks 5-8) and the Phase 1 templates. `mvp-prd.md` §6 (confirmed stack) and §0 (riskiest assumptions A1..) are the anchors every downstream template cites.

- [ ] **Step 1: Establish the fixed template header (used by ALL templates)**

Every template file begins with this exact comment block (fill the three fields per template):
```markdown
<!-- TEMPLATE: project-genesis
INPUT: <which upstream artifact(s) this is derived from>
OUTPUT: <target path in the new project, e.g. docs/mvp-prd.md>
TIER: <universal | conditional:<flag>> -->
```

- [ ] **Step 2: Write `00-brief.md` template**

Header (INPUT: intake conversation/brief; OUTPUT: docs/00-brief.md; TIER: universal). Body sections (placeholders in `{{...}}`): one-liner, target user & core value, top-3 riskiest assumptions, in-scope, out-of-scope, trait flags block (all flags from Task 2 with example values), stack preference. This is the organized "티키타카 정리" SSOT.

- [ ] **Step 3: Write `mvp-prd.md` template**

Extract structure from `interior-3d-estimator/docs/mvp-prd.md`. Header (INPUT: docs/00-brief.md + competitive-landscape.md; OUTPUT: docs/mvp-prd.md; TIER: universal). Sections (parameterized, keep the numbering): §0 one-liner + riskiest assumptions A1..An + why-MVP-validates; §1 scope (in F1..Fn / out / constraints); §2 persona + happy path; §3 per-feature specs (action/input/output/edge/AC); §4 data model sketch; §5 API outline; §6 **CONFIRMED STACK TABLE** (SoT); §7 glossary pointer; §8 competitive pointer; §9 milestone outline M-1..M5.

- [ ] **Step 4: Write `competitive-landscape.md` template**

Extract from `interior-3d-estimator/docs/competitive-landscape.md`. Header (INPUT: market research + 00-brief; OUTPUT: docs/competitive-landscape.md; TIER: universal). Sections: TL;DR, competitor categories (parameterized list), white-space conclusion, resulting non-goals.

- [ ] **Step 5: Verify header convention present in all three**

Run:
```bash
cd /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis/references/templates
for f in 00-brief.md mvp-prd.md competitive-landscape.md; do grep -q "TEMPLATE: project-genesis" "$f" && echo "$f OK"; done
grep -q "CONFIRMED STACK" mvp-prd.md && echo "stack-table OK"
```
Expected: three `OK` lines + `stack-table OK`.

- [ ] **Step 6: Commit**

```bash
git add references/templates/00-brief.md references/templates/mvp-prd.md references/templates/competitive-landscape.md
git commit -m "feat(project-genesis): template header convention + product-tier templates"
```

---

## Task 5: Architecture / domain templates

**Files:**
- Create: `references/templates/architecture.md`
- Create: `references/templates/glossary.md`
- Create: `references/templates/data-model.md`
- Create: `references/templates/infra-security-spec.md`

**Interfaces:**
- Consumes: the header convention + mvp-prd §4/§6 anchors from Task 4.
- Produces: Phase 2 templates. `data-model.md` is TIER conditional:has_persistent_data; `infra-security-spec.md` is TIER conditional:is_multitenant_saas; the other two universal.

- [ ] **Step 1: Write `architecture.md`** — extract from reference. Sections: components→repo mapping table, data-flow (happy path), dependency-direction rules, key entities pointer, confirmed-stack + open decisions. Header TIER universal, INPUT mvp-prd.md.

- [ ] **Step 2: Write `glossary.md`** — extract from reference. Sections: domain term groups (parameterized), calculation/unit rules table, validation assumptions A1..An. Header TIER universal, INPUT mvp-prd.md.

- [ ] **Step 3: Write `data-model.md`** — extract from reference. Sections: ERD/entity relationships, table definitions (columns/constraints), row-level-security policies (if multi-tenant), indexing, migration, test requirements. Header TIER conditional:has_persistent_data, INPUT mvp-prd.md §4.

- [ ] **Step 4: Write `infra-security-spec.md`** — extract from reference. Sections: blocker list, object-storage isolation, web↔worker trust boundary, ORM×serverless×RLS wiring, tenant-internal authz, document-impact table, out-of-scope, test matrix. Header TIER conditional:is_multitenant_saas, INPUT mvp-prd.md §6.

- [ ] **Step 5: Verify tiers are tagged correctly**

Run:
```bash
cd .../references/templates   # (project-genesis references/templates dir)
grep -l "TIER: conditional:has_persistent_data" data-model.md
grep -l "TIER: conditional:is_multitenant_saas" infra-security-spec.md
grep -l "TIER: universal" architecture.md glossary.md
```
Expected: each file matches its intended tier line.

- [ ] **Step 6: Commit**

```bash
git add references/templates/architecture.md references/templates/glossary.md references/templates/data-model.md references/templates/infra-security-spec.md
git commit -m "feat(project-genesis): architecture/domain templates (tiered)"
```

---

## Task 6: Engineering-spec templates

**Files:**
- Create: `references/templates/api-spec.md`
- Create: `references/templates/ui-flows.md`
- Create: `references/templates/test-strategy.md`
- Create: `references/templates/core-module-spec.md`

**Interfaces:**
- Produces: Phase 3 templates. `api-spec.md` conditional:has_api; `ui-flows.md` conditional:has_ui; `test-strategy.md` universal; `core-module-spec.md` conditional:core_risk_modules (instantiated once per module — the generalization of the reference's estimate-engine-spec/cad-3d-spec).

- [ ] **Step 1: Write `api-spec.md`** — extract from reference. Sections: common rules (auth/tenancy/errors/formats), per-resource endpoint groups (method/path/req/res/errors), async/worker jobs. Header TIER conditional:has_api, INPUT mvp-prd.md §5 + infra-security.

- [ ] **Step 2: Write `ui-flows.md`** — extract from reference. Sections: screen inventory table (S1..Sn), navigation flow, per-screen detail (layout/state/interactions). Header TIER conditional:has_ui, INPUT mvp-prd.md §2.

- [ ] **Step 3: Write `test-strategy.md`** — extract from reference. Sections: test pyramid, TDD-mandatory areas, level-by-level detail, non-functional gates (A1..An), test data, CI gates, out-of-scope. Header TIER universal, INPUT mvp-prd.md §0 + core-module specs.

- [ ] **Step 4: Write `core-module-spec.md`** — GENERALIZE the reference's estimate-engine-spec/cad-3d-spec into a reusable single-module contract. Sections: `{{ModuleName}}` design principles, types/interfaces, formulas/algorithms, invariants (INV1..n), test vectors, unit rules. Header TIER conditional:core_risk_modules, INPUT mvp-prd.md feature ref + glossary.md. Add a note: "instantiate once per entry in `core_risk_modules`, output `docs/{{module}}-spec.md`."

- [ ] **Step 5: Verify**

Run:
```bash
cd .../references/templates
grep -q "TIER: conditional:has_api" api-spec.md && grep -q "TIER: conditional:has_ui" ui-flows.md && grep -q "instantiate once per" core-module-spec.md && echo "ALL OK"
```
Expected: `ALL OK`.

- [ ] **Step 6: Commit**

```bash
git add references/templates/api-spec.md references/templates/ui-flows.md references/templates/test-strategy.md references/templates/core-module-spec.md
git commit -m "feat(project-genesis): engineering-spec templates + generalized core-module-spec"
```

---

## Task 7: Constitution + docs-index templates

**Files:**
- Create: `references/templates/CLAUDE.md`
- Create: `references/templates/AGENT.md`
- Create: `references/templates/README.md`
- Create: `references/templates/docs-README.md`

**Interfaces:**
- Produces: Phase 4 templates (all universal). `CLAUDE.md` §-for-stack pulls verbatim from mvp-prd §6.

- [ ] **Step 1: Write `CLAUDE.md`** — extract from reference. Sections: product one-liner + core value, confirmed tech decisions table (= mvp-prd §6), repo structure + boundary rules, core domain rules, non-functional requirements, AI agent working rules, dev-process SSOT pointer (§7-style referencing docs/dev/), current status. Header TIER universal.

- [ ] **Step 2: Write `AGENT.md`** — extract from reference. Sections: work-startup routine, track-by-track command order, component ownership guide, Definition-of-Done checklist, anti-patterns, dev-SSOT ceremony guide. Header TIER universal, INPUT CLAUDE.md.

- [ ] **Step 3: Write `README.md`** — root overview template: one-liner, problem, stack table, monorepo structure, current status, agent-setup links. Header TIER universal.

- [ ] **Step 4: Write `docs-README.md`** — docs hub: SoT callouts + grouped links (business/architecture/engineering/planning). Header TIER universal, OUTPUT docs/README.md.

- [ ] **Step 5: Verify**

Run:
```bash
cd .../references/templates
for f in CLAUDE.md AGENT.md README.md docs-README.md; do grep -q "TEMPLATE: project-genesis" "$f" && echo "$f OK"; done
```
Expected: four `OK` lines.

- [ ] **Step 6: Commit**

```bash
git add references/templates/CLAUDE.md references/templates/AGENT.md references/templates/README.md references/templates/docs-README.md
git commit -m "feat(project-genesis): constitution + docs-index templates"
```

---

## Task 8: Planning + dev-process + setup templates

**Files:**
- Create: `references/templates/roadmap.md`
- Create: `references/templates/getting-started.md`
- Create: `references/templates/dev-README.md`
- Create: `references/templates/dev-WORKFLOW.md`
- Create: `references/templates/dev-SESSION-CLOSE.md`

**Interfaces:**
- Produces: Phase 5/6 templates. `roadmap.md` defines the M-1..M5 + task-ID structure that `PROGRESS.md` and `dashboard.mjs` (Tasks 9-11) parse. Task-ID format is `M{n}.T{k}` and milestone IDs are `M-1, M0, M1..M5`.

- [ ] **Step 1: Write `roadmap.md`** — extract from reference. Sections: how-to-read/principles, milestone overview table (id/name/goal/size/gate), dependency graph, per-milestone task decomposition (`M{n}.T{k}` bullets with prereqs/exit/gates). Header TIER universal, INPUT mvp-prd.md §9. **Keep milestone-ID and task-ID formats exact** (`M-1`, `M0`..`M5`, `M2.T3`).

- [ ] **Step 2: Write `getting-started.md`** — extract from reference. Sections: prerequisites, confirmed-stack summary, initial setup steps, `.env` template, multi-tenancy wiring (if applicable), common scripts, deployment, seed data, related-docs. Header TIER universal, INPUT infra-security + mvp-prd §6.

- [ ] **Step 3: Write `dev-README.md`, `dev-WORKFLOW.md`, `dev-SESSION-CLOSE.md`** — extract from `interior-3d-estimator/docs/dev/{README,WORKFLOW,SESSION-CLOSE}.md`. These are largely project-agnostic already; parameterize only project name + milestone table. Headers TIER universal, OUTPUT `docs/dev/README.md` etc. `dev-README.md` MUST document the exact PROGRESS.md status vocabulary (todo/doing/blocked/review/done/cut) since dashboard.mjs depends on it.

- [ ] **Step 4: Verify roadmap + progress vocabulary consistency**

Run:
```bash
cd .../references/templates
grep -qE "M-1|M0|M2\.T" roadmap.md && echo "roadmap-ids OK"
grep -qE "todo|doing|blocked|review|done|cut" dev-README.md && echo "status-vocab OK"
```
Expected: `roadmap-ids OK` + `status-vocab OK`.

- [ ] **Step 5: Commit**

```bash
git add references/templates/roadmap.md references/templates/getting-started.md references/templates/dev-README.md references/templates/dev-WORKFLOW.md references/templates/dev-SESSION-CLOSE.md
git commit -m "feat(project-genesis): planning/dev-process/setup templates"
```

---

## Task 9: dashboard.mjs — PROGRESS.md parser (TDD)

**Files:**
- Create: `skill-factory/skills/project-genesis/scripts/dashboard.mjs`
- Create: `skill-factory/skills/project-genesis/scripts/dashboard.test.mjs`
- Create: `skill-factory/skills/project-genesis/scripts/fixtures/PROGRESS.sample.md`

**Interfaces:**
- Produces: `export function parseProgress(md)` returning:
  `{ status: { blocker: string|null, nextAction: string|null, latestHandoff: string|null }, rollup: Array<{id, status, done, total}>, tasks: Record<milestoneId, Array<{id, status, handoff}>> }`

- [ ] **Step 1: Create the fixture `PROGRESS.sample.md`**

Copy the exact format of the reference (header comment, `## 0. 현재 상태` with `- 막힘:`, `- 최신 핸드오프:`, `- 다음 액션:`; `## 1. 롤업` pipe table with columns `그룹|status|done/total`; `## 2. 태스크 상태` with `### M-1` etc. and per-milestone `| ID | status | handoff |` tables). Include at least M-1 (with one `blocked` + one `done` row) and M0 (all todo) so tests cover multiple statuses.

- [ ] **Step 2: Write the failing test for `parseProgress`**

```javascript
// dashboard.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { parseProgress } from './dashboard.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const sample = readFileSync(join(here, 'fixtures/PROGRESS.sample.md'), 'utf8');

test('parseProgress: status section', () => {
  const p = parseProgress(sample);
  assert.equal(p.status.blocker, 'M-1.T3');
  assert.match(p.status.nextAction, /M-1\.T3/);
  assert.match(p.status.latestHandoff, /\.md$/);
});

test('parseProgress: rollup rows', () => {
  const p = parseProgress(sample);
  const m1 = p.rollup.find(r => r.id === 'M-1');
  assert.equal(m1.status, 'doing');
  assert.equal(m1.total, 7);
  assert.ok(m1.done >= 1);
});

test('parseProgress: task tables per milestone', () => {
  const p = parseProgress(sample);
  assert.ok(Array.isArray(p.tasks['M-1']));
  const blocked = p.tasks['M-1'].find(t => t.status === 'blocked');
  assert.ok(blocked, 'expected a blocked task in M-1');
  assert.match(blocked.id, /^M-1\.T\d+$/);
});
```

(Ensure the fixture's `## 0` blocker says `M-1.T3` and M-1 rollup is `doing 3/7` to match these assertions.)

- [ ] **Step 3: Run test to verify it fails**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: FAIL — `parseProgress` is not exported / not defined.

- [ ] **Step 4: Implement `parseProgress` in `dashboard.mjs`**

```javascript
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add skills/project-genesis/scripts/dashboard.mjs skills/project-genesis/scripts/dashboard.test.mjs skills/project-genesis/scripts/fixtures/PROGRESS.sample.md
git commit -m "feat(project-genesis): dashboard PROGRESS.md parser (TDD)"
```

---

## Task 10: dashboard.mjs — session frontmatter parser (TDD)

**Files:**
- Modify: `skill-factory/skills/project-genesis/scripts/dashboard.mjs`
- Modify: `skill-factory/skills/project-genesis/scripts/dashboard.test.mjs`
- Create: `scripts/fixtures/sessions/2026-07-01-100014-boot.md`
- Create: `scripts/fixtures/sessions/2026-07-01-113703-close.md`

**Interfaces:**
- Consumes: nothing from Task 9.
- Produces: `export function parseSession(md, filename)` returning:
  `{ session: string, milestones: string[], tasksTouched: string[], statusAfter: Record<string,string>, nextAction: string|null, meta: boolean, title: string, filename: string }`

- [ ] **Step 1: Create two session fixtures**

Reproduce the reference frontmatter shape exactly, e.g.:
```markdown
---
session: 2026-07-01-100014
milestones: [M-1]
tasks_touched: [M-1.T1]
status_after: { M-1.T1: blocked }
next_action: "M-1.T1 — decide worker PaaS then bootstrap"
covers_commit: a560115
verified: "regen-progress 14/14"
consistency: { hard_errors: [], overrides: [] }
---
# dev-process SSOT bootstrap
```
Second fixture: add `meta: true` and `tasks_touched: []` / `status_after: {}` like the reference `close` handoff.

- [ ] **Step 2: Write the failing test for `parseSession`**

```javascript
import { parseSession } from './dashboard.mjs';

test('parseSession: extracts frontmatter fields', () => {
  const md = readFileSync(join(here, 'fixtures/sessions/2026-07-01-100014-boot.md'), 'utf8');
  const s = parseSession(md, '2026-07-01-100014-boot.md');
  assert.equal(s.session, '2026-07-01-100014');
  assert.deepEqual(s.milestones, ['M-1']);
  assert.deepEqual(s.tasksTouched, ['M-1.T1']);
  assert.equal(s.statusAfter['M-1.T1'], 'blocked');
  assert.match(s.nextAction, /worker PaaS/);
  assert.equal(s.meta, false);
  assert.equal(s.title, 'dev-process SSOT bootstrap');
});

test('parseSession: meta flag + empty arrays', () => {
  const md = readFileSync(join(here, 'fixtures/sessions/2026-07-01-113703-close.md'), 'utf8');
  const s = parseSession(md, '2026-07-01-113703-close.md');
  assert.equal(s.meta, true);
  assert.deepEqual(s.tasksTouched, []);
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: FAIL — `parseSession` not defined.

- [ ] **Step 4: Implement `parseSession`**

```javascript
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: PASS (5 tests total).

- [ ] **Step 6: Commit**

```bash
git add skills/project-genesis/scripts/dashboard.mjs skills/project-genesis/scripts/dashboard.test.mjs skills/project-genesis/scripts/fixtures/sessions/
git commit -m "feat(project-genesis): dashboard session frontmatter parser (TDD)"
```

---

## Task 11: dashboard.mjs — HTML escape + renderer + CLI (TDD)

**Files:**
- Modify: `skill-factory/skills/project-genesis/scripts/dashboard.mjs`
- Modify: `skill-factory/skills/project-genesis/scripts/dashboard.test.mjs`

**Interfaces:**
- Consumes: `parseProgress` (Task 9), `parseSession` (Task 10).
- Produces:
  - `export function escapeHtml(s)` → string with `& < > " '` escaped.
  - `export function renderDashboard({ project, generatedAt, progress, sessions })` → full HTML string.
  - CLI: `node dashboard.mjs <progressPath> <sessionsDir> <outPath>` writes the HTML file.

- [ ] **Step 1: Write failing tests for escape + render**

```javascript
import { escapeHtml, renderDashboard, parseProgress } from './dashboard.mjs';

test('escapeHtml: neutralizes HTML', () => {
  assert.equal(escapeHtml(`<script>"x"&'y'`), '&lt;script&gt;&quot;x&quot;&amp;&#39;y&#39;');
});

test('renderDashboard: injects statuses and escapes text', () => {
  const progress = parseProgress(readFileSync(join(here, 'fixtures/PROGRESS.sample.md'), 'utf8'));
  const sessions = [{
    session: '2026-07-01-100014', milestones: ['M-1'], tasksTouched: ['M-1.T1'],
    statusAfter: { 'M-1.T1': 'blocked' }, nextAction: 'x <b>y</b>', meta: false,
    title: 'boot <img>', filename: 'f.md',
  }];
  const html = renderDashboard({ project: 'Demo & Co', generatedAt: '2026-07-01', progress, sessions });
  assert.match(html, /<!doctype html>/i);
  assert.match(html, /Demo &amp; Co/);              // project name escaped
  assert.match(html, /boot &lt;img&gt;/);           // session title escaped
  assert.ok(!/<img>/.test(html), 'raw <img> must not appear');
  assert.match(html, /c-blocked|s-blocked/);        // status color class present
  assert.match(html, /M-1/);                         // milestone rendered
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: FAIL — `escapeHtml`/`renderDashboard` not defined.

- [ ] **Step 3: Implement escape, render, CLI**

```javascript
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
import { readFileSync as _read, readdirSync, writeFileSync } from 'node:fs';
import { join as _join, basename } from 'node:path';

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
  writeFileSync(outPath, html);
  console.log('dashboard written:', outPath);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
```

Note: place the `export function parseProgress`/`parseSession` from Tasks 9-10 ABOVE this block in the same file; the CLI + render code appends after them.

- [ ] **Step 4: Run tests to verify all pass**

Run: `node --test skills/project-genesis/scripts/dashboard.test.mjs`
Expected: PASS (7 tests total).

- [ ] **Step 5: Commit**

```bash
git add skills/project-genesis/scripts/dashboard.mjs skills/project-genesis/scripts/dashboard.test.mjs
git commit -m "feat(project-genesis): dashboard HTML escape + renderer + CLI (TDD)"
```

---

## Task 12: End-to-end validation + install to global

**Files:**
- Modify: `skill-factory/skills/project-genesis/SKILL.md` (fix the dashboard invocation path if needed)
- Install target: `~/.claude/skills/project-genesis/`

**Interfaces:**
- Consumes: the full skill tree.
- Produces: a globally-installed, smoke-tested skill.

- [ ] **Step 1: Run dashboard against the REAL reference PROGRESS.md**

Run:
```bash
cd /Users/chulheewon/development/main_project/interior-3d-estimator
node /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis/scripts/dashboard.mjs \
  docs/dev/PROGRESS.md docs/sessions /tmp/genesis-dashboard.html
```
Expected: `dashboard written: /tmp/genesis-dashboard.html`.

- [ ] **Step 2: Verify the generated HTML is well-formed and populated**

Run:
```bash
grep -c "class=\"mile\"" /tmp/genesis-dashboard.html   # expect 7 (M-1..M5)
grep -c "class=\"tgrp\"" /tmp/genesis-dashboard.html    # expect 7
grep -q "M-1.T1" /tmp/genesis-dashboard.html && echo "tasks OK"
grep -q "<script>" /tmp/genesis-dashboard.html && echo "UNSAFE" || echo "escape OK"
```
Expected: 7 + 7 + `tasks OK` + `escape OK`.

- [ ] **Step 3: Open it to eyeball the render**

Run: `open /tmp/genesis-dashboard.html`
Expected: dashboard shows M-1 doing/blocked, other milestones todo, session timeline present.

- [ ] **Step 4: Run the full test suite once more**

Run: `node --test /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis/scripts/dashboard.test.mjs`
Expected: all 7 tests PASS.

- [ ] **Step 5: Install to global skills dir (copy, matching dev-lifecycle pattern)**

Run:
```bash
rm -rf ~/.claude/skills/project-genesis
cp -R /Users/chulheewon/development/main_project/skill-factory/skills/project-genesis ~/.claude/skills/project-genesis
ls ~/.claude/skills/project-genesis/SKILL.md && echo "INSTALLED"
```
Expected: `INSTALLED`.

- [ ] **Step 6: Commit the plan completion**

```bash
cd /Users/chulheewon/development/main_project/skill-factory
git add skills/project-genesis
git commit -m "feat(project-genesis): e2e validation + global install"
```

---

## Self-Review

**1. Spec coverage:**
- Spec §2 decisions (2 modes / tiered / orchestration / static HTML / docs+skeleton / name) → Tasks 1,2,4-8 (templates+matrix), 9-11 (dashboard), 12 (install). ✓
- Spec §3 file structure → File Structure section + Tasks 1-11. ✓
- Spec §4 8 phases → SKILL.md (Task 1) documents all 8; templates for each output in Tasks 4-8; dashboard is Phase 7 (Tasks 9-11). ✓
- Spec §5 conditional matrix → Task 2 Step 3. ✓
- Spec §6 orchestration (reuse dev-handoff) → Task 3. ✓
- Spec §7 dashboard (5 sections, 6 colors, @html hardening) → Tasks 9-11 (render covers status bar, rollup, task grid, timeline; overall-progress added; escape enforced). ✓
- Spec §10 success criteria → Task 12 validates against real PROGRESS.md. ✓

**2. Placeholder scan:** Dashboard tasks contain complete runnable code + tests. Template tasks specify exact source reference doc + exact section lists + the fixed header block — the "content" is the derivation instruction, which is the real work for a template-extraction task; no `TODO`/`TBD` left.

**3. Type consistency:** `parseProgress` shape (status/rollup/tasks) consumed identically in Task 11 render. `parseSession` shape (session/milestones/tasksTouched/statusAfter/nextAction/meta/title/filename) matches render's timeline usage. `STATUS_CLASS` keys = the 6 fixed statuses = dev-README vocabulary (Task 8). `escapeHtml`/`renderDashboard`/`parseProgress`/`parseSession` names consistent across tasks 9-12.

**Note on one spec §7 item:** the reference-project dashboard sample also rendered a per-milestone verification gate (A1/A2/A3). `parseProgress` reads only PROGRESS.md (which has no gate column), so gates are omitted from the generated dashboard to avoid inventing data; they remain in `roadmap.md`. This is an intentional narrowing recorded here.
