# Die `verify.sh`-Konvention

> Der englische Text in [SPEC.md](../../SPEC.md) ist die normative Fassung. Übersetzungen gibt es für
> [中文](SPEC.zh.md) ·
> Deutsch ·
> [日本語](SPEC.ja.md) ·
> [हिन्दी](SPEC.hi.md) ·
> [Français](SPEC.fr.md) ·
> [Italiano](SPEC.it.md) ·
> [Português](SPEC.pt.md) ·
> [Русский](SPEC.ru.md) ·
> [Español](SPEC.es.md) ·
> [한국어](SPEC.ko.md).
> Sie sind informativ. Wo eine Übersetzung und dieser Text sich widersprechen,
> gilt dieser Text, und die Übersetzung ist ein zu meldender Fehler.

Version 0.1 (Entwurf). Ein Repository erklärt, wie es sich selbst beweist, und
ein Agent darf keine Fertigstellung behaupten, bis dieser Beweis besteht.

Dieses Dokument ist der Vertrag. Das Skript in `hooks/` ist eine Umsetzung
davon, und eine bewusst kleine. Lies Abschnitt 5 über Konformitätsstufen, bevor
du annimmst, dass das Werkzeug alles hier Geschriebene erzwingt.

## 1. Das Problem

Coding-Agenten beenden Züge mit Sätzen wie diesen:

- "Tests bestehen." Die Tests wurden nie ausgeführt.
- "Fehler behoben." Der Fehler wurde nie reproduziert.
- "Die Migration ist sicher." Nichts wurde auf eine Wegwerf-Datenbank angewendet.

Das sind keine Lügen im gewöhnlichen Sinn. Ein Agent kann nicht unterscheiden,
was er getan hat, von dem, was er tun wollte, also beschreibt sein Bericht die
Absicht. Das Versagen ist strukturell, und Prompting beseitigt es nicht.
Prompt-Technik veraltet zudem mit jeder Modellgeneration, während eine Forderung
nach Beweisen eine Schicht über dem Modell sitzt und das Upgrade übersteht.

So hört "fertig" auf, etwas zu sein, das ein Agent erklärt, und wird zu einer
Prüfung, die er bestehen muss.

## 2. Die Konvention

Ein konformes Repository hat eine ausführbare Datei `verify.sh` in seinem
Wurzelverzeichnis.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

Der Vertrag:

| | |
|---|---|
| Ort | Wurzelverzeichnis des Repositorys |
| Modus | ausführbar (`chmod +x`) |
| Aufruf | mit CWD im Wurzelverzeichnis ausführen, ohne Argumente |
| Exit `0` | Verifikation bestanden |
| Exit ungleich `0` | Verifikation fehlgeschlagen; stdout und stderr erklären warum |
| Ausgabe | menschenlesbar; die letzten 20 Zeilen sind das, was ein Agent sieht |
| Laufzeit | unter einer Minute; langsame Checks gehören in CI |
| Fehlt | kein Gate. Abwesenheit ist ein gültiger Zustand, kein Fehler |

`verify.sh` beantwortet eine Frage: Was müsste wahr sein, damit eine Änderung
hier nachweisbar sicher zurückzugeben ist? Jedes Repository beantwortet sie
anders, weshalb diese Konvention die Datei benennt und nicht ihren Inhalt.

Der Ausstieg braucht eine Handlung: lösch `verify.sh` oder reduzier es auf
`exit 0`. Das ist Absicht. Menschen routen um ein Gate herum, das sie nicht
entfernen können, und ein umgangenes Gate meldet trotzdem Erfolg.

## 3. Die vier Arten von Beweisen

Ein `verify.sh` sollte gegen Beweise prüfen statt gegen Überzeugung. Vier Arten
haben Gewicht. Ein nützliches `verify.sh` deckt mindestens eine ab, ein
ausgereiftes alle vier über die Checks, die es ausführt.

