#!/bin/bash
# Baut das Weiterarbeiten-Werkzeug EINMAL global ein -- nach ~/.claude/.
#
# Danach gilt es in JEDEM Projekt, in Terminal und Desktop-App, ohne dass du
# je wieder einen Pfad nennen musst. Dieses Skript ist in sich geschlossen:
# nach dem Lauf kannst du den Ordner, aus dem du es gestartet hast, loeschen.
#
#   bash weiterarbeiten-einrichten.sh
#
# Es installiert drei Teile:
#   1. ~/.claude/hooks/weiterarbeiten.sh   der Stop-Hook (haelt Claude am Arbeiten)
#   2. ~/.claude/settings.json             schaltet den Hook global ein
#   3. ~/.claude/skills/weiter/SKILL.md    den Befehl /weiter fuer alle Projekte

set -eu

HOOK="$HOME/.claude/hooks/weiterarbeiten.sh"
EINSTELLUNGEN="$HOME/.claude/settings.json"
SKILLVERZ="$HOME/.claude/skills/weiter"

mkdir -p "$HOME/.claude/hooks" "$SKILLVERZ"

# ============================================================== 1. Stop-Hook
cat >"$HOOK" <<'HOOK_ENDE'
#!/bin/bash
# Stop-Hook: haelt Claude am Arbeiten, bis die Arbeitsliste abgehakt ist.
# Ohne .claude/worklist.md im Projekt tut dieser Hook nichts.
set -u
cat >/dev/null 2>&1 || true

PROJEKT="${CLAUDE_PROJECT_DIR:-$PWD}"
LISTE="$PROJEKT/.claude/worklist.md"
ZAEHLER="$PROJEKT/.claude/.weiter-zaehler"
NOTBREMSE="$PROJEKT/.claude/STOP"
MAX="${WEITER_MAX_RUNDEN:-25}"

erlauben() { printf '{"decision":"allow"}\n'; exit 0; }

if [ -f "$NOTBREMSE" ]; then rm -f "$ZAEHLER"; erlauben; fi
[ -f "$LISTE" ] || erlauben

