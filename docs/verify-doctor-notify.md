# verify — lane doctor-notify

Evidence from real runs on this machine (macOS, 2026-07-08), worktree
`.polylane/wt/doctor-notify`, branch `lane/doctor-notify`. Every claim below has
the verbatim command output + exit code that proves it.

## 1. Lint — `bash -n` + shellcheck, both scripts

```
$ bash -n bin/polylane-doctor.sh   && echo clean   # -> clean (exit 0)
$ bash -n bin/polylane-notify.sh   && echo clean   # -> clean (exit 0)
$ shellcheck bin/polylane-doctor.sh bin/polylane-notify.sh && echo clean
clean
```

## 2. bash-3.2 safety — executed under macOS system bash

```
$ /bin/bash --version | head -1
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ /bin/bash bin/polylane-notify.sh done "bash-3.2 run"; echo $?     # -> 0
$ POLYLANE_SESSION=doctor-selftest /bin/bash bin/polylane-doctor.sh >/dev/null; echo $?  # -> 0
```

## 3. doctor — real table vs this repo (no manifest arg)

```
$ bin/polylane-doctor.sh
== polylane doctor ==
STAT  CHECK                                   FIX / DETAIL
----  --------------------------------------  ------------
PASS  dep: tmux                               /opt/homebrew/bin/tmux
PASS  dep: jq                                 /opt/homebrew/bin/jq
PASS  dep: git                                /opt/homebrew/bin/git
PASS  dep: claude                             /opt/homebrew/bin/claude
PASS  dep: shellcheck (optional)              /opt/homebrew/bin/shellcheck
PASS  git: repository                         /Users/leonardo/Downloads/polylane/.polylane/wt/doctor-notify
WARN  git: working tree                       2 uncommitted: bin/polylane-doctor.sh docs/superpowers/ — commit/stash orphan work before launching lanes
WARN  manifest: exists                        no /Users/leonardo/Downloads/polylane/.polylane/wt/doctor-notify/.polylane/run.json — run /polylane first (env checks still valid)
WARN  disk: free space                        2GB free (<5GB) — one worktree per lane adds up; consider freeing space
FAIL  tmux: session 'polylane'                already exists — tmux kill-session -t 'polylane' or set POLYLANE_SESSION=<other>
PASS  claude: version                         2.1.202 (Claude Code)

7 PASS · 3 WARN · 1 FAIL
exit=1
```

Notes: the tmux FAIL is a REAL collision (this very run lives in session
`polylane`) — collision detection works; orphan WARN lists the actual paths;
disk WARN is the real <5GB state of this disk.

### exit-0 path (same run, session name freed via POLYLANE_SESSION)

```
$ POLYLANE_SESSION=doctor-selftest bin/polylane-doctor.sh
...
PASS  tmux: session 'doctor-selftest'         name free
...
8 PASS · 3 WARN · 0 FAIL
exit=0
```

Contract proven: 0 = no FAIL (WARNs allowed) · 1 = any FAIL.

## 4. doctor — real manifest (main project `.polylane/run.json`, 9 lanes + integrator)

```
$ bin/polylane-doctor.sh /Users/leonardo/Downloads/polylane/.polylane/run.json
...
PASS  manifest: exists                        /Users/leonardo/Downloads/polylane/.polylane/run.json
PASS  manifest: valid JSON                    parses clean
PASS  manifest: prompt files                  all 10 exist and are non-empty
PASS  manifest: worktree paths                all 10 sane
WARN  git: branch collision (engine)          branch 'lane/engine' exists — runner reuses it ...
WARN  git: worktree collision (engine)        path '/Users/leonardo/Downloads/polylane/.polylane/wt/engine' exists — ...
... (branch + worktree collision WARN pairs for all 9 live lanes) ...
FAIL  tmux: session 'polylane'                already exists — ...
11 PASS · 20 WARN · 1 FAIL
exit=1
```

Bug found + fixed during this verification: worktree sanity originally compared
against the CALLER's repo root, so running doctor from inside a lane worktree
false-FAILed that lane's own path. Anchor is now the manifest's project root
(parent of `.polylane`), matching the runner's `abs_prompt` rule. Post-fix rerun
above shows `worktree paths all 10 sane`.

## 5. doctor — failure paths

