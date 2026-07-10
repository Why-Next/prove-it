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
[Français](README.fr.md) ·
Italiano ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

Il tuo agente non può terminare il turno finché il repository non lo dimostra.

Gli agenti di codice riferiscono che i test passano quando non li hanno mai
eseguiti, e che un bug è risolto quando non lo hanno mai riprodotto. L'agente non
ha modo di confrontare ciò che ha fatto con ciò che intendeva fare, quindi
riferisce l'intenzione. È una proprietà del progetto, non un difetto di
carattere, e nessun prompt lo risolve.

`prove-it` trasforma il resoconto in un controllo. Metti un `verify.sh` alla
radice del repository. Quando l'agente prova a terminare il turno, un hook esegue
lo script, e un'uscita diversa da zero rimanda l'agente al lavoro invece di
lasciarlo fermare.

![prove-it blocca un agente che dichiara di aver finito](../../docs/demo.svg)

Il gate insiste fino a tre volte per turno e poi cede, perché un hook che non
cede mai blocca la sessione. Cedere non è lo stesso che passare, quindi l'ultima
cosa che vedi è un avviso che il turno è finito non verificato anziché la parola
"fatto". Tre è un numero che puoi cambiare, e niente di tutto questo è
un'affermazione che il tuo agente non possa superare il gate. È un'affermazione
che non può superarlo in silenzio.

Usalo quando un repository ha un comando locale che deve essere vero prima che
un agente restituisca il lavoro: test, controlli di tipo, lint, controlli sui
file generati, dry run di migrazione o un piccolo smoke test che prova che il bug
è sparito. `prove-it` è più utile nei repository in cui un agente modifica codice
e dice "fatto" nello stesso thread.

Non usarlo come sandbox, sostituto della CI o posto per job lunghi con rete. Se
un controllo richiede secrets, accesso alla produzione o più di circa un minuto,
mettilo in CI e tieni `verify.sh` alla prova locale che l'agente può eseguire
mentre sta ancora lavorando.

Il flusso del primo giorno è piccolo per scelta. Installa il plugin, esegui
`/prove-it:init`, lascia il `git diff --check` generato come unico controllo
attivo, poi attiva un comando reale solo dopo averlo visto passare a mano. Da
quel momento, quando l'agente cambia il repository e prova a fermarsi,
`verify.sh` decide se può restituire il lavoro.

## Perché non cinque righe scritte da te?

Uno Stop hook che esegue i tuoi test è questione di cinque righe di bash, è la
prima versione di quasi tutti, e fallisce in quattro modi silenziosi. Alcuni di
questi erano bug nelle prime versioni proprio di questo gate, ed è per questo
che ognuno ora ha un test di regressione.

- **Rimanda indietro una volta, poi mai più.** Claude Code imposta
  `stop_hook_active` a ogni stop dopo il primo blocco. Un hook che legge quel
  flag come "lascialo passare" blocca esattamente una volta e poi smette di
  essere un gate, e uno che ignora il flag blocca per sempre e paralizza la
  sessione. Questo gate conta i tentativi, rimanda indietro un numero limitato
  di volte, e poi cede facendosi sentire.
- **Dopo un commit sembra che non sia successo nulla.** Un hook che decide
  controllando se l'albero di lavoro è sporco lascia passare qualsiasi turno
  che finisce con un commit, e committare è la cosa più ordinaria che un agente
  faccia. Questo gate confronta l'albero con una baseline registrata all'inizio
  della sessione, quindi un commit, una riscrittura con `sed` e un file
  generato contano tutti come modifiche.
- **L'agente può rimuovere il controllo.** Un agente che non riesce a superare
  `verify.sh` può invece cancellarlo o dargli un `chmod -x`. Questo gate
  registra se il repository era armato quando la sessione è iniziata e rifiuta
  un turno che finisce con il gate disarmato. Una riscrittura che lo mantiene
  eseguibile viene lasciata passare, e ti viene segnalata anziché essere
  creduta in silenzio.
- **Cedere è indistinguibile dal passare.** Ogni host prima o poi costringe un
  hook a cedere. Un hook fatto a mano cede in silenzio e l'ultima parola che
  vedi è "fatto"; l'ultima parola di questo è un avviso che il turno è finito
  non verificato.

Se preferisci tenere il tuo hook, tienilo, e leggi [SPEC.md](../../SPEC.md) per
i casi che deve coprire. La convenzione conta più di questa sua implementazione.

## Installazione

