# prove-it

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
Italiano ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

**Il tuo agente non può terminare il suo turno finché il tuo repo non lo dimostra.**

Gli agenti di coding dicono "i test passano" senza averli eseguiti, e "risolto"
senza aver mai riprodotto il bug. Non per malizia: un agente non sa distinguere
ciò che ha fatto da ciò che intendeva fare, quindi riporta l'intenzione.

`prove-it` rende *fatto* qualcosa che un agente deve superare, non qualcosa che
può semplicemente dichiarare. Metti un `verify.sh` alla radice del tuo repo.
Quando l'agente prova a fermarsi, il gate lo esegue. Exit diverso da zero, e il
turno non finisce.

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

Circa la metà delle volte, un agente a cui viene chiesta una prova risponde
"hai ragione, non è ancora fatto."

## Installazione

Richiede `bash`, `git`, `python3`. Nessun pacchetto, nessun daemon, niente a cui
iscriversi. Clonalo dove vuoi:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

Collega i due hook a Claude Code unendo
[`hooks/settings.example.json`](../../hooks/settings.example.json) nel tuo
`.claude/settings.json` (per repo) o `~/.claude/settings.json` (ovunque).

Poi scrivi l'unico file che conta:

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

Questa è tutta la configurazione. Nel tuo repo non c'è ancora nessun
`verify.sh`, quindi finché non ne scrivi uno, il gate non fa assolutamente
nulla.

## I tuoi primi cinque minuti

Comincia più in piccolo di quanto pensi. Un `verify.sh` che esegue solo
`git diff --check` vale già la pena di averlo, e passerà, il che ti insegna che
il gate resta silenzioso quando tutto va bene.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Ora guardalo fallire di proposito, così sai che il gate è reale:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Chiedi al tuo agente di modificare un file qualsiasi, poi lascialo terminare.
Proverà a chiudere il suo turno, il gate eseguirà `verify.sh`, e il turno
verrà bloccato. Annulla l'`exit 1` e lo stesso agente passerà senza problemi.

Da lì, aggiungi un controllo reale alla volta: il comando di test che esegui
davvero, poi il type checker, poi l'igiene del diff. Ogni controllo che aggiungi
è una frase nella tua risposta a *cosa significa dimostrato qui*. Fermati quando
il tutto richiede circa un minuto.

L'errore da evitare è scrivere un `verify.sh` ambizioso il primo giorno. Un gate
lento o instabile viene aggirato nel giro di una settimana, e un gate aggirato è
peggio di nessun gate: ti dice che un controllo è avvenuto quando non è così.

## Come decide se eseguire

Il gate è silenzioso per impostazione predefinita. Esegue `verify.sh` solo
quando tutte queste condizioni sono vere:

- la sessione ha effettivamente modificato dei file (una sessione di sola lettura non ha nulla da dimostrare)
- esiste un `verify.sh` eseguibile alla radice del repo
- il working tree ha modifiche non committate
- questo esatto stato dell'albero non è già passato

Quest'ultima condizione significa che un albero che passa viene verificato una
volta sola, non a ogni stop. I fallimenti stampano le ultime 20 righe di output
all'agente, il che di solito è sufficiente perché corregga la causa senza che
gli venga detto.

Per superare il gate di proposito: `PROVE_IT_SKIP=1`. Per disattivarlo del tutto:
elimina `verify.sh`. Entrambe le cose sono deliberate. Un gate che nessuno può
rimuovere è un gate che le persone aggirano.

## Il chiamarsi fuori è la funzionalità

La modalità di fallimento più difficile non è un controllo instabile. È un
agente che non riesce a passare `verify.sh` e modifica silenziosamente
`verify.sh` al suo posto. Il messaggio di fallimento del gate lo dice a chiare
lettere, e la spec ne fa una violazione dichiarata. Tienilo comunque d'occhio nei
tuoi diff. È a questo che serve l'evidenza del diff.

## La convenzione `verify.sh`

Lo script in `hooks/` è piccolo di proposito. Il vero artefatto è la convenzione
che implementa, messa nero su bianco in **[SPEC.md](../../SPEC.md)**: un repository
dichiara come dimostra se stesso, in un posto noto, con un contratto noto, e un
agente non può dichiarare il completamento finché quella prova non passa.

Leggi la spec per i quattro tipi di evidenza che un `verify.sh` dovrebbe
asserire - output dei comandi, diff, riproduzione, cross-check - e per i livelli
di conformità.

**Una nota onesta in premessa.** Questo strumento impone esattamente una cosa: che
`verify.sh` abbia restituito zero prima che il turno finisse. Se quello zero
*significhi* qualcosa dipende interamente dai controlli che hai scritto. Un
`verify.sh` che contiene solo `exit 0` passerà questo gate e non dimostrerà
nulla. Lo strumento è Level 1. L'evidenza è Level 2, e il Level 2 è una
pratica, non una funzionalità.

## Ricette

Punti di partenza per ogni stack, in [`recipes/`](../../recipes/). Copiane uno in
`verify.sh` e taglia ciò che non si applica. Tienilo sotto il minuto; i controlli
lenti appartengono alla CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

La parte difficile dell'adottare tutto questo non è mai collegare l'hook. È
rispondere per la prima volta a "cosa significa *dimostrato* in questo repo".

## Il registro

Imposta `PROVE_IT_LEDGER=1` e ogni falso completamento intercettato aggiunge una
riga a `~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Cosa è stato dichiarato, cosa è stato richiesto, cosa era vero. Solo disco
locale, mai trasmesso, disattivato a meno che tu non lo attivi. Dopo un mese
smetti di tirare a indovinare su come fallisce il tuo agente e cominci a leggerlo.

## Questo repo applica il gate a se stesso

`prove-it` ha un `verify.sh`, e lo esegue contro repo git reali in una directory
temporanea: un controllo che fallisce blocca, un controllo che passa consente, una
sessione di sola lettura resta intatta, un albero pulito viene saltato, il bypass
funziona.

```bash
./verify.sh
```

Sarebbe una cosa strana da rilasciare altrimenti.

## Licenza

MIT.
