#!/bin/bash
# lifecycle-log.sh 단위 테스트. 실행: bash tests/test-lifecycle-log.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
. "$PKG/bin/lifecycle-log.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }

SB=$(mktemp -d); export GROWING_SKILLS_ROOT="$SB"
F="$SB/.lifecycle-events.jsonl"
lifecycle_log "promoted" "alpha" "사용자 승격" '{"x":1}'
lifecycle_log "archived" "beta" "95일 미사용" '{"idle_days":95}'
assert_eq "two lines"  "2" "$(wc -l < "$F" | tr -d ' ')"
assert_eq "valid json" "ok" "$(jq -e . "$F" >/dev/null 2>&1 && echo ok || echo no)"
assert_eq "event"      "promoted" "$(sed -n 1p "$F" | jq -r .event)"
assert_eq "reason"     "95일 미사용" "$(sed -n 2p "$F" | jq -r .reason)"
assert_eq "meta"       "95" "$(sed -n 2p "$F" | jq -r .metadata.idle_days)"
# 비차단: 빈 event 무시, 호출자 중단 없음
lifecycle_log "" "x" "y"; echo "after-empty: 계속 실행됨"
assert_eq "empty ignored" "2" "$(wc -l < "$F" | tr -d ' ')"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
