---
name: project-genesis
description: Use when starting a brand-new project from scratch — takes customer intake (interview or brief) through mvp-prd, architecture/domain/engineering specs, CLAUDE.md/AGENT.md constitution, roadmap, dev-process SSOT, repo skeleton, and ends by generating a static HTML progress dashboard. For greenfield project initialization up to "ready to code".
---

# Project Genesis

A thin orchestrator that carries a project from customer intake to "ready to code": doc tree + repo skeleton + dev-process SSOT + a static progress dashboard. It does not write application code, and it does not generate documents itself — each doc-generation phase is delegated to a subagent with a template.

## When to use / not use

- **Use** for greenfield project initialization — an empty or brand-new directory with no prior docs, starting from a customer interview or a brief and going up to "ready to code" (M-1 can start).
- **Not** for an existing project mid-development — that's `dev-lifecycle` (feature/bug/refactor track selection).
- **Not** for a single feature or isolated design decision inside an existing project — that's `brainstorming` (optionally `/spec`).

## Phase 0 — Intake (pick a mode)

Ask the user to pick one intake mode before anything else:

- **Interview mode** — conversational back-and-forth. Follow `references/intake-interview.md`.
- **Brief mode** — user pastes an existing brief; gap-fill only. Follow `references/intake-brief.md`.

Output: `docs/00-brief.md` (the cleaned-up SSOT of intake) plus the trait flags decided per `references/conditional-matrix.md` (`has_ui`, `has_api`, `has_persistent_data`, `is_multitenant_saas`, `core_risk_modules[]`, `is_monorepo`, `stack`). These flags drive every conditional output in the phases below.

## The 8 phases

| # | Phase | Outputs | Tier | Upstream input |
|---|---|---|---|---|
| 0 | Intake (mode select) | `docs/00-brief.md` + trait flags | Universal | User conversation/brief |
| 1 | Product definition | `competitive-landscape.md`, `mvp-prd.md` (§0 risk assumptions · §6 confirmed stack · §9 milestone overview) | Universal | 00-brief |
| 2 | Architecture/domain | `architecture.md`, `glossary.md`; *`data-model.md`* (if has_persistent_data), *`infra-security-spec.md`* (if is_multitenant_saas) | Universal + conditional | mvp-prd |
| 3 | Engineering specs | `test-strategy.md`; *`api-spec.md`* (if has_api), *`ui-flows.md`* (if has_ui), *`core-module-spec.md` × N* (one per core_risk_modules entry) | Conditional | mvp-prd, glossary, data-model |
| 4 | Constitution | `CLAUDE.md`, `AGENT.md`, `README.md`, `docs/README.md` | Universal | mvp-prd §6, all prior docs |
| 5 | Plan/dev-process | `docs/roadmap.md` (M-1..M5 · task IDs · gates) + `docs/dev/{README,WORKFLOW,SESSION-CLOSE}` + initial `PROGRESS.md` (regen) | Universal | mvp-prd §9, architecture, infra-security |
| 6 | Repo skeleton | Monorepo/single-app directories + package README + `.env.example` + `getting-started.md` + `infra/README.md` + scaffold commit | Universal + stack-conditional | mvp-prd §6, infra-security |
| 7 | Dashboard | Install `scripts/dashboard.mjs` + generate `docs/dashboard/index.html` → open | Universal (finale) | PROGRESS.md, docs/sessions |

## Delegation rule

Each doc-generation phase (1-6) is dispatched to a subagent, never written inline by the orchestrator. The subagent receives:

1. the phase's template from `references/templates/`,
2. `docs/00-brief.md` plus the named upstream documents for that phase (per the table above),
3. generation instructions (fill the template's placeholders from the brief/upstream docs; preserve the template's section structure and format).

The orchestrator recovers only the written file path(s) from each subagent — never the document body itself. This follows the user's `preserving-main-context` doctrine: the main session holds decisions and paths, not raw generated content.

## Conditional generation

Consult `references/conditional-matrix.md` (using the Phase 0 trait flags) to decide which Phase 2/3/6 outputs are ON vs OFF for this project.

## Reuse

- Intake exploration and any ambiguous-requirement digging inside Phase 0/1 → delegate to `superpowers:brainstorming` (and `/spec` if needed). Do not reinvent question flows here.
- Progress tracking / `PROGRESS.md` generation and validation → `~/.claude/skills/dev-handoff/regen-progress.mjs`, wired as-is in Phase 5 and reused by every later session's dev-handoff. Never reimplement this script.

## Phase gates

After each phase completes, report the written file path(s) to the user and continue to the next phase. If the user wants to edit a document, stop at that point — the pipeline is sequential and resumable, not one uninterruptible run.

## Phase 7 — Dashboard (finale)

Install/locate `scripts/dashboard.mjs` (this skill's own script, at `<skill-dir>/scripts/dashboard.mjs`) and run it against the project's own docs:

```bash
node <skill-dir>/scripts/dashboard.mjs <progressPath> <sessionsDir> <outPath>
# e.g. node <skill-dir>/scripts/dashboard.mjs docs/dev/PROGRESS.md docs/sessions docs/dashboard/index.html
```

Then open the generated HTML. This is the pipeline's finale: the project is now "ready to code" — hand off to `dev-lifecycle`/`WORKFLOW.md` for M-1.
