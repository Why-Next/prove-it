# Contribution

## Où va un changement

Ce dépôt contient deux choses de poids différent.

[SPEC.md](../../SPEC.md) décrit une convention que d'autres outils devraient
pouvoir implémenter sans lire une ligne de ce code. Les modifications qui la
touchent commencent par une issue, pour que la discussion ait lieu avant que
quiconque n'écrive un correctif. Une pull request qui élargit discrètement le
contrat est plus difficile à contester qu'une proposition qui dit clairement ce
qu'elle veut changer.

`hooks/prove-it.sh` est une implémentation de cette convention, quelque
soixante-dix lignes, et les pull requests qui la visent ne demandent aucune
cérémonie.

Si vous ne savez pas laquelle des deux vous touchez, ouvrez une issue et
demandez.

## La barrière s'applique à vous aussi

Ce dépôt a un `verify.sh`. Lancez-le avant d'ouvrir une pull request :

```bash
./verify.sh
```

Il vérifie la syntaxe shell, lance shellcheck, valide les manifestes du plugin,
impose les règles de prose ci-dessous, tient les traductions à leurs originaux
anglais, et lance la propre suite de tests de la barrière contre de vrais dépôts
git dans un répertoire temporaire. La CI lance le même script sous Linux et
macOS, plus un job distinct qui prouve que la barrière bloque toujours un dépôt
dont les vérifications échouent.

Si `verify.sh` échoue, corrigez la cause. N'affaiblissez pas `verify.sh`. C'est
le seul changement que ce projet ne fusionnera pas, pour la raison même de son
existence.

## Ajouter une vérification

Une nouvelle vérification est bienvenue quand elle aurait attrapé un vrai bug.
Cassez quelque chose exprès, regardez votre vérification le remarquer, puis
corrigez et commitez les deux. Une vérification que personne n'a vue échouer
n'est pas une vérification.

Deux des scripts sous `scripts/` existent parce que leurs premières versions
passaient contre une base de code déjà cassée.

## Traductions

`README.md` et `SPEC.md` sont canoniques, et le texte anglais de `SPEC.md` fait
autorité là où une traduction le contredit. `scripts/check_i18n.py` tient chaque
traduction à son original : le nombre de titres, si les titres ont bien été
traduits, si les accents ont survécu, si les blocs de code sont identiques octet
pour octet à l'anglais, et si les liens relatifs se résolvent.

Deux règles font trébucher les gens.

N'utilisez jamais de tiret long. Pas de tiret cadratin, de tiret demi-cadratin,
de barre horizontale, ni de signe moins. Uniquement le trait d'union ASCII
simple, dans toutes les langues, y compris celles dont la typographie préfère le
contraire, parce qu'un tiret long se lit comme du texte écrit par une machine.
(Ce paragraphe nomme les caractères au lieu de les montrer, puisque
`scripts/check_no_long_dash.py` lit aussi ce fichier.)

Gardez toujours les accents. La règle du tiret couvre six caractères précis et
n'est pas une interdiction du non-ASCII. `décidé` reste `décidé`, et `è` ne
devient jamais `e'`. Une première traduction a supprimé tous les accents du
fichier en appliquant la première règle à l'excès.

## Recettes

Une recette est un point de départ pour une stack plutôt qu'un `verify.sh` fini.
Gardez-la sous une minute d'exécution, préférez les vérifications qui produisent
des preuves à celles qui produisent des opinions, et notez lequel des quatre
types de preuves de la spec chaque vérification livre.

## Commits

Commits conventionnels (`feat:`, `fix:`, `docs:`, `chore:`). Dites dans le corps
ce qui a changé et pourquoi. Si vous avez corrigé un bug, dites comment vous
l'avez reproduit.

## Releases

Les mainteneurs suivent [RELEASE.md](../../RELEASE.md). Une release exige un
`./verify.sh` local propre, les workflows `verify`, `codeql` et `scorecard` au
vert sur `main`, ainsi que la somme de contrôle et l'attestation de provenance
du workflow de tag. Ne publiez pas depuis un arbre non vérifié.
