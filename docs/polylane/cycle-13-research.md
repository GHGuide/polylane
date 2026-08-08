# Cycle 13 research — whole-system perfection

The local audit found three live design gaps. First, `.intensity` in a manifest is not read
into the runner override path, while a CLI intensity applies one Claude-oriented model to
every lane and only clamps the integrator's effort. This contradicts the documented role and
agent rules. Second, skill matching is a short hard-coded domain list; it ignores the
frontmatter descriptions that agents actually use for progressive disclosure and cannot
explain most installed skills. Third, `polylane-promptopt.sh` counts whitespace-separated
words but labels them tokens and validates rather than optimizing prompt structure.

The first real launch added a fourth finding: the existing tmux server lacks macOS privacy
access to `~/Downloads`, producing `Operation not permitted` before Codex could read a prompt.
The safe autonomous fallback is a temporary local clone on an accessible volume, followed by
the normal verified fast-forward. Supervisor resumes also appended the same preflight
compaction observation repeatedly, so prelaunch learning needs a run-id idempotence key.

Primary references reinforce the repair direction. OpenAI's current GPT-5.6 guidance defines
`gpt-5.6-luna`, `gpt-5.6-terra`, and `gpt-5.6-sol` as efficiency, balanced, and frontier
tiers and recommends deliberately benchmarking reasoning effort. The Agent Skills
specification makes `name` and `description` the metadata discovery layer and recommends
progressive disclosure instead of eagerly loading every full skill. Codex hooks expose
`SessionStart`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, and `Stop`; compact
context restoration and an honest stop gate are therefore native lifecycle controls, while
tool hooks remain guardrails rather than a complete security boundary.

Sources: https://developers.openai.com/api/docs/guides/latest-model ·
https://agentskills.io/specification · https://agentskills.io/skill-creation/optimizing-descriptions ·
https://developers.openai.com/codex/hooks
