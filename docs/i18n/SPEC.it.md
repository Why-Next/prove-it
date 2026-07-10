# La convenzione `verify.sh`

> Questo testo inglese di [SPEC.md](../../SPEC.md) è la versione normativa. Esistono traduzioni in
> [中文](SPEC.zh.md) ·
> [Deutsch](SPEC.de.md) ·
> [日本語](SPEC.ja.md) ·
> [हिन्दी](SPEC.hi.md) ·
> [Français](SPEC.fr.md) ·
> Italiano ·
> [Português](SPEC.pt.md) ·
> [Русский](SPEC.ru.md) ·
> [Español](SPEC.es.md) ·
> [한국어](SPEC.ko.md).
> Sono informative. Dove una traduzione e questo testo divergono, questo testo
> prevale e la traduzione è un bug da segnalare.

Versione 0.1 (bozza). Un repository dichiara come si dimostra, e un agente non
può dichiarare il completamento finché quella prova non passa.

Questo documento è il contratto. Lo script in `hooks/` è una sua implementazione,
e volutamente piccola. Leggi la sezione 5 sui livelli di conformità prima di
dare per scontato che lo strumento imponga tutto ciò che è scritto qui.

## 1. Il problema

Gli agenti di codice terminano i turni con frasi come queste:

- "I test passano." I test non sono mai stati eseguiti.
- "Bug corretto." Il bug non è mai stato riprodotto.
- "La migrazione è sicura." Nulla è stato applicato a un database di prova.

Non sono bugie nel senso comune. Un agente non riesce a distinguere ciò che ha
fatto da ciò che intendeva fare, quindi il suo resoconto descrive l'intenzione.
Il fallimento è strutturale, e il prompting non lo eliminerà. Anche la tecnica
di prompt invecchia a ogni generazione di modello, mentre una richiesta di prove
sta un livello sopra il modello e sopravvive all'aggiornamento.

Così "fatto" smette di essere qualcosa che un agente dichiara e diventa un
controllo che deve superare.

## 2. La convenzione

Un repository conforme ha un file eseguibile `verify.sh` alla sua radice.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

Il contratto:

| | |
|---|---|
| Posizione | radice del repository |
| Modalità | eseguibile (`chmod +x`) |
| Invocazione | eseguito con CWD alla radice del repository, senza argomenti |
| Uscita `0` | verifica superata |
| Uscita diversa da `0` | verifica fallita; stdout e stderr spiegano perché |
| Output | leggibile da un umano; le ultime 20 righe sono ciò che vede un agente |
| Runtime | sotto il minuto; i controlli lenti stanno in CI |
| Assente | nessun gate. L'assenza è uno stato valido, non un fallimento |

`verify.sh` risponde a una domanda: cosa dovrebbe essere vero perché una modifica
qui sia dimostrabilmente sicura da restituire? Ogni repository risponde in modo
diverso, ed è per questo che questa convenzione nomina il file e non il suo
contenuto.

Rinunciare richiede un'azione sola: cancellare `verify.sh`, o ridurlo a
`exit 0`. È intenzionale. Le persone aggirano un gate che non possono rimuovere,
e un gate aggirato segnala comunque successo.

## 3. I quattro tipi di prova

Un `verify.sh` dovrebbe verificarsi contro prove anziché convinzioni. Quattro
tipi hanno peso. Un `verify.sh` utile ne copre almeno uno, e uno maturo li copre
tutti e quattro attraverso i controlli che esegue.

**Output del comando.** Un comando è stato eseguito e il controllo ne ha letto il
codice di uscita. Non "i test dovrebbero passare" ma il verdetto stesso
dell'esecutore dei test.

**Diff.** La modifica è ciò che era previsto e nulla di più: nessuna istruzione
di debug, nessun file vagante, nessun rimescolamento di formattazione estraneo.
`git diff --check` è il minimo.

**Riproduzione.** Per una correzione di bug, il fallimento è stato osservato prima
della modifica ed è assente dopo. Una correzione mai riprodotta è un'ipotesi su
quale riga fosse sbagliata.

**Controllo incrociato.** Una seconda fonte indipendente concorda. Un altro
modello, un altro strumento, un controllore di tipi contro una suite di test.
L'indipendenza è ciò che gli dà valore; due controlli che condividono un
presupposto confermano il presupposto anziché il codice.

Le quattro categorie esistono perché "l'ho verificato" debba nominare un metodo.
Un agente che non sa dire quale dei quattro tipi di prova possiede non ne possiede
nessuno.

## 4. Cosa devono fare le implementazioni

Un'implementazione di questa convenzione è un gate. Per essere conforme deve:

1. Eseguire `verify.sh` dalla radice del repository prima che il turno
   dell'agente possa terminare.
2. Bloccare il turno su un'uscita diversa da zero, e mostrare l'output.
3. Non fare nulla quando `verify.sh` non esiste come eseguibile al momento in cui
   il gate viene eseguito e non esisteva come eseguibile all'inizio della sessione.
4. Non fare nulla quando la sessione non ha modificato quel repository.
5. Fornire un bypass esplicito e ispezionabile con grep. Un bypass silenzioso
   insegna alle persone a diffidare del gate; uno tracciato lo mantiene onesto.
