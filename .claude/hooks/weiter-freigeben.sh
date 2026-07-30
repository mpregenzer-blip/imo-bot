#!/bin/bash
# Gibt ein Projekt fuer das selbsttaetige Weiterarbeiten frei.
#
#   bash ~/.claude/hooks/weiter-freigeben.sh              # aktuelles Verzeichnis
#   bash ~/.claude/hooks/weiter-freigeben.sh /pfad/dahin
#   bash ~/.claude/hooks/weiter-freigeben.sh --liste       # zeigt alle Freigaben
#   bash ~/.claude/hooks/weiter-freigeben.sh --entfernen   # nimmt zurueck
#
# Warum es diese Freigabe gibt: Der Stop-Hook liest .claude/worklist.md und
# gibt deren Inhalt als Auftrag an Claude zurueck -- ohne dass jemand etwas
# tippt. Ein geklontes Repository kann so eine Datei mitbringen. Die Freigabe
# stellt sicher, dass nur Projekte getrieben werden, die du selbst benannt hast.

set -u

FREIGABE="$HOME/.claude/weiter-projekte.txt"
mkdir -p "$HOME/.claude"
[ -f "$FREIGABE" ] || : >"$FREIGABE"

case "${1:-}" in
  --liste)
    if [ -s "$FREIGABE" ]; then
      echo "Freigegebene Projekte:"
      sed 's/^/   /' "$FREIGABE"
    else
      echo "Noch kein Projekt freigegeben."
    fi
    exit 0
    ;;
  --entfernen)
    ZIELPFAD="${2:-$PWD}"
    cd "$ZIELPFAD" 2>/dev/null || { echo "FEHLER: $ZIELPFAD gibt es nicht."; exit 1; }
    ZIELPFAD="$PWD"
    if grep -qxF -- "$ZIELPFAD" "$FREIGABE"; then
      grep -vxF -- "$ZIELPFAD" "$FREIGABE" >"$FREIGABE.neu" || true
      mv "$FREIGABE.neu" "$FREIGABE"
      echo "Freigabe zurueckgenommen: $ZIELPFAD"
    else
      echo "War nicht freigegeben: $ZIELPFAD"
    fi
    exit 0
    ;;
esac

PROJEKT="${1:-$PWD}"
cd "$PROJEKT" 2>/dev/null || { echo "FEHLER: $PROJEKT gibt es nicht."; exit 1; }
PROJEKT="$PWD"

if grep -qxF -- "$PROJEKT" "$FREIGABE"; then
  echo "Schon freigegeben: $PROJEKT"
else
  printf '%s\n' "$PROJEKT" >>"$FREIGABE"
  echo "Freigegeben: $PROJEKT"
fi

if [ ! -f "$PROJEKT/.claude/worklist.md" ]; then
  echo "Hinweis: In diesem Projekt gibt es noch keine .claude/worklist.md."
  echo "         Ohne Arbeitsliste bleibt der Hook wirkungslos."
fi
echo "Zuruecknehmen:  bash $0 --entfernen"
echo "Alle ansehen:   bash $0 --liste"
