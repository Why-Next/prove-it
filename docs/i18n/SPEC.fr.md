# La convention `verify.sh`

> Le texte anglais de [SPEC.md](../../SPEC.md) est la version normative. Des traductions existent pour
> [中文](SPEC.zh.md) ·
> [Deutsch](SPEC.de.md) ·
> [日本語](SPEC.ja.md) ·
> [हिन्दी](SPEC.hi.md) ·
> Français ·
> [Italiano](SPEC.it.md) ·
> [Português](SPEC.pt.md) ·
> [Русский](SPEC.ru.md) ·
> [Español](SPEC.es.md) ·
> [한국어](SPEC.ko.md).
> Elles sont informatives. Là où une traduction et ce texte divergent, ce texte
> fait autorité et la traduction est un bug à signaler.

Version 0.1 (brouillon). Un dépôt déclare comment il se prouve lui-même, et un
agent ne peut pas revendiquer l'achèvement tant que cette preuve ne passe pas.

Ce document est le contrat. Le script dans `hooks/` en est une implémentation,
délibérément petite. Lisez la section 5 sur les niveaux de conformité avant de
supposer que l'outil impose tout ce qui est écrit ici.

## 1. Le problème

Les agents de code terminent leurs tours avec des phrases comme celles-ci :

- "Les tests passent." Les tests n'ont jamais été lancés.
- "Bug corrigé." Le bug n'a jamais été reproduit.
- "La migration est sûre." Rien n'a été appliqué à une base de test.

Ce ne sont pas des mensonges au sens ordinaire. Un agent ne peut pas distinguer
ce qu'il a fait de ce qu'il avait l'intention de faire, alors son rapport décrit
l'intention. L'échec est structurel, et le prompting ne l'éliminera pas. Les
techniques de prompt vieillissent aussi à chaque génération de modèle, tandis
qu'une exigence de preuve se situe une couche au-dessus du modèle et survit à la
mise à jour.

Ainsi "terminé" cesse d'être quelque chose qu'un agent déclare et devient une
vérification qu'il doit réussir.

## 2. La convention

Un dépôt conforme possède un fichier exécutable `verify.sh` à sa racine.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

Le contrat :

| | |
|---|---|
| Emplacement | racine du dépôt |
| Mode | exécutable (`chmod +x`) |
| Invocation | lancé avec le CWD à la racine du dépôt, sans arguments |
| Code de sortie `0` | vérification réussie |
| Code de sortie non-`0` | vérification échouée ; stdout et stderr expliquent pourquoi |
| Sortie | lisible par un humain ; les 20 dernières lignes sont ce que voit un agent |
| Durée d'exécution | moins d'une minute ; les vérifications lentes ont leur place dans la CI |
| Absent | pas de barrière. L'absence est un état valide, pas un échec |

`verify.sh` répond à une seule question : que faudrait-il pour qu'un changement
ici soit sûr à rendre de façon démontrable ? Chaque dépôt y répond différemment,
et c'est pourquoi cette convention nomme le fichier et non son contenu.

Se retirer ne demande qu'une action : supprimer `verify.sh`, ou le réduire à
`exit 0`. C'est intentionnel. Les gens contournent une barrière qu'ils ne
peuvent pas retirer, et une barrière contournée rapporte quand même un succès.

## 3. Les quatre types de preuves

Un `verify.sh` devrait s'appuyer sur des preuves plutôt que sur des croyances.
Quatre types ont du poids. Un `verify.sh` utile en couvre au moins un, et un
`verify.sh` mûr les couvre tous les quatre à travers les vérifications qu'il
lance.

**Sortie de commande.** Une commande a été lancée et la vérification a lu son
code de sortie. Pas "les tests devraient passer" mais le verdict propre du
lanceur de tests.

**Diff.** Le changement est ce qui était voulu et rien de plus : pas
d'instructions de débogage, pas de fichiers égarés, pas de remaniement de mise en
forme sans rapport. `git diff --check` est le plancher.

**Reproduction.** Pour une correction de bug, l'échec a été observé avant le
changement et est absent après. Une correction qui n'a jamais été reproduite est
une supposition sur la ligne qui n'allait pas.

**Vérification croisée.** Une seconde source, indépendante, est d'accord. Un
autre modèle, un autre outil, un vérificateur de types face à une suite de tests.
C'est l'indépendance qui lui donne sa valeur ; deux vérifications qui partagent
une hypothèse confirment l'hypothèse plutôt que le code.

Les quatre catégories existent pour que "je l'ai vérifié" doive nommer une
méthode. Un agent qui ne peut pas dire lequel des quatre types de preuves il
détient n'en détient aucun.

## 4. Ce que les implémentations doivent faire

Une implémentation de cette convention est une barrière. Pour être conforme, elle
doit :

1. Lancer `verify.sh` depuis la racine du dépôt avant que le tour de l'agent
   puisse se terminer.
2. Bloquer le tour sur une sortie non nulle, et faire remonter la sortie.
3. Ne rien faire quand `verify.sh` n'existe pas comme exécutable au moment où la
   barrière s'exécute et n'existait pas comme exécutable au début de la session.
