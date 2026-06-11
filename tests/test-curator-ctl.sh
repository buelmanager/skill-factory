#!/bin/bash
# curator-ctl.sh 테스트. 실행: bash tests/test-curator-ctl.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/curator-ctl.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SK=$(mktemp -d); PR=$(mktemp -d)
  US="$SK/.usage.json"; ST="$SK/.curator_state"
  printf '{"skills":{},"compacted_at":null}\n' > "$US"
  mkdir -p "$PR/new-skill"
  printf -- "---\nname: new-skill\ndescription: Use when testing promote\ncreated_by: agent\n---\nbody\n" > "$PR/new-skill/SKILL.md"
}
teardown() { rm -rf "$SK" "$PR"; }
ctl() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$BIN" "$@"; }

# T1: promote — 제안을 skills로 이동 + 사이드카 created_by:agent 등록
setup
ctl promote new-skill >/dev/null
assert_eq "T1 moved" "yes" "$([ -f "$SK/new-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T1 proposal gone" "no" "$([ -d "$PR/new-skill" ] && echo yes || echo no)"
assert_eq "T1 sidecar agent" "agent" "$(jq -r '.skills["new-skill"].created_by' "$US")"
assert_eq "T1 sidecar active" "active" "$(jq -r '.skills["new-skill"].state' "$US")"

# T2: promote 중복 → 오류, 비파괴
ctl promote new-skill >/dev/null 2>&1
assert_eq "T2 dup rejected" "1" "$?"

# T3: pin / unpin
ctl pin new-skill >/dev/null
assert_eq "T3 pinned" "true" "$(jq -r '.skills["new-skill"].pinned' "$US")"
ctl unpin new-skill >/dev/null
assert_eq "T3 unpinned" "false" "$(jq -r '.skills["new-skill"].pinned' "$US")"

# T4: pause / resume
ctl pause >/dev/null
assert_eq "T4 paused" "true" "$(jq -r '.paused' "$ST")"
ctl resume >/dev/null
assert_eq "T4 resumed" "false" "$(jq -r '.paused' "$ST")"

# T5: restore — .archive에서 복원 + state active
mkdir -p "$SK/.archive/old-skill"
printf -- "---\nname: old-skill\ndescription: t\n---\n" > "$SK/.archive/old-skill/SKILL.md"
jq '.skills["old-skill"] = {use:1, created_by:"agent", state:"archived", pinned:false}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
ctl restore old-skill >/dev/null
assert_eq "T5 restored" "yes" "$([ -f "$SK/old-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T5 state active" "active" "$(jq -r '.skills["old-skill"].state' "$US")"

# T6: adopt — 사용자 스킬 수명 관리 옵트인 (curated 플래그)
mkdir -p "$SK/user-skill"
printf -- "---\nname: user-skill\ndescription: t\n---\n" > "$SK/user-skill/SKILL.md"
ctl adopt user-skill >/dev/null
assert_eq "T6 curated" "true" "$(jq -r '.skills["user-skill"].curated' "$US")"
assert_eq "T6 still user" "user" "$(jq -r '.skills["user-skill"].created_by' "$US")"

# T7: status — 핵심 수치 출력
OUT=$(ctl status)
assert_eq "T7 has agent count" "1" "$(printf '%s' "$OUT" | grep -c "agent 스킬:")"
assert_eq "T7 has proposals" "1" "$(printf '%s' "$OUT" | grep -c "대기 제안:")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
