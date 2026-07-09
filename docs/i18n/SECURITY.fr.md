# Sécurité

## Ce que ce logiciel fait sur votre machine

`prove-it` lance un script qui vit dans le dépôt que vous avez ouvert. Si vous
ouvrez un dépôt en lequel vous n'avez pas confiance, et que son `verify.sh` est
exécutable, votre agent qui termine un tour exécutera ce fichier.

Ce comportement relève de la conception plutôt que d'un défaut, et le risque est
celui que vous acceptez déjà quand vous lancez `npm install` ou ouvrez un projet
avec un `Makefile`. Lisez un `verify.sh` inconnu avant de laisser un agent
travailler dans le dépôt qui le contient, comme vous liriez un script
`postinstall` inconnu.

La barrière ne se lance que lorsque la session a modifié des fichiers **dans ce
même dépôt**, que l'arbre de travail est sale, et qu'un `verify.sh` exécutable
existe à la racine du dépôt. Cloner et lire un dépôt ne la déclenche jamais, et
modifier un dépôt ne fait jamais lancer le `verify.sh` d'un autre dépôt.

## Ce qu'il écrit sur le disque

Deux marqueurs, tous deux dans un répertoire privé créé en mode `0700` :
`$XDG_STATE_HOME/prove-it/`, ou `~/.local/state/prove-it/` quand cette variable
n'est pas définie. Remplacez-le avec `PROVE_IT_STATE_DIR`. Rien n'est écrit dans
le `/tmp` partagé, parce que ces noms de fichiers sont dérivés du chemin du dépôt
et sont donc prévisibles, et un nom prévisible dans un répertoire ouvert en
écriture à tous est une cible de lien symbolique.

Le registre optionnel (`PROVE_IT_LEDGER=1`, **désactivé par défaut**) ajoute une
ligne JSON par fausse complétion attrapée à `~/.prove-it/ledger.jsonl`, créé en
mode `0600` dans un répertoire `0700`. Chaque ligne contient :

- le dernier message de l'agent avant qu'il ne tente de s'arrêter, tronqué à 300
  caractères et tiré de votre transcription locale, donc il peut contenir tout ce
  qui était dans votre conversation
- le chemin absolu du dépôt
- le code de sortie et les cinq dernières lignes de la sortie de votre `verify.sh`
- un horodatage

Traitez-le comme des données de conversation. Rien dans ce projet ne le relit ni
ne l'envoie où que ce soit, mais il reste un fichier ordinaire, donc vos
sauvegardes le copieront et quiconque a un accès en lecture à votre répertoire
personnel peut l'ouvrir.

## Ce qu'il envoie

Rien. Le logiciel qui tourne sur votre machine ne contient aucune télémétrie,
aucun appel réseau, et aucune vérification de mise à jour. Vous pouvez le
confirmer avec un seul grep de `curl`, `wget`, `urllib`, `requests`, ou `socket`
à travers `hooks/` et `scripts/`.

L'intégration continue est la seule exception, et ce n'est pas du code que vous
lancez : le workflow GitHub Actions installe `shellcheck` depuis `apt` ou `brew`
avant de lancer le même `verify.sh` que vous lanceriez localement.

## Signaler une vulnérabilité

Envoyez un courriel à **hello@whynext.app** avec les détails et une reproduction.
Merci de ne pas ouvrir d'issue publique pour tout ce qui permet à un dépôt de
sortir des limites décrites ci-dessus.

Attendez-vous à un accusé de réception sous quelques jours. Une seule personne
maintient ceci, donc la patience aide, et la reproduction aussi. Un rapport que
je ne peux pas reproduire est un rapport que je ne peux pas corriger.

## Versions prises en charge

La dernière version publiée. Ce projet est assez petit pour que le rétroportage
ne rende service à personne.
