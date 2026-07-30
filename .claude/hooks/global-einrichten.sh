#!/bin/bash
# Baut den Weiterarbeiten-Hook EINMAL global ein: ~/.claude/
# Gilt danach fuer alle Projekte und fuer Terminal wie Desktop-App gleichzeitig.
#
# Gefahrlos, weil der Hook ohne .claude/worklist.md im Projekt nichts tut.
# Er wird also nur dort aktiv, wo du bewusst eine Arbeitsliste anlegst.

set -eu

HOOKVERZ="$HOME/.claude/hooks"
HOOK="$HOOKVERZ/weiterarbeiten.sh"
EINSTELLUNGEN="$HOME/.claude/settings.json"

mkdir -p "$HOOKVERZ"

# ---------------------------------------------------------------- Hook schreiben
cat >"$HOOK" <<'HOOK_ENDE'
#!/bin/bash
# Stop-Hook: haelt Claude am Arbeiten, bis die Arbeitsliste abgehakt ist.
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
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten-Hook: Arbeitsliste ist vollstaendig abgehakt."}\n'
  exit 0
fi

N=0
[ -f "$ZAEHLER" ] && N="$(cat "$ZAEHLER" 2>/dev/null || echo 0)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac

if [ "$N" -ge "$MAX" ]; then
  rm -f "$ZAEHLER"
  printf '{"decision":"allow","systemMessage":"Weiterarbeiten-Hook: %s Runden erreicht, Zwangspause. Ein beliebiges Wort setzt den Lauf fort."}\n' "$MAX"
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
echo "1/2  Hook geschrieben: $HOOK"

# ------------------------------------------------ In settings.json eintragen
# Sauber zusammenfuehren, damit vorhandene Einstellungen erhalten bleiben.
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
            "Bitte die Datei erst reparieren; ich habe nichts geaendert."
        )

stop = cfg.setdefault("hooks", {}).setdefault("Stop", [])
stop[:] = [e for e in stop if "weiterarbeiten" not in json.dumps(e)]
stop.append({"type": "command", "command": hook})

with open(pfad, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"2/2  Hook aktiviert in {pfad}")
if os.path.exists(pfad + ".sicherung"):
    print(f"     Sicherung der alten Datei: {pfad}.sicherung")
PY_ENDE
elif [ ! -s "$EINSTELLUNGEN" ]; then
  cat >"$EINSTELLUNGEN" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "$HOOK"
      }
    ]
  }
}
EOF
  echo "2/2  Hook aktiviert in $EINSTELLUNGEN"
else
  echo
  echo "2/2  KEIN python3 gefunden und $EINSTELLUNGEN ist nicht leer."
  echo "     Bitte diesen Block dort im \"hooks\"-Abschnitt selbst ergaenzen:"
  echo
  cat <<EOF
  "Stop": [
    { "type": "command", "command": "$HOOK" }
  ]
EOF
  exit 1
fi

cat <<EOF

Fertig. Claude Code neu starten (Terminal und Desktop-App).
Pruefen mit dem Befehl:  /hooks

Ab jetzt in jedem Projekt, das durcharbeiten soll:
  mkdir -p .claude
  printf '# Arbeitsliste\\n\\n- [ ] erster Punkt\\n' > .claude/worklist.md

Notbremse:  touch .claude/STOP
Wieder an:  rm .claude/STOP
EOF
