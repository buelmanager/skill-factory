#!/bin/bash
# session-end-queue.sh 테스트. 실행: bash tests/test-queue-hook.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
HOOK="$PKG/hooks/session-end-queue.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

mk_transcript() { # path tool_count
  : > "$1"
  i=0
  while [ "$i" -lt "$2" ]; do
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}]}}' >> "$1"
    i=$((i+1))
  done
  echo '{"type":"user","message":{"content":"do the thing"}}' >> "$1"
}

setup() {
  SB=$(mktemp -d)
  SKILLS="$SB/skills"; mkdir -p "$SKILLS"
  QUEUE="$SKILLS/.review-queue"
}
teardown() { rm -rf "$SB"; }

run_hook() { # payload
  printf '%s' "$1" | GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_MIN_TOOLS=3 GROWING_SKILLS_NO_SPAWN=1 \
    GROWING_SKILLS_PROJECTS_DIR="$SB/projects" bash "$HOOK"
}

# T1: 자격 세션(도구 4 ≥ 임계 3) + transcript_path 명시 → 큐 적재
setup
mk_transcript "$SB/t.jsonl" 4
run_hook "{\"session_id\":\"sess-12345678\",\"cwd\":\"/tmp/p\",\"transcript_path\":\"$SB/t.jsonl\"}"
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 one queue file" "1" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 header in digest" "1" "$(grep -c "=== SESSION sess-12345678" "$QUEUE"/*.md)"
teardown

# T2: 임계 미달(도구 2 < 3) → 적재 안 함
setup
mk_transcript "$SB/t.jsonl" 2
run_hook "{\"session_id\":\"s\",\"cwd\":\"/tmp\",\"transcript_path\":\"$SB/t.jsonl\"}"
assert_eq "T2 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T3: 백그라운드 마커 → 적재 안 함
setup
mk_transcript "$SB/t.jsonl" 4
printf '%s' "{\"session_id\":\"s\",\"cwd\":\"/tmp\",\"transcript_path\":\"$SB/t.jsonl\"}" \
  | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_MIN_TOOLS=3 GROWING_SKILLS_NO_SPAWN=1 bash "$HOOK"
assert_eq "T3 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T4: transcript_path 없음 → cwd+session_id 파생 경로 폴백
setup
mkdir -p "$SB/projects/-tmp-my-proj"
mk_transcript "$SB/projects/-tmp-my-proj/sess-99.jsonl" 4
run_hook "{\"session_id\":\"sess-99\",\"cwd\":\"/tmp/my_proj\"}"
assert_eq "T4 derived queue file" "1" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T5: 깨진 페이로드 → exit 0, 적재 안 함
setup
run_hook 'not-json{{{'
assert_eq "T5 exit 0" "0" "$?"
assert_eq "T5 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
