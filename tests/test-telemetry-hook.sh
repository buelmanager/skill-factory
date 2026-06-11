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

# T3: 플러그인 스킬(콜론 포함) → 기록 안 함
setup
payload "superpowers:writing-skills" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T3 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T4: 글로벌에 없는 스킬 → 기록 안 함
setup
payload "nonexistent-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T4 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T5: 깨진 JSON → exit 0, 기록 안 함
setup
printf 'not-json{{{' | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T5 exit 0" "0" "$?"
assert_eq "T5 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T6: Skill 외 도구 페이로드(tool_input에 skill 없음) → 기록 안 함
setup
printf '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T6 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T7: 동시 append 10개 → 10줄 전부 온전한 JSON (O_APPEND 원자성)
setup
for i in $(seq 1 10); do
  payload "known-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK" &
done
wait
assert_eq "T7 ten lines" "10" "$(wc -l < "$EVENTS" | tr -d ' ')"
assert_eq "T7 all valid json" "10" "$(jq -c . "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T8: 경로 문자가 든 스킬명 → 기록 안 함 (경로 순회 방지)
setup
mkdir -p "$TESTROOT/../outside-skill" 2>/dev/null
printf -- "---\nname: outside\ndescription: t\n---\n" > "$TESTROOT/../outside-skill/SKILL.md"
payload "../outside-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T8 traversal no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
payload "sub/dir-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T8 nested slash no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
rm -rf "$TESTROOT/../outside-skill"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
