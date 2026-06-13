---
name: dev-lifecycle
description: Use when starting any development task — feature request, bug report, refactor, or shipping work — and the order of skills/commands must be chosen; when tempted to skip review or verification stages; when choosing between overlapping skills (brainstorming vs /spec, /verify vs /qa, /ship vs finishing-a-development-branch, /investigate vs systematic-debugging); or when deciding whether a stage can be delegated to a subagent.
---

# Dev Lifecycle

Pick one **base track** (work-kind + clarity), then layer on any **risk gates** that fire. Gates are evaluated first and override — a "trivial" or "bug" label never exempts a change from a gate. Run stages in order; skipping a listed stage requires stating why to the user, but a fired risk gate is non-skippable.

## Track Selection

### Base track (work-kind + clarity)

| Track | Trigger |
|---|---|
| **Light** | Clear bug (error/symptom given) OR trivial edit (one file, one fact: typo, config value) |
| **Heavy** | Requirements ambiguous enough to need a spec, OR spans multiple sessions. = Basic with /spec + /plan-eng-review prepended. Runs with ultracode (full delegation budget). |
| **Basic** | Everything else — default for ordinary features/improvements |

### Risk gates (independent overlay — check first, apply on top of ANY track)

| Gate fires when | Attach regardless of base track |
|---|---|
| Security / data boundary touched (auth, input, secrets, data exposure) | + /security-review (required, before /ship); prompt stays on Opus 4.8 |
| Hard-to-reverse (schema/data migration, public API change, deletion) | + worktree + /freeze (before implementation) + /codex review (before /ship) |
| Deploy target | + /land-and-deploy → /canary --quick (after /ship) |
| Release-grade UI | /verify becomes full /qa |

"One file, one config value" is not "low risk" — a single line that flips a security/data boundary stays Light in structure but still carries the security gate.

## Command Order (cheat sheet)

Base track — pick one:
```
Light : clear bug → /investigate "<symptom>" → /ship (direct commit if tiny)
        trivial   → fix inline → one verification run → commit. No skills, no subagents.
Basic : brainstorming → writing-plans → subagent-driven-development(+TDD)
        → /code-review (medium) → /verify (UI: /qa-only --quick) → /ship
        [skip brainstorming when requirements are already clear — say why; first-class path, not an exception]
        [worktree first ONLY if the work spans multiple sessions]
Heavy : /spec → writing-plans → /plan-eng-review → worktree (isolation)
        → subagent-driven-development(+TDD, parallel independent tasks)
        → /simplify → /code-review (medium) → /verify (UI: /qa-only --quick) → /ship
```

Risk gates — layer onto whichever track above, ordered relative to it:
```
security/data boundary → /security-review before /ship (required)
hard-to-reverse        → worktree + /freeze before implementation; /codex review before /ship
deploy target          → /land-and-deploy → /canary --quick after /ship
release-grade UI        → /verify (or /qa-only --quick) becomes full /qa
```
(All four gates firing on a Heavy base reproduces the old full heavy line: /spec → … → worktree+/freeze → SDD → /simplify → /code-review → /codex review → /security-review → /qa → /ship → /land-and-deploy → /canary.)

Non-skippable when tempted: any fired risk gate (you cannot drop /security-review or /freeze just because the base track is Light/Basic); /code-review after implementation (per-task SDD reviews do not replace the whole-diff review); /ship instead of manual commit+PR.

Escalation: the track is chosen once, but re-declare if discovery changes the picture — a Light bug whose fix spans multiple files or crosses a boundary becomes Basic/Heavy plus the relevant gate. Surface the re-route to the user.

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
| **Strong** (reasoning / implementation / verification / gates) | brainstorming, /spec, writing-plans, /plan-*-review, SDD implementation, /code-review, /simplify, /verify, /qa, /ship | strongest available coding model — **Opus 4.8** |
| **Cheap** (read-only / mechanical, output re-validated downstream) | pre-plan codebase research & Explore fan-out, /freeze + git mechanics, /canary, /land-and-deploy, routine test scaffolding | Sonnet 4.6 / Haiku 4.5 |

- Default = session model everywhere; override DOWN to cheap only for the read-only/mechanical subagents above.
- Never downgrade correctness-critical implementation (determinism, security boundaries) to the cheap tier.
- Security-sensitive prompts (cybersecurity, secrets/keyring) stay on Opus 4.8 — never downgrade them to the cheap tier.
- Cross-*family* review stays /codex review (OpenAI); model tiering here is within the Claude family and gives capability/cost matching, not an independent second opinion.

## Overlap Rules

- brainstorming beats /spec by default; /spec only on heavy track.
- writing-plans beats /autoplan; reserve /autoplan for rare product-direction overhauls.
- Built-in /code-review beats gstack /review: /ship runs /review internally, so running it earlier double-spends.
- /verify beats /qa by default; /qa only for release-grade UI work.
- /ship beats finishing-a-development-branch (versioning/CHANGELOG/PR superset) — do not substitute.
- Main-session bug report → /investigate (fix + regression test + learnings in one cycle); systematic-debugging only inside subagents; one-minute obvious bug → inline.

Before /ship or any commit: verify git identity matches the project's CLAUDE.md account rules.
