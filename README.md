# Moodle Bulk Backup & Restore Scripts

Script Bash per automatizzare il backup e il ripristino massivo di corsi Moodle tramite le utility CLI native della piattaforma.

Il repository include due strumenti:

- `bulk-cat-backup.sh`: esegue il backup di più corsi Moodle in una directory locale.
- `bulk-restore.sh`: ripristina tutti i file `.mbz` presenti in una directory dentro una categoria Moodle specifica.

## Obiettivo

Questi script nascono per semplificare operazioni amministrative ripetitive su Moodle, riducendo il lavoro manuale e introducendo controlli, logging e gestione errori più robusti rispetto a una versione minimale.

## Requisiti

- Linux o ambiente Unix-like
- Bash 4+
- PHP CLI installato
- Un'installazione Moodle accessibile sul filesystem
- Permessi adeguati per eseguire:
  - `admin/cli/backup.php`
  - `admin/cli/restore_backup.php`
- `sudo`, solo se si usa l'opzione `--run-as`

## File inclusi

### `bulk-cat-backup.sh`

Esegue backup multipli di corsi Moodle tramite `admin/cli/backup.php`.

Funzionalità principali:

- supporto a elenco corsi incorporato nello script
- supporto a corsi passati da riga di comando
- supporto a file esterno con un ID corso per riga
- logging dettagliato con timestamp
- file separato con gli ID falliti
- modalità `dry-run`
- opzione `--skip-existing` per evitare backup duplicati
- supporto reale a `--run-as` tramite `sudo -u`

### `bulk-restore.sh`

Ripristina tutti i backup `.mbz` trovati in una cartella, creando i corsi in una categoria Moodle specificata.

Funzionalità principali:

- scansione automatica dei file `.mbz`
- validazione dei percorsi e dei parametri obbligatori
- logging dettagliato con timestamp
- file separato con l'elenco dei restore falliti
- modalità `dry-run`
- supporto reale a `--run-as` tramite `sudo -u`

## Analisi tecnica degli script originali

Le versioni di partenza erano funzionali ma essenziali. In particolare:

- i percorsi di Moodle e PHP erano hardcoded
- `RUNAS` era dichiarata ma non utilizzata
- mancavano help e parametri da riga di comando
- non erano presenti validazioni preliminari su directory, binari e script Moodle
- il logging era minimo
- non c'era distinzione chiara tra successi, fallimenti e file saltati
- la gestione degli errori era limitata al solo exit code finale

Le versioni corrette introdotte in questo repository risolvono questi punti mantenendo una struttura semplice e leggibile.

## Installazione

Clona il repository e rendi eseguibili gli script:

```bash
git clone <repository-url>
cd <repository-folder>
chmod +x bulk-cat-backup.sh bulk-restore.sh
```

## Utilizzo

## 1. Backup massivo corsi

### Uso base

Se non passi corsi specifici, lo script usa l'elenco predefinito incluso nel file.

```bash
./bulk-cat-backup.sh
```

### Specificare una cartella di destinazione

```bash
./bulk-cat-backup.sh --destination /var/backups/moodle
```

### Passare corsi da riga di comando

```bash
./bulk-cat-backup.sh --course-id 12 --course-id 34 --course-id 56
```

Oppure:

```bash
./bulk-cat-backup.sh --course-ids 12,34,56
```

### Leggere gli ID da file

Esempio di `courseids.txt`:

```text
12
34
56
# commento
78
```

Esecuzione:

```bash
./bulk-cat-backup.sh --course-file courseids.txt
```

### Eseguire come utente web server

```bash
./bulk-cat-backup.sh --run-as www-data --moodle-dir /var/www/html/moodle
```

### Saltare backup già presenti

```bash
./bulk-cat-backup.sh --destination /var/backups/moodle --skip-existing
```

### Simulazione senza esecuzione

```bash
./bulk-cat-backup.sh --course-ids 12,34,56 --dry-run
```

## 2. Restore massivo da file `.mbz`

### Uso base

```bash
./bulk-restore.sh --category-id 15
```

Lo script cercherà tutti i file `.mbz` nella directory corrente e li ripristinerà nella categoria Moodle con ID `15`.

### Specificare directory sorgente

```bash
./bulk-restore.sh --category-id 15 --source-dir /var/backups/moodle
```

### Eseguire come utente web server

