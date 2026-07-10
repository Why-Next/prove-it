# The `verify.sh` convention

> This English text is the normative version. Translations exist for
> [中文](docs/i18n/SPEC.zh.md) ·
> [Deutsch](docs/i18n/SPEC.de.md) ·
> [日本語](docs/i18n/SPEC.ja.md) ·
> [हिन्दी](docs/i18n/SPEC.hi.md) ·
> [Français](docs/i18n/SPEC.fr.md) ·
> [Italiano](docs/i18n/SPEC.it.md) ·
> [Português](docs/i18n/SPEC.pt.md) ·
> [Русский](docs/i18n/SPEC.ru.md) ·
> [Español](docs/i18n/SPEC.es.md) ·
> [한국어](docs/i18n/SPEC.ko.md).
> They are informative. Where a translation and this text disagree, this text
> governs and the translation is a bug to be reported.

Version 0.1 (draft). A repository declares how it proves itself, and an agent may
not claim completion until that proof passes.

This document is the contract. The script in `hooks/` is one implementation of
it, and a deliberately small one. Read section 5 on conformance levels before
assuming the tool enforces everything written here.

## 1. The problem

Coding agents end turns with sentences like these:

- "Tests pass." The tests were never run.
- "Fixed the bug." The bug was never reproduced.
- "The migration is safe." Nothing was applied to a scratch database.

These are not lies in the ordinary sense. An agent cannot distinguish what it did
from what it intended to do, so its report describes the intention. The failure
is structural, and prompting will not remove it. Prompt technique also ages out
with each model generation, while a demand for evidence sits one layer above the
model and survives the upgrade.

So "done" stops being something an agent declares and becomes a check it has to
pass.

## 2. The convention

A conforming repository has an executable file `verify.sh` at its root.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

The contract:

| | |
|---|---|
| Location | repository root |
| Mode | executable (`chmod +x`) |
| Invocation | run with CWD at the repository root, no arguments |
| Exit `0` | verification passed |
| Exit non-`0` | verification failed; stdout and stderr explain why |
| Output | human-readable; the last 20 lines are what an agent sees |
| Runtime | under a minute; slow checks belong in CI |
| Absent | no gate. Absence is a valid state, not a failure |

`verify.sh` answers one question: what would have to be true for a change here to
be provably safe to hand back? Every repository answers it differently, which is
why this convention names the file and not its contents.

Opting out takes one action: delete `verify.sh`, or reduce it to `exit 0`. That
is intentional. People route around a gate they cannot remove, and a gate that is
routed around still reports success.

## 3. The four kinds of evidence

A `verify.sh` should assert against evidence rather than belief. Four kinds carry
weight. A useful `verify.sh` covers at least one, and a mature one covers all
four across the checks it runs.

**Command output.** A command ran and the check read its exit code. Not "the
tests should pass" but the test runner's own verdict.

**Diff.** The change is what was intended and nothing more: no debug statements,
no stray files, no unrelated formatting churn. `git diff --check` is the floor.

**Reproduction.** For a bug fix, the failure was observed before the change and
is absent after it. A fix that was never reproduced is a guess about which line
was wrong.

**Cross-check.** A second, independent source agrees. Another model, another
tool, a type checker against a test suite. Independence is what makes it worth
anything; two checks that share an assumption confirm the assumption rather than
the code.

The four categories exist so that "I verified it" has to name a method. An agent
that cannot say which of the four kinds of evidence it holds is holding none of
them.

## 4. What implementations must do

An implementation of this convention is a gate. To conform it must:

1. Run `verify.sh` from the repository root before the agent's turn can end.
2. Block the turn on a non-zero exit, and surface the output.
3. Do nothing when `verify.sh` neither exists as executable when the gate runs
   nor existed as executable at the start of the session.
4. Do nothing when the session did not change that repository.
5. Provide an explicit, greppable bypass. A silent bypass teaches people to
   distrust the gate; an audited one keeps it honest.
6. Never end a turn silently after a failed verification. An implementation that
   stops blocking, for any reason, must say so where the user will see it.

Point 4 asks what changed, not who changed it. An implementation that decides by
watching which editing tools the agent called will miss a file rewritten by
`sed`, a patch applied with `git apply`, output from a code generator, and a
commit. Committing is the most ordinary thing an agent does, and a gate that
treats a clean working tree as nothing to prove will wave through the very turns
it exists to catch. Compare the repository against what it looked like when the
session began.

Point 3 uses both moments deliberately. The current stop matters so an
installation command can create `verify.sh` and arm the repository in the same
session. The starting state matters so a mid-session deletion or `chmod -x` is
treated as disarming the gate rather than opting out honestly.

Point 6 exists because a gate that can block forever hangs the session, and
every host eventually forces it to yield. That is fine. What is not fine is
yielding in a way indistinguishable from passing.

It must not modify `verify.sh`, and it must tell the agent that weakening
`verify.sh` to get past the gate is a violation rather than a fix. This is the
likeliest failure mode in practice. An agent that cannot pass a check will, given
the opportunity, edit the check.

The crudest form of that is removing the check. An implementation should record
whether `verify.sh` was present and executable when the session began, and refuse
a turn that ends with it deleted or disarmed. Deleting the file between sessions
is the opt-out in section 2 and must keep working. Deleting it in the middle of
the session that it was about to block is not an opt-out, and the difference
between the two is only visible to an implementation that looked before.

The subtler form keeps `verify.sh` executable and rewrites the checks inside it.
That cannot be refused without also refusing legitimate work on the gate, so an
implementation should record what `verify.sh` contained when the session began,
and when a turn passes through a `verify.sh` that changed during the session,
say so where the user will see it. The pass stands; the silence does not.

## 5. Conformance levels

Be precise about what a machine enforces and what a person practises. That
distinction matters more than the ambition behind the convention.

**Level 1, the gate.** `verify.sh` exists, and something mechanically refuses to
let a turn end while it fails. The reference implementation in `hooks/` enforces
this in full, and it is where every repository should start. "Refuses" has a
budget: it sends the turn back a bounded number of times and then yields with a
warning, because the host will not let a hook block forever.

**Level 2, the evidence.** The checks inside `verify.sh` cover the four kinds of
evidence in section 3. No tool enforces this, including this one. The gate
verifies that your `verify.sh` returned zero. Whether that zero means anything is
a claim about the checks you wrote, and a `verify.sh` containing only `exit 0`
reaches Level 1 while proving nothing.

**Level 3, the ledger.** Every caught false completion is recorded, so that the
failure modes become data rather than anecdote. The reference implementation
writes this only when explicitly enabled.

Level 1 is a property of a tool. Level 2 is a property of a team's habits, and
any tool claiming to deliver it is delivering Level 1 and hoping nobody reads the
source.

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

`claim` holds the agent's own last message before it tried to stop. It is the
most useful field in the record and the most sensitive one, since it can contain
any conversation text. An implementation must write the ledger to local disk with
restrictive permissions and must never transmit it.

One row holds three things: what was claimed, what was demanded, and what was
true.

## 7. Non-goals

This convention does not tell you what to check, does not run your CI, does not
score your code, and does not replace review. It answers a single question, which
is whether this repository proved itself before the agent walked away.

---

*Proposals to change this document belong in an issue rather than a pull request
against the reference implementation. Every addition here is something that every
future implementation has to carry.*
