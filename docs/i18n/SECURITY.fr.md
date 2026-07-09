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

La barrière ne se lance que lorsque la session a changé **ce même dépôt** et
qu'un `verify.sh` exécutable existe à sa racine. Cloner et lire un dépôt ne la
déclenche jamais, et changer un dépôt ne fait jamais lancer le `verify.sh` d'un
autre dépôt.

`prove-it doctor` est l'exception, et c'est délibéré : vous lui avez demandé de
lancer la barrière, alors il lance `verify.sh` immédiatement, dans le dépôt où
vous vous trouvez. Ne le lancez pas dans un dépôt dont vous n'avez pas lu le
`verify.sh`.

Rien de tout cela n'est un bac à sable. Les hooks et leur comptabilité
s'exécutent en tant que vous, et le shell de l'agent aussi, si bien qu'un agent
décidé à vaincre la barrière pourrait supprimer le répertoire d'état, puis
désarmer `verify.sh`. `prove-it` est un garde-fou contre un agent qui a tort
avec assurance, et c'est celui que vous avez. Ce n'est pas une frontière contre
un agent hostile. Une vérification qu'un agent hostile ne peut pas atteindre
doit s'exécuter quelque part où il ne peut pas l'atteindre, et cet endroit,
c'est la CI.

## Ce qu'il écrit sur le disque

De petits fichiers de comptabilité, tous dans un répertoire privé créé en mode
`0700` : `$XDG_STATE_HOME/prove-it/`, ou `~/.local/state/prove-it/` quand cette
variable n'est pas définie. Remplacez-le avec `PROVE_IT_STATE_DIR`. Ils
enregistrent à quoi ressemblait l'arbre au démarrage d'une session, si la
barrière était armée à ce moment-là, dans quels dépôts une session a écrit,
quels états de l'arbre ont déjà passé, et combien de fois le tour en cours a été
renvoyé. Chacun contient une somme de contrôle ou un petit entier, jamais le
contenu des fichiers. Rien n'est écrit dans le `/tmp` partagé, parce que ces noms
de fichiers sont dérivés du chemin du dépôt et sont donc prévisibles, et un nom
prévisible dans un répertoire ouvert en écriture à tous est une cible de lien
symbolique.

L'identifiant de session arrive dans la charge JSON du hook et se retrouve à
l'intérieur d'un de ces noms de fichiers, alors il est réduit à des lettres, des
chiffres, des tirets et des traits de soulignement avant d'être utilisé. Une
charge n'est pas une source de confiance pour des composants de chemin.

Le registre optionnel (`PROVE_IT_LEDGER=1`, **désactivé par défaut**) ajoute une
ligne JSON par fausse complétion attrapée à `~/.prove-it/ledger.jsonl`, créé en
mode `0600` dans un répertoire `0700`. Chaque ligne contient :

- le dernier message de l'agent avant qu'il ne tente de s'arrêter, tronqué à 300
  caractères et tiré de votre transcription locale, donc il peut contenir tout ce
  qui était dans votre conversation
- le chemin absolu du dépôt
- le code de sortie, et les lignes de la sortie de votre `verify.sh` qui nomment un échec
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
