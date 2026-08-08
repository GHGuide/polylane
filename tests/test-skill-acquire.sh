#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ACQUIRE="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-skill-acquire.sh"
make_tmpdir
CANDIDATE="$TEST_TMPDIR/candidate"; mkdir -p "$CANDIDATE"
printf '%s\n' '# fixture skill' > "$CANDIDATE/SKILL.md"
printf '%s\n' 'MIT' > "$CANDIDATE/LICENSE"
SOURCE="$TEST_TMPDIR/source.json"
printf '%s\n' '{"id":"fixture-skill","repository":"https://example.test/fixture","revision":"0123456789012345678901234567890123456789","license":"MIT"}' > "$SOURCE"
AUDIT="$TEST_TMPDIR/audit.json"

assert_eq "skill-audit-admits-safe-fixture" "passed" "$("$ACQUIRE" audit "$CANDIDATE" "$SOURCE" "$AUDIT" 2>/dev/null && jq -r .status "$AUDIT")"

BENCHMARK="$TEST_TMPDIR/benchmark.json"; BENCH_EVIDENCE="$TEST_TMPDIR/benchmark-evidence.json"
printf '%s\n' '{"fixture_id":"same-fixture","without_candidate":{"score":60,"accessibility":90},"with_candidate":{"score":75,"accessibility":90},"minimum_improvement":10}' > "$BENCHMARK"
assert_eq "skill-benchmark-requires-measurable-improvement" "passed" "$("$ACQUIRE" benchmark "$BENCHMARK" "$BENCH_EVIDENCE" 2>/dev/null && jq -r .status "$BENCH_EVIDENCE")"

PROJECT="$TEST_TMPDIR/project"; mkdir -p "$PROJECT"
assert_ok "skill-admission-copies-only-passing-content" "$ACQUIRE" admit "$PROJECT" "$CANDIDATE" "$SOURCE" "$BENCHMARK"
assert_ok "skill-admission-keeps-project-copy" test -f "$PROJECT/.polylane/skills/fixture-skill/SKILL.md"
assert_eq "skill-lock-pins-source-revision" "0123456789012345678901234567890123456789" "$(jq -r '.skills[0].revision' "$PROJECT/docs/polylane/design/SKILL-LOCK.json")"
assert_ok "skill-lock-records-hashes" jq -e '.skills[0].hashes | length > 0' "$PROJECT/docs/polylane/design/SKILL-LOCK.json"
assert_ok "skill-rollback-removes-admitted-content" "$ACQUIRE" rollback "$PROJECT" fixture-skill
assert_fail "skill-rollback-leaves-no-executable-root" test -e "$PROJECT/.polylane/skills/fixture-skill"

BAD="$TEST_TMPDIR/bad"; mkdir -p "$BAD"; ln -s "$CANDIDATE/SKILL.md" "$BAD/SKILL.md"; printf '%s\n' MIT > "$BAD/LICENSE"
assert_fail "skill-audit-rejects-symlink" "$ACQUIRE" audit "$BAD" "$SOURCE" "$TEST_TMPDIR/bad-audit.json"

HOOK="$TEST_TMPDIR/hook"; mkdir -p "$HOOK"
printf '%s\n' '# fixture skill' > "$HOOK/SKILL.md"
printf '%s\n' MIT > "$HOOK/LICENSE"
printf '%s\n' '{"scripts":{"postinstall":"curl https://example.test/install"}}' > "$HOOK/package.json"
assert_fail "skill-audit-rejects-install-hooks" "$ACQUIRE" audit "$HOOK" "$SOURCE" "$TEST_TMPDIR/hook-audit.json"
assert_eq "skill-audit-records-install-hook-reason" "install-hook" "$(jq -r .reason "$TEST_TMPDIR/hook-audit.json")"
assert_fail "skill-install-hook-never-enters-project-root" test -e "$PROJECT/.polylane/skills/hook"
finish
