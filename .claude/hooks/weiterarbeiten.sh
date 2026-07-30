#!/bin/bash
# Stop-Hook: haelt Claude am Arbeiten, bis die Arbeitsliste abgehakt ist.
#
# Ablauf: Claude beendet eine Antwort -> dieser Hook laeuft -> findet er in
# .claude/worklist.md noch einen offenen Punkt "- [ ] ...", gibt er
# {"decision":"block"} zurueck. Damit macht Claude sofort weiter, ohne dass
# jemand etwas tippt. Sind alle Punkte "- [x]", laeuft der Hook durch und
# Claude darf fertig werden.
#
# Keine Abhaengigkeiten: kein jq, kein python. Nur bash, grep, sed.

set -u

# stdin (das Hook-JSON) verwerfen. Wir brauchen es nicht -- unser Kriterium
# ist die Arbeitsliste, nicht der Text der letzten Antwort.
cat >/dev/null 2>&1 || true

PROJEKT="${CLAUDE_PROJECT_DIR:-$PWD}"
LISTE="$PROJEKT/.claude/worklist.md"
ZAEHLER="$PROJEKT/.claude/.weiter-zaehler"
NOTBREMSE="$PROJEKT/.claude/STOP"
MAX="${WEITER_MAX_RUNDEN:-25}"

erlauben() { printf '{"decision":"allow"}\n'; exit 0; }

# 1. Notbremse: Datei .claude/STOP anlegen -> Hook haelt sofort still.
if [ -f "$NOTBREMSE" ]; then
  rm -f "$ZAEHLER"
  erlauben
fi

# 2. Ohne Arbeitsliste mischt sich der Hook nicht ein.
[ -f "$LISTE" ] || erlauben

# 3. Ersten offenen Punkt suchen.
PUNKT="$(grep -m1 -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$LISTE" 2>/dev/null || true)"
if [ -z "$PUNKT" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten-Hook: Arbeitsliste ist vollstaendig abgehakt."}\n'
  exit 0
fi

# 4. Rundenzaehler -- die Bremse gegen Endlosschleifen.
N=0
[ -f "$ZAEHLER" ] && N="$(cat "$ZAEHLER" 2>/dev/null || echo 0)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac

if [ "$N" -ge "$MAX" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten-Hook: %s Runden erreicht, Zwangspause. Ein beliebiges Wort setzt den Lauf fort."}\n' "$MAX"
  exit 0
fi
echo "$((N + 1))" >"$ZAEHLER"

# 5. Punkt aufraeumen und JSON-sicher machen (Backslash vor Anfuehrungszeichen).
TEXT="$(printf '%s' "$PUNKT" | sed \
  -e 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*//' \
  -e 's/\\/\\\\/g' \
  -e 's/"/\\"/g' \
  -e 's/	/ /g')"

# 6. Blockieren. Der "reason" ist der Auftrag, den Claude als naechstes liest.
#    Deshalb steht hier der konkrete Punkt und nicht nur "mach weiter".
printf '{"decision":"block","reason":"Die Arbeit ist noch nicht fertig. Naechster offener Punkt aus .claude/worklist.md: %s -- arbeite ihn jetzt ab. Hake ihn danach in der Datei mit [x] ab und schreibe den Stand in einem Satz dazu. Frage nicht nach Bestaetigung und warte nicht auf Zuruf. Runde %s von %s."}\n' \
  "$TEXT" "$((N + 1))" "$MAX"
exit 0
