---
name: preserving-main-context
description: Use when, in the primary (non-spawned) session, about to read 3+ whole files, paste a long log or search dump into the conversation, run repeated multi-file greps, start a multi-step task (feature, review, migration, audit, research, design), or reason "I must read it myself to explain it" — or when explicitly choosing between workflow, subagent, and inline.
---

# Preserving Main Context

## Overview

The main (orchestrator) session holds only DECISIONS and CONCLUSIONS. Raw material — file contents, broad search results, long logs — is consumed in a SUB-context (subagent or workflow); only the distilled conclusion returns to the main window.

## Routing

| Route | Take it when |
|---|---|
| **Workflow** | Substantive multi-step work (feature impl, code review, migration, audit, research, design) — multiple steps where parallelism or verification is valuable |
| **Single subagent** (Explore / general-purpose) | Answering requires reading/scanning several files: "where is X", find a value/pattern, trace or explain a flow |
| **Inline** | Already know the file and it's one fact / one edit / just talking |

VOLUME OF RAW MATERIAL entering main decides the route — not whether code is edited, and not whether delegation "pays for itself". A read-only "explain/trace end-to-end" task is still ONE investigation → single subagent. Fan out into parallel subagents only when one investigation spans many independent areas.

**Ultracode ON:** the subagent row is absorbed into the workflow row — multi-file lookups, traces, and explanations route to a workflow (e.g. Explore fan-out + adversarial verify); inline remains only for conversational replies and trivial mechanical edits. "No parallel fan-out" is never a reason to downgrade a route under ultracode: tune thoroughness with token-budget directives and quality patterns (adversarial verify, judge panels, loop-until-dry), never by downgrading the route.

This skill's workflow route is an intended Workflow opt-in path. When ultracode is already ON, ultracode's rules take precedence and this table only identifies what stays inline.

## Delegation prompt

Every delegation must state an output contract: return the conclusion plus absolute file:line references only; no quoting of file contents or logs; bounded length (e.g. "under 40 lines"). Without a contract, the delegation saves no main context.

## Read & run discipline

- Use targeted `offset`/`limit` reads; do not pull whole files inline when a slice answers the question.
- Long-running or long-output commands → background or subagent; return pass/fail + the few key lines. Never paste raw build/test logs into main.

## Offload, don't hold

- Durable cross-session facts go to memory files, not the conversation.
- When something must ALWAYS apply, put a one-line pointer in CLAUDE.md and keep the detail in an on-demand skill.

## Red flags

- About to read 3+ whole files into the main window → delegate to one subagent; keep only its conclusion.
- Repeated grep passes building long file lists in main → delegate the multi-file scan; receive the answer.
- Reasoning "I must read it myself to explain it" → that is the subagent's job, not the orchestrator's.
- Wrapping a single fact or one-line edit in a subagent/workflow → do it inline (holds even under ultracode).
- Ultracode OFF only: wrapping an end-to-end explanation in a workflow → single subagent.
- Delegating with no output contract → the report dump lands in main; fix the prompt, not the route.
