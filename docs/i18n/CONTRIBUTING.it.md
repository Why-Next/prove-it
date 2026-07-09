# Contribuire

## Dove va una modifica

Questo repository contiene due cose di peso diverso.

[SPEC.md](../../SPEC.md) descrive una convenzione che altri strumenti dovrebbero
poter implementare senza leggere una riga di questo codice. Le modifiche a essa
iniziano come una issue, così che la discussione avvenga prima che qualcuno
scriva una patch. Una pull request che allarga di nascosto il contratto è più
difficile da contestare di una proposta che dice apertamente cosa vuole cambiare.

`hooks/prove-it.sh` è un'implementazione di quella convenzione, settanta e passa
righe, e le pull request contro di esso non richiedono cerimonie.

Se non sei sicuro di quale dei due stai toccando, apri una issue e chiedi.

## Il gate vale anche per te

Questo repository ha un `verify.sh`. Eseguilo prima di aprire una pull request:

```bash
./verify.sh
```

Controlla la sintassi shell, esegue shellcheck, convalida i manifesti del plugin,
applica le regole di prosa qui sotto, tiene le traduzioni fedeli agli originali
inglesi, ed esegue la suite di test del gate contro repository git reali in una
directory temporanea. La CI esegue lo stesso script su Linux e macOS, più un job
separato che dimostra che il gate blocca ancora un repository i cui controlli
falliscono.

Se `verify.sh` fallisce, correggi la causa. Non indebolire `verify.sh`. È
l'unica modifica che questo progetto non accetterà in merge, per la ragione
stessa per cui il progetto esiste.

## Aggiungere un controllo

Un nuovo controllo è benvenuto quando avrebbe intercettato un bug reale. Rompi
qualcosa di proposito, osserva il tuo controllo accorgersene, poi correggilo e
committa entrambi. Un controllo che nessuno ha visto fallire non è un controllo.

Due degli script sotto `scripts/` esistono perché le loro prime versioni
passavano contro un codice che era già rotto.

## Traduzioni

`README.md` e `SPEC.md` sono canonici, e il testo inglese di `SPEC.md` prevale
dove una traduzione lo contraddice. `scripts/check_i18n.py` tiene ogni traduzione
fedele al suo originale: il conteggio dei titoli, se i titoli sono stati tradotti,
se gli accenti sono sopravvissuti, se i blocchi di codice sono identici byte per
byte all'inglese, e se i link relativi si risolvono.

Due regole mettono in difficoltà le persone.

Non usare mai un trattino lungo. Niente trattino em, trattino en, barra
orizzontale o segno meno. Solo il trattino ASCII semplice, in ogni lingua,
comprese quelle la cui tipografia preferirebbe altro, perché un trattino lungo si
legge come testo scritto da una macchina. (Questo paragrafo nomina i caratteri
anziché mostrarli, dato che anche `scripts/check_no_long_dash.py` legge questo
file.)

Mantieni sempre gli accenti. La regola sul trattino riguarda sei caratteri
specifici e non è un divieto sul non-ASCII. `décidé` resta `décidé`, e `è` non
diventa mai `e'`. Una traduzione iniziale ha eliminato ogni accento nel file
applicando in eccesso la prima regola.

## Ricette

Una ricetta è un punto di partenza per uno stack, non un `verify.sh` finito.
Tienila sotto il minuto di runtime, preferisci i controlli che producono prove a
quelli che producono opinioni, e annota quale dei quattro tipi di prova della
specifica fornisce ogni controllo.

## Commit

Conventional commit (`feat:`, `fix:`, `docs:`, `chore:`). Indica nel corpo cosa è
cambiato e perché. Se hai corretto un bug, indica come lo hai riprodotto.
