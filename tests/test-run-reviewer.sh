#!/bin/bash
# run-reviewer.sh 테스트 — claude는 PATH 스텁. 실행: bash tests/test-run-reviewer.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/run-reviewer.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SB=$(mktemp -d)
  SKILLS="$SB/skills"; QUEUE="$SKILLS/.review-queue"
  PROPOSALS="$SB/proposals"; WIKI="$SB/wiki"
  mkdir -p "$QUEUE" "$PROPOSALS" "$WIKI/domains/dev/raw"
  printf '=== SESSION aaa (tools: 20) ===\n[USER] do x\n' > "$QUEUE/20260611-000001-aaa.md"
  printf '=== SESSION bbb (tools: 18) ===\n[USER] do y\n' > "$QUEUE/20260611-000002-bbb.md"
  # claude 스텁
  STUB="$SB/stub"; mkdir -p "$STUB"
  cat > "$STUB/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$SB/args.log"
echo "ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-UNSET}" > "$SB/env.log"
echo "GROWING_SKILLS_BG=\${GROWING_SKILLS_BG:-UNSET}" >> "$SB/env.log"
cat > "$SB/stdin.log"
[ "\${STUB_FAIL:-}" = "1" ] && exit 1
echo "리뷰 완료: 제안 1건"
EOF
  chmod +x "$STUB/claude"
}
teardown() { rm -rf "$SB"; }

run_reviewer() {
  PATH="$STUB:$PATH" GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_PROPOSALS_DIR="$PROPOSALS" WIKI_BODY_PATH="$WIKI" \
    GROWING_SKILLS_FORCE="${FORCE:-1}" bash "$RUN"
}

# T1: 신선한 락 → 실행 안 함, 큐 보존
setup
printf '%s\n%s\n' 99999 "$(date +%s)" > "$SKILLS/.reviewer.lock"
run_reviewer
assert_eq "T1 no claude run" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T1 queue intact" "2" "$(ls "$QUEUE"/*.md | wc -l | tr -d ' ')"
teardown

# T2: stale 락(3시간 전) → 실행됨, 종료 후 락 해제
setup
printf '%s\n%s\n' 99999 "$(( $(date +%s) - 10800 ))" > "$SKILLS/.reviewer.lock"
run_reviewer
assert_eq "T2 claude ran" "yes" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T2 lock released" "no" "$([ -f "$SKILLS/.reviewer.lock" ] && echo yes || echo no)"
teardown

# T3: 일간 게이트 — 최근 실행 기록 + FORCE 미설정 → 스킵; FORCE=1 → 실행
setup
printf '{"last_run_at": %s}\n' "$(date +%s)" > "$SKILLS/.reviewer_state"
FORCE=0 run_reviewer
assert_eq "T3 gated skip" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
run_reviewer
assert_eq "T3 force runs" "yes" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
teardown

# T4: 빈 큐 → 실행 안 함, 스탬프 안 찍음
setup
rm -f "$QUEUE"/*.md
run_reviewer
assert_eq "T4 no run" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T4 no stamp" "no" "$([ -f "$SKILLS/.reviewer_state" ] && echo yes || echo no)"
teardown

# T5: 정상 실행 — 배치 stdin, 격리 env, 인자, 큐 이동, 보고서, write-ahead 스탬프
setup
run_reviewer
assert_eq "T5 report exists" "1" "$(ls "$SKILLS/.review-reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T5 queue drained" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T5 done has both" "2" "$(ls "$QUEUE/done"/*.md | wc -l | tr -d ' ')"
assert_eq "T5 stdin has aaa" "1" "$(grep -c "SESSION aaa" "$SB/stdin.log")"
assert_eq "T5 stdin has bbb" "1" "$(grep -c "SESSION bbb" "$SB/stdin.log")"
assert_eq "T5 api key unset" "1" "$(grep -c "ANTHROPIC_API_KEY=UNSET" "$SB/env.log")"
assert_eq "T5 bg marker" "1" "$(grep -c "GROWING_SKILLS_BG=1" "$SB/env.log")"
assert_eq "T5 strict mcp" "1" "$(grep -c -- "--strict-mcp-config" "$SB/args.log")"
assert_eq "T5 stamp written" "yes" "$([ -f "$SKILLS/.reviewer_state" ] && echo yes || echo no)"
teardown

# T6: claude 실패 → 큐 보존, 보고서에 실패 기록
setup
STUB_FAIL=1; export STUB_FAIL
run_reviewer
unset STUB_FAIL
assert_eq "T6 queue preserved" "2" "$(ls "$QUEUE"/*.md | wc -l | tr -d ' ')"
assert_eq "T6 failure noted" "1" "$(grep -c "실패" "$SKILLS/.review-reports"/*.md)"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
