#!/bin/bash
# session-start-curator.sh 테스트. 실행: bash tests/test-curator-hook.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
HOOK="$PKG/hooks/session-start-curator.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() { SK=$(mktemp -d); ST="$SK/.curator_state"; }
teardown() { rm -rf "$SK"; }
run_hook() {
  printf '{"session_id":"s","source":"startup"}' | \
    GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" GROWING_SKILLS_NO_SPAWN="${NOSPAWN:-1}" bash "$HOOK"
}

# T1: 어떤 경우에도 stdout 무음 (컨텍스트 주입 방지) + exit 0
setup
OUT=$(run_hook)
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 silent" "" "$OUT"
teardown

# T2: 7일 미경과 → 스폰 마커 없음 (스폰 검증은 NO_SPAWN=0 + 가짜 pass 스크립트로)
setup
printf '{"last_run_at":%s,"paused":false}\n' "$(date +%s)" > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T2 not spawned" "no" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
rm -rf "$FAKE_HOME"
teardown

# T3: 7일 경과 → 스폰됨
setup
printf '{"last_run_at":%s,"paused":false}\n' "$(( $(date +%s) - 700000 ))" > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T3 spawned" "yes" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
rm -rf "$FAKE_HOME"
teardown

# T4: paused → 스폰 안 함 / BG 마커 → 즉시 종료
setup
printf '{"last_run_at":0,"paused":true}\n' > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T4 paused no spawn" "no" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
OUT=$(printf '{}' | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$SK" bash "$HOOK")
assert_eq "T4 bg silent exit" "0" "$?"
rm -rf "$FAKE_HOME"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
