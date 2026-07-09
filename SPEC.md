# The `verify.sh` convention

**Version 0.1 (draft).** A repository declares how it proves itself. An agent
may not claim completion until that proof passes.

This document is the contract. The script in `hooks/` is one implementation of
it, and deliberately a small one. Read the section on conformance levels before
you assume the tool enforces everything written here.

---

## 1. The problem

Coding agents end turns with sentences like these:

- "Tests pass." (they were never run)
- "Fixed the bug." (it was never reproduced)
- "Migration is safe." (nothing was applied to a scratch database)

None of these are lies in the ordinary sense. The agent has no way to
distinguish what it did from what it intended to do, so the report describes the
intention. The failure is structural, not moral, and it will not be prompted
away. Prompt technique ages out with each model generation. A demand for
evidence sits one layer above the model and does not.

So: **"done" stops being something an agent declares, and becomes a check it
has to pass.**

## 2. The convention

A conforming repository has an executable file `verify.sh` at its root.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

**Contract:**

| | |
|---|---|
| Location | repository root |
| Mode | executable (`chmod +x`) |
| Invocation | run with CWD at the repository root, no arguments |
| Exit `0` | verification passed |
| Exit non-`0` | verification failed; stdout+stderr explain why |
| Output | human-readable; the last 20 lines are what an agent sees |
| Runtime | keep it under a minute; slow checks belong in CI |
| Absent | no gate. Absence is a valid state, not a failure |

`verify.sh` is the repo's answer to one question: *what would have to be true
for a change here to be provably safe to hand back?* That question has a
different answer in every repository, which is exactly why the convention names
the file and not its contents.

**Opting out is a single action:** delete `verify.sh`, or reduce it to
`exit 0`. This is intentional. A gate nobody can remove is a gate people route
around.

## 3. The four kinds of evidence

A `verify.sh` should assert against evidence, not against belief. Four kinds
carry weight. A good `verify.sh` covers at least one; a mature one covers all
four across the checks it runs.

**Command output.** The check ran a command and read its exit code. Not "the
tests should pass" but the test runner's own verdict.

**Diff.** The change is exactly what was intended and nothing more. Debug
statements removed, no stray files, no unrelated formatting churn.
`git diff --check` is the floor here.

**Reproduction.** For a bug fix: the failure was observed before, and is absent
after. A fix that was never reproduced is a guess about which line was wrong.

**Cross-check.** A second, independent source agrees. Another model, another
tool, a type checker against a test suite. Independence is the point; two
checks that share an assumption confirm the assumption, not the code.

The four kinds exist so that "I verified it" has to name *how*. When an agent
cannot say which of the four it has, it has none of them.

## 4. What implementations must do

An implementation of this convention is a gate. To conform it must:

1. Run `verify.sh` from the repo root before the agent's turn can end.
2. Block the turn on non-zero exit, and surface the output.
3. Do nothing when `verify.sh` is absent or not executable.
4. Do nothing when the session made no edits.
5. Provide an explicit, greppable bypass. Silent bypasses train people to
   distrust the gate; an audited one keeps it honest.

It must **not** modify `verify.sh`, and it must instruct the agent that
weakening `verify.sh` to get past the gate is a violation rather than a fix.
This is the single most likely failure mode in practice. An agent that cannot
pass a check will, given the chance, edit the check.

## 5. Conformance levels

Be precise about what is machine-enforced and what is discipline. The
distinction matters more than the ambition.

**Level 1 - the gate.** `verify.sh` exists, and something mechanically refuses
to let a turn end while it fails. This is fully enforced by the reference
implementation in `hooks/`, and it is where every repo should start.

**Level 2 - the evidence.** The checks inside `verify.sh` cover the four kinds
of evidence in section 3. **No tool enforces this, including this one.** The
gate verifies that your `verify.sh` returned zero. Whether that zero means
anything is a claim about the checks you wrote. A `verify.sh` containing only
`exit 0` passes Level 1 and is worthless.

**Level 3 - the ledger.** Every caught false completion is recorded, so the
failure modes become data instead of anecdote. The reference implementation
writes this only when explicitly enabled.

Level 1 is a tool. Level 2 is a practice. Anyone selling you Level 2 as a
tool is selling you Level 1 and hoping you do not read the source.

## 6. The ledger format

When enabled, each caught false completion appends one JSON object per line:

```json
{
  "ts": "2026-07-09T04:12:33Z",
  "repo": "/home/you/src/api",
  "exit_code": 1,
  "claim": "All tests pass. Ready to merge.",
  "evidence_demanded": "verify.sh exit 0",
  "actual": ["FAIL src/auth.test.ts", "3 failed, 41 passed"]
}
```

`claim` is the agent's own last message before it tried to stop. It is the most
useful field and the most sensitive one. The ledger is written to local disk
and is never transmitted anywhere. Nothing in this project phones home.

Three fields, one row: what was claimed, what was demanded, what was true.

## 7. Non-goals

This convention does not tell you what to check, does not run your CI, does not
score your code, and does not replace review. It answers one question and stops:
**has this repository proven itself before the agent walked away?**

---

*Contributions to this spec belong in an issue, not a pull request against the
reference implementation. The convention is the artifact. The script is the
footnote.*