Tre righe, e la terza fa il lavoro:

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` rileva il tuo stack, scrive un `verify.sh`, lo esegue così lo
vedi passare, poi esegue una copia con `exit 1` aggiunto in coda così vedi il
gate rifiutare un turno. Impiega circa trenta secondi e non sovrascrive mai un
`verify.sh` che hai già.

Il gate generato ha esattamente un controllo attivo, `git diff --check`, con i
controlli per il tuo stack scritti come commenti. Passa il giorno in cui lo
installi, di proposito. Un gate che fallisce su `main` il giorno in cui arriva
insegna alle persone ad aggirarlo nella prima settimana. Attiva i controlli
commentati uno alla volta, dopo aver visto ciascuno passare a mano.

Nient'altro è configurato, e nulla viene eseguito finché non esiste un
`verify.sh`. Se apri un repository che non ne ha uno, il plugin lo dice
all'inizio della sessione anziché restare in silenzio e lasciarti supporre di
essere coperto.

## Senza il plugin

Gli hook sono semplice bash e richiedono solo `bash`, `git` e `python3`:

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Unisci [`hooks/settings.example.json`](../../hooks/settings.example.json) al tuo
`.claude/settings.json` per un singolo repository, oppure a
`~/.claude/settings.json` per tutti. Il gate legge un payload JSON dello Stop
hook su stdin e risponde con un codice di uscita, quindi qualsiasi cosa possa
eseguire uno script a fine turno può pilotarlo. Claude Code è dove viene
testato; [docs/ADAPTERS.md](../ADAPTERS.md) spiega come collegarlo a Codex CLI,
Qwen Code, Gemini CLI e Copilot CLI, che espongono lo stesso tipo di hook
bloccante di fine turno, e dice chiaramente quali host non possono affatto
pilotare un gate.

`prove-it doctor` risponde se il gate scatterebbe nel repository in cui ti trovi,
e ti dice cosa lo blocca se non lo farebbe:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Far crescere il gate

Ogni controllo che aggiungi è una frase nella tua risposta alla domanda su cosa
significhi "dimostrato" in questo repository. Aggiungi il comando di test che
esegui davvero, poi il controllo dei tipi, poi qualsiasi cosa le tue revisioni
continuino a intercettare. Fermati quando l'intero script impiega circa un
minuto; i controlli lenti stanno in CI.

Esegui ogni controllo a mano prima di attivarlo. E non rilasciare mai un
controllo che non hai visto fallire: un controllo che non può fallire non è un
controllo, e non lo scoprirai il giorno in cui ne hai bisogno.

L'errore comune è scrivere un `verify.sh` ambizioso il primo giorno. Un gate
lento o instabile viene aggirato nel giro di una settimana, e un gate aggirato è
peggio di nessun gate, perché segnala che un controllo è stato eseguito quando
non è successo nulla.

## Come decide se eseguire

Il gate resta silenzioso a meno che non valgano tutte queste condizioni:

- questa sessione ha modificato questo repository
- esiste un `verify.sh` eseguibile alla radice del repository
- questo stato esatto dell'albero non è già passato

"Modificato" lo risponde il repository, non un registro di quali strumenti sono
stati eseguiti. All'inizio di una sessione l'hook registra com'era l'albero, e a
ogni stop chiede se l'albero abbia ancora quell'aspetto. Un file riscritto da
`sed`, una patch applicata con `git apply`, un file prodotto da un generatore di
codice e un commit sono tutti modifiche, perché tutti cambiano l'albero. Una
sessione che ha solo letto conta come nulla, anche in un repository che era già
sporco quando è stata aperta.

L'ultima condizione fa sì che un albero che passa venga verificato una volta sola
invece che a ogni stop. Quando la verifica fallisce, l'agente vede le ultime
venti righe dell'output, di solito abbastanza per correggere la causa senza che
gli venga detto cosa è andato storto.

`PROVE_IT_SKIP=1` supera il gate di proposito. Cancellare `verify.sh` tra una
sessione e l'altra lo disattiva del tutto. Entrambe le vie di fuga sono volute:
le persone aggirano un gate che non possono rimuovere. `PROVE_IT_MAX_BLOCKS`
imposta quante volte un singolo turno può essere rimandato indietro, e `0` fa sì
che il gate segnali senza mai bloccare.

## Quando l'agente modifica il gate

La modalità di fallimento più difficile non è un controllo instabile. È un agente
che non riesce a far passare `verify.sh` e allora modifica `verify.sh`.

La versione più economica è disarmare il gate del tutto, e allora il gate la
rifiuta. L'hook registra se `verify.sh` era eseguibile quando la sessione è
iniziata, e una sessione che finisce con il file cancellato o con il bit di
esecuzione rimosso viene bloccata, le viene detto cosa ha fatto, e le viene detto
come rinunciare in modo onesto se era questo che intendeva. Cancellare
`verify.sh` tra una sessione e l'altra resta una rinuncia e richiede ancora un
solo comando.

La versione sottile è un agente che tiene `verify.sh` eseguibile e ne riscrive i
controlli. Quel passaggio non viene bloccato, perché modificare `verify.sh` è
spesso esattamente il lavoro che hai chiesto, ma non è più nemmeno silenzioso:
quando un turno passa attraverso un `verify.sh` cambiato durante la sessione, il
gate te lo dice, e il diff a `verify.sh` ti dice se la modifica era lavoro o
elusione. Leggi quel diff. È a questo che serve la prova per diff nella
specifica.

## La convenzione `verify.sh`

Lo script in `hooks/` è volutamente piccolo. Ciò che implementa è scritto in
[SPEC.md](../../SPEC.md): un repository dichiara come si dimostra, a un percorso
noto, con un contratto noto, e un agente non può dichiarare il completamento
finché quella prova non passa. La specifica nomina un file e un codice di uscita
e non nomina mai un fornitore, quindi il plugin è un modo di distribuire l'idea
piuttosto che l'idea stessa.

Leggi la specifica per i quattro tipi di prova contro cui un `verify.sh`
dovrebbe verificarsi, cioè l'output del comando, il diff, la riproduzione e il
controllo incrociato, e per i livelli di conformità.

## Cosa non fa

Il gate impone una sola cosa: che `verify.sh` abbia restituito zero prima della
fine del turno. Se quello zero significhi qualcosa dipende interamente dai
controlli che hai scritto. Un `verify.sh` che contiene solo `exit 0` passa questo
gate e non dimostra nulla.

La specifica lo chiama Level 1. Il Level 2 è se i tuoi controlli si verificano
contro prove reali, e nessuno strumento può verificarlo al posto tuo, questo
incluso.

Altri tre confini, detti chiaramente perché altrimenti li scoprirai in un brutto
momento. Il gate cede dopo `PROVE_IT_MAX_BLOCKS` rifiuti, quindi un agente
ostinato raggiunge la fine del suo turno; ciò che non può fare è arrivarci in
silenzio. I file che il tuo `.gitignore` esclude sono invisibili al rilevamento
delle modifiche, quindi un `verify.sh` che legge un `.env` ignorato può essere
saltato quando è cambiato solo quel file. E una sessione che inizia fuori dal
repository che poi modifica non ha alcuna baseline con cui confrontarsi, il che
riporta il gate al test più debole di se l'albero di lavoro è sporco.

## Ricette

I punti di partenza per ogni stack stanno in [`recipes/`](../../recipes/).
Copiane uno in `verify.sh` e taglia ciò che non serve. Tienilo sotto il minuto;
i controlli lenti stanno in CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | test, typecheck, lint, igiene del diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, controllo gofmt |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, controllo del formato |

Collegare l'hook è la parte facile. Il lavoro è rispondere a cosa significhi
"dimostrato" nel tuo repository, e nessuna ricetta lo risponde al posto tuo.

## Il ledger

Imposta `PROVE_IT_LEDGER=1` e ogni falso completamento intercettato aggiunge una
riga a `~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