```bash
./bulk-restore.sh --category-id 15 --run-as www-data --moodle-dir /var/www/html/moodle
```

### Simulazione senza esecuzione

```bash
./bulk-restore.sh --category-id 15 --source-dir /var/backups/moodle --dry-run
```

## Opzioni complete

### `bulk-cat-backup.sh`

```text
-d, --destination DIR    Directory di destinazione dei backup
-m, --moodle-dir DIR     Directory radice di Moodle
-p, --php PATH           Binario PHP
-u, --run-as USER        Esecuzione via sudo -u USER
-i, --course-id ID       ID corso, opzione ripetibile
    --course-ids LIST    Elenco separato da virgole
-f, --course-file FILE   File con un ID per riga
-l, --log-dir DIR        Directory dei log
    --skip-existing      Salta i backup già presenti
-n, --dry-run            Simula l'esecuzione
-h, --help               Mostra help
```

### `bulk-restore.sh`

```text
-c, --category-id ID     ID categoria Moodle di destinazione
-d, --source-dir DIR     Directory che contiene i file .mbz
-m, --moodle-dir DIR     Directory radice di Moodle
-p, --php PATH           Binario PHP
-u, --run-as USER        Esecuzione via sudo -u USER
-l, --log-dir DIR        Directory dei log
-n, --dry-run            Simula l'esecuzione
-h, --help               Mostra help
```

## Output e log

Entrambi gli script producono:

- un file di log con timestamp
- un file separato con i soli elementi falliti

Esempi:

```text
backup_2026-03-24_130501.log
backup_failed_2026-03-24_130501.txt
restore_2026-03-24_130744.log
restore_failed_2026-03-24_130744.txt
```

## Note operative

### Backup

Lo script richiama direttamente il comando CLI ufficiale di Moodle:

```bash
php /path/to/moodle/admin/cli/backup.php --courseid=123 --destination=/backup/path
```

Questo significa che il naming finale dei file `.mbz` dipende da Moodle, non dallo script.

### Restore

Lo script richiama:

```bash
php /path/to/moodle/admin/cli/restore_backup.php --file=/path/backup.mbz --categoryid=15
```

Il comportamento finale del ripristino dipende dalle regole e dai controlli interni di Moodle, inclusi permessi, stato del backup e validità del file `.mbz`.

## Limiti attuali

Pur essendo più solide delle versioni iniziali, queste utility hanno ancora alcuni limiti intenzionali:

- non gestiscono l'esecuzione concorrente o in parallelo
- non implementano retry automatici
- non validano in anticipo il contenuto interno dei file `.mbz`
- non producono report JSON o CSV
- `--skip-existing` usa pattern filename-based, quindi è pratico ma non infallibile al 100%
- non inviano notifiche email o webhook a fine processo
- non gestiscono rotazione o retention automatica dei log

## Miglioramenti possibili

Estensioni utili per una futura evoluzione del repository:

- file di configurazione `.env` o `.conf`
- supporto a notifiche email o Slack
- esportazione report in CSV/JSON
- verifica preventiva dello spazio disco disponibile
- esecuzione parallela controllata
- mapping avanzato tra course ID e nome atteso del file di backup
- integrazione con `shellcheck` e pipeline CI

## Buone pratiche consigliate

- eseguire sempre prima un `--dry-run`
- usare `--run-as` con l'utente corretto del web server quando necessario
- verificare che il cron e il filesystem Moodle siano in stato coerente
- testare restore e backup prima su ambiente di staging
- conservare i file di log insieme agli output dei processi

## Sicurezza

Gli script non trasmettono dati in rete e operano solo localmente, ma devono essere eseguiti con attenzione perché agiscono su un'istanza Moodle reale.

Si raccomanda di:

- limitare i permessi di esecuzione agli amministratori
- non eseguire gli script con privilegi eccessivi se non necessario
- proteggere la directory dei backup e dei log
- verificare che i file `.mbz` provengano da fonti affidabili

## Licenza

Aggiungi qui la licenza che preferisci per il repository, ad esempio MIT.

```text
MIT License
```

## Disclaimer

Questi script sono wrapper operativi intorno alle utility CLI di Moodle. Il corretto funzionamento dipende dalla configurazione locale della piattaforma, dai permessi filesystem e dalla compatibilità dei backup trattati.
