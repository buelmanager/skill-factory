#!/bin/bash
# compact-events.sh 테스트. 실행: bash tests/test-compact-events.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/compact-events.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() { SK=$(mktemp -d); EV="$SK/.usage-events.jsonl"; US="$SK/.usage.json"; }
teardown() { rm -rf "$SK"; }
run_compact() { GROWING_SKILLS_ROOT="$SK" bash "$BIN"; }

# T1: 신규 스킬 이벤트 → created_by:user 기본으로 등록, use 집계, last_activity 기록
setup
printf '{"ts":"2026-06-10T01:00:00Z","skill":"alpha","event":"use","session":"s1"}\n{"ts":"2026-06-11T02:00:00Z","skill":"alpha","event":"use","session":"s2"}\n{"ts":"2026-06-11T03:00:00Z","skill":"beta","event":"use","session":"s2"}\n' > "$EV"
run_compact
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 alpha use" "2" "$(jq -r '.skills.alpha.use' "$US")"
assert_eq "T1 alpha last" "2026-06-11T02:00:00Z" "$(jq -r '.skills.alpha.last_activity_at' "$US")"
assert_eq "T1 alpha created_by" "user" "$(jq -r '.skills.alpha.created_by' "$US")"
assert_eq "T1 beta registered" "1" "$(jq -r '.skills.beta.use' "$US")"
assert_eq "T1 events rotated" "no" "$([ -f "$EV" ] && echo yes || echo no)"
teardown

# T2: 기존 사이드카에 누적 + stale 부활 + agent 필드 보존
setup
printf '{"skills":{"alpha":{"use":5,"last_activity_at":"2026-01-01T00:00:00Z","first_seen":"2026-01-01T00:00:00Z","created_by":"agent","state":"stale","pinned":true}},"compacted_at":null}\n' > "$US"
printf '{"ts":"2026-06-11T01:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV"
run_compact
assert_eq "T2 use accumulated" "6" "$(jq -r '.skills.alpha.use' "$US")"
assert_eq "T2 stale revived" "active" "$(jq -r '.skills.alpha.state' "$US")"
assert_eq "T2 created_by preserved" "agent" "$(jq -r '.skills.alpha.created_by' "$US")"
assert_eq "T2 pinned preserved" "true" "$(jq -r '.skills.alpha.pinned' "$US")"
teardown

# T3: 깨진 이벤트 라인 → 정상 라인만 반영, 실패하지 않음
setup
printf '{"ts":"2026-06-11T01:00:00Z","skill":"alpha","event":"use","session":"s"}\nnot-json{{{\n{"ts":"2026-06-11T02:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV"
run_compact
assert_eq "T3 exit 0" "0" "$?"
assert_eq "T3 valid lines counted" "2" "$(jq -r '.skills.alpha.use' "$US")"
teardown

# T4: 이벤트 없음 → 무변경, exit 0
setup
printf '{"skills":{},"compacted_at":null}\n' > "$US"
run_compact
assert_eq "T4 exit 0" "0" "$?"
assert_eq "T4 usage intact" "{}" "$(jq -c '.skills' "$US")"
teardown

# T5: 고아 .processing 복구 — 이전 크래시의 이벤트가 유실되지 않는다 (리뷰 수정 회귀)
setup
printf '{"ts":"2026-06-10T01:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV.processing"
printf '{"ts":"2026-06-11T01:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV"
run_compact
assert_eq "T5 both counted" "2" "$(jq -r '.skills.alpha.use' "$US")"
assert_eq "T5 orphan cleaned" "no" "$([ -f "$EV.processing" ] && echo yes || echo no)"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
