# Mitwirken

## Wo eine Änderung hingehört

Dieses Repository enthält zwei Dinge von unterschiedlichem Gewicht.

[SPEC.md](../../SPEC.md) beschreibt eine Konvention, die andere Werkzeuge
umsetzen können sollten, ohne eine Zeile dieses Codes zu lesen. Änderungen daran
beginnen als Issue, damit die Diskussion stattfindet, bevor jemand einen Patch
schreibt. Ein Pull Request, der den Vertrag stillschweigend erweitert, ist
schwerer zu diskutieren als ein Vorschlag, der klar sagt, was er ändern will.

`hooks/prove-it.sh` ist eine Umsetzung dieser Konvention, etwa siebzig Zeilen
davon, und Pull Requests dagegen brauchen kein Zeremoniell.

Wenn du unsicher bist, welches der beiden du berührst, öffne ein Issue und frag.

## Das Gate gilt auch für dich

Dieses Repository hat ein `verify.sh`. Führ es aus, bevor du einen Pull Request
öffnest:

```bash
./verify.sh
```

Es prüft die Shell-Syntax, führt shellcheck aus, validiert die
Plugin-Manifeste, erzwingt die Prosaregeln unten, hält die Übersetzungen an die
englischen Originale und führt die eigene Testsuite des Gates gegen echte
Git-Repositorys in einem temporären Verzeichnis aus. CI führt dasselbe Skript
auf Linux und macOS aus, dazu einen separaten Job, der beweist, dass das Gate
ein Repository, dessen Checks fehlschlagen, weiterhin blockiert.

Wenn `verify.sh` fehlschlägt, behebe die Ursache. Schwäch `verify.sh` nicht ab.
Das ist die eine Änderung, die dieses Projekt nicht mergen wird, aus dem Grund,
aus dem das Projekt existiert.

## Einen Check hinzufügen

Ein neuer Check ist willkommen, wenn er einen echten Fehler gefangen hätte. Mach
absichtlich etwas kaputt, sieh zu, wie dein Check es bemerkt, behebe es dann und
committe beides. Ein Check, den niemand hat fehlschlagen sehen, ist kein Check.

Zwei der Skripte unter `scripts/` existieren, weil ihre ersten Versionen gegen
eine Codebasis bestanden, die bereits kaputt war.

## Übersetzungen

`README.md` und `SPEC.md` sind maßgeblich, und der englische Text von `SPEC.md`
gilt, wo eine Übersetzung ihm widerspricht. `scripts/check_i18n.py` hält jede
Übersetzung an ihr Original: Überschriftenzahlen, ob die Überschriften überhaupt
übersetzt wurden, ob die Akzente überlebt haben, ob Codeblöcke byte-identisch
zum Englischen sind und ob relative Links auflösen.

Zwei Regeln bringen Leute zu Fall.

Verwende nie einen langen Bindestrich. Keinen Geviertstrich, keinen
Halbgeviertstrich, keinen waagerechten Balken und kein Minuszeichen. Nur einen
einfachen ASCII-Bindestrich, in jeder Sprache, auch in denen, deren Typografie
es anders bevorzugt, weil ein langer Strich sich wie maschinengeschriebener Text
liest. (Dieser Absatz benennt die Zeichen, statt sie zu zeigen, da
`scripts/check_no_long_dash.py` auch diese Datei liest.)

Behalte immer die Akzente. Die Strich-Regel betrifft sechs bestimmte Zeichen und
ist kein Verbot von Nicht-ASCII. `décidé` bleibt `décidé`, und `è` wird nie zu
`e'`. Eine frühe Übersetzung entfernte jeden Akzent in der Datei, indem sie die
erste Regel überdehnte.

## Rezepte

Ein Rezept ist ein Ausgangspunkt für einen Stack, kein fertiges `verify.sh`.
Halt es unter einer Minute Laufzeit, bevorzuge Checks, die Beweise erzeugen,
gegenüber Checks, die Meinungen erzeugen, und notiere, welche der vier
Beweisarten der Spec jeder Check liefert.

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`). Sag im Rumpf, was
sich geändert hat und warum. Wenn du einen Fehler behoben hast, sag, wie du ihn
reproduziert hast.
