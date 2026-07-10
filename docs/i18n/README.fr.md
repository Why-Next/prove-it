# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
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
script, et une sortie non nulle renvoie l'agent au travail au lieu de le laisser
s'arrêter.

![prove-it bloque un agent qui prétend avoir terminé](../../docs/demo.svg)

La barrière repousse le tour jusqu'à trois fois puis cède, parce qu'un hook qui
ne cède jamais fait se figer la session. Céder n'est pas la même chose que
passer, donc la dernière chose que vous voyez est un avertissement disant que le
tour s'est terminé sans vérification, plutôt que le mot "terminé". Trois est un
nombre que vous pouvez changer, et rien de tout cela ne prétend que votre agent
ne peut pas franchir la barrière. Cela prétend qu'il ne peut pas la franchir en
silence.

Utilisez-le quand un dépôt a une commande locale qui doit être vraie avant qu'un
agent rende le travail : tests, vérification de types, lint, contrôles de
fichiers générés, dry runs de migration, ou petit smoke test qui prouve que le
bug a disparu. `prove-it` est le plus utile dans les dépôts où un agent modifie
du code puis dit "terminé" dans le même fil.

Ne l'utilisez pas comme sandbox, remplacement de CI, ou endroit pour de longs
jobs réseau. Si une vérification a besoin de secrets, d'accès production, ou de
plus d'environ une minute, mettez-la en CI et gardez `verify.sh` pour la preuve
locale que l'agent peut lancer pendant qu'il travaille encore.

Le flux du premier jour reste petit exprès. Installez le plugin, lancez
`/prove-it:init`, gardez le `git diff --check` généré comme seule vérification
active, puis activez une vraie commande seulement après l'avoir vue passer à la
main. Ensuite, quand l'agent modifie le dépôt et tente de s'arrêter,
`verify.sh` décide s'il peut rendre le travail.

## Pourquoi pas cinq lignes de votre cru ?

Un Stop hook qui lance vos tests tient en cinq lignes de bash, c'est la première
version que presque tout le monde écrit, et il échoue de quatre façons
silencieuses. Plusieurs d'entre elles étaient des bugs dans les premières
versions de cette barrière même, et c'est pourquoi chacune a désormais son test
de régression.

- **Il repousse une fois, puis plus jamais.** Claude Code définit
  `stop_hook_active` à chaque arrêt après le premier blocage. Un hook qui lit ce
  drapeau comme "laisse passer" bloque exactement une fois puis cesse d'être une
  barrière, et un hook qui ignore le drapeau bloque pour toujours et fait se
  figer la session. Cette barrière compte les tentatives, repousse un nombre
  borné de fois, puis cède bruyamment.
- **Un commit ressemble à une absence de changement.** Un hook qui décide en
  regardant si l'arbre de travail est sale laisse passer tout tour qui se
  termine par un commit, et committer est la chose la plus ordinaire qu'un agent
  fasse. Cette barrière compare l'arbre à une référence enregistrée au début de
  la session, donc un commit, une réécriture par `sed` et un fichier généré
  comptent tous comme des changements.
- **L'agent peut retirer la vérification.** Un agent qui n'arrive pas à faire
  passer `verify.sh` peut le supprimer ou lui appliquer `chmod -x` à la place.
  Cette barrière enregistre si le dépôt était armé au début de la session et
  refuse un tour qui se termine avec la barrière désarmée. Une réécriture qui le
  garde exécutable est laissée passer, et vous est signalée plutôt que d'être
  crue en silence.
- **Abandonner est indiscernable de passer.** Tout hôte finit par forcer un hook
  à céder. Un hook écrit à la main cède en silence et le dernier mot que vous
  voyez est "terminé" ; le dernier mot de celui-ci est un avertissement disant
  que le tour s'est terminé sans vérification.

Si vous préférez garder votre propre hook, gardez-le, et lisez
[SPEC.md](../../SPEC.md) pour les cas qu'il doit couvrir. La convention compte
plus que cette implémentation-ci.

## Installation

Trois lignes, et c'est la troisième qui fait le travail :

