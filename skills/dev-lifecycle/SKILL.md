---
name: dev-lifecycle
description: Use when starting any development task — feature request, bug report, refactor, or shipping work — and the order of skills/commands must be chosen; when tempted to skip review or verification stages; when choosing between overlapping skills (brainstorming vs /spec, /verify vs /qa, /ship vs finishing-a-development-branch, /investigate vs systematic-debugging); or when deciding whether a stage can be delegated to a subagent.
---

# Dev Lifecycle

Pick exactly one track before doing anything. Run stages in order; skipping a listed stage requires stating why to the user.

## Track Selection (observable triggers)

| Track | Trigger |
|---|---|
| **Light** | Bug report (error/symptom given) OR trivial edit (one file, one fact: typo, config value) |
| **Heavy** | Any of: requirements ambiguous enough to need a spec; spans multiple sessions; hard-to-reverse decision; security/data boundary change. Runs with ultracode (full delegation budget). |
| **Basic** | Everything else — default for ordinary features/improvements |

## Command Order (cheat sheet)

```
Basic : brainstorming → writing-plans → subagent-driven-development(+TDD)
        → /code-review (medium) → /verify (UI: /qa-only --quick) → /ship
        [worktree first ONLY if the feature spans multiple sessions]
        [→ /land-and-deploy → /canary --quick only if deploy target]
Light : bug    → /investigate "<symptom>" → /ship (direct commit if tiny)
        trivial→ fix inline → one verification run → commit. No skills, no subagents.
Heavy : /spec → writing-plans → /plan-eng-review → worktree + /freeze (mandatory here)
        → subagent-driven-development (parallel independent tasks) → /simplify → /code-review (medium)
        → /codex review (optional: only irreversible OR security-sensitive changes)
        → /security-review (required if auth/input/secrets touched) → /qa
        → /ship → /land-and-deploy → /canary --quick
```

Non-skippable when tempted: worktree+/freeze on the heavy track; /code-review after implementation (per-task SDD reviews do not replace the whole-diff review); /ship instead of manual commit+PR.

## Context-Protection Profile (per stage)

| Stage | Where | Why |
|---|---|---|
| Pre-plan codebase research | DELEGATE (one subagent) | multi-file reads; keeps main lean |
| Implementation | DELEGATE via subagent-driven-development | global rule; main stays orchestrator |
| Interactive gstack skills (/spec, /plan-*-review, /autoplan, /qa, /design-*) | MAIN only | they run on AskUserQuestion gates; a subagent cannot surface those questions, so delegating breaks the skill |
| Irreversible gates (/ship, /land-and-deploy) | MAIN only | gate stops must reach the user live; delegation is unsafe, not just wasteful |
| Trivial edits | INLINE | dispatch overhead exceeds the work |

Delegation mechanics (subagent vs workflow vs inline) follow preserving-main-context.

## Per-Stage Model Profile

Match model to a stage's reasoning load + irreversibility, not its token volume. Mechanism: main-session stages run on whatever the session model is — so set the session model to the strong tier; only *delegated* subagents can take a per-agent override (Agent `model` / workflow `opts.model`). Two tiers only — finer splits cost more in config drift than they save.

| Tier | Stages | Model |
|---|---|---|
| **Strong** (reasoning / implementation / verification / gates) | brainstorming, /spec, writing-plans, /plan-*-review, SDD implementation, /code-review, /simplify, /verify, /qa, /ship | strongest available coding model — **Fable 5** (2026-06: GA flagship above Opus, coding + finance + long-agentic leader); **Opus 4.8** = half-cost fallback |
| **Cheap** (read-only / mechanical, output re-validated downstream) | pre-plan codebase research & Explore fan-out, /freeze + git mechanics, /canary, /land-and-deploy, routine test scaffolding | Sonnet 4.6 / Haiku 4.5 |

- Default = session model everywhere; override DOWN to cheap only for the read-only/mechanical subagents above.
- Never downgrade correctness-critical implementation (determinism, security boundaries) to the cheap tier.
- Security-sensitive prompts (cybersecurity, secrets/keyring) auto-route to Opus 4.8 regardless — no manual override needed.
- Cross-*family* review stays /codex review (OpenAI); model tiering here is within the Claude family and gives capability/cost matching, not an independent second opinion.

## Overlap Rules

- brainstorming beats /spec by default; /spec only on heavy track.
- writing-plans beats /autoplan; reserve /autoplan for rare product-direction overhauls.
- Built-in /code-review beats gstack /review: /ship runs /review internally, so running it earlier double-spends.
- /verify beats /qa by default; /qa only for release-grade UI work.
- /ship beats finishing-a-development-branch (versioning/CHANGELOG/PR superset) — do not substitute.
- Main-session bug report → /investigate (fix + regression test + learnings in one cycle); systematic-debugging only inside subagents; one-minute obvious bug → inline.

Before /ship or any commit: verify git identity matches the project's CLAUDE.md account rules.
