# Driving the gate from other hosts

The spec names a file and an exit code and never names a vendor. This page is
where that claim is cashed in: the same `hooks/prove-it.sh` wired into hosts
other than Claude Code.

## What the gate needs from a host

The gate is a script with a narrow contract, and any host that can meet it can
drive it:

1. **Run a command when the agent tries to end its turn**, with a JSON payload
   on stdin. The gate reads three fields, all optional: `session_id`,
   `stop_hook_active`, and `transcript_path`. A missing field falls back to a
   safe default.
2. **Treat exit `2` as "send the agent back to work"** and feed it stderr as
   the reason. Exit `0` lets the turn end.
3. **Run a command at session start** (`hooks/session-start.sh`, same stdin
   shape). This records the baseline the gate compares against. Without it the
   gate falls back to the weaker dirty-tree test and cannot see a change that
   was committed.

One field deserves care: `stop_hook_active` (true on every stop after the
first block) is how the gate counts attempts against `PROVE_IT_MAX_BLOCKS`. On
a host that never sends it, every block looks like the first, the budget never
runs out, and the only thing that ends the loop is the host's own retry cap.
Check your host has one before wiring the gate in.

## Status

| Host | Turn-end block | Status |
|---|---|---|
| Claude Code | `Stop` hook, exit 2 + stderr | tested; this is the reference host |
| Codex CLI | `Stop` hook, exit 2 + stderr | documented below, not yet tested |
| Qwen Code | `Stop` hook, exit 2 + stderr | documented below, not yet tested |
| Gemini CLI | `AfterAgent`, exit 2 + stderr | documented below, not yet tested |
| Copilot CLI | `agentStop`, JSON decision | needs a wrapper, sketched below |
| Cursor CLI | `stop` + `followup_message` | partial: no true block, capped loop |
| OpenCode | none | not possible today: `session.idle` fires after the loop has already ended |

"Not yet tested" means exactly that. If you run one of these and it works, or
does not, say so in an issue: one report moves a row out of this column.

## Codex CLI

Codex hooks mirror Claude Code's: a `Stop` event, exit code 2 with stderr as
the continuation prompt, `stop_hook_active` in the payload, and a
`SessionStart` event. Merge into `~/.codex/hooks.json` or
`<repo>/.codex/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash ~/.local/share/prove-it/hooks/session-start.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash ~/.local/share/prove-it/hooks/prove-it.sh", "timeout": 180}]}
    ]
  }
}
```

## Qwen Code

Hook semantics are identical to Claude Code's, including `stop_hook_active`.
Merge into `.qwen/settings.json` or `~/.qwen/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash ~/.local/share/prove-it/hooks/session-start.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash ~/.local/share/prove-it/hooks/prove-it.sh", "timeout": 180000}]}
    ]
  }
}
```

## Gemini CLI

`AfterAgent` fires after the model's final response; exit code 2 with stderr
as the reason makes the CLI open a correction turn. The payload shape is not
Claude's, so the gate's optional fields fall back to defaults, and the
`stop_hook_active` caveat above applies: rely on the CLI's own retry limit and
keep `PROVE_IT_MAX_BLOCKS` low. Merge into `.gemini/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {"type": "command", "name": "prove-it-baseline", "command": "bash ~/.local/share/prove-it/hooks/session-start.sh"}
    ],
    "AfterAgent": [
      {"type": "command", "name": "prove-it-gate", "command": "bash ~/.local/share/prove-it/hooks/prove-it.sh", "timeout": 180000}
    ]
  }
}
```

## Copilot CLI

`agentStop` cannot use the exit-2 contract: blocking means printing
`{"decision": "block", "reason": "..."}` on stdout. A ten-line wrapper
translates:

```bash
#!/bin/bash
# copilot-adapter.sh: exit-2-with-stderr in, decision-JSON out.
INPUT=$(cat)
ERR=$(printf '%s' "$INPUT" | bash ~/.local/share/prove-it/hooks/prove-it.sh 2>&1 >/dev/null)
if [ $? -eq 2 ]; then
    REASON="$ERR" python3 <<'PY'
import json, os
print(json.dumps({"decision": "block", "reason": os.environ["REASON"]}))
PY
fi
exit 0
```

Wire it as an `agentStop` hook in `.github/hooks/` or `~/.copilot/hooks/`.

## What does not work, and why that is written down

Cursor's `stop` hook cannot refuse a turn; it can only auto-submit a follow-up
message, a bounded number of times, and the turn it follows has already been
presented as finished. OpenCode has no pre-stop event at all yet. Neither host
can currently satisfy requirement 2 of [SPEC.md](../SPEC.md) section 4, and an
adapter that pretends otherwise would be this project committing the exact sin
it exists to catch: reporting a gate where there is none.
