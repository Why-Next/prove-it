# Sicurezza

## Cosa fa questo software sulla tua macchina

`prove-it` esegue uno script che vive nel repository che hai aperto. Se apri un
repository di cui non ti fidi, e il suo `verify.sh` è eseguibile, il tuo agente
che termina un turno eseguirà quel file.

Questo comportamento è il progetto, non un suo difetto, e il rischio è lo stesso
che accetti già quando esegui `npm install` o apri un progetto con un `Makefile`.
Leggi un `verify.sh` sconosciuto prima di lasciare che un agente lavori nel
repository che lo contiene, come leggeresti uno script `postinstall` sconosciuto.

Il gate viene eseguito solo quando la sessione ha modificato file **in quello
stesso repository**, l'albero di lavoro è sporco, e un `verify.sh` eseguibile
esiste alla radice del repo. Clonare e leggere un repository non lo attiva mai, e
modificare un repository non provoca mai l'esecuzione del `verify.sh` di un altro
repository.

## Cosa scrive su disco

Due marcatori, entrambi in una directory privata creata con modalità `0700`:
`$XDG_STATE_HOME/prove-it/`, oppure `~/.local/state/prove-it/` quando non è
impostata. Puoi ridefinirla con `PROVE_IT_STATE_DIR`. Nulla viene scritto nella
`/tmp` condivisa, perché questi nomi di file derivano dal percorso del repository
e sono quindi prevedibili, e un nome prevedibile in una directory scrivibile da
chiunque è un bersaglio per symlink.

Il ledger opzionale (`PROVE_IT_LEDGER=1`, **disattivato per impostazione
predefinita**) aggiunge una riga JSON per ogni falso completamento intercettato a
`~/.prove-it/ledger.jsonl`, creato con modalità `0600` dentro una directory
`0700`. Ogni riga contiene:

- l'ultimo messaggio dell'agente prima che provasse a fermarsi, troncato a 300
  caratteri e tratto dal tuo transcript locale, quindi può contenere qualsiasi
  cosa fosse nella tua conversazione
- il percorso assoluto del repository
- il codice di uscita e le ultime cinque righe dell'output del tuo `verify.sh`
- un timestamp

Trattalo come dati di conversazione. Niente in questo progetto lo rilegge o lo
invia da qualche parte, ma resta un file ordinario, quindi i tuoi backup lo
copieranno e chiunque abbia accesso in lettura alla tua home directory può
aprirlo.

## Cosa invia

Niente. Il software che gira sulla tua macchina non contiene telemetria, nessuna
chiamata di rete e nessun controllo degli aggiornamenti. Puoi confermarlo con un
solo grep di `curl`, `wget`, `urllib`, `requests` o `socket` in `hooks/` e
`scripts/`.

L'integrazione continua è l'unica eccezione, e non è codice che esegui tu: il
workflow GitHub Actions installa `shellcheck` da `apt` o `brew` prima di eseguire
lo stesso `verify.sh` che eseguiresti in locale.

## Segnalare una vulnerabilità

Scrivi a **hello@whynext.app** con i dettagli e una riproduzione. Per favore non
aprire una issue pubblica per qualcosa che permetta a un repository di uscire dai
confini descritti sopra.

Aspettati un riscontro entro qualche giorno. Lo mantiene una persona sola, quindi
la pazienza aiuta, e così la riproduzione. Una segnalazione che non riesco a
riprodurre è una che non riesco a correggere.

## Versioni supportate

L'ultima release. Questo progetto è abbastanza piccolo che il backport non è un
servizio da cui qualcuno trarrebbe beneficio.