```
/plugin marketplace add Why-Next/prove-it
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
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Fusionnez [`hooks/settings.example.json`](../../hooks/settings.example.json) dans
votre `.claude/settings.json` pour un seul dépôt, ou `~/.claude/settings.json`
pour tous. La barrière lit une charge JSON de Stop hook sur stdin et répond par
un code de sortie, donc tout ce qui peut lancer un script en fin de tour peut la
piloter. Claude Code est là où elle est testée ;
[docs/ADAPTERS.md](../ADAPTERS.md) contient le branchement pour Codex CLI, Qwen
Code, Gemini CLI et Copilot CLI, qui exposent le même genre de hook bloquant de
fin de tour, et dit clairement quels hôtes ne peuvent pas piloter de barrière du
tout.

`prove-it doctor` répond à la question de savoir si la barrière se déclencherait
dans le dépôt où vous vous trouvez, et vous dit ce qui l'en empêche si ce n'est
pas le cas :

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
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

- cette session a changé ce dépôt
- un `verify.sh` exécutable existe à la racine du dépôt
- cet état exact de l'arbre n'a pas déjà passé

"Changé" est une question à laquelle répond le dépôt, pas un journal des outils
qui se sont lancés. Au début d'une session, le hook enregistre à quoi ressemblait
l'arbre, et à chaque arrêt il demande si l'arbre y ressemble toujours. Un fichier
réécrit par `sed`, un correctif appliqué avec `git apply`, un fichier émis par un
générateur de code, et un commit sont tous des changements, parce qu'ils changent
tous l'arbre. Une session qui n'a fait que lire ne compte pour rien, même dans un
dépôt qui était déjà sale à son ouverture.

La dernière condition signifie qu'un arbre qui passe est vérifié une seule fois,
pas à chaque arrêt. Quand la vérification échoue, l'agent voit les vingt
dernières lignes de sortie, ce qui suffit généralement pour qu'il corrige la
cause sans qu'on lui dise ce qui n'allait pas.

`PROVE_IT_SKIP=1` franchit la barrière volontairement. Supprimer `verify.sh`
entre les sessions la désactive pour de bon. Les deux échappatoires sont
délibérées : les gens contournent une barrière qu'ils ne peuvent pas retirer.
`PROVE_IT_MAX_BLOCKS` fixe combien de fois un même tour peut être renvoyé, et `0`
fait que la barrière rapporte sans jamais bloquer.

## Quand l'agent modifie la barrière

Le mode d'échec le plus difficile n'est pas une vérification instable. C'est un
agent qui n'arrive pas à faire passer `verify.sh` et qui modifie `verify.sh` à la
place.

La version la moins chère de cela est de désarmer purement et simplement la
barrière, alors la barrière refuse. Le hook enregistre si `verify.sh` était
exécutable au début de la session, et une session qui se termine avec ce fichier
supprimé ou son bit d'exécution retiré est bloquée, informée de ce qu'elle a
fait, et informée de comment se retirer honnêtement si c'était bien son
intention. Supprimer `verify.sh` entre les sessions reste un retrait et ne
demande toujours qu'une seule commande.

La version subtile, c'est un agent qui garde `verify.sh` exécutable et réécrit
les vérifications qu'il contient. Ce passage n'est pas bloqué, parce que
modifier `verify.sh` est souvent exactement le travail que vous avez demandé,
mais il n'est plus silencieux non plus : quand un tour passe à travers un
`verify.sh` qui a changé pendant la session, la barrière vous le dit, et le diff
de `verify.sh` vous dit si le changement était du travail ou une esquive. Lisez
ce diff. C'est à cela que sert la preuve par le diff dans la spec.

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

Trois autres limites, énoncées clairement parce que sinon vous les découvrirez à
un mauvais moment. La barrière cède après `PROVE_IT_MAX_BLOCKS` refus, donc un
agent déterminé atteint la fin de son tour ; ce qu'il ne peut pas faire, c'est y
arriver en silence. Les fichiers que votre `.gitignore` exclut sont invisibles à
la détection de changements, donc un `verify.sh` qui lit un `.env` ignoré peut
être sauté quand seul ce fichier a changé. Et une session qui commence hors du
dépôt qu'elle modifie ensuite n'a aucune référence à laquelle se comparer, ce qui
rabat la barrière sur le test plus faible de savoir si l'arbre de travail est
sale.

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
en lecture seule est laissée tranquille, un arbre propre après un commit n'est
pas confondu avec une absence de travail, le contournement fonctionne.

```bash
./verify.sh
```

La CI lance ce même script sous Linux et macOS, plus un job distinct qui prouve
que la barrière bloque toujours un dépôt dont les vérifications échouent. Le
dépôt lance aussi CodeQL, OpenSSF Scorecard, et un workflow de release sur tag
qui empaquette la source avec une somme de contrôle et une attestation de
provenance GitHub.

## Confiance du projet

Lis [SECURITY.md](../../SECURITY.md) avant d'utiliser ceci dans des dépôts
auxquels tu ne fais pas confiance. `prove-it` exécute le `verify.sh` appartenant
au dépôt ; c'est un garde-fou, pas une sandbox.

Les étapes de release sont dans [RELEASE.md](../../RELEASE.md), avec la liste
pour la vérification, l'état des workflows, les sommes de contrôle, et
l'attestation de provenance. Les limites du support sont dans
[SUPPORT.md](../../SUPPORT.md).

## Contribution

Les issues et les pull requests sont bienvenues. Les modifications de la
convention relèvent d'une issue plutôt que d'une pull request contre
l'implémentation de référence. Voir [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licence

MIT.
