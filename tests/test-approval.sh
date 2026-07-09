#!/usr/bin/env bash
# approval relay: SAFE prompts (local test/build/git in an isolated worktree) are
# auto-approved; CRITICAL ones (network, destructive, secrets, force-push, outside
# the worktree) are escalated. Unit-tests the classifier that decides which.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

# safe → must NOT be flagged critical
for c in \
  "node --test test/x.mjs" "git add src/foo.js" "git add -A" "git commit -m msg" \
  "mkdir -p src" "npm test" "npm run build" "chmod +x q.sh" "ls -la" "grep foo bar" \
  "cat src/app.js" "touch f" "node app.js"; do
  if approval_is_critical "$c"; then fail "safe:$c" "flagged critical: $c"; else pass "safe:$c"; fi
done

# critical → must be flagged
for c in \
  "rm -rf build" "git push origin main" "git push --force" "curl http://x" "wget y" \
  "sudo rm x" "cat ~/.env" "npm install lodash" "pip install requests" \
  "echo x > /etc/hosts" "kill 123" "ssh host" "cat secret.txt"; do
  if approval_is_critical "$c"; then pass "crit:$c"; else fail "crit:$c" "missed critical: $c"; fi
done

finish