La riga registra ciò che l'agente ha affermato, ciò che gli è stato richiesto e
ciò che si è rivelato vero. Il file è scritto su disco locale con permessi
`0600`, nulla lo trasmette da nessuna parte, e resta disattivato finché non lo
attivi. Dopo un mese di voci puoi smettere di tirare a indovinare su come
fallisce il tuo agente e leggerlo invece. `/prove-it:ledger` ti riassume il file,
così come `prove-it ledger` da riga di comando.

## Questo repo applica il gate a se stesso

`prove-it` ha un `verify.sh`, e parte di ciò che esegue è il gate stesso, contro
repository git reali in una directory temporanea: un controllo che fallisce
blocca, un controllo che passa lascia procedere, una sessione di sola lettura
viene lasciata in pace, un albero pulito dopo un commit non viene scambiato per
assenza di lavoro, il bypass funziona.

```bash
./verify.sh
```

La CI esegue lo stesso script su Linux e macOS, più un job separato che dimostra
che il gate blocca ancora un repository i cui controlli falliscono. Il
repository esegue anche CodeQL, OpenSSF Scorecard e un workflow di release su
tag che impacchetta il sorgente con checksum e attestazione di provenienza
GitHub.

## Fiducia nel progetto

Leggi [SECURITY.md](../../SECURITY.md) prima di usarlo in repository di cui non
ti fidi. `prove-it` esegue il `verify.sh` di proprietà del repository; è un
guardrail, non una sandbox.

I passi di release sono in [RELEASE.md](../../RELEASE.md), inclusa la checklist
per verifica, stato dei workflow, checksum e attestazione di provenienza. I
confini del supporto sono in [SUPPORT.md](../../SUPPORT.md).

## Contribuire

Issue e pull request sono benvenute. Le modifiche alla convenzione vanno in una
issue anziché in una pull request contro l'implementazione di riferimento. Vedi
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licenza

MIT.
