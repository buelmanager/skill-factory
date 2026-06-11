#!/bin/bash
# digest-transcript.sh 테스트. 실행: bash tests/test-digest.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/digest-transcript.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# 실측 트랜스크립트 구조를 따른 픽스처
cat > "$WORK/t1.jsonl" <<'EOF'
{"type":"user","message":{"content":"hello world string message"}}
{"type":"user","message":{"content":[{"type":"text","text":"array user text"}]}}
{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"secretthought"},{"type":"text","text":"assistant says hi"},{"type":"tool_use","name":"Bash","input":{"command":"ls -la"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","is_error":true,"content":"command failed: boom"}]}}
{"type":"attachment","foo":1}
EOF

# T1: 추출 — USER/TOOL/CLAUDE/ERROR 포함, thinking 제외, 헤더 포함
OUT=$(bash "$BIN" "$WORK/t1.jsonl" "sess-abc" "/tmp/proj")
assert_eq "T1 user string" "1" "$(printf '%s' "$OUT" | grep -c "\[USER\] hello world string message")"
assert_eq "T1 tool line" "1" "$(printf '%s' "$OUT" | grep -c "\[TOOL\] Bash")"
assert_eq "T1 claude line" "1" "$(printf '%s' "$OUT" | grep -c "\[CLAUDE\] assistant says hi")"
assert_eq "T1 error line" "1" "$(printf '%s' "$OUT" | grep -c "\[ERROR\] command failed: boom")"
assert_eq "T1 thinking excluded" "0" "$(printf '%s' "$OUT" | grep -c "secretthought")"
assert_eq "T1 header" "1" "$(printf '%s' "$OUT" | grep -c "=== SESSION sess-abc")"

# T2: 시크릿 마스킹
cat > "$WORK/t2.jsonl" <<'EOF'
{"type":"user","message":{"content":"key is sk-ant-api03-AbCdEf123456789 and ghp_AbCdEfGh123456789012 and password=supersecret999"}}
EOF
OUT=$(bash "$BIN" "$WORK/t2.jsonl" "s" "/tmp")
assert_eq "T2 no sk-ant" "0" "$(printf '%s' "$OUT" | grep -c "sk-ant-api03")"
assert_eq "T2 no ghp" "0" "$(printf '%s' "$OUT" | grep -c "ghp_AbCdEfGh")"
assert_eq "T2 no password value" "0" "$(printf '%s' "$OUT" | grep -c "supersecret999")"
assert_eq "T2 masked marker present" "yes" "$([ "$(printf '%s' "$OUT" | grep -c 'MASKED')" -ge 1 ] && echo yes)"

# T3: 200KB 상한
BIG=$(awk 'BEGIN{for(i=0;i<300000;i++)printf "a"}')
jq -n --arg t "$BIG" '{type:"user",message:{content:$t}}' > "$WORK/t3.jsonl"
SZ=$(bash "$BIN" "$WORK/t3.jsonl" "s" "/tmp" | wc -c | tr -d ' ')
assert_eq "T3 capped" "yes" "$([ "$SZ" -le 200200 ] && echo yes)"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