PUNKT="$(grep -m1 -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$LISTE" 2>/dev/null || true)"
if [ -z "$PUNKT" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten: Arbeitsliste ist vollstaendig abgehakt."}\n'
  exit 0
fi

N=0
[ -f "$ZAEHLER" ] && N="$(cat "$ZAEHLER" 2>/dev/null || echo 0)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac

if [ "$N" -ge "$MAX" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten: %s Runden erreicht, Zwangspause. Ein beliebiges Wort setzt den Lauf fort."}\n' "$MAX"
  exit 0
fi
echo "$((N + 1))" >"$ZAEHLER"

TEXT="$(printf '%s' "$PUNKT" | sed \
  -e 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*//' \
  -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/ /g')"

printf '{"decision":"block","reason":"Die Arbeit ist noch nicht fertig. Naechster offener Punkt aus .claude/worklist.md: %s -- arbeite ihn jetzt ab. Hake ihn danach in der Datei mit [x] ab und schreibe den Stand in einem Satz dazu. Frage nicht nach Bestaetigung und warte nicht auf Zuruf. Runde %s von %s."}\n' \
  "$TEXT" "$((N + 1))" "$MAX"
exit 0
HOOK_ENDE
chmod +x "$HOOK"
echo "1/3  Hook:   $HOOK"

# ======================================================== 2. Hook einschalten
if command -v python3 >/dev/null 2>&1; then
  HOOK="$HOOK" EINSTELLUNGEN="$EINSTELLUNGEN" python3 <<'PY_ENDE'
import json, os, shutil

pfad = os.environ["EINSTELLUNGEN"]
hook = os.environ["HOOK"]

cfg = {}
if os.path.exists(pfad):
    shutil.copy(pfad, pfad + ".sicherung")
    try:
        with open(pfad) as f:
            inhalt = f.read().strip()
        cfg = json.loads(inhalt) if inhalt else {}
    except json.JSONDecodeError as e:
        raise SystemExit(
            f"ABBRUCH: {pfad} ist kein gueltiges JSON ({e}).\n"
            "Bitte erst reparieren; ich habe nichts geaendert."
        )

stop = cfg.setdefault("hooks", {}).setdefault("Stop", [])
stop[:] = [e for e in stop if "weiterarbeiten" not in json.dumps(e)]
stop.append({"type": "command", "command": hook})

with open(pfad, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY_ENDE
  echo "2/3  Aktiv:  $EINSTELLUNGEN"
elif [ ! -s "$EINSTELLUNGEN" ]; then
  printf '{\n  "hooks": {\n    "Stop": [\n      { "type": "command", "command": "%s" }\n    ]\n  }\n}\n' "$HOOK" >"$EINSTELLUNGEN"
  echo "2/3  Aktiv:  $EINSTELLUNGEN"
else
  echo "2/3  KEIN python3 und $EINSTELLUNGEN ist nicht leer."
  echo "     Bitte im \"hooks\"-Abschnitt selbst ergaenzen:"
  printf '       "Stop": [ { "type": "command", "command": "%s" } ]\n' "$HOOK"
fi

# ====================================================== 3. Befehl /weiter
cat >"$SKILLVERZ/SKILL.md" <<'SKILL_ENDE'
---
description: Legt die Arbeitsliste des aktuellen Projekts an oder ergaenzt sie und arbeitet sie dann selbsttaetig durch, ohne nach jedem Schritt nachzufragen. Nutzen, wenn der Nutzer /weiter tippt, eine Liste von Aufgaben nennt, die ohne Zuruf abgearbeitet werden soll, oder verlangt, dass ohne Rueckfrage weitergearbeitet wird.
argument-hint: [neue Punkte, mit Semikolon getrennt -- oder leer, um fortzusetzen]
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cat:*), Bash(ls:*)
---

## Arbeitsliste dieses Projekts

!`cat .claude/worklist.md 2>/dev/null || echo "(noch keine Arbeitsliste in diesem Projekt)"`

## Neue Punkte vom Nutzer

$ARGUMENTS

## Anweisungen

Diese Arbeitsweise wird von einem Stop-Hook getragen: Solange in
`.claude/worklist.md` ein Punkt mit offenem Kaestchen `- [ ]` steht, wird das
Beenden der Antwort blockiert und der naechste offene Punkt als Auftrag
nachgeliefert. Der Nutzer muss also nichts tippen. Halte dich daran:

1. **Neue Punkte eintragen.** Stehen oben unter "Neue Punkte vom Nutzer"
   Angaben, trage sie als `- [ ]` unter `## Offen` in `.claude/worklist.md`
   ein. Fehlt die Datei, lege sie mit dieser Struktur an:

   ```markdown
   # Arbeitsliste

   ## Offen

   - [ ] erster Punkt

   ## Fertig
   ```

   Schreibe jeden Punkt so, dass er ohne Rueckfrage bearbeitbar ist: Datei,
   Stelle und Ziel nennen. Teile zu grosse Punkte in mehrere auf.

2. **Ersten offenen Punkt abarbeiten.** Nimm den obersten `- [ ]` und
   bearbeite ihn vollstaendig. Frage nicht nach Bestaetigung und frage nicht,
   ob du weitermachen sollst.

3. **Abhaken und Stand schreiben.** Danach das Kaestchen auf `- [x]` setzen,
   die Zeile nach `## Fertig` verschieben und in einem Satz dazuschreiben, was
   herausgekommen ist. Das ist wichtig: Die Datei liegt auf der Festplatte und
   ueberlebt einen vollen Chat, der Gesprächsverlauf nicht.

4. **Stoesst du auf etwas Neues,** trage es als weiteren offenen Punkt ein,
   statt die Arbeit zu unterbrechen.

5. **Blockiert ein Punkt wirklich** -- fehlende Zugangsdaten, eine
   Entscheidung, die nur der Nutzer treffen kann -- dann hake ihn nicht ab,
   sondern schreibe die Frage in die Zeile und arbeite am naechsten Punkt
   weiter. Am Ende die offenen Fragen gesammelt nennen.

6. **Ist alles abgehakt,** sage das in einem Satz und hoere auf.

Bremsen, die der Nutzer kennt: Nach 25 erzwungenen Runden macht der Hook eine
Zwangspause. `touch .claude/STOP` haelt ihn sofort still, `rm .claude/STOP`
schaltet ihn wieder ein.
SKILL_ENDE
echo "3/3  Befehl: $SKILLVERZ/SKILL.md  ->  /weiter"

cat <<'EOF'

==================================================================
 Fertig. Claude Code neu starten (Terminal und Desktop-App).
==================================================================

 Ab jetzt in JEDEM Projekt, ohne Pfade, ohne Einrichten:

   cd <irgendein Projekt>
   claude
   /weiter Punkt eins; Punkt zwei; Punkt drei

 Das legt die Arbeitsliste an und arbeitet sie durch.
 Beim naechsten Mal reicht:   /weiter

 Notbremse:  touch .claude/STOP
 Wieder an:  rm .claude/STOP

 Dieses Werkzeug liegt jetzt vollstaendig in ~/.claude/.
 Der Ordner, aus dem du dieses Skript gestartet hast, kann weg.
EOF
