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
lo script, e un'uscita diversa da zero tiene aperto il turno finché la causa non
è risolta.

![prove-it blocca un agente che dichiara di aver finito](../../docs/demo.svg)

Nel mio uso, poco meno della metà dei turni che incontrano un gate fallito
tornano con l'agente che ammette di non aver finito. Quei turni sarebbero
altrimenti finiti con la parola "fatto".

## Installazione

Tre righe, e la terza fa il lavoro:

```
/plugin marketplace add WhyNext/prove-it
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
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Unisci [`hooks/settings.example.json`](../../hooks/settings.example.json) al tuo
`.claude/settings.json` per un singolo repository, oppure a
`~/.claude/settings.json` per tutti. Il gate legge un payload JSON dello Stop
hook su stdin e risponde con un codice di uscita, quindi qualsiasi cosa possa
eseguire uno script a fine turno può pilotarlo.

`prove-it doctor` risponde se il gate scatterebbe nel repository in cui ti trovi,
e ti dice cosa lo blocca se non lo farebbe:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty, so the gate would run on the next stop
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

- questa sessione ha modificato file in questo repository
- esiste un `verify.sh` eseguibile alla radice del repository
- l'albero di lavoro ha modifiche non ancora committate
- questo stato esatto dell'albero non è già passato

L'ultima condizione fa sì che un albero che passa venga verificato una volta sola
invece che a ogni stop. Quando la verifica fallisce, l'agente vede le ultime
venti righe dell'output, di solito abbastanza per correggere la causa senza che
gli venga detto cosa è andato storto.

`PROVE_IT_SKIP=1` supera il gate di proposito. Cancellare `verify.sh` lo
disattiva del tutto. Entrambe le vie di fuga sono volute: le persone aggirano un
gate che non possono rimuovere.

## Quando l'agente modifica il gate

La modalità di fallimento più difficile non è un controllo instabile. È un agente
che non riesce a far passare `verify.sh` e allora modifica `verify.sh`. Il
messaggio di errore gli dice di non farlo, e [SPEC.md](../../SPEC.md) lo
definisce una violazione anziché una correzione, ma nessuna delle due cose è
un'imposizione. Leggi i tuoi diff. È a questo che serve la prova per diff nella
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
viene lasciata in pace, un albero pulito viene saltato, il bypass funziona.

```bash
./verify.sh
```

La CI esegue lo stesso script su Linux e macOS, più un job separato che dimostra
che il gate blocca ancora un repository i cui controlli falliscono.

## Contribuire

Issue e pull request sono benvenute. Le modifiche alla convenzione vanno in una
issue anziché in una pull request contro l'implementazione di riferimento. Vedi
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licenza

MIT.