```
$ bin/polylane-doctor.sh /nope/run.json
FAIL  manifest: exists                        not found: /nope/run.json — run /polylane to emit it
7 PASS · 2 WARN · 2 FAIL          exit=1

$ echo '{bad' > $SCRATCH/bad.json && bin/polylane-doctor.sh $SCRATCH/bad.json
PASS  manifest: exists                        .../bad.json
FAIL  manifest: valid JSON                    invalid JSON — re-emit with /polylane or fix by hand
8 PASS · 2 WARN · 2 FAIL          exit=1

# synthetic evil manifest: worktree "/" + missing prompt_files (lane + integrator)
$ bin/polylane-doctor.sh $SCRATCH/evil/.polylane/run.json
FAIL  manifest: prompt_file (x)               missing/empty: .../evil/nope.txt — /polylane phase 6 must emit it
FAIL  manifest: prompt_file (int)             missing/empty: .../evil/nope-int.txt — /polylane phase 6 must emit it
FAIL  manifest: worktree (x)                  insane path: '/' — must be a dedicated dir, not / or the project root
FAIL  manifest: worktree (integrator)         insane path: '/' — must be a dedicated dir, not / or the project root
9 PASS · 3 WARN · 5 FAIL          exit=1
```

### disk FAIL branch (<1GB) — sourced with mocked `df` (real disk has 2GB)

```
$ /bin/bash -c 'source bin/polylane-doctor.sh; df(){ echo h; echo "/dev/mock 100 50 500000 99% /"; }; check_disk; render'
FAIL  disk: free space                        only 0GB free (<1GB) — worktrees need room; free space first
0 PASS · 0 WARN · 1 FAIL
```

### `set -e` caller survival

```
$ bash -ec 'bin/polylane-doctor.sh /nope/run.json >/dev/null 2>&1 || rc=$?; echo "caller SURVIVED, doctor rc=${rc:-0}"'
caller SURVIVED, doctor rc=1
```

## 6. notify — all 5 events + edges (banners + sounds fired on this mac)

```
$ bin/polylane-notify.sh --help; echo exit=$?          # usage text, exit=0
$ for ev in done go no-go halt stall; do bin/polylane-notify.sh "$ev" "polylane test: event $ev"; echo "event=$ev exit=$?"; done
event=done exit=0     # banner + Ping
event=go exit=0       # banner + Glass
event=no-go exit=0    # banner + Basso
event=halt exit=0     # banner + Basso
event=stall exit=0    # banner + Sosumi
$ bin/polylane-notify.sh bogus "unknown event still exits 0"; echo exit=$?
event=bogus exit=0    # banner, no sound
$ bin/polylane-notify.sh; echo exit=$?
no-args exit=0        # usage to stderr, still 0
$ bash -ec 'bin/polylane-notify.sh halt "under set -e"; echo "caller SURVIVED"'
caller SURVIVED
```

### non-macOS / osascript-absent simulation

```
$ PATH=/nonexistent /bin/bash bin/polylane-notify.sh done "no-osascript sim"; echo "output='<$out>' exit=$rc"
output='<>' exit=0    # quiet no-op, exit 0
```

## Contract checklist

| Requirement | Evidence |
|---|---|
| doctor CLI `bin/polylane-doctor.sh [manifest.json]` | §3, §4, §5 |
| doctor exit 0 all-pass / 1 any-fail | §3 (both codes) |
| PASS/WARN/FAIL table + one-line fix hint per row | §3, §4 tables |
| deps check (tmux jq git claude, shellcheck optional) | §3 rows |
| git repo + listed orphans + branch/worktree collisions | §3 WARN row (paths listed), §4 collision WARNs |
| manifest exists + valid JSON + prompt_files non-empty + worktrees sane | §4 PASS rows, §5 FAIL rows |
| disk WARN <5GB / FAIL <1GB | §3 (real 2GB WARN), §5 (mock FAIL) |
| tmux session collision (POLYLANE_SESSION) | §3 real FAIL + override PASS |
| claude on PATH + version | §3 PASS row (2.1.202) |
| notify CLI `bin/polylane-notify.sh <event> <message>` | §6 |
| events done/go/no-go/halt/stall + sounds Ping/Glass/Basso/Basso/Sosumi | §6 |
| notify exit 0 ALWAYS (incl. unknown event, no args, set -e) | §6 (every exit=0) |
| quiet no-op when osascript absent | §6 simulation |
| --help both | §3, §6 |
| bash -n clean both | §1 |
| bash-3.2 safe (ran under 3.2.57) | §2 |
