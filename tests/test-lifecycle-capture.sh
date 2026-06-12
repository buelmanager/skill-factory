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

# curator-ctl promote
SB3=$(mktemp -d); SK3="$SB3/skills"; PR3="$SB3/proposals"; mkdir -p "$SK3" "$PR3/new-skill"
printf -- "---\nname: new-skill\ncreated_by: agent\nproposed_at: %s\n---\nx\n" "$(date +%Y-%m-%d)" > "$PR3/new-skill/SKILL.md"
printf '{"skills":{},"compacted_at":null}\n' > "$SK3/.usage.json"
GROWING_SKILLS_ROOT="$SK3" GROWING_SKILLS_PROPOSALS_DIR="$PR3" bash "$PKG/bin/curator-ctl.sh" promote new-skill >/dev/null 2>&1
assert_eq "promote emit" "new-skill" "$(jq -r 'select(.event=="promoted").skill' "$SK3/.lifecycle-events.jsonl" 2>/dev/null | head -1)"
# restore
mkdir -p "$SK3/.archive/gone"; printf -- "---\nname: gone\n---\nx\n" > "$SK3/.archive/gone/SKILL.md"
GROWING_SKILLS_ROOT="$SK3" GROWING_SKILLS_PROPOSALS_DIR="$PR3" bash "$PKG/bin/curator-ctl.sh" restore gone >/dev/null 2>&1
assert_eq "restore emit" "gone" "$(jq -r 'select(.event=="restored").skill' "$SK3/.lifecycle-events.jsonl" 2>/dev/null | head -1)"

# run-reviewer proposed emit (claude 스텁이 rationale 포함 제안 작성)
SB4=$(mktemp -d); SK4="$SB4/skills"; PR4="$SB4/proposals"; STUB="$SB4/stub"
mkdir -p "$SK4/.review-queue" "$PR4" "$STUB"
printf 'digest content\n' > "$SK4/.review-queue/20260611-000000-x.md"
cat > "$STUB/claude" <<STUBEOF
#!/bin/bash
mkdir -p "$PR4/fixing-x"
printf -- "---\nname: fixing-x\ndescription: Use when...\ncreated_by: agent\nproposed_at: %s\nsource_session: sess-9\nrationale: git rebase 충돌을 반복 수동 해결함\n---\nproc\n" "\$(date +%Y-%m-%d)" > "$PR4/fixing-x/SKILL.md"
echo "리뷰 보고"
STUBEOF
chmod +x "$STUB/claude"
PATH="$STUB:$PATH" GROWING_SKILLS_FORCE=1 GROWING_SKILLS_ROOT="$SK4" GROWING_SKILLS_HOME="$PKG" GROWING_SKILLS_PROPOSALS_DIR="$PR4" bash "$PKG/bin/run-reviewer.sh" >/dev/null 2>&1
LF4="$SK4/.lifecycle-events.jsonl"
assert_eq "proposed emit"   "fixing-x" "$(jq -r 'select(.event=="proposed").skill' "$LF4" 2>/dev/null | head -1)"
assert_eq "proposed reason" "ok" "$(jq -r 'select(.event=="proposed").reason' "$LF4" 2>/dev/null | grep -q rebase && echo ok || echo no)"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
