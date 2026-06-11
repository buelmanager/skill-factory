#!/bin/bash
# curator-pass.sh 테스트 — claude는 PATH 스텁. 실행: bash tests/test-curator-pass.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/curator-pass.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

iso_days_ago() { # n
  date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ
}

mk_skill() { # root name
  mkdir -p "$1/$2"
  printf -- "---\nname: %s\ndescription: Use when testing\ncreated_by: agent\n---\nrefers to old-a here\n" "$2" > "$1/$2/SKILL.md"
}

setup() {
  SB=$(mktemp -d); SK="$SB/skills"; PR="$SB/proposals"
  mkdir -p "$SK" "$PR"
  US="$SK/.usage.json"; ST="$SK/.curator_state"
  # 스킬 4종: old-a(40일 미사용, agent) old-b(100일, agent) pinned-c(100일, agent+pinned) user-d(100일, user)
  mk_skill "$SK" old-a; mk_skill "$SK" old-b; mk_skill "$SK" pinned-c; mk_skill "$SK" user-d
  jq -n --arg d40 "$(iso_days_ago 40)" --arg d100 "$(iso_days_ago 100)" '{
    skills: {
      "old-a":    {use:3, last_activity_at:$d40,  first_seen:$d40,  created_by:"agent", state:"active", pinned:false},
      "old-b":    {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"agent", state:"active", pinned:false},
      "pinned-c": {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"agent", state:"active", pinned:true},
      "user-d":   {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"user",  state:"active", pinned:false}
    }, compacted_at:null}' > "$US"
  STUB="$SB/stub"; mkdir -p "$STUB"
  cat > "$STUB/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$SB/args.log"
cat > "$SB/stdin.log"
STAGING=\$(grep -ho '/[^ ]*\.curator_staging' "$SB/args.log" "$SB/stdin.log" 2>/dev/null | head -1)
if [ "\${STUB_MODE:-good}" = "bad-manifest" ]; then
  printf '{"moves":[{"from":"NOT-IN-INPUT","into":"x","reason":"r"}],"summary":"s"}\n' > "\$STAGING/moves.json"
else
  mkdir -p "\$STAGING/umbrella-skill"
  printf -- "---\nname: umbrella-skill\ndescription: Use when testing umbrellas\ncreated_by: agent\n---\nmerged content\n" > "\$STAGING/umbrella-skill/SKILL.md"
  printf '{"moves":[{"from":"fresh-1","into":"umbrella-skill","reason":"cluster"},{"from":"fresh-2","into":"umbrella-skill","reason":"cluster"}],"summary":"2 narrow into 1 umbrella"}\n' > "\$STAGING/moves.json"
fi
echo "통합 보고"
EOF
  chmod +x "$STUB/claude"
}
teardown() { rm -rf "$SB"; }
run_pass() {
  PATH="$STUB:$PATH" GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_PROPOSALS_DIR="$PR" GROWING_SKILLS_CONSOLIDATE_MIN="${CMIN:-99}" \
    bash "$RUN" "$@"
}