4. Ne rien faire quand la session n'a pas changé ce dépôt.
5. Fournir un contournement explicite et repérable au grep. Un contournement
   silencieux apprend aux gens à se méfier de la barrière ; un contournement
   audité la garde honnête.
6. Ne jamais terminer un tour en silence après une vérification en échec. Une
   implémentation qui cesse de bloquer, pour quelque raison que ce soit, doit le
   dire là où l'utilisateur le verra.

Le point 4 demande ce qui a changé, pas qui a changé. Une implémentation qui
décide en observant quels outils d'édition l'agent a appelés manquera un fichier
réécrit par `sed`, un correctif appliqué avec `git apply`, la sortie d'un
générateur de code, et un commit. Committer est la chose la plus ordinaire qu'un
agent fasse, et une barrière qui traite un arbre de travail propre comme s'il n'y
avait rien à prouver laissera passer les tours mêmes qu'elle existe pour
attraper. Comparez le dépôt à ce à quoi il ressemblait au début de la session.

Le point 3 utilise ces deux moments délibérément. Le stop actuel compte pour
qu'une commande d'installation puisse créer `verify.sh` et armer le dépôt dans
la même session. L'état initial compte pour qu'une suppression ou un `chmod -x`
au milieu de la session soit traitée comme un désarmement de la barrière, et non
comme un retrait honnête.

Le point 6 existe parce qu'une barrière qui peut bloquer indéfiniment fait se
figer la session, et tout hôte finit par la forcer à céder. C'est très bien. Ce
qui ne va pas, c'est de céder d'une manière indiscernable du fait de passer.

Elle ne doit pas modifier `verify.sh`, et elle doit dire à l'agent qu'affaiblir
`verify.sh` pour franchir la barrière est une violation plutôt qu'un correctif.
C'est le mode d'échec le plus probable en pratique. Un agent qui n'arrive pas à
passer une vérification, si l'occasion se présente, modifiera la vérification.

La forme la plus grossière de cela est de retirer la vérification. Une
implémentation devrait enregistrer si `verify.sh` était présent et exécutable au
début de la session, et refuser un tour qui se termine avec ce fichier supprimé
ou désarmé. Supprimer le fichier entre les sessions est le retrait de la section
2 et doit continuer de fonctionner. Le supprimer au milieu de la session qu'il
était sur le point de bloquer n'est pas un retrait, et la différence entre les
deux n'est visible que pour une implémentation qui a regardé avant.

## 5. Les niveaux de conformité

Soyez précis sur ce qu'une machine impose et ce qu'une personne pratique. Cette
distinction compte plus que l'ambition derrière la convention.

**Level 1, la barrière.** `verify.sh` existe, et quelque chose refuse
mécaniquement de laisser un tour se terminer tant qu'il échoue. L'implémentation
de référence dans `hooks/` l'impose entièrement, et c'est là que chaque dépôt
devrait commencer. "Refuse" a un budget : elle renvoie le tour un nombre borné de
fois puis cède avec un avertissement, parce que l'hôte ne laissera pas un hook
bloquer indéfiniment.

**Level 2, les preuves.** Les vérifications à l'intérieur de `verify.sh` couvrent
les quatre types de preuves de la section 3. Aucun outil ne l'impose, celui-ci
compris. La barrière vérifie que votre `verify.sh` a renvoyé zéro. Que ce zéro
signifie quelque chose est une affirmation sur les vérifications que vous avez
écrites, et un `verify.sh` ne contenant que `exit 0` atteint Level 1 sans rien
prouver.

**Level 3, le registre.** Chaque fausse complétion attrapée est enregistrée,
pour que les modes d'échec deviennent des données plutôt que des anecdotes.
L'implémentation de référence ne l'écrit que lorsque c'est explicitement activé.

Level 1 est une propriété d'un outil. Level 2 est une propriété des habitudes
d'une équipe, et tout outil qui prétend le livrer livre Level 1 en espérant que
personne ne lise le code source.

## 6. Le format du registre

Une fois activé, chaque fausse complétion attrapée ajoute un objet JSON par
ligne :

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

`claim` contient le dernier message de l'agent lui-même avant qu'il ne tente de
s'arrêter. C'est le champ le plus utile du relevé et le plus sensible, puisqu'il
peut contenir n'importe quel texte de la conversation. Une implémentation doit
écrire le registre sur le disque local avec des permissions restrictives et ne
doit jamais le transmettre.

Une ligne contient trois choses : ce qui a été revendiqué, ce qui a été exigé, et
ce qui était vrai.

## 7. Hors objectifs

Cette convention ne vous dit pas quoi vérifier, ne lance pas votre CI, ne note
pas votre code, et ne remplace pas la revue. Elle répond à une seule question :
ce dépôt s'est-il prouvé lui-même avant que l'agent ne s'en aille ?

---

*Les propositions de modification de ce document relèvent d'une issue plutôt que
d'une pull request contre l'implémentation de référence. Chaque ajout ici est
quelque chose que toute implémentation future devra porter.*