6. Non terminare mai un turno in silenzio dopo una verifica fallita.
   Un'implementazione che smette di bloccare, per qualsiasi motivo, deve dirlo
   dove l'utente lo vedrà.

Il punto 4 chiede cosa è cambiato, non chi lo ha cambiato. Un'implementazione che
decide osservando quali strumenti di modifica l'agente ha chiamato mancherà un
file riscritto da `sed`, una patch applicata con `git apply`, l'output di un
generatore di codice e un commit. Committare è la cosa più ordinaria che un
agente faccia, e un gate che tratta un albero di lavoro pulito come nulla da
dimostrare lascerà passare proprio i turni che esiste per intercettare. Confronta
il repository con com'era quando la sessione è iniziata.

Il punto 3 usa deliberatamente entrambi i momenti. Lo stop corrente conta perché
un comando di installazione possa creare `verify.sh` e armare il repository nella
stessa sessione. Lo stato iniziale conta perché una cancellazione o un `chmod -x`
a metà sessione sia trattato come disarmo del gate, non come opt-out onesto.

Il punto 6 esiste perché un gate che può bloccare per sempre blocca la sessione,
e ogni host prima o poi lo costringe a cedere. Questo va bene. Ciò che non va bene
è cedere in un modo indistinguibile dal passare.

Non deve modificare `verify.sh`, e deve dire all'agente che indebolire
`verify.sh` per superare il gate è una violazione anziché una correzione. Questa
è la modalità di fallimento più probabile nella pratica. Un agente che non riesce
a superare un controllo, se ne ha l'occasione, modificherà il controllo.

La forma più grossolana di ciò è rimuovere il controllo. Un'implementazione
dovrebbe registrare se `verify.sh` era presente ed eseguibile quando la sessione
è iniziata, e rifiutare un turno che finisce con il file cancellato o disarmato.
Cancellare il file tra una sessione e l'altra è la rinuncia della sezione 2 e
deve continuare a funzionare. Cancellarlo nel mezzo della sessione che stava per
bloccare non è una rinuncia, e la differenza tra le due è visibile solo a
un'implementazione che ha guardato prima.

La forma più sottile tiene `verify.sh` eseguibile e ne riscrive i controlli.
Questo non può essere rifiutato senza rifiutare anche il lavoro legittimo sul
gate, quindi un'implementazione dovrebbe registrare cosa conteneva `verify.sh`
quando la sessione è iniziata, e quando un turno passa attraverso un `verify.sh`
cambiato durante la sessione, dirlo dove l'utente lo vedrà. Il passaggio resta
valido; il silenzio no.

## 5. Livelli di conformità

Sii preciso su cosa impone una macchina e cosa mette in pratica una persona.
Questa distinzione conta più dell'ambizione dietro la convenzione.

**Level 1, il gate.** `verify.sh` esiste, e qualcosa rifiuta meccanicamente di
lasciar terminare un turno mentre fallisce. L'implementazione di riferimento in
`hooks/` lo impone per intero, ed è da qui che ogni repository dovrebbe partire.
"Rifiuta" ha un budget: rimanda il turno indietro un numero limitato di volte e
poi cede con un avviso, perché l'host non lascerà che un hook blocchi per sempre.

**Level 2, la prova.** I controlli dentro `verify.sh` coprono i quattro tipi di
prova della sezione 3. Nessuno strumento lo impone, questo incluso. Il gate
verifica che il tuo `verify.sh` abbia restituito zero. Se quello zero significhi
qualcosa è un'affermazione sui controlli che hai scritto, e un `verify.sh` che
contiene solo `exit 0` raggiunge il Level 1 senza dimostrare nulla.

**Level 3, il ledger.** Ogni falso completamento intercettato viene registrato,
così che le modalità di fallimento diventino dati anziché aneddoti.
L'implementazione di riferimento lo scrive solo quando è abilitato
esplicitamente.

Il Level 1 è una proprietà di uno strumento. Il Level 2 è una proprietà delle
abitudini di un team, e qualsiasi strumento che dichiari di fornirlo sta fornendo
il Level 1 e sperando che nessuno legga il sorgente.

## 6. Il formato del ledger

Quando è abilitato, ogni falso completamento intercettato aggiunge un oggetto
JSON per riga:

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

`claim` contiene l'ultimo messaggio dell'agente prima che provasse a fermarsi. È
il campo più utile del record e il più sensibile, poiché può contenere qualsiasi
testo della conversazione. Un'implementazione deve scrivere il ledger su disco
locale con permessi restrittivi e non deve mai trasmetterlo.

Una riga contiene tre cose: cosa è stato affermato, cosa è stato richiesto e cosa
era vero.

## 7. Non-obiettivi

Questa convenzione non ti dice cosa controllare, non esegue la tua CI, non assegna
un punteggio al tuo codice e non sostituisce la revisione. Risponde a una sola
domanda: se questo repository si è dimostrato prima che l'agente se ne andasse.

---

*Le proposte per modificare questo documento vanno in una issue anziché in una
pull request contro l'implementazione di riferimento. Ogni aggiunta qui è
qualcosa che ogni futura implementazione dovrà portarsi dietro.*