**Kommando-Ausgabe.** Ein Kommando lief, und der Check las seinen Exit-Code.
Nicht "die Tests sollten bestehen", sondern das eigene Urteil des Test-Runners.

**Diff.** Die Änderung ist das, was beabsichtigt war, und nichts weiter: keine
Debug-Anweisungen, keine verirrten Dateien, keine unnötige Formatierungswut.
`git diff --check` ist die Untergrenze.

**Reproduktion.** Bei einer Fehlerbehebung wurde der Fehler vor der Änderung
beobachtet und ist danach verschwunden. Eine Behebung, die nie reproduziert
wurde, ist eine Vermutung darüber, welche Zeile falsch war.

**Gegenprüfung.** Eine zweite, unabhängige Quelle stimmt zu. Ein anderes Modell,
ein anderes Werkzeug, ein Typ-Checker gegen eine Testsuite. Unabhängigkeit ist
das, was es überhaupt wertvoll macht; zwei Checks, die eine Annahme teilen,
bestätigen die Annahme statt den Code.

Die vier Kategorien gibt es, damit "ich habe es verifiziert" eine Methode
benennen muss. Ein Agent, der nicht sagen kann, welche der vier Arten von
Beweisen er hat, hat keine davon.

## 4. Was Implementierungen tun müssen

Eine Implementierung dieser Konvention ist ein Gate. Um konform zu sein, muss
sie:

1. `verify.sh` vom Wurzelverzeichnis des Repositorys aus ausführen, bevor der
   Zug des Agenten enden kann.
2. Den Zug bei einem Exit-Code ungleich null blockieren und die Ausgabe zeigen.
3. Nichts tun, wenn `verify.sh` weder beim Lauf des Gates ausführbar vorhanden
   ist noch zu Beginn der Sitzung ausführbar vorhanden war.
4. Nichts tun, wenn die Sitzung dieses Repository nicht verändert hat.
5. Einen expliziten, grepbaren Bypass bereitstellen. Ein stiller Bypass bringt
   Menschen dazu, dem Gate zu misstrauen; ein auditierter hält es ehrlich.
6. Einen Zug niemals still nach einer fehlgeschlagenen Verifikation beenden. Eine
   Implementierung, die aus welchem Grund auch immer aufhört zu blockieren, muss
   das dort sagen, wo der Nutzer es sieht.

Punkt 4 fragt, was sich geändert hat, nicht wer es geändert hat. Eine
Implementierung, die anhand dessen entscheidet, welche Bearbeitungswerkzeuge der
Agent aufgerufen hat, verpasst eine von `sed` neu geschriebene Datei, einen mit
`git apply` angewandten Patch, die Ausgabe eines Code-Generators und einen
Commit. Committen ist das Gewöhnlichste, was ein Agent tut, und ein Gate, das
einen sauberen Arbeitsbaum als nichts zu Beweisendes behandelt, winkt genau die
Züge durch, die es fangen soll. Vergleiche das Repository damit, wie es aussah,
als die Sitzung begann.

Punkt 3 verwendet beide Zeitpunkte absichtlich. Der aktuelle Stopp zählt, damit
ein Installationsbefehl `verify.sh` erstellen und das Repository in derselben
Sitzung scharf schalten kann. Der Anfangszustand zählt, damit eine Löschung oder
ein `chmod -x` mitten in der Sitzung als Entwaffnen des Gates behandelt wird und
nicht als ehrlicher Ausstieg.

Punkt 6 gibt es, weil ein Gate, das ewig blockieren kann, die Sitzung hängen
lässt, und jeder Host es irgendwann zum Nachgeben zwingt. Das ist in Ordnung.
Nicht in Ordnung ist es, auf eine Weise nachzugeben, die von Bestehen nicht zu
unterscheiden ist.

