#!/bin/bash
# Stop-Hook: haelt Claude am Arbeiten, bis die Arbeitsliste abgehakt ist.
#
# SICHERHEIT -- bitte vor dem Aendern lesen:
# Der Auftrag, den dieser Hook zurueckgibt, stammt aus .claude/worklist.md.
# Diese Datei kann ein geklontes Repository mitbringen. Ohne Freigabe wuerde
# also fremder Text Claude steuern, ohne dass jemand etwas tippt. Deshalb
# wirkt der Hook nur in Projekten, die ausdruecklich freigegeben sind:
#     bash ~/.claude/hooks/weiter-freigeben.sh
# Die Freigabeliste steht in ~/.claude/weiter-projekte.txt, eine Zeile je Pfad.

set -u
cat >/dev/null 2>&1 || true

PROJEKT="${CLAUDE_PROJECT_DIR:-$PWD}"
LISTE="$PROJEKT/.claude/worklist.md"
ZAEHLER="$PROJEKT/.claude/.weiter-zaehler"
NOTBREMSE="$PROJEKT/.claude/STOP"
FREIGABE="$HOME/.claude/weiter-projekte.txt"
MAX="${WEITER_MAX_RUNDEN:-25}"

erlauben() { printf '{"decision":"allow"}\n'; exit 0; }

# 1. Notbremse.
if [ -f "$NOTBREMSE" ]; then rm -f "$ZAEHLER"; erlauben; fi

# 2. Ohne Arbeitsliste mischt sich der Hook nicht ein.
[ -f "$LISTE" ] || erlauben

# 3. Freigabe. Der Pfad muss zeilenweise und vollstaendig in der Liste stehen
#    (-x fuer ganze Zeile, -F fuer wortwoertlich, damit kein Muster wirkt).
if [ ! -f "$FREIGABE" ] || ! grep -qxF -- "$PROJEKT" "$FREIGABE" 2>/dev/null; then
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten: Dieses Projekt ist nicht freigegeben, die Arbeitsliste wird ignoriert. Freigeben mit: bash ~/.claude/hooks/weiter-freigeben.sh"}\n'
  exit 0
fi

# 4. Ersten offenen Punkt suchen.
PUNKT="$(grep -m1 -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$LISTE" 2>/dev/null || true)"
if [ -z "$PUNKT" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten: Arbeitsliste ist vollstaendig abgehakt."}\n'
  exit 0
fi

# 5. Rundenzaehler -- die Bremse gegen Endlosschleifen.
N=0
[ -f "$ZAEHLER" ] && N="$(cat "$ZAEHLER" 2>/dev/null || echo 0)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac

if [ "$N" -ge "$MAX" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten: %s Runden erreicht, Zwangspause. Ein beliebiges Wort setzt den Lauf fort."}\n' "$MAX"
  exit 0
fi
echo "$((N + 1))" >"$ZAEHLER"

# 6. Text JSON-sicher machen. Reihenfolge ist wichtig: erst Backslash und
#    Anfuehrungszeichen maskieren, dann Tabulator zu Leerzeichen, dann alle
#    uebrigen Steuerzeichen entfernen. Ohne den letzten Schritt erzeugen
#    Windows-Zeilenenden (CR) oder Farbcodes ungueltiges JSON, und der Hook
#    fiel wirkungslos aus.
TEXT="$(printf '%s' "$PUNKT" \
  | sed -e 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*//' \
        -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
  | tr '\011' ' ' | tr -d '\000-\037')"

printf '{"decision":"block","reason":"Die Arbeit ist noch nicht fertig. Naechster offener Punkt aus .claude/worklist.md: %s -- arbeite ihn jetzt ab. Hake ihn danach in der Datei mit [x] ab und schreibe den Stand in einem Satz dazu. Frage nicht nach Bestaetigung und warte nicht auf Zuruf. Runde %s von %s."}\n' \
  "$TEXT" "$((N + 1))" "$MAX"
exit 0
