#!/usr/bin/env bash
set -euo pipefail

MOODLEDIR="/home/espjovgi/www/"   # <-- cambia se serve
PHP="/usr/local/bin/php"
RUNAS=""

CATID=1  # <-- ID della categoria di destinazione (obbligatorio)

DESTDIR="$(pwd)"   # cartella corrente: qui cerco i .mbz
LOG="$DESTDIR/restore_$(date +%F_%H%M).log"
FAIL="$DESTDIR/restore_failed.txt"
: > "$FAIL"

echo "Cartella backup: $DESTDIR" | tee -a "$LOG"
echo "Ripristino nella categoria ID: $CATID" | tee -a "$LOG"

shopt -s nullglob
files=( "$DESTDIR"/*.mbz )

if [ ${#files[@]} -eq 0 ]; then
  echo "Nessun .mbz trovato in $DESTDIR" | tee -a "$LOG"
  exit 1
fi

for f in "${files[@]}"; do
  echo "==> Restore: $(basename "$f")" | tee -a "$LOG"
  "$PHP" "$MOODLEDIR/admin/cli/restore_backup.php" \
    --file="$f" --categoryid="$CATID" >>"$LOG" 2>&1 \
    || echo "$f" >> "$FAIL"
done

echo "Fatto. Eventuali falliti in: $FAIL" | tee -a "$LOG"
