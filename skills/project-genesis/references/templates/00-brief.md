<!-- TEMPLATE: project-genesis
INPUT: intake conversation/brief
OUTPUT: docs/00-brief.md
TIER: universal -->

# 00-Brief — {{project_name}}

> This is the organized, cleaned-up write-up of Phase 0 intake (interview or brief mode). It is the single source of truth downstream phases read from — they do not know which intake mode produced it.

## Product one-liner

> {{product_one_liner}}

## Target user & core value

- **Target user**: {{target_user}}
- **Core value / problem solved**: {{core_value}}

## Top 3 riskiest assumptions

The riskiest assumptions this project rests on (feeds `mvp-prd.md` §0 as `A1, A2, A3`):

1. **A1 — {{assumption_1_label}}**: {{assumption_1_detail}}
2. **A2 — {{assumption_2_label}}**: {{assumption_2_detail}}
3. **A3 — {{assumption_3_label}}**: {{assumption_3_detail}}

## Scope

### In-scope (v1)

- {{in_scope_item_1}}
- {{in_scope_item_2}}

### Out-of-scope (v1)

- {{out_of_scope_item_1}}
- {{out_of_scope_item_2}}

## Trait flags

The flags below drive every conditional output per `references/conditional-matrix.md`. Never leave a flag unset — if undetermined, it must be resolved before Phase 0 completes.

| Flag | Value | Notes |
|---|---|---|
| `has_ui` | {{has_ui}} | e.g. `true` |
| `has_api` | {{has_api}} | e.g. `true` |
| `has_persistent_data` | {{has_persistent_data}} | e.g. `true` |
| `is_multitenant_saas` | {{is_multitenant_saas}} | e.g. `false` |
| `core_risk_modules` | {{core_risk_modules}} | array, e.g. `["billing", "matching-engine"]` |
| `is_monorepo` | {{is_monorepo}} | e.g. `true` |

## Stack preference

- **Confirmed / preferred stack**: {{stack}}
