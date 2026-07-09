# prove-it

[English](../../README.md) ·
[中文](README.zh.md) ·
Deutsch ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

**Dein Agent kann seinen Zug nicht beenden, bis dein Repo sich selbst beweist.**

Coding-Agenten sagen "Tests bestehen", ohne sie ausgeführt zu haben, und
"behoben", ohne den Fehler je reproduziert zu haben. Nicht aus Bosheit: Ein
Agent kann nicht unterscheiden, was er getan hat, von dem, was er tun wollte -
also meldet er die Absicht.

`prove-it` macht aus *fertig* etwas, das ein Agent bestehen muss, nicht etwas,
das er einfach behaupten darf. Leg ein `verify.sh` in das Wurzelverzeichnis
deines Repos. Wenn der Agent aufhören will, führt das Gate es aus. Exit-Code
ungleich null, und der Zug endet nicht.

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

Etwa in der Hälfte der Fälle antwortet ein Agent, den man um Beweise bittet, mit
"du hast recht, es ist noch nicht fertig."

## Installation

Erfordert `bash`, `git`, `python3`. Keine Pakete, kein Daemon, keine Anmeldung.
Klone es an einen beliebigen Ort:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

Verdrahte die zwei Hooks in Claude Code, indem du
[`hooks/settings.example.json`](../../hooks/settings.example.json) in deine
`.claude/settings.json` (pro Repo) oder `~/.claude/settings.json` (überall)
einfügst.

Dann schreib die einzige Datei, die zählt:

```bash
cat > verify.sh <<'EOF'
#!/bin/bash
set -eu
cd "$(dirname "$0")"

npm test
npx tsc --noEmit
git diff --check

echo "verify.sh OK"
EOF
chmod +x verify.sh
```

Das ist die gesamte Einrichtung. Es gibt noch kein `verify.sh` in deinem Repo,
also tut das Gate gar nichts, bis du eines schreibst.

## Deine ersten fünf Minuten

Fang kleiner an, als du denkst. Ein `verify.sh`, das nur `git diff --check`
ausführt, ist schon etwas wert, und es wird bestehen - was dir zeigt, dass das
Gate still ist, wenn alles in Ordnung ist.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Jetzt lass es absichtlich fehlschlagen, damit du weißt, dass das Gate echt ist:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Bitte deinen Agenten, irgendeine Datei zu bearbeiten, und lass ihn dann fertig
werden. Er wird versuchen, seinen Zug zu beenden, das Gate wird `verify.sh`
ausführen, und der Zug wird blockiert. Mach das `exit 1` rückgängig, und
derselbe Agent kommt problemlos durch.

Von da an füge einen echten Check nach dem anderen hinzu: das Test-Kommando, das
du tatsächlich ausführst, dann den Typ-Checker, dann die Diff-Hygiene. Jeder
Check, den du hinzufügst, ist ein Satz in deiner Antwort auf *was bedeutet hier
bewiesen*. Hör auf, wenn das Ganze etwa eine Minute dauert.

Der Fehler, den es zu vermeiden gilt, ist, am ersten Tag ein ehrgeiziges
`verify.sh` zu schreiben. Ein langsames oder flackerndes Gate wird innerhalb
einer Woche umgangen, und ein umgangenes Gate ist schlimmer als keines: Es sagt
dir, dass ein Check stattgefunden hat, obwohl das nicht der Fall war.

## Wie es entscheidet, ob es läuft

Das Gate ist standardmäßig still. Es führt `verify.sh` nur aus, wenn jede dieser
Bedingungen erfüllt ist:

- die Sitzung hat tatsächlich Dateien bearbeitet (eine reine Lese-Sitzung hat nichts zu beweisen)
- ein ausführbares `verify.sh` existiert im Wurzelverzeichnis des Repos
- der Arbeitsbaum hat nicht committete Änderungen
- genau dieser Baumzustand hat noch nicht bestanden

Letzteres bedeutet, dass ein bestehender Baum einmal verifiziert wird, nicht bei
jedem Stopp. Fehlschläge geben die letzten 20 Zeilen der Ausgabe an den Agenten
aus, was meist ausreicht, damit er die Ursache behebt, ohne dass man es ihm
sagen muss.

Um das Gate absichtlich zu passieren: `PROVE_IT_SKIP=1`. Um es dauerhaft
abzuschalten: lösch `verify.sh`. Beides ist bewusst so. Ein Gate, das niemand
entfernen kann, ist ein Gate, um das die Leute herum routen.

## Der Ausstieg ist das Feature

Der härteste Fehlermodus ist kein flackernder Check. Es ist ein Agent, der
`verify.sh` nicht bestehen kann und stattdessen still `verify.sh` bearbeitet. Die
Fehlermeldung des Gates sagt das mit klaren Worten, und die Spec macht es zu
einer erklärten Verletzung. Achte trotzdem in deinen Diffs darauf. Genau dafür
ist der Diff-Beweis da.

## Die `verify.sh`-Konvention

Das Skript in `hooks/` ist absichtlich klein. Das eigentliche Artefakt ist die
Konvention, die es umsetzt, festgehalten in **[SPEC.md](../../SPEC.md)**: Ein
Repository erklärt, wie es sich selbst beweist, an einem bekannten Ort, mit einem
bekannten Vertrag, und ein Agent darf keine Fertigstellung behaupten, bis dieser
Beweis besteht.

Lies die Spec für die vier Arten von Beweisen, gegen die ein `verify.sh` prüfen
sollte - Kommando-Ausgabe, Diff, Reproduktion, Gegenprüfung - und für die
Konformitätsstufen.

**Eine ehrliche Anmerkung vorweg.** Dieses Werkzeug erzwingt genau eine Sache:
dass `verify.sh` null zurückgegeben hat, bevor der Zug endete. Ob diese Null
etwas *bedeutet*, hängt vollständig von den Checks ab, die du geschrieben hast.
Ein `verify.sh`, das nur `exit 0` enthält, besteht dieses Gate und beweist
nichts. Das Werkzeug ist Level 1. Der Beweis ist Level 2, und Level 2 ist eine
Praxis, kein Feature.

## Rezepte

Ausgangspunkte pro Stack, in [`recipes/`](../../recipes/). Kopier eines nach
`verify.sh` und streich, was nicht zutrifft. Halt es unter einer Minute;
langsame Checks gehören in CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

Der schwere Teil bei der Einführung ist nie das Verdrahten des Hooks. Es ist,
zum ersten Mal "was bedeutet *bewiesen* in diesem Repo" zu beantworten.

## Das Ledger

Setz `PROVE_IT_LEDGER=1`, und jede erwischte falsche Fertigmeldung hängt eine
Zeile an `~/.prove-it/ledger.jsonl` an:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Was behauptet wurde, was gefordert wurde, was wahr war. Nur lokale Festplatte,
nie übertragen, aus, außer du schaltest es ein. Nach einem Monat hörst du auf,
zu raten, wie dein Agent scheitert, und fängst an, es zu lesen.

## Dieses Repo gated sich selbst

`prove-it` hat ein `verify.sh`, und es führt das Gate gegen echte Git-Repos in
einem temporären Verzeichnis aus: ein fehlschlagender Check blockiert, ein
bestehender Check erlaubt, eine reine Lese-Sitzung bleibt unangetastet, ein
sauberer Baum wird übersprungen, der Bypass funktioniert.

```bash
./verify.sh
```

Alles andere auszuliefern wäre eine merkwürdige Sache.

## Lizenz

MIT.
