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

Das Gate läuft nur, wenn die Sitzung Dateien **in genau diesem Repository**
bearbeitet hat, der Arbeitsbaum schmutzig ist und ein ausführbares `verify.sh`
im Wurzelverzeichnis des Repos existiert. Ein Repository zu klonen und zu lesen
löst es nie aus, und ein Repository zu bearbeiten lässt nie das `verify.sh` eines
anderen Repositorys laufen.

## Was es auf die Festplatte schreibt

Zwei Marker, beide in einem privaten Verzeichnis, das mit Modus `0700` angelegt
wird: `$XDG_STATE_HOME/prove-it/`, oder `~/.local/state/prove-it/`, wenn das
nicht gesetzt ist. Überschreib es mit `PROVE_IT_STATE_DIR`. Nichts wird in das
gemeinsame `/tmp` geschrieben, weil diese Dateinamen vom Repository-Pfad
abgeleitet und daher vorhersehbar sind, und ein vorhersehbarer Name in einem für
alle beschreibbaren Verzeichnis ist ein Symlink-Ziel.

Das optionale Ledger (`PROVE_IT_LEDGER=1`, **standardmäßig aus**) hängt eine
JSON-Zeile pro erwischter falscher Fertigmeldung an `~/.prove-it/ledger.jsonl`
an, angelegt mit Modus `0600` in einem `0700`-Verzeichnis. Jede Zeile hält:

- die letzte Nachricht des Agenten, bevor er zu stoppen versuchte, auf 300
  Zeichen gekürzt und aus deinem lokalen Transkript gezogen, sodass sie alles
  enthalten kann, was in deinem Gespräch stand
- den absoluten Pfad des Repositorys
- den Exit-Code und die letzten fünf Zeilen deiner `verify.sh`-Ausgabe
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
