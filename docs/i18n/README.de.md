# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

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

Dein Agent kann seinen Zug nicht beenden, bis dein Repository sich selbst beweist.

Coding-Agenten melden, dass die Tests bestehen, obwohl sie sie nie ausgeführt
haben, und dass ein Fehler behoben ist, obwohl sie ihn nie reproduziert haben.
Der Agent hat keine Möglichkeit, das Getane mit dem Beabsichtigten zu
vergleichen, also meldet er die Absicht. Das ist eine Eigenschaft der Bauart,
kein Charakterfehler, und kein Prompt behebt es.

`prove-it` macht aus der Meldung eine Prüfung. Leg ein `verify.sh` in das
Wurzelverzeichnis deines Repositorys. Wenn der Agent seinen Zug beenden will,
führt ein Hook das Skript aus, und ein Exit-Code ungleich null schickt den
Agenten zurück an die Arbeit, statt ihn stoppen zu lassen.

![prove-it blockiert einen Agenten, der behauptet, fertig zu sein](../../docs/demo.svg)

Das Gate drängt bis zu dreimal pro Zug zurück und gibt dann nach, denn ein Hook,
der nie nachgibt, lässt die Sitzung hängen. Nachgeben ist nicht dasselbe wie
Bestehen, also ist das Letzte, was du siehst, eine Warnung, dass der Zug
unverifiziert endete, statt des Worts "fertig". Drei ist eine Zahl, die du ändern
kannst, und nichts davon ist die Behauptung, dass dein Agent nicht am Gate
vorbeikommen kann. Es ist die Behauptung, dass er nicht still am Gate
vorbeikommen kann.

Verwende es, wenn dein Repository einen lokalen Befehl hat, der wahr sein muss,
bevor ein Agent Arbeit zurückgibt: Tests, Typprüfungen, Lint, Checks für
generierte Dateien, Migration-Dry-Runs oder ein kleiner Smoke-Test, der zeigt,
dass der Fehler weg ist. `prove-it` ist am nützlichsten in Repositorys, in denen
ein Agent Code bearbeitet und im selben Thread "fertig" sagt.

Verwende es nicht als Sandbox, CI-Ersatz oder Ort für lange Netzwerkjobs. Wenn
ein Check Secrets, Produktionszugang oder mehr als ungefähr eine Minute braucht,
gehört er in CI. Halte `verify.sh` bei dem lokalen Beweis, den der Agent
ausführen kann, solange er noch arbeitet.

Der erste Tag ist absichtlich klein. Installiere das Plugin, führe
`/prove-it:init` aus, behalte das generierte `git diff --check` als einzigen
aktiven Check, und schalte dann einen echten Befehl erst ein, nachdem du ihn von
Hand hast bestehen sehen. Danach entscheidet `verify.sh`, ob der Agent die Arbeit
zurückgeben darf, wenn er das Repository geändert hat und stoppen will.

## Installation

