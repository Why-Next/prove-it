# prove-it

[![verify](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
Français ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

Votre agent ne peut pas terminer son tour tant que votre dépôt ne s'est pas prouvé lui-même.

Les agents de code rapportent que les tests passent alors qu'ils ne les ont
jamais lancés, et qu'un bug est corrigé alors qu'ils ne l'ont jamais reproduit.
L'agent n'a aucun moyen de comparer ce qu'il a fait à ce qu'il voulait faire,
alors il rapporte l'intention. C'est une propriété de conception, pas un défaut
de caractère, et aucun prompt ne le corrige.

`prove-it` transforme le rapport en vérification. Placez un `verify.sh` à la
racine de votre dépôt. Quand l'agent tente de terminer son tour, un hook lance le
script, et une sortie non nulle maintient le tour ouvert jusqu'à ce que la cause
soit corrigée.

![prove-it bloque un agent qui prétend avoir terminé](../../docs/demo.svg)

Dans mon propre usage, un peu moins de la moitié des tours qui butent sur une
barrière en échec reviennent avec l'agent qui admet qu'il n'avait pas fini. Ces
tours se seraient autrement terminés sur le mot "terminé".

## Installation

Trois lignes, et c'est la troisième qui fait le travail :

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` détecte votre stack, écrit un `verify.sh`, le lance pour que
vous le voyiez passer, puis lance une copie avec `exit 1` ajouté pour que vous
voyiez la barrière refuser un tour. Cela prend environ trente secondes et
n'écrase jamais un `verify.sh` que vous avez déjà.

La barrière générée a exactement une vérification active, `git diff --check`,
avec les vérifications pour votre stack écrites en commentaires. Elle passe le
jour où vous l'installez, délibérément. Une barrière qui échoue sur `main` le
jour de son arrivée apprend aux gens à la contourner dès la première semaine.
Activez les vérifications commentées une à la fois, après avoir vu chacune passer
à la main.

Rien d'autre n'est configuré, et rien ne se lance tant qu'un `verify.sh`
n'existe pas. Si vous ouvrez un dépôt qui n'en a pas, le plugin le dit au début
de la session plutôt que de rester silencieux et de vous laisser supposer que
vous êtes couvert.

## Sans le plugin

Les hooks sont de simples scripts bash et n'ont besoin que de `bash`, `git` et
`python3` :

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Fusionnez [`hooks/settings.example.json`](../../hooks/settings.example.json) dans
votre `.claude/settings.json` pour un seul dépôt, ou `~/.claude/settings.json`
pour tous. La barrière lit une charge JSON de Stop hook sur stdin et répond par
un code de sortie, donc tout ce qui peut lancer un script en fin de tour peut la
piloter.

`prove-it doctor` répond à la question de savoir si la barrière se déclencherait
dans le dépôt où vous vous trouvez, et vous dit ce qui l'en empêche si ce n'est
pas le cas :

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty, so the gate would run on the next stop
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Faire grandir la barrière

Chaque vérification que vous ajoutez est une phrase dans votre réponse à la
question de ce que "prouvé" signifie dans ce dépôt. Ajoutez la commande de test
que vous lancez vraiment, puis le vérificateur de types, puis tout ce que vos
revues attrapent régulièrement. Arrêtez-vous quand le script complet prend
environ une minute ; les vérifications lentes ont leur place dans la CI.

Lancez chaque vérification à la main avant de l'activer. Ne livrez jamais non
plus une vérification que vous n'avez pas vue échouer : une vérification qui ne
peut pas échouer n'est pas une vérification, et vous ne le découvrirez pas le
jour où vous en aurez besoin.

L'erreur courante est d'écrire un `verify.sh` ambitieux dès le premier jour. Une
barrière lente ou instable se fait contourner en une semaine, et une barrière
contournée est pire que pas de barrière du tout, parce qu'elle rapporte qu'une
vérification a eu lieu alors que rien ne s'est passé.

## Comment elle décide de se lancer

La barrière reste silencieuse à moins que toutes ces conditions soient vraies :

- cette session a modifié des fichiers dans ce dépôt
- un `verify.sh` exécutable existe à la racine du dépôt
- l'arbre de travail contient des modifications non commitées
- cet état exact de l'arbre n'a pas déjà passé

La dernière condition signifie qu'un arbre qui passe est vérifié une seule fois,
pas à chaque arrêt. Quand la vérification échoue, l'agent voit les vingt
dernières lignes de sortie, ce qui suffit généralement pour qu'il corrige la
cause sans qu'on lui dise ce qui n'allait pas.

`PROVE_IT_SKIP=1` franchit la barrière volontairement. Supprimer `verify.sh` la
désactive pour de bon. Les deux échappatoires sont délibérées : les gens
contournent une barrière qu'ils ne peuvent pas retirer.

## Quand l'agent modifie la barrière

Le mode d'échec le plus difficile n'est pas une vérification instable. C'est un
agent qui n'arrive pas à faire passer `verify.sh` et qui modifie `verify.sh` à la
place. Le message d'échec lui dit de ne pas le faire, et
[SPEC.md](../../SPEC.md) qualifie cela de violation plutôt que de correctif, mais
aucun des deux n'est une contrainte technique. Lisez vos diffs. C'est à cela que
sert la preuve par le diff dans la spec.

## La convention `verify.sh`

Le script dans `hooks/` est volontairement petit. Ce qu'il implémente est écrit
noir sur blanc dans [SPEC.md](../../SPEC.md) : un dépôt déclare comment il se
prouve lui-même, à un endroit connu, avec un contrat connu, et un agent ne peut
pas revendiquer l'achèvement tant que cette preuve ne passe pas. La spec nomme un
fichier et un code de sortie, jamais un fournisseur, donc le plugin est une façon
de distribuer l'idée plutôt que l'idée elle-même.

Lisez la spec pour les quatre types de preuves qu'un `verify.sh` devrait
affirmer, à savoir la sortie de commande, le diff, la reproduction et la
vérification croisée, ainsi que pour les niveaux de conformité.

## Ce que ceci ne fait pas

La barrière impose une seule chose : que `verify.sh` ait renvoyé zéro avant la
fin du tour. Que ce zéro signifie quelque chose dépend entièrement des
vérifications que vous avez écrites. Un `verify.sh` ne contenant que `exit 0`
passe cette barrière et ne prouve rien.

La spec appelle cela Level 1. Level 2, c'est de savoir si vos vérifications
s'appuient sur de vraies preuves, et aucun outil ne peut le vérifier à votre
place, celui-ci compris.

## Recettes

Des points de départ par stack vivent dans [`recipes/`](../../recipes/).
Copiez-en un vers `verify.sh` et coupez ce qui ne s'applique pas. Gardez-le sous
une minute ; les vérifications lentes ont leur place dans la CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typage, lint, hygiène du diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, vérification gofmt |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, vérification du format |

Brancher le hook est la partie facile. Le travail, c'est de répondre à ce que
"prouvé" signifie dans votre dépôt, et aucune recette n'y répond à votre place.

## Le registre

Définissez `PROVE_IT_LEDGER=1` et chaque fausse complétion attrapée ajoute une
ligne à `~/.prove-it/ledger.jsonl` :

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

La ligne enregistre ce que l'agent a revendiqué, ce qui lui a été exigé, et ce
qui s'est avéré vrai. Le fichier est écrit sur le disque local avec le mode
`0600`, rien ne le transmet où que ce soit, et il reste désactivé jusqu'à ce que
vous l'activiez. Après un mois d'entrées, vous pouvez arrêter de deviner comment
votre agent échoue et le lire à la place. `/prove-it:ledger` en fait un résumé
pour vous, tout comme `prove-it ledger` en ligne de commande.

## Ce dépôt se met lui-même sous barrière

`prove-it` a un `verify.sh`, et une partie de ce qu'il lance est la barrière
elle-même, contre de vrais dépôts git dans un répertoire temporaire : une
vérification qui échoue bloque, une vérification qui passe autorise, une session
en lecture seule est laissée tranquille, un arbre propre est sauté, le
contournement fonctionne.

```bash
./verify.sh
```

La CI lance ce même script sous Linux et macOS, plus un job distinct qui prouve
que la barrière bloque toujours un dépôt dont les vérifications échouent.

## Contribution

Les issues et les pull requests sont bienvenues. Les modifications de la
convention relèvent d'une issue plutôt que d'une pull request contre
l'implémentation de référence. Voir [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licence

MIT.
