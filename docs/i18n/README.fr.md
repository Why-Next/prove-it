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

**Votre agent ne peut pas terminer son tour tant que votre dépôt ne s'est pas prouvé lui-même.**

Les agents de code disent "les tests passent" sans les avoir lancés, et "corrigé"
sans avoir jamais reproduit le bug. Non par malveillance : un agent ne peut pas
distinguer ce qu'il a fait de ce qu'il avait l'intention de faire, alors il
rapporte l'intention.

`prove-it` fait de *terminé* quelque chose qu'un agent doit réussir, pas quelque
chose qu'il peut se contenter de dire. Placez un `verify.sh` à la racine de votre
dépôt. Quand l'agent tente de s'arrêter, la barrière le lance. Sortie non nulle,
et le tour ne se termine pas.

![prove-it bloque un agent qui prétend avoir terminé](../../docs/demo.svg)

À peu près une fois sur deux, un agent à qui l'on demande des preuves répond
"vous avez raison, ce n'est pas encore fini."

## Installation

En tant que plugin Claude Code :

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

C'est toute l'installation. Le plugin enregistre deux hooks : l'un marque qu'une
session a modifié des fichiers, l'autre met le tour sous barrière.

Pour tout autre agent, ou si vous préférez ne pas installer de plugin, clonez le
dépôt et branchez vous-même les deux mêmes hooks. Ce sont de simples scripts bash
qui ne dépendent de rien d'autre que `bash`, `git` et `python3` :

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

Fusionnez [`hooks/settings.example.json`](../../hooks/settings.example.json) dans
votre `.claude/settings.json` (par dépôt) ou `~/.claude/settings.json` (partout).
La barrière lit une charge JSON de Stop hook sur stdin et communique par code de
sortie, donc tout ce qui peut lancer un script en fin de tour peut la piloter.

Ensuite, écrivez le seul fichier qui compte :

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

Tant que vous n'écrivez pas ce fichier, la barrière ne fait absolument rien.

## Vos cinq premières minutes

Commencez plus petit que vous ne le pensez. Un `verify.sh` qui ne lance que
`git diff --check` vaut déjà la peine d'exister, et il va passer, ce qui vous
apprend que la barrière reste silencieuse quand tout va bien.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Maintenant, regardez-le échouer exprès, pour que vous sachiez que la barrière est
réelle :

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Demandez à votre agent de modifier n'importe quel fichier, puis laissez-le
terminer. Il va tenter de finir son tour, la barrière va lancer `verify.sh`, et le
tour sera bloqué. Annulez le `exit 1` et le même agent passe sans encombre.

À partir de là, ajoutez une vraie vérification à la fois : la commande de test que
vous lancez réellement, puis le vérificateur de types, puis l'hygiène du diff.
Chaque vérification que vous ajoutez est une phrase dans votre réponse à *que
signifie prouvé ici*. Arrêtez-vous quand l'ensemble prend environ une minute.

L'erreur à éviter est d'écrire un `verify.sh` ambitieux dès le premier jour. Une
barrière lente ou instable se fait contourner en une semaine, et une barrière
contournée est pire que rien : elle vous dit qu'une vérification a eu lieu alors
que non.

## Comment elle décide de se lancer

La barrière est silencieuse par défaut. Elle ne lance `verify.sh` que lorsque
chacune de ces conditions est vraie :

- la session a réellement modifié des fichiers (une session en lecture seule n'a rien à prouver)
- un `verify.sh` exécutable existe à la racine du dépôt
- l'arbre de travail contient des modifications non commitées
- cet état exact de l'arbre n'a pas déjà passé

Cette dernière condition signifie qu'un arbre qui passe est vérifié une fois, pas à
chaque arrêt. Les échecs affichent les 20 dernières lignes de sortie à l'agent, ce
qui suffit généralement pour qu'il corrige la cause sans qu'on le lui dise.

Pour franchir la barrière volontairement : `PROVE_IT_SKIP=1`. Pour la désactiver
définitivement : supprimez `verify.sh`. Les deux sont délibérés. Une barrière que
personne ne peut retirer est une barrière que les gens contournent.

## Le retrait est la fonctionnalité

Le mode d'échec le plus difficile n'est pas une vérification instable. C'est un
agent qui n'arrive pas à passer `verify.sh` et modifie discrètement `verify.sh` à
la place. Le message d'échec de la barrière le dit en toutes lettres, et la spec en
fait une violation déclarée. Surveillez-le dans vos diffs quand même. C'est à cela
que sert la preuve par le diff.

## La convention `verify.sh`

Le script dans `hooks/` est volontairement petit. Le vrai artefact est la
convention qu'il implémente, écrite noir sur blanc dans **[SPEC.md](../../SPEC.md)** :
un dépôt déclare comment il se prouve lui-même, dans un endroit connu, avec un
contrat connu, et un agent ne peut pas revendiquer l'achèvement tant que cette
preuve ne passe pas.

Le plugin est un canal de distribution, pas l'idée. La convention est censée
survivre à n'importe quel agent, donc la spec nomme un fichier et un code de
sortie, jamais un fournisseur.

Lisez la spec pour les quatre types de preuves qu'un `verify.sh` devrait affirmer -
sortie de commande, diff, reproduction, vérification croisée - et pour les niveaux
de conformité.

**Une note honnête d'emblée.** Cet outil impose exactement une chose : que
`verify.sh` ait renvoyé zéro avant la fin du tour. Que ce zéro *signifie* quelque
chose dépend entièrement des vérifications que vous avez écrites. Un `verify.sh`
ne contenant que `exit 0` passera cette barrière et ne prouvera rien. L'outil est
Level 1. La preuve est Level 2, et Level 2 est une pratique, pas une
fonctionnalité.

## Recettes

Points de départ par stack, dans [`recipes/`](../../recipes/). Copiez-en un vers
`verify.sh` et coupez ce qui ne s'applique pas. Gardez-le sous une minute ; les
vérifications lentes ont leur place dans la CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typage, lint, hygiène du diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, vérification gofmt |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, vérification du format |

Le plus dur dans l'adoption de ceci n'est jamais de brancher le hook. C'est de
répondre à "que signifie *prouvé* dans ce dépôt" pour la première fois.

## Le registre

Définissez `PROVE_IT_LEDGER=1` et chaque fausse complétion attrapée ajoute une
ligne à `~/.prove-it/ledger.jsonl` :

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Ce qui a été revendiqué, ce qui a été exigé, ce qui était vrai. Disque local
uniquement, jamais transmis, désactivé sauf si vous l'activez. Après un mois, vous
arrêtez de deviner comment votre agent échoue et vous commencez à le lire.

## Ce dépôt se met lui-même sous barrière

`prove-it` a un `verify.sh`, et il lance la barrière contre de vrais dépôts git
dans un répertoire temporaire : une vérification qui échoue bloque, une
vérification qui passe autorise, une session en lecture seule reste intacte, un
arbre propre est sauté, le contournement fonctionne.

```bash
./verify.sh
```

Il serait étrange de livrer autrement.

## Contribution

Les issues et les pull requests sont bienvenues. Les modifications de la convention
elle-même relèvent d'une issue plutôt que d'une pull request contre
l'implémentation de référence : la convention est l'artefact, le script est la note
de bas de page. Voir [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licence

MIT.
