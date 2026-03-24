#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME --category-id ID [options]

Description:
  Ripristina in massa tutti i file .mbz presenti in una directory,
  creando i corsi nella categoria Moodle indicata.

Options:
  -c, --category-id ID     ID della categoria Moodle di destinazione (obbligatorio)
  -d, --source-dir DIR     Directory contenente i file .mbz (default: directory corrente)
  -m, --moodle-dir DIR     Directory radice di Moodle
                           (default: /home/espjovgi/www)
  -p, --php PATH           Binario PHP da usare (default: /usr/local/bin/php)
  -u, --run-as USER        Esegue il comando come utente specifico via sudo -u
  -l, --log-dir DIR        Directory per log e file dei fallimenti
                           (default: source-dir)
  -n, --dry-run            Mostra i comandi senza eseguirli
  -h, --help               Mostra questo help

Examples:
  $SCRIPT_NAME --category-id 12
  $SCRIPT_NAME -c 12 -d /backup/moodle -m /var/www/moodle -u www-data
USAGE
}

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$LOG"
}

die() {
  local msg="$1"
  printf 'ERROR: %s\n' "$msg" >&2
  exit 1
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

run_cmd() {
  if [[ -n "$RUNAS" ]]; then
    sudo -u "$RUNAS" -- "$@"
  else
    "$@"
  fi
}

MOODLEDIR="/home/espjovgi/www"
PHP_BIN="/usr/local/bin/php"
RUNAS=""
CATEGORY_ID=""
SOURCE_DIR="$(pwd)"
LOG_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--category-id)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      CATEGORY_ID="$2"
      shift 2
      ;;
    -d|--source-dir)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      SOURCE_DIR="$2"
      shift 2
      ;;
    -m|--moodle-dir)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      MOODLEDIR="$2"
      shift 2
      ;;
    -p|--php)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      PHP_BIN="$2"
      shift 2
      ;;
    -u|--run-as)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      RUNAS="$2"
      shift 2
      ;;
    -l|--log-dir)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      LOG_DIR="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$CATEGORY_ID" ]] || die "--category-id is required"
is_integer "$CATEGORY_ID" || die "Category ID must be an integer"
[[ -d "$SOURCE_DIR" ]] || die "Source directory not found: $SOURCE_DIR"
[[ -d "$MOODLEDIR" ]] || die "Moodle directory not found: $MOODLEDIR"
[[ -x "$PHP_BIN" ]] || die "PHP binary not executable: $PHP_BIN"
[[ -f "$MOODLEDIR/admin/cli/restore_backup.php" ]] || die "Moodle restore CLI script not found"

LOG_DIR="${LOG_DIR:-$SOURCE_DIR}"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +%F_%H%M%S)"
LOG="$LOG_DIR/restore_${TIMESTAMP}.log"
FAIL="$LOG_DIR/restore_failed_${TIMESTAMP}.txt"
: > "$FAIL"
: > "$LOG"

if [[ -n "$RUNAS" ]] && ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required when --run-as is used"
fi

shopt -s nullglob
files=( "$SOURCE_DIR"/*.mbz )
shopt -u nullglob

(( ${#files[@]} > 0 )) || die "No .mbz files found in $SOURCE_DIR"

log "Bulk restore started"
log "Source directory: $SOURCE_DIR"
log "Category ID: $CATEGORY_ID"
log "Moodle dir: $MOODLEDIR"
log "PHP bin: $PHP_BIN"
[[ -n "$RUNAS" ]] && log "Run as user: $RUNAS"
(( DRY_RUN == 1 )) && log "Dry-run mode enabled"
log "Files found: ${#files[@]}"

success=0
failed=0

for file in "${files[@]}"; do
  cmd=( "$PHP_BIN" "$MOODLEDIR/admin/cli/restore_backup.php" --file="$file" --categoryid="$CATEGORY_ID" )
  log "Restoring: $(basename "$file")"

  if (( DRY_RUN == 1 )); then
    printf 'DRY-RUN: ' | tee -a "$LOG"
    printf '%q ' "${cmd[@]}" | tee -a "$LOG"
    printf '\n' | tee -a "$LOG"
    ((success+=1))
    continue
  fi

  if run_cmd "${cmd[@]}" >>"$LOG" 2>&1; then
    log "OK: $(basename "$file")"
    ((success+=1))
  else
    log "FAILED: $(basename "$file")"
    printf '%s\n' "$file" >> "$FAIL"
    ((failed+=1))
  fi
done

log "Completed. Success: $success | Failed: $failed"
if (( failed > 0 )); then
  log "Failed items saved in: $FAIL"
else
  rm -f "$FAIL"
  log "No failures detected"
fi
