#!/bin/bash
# dashboard.sh 테스트. 실행: bash tests/test-dashboard.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/dashboard.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$2" | grep -qF "$3"; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (missing [$3])"; fi; }
iso_days_ago() { date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ; }
mk_skill() { mkdir -p "$1/$2"; printf -- "---\nname: %s\ndescription: Use when testing\ncreated_by: %s\n---\nbody\n" "$2" "$3" > "$1/$2/SKILL.md"; }
new_env() { SB=$(mktemp -d); SK="$SB/skills"; PR="$SB/proposals"; mkdir -p "$SK" "$PR"; }
runjson() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$RUN" --json; }
render() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$RUN" --render-stdin; }

# T1: 빈 환경
new_env
OUT=$(runjson)
assert_eq "T1 valid json"     "ok" "$(printf '%s' "$OUT" | jq -e . >/dev/null 2>&1 && echo ok || echo no)"
assert_eq "T1 stale_days"     "30" "$(printf '%s' "$OUT" | jq -r '.thresholds.stale_days')"
assert_eq "T1 archive_days"   "90" "$(printf '%s' "$OUT" | jq -r '.thresholds.archive_days')"
assert_eq "T1 consolidate"    "8"  "$(printf '%s' "$OUT" | jq -r '.thresholds.consolidate_min')"
assert_eq "T1 summary.active" "0"  "$(printf '%s' "$OUT" | jq -r '.summary.active')"
assert_eq "T1 skills empty"   "0"  "$(printf '%s' "$OUT" | jq -r '.skills | length')"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
