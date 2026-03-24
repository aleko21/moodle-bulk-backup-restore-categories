#!/usr/bin/env bash
set -euo pipefail

MOODLEDIR="/home/whlyiult/www/"   # <-- cambia se serve
PHP="/usr/local/bin/php"
RUNAS=""

DEST="$(pwd)"   # cartella da cui lanci lo script

COURSEIDS=(
575
578
580
581
583
586
588
592
596
603
608
613
616
618
621
625
632
635
641
644
646
650
653
654
655
656
657
658
659
1809
1812
)

echo "Destinazione backup: $DEST"
echo "Avvio backup di ${#COURSEIDS[@]} corsi..."

for id in "${COURSEIDS[@]}"; do
  echo "==> Corso $id"
  "$PHP" "$MOODLEDIR/admin/cli/backup.php" --courseid="$id" --destination="$DEST"
done

echo "Fatto."
