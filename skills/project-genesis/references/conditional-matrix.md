# Conditional Matrix

The single source of truth for which documents/skeletons turn ON or OFF, based on the Phase 0 trait flags (`references/intake-interview.md` / `references/intake-brief.md`).

## Conditional (flag-driven)

| flag (true) | turns ON | phase |
|---|---|---|
| `has_ui` | `templates/ui-flows.md` + UI skeleton | 3, 6 |
| `has_api` | `templates/api-spec.md` | 3 |
| `has_persistent_data` | `templates/data-model.md` | 2 |
| `is_multitenant_saas` | `templates/infra-security-spec.md` + RLS/tenancy skeleton | 2, 6 |
| `core_risk_modules[each]` | one `templates/core-module-spec.md` instance per module | 3 |
| `is_monorepo` | monorepo skeleton (else single-app) | 6 |

Each row is independent — flags are not mutually exclusive. `core_risk_modules` fans out to N instances (one per array entry), not a single on/off.

## Universal (always)

These are generated regardless of flag values:

- `00-brief.md`
- `competitive-landscape.md`
- `mvp-prd.md`
- `architecture.md`
- `glossary.md`
- `test-strategy.md`
- `CLAUDE.md`
- `AGENT.md`
- `README.md`
- `docs/README.md`
- `roadmap.md`
- `getting-started.md`
- `docs/dev/README.md`
- `docs/dev/WORKFLOW.md`
- `docs/dev/SESSION-CLOSE.md`
- `PROGRESS.md`
- dashboard (`docs/dashboard/index.html`)

## Worked example

**General web app** with a UI, a backend API, and a database, but not multi-tenant SaaS and no flagged high-risk core modules:

- `has_ui: true`, `has_api: true`, `has_persistent_data: true`
- `is_multitenant_saas: false`, `core_risk_modules: []`

Result: `templates/api-spec.md` + `templates/ui-flows.md` + `templates/data-model.md` turn **ON**. `templates/infra-security-spec.md` and `templates/core-module-spec.md` stay **OFF** (no multi-tenant isolation concerns, no flagged high-risk modules). All Universal docs are generated as usual.
