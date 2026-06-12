#!/bin/bash
# 프로듀서 emit 통합 테스트. 실행: bash tests/test-lifecycle-capture.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }
iso_days_ago() { date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ; }
mk_skill() { mkdir -p "$1/$2"; printf -- "---\nname: %s\ncreated_by: agent\n---\nbody\n" "$2" > "$1/$2/SKILL.md"; }

# curator-pass: stale(40일) + archive(100일)
SB=$(mktemp -d); SK="$SB/skills"; mkdir -p "$SK"
mk_skill "$SK" old-a; mk_skill "$SK" old-b
jq -n --arg d40 "$(iso_days_ago 40)" --arg d100 "$(iso_days_ago 100)" '{skills:{
  "old-a":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d40,last_activity_at:$d40},
  "old-b":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d100,last_activity_at:$d100}
},compacted_at:null}' > "$SK/.usage.json"
GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" bash "$PKG/bin/curator-pass.sh" >/dev/null 2>&1
LF="$SK/.lifecycle-events.jsonl"
assert_eq "stale emit"   "old-a" "$(jq -r 'select(.event=="stale").skill'    "$LF" 2>/dev/null | head -1)"
assert_eq "archive emit" "old-b" "$(jq -r 'select(.event=="archived").skill' "$LF" 2>/dev/null | head -1)"
assert_eq "archive reason" "ok" "$(jq -r 'select(.event=="archived").reason' "$LF" 2>/dev/null | grep -q 미사용 && echo ok || echo no)"

# dry-run: 이벤트 없음
SB2=$(mktemp -d); SK2="$SB2/skills"; mkdir -p "$SK2"; mk_skill "$SK2" old-c
jq -n --arg d100 "$(iso_days_ago 100)" '{skills:{"old-c":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d100,last_activity_at:$d100}},compacted_at:null}' > "$SK2/.usage.json"
GROWING_SKILLS_ROOT="$SK2" GROWING_SKILLS_HOME="$PKG" bash "$PKG/bin/curator-pass.sh" --dry-run >/dev/null 2>&1
assert_eq "dry-run no emit" "0" "$([ -f "$SK2/.lifecycle-events.jsonl" ] && wc -l < "$SK2/.lifecycle-events.jsonl" | tr -d ' ' || echo 0)"

# 제안 60일 폐기 emit
SB5=$(mktemp -d); SK5="$SB5/skills"; PR5="$SB5/proposals"; mkdir -p "$SK5" "$PR5/stale-prop"
printf -- "---\nname: stale-prop\nproposed_at: %s\n---\nx\n" "$(iso_days_ago 70)" > "$PR5/stale-prop/SKILL.md"
printf '{"skills":{},"compacted_at":null}\n' > "$SK5/.usage.json"
GROWING_SKILLS_ROOT="$SK5" GROWING_SKILLS_HOME="$PKG" GROWING_SKILLS_PROPOSALS_DIR="$PR5" bash "$PKG/bin/curator-pass.sh" >/dev/null 2>&1
assert_eq "discard emit" "stale-prop" "$(jq -r 'select(.event=="discarded").skill' "$SK5/.lifecycle-events.jsonl" 2>/dev/null | head -1)"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