Drei Zeilen, und die dritte erledigt die Arbeit:

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` erkennt deinen Stack, schreibt ein `verify.sh`, führt es aus,
damit du siehst, wie es besteht, und führt dann eine Kopie mit angehängtem
`exit 1` aus, damit du siehst, wie das Gate einen Zug verweigert. Das dauert
etwa dreißig Sekunden, und es überschreibt nie ein `verify.sh`, das du bereits
hast.

Das erzeugte Gate hat genau einen aktiven Check, `git diff --check`, wobei die
Checks für deinen Stack als Kommentare hineingeschrieben sind. Es besteht an dem
Tag, an dem du es installierst, mit Absicht. Ein Gate, das an dem Tag, an dem es
landet, auf `main` fehlschlägt, bringt Leuten bei, es in der ersten Woche zu
umgehen. Schalte die auskommentierten Checks einen nach dem anderen an, nachdem
du jeden von Hand hast bestehen sehen.

Sonst ist nichts konfiguriert, und nichts läuft, bis ein `verify.sh` existiert.
Wenn du ein Repository öffnest, das keines hat, sagt das Plugin das zu Beginn
der Sitzung, statt still zu bleiben und dich annehmen zu lassen, du seist
abgesichert.

## Ohne das Plugin

Die Hooks sind reines bash und brauchen nur `bash`, `git` und `python3`:

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Füge [`hooks/settings.example.json`](../../hooks/settings.example.json) in deine
`.claude/settings.json` für ein einzelnes Repository ein, oder in
`~/.claude/settings.json` für alle. Das Gate liest eine Stop-hook-JSON-Nutzlast
von stdin und antwortet mit einem Exit-Code, sodass alles, was am Ende eines
Zuges ein Skript ausführen kann, es antreiben kann.

`prove-it doctor` beantwortet, ob das Gate in dem Repository, in dem du stehst,
auslösen würde, und sagt dir, was es aufhält, falls nicht:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Das Gate wachsen lassen

Jeder Check, den du hinzufügst, ist ein Satz in deiner Antwort auf die Frage,
was "bewiesen" in diesem Repository bedeutet. Füge das Test-Kommando hinzu, das
du wirklich ausführst, dann den Typ-Checker, dann was auch immer deine Reviews
immer wieder erwischen. Hör auf, wenn das ganze Skript etwa eine Minute dauert;
langsame Checks gehören in CI.

Führ jeden Check von Hand aus, bevor du ihn anschaltest. Liefere auch nie einen
Check aus, den du nicht hast fehlschlagen sehen: ein Check, der nicht
fehlschlagen kann, ist kein Check, und das wirst du nicht an dem Tag
herausfinden, an dem du ihn brauchst.

Der häufige Fehler ist, am ersten Tag ein ehrgeiziges `verify.sh` zu schreiben.
Ein Gate, das langsam oder flackerig ist, wird binnen einer Woche umgangen, und
ein umgangenes Gate ist schlimmer als gar keines, weil es meldet, dass ein Check
lief, obwohl nichts lief.

## Wie es entscheidet, ob es läuft

Das Gate bleibt still, außer all dies trifft zu:

- diese Sitzung hat dieses Repository verändert
- ein ausführbares `verify.sh` existiert im Wurzelverzeichnis des Repositorys
- genau dieser Baumzustand hat noch nicht bestanden

"Verändert" beantwortet das Repository, nicht ein Protokoll darüber, welche
Werkzeuge liefen. Zu Beginn einer Sitzung hält der Hook fest, wie der Baum aussah,
und bei jedem Stopp fragt er, ob der Baum noch so aussieht. Eine von `sed` neu
geschriebene Datei, ein mit `git apply` angewandter Patch, eine von einem
Code-Generator ausgegebene Datei und ein Commit sind alle Änderungen, weil sie
alle den Baum verändern. Eine Sitzung, die nur gelesen hat, zählt als nichts,
selbst in einem Repository, das schon schmutzig war, als es geöffnet wurde.

Die letzte Bedingung bedeutet, dass ein bestehender Baum einmal verifiziert wird
statt bei jedem Stopp. Wenn die Verifikation fehlschlägt, sieht der Agent die
letzten zwanzig Zeilen der Ausgabe, was meist ausreicht, damit er die Ursache
behebt, ohne dass man ihm sagt, was schiefging.

`PROVE_IT_SKIP=1` kommt absichtlich am Gate vorbei. `verify.sh` zwischen
Sitzungen zu löschen schaltet es dauerhaft ab. Beide Notausgänge sind bewusst so:
Menschen routen um ein Gate herum, das sie nicht entfernen können.
`PROVE_IT_MAX_BLOCKS` legt fest, wie oft ein Zug zurückgeschickt werden kann, und
`0` lässt das Gate melden, ohne je zu blockieren.

## Wenn der Agent das Gate bearbeitet

Der härteste Fehlermodus ist kein flackeriger Check. Es ist ein Agent, der
`verify.sh` nicht bestehen kann und stattdessen `verify.sh` bearbeitet.

Die billigste Ausführung davon ist, das Gate schlicht zu entwaffnen, also
verweigert das Gate das. Der Hook hält fest, ob `verify.sh` ausführbar war, als
die Sitzung begann, und eine Sitzung, die mit gelöschtem `verify.sh` oder
entferntem Ausführbar-Bit endet, wird blockiert, ihr wird gesagt, was sie getan
hat, und ihr wird gesagt, wie man ehrlich aussteigt, falls das gemeint war.
`verify.sh` zwischen Sitzungen zu löschen ist weiterhin ein Ausstieg und braucht
weiterhin ein einziges Kommando.

Was unerzwungen bleibt, ist die subtile Ausführung: ein Agent, der `verify.sh`
ausführbar hält und die Checks darin still aushöhlt. Die Fehlermeldung sagt ihm,
dass er das nicht tun soll, und [SPEC.md](../../SPEC.md) nennt es eine Verletzung
statt einer Behebung, aber keines von beidem ist Durchsetzung. Lies deine Diffs.
Genau dafür ist der Diff-Beweis in der Spec da.

## Die `verify.sh`-Konvention

Das Skript in `hooks/` ist absichtlich klein. Was es umsetzt, ist in
[SPEC.md](../../SPEC.md) festgehalten: Ein Repository erklärt, wie es sich selbst
beweist, an einem bekannten Pfad, mit einem bekannten Vertrag, und ein Agent
darf keine Fertigstellung behaupten, bis dieser Beweis besteht. Die Spec benennt
eine Datei und einen Exit-Code und nie einen Anbieter, sodass das Plugin ein Weg
ist, die Idee zu verbreiten, nicht die Idee selbst.

Lies die Spec für die vier Arten von Beweisen, gegen die ein `verify.sh` prüfen
sollte - Kommando-Ausgabe, Diff, Reproduktion und Gegenprüfung - und für die
Konformitätsstufen.

## Was das nicht tut

Das Gate erzwingt eine Sache: dass `verify.sh` null zurückgegeben hat, bevor der
Zug endete. Ob diese Null etwas bedeutet, hängt vollständig von den Checks ab,
die du geschrieben hast. Ein `verify.sh`, das nur `exit 0` enthält, besteht
dieses Gate und beweist nichts.

Die Spec nennt das Level 1. Level 2 ist die Frage, ob deine Checks gegen echte
Beweise prüfen, und kein Werkzeug kann das für dich verifizieren, dieses
eingeschlossen.

Drei weitere Grenzen, schlicht benannt, weil du sie sonst in einem schlechten
Moment findest. Das Gate gibt nach `PROVE_IT_MAX_BLOCKS` Verweigerungen nach,
sodass ein entschlossener Agent das Ende seines Zuges erreicht; was er nicht
kann, ist still dort ankommen. Dateien, die deine `.gitignore` ausschließt, sind
für die Änderungserkennung unsichtbar, sodass ein `verify.sh`, das eine
ignorierte `.env` liest, übersprungen werden kann, wenn sich nur diese Datei
geändert hat. Und eine Sitzung, die außerhalb des Repositorys beginnt, das sie
später bearbeitet, hat keine Grundlinie zum Vergleich, was das Gate auf den
schwächeren Test zurückwirft, ob der Arbeitsbaum schmutzig ist.

## Rezepte

Ausgangspunkte pro Stack liegen in [`recipes/`](../../recipes/). Kopier eines
nach `verify.sh` und streich, was nicht zutrifft. Halt es unter einer Minute;
langsame Checks gehören in CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

Das Verdrahten des Hooks ist der leichte Teil. Die Arbeit ist, zu beantworten,
was "bewiesen" in deinem Repository bedeutet, und kein Rezept beantwortet das
für dich.

## Das Ledger

Setz `PROVE_IT_LEDGER=1`, und jede erwischte falsche Fertigmeldung hängt eine
Zeile an `~/.prove-it/ledger.jsonl` an:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Die Zeile hält fest, was der Agent behauptet hat, was von ihm gefordert wurde
und was sich als wahr herausstellte. Die Datei wird mit Modus `0600` auf die
lokale Festplatte geschrieben, nichts überträgt sie irgendwohin, und sie bleibt
aus, bis du sie einschaltest. Nach einem Monat an Einträgen kannst du aufhören
zu raten, wie dein Agent scheitert, und es stattdessen nachlesen.
`/prove-it:ledger` fasst die Datei für dich zusammen, ebenso wie
`prove-it ledger` auf der Kommandozeile.

## Dieses Repo gated sich selbst

`prove-it` hat ein `verify.sh`, und ein Teil dessen, was es ausführt, ist das
Gate selbst, gegen echte Git-Repositorys in einem temporären Verzeichnis: ein
fehlschlagender Check blockiert, ein bestehender Check erlaubt, eine reine
Lese-Sitzung bleibt unangetastet, ein sauberer Baum wird nach einem Commit
nicht mit keiner Arbeit verwechselt, der Bypass funktioniert.

```bash
./verify.sh
```

CI führt genau dieses Skript auf Linux und macOS aus, dazu einen separaten Job,
der beweist, dass das Gate ein Repository, dessen Checks fehlschlagen, weiterhin
blockiert. Das Repository führt außerdem CodeQL, OpenSSF Scorecard und einen
Tag-Release-Workflow aus, der Quellcode mit Prüfsumme und GitHub-Provenance-
Attestation paketiert.

## Projektvertrauen

Lies [SECURITY.md](../../SECURITY.md), bevor du dies in Repositorys verwendest,
denen du nicht vertraust. `prove-it` führt das repository-eigene `verify.sh`
aus; es ist ein Guardrail, keine Sandbox.

Die Release-Schritte stehen in [RELEASE.md](../../RELEASE.md), einschließlich
der Checkliste für Verifikation, Workflow-Status, Prüfsummen und Provenance-
Attestation. Die Support-Grenzen stehen in [SUPPORT.md](../../SUPPORT.md).

## Mitwirken

Issues und Pull Requests sind willkommen. Änderungen an der Konvention gehören
in ein Issue statt in einen Pull Request gegen die Referenzimplementierung.
Siehe [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Lizenz

MIT.
