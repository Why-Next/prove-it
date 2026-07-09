---
description: Read the local ledger of caught false completions and report how this agent actually fails.
argument-hint: "[optional: number of recent entries, default 20]"
---

# /prove-it:ledger

Read `~/.prove-it/ledger.jsonl` (or `$PROVE_IT_LEDGER_DIR/ledger.jsonl`) and tell
the user how their agent actually fails, using their own data rather than
folklore.

## Arguments

$ARGUMENTS

## If the file does not exist

The ledger is off by default. Say so, show them how to turn it on, and stop:

```bash
export PROVE_IT_LEDGER=1
```

Explain what it will record: the agent's last message before it tried to stop
(up to 300 characters of conversation text), the repository path, the exit code,
and the lines of `verify.sh` output that name a failure. It is written to local
disk mode `0600` and is never transmitted. Do not turn it on for them.

## If it exists

Each line is one caught false completion:

```json
{"ts":"...","repo":"...","exit_code":1,"claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Report, in prose, not a wall of JSON:

1. **How often.** Total entries, and entries in the last 7 days.
2. **What the agent claimed.** Group the `claim` field by what was being asserted:
   tests pass, bug fixed, types check, ready to merge. Quote two or three
   verbatim. These are the sentences to stop believing.
3. **What was actually wrong.** Group `actual` by failure kind. Whether the same
   check catches most of them, which tells the user where their real risk is.
4. **Which repos.** If more than one, say whether one repository dominates.
5. **The one sentence.** Finish with what this data says about this specific
   agent's failure mode. Not a general observation about AI: theirs.

## Be careful

- The `claim` field contains conversation text. Do not paste it anywhere outside
  this session, and do not include it in a commit, an issue, or a bug report
  without asking.
- Do not editorialise the count upward. If there are three entries, say three.
  Three is a fact; "frequently" is a guess.
- If every entry has the same `exit_code` and the same `actual`, the user
  probably has one broken check rather than a lying agent. Say that.
