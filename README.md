# Moodle Bulk Backup and Restore Utilities

Repository con script CLI per eseguire backup e restore massivi di corsi Moodle.

## File inclusi

- `bulk-cat-backup.sh`  
  Esegue backup massivi di corsi Moodle tramite `admin/cli/backup.php`.

- `bulk-restore.sh`  
  Esegue restore massivi di file `.mbz` presenti in una directory, creando i corsi nella categoria Moodle indicata.

- `restore_backup_nousers.php`  
  Script PHP custom da posizionare in `admin/cli/` della tua installazione Moodle. Prova a ripristinare i backup escludendo utenti e dati utente.

## Requisiti

- accesso shell al server
- PHP CLI disponibile
- installazione Moodle raggiungibile da filesystem
- permessi di scrittura su `moodledata/temp/backup`
- privilegi sufficienti per creare corsi nella categoria di destinazione
- `sudo`, solo se usi `--run-as`

## 1. Backup massivo dei corsi

### File
`bulk-cat-backup.sh`

### Funzionalità

- backup di uno o più corsi per ID
- supporto a lista di ID da CLI o da file
- logging con timestamp
- supporto a `--dry-run`
- supporto a `--skip-existing`
- salvataggio degli ID falliti in file dedicato

### Esempi

Backup di corsi specifici:

```bash
./bulk-cat-backup.sh --course-ids 829,1404,1833 --destination /home/espjovgi/www/public/alebackup/29
```

Backup leggendo gli ID da file:

```bash
./bulk-cat-backup.sh --course-file courseids.txt --destination /home/espjovgi/www/public/alebackup/29
```

Solo simulazione:

```bash
./bulk-cat-backup.sh --course-ids 829,1404,1833 --destination /backup --dry-run
```

## 2. Restore massivo senza utenti

### File
`bulk-restore.sh`

### Funzionalità

- legge tutti i file `.mbz` da una directory
- crea un nuovo corso per ogni backup nella categoria indicata
- richiama uno script PHP custom di restore
- supporta `--showdebugging` di default tramite il PHP custom
- salva i backup falliti in file dedicato

### Esempi

```bash
./bulk-restore.sh --category-id 29 --source-dir /home/espjovgi/www/public/alebackup/29
```

Con utente specifico:

```bash
./bulk-restore.sh --category-id 29 --source-dir /backup --run-as www-data
```

Senza debug PHP:

```bash
./bulk-restore.sh --category-id 29 --source-dir /backup --no-debug
```

## 3. Script PHP custom di restore

### File
`restore_backup_nousers.php`

### Dove salvarlo

Copia il file dentro la tua installazione Moodle:

```bash
/home/espjovgi/www/admin/cli/restore_backup_nousers.php
```

Poi rendilo eseguibile:

```bash
chmod +x /home/espjovgi/www/admin/cli/restore_backup_nousers.php
```

### Cosa fa

- estrae il `.mbz` in una directory temporanea sotto `moodledata/temp/backup`
- crea un nuovo corso nella categoria indicata
- costruisce un `restore_controller`
- prova a impostare `users = false`
- prova a disattivare anche altri setting collegati ai dati utente, se presenti
- esegue `execute_precheck()`
- se il precheck passa, esegue `execute_plan()`
- pulisce i file temporanei

### Test singolo consigliato

Prima di lanciare il restore massivo, prova un solo file:

```bash
/usr/local/bin/php /home/espjovgi/www/admin/cli/restore_backup_nousers.php \
  --file="/home/espjovgi/www/public/alebackup/29/backup-moodle2-course-837-gppro-rmsc-20260324-1440.mbz" \
  --categoryid=29 \
  --showdebugging
```

## Flusso consigliato

1. Genera i `.mbz` con `bulk-cat-backup.sh`
2. Copia `restore_backup_nousers.php` in `admin/cli/`
3. Prova un restore singolo
4. Lancia il restore massivo con `bulk-restore.sh`

## Limitazioni note

- lo script PHP custom non usa un flag standard Moodle: è una personalizzazione
- l'esclusione utenti dipende dai setting effettivamente presenti nel piano di restore
- se il restore fallisce ancora, il problema potrebbe essere dovuto a:
  - plugin mancanti sul sito di destinazione
  - differenze di versione Moodle
  - backup corrotti o parziali
  - attività o question bank non compatibili

## Note operative

- `bulk-restore.sh` è pensato per creare nuovi corsi, non per ripristinare dentro corsi esistenti
- per log più leggibili, lascia attivo il debug nelle prime prove
- verifica i path di default prima dell'uso in produzione
