#!/bin/bash
# Richtet den Weiterarbeiten-Hook in einem beliebigen Projekt ein.
#
# Aufruf:   bash einrichten.sh /Pfad/zum/Projekt
# Beispiel: bash einrichten.sh ~/Mail_Agent
#
# Ohne Argument wird das aktuelle Verzeichnis genommen.

set -eu

ZIEL="${1:-$PWD}"
QUELLE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$ZIEL" ]; then
  echo "Fehler: Verzeichnis $ZIEL gibt es nicht." >&2
  exit 1
fi

mkdir -p "$ZIEL/.claude/hooks"
cp "$QUELLE/weiterarbeiten.sh" "$ZIEL/.claude/hooks/weiterarbeiten.sh"
chmod +x "$ZIEL/.claude/hooks/weiterarbeiten.sh"
echo "Hook kopiert nach $ZIEL/.claude/hooks/weiterarbeiten.sh"

# Arbeitsliste anlegen, falls noch keine da ist.
if [ ! -f "$ZIEL/.claude/worklist.md" ]; then
  cat >"$ZIEL/.claude/worklist.md" <<'ENDE'
# Arbeitsliste

## Offen

- [ ] Ersten Punkt hier eintragen.

## Fertig
ENDE
  echo "Arbeitsliste angelegt: $ZIEL/.claude/worklist.md"
else
  echo "Arbeitsliste existiert bereits, unveraendert gelassen."
fi

# .gitignore-Eintraege fuer Zaehler und Notbremse.
IGNORE="$ZIEL/.claude/.gitignore"
if [ ! -f "$IGNORE" ]; then
  printf '.weiter-zaehler\nSTOP\n' >"$IGNORE"
fi

EINSTELLUNGEN="$ZIEL/.claude/settings.local.json"
SCHNIPSEL='{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/weiterarbeiten.sh"
      }
    ]
  }
}'

if [ ! -f "$EINSTELLUNGEN" ]; then
  printf '%s\n' "$SCHNIPSEL" >"$EINSTELLUNGEN"
  echo "Hook aktiviert in $EINSTELLUNGEN"
  echo
  echo "Fertig. Claude Code im Projekt neu starten, dann laeuft es."
else
  echo
  echo "ACHTUNG: $EINSTELLUNGEN existiert schon -- ich ueberschreibe sie nicht."
  echo "Trage den Hook-Block dort selbst ein:"
  echo
  printf '%s\n' "$SCHNIPSEL"
fi

echo
echo "Notbremse:  touch $ZIEL/.claude/STOP    (Hook haelt sofort still)"
echo "Wieder an:  rm $ZIEL/.claude/STOP"
