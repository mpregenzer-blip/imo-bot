#!/bin/bash
# Macht alles auf einmal: Hook pruefen, Projektordner finden, Arbeitsliste
# anlegen, Hook testen, klares Urteil ausgeben.
#
# Aufruf ohne Argument: sucht selbst nach dem Projektordner.
# Aufruf mit Pfad:      bash loslegen.sh /Users/Michael/Mail_Agent

set -u

SUCHNAME="${SUCHNAME:-Mail_Agent}"
HOOK="$HOME/.claude/hooks/weiterarbeiten.sh"

echo "=============================================="
echo " 1. Ist der Hook eingebaut?"
echo "=============================================="
if [ ! -f "$HOOK" ]; then
  echo "  FEHLER: $HOOK fehlt."
  echo "  -> Einbau nachholen:"
  echo "     bash ~/imo-bot-hook/.claude/hooks/global-einrichten.sh"
  exit 1
fi
[ -x "$HOOK" ] || chmod +x "$HOOK" 2>/dev/null || true
echo "  ok  $HOOK"

if grep -q "weiterarbeiten" "$HOME/.claude/settings.json" 2>/dev/null; then
  echo "  ok  in ~/.claude/settings.json eingetragen"
else
  echo "  WARNUNG: kein Eintrag in ~/.claude/settings.json gefunden."
  echo "  Der Test unten laeuft trotzdem, aber Claude ruft den Hook dann nicht auf."
fi

echo
echo "=============================================="
echo " 2. Projektordner"
echo "=============================================="
PROJEKT="${1:-}"

if [ -n "$PROJEKT" ]; then
  if [ ! -d "$PROJEKT" ]; then
    echo "  FEHLER: $PROJEKT ist kein Ordner."
    exit 1
  fi
else
  TREFFER="$(find "$HOME" -maxdepth 4 -type d -name "$SUCHNAME" \
    -not -path '*/.Trash/*' 2>/dev/null | head -20)"
  if [ -z "$TREFFER" ]; then
    ANZAHL=0
  else
    ANZAHL="$(printf '%s\n' "$TREFFER" | wc -l | tr -d ' ')"
  fi

  if [ "$ANZAHL" -eq 0 ]; then
    echo "  Kein Ordner namens '$SUCHNAME' gefunden."
    echo
    echo "  Zwei Wege:"
    echo "   a) Pfad direkt angeben:"
    echo "      bash $0 /Pfad/zum/Projekt"
    echo "   b) Anderen Namen suchen:"
    echo "      SUCHNAME=Hotel bash $0"
    echo
    echo "  Ordner im Home-Verzeichnis zur Orientierung:"
    find "$HOME" -maxdepth 1 -type d -not -name '.*' 2>/dev/null \
      | sed "s|^$HOME/|   |" | head -25
    exit 1
  elif [ "$ANZAHL" -gt 1 ]; then
    echo "  Mehrere Treffer. Bitte einen auswaehlen:"
    printf '%s\n' "$TREFFER" | sed 's/^/   /'
    echo
    echo "  Dann:  bash $0 <gewaehlter Pfad>"
    exit 1
  fi
  PROJEKT="$TREFFER"
fi

# Sicherheitsnetz: ohne Pfad niemals im aktuellen Verzeichnis weitermachen.
if [ -z "$PROJEKT" ] || [ ! -d "$PROJEKT" ]; then
  echo "  ABBRUCH: kein gueltiger Projektordner ermittelt. Nichts geaendert."
  exit 1
fi

cd "$PROJEKT" || exit 1
PROJEKT="$PWD"
echo "  ok  $PROJEKT"

echo
echo "=============================================="
echo " 3. Arbeitsliste"
echo "=============================================="
mkdir -p "$PROJEKT/.claude"
LISTE="$PROJEKT/.claude/worklist.md"

if [ -f "$LISTE" ] && grep -qE '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$LISTE"; then
  echo "  Es gibt schon eine Liste mit offenen Punkten. Bleibt unveraendert."
else
  [ -f "$LISTE" ] && cp "$LISTE" "$LISTE.sicherung"
  cat >"$LISTE" <<'LISTE_ENDE'
# Arbeitsliste

## Offen

- [ ] Zimmer-Abschnitt: aria-label am nur 121 px hohen Ueberschriftenblock entfernen
- [ ] Wellness: von zwei ineinanderliegenden Bereichen gleicher Groesse den inneren entnennen
- [ ] Dritte Doppelung beheben, danach Messwerkzeug erneut laufen lassen und Ergebnis hier notieren

## Fertig

- [x] Messwerkzeug gebaut, das jede doppelte Bereichsnennung mit Position, Hoehe und Verschachtelung ausgibt
LISTE_ENDE
  echo "  angelegt: $LISTE"
fi
echo
grep -nE '^[[:space:]]*-[[:space:]]+\[' "$LISTE" | sed 's/^/   /'

echo
echo "=============================================="
echo " 4. Test: feuert der Hook?"
echo "=============================================="
AUSGABE="$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJEKT" "$HOOK" 2>&1)"
echo "$AUSGABE" | cut -c1-160
echo
case "$AUSGABE" in
  '{"decision":"block"'*)
    echo "  BESTANDEN. Der Hook blockt und liefert den ersten offenen Punkt."
    echo
    echo "=============================================="
    echo " 5. Jetzt du -- ein einziger Satz"
    echo "=============================================="
    echo "  Claude Code in DIESEM Ordner starten:"
    echo "     cd $PROJEKT && claude"
    echo
    echo "  Dann in Claude Code eingeben:"
    echo "     Arbeite die Arbeitsliste in .claude/worklist.md ab."
    echo
    echo "  Danach tippst du nichts mehr."
    echo
    echo "  Notbremse:  touch $PROJEKT/.claude/STOP"
    echo "  Wieder an:  rm $PROJEKT/.claude/STOP"
    ;;
  *)
    echo "  NICHT BESTANDEN. Erwartet war {\"decision\":\"block\"...}"
    echo "  Pruefe, ob in $LISTE ein Kaestchen wirklich offen ist."
    echo "  Das Muster ist streng: '- [ ]' mit Leerzeichen, nicht '- []'."
    exit 1
    ;;
esac