# T1: 수명 전이 — 40일 agent→stale, 100일 agent→archive, pinned·user 불가침
setup
run_pass >/dev/null
assert_eq "T1 40d stale" "stale" "$(jq -r '.skills["old-a"].state' "$US")"
assert_eq "T1 100d archived dir" "yes" "$([ -d "$SK/.archive/old-b" ] && echo yes || echo no)"
assert_eq "T1 100d sidecar" "archived" "$(jq -r '.skills["old-b"].state' "$US")"
assert_eq "T1 pinned untouched" "yes" "$([ -d "$SK/pinned-c" ] && echo yes || echo no)"
assert_eq "T1 user untouched" "yes" "$([ -d "$SK/user-d" ] && echo yes || echo no)"
assert_eq "T1 report exists" "1" "$(command ls "$SK/.curator_reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 snapshot exists" "1" "$(command ls "$SK/.curator_backups"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 stamp written" "yes" "$([ -f "$ST" ] && echo yes || echo no)"
teardown

# T2: dry-run — 아무것도 바뀌지 않고 보고서만 (DRY-RUN 표기), 스탬프 안 찍음
setup
run_pass --dry-run >/dev/null
assert_eq "T2 no stale" "active" "$(jq -r '.skills["old-a"].state' "$US")"
assert_eq "T2 no archive" "no" "$([ -d "$SK/.archive/old-b" ] && echo yes || echo no)"
assert_eq "T2 report dry" "1" "$(grep -l "DRY-RUN" "$SK/.curator_reports"/*.md | wc -l | tr -d ' ')"
assert_eq "T2 no stamp" "no" "$([ -f "$ST" ] && echo yes || echo no)"
teardown

# T3: 제안 60일 폐기 → .discarded로 이동
setup
mkdir -p "$PR/stale-prop"
printf -- "---\nname: stale-prop\nproposed_at: %s\n---\n" "$(iso_days_ago 70)" > "$PR/stale-prop/SKILL.md"
mkdir -p "$PR/fresh-prop"
printf -- "---\nname: fresh-prop\nproposed_at: %s\n---\n" "$(iso_days_ago 5)" > "$PR/fresh-prop/SKILL.md"
run_pass >/dev/null
assert_eq "T3 stale discarded" "yes" "$([ -d "$PR/.discarded/stale-prop" ] && echo yes || echo no)"
assert_eq "T3 fresh kept" "yes" "$([ -d "$PR/fresh-prop" ] && echo yes || echo no)"
teardown

# T4: LLM 통합 — 신선한 agent 스킬 2개 + CMIN=2 → 우산 적용, from들 archive, 참조 재작성
setup
mk_skill "$SK" fresh-1; mk_skill "$SK" fresh-2
mkdir -p "$SK/fresh-3"
printf -- "---\nname: fresh-3\ndescription: t\ncreated_by: agent\n---\nsee fresh-1 for details\n" > "$SK/fresh-3/SKILL.md" # 참조 재작성 대상
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg now "$NOWISO" '.skills += {"fresh-1":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-2":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-3":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false}}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
CMIN=2 run_pass >/dev/null
assert_eq "T4 umbrella installed" "yes" "$([ -f "$SK/umbrella-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T4 umbrella sidecar" "agent" "$(jq -r '.skills["umbrella-skill"].created_by' "$US")"
assert_eq "T4 from archived" "yes" "$([ -d "$SK/.archive/fresh-1" ] && [ -d "$SK/.archive/fresh-2" ] && echo yes || echo no)"
assert_eq "T4 absorbed_into" "umbrella-skill" "$(jq -r '.skills["fresh-1"].absorbed_into' "$US")"
assert_eq "T4 ref rewritten" "1" "$(grep -c "see umbrella-skill for details" "$SK/fresh-3/SKILL.md")"
assert_eq "T4 user file untouched" "1" "$(grep -c "refers to old-a here" "$SK/user-d/SKILL.md")"
teardown

# T5: 불량 매니페스트(입력에 없는 from) → 통합 거부, 스킬 무변경, 보고서에 기록
setup
mk_skill "$SK" fresh-1; mk_skill "$SK" fresh-2
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg now "$NOWISO" '.skills += {"fresh-1":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-2":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false}}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
STUB_MODE=bad-manifest; export STUB_MODE
CMIN=2 run_pass >/dev/null
unset STUB_MODE
assert_eq "T5 fresh-1 intact" "yes" "$([ -d "$SK/fresh-1" ] && echo yes || echo no)"
assert_eq "T5 rejected in report" "1" "$(grep -l "매니페스트 검증 실패" "$SK/.curator_reports"/*.md | wc -l | tr -d ' ')"
teardown

# T6: paused → 즉시 종료, 무변경
setup
printf '{"last_run_at":0,"paused":true}\n' > "$ST"
run_pass >/dev/null
assert_eq "T6 no report" "0" "$(command ls "$SK/.curator_reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
