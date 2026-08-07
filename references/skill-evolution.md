# Evidence-gated skill evolution

Use this only when production evidence says a skill is repeatedly harmful,
repeatedly unused, explicitly corrected, or regressed. Ordinary successful
cycles keep using the champion; they do not rewrite instructions for novelty.

The invariant is:

`reflection proposes → frozen evaluation measures → hidden cases + blind judges gate → activation can roll back`

Never edit an installed or champion `SKILL.md` in place. A model may generate a
challenger, but it cannot promote its own work.

## Workspace and frozen corpus

Keep durable state outside `.polylane/`:

```bash
EVOLVE=bin/polylane-skill-evolve.sh       # installed Codex: scripts/...
EW=docs/polylane/skill-evolution/polylane
ACTIVE=/absolute/path/to/the/installed/polylane-skill
EVALS=/absolute/path/to/benchmarks/skill-evolution/polylane/evals.json

"$EVOLVE" validate "$EVALS"
"$EVOLVE" init "$EW" "$ACTIVE" "$EVALS"
```

Initialization snapshots generation 0 and copies every evaluator and judge into
the workspace. Later edits to the source benchmark cannot move the current gate.
The workspace and active skill must be separate directory trees; `init` rejects
either one nested inside the other to prevent recursive snapshots or activation
from moving its own journal.
The corpus requires train, development, and held-back promotion cases plus
exactly three bounded blind judges. Real adapters receive the same frozen model
and effort for champion and challenger. Unknown scores, costs, time, evaluator
failures, and judge failures fail closed.

The bundled Polylane corpus runs real Codex by default. Set
`POLYLANE_SKILL_EVAL_AGENT=claude` for the Claude skill. A serious private run
should add private held-back cases not visible to the candidate lane; the public
corpus is a portable minimum, not a secrecy boundary.

## Observe at cycle close

After verification, inspect the lane transcript and evidence—not the lane's
self-assessment—and record one signal only when it is supported:

```bash
"$EVOLVE" observe "$EW" <cycle> polylane \
  <helped|unused|hurt|regression|correction> \
  "<observable behavior>" "<evidence path>"
```

`observe` returns 0 and prints `EVOLVE` after one regression, two corrections,
two hurts, or three unused outcomes by default. It returns 3 while stable.
Duplicate evidence is ignored. A promotion advances the observation cursor so
old failures do not repeatedly retrigger a fixed skill.

Skill evolution is maintenance, not a new product goal. Continue independent
goal work first. Schedule it immediately only when the skill defect is blocking
or repeatedly wasting the current product loop.

## Build challengers without seeing promotion cases

```bash
"$EVOLVE" packet "$EW" polylane > /tmp/polylane-challenger-packet.md
```

The packet exposes the immutable champion, recent evidence, and train/development
cases; it omits hidden case identifiers. Use the platform's skill creator to
produce three focused variants, then pressure-test each with
`superpowers:writing-skills`. Change one hypothesis per variant and keep the
prompt lean. Candidate lanes own only their copied skill directories and must
not read the frozen promotion corpus.

Stage snapshots; later source edits cannot change them:

```bash
"$EVOLVE" stage "$EW" concise /path/to/variant-a "remove repeated prompt blocks"
"$EVOLVE" stage "$EW" strict  /path/to/variant-b "close premature-stop loophole"
"$EVOLVE" stage "$EW" shaped  /path/to/variant-c "make required output structure explicit"
```

## Compare, select, promote

Run all comparisons against the same current champion:

```bash
POLYLANE_SKILL_EVAL_AGENT=codex "$EVOLVE" compare "$EW" concise
POLYLANE_SKILL_EVAL_AGENT=codex "$EVOLVE" compare "$EW" strict
POLYLANE_SKILL_EVAL_AGENT=codex "$EVOLVE" compare "$EW" shaped
WINNER=$("$EVOLVE" select "$EW" concise strict shaped)
```

`compare` runs champion and challenger concurrently per case, then gates:

- every adapter result is valid and every hard minimum passes;
- development and hidden deltas clear their frozen margins;
- tokens, duration, and interventions stay within frozen ceilings;
- exactly three anonymized A/B judges run, and the challenger wins at least two.

Only a current-champion `GO` verdict can promote. `select` ranks eligible GO
challengers by hidden score, development score, then lower token cost.

```bash
"$EVOLVE" promote "$EW" "$WINNER" "$ACTIVE"
"$EVOLVE" canary "$EW" "$ACTIVE"
```

Promotion compares the active directory hash with the champion snapshot before
writing. If the user or another process changed it, exit 6 preserves that work:
refuse the overwrite, inspect the drift, rebase a new challenger, and benchmark
again. Activation uses a sibling staged directory and journal; `recover` restores
the prior tree after an interrupted replacement. A failing post-promotion hidden
canary records regression evidence, automatically restores the previous immutable
generation, and exits 7.

Manual controls:

```bash
"$EVOLVE" status "$EW" --json
"$EVOLVE" recover "$EW"
"$EVOLVE" rollback "$EW" "$ACTIVE"
```

Never interpret a NO-GO as permission to weaken the held-back cases, judge
majority, or cost limits. Change the challenger hypothesis. After three failed
hypotheses, retain the champion, record what was learned, and return to product
work until new evidence appears.
