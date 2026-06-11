#!/bin/bash
# growing-skills telemetry hook tests. 실행: bash tests/test-telemetry-hook.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/hooks/skill-telemetry.sh"
PASS=0; FAIL=0

setup() {
  TESTROOT=$(mktemp -d)
  mkdir -p "$TESTROOT/known-skill"
  printf -- "---\nname: known-skill\ndescription: test\n---\nbody\n" > "$TESTROOT/known-skill/SKILL.md"
  EVENTS="$TESTROOT/.usage-events.jsonl"
}
teardown() { rm -rf "$TESTROOT"; }

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1";
  else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi
}

payload() { # skill_name
  printf '{"session_id":"sess-1","cwd":"/tmp","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"%s"}}' "$1"
}

# T1: 알려진 글로벌 스킬 → 이벤트 1줄 append
setup
payload "known-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T1 exit code" "0" "$?"
assert_eq "T1 one line appended" "1" "$(wc -l < "$EVENTS" 2>/dev/null | tr -d ' ')"
assert_eq "T1 skill field" "known-skill" "$(jq -r '.skill' "$EVENTS")"
assert_eq "T1 event field" "use" "$(jq -r '.event' "$EVENTS")"
assert_eq "T1 session field" "sess-1" "$(jq -r '.session' "$EVENTS")"
assert_eq "T1 ts is ISO8601" "ok" "$(jq -r '.ts' "$EVENTS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' && echo ok)"
teardown

# T2: 백그라운드 마커 → 기록 안 함
setup
payload "known-skill" | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T2 exit 0" "0" "$?"
assert_eq "T2 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