Sie darf `verify.sh` nicht verändern, und sie muss dem Agenten sagen, dass das
Abschwächen von `verify.sh`, um am Gate vorbeizukommen, eine Verletzung ist und
keine Behebung. Das ist in der Praxis der wahrscheinlichste Fehlermodus. Ein
Agent, der einen Check nicht bestehen kann, wird, wenn er die Gelegenheit hat,
den Check bearbeiten.

Die roheste Form davon ist, den Check zu entfernen. Eine Implementierung sollte
festhalten, ob `verify.sh` beim Beginn der Sitzung vorhanden und ausführbar war,
und einen Zug verweigern, der mit gelöschtem oder entwaffnetem `verify.sh` endet.
Die Datei zwischen Sitzungen zu löschen ist der Ausstieg aus Abschnitt 2 und muss
weiter funktionieren. Sie mitten in der Sitzung zu löschen, die sie gerade
blockieren wollte, ist kein Ausstieg, und der Unterschied zwischen beidem ist nur
für eine Implementierung sichtbar, die vorher hingeschaut hat.

## 5. Konformitätsstufen

Sei genau darin, was eine Maschine erzwingt und was ein Mensch praktiziert.
Diese Unterscheidung zählt mehr als der Ehrgeiz hinter der Konvention.

**Level 1, das Gate.** `verify.sh` existiert, und etwas verweigert mechanisch,
einen Zug enden zu lassen, solange es fehlschlägt. Die Referenzimplementierung
in `hooks/` erzwingt das vollständig, und dort sollte jedes Repository anfangen.
"Verweigert" hat ein Budget: Es schickt den Zug eine begrenzte Anzahl von Malen
zurück und gibt dann mit einer Warnung nach, weil der Host einen Hook nicht ewig
blockieren lässt.

**Level 2, die Beweise.** Die Checks in `verify.sh` decken die vier Arten von
Beweisen aus Abschnitt 3 ab. Kein Werkzeug erzwingt das, dieses eingeschlossen.
Das Gate verifiziert, dass dein `verify.sh` null zurückgegeben hat. Ob diese
Null etwas bedeutet, ist eine Aussage über die Checks, die du geschrieben hast,
und ein `verify.sh`, das nur `exit 0` enthält, erreicht Level 1 und beweist
dabei nichts.

**Level 3, das Ledger.** Jede erwischte falsche Fertigmeldung wird
aufgezeichnet, damit die Fehlermodi zu Daten statt zu Anekdoten werden. Die
Referenzimplementierung schreibt das nur, wenn es ausdrücklich aktiviert ist.

Level 1 ist eine Eigenschaft eines Werkzeugs. Level 2 ist eine Eigenschaft der
Gewohnheiten eines Teams, und jedes Werkzeug, das behauptet, es zu liefern,
liefert Level 1 und hofft, dass niemand den Quelltext liest.

## 6. Das Ledger-Format

Wenn aktiviert, hängt jede erwischte falsche Fertigmeldung ein JSON-Objekt pro
Zeile an:

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

`claim` enthält die eigene letzte Nachricht des Agenten, bevor er zu stoppen
versuchte. Es ist das nützlichste Feld im Datensatz und das heikelste, da es
beliebigen Gesprächstext enthalten kann. Eine Implementierung muss das Ledger
mit restriktiven Rechten auf die lokale Festplatte schreiben und darf es niemals
übertragen.

Eine Zeile hält drei Dinge fest: was behauptet wurde, was gefordert wurde und
was wahr war.

## 7. Nicht-Ziele

Diese Konvention sagt dir nicht, was du prüfen sollst, führt dein CI nicht aus,
bewertet deinen Code nicht und ersetzt kein Review. Sie beantwortet eine einzige
Frage: ob dieses Repository sich selbst bewiesen hat, bevor der Agent davonging.

---

*Vorschläge zur Änderung dieses Dokuments gehören in ein Issue statt in einen
Pull Request gegen die Referenzimplementierung. Jede Ergänzung hier ist etwas,
das jede zukünftige Implementierung mittragen muss.*
