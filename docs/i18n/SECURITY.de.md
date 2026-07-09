# Sicherheit

## Was diese Software auf deinem Rechner tut

`prove-it` führt ein Skript aus, das in dem Repository liegt, das du geöffnet
hast. Wenn du ein Repository öffnest, dem du nicht vertraust, und sein
`verify.sh` ausführbar ist, führt dein Agent beim Beenden eines Zuges diese
Datei aus.

Dieses Verhalten ist das Design und kein Fehler darin, und das Risiko ist
dasselbe, das du bereits eingehst, wenn du `npm install` ausführst oder ein
Projekt mit einem `Makefile` öffnest. Lies ein unbekanntes `verify.sh`, bevor du
einen Agenten in dem Repository arbeiten lässt, das es enthält, so wie du ein
unbekanntes `postinstall`-Skript lesen würdest.

Das Gate läuft nur, wenn die Sitzung **genau dieses Repository** verändert hat
und ein ausführbares `verify.sh` in seinem Wurzelverzeichnis existiert. Ein
Repository zu klonen und zu lesen löst es nie aus, und ein Repository zu
verändern lässt nie das `verify.sh` eines anderen Repositorys laufen.

`prove-it doctor` ist die Ausnahme, und das ist Absicht: Du hast es gebeten, das
Gate auszuführen, also führt es `verify.sh` sofort aus, in welchem Repository du
auch stehst. Führ es nicht in einem Repository aus, dessen `verify.sh` du nicht
gelesen hast.

Nichts davon ist eine Sandbox. Die Hooks und ihre Buchführung laufen als du, und
die Shell des Agenten ebenso, also könnte ein Agent, der sich vorgenommen hat,
das Gate auszuhebeln, das Zustandsverzeichnis löschen und dann `verify.sh`
entwaffnen. `prove-it` ist ein Schutzgeländer gegen einen Agenten, der
zuversichtlich falschliegt, und genau den hast du. Es ist keine Grenze gegen
einen feindseligen. Eine Prüfung, die ein feindseliger Agent nicht erreichen
kann, muss irgendwo laufen, wo er sie nicht erreichen kann, und dieser Ort ist
CI.

## Was es auf die Festplatte schreibt

Kleine Buchhaltungsdateien, alle in einem privaten Verzeichnis, das mit Modus
`0700` angelegt wird: `$XDG_STATE_HOME/prove-it/`, oder `~/.local/state/prove-it/`,
wenn das nicht gesetzt ist. Überschreib es mit `PROVE_IT_STATE_DIR`. Sie halten
fest, wie der Baum aussah, als eine Sitzung begann, ob das Gate in diesem Moment
scharf war, in welche Repositorys eine Sitzung geschrieben hat, welche
Baumzustände bereits bestanden haben und wie oft der aktuelle Zug zurückgeschickt
wurde. Jede enthält eine Prüfsumme oder eine kleine Ganzzahl, nie Dateiinhalte.
Nichts wird in das gemeinsame `/tmp` geschrieben, weil diese Dateinamen vom
Repository-Pfad abgeleitet und daher vorhersehbar sind, und ein vorhersehbarer
Name in einem für alle beschreibbaren Verzeichnis ist ein Symlink-Ziel.

Die Sitzungskennung kommt in der JSON-Nutzlast des Hooks an und landet in einem
dieser Dateinamen, also wird sie auf Buchstaben, Ziffern, Bindestrich und
Unterstrich reduziert, bevor sie verwendet wird. Eine Nutzlast ist keine
vertrauenswürdige Quelle für Pfadbestandteile.

Das optionale Ledger (`PROVE_IT_LEDGER=1`, **standardmäßig aus**) hängt eine
JSON-Zeile pro erwischter falscher Fertigmeldung an `~/.prove-it/ledger.jsonl`
an, angelegt mit Modus `0600` in einem `0700`-Verzeichnis. Jede Zeile hält:

- die letzte Nachricht des Agenten, bevor er zu stoppen versuchte, auf 300
  Zeichen gekürzt und aus deinem lokalen Transkript gezogen, sodass sie alles
  enthalten kann, was in deinem Gespräch stand
- den absoluten Pfad des Repositorys
- den Exit-Code und die Zeilen deiner `verify.sh`-Ausgabe, die einen Fehler
  benennen
- einen Zeitstempel

Behandle es als Gesprächsdaten. Nichts in diesem Projekt liest es zurück oder
schickt es irgendwohin, aber es bleibt eine gewöhnliche Datei, also kopieren
deine Backups sie, und jeder mit Lesezugriff auf dein Home-Verzeichnis kann sie
öffnen.

## Was es sendet

Nichts. Die Software, die auf deinem Rechner läuft, enthält keine Telemetrie,
keinen Netzwerkaufruf und keine Update-Prüfung. Du kannst das mit einem einzigen
grep nach `curl`, `wget`, `urllib`, `requests` oder `socket` über `hooks/` und
`scripts/` bestätigen.

Continuous Integration ist die eine Ausnahme, und es ist kein Code, den du
ausführst: Der GitHub-Actions-Workflow installiert `shellcheck` aus `apt` oder
`brew`, bevor er dasselbe `verify.sh` ausführt, das du lokal ausführen würdest.

## Eine Schwachstelle melden

Schreib eine E-Mail an **hello@whynext.app** mit den Details und einer
Reproduktion. Bitte öffne kein öffentliches Issue für etwas, das ein Repository
aus den oben beschriebenen Grenzen ausbrechen lässt.

Rechne innerhalb weniger Tage mit einer Bestätigung. Eine Person pflegt das,
also hilft Geduld, und die Reproduktion hilft auch. Ein Bericht, den ich nicht
reproduzieren kann, ist einer, den ich nicht beheben kann.

## Unterstützte Versionen

Die neueste Veröffentlichung. Dieses Projekt ist klein genug, dass Backporting
kein Dienst ist, von dem irgendjemand profitieren würde.
