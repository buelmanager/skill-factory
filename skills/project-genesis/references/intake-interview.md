# Intake — Interview Mode

## Goal

Run a conversational, one-question-at-a-time intake that produces:

1. `docs/00-brief.md` — the organized, cleaned-up write-up of the user's answers.
2. The trait flags (exact names, consumed by `conditional-matrix.md`): `has_ui`, `has_api`, `has_persistent_data`, `is_multitenant_saas`, `core_risk_modules` (array), `is_monorepo`, `stack` (string).

Use this mode when the user has not already written up their idea — they want to talk it through.

## Ask one at a time

Ask these in order, tiki-taka style — one question, wait for the answer, then the next. Do not front-load multiple questions in one message. Rephrase/probe if an answer is vague; move on once you have a usable answer.

1. **Product one-liner** — "What is this product, in one sentence?"
2. **Target user + core value** — "Who is this for, and what's the core value/problem it solves for them?"
3. **Top 3 riskiest assumptions** — "What are the top 3 riskiest assumptions this project rests on?" (feeds `mvp-prd.md` §0)
4. **In/out scope** — "What's explicitly in scope for v1? What's explicitly out of scope?"
5. **Has UI?** — "Does this have a user-facing UI?" → `has_ui`
6. **Has API?** — "Does this expose an API (public or internal)?" → `has_api`
7. **Persistent data?** — "Does this need to persist data (a database, files, etc.)?" → `has_persistent_data`
8. **Multi-tenant SaaS?** — "Is this a multi-tenant SaaS product (multiple customer orgs sharing the system, needing tenant isolation)?" → `is_multitenant_saas`
9. **Core high-risk modules** — "Are there any core modules that are especially high-risk or complex (e.g. billing, auth, a matching/pricing engine)? List them." → `core_risk_modules` (each entry gets its own `core-module-spec.md` instance)
10. **Monorepo vs single app** — "Should this be a monorepo (multiple packages/apps) or a single app?" → `is_monorepo`
11. **Confirmed stack** — "What's the confirmed tech stack (language, framework, DB, hosting)?" → `stack`

If the idea is fuzzy or the user is still exploring ("I don't know yet", conflicting answers, open-ended brainstorming needed) — pause the question script and delegate that exploration to `superpowers:brainstorming`, then resume the script once the fog clears.

## Output

- Write the organized answers into `docs/00-brief.md` (product one-liner, target user/value, top 3 risks, in/out scope, confirmed stack, and the flag values below).
- Record the flag values exactly as answered — do not infer a flag the user didn't confirm; ask again if an answer was ambiguous.
- This output shape is identical to Brief mode's output (`references/intake-brief.md`) — downstream phases don't know which intake mode produced `00-brief.md`.
