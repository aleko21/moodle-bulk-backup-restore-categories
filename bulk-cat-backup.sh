#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Description:
  Esegue il backup massivo di corsi Moodle tramite admin/cli/backup.php.
  Se non vengono specificati corsi via argomenti o file, usa l'elenco
  predefinito incorporato nello script.

Options:
  -d, --destination DIR    Directory di destinazione dei backup (default: directory corrente)
  -m, --moodle-dir DIR     Directory radice di Moodle
                           (default: /home/whlyiult/www)
  -p, --php PATH           Binario PHP da usare (default: /usr/local/bin/php)
  -u, --run-as USER        Esegue il comando come utente specifico via sudo -u
  -i, --course-id ID       ID corso da includere (ripetibile)
      --course-ids LIST    Elenco separato da virgole, es. 12,34,56
  -f, --course-file FILE   File di testo con un ID corso per riga
  -l, --log-dir DIR        Directory per log e file dei fallimenti
                           (default: destination)
      --skip-existing      Salta il backup se esiste già un .mbz compatibile col courseid
  -n, --dry-run            Mostra i comandi senza eseguirli
  -h, --help               Mostra questo help

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME -d /backup/moodle --course-ids 12,34,56
  $SCRIPT_NAME -f courseids.txt -m /var/www/moodle -u www-data
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

append_course_id() {
  local id="$1"
  is_integer "$id" || die "Invalid course ID: $id"
  COURSEIDS+=( "$id" )
}

MOODLEDIR="/home/whlyiult/www"
PHP_BIN="/usr/local/bin/php"
RUNAS=""
DESTINATION="$(pwd)"
LOG_DIR=""
DRY_RUN=0
SKIP_EXISTING=0
COURSE_FILE=""
COURSEIDS=()

DEFAULT_COURSEIDS=(
  575 578 580 581 583 586 588 592 596 603 608 613 616 618 621 625 632
  635 641 644 646 650 653 654 655 656 657 658 659 1809 1812
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--destination)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      DESTINATION="$2"
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
    -i|--course-id)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      append_course_id "$2"
      shift 2
      ;;
    --course-ids)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      IFS=',' read -r -a ids_from_list <<< "$2"
      for id in "${ids_from_list[@]}"; do
        id="${id//[[:space:]]/}"
        [[ -n "$id" ]] && append_course_id "$id"
      done
      shift 2
      ;;
    -f|--course-file)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      COURSE_FILE="$2"
      shift 2
      ;;
    -l|--log-dir)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      LOG_DIR="$2"
      shift 2
      ;;
    --skip-existing)
      SKIP_EXISTING=1
      shift
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

if [[ -n "$COURSE_FILE" ]]; then
  [[ -f "$COURSE_FILE" ]] || die "Course file not found: $COURSE_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    append_course_id "$line"
  done < "$COURSE_FILE"
fi

if (( ${#COURSEIDS[@]} == 0 )); then
  COURSEIDS=( "${DEFAULT_COURSEIDS[@]}" )
fi

[[ -d "$MOODLEDIR" ]] || die "Moodle directory not found: $MOODLEDIR"
[[ -x "$PHP_BIN" ]] || die "PHP binary not executable: $PHP_BIN"
[[ -f "$MOODLEDIR/admin/cli/backup.php" ]] || die "Moodle backup CLI script not found"
mkdir -p "$DESTINATION"
LOG_DIR="${LOG_DIR:-$DESTINATION}"
mkdir -p "$LOG_DIR"

if [[ -n "$RUNAS" ]] && ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required when --run-as is used"
fi

TIMESTAMP="$(date +%F_%H%M%S)"
LOG="$LOG_DIR/backup_${TIMESTAMP}.log"
FAIL="$LOG_DIR/backup_failed_${TIMESTAMP}.txt"
: > "$LOG"
: > "$FAIL"

log "Bulk backup started"
log "Destination: $DESTINATION"
log "Moodle dir: $MOODLEDIR"
log "PHP bin: $PHP_BIN"
[[ -n "$RUNAS" ]] && log "Run as user: $RUNAS"
(( DRY_RUN == 1 )) && log "Dry-run mode enabled"
(( SKIP_EXISTING == 1 )) && log "Skip-existing enabled"
log "Courses to process: ${#COURSEIDS[@]}"

success=0
failed=0
skipped=0

for id in "${COURSEIDS[@]}"; do
  log "Processing course ID: $id"

  if (( SKIP_EXISTING == 1 )); then
    shopt -s nullglob
    existing=( "$DESTINATION"/*-"$id"-*.mbz "$DESTINATION"/*course-"$id"*.mbz "$DESTINATION"/*"$id"*.mbz )
    shopt -u nullglob
    if (( ${#existing[@]} > 0 )); then
      log "SKIPPED: course $id (existing backup found)"
      ((skipped+=1))
      continue
    fi
  fi

  cmd=( "$PHP_BIN" "$MOODLEDIR/admin/cli/backup.php" --courseid="$id" --destination="$DESTINATION" )

  if (( DRY_RUN == 1 )); then
    printf 'DRY-RUN: ' | tee -a "$LOG"
    printf '%q ' "${cmd[@]}" | tee -a "$LOG"
    printf '\n' | tee -a "$LOG"
    ((success+=1))
    continue
  fi

  if run_cmd "${cmd[@]}" >>"$LOG" 2>&1; then
    log "OK: course $id"
    ((success+=1))
  else
    log "FAILED: course $id"
    printf '%s\n' "$id" >> "$FAIL"
    ((failed+=1))
  fi
done

log "Completed. Success: $success | Failed: $failed | Skipped: $skipped"
if (( failed > 0 )); then
  log "Failed course IDs saved in: $FAIL"
else
  rm -f "$FAIL"
  log "No failures detected"
fi
