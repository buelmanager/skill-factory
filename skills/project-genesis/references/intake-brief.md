# Intake — Brief Mode

## Goal

The user pastes an existing brief (idea doc, one-pager, notes, etc.) instead of doing a live interview. Parse it, gap-fill only what's missing, and produce the identical output shape as Interview mode:

1. `docs/00-brief.md` — the organized, cleaned-up write-up.
2. The trait flags (exact names): `has_ui`, `has_api`, `has_persistent_data`, `is_multitenant_saas`, `core_risk_modules` (array), `is_monorepo`, `stack` (string).

Use this mode when the user has already written something up and wants to paste it rather than be interviewed field by field.

## Parse

Read the pasted brief and extract the same fields Interview mode collects:

- Product one-liner
- Target user + core value
- Top 3 riskiest assumptions (→ `mvp-prd.md` §0)
- In/out scope
- `has_ui`
- `has_api`
- `has_persistent_data`
- `is_multitenant_saas`
- `core_risk_modules` (array)
- `is_monorepo`
- `stack`

Map whatever the brief states onto these fields, even if the brief uses different words (e.g. "web dashboard" implies `has_ui: true`). Do not force the user's prose into the fields verbatim — normalize into the flag vocabulary.

## Gap questions

After parsing, list which of the fields/flags above are still MISSING or ambiguous. Ask about **only those** — one at a time, same tiki-taka style as Interview mode. Do not re-ask anything the brief already answered; re-confirming settled answers wastes the user's time and defeats the point of brief mode.

If the brief itself is too fuzzy to parse at all (no clear product concept), fall back to delegating exploration to `superpowers:brainstorming` rather than guessing flag values.

## Output

- Write the organized answers (parsed + gap-filled) into `docs/00-brief.md` — same structure as Interview mode's output.
- Record the flag values exactly as determined (parsed from brief or answered in gap questions) — never leave a flag silently unset; if truly undetermined after gap questions, ask again rather than defaulting.
- This output shape is identical to Interview mode's output (`references/intake-interview.md`) — downstream phases don't know which intake mode produced `00-brief.md`.
