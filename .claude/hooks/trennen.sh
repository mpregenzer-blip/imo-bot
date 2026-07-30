#!/bin/bash
# Trennt die Hotel-Website-Arbeit aus dem Mail_Agent-Ordner in ein eigenes
# Projekt heraus -- ohne den laufenden Mail-Bot zu beschaedigen.
#
#   bash trennen.sh                 Trockenlauf: zeigt nur, aendert nichts
#   bash trennen.sh --machen        kopiert die Website-Dateien ins neue Projekt
#   bash trennen.sh --aufraeumen    loescht die Originale (erst nach Pruefung!)
#
# Grundregel: Der Mail-Bot ist eine feste, kleine Menge Dateien -- die steht
# unten als Positivliste. Klar erkennbare Website-Dateien wandern. Alles, was
# in keine der beiden Schubladen passt, BLEIBT LIEGEN und wird dir gemeldet.
# Lieber etwas nachtragen als etwas Falsches verschieben.

set -u

QUELLE="${QUELLE:-$HOME/Programme/Claude/Mail_Agent}"
ZIEL="${ZIEL:-$HOME/Programme/Claude/Hotel_Gebhard_Web}"
SCHREIBTISCH="${SCHREIBTISCH:-$HOME/Desktop/Hotel Gebhard - Projekt}"
MODUS="${1:-trocken}"

# ------------------------------------------------- Planungsmaterial vom Desktop
# Die durchnummerierten Strategie-, Ads-, GA4- und SEO-Dateien sind eine andere
# Art Material als die Framer-Bausteine. Sie kommen als Unterordner herein,
# nicht in die gleiche Reihe.
schreibtisch_holen() {
  local TUN="$1"
  if [ ! -d "$SCHREIBTISCH" ]; then
    echo "FEHLER: \"$SCHREIBTISCH\" gibt es nicht."
    echo "Anderen Pfad angeben:"
    echo "  SCHREIBTISCH=\"/pfad/zum/ordner\" bash $0 $MODUS"
    return 1
  fi
  local N
  N="$(cd "$SCHREIBTISCH" && ls -A | grep -c . || echo 0)"
  echo "=================================================================="
  echo " Planungsmaterial: $SCHREIBTISCH"
  echo " Zielordner:       $ZIEL/strategie"
  echo " Einträge:         $N"
  echo "=================================================================="
  echo
  (cd "$SCHREIBTISCH" && ls -A | sed 's/^/   /')
  echo
  if [ "$TUN" != "ja" ]; then
    echo " TROCKENLAUF -- nichts wurde geaendert."
    echo " Wenn es passt:   bash $0 --schreibtisch-machen"
    return 0
  fi
  if [ ! -d "$ZIEL" ]; then
    echo "FEHLER: $ZIEL gibt es noch nicht. Erst 'bash $0 --machen' ausfuehren."
    return 1
  fi
  mkdir -p "$ZIEL/strategie"
  if cp -Rp "$SCHREIBTISCH/." "$ZIEL/strategie/"; then
    echo " FERTIG. $N Einträge kopiert nach $ZIEL/strategie"
    echo " Das Original auf dem Schreibtisch bleibt liegen -- Absicht."
    echo " Loeschen erst, wenn du im neuen Projekt nachgesehen hast."
  else
    echo " FEHLER beim Kopieren. Original ist unberuehrt."
    return 1
  fi
}

# Diese zwei Modi brauchen den Mail_Agent-Ordner gar nicht -- vorher abfangen.
case "$MODUS" in
  --schreibtisch)        schreibtisch_holen nein; exit $? ;;
  --schreibtisch-machen) schreibtisch_holen ja;   exit $? ;;
esac

# ---------------------------------------------------------------- Positivliste
# Alles hier gehoert zum Mail-Bot und bleibt, wo es ist.
behalten() {
  case "$1" in
    # Python-Programm
    main.py|core.py|config.py|server.py|bot.py|history.py|paths.py) return 0 ;;
    seekda.py|webchat.py|whatsapp.py|outlook_mail.py|outlook_bot.py|gmail_auth.py) return 0 ;;
    # Zustand, Datenbank, Zugangsdaten
    history.db|history.db-wal|history.db-shm) return 0 ;;
    credentials.json|credentials_old_backup.json|token.json|secret_key.txt) return 0 ;;
    api_cost.json|inquiries_log.jsonl) return 0 ;;
    test_mode.txt|poll_interval.txt|pricing_link_mode.txt|templates.txt|hotel_context.txt) return 0 ;;
    # Bauen und Starten
    requirements.txt|build_windows.bat|first_run_setup.bat|start.command) return 0 ;;
    "Gebhard Kommunikation.spec"|Mail-Bot|mailbot_launch.log) return 0 ;;
    app_icon.icns|app_icon_old_mountain.icns.bak|logo_signatur.png) return 0 ;;
    # Oberflaeche des Bots -- index.html gehoert dem server.py, NICHT dem Hotel
    index.html|chat_widget.html) return 0 ;;
    # Anleitungen zum Bot
    SETUP.md|BUILD.md|WINDOWS_SETUP.md|MICROSOFT_SETUP.md|WHATSAPP_SETUP.md|PLATFORM.md) return 0 ;;
    # Ordner und Verstecktes
    venv|.venv|build|dist|__pycache__|mail-agent-ui-update) return 0 ;;
    .git|.gitignore|.claude|.DS_Store) return 0 ;;
  esac
  return 1
}

# ------------------------------------------------------------ Website-Erkennung
website() {
  case "$1" in
    *.tsx) return 0 ;;
    Framer_*|FRAMER_*) return 0 ;;
    Seekda_*|SeekdaBookingBar_*|SeekdaRoomsWidget_*) return 0 ;;
    Menue*|MenuePanel_*|menuePanel*) return 0 ;;
    Navigation*|nav_toc_*) return 0 ;;
    RoomCarousel*|RoomsPreview_*|BookingBar*) return 0 ;;
    ALTTEXTE_*|SEO_*|SEITE_*|SEITEN_*|BAUPAKET*|ZIMMER_*) return 0 ;;
    PLAN_*|NACHTLAUF*|UEBERGABE_*|MESSBERICHT_*|MORGENBERICHT_*) return 0 ;;
    ABSTAENDE_*|BILDER_TAUSCHEN*|BILDGEWICHT*|BANDBREITE*) return 0 ;;
    LIVEGANG_*|WIDERSPRUCH_*|EN_*|REGELNUMMERN_*|REGELN_INVENTAR.md) return 0 ;;
    DURCHMARSCH.md|ARBEITSPLAN.md|ABSCHLUSS_*|OFFEN_ENTSCHIEDEN.md) return 0 ;;
    START_NEUER_CHAT.md|Gebhard_landing_*|VIDEO_UND_GAESTE.md) return 0 ;;
    PRUEFPROTOKOLL_Hotel_*|PRUEFPROTOKOLL_ABNAHME.md) return 0 ;;
    ENTWURF_*|alte_urls_typo3.txt) return 0 ;;
    poster_*.jpg|kopf_*.png|og_gebhard_*.jpg) return 0 ;;
    logo|bilder_klein|EINBAU_*|pruefwerkzeuge) return 0 ;;
    LEERE_SNIPPETS_*|MASTERPLAN.md|OFFENE_FRAGEN_LAUF.md) return 0 ;;
  esac
  return 1
}

# -------------------------------------------------------------------- Pruefung
if [ ! -d "$QUELLE" ]; then
  echo "FEHLER: $QUELLE gibt es nicht."
  echo "Anderen Pfad angeben:  QUELLE=/pfad/zum/ordner bash $0"
  exit 1
fi

# ------------------------------------------------------------------ Einsortieren
B_LISTE=""; W_LISTE=""; U_LISTE=""
B_N=0; W_N=0; U_N=0

while IFS= read -r NAME; do
  [ -z "$NAME" ] && continue
  if behalten "$NAME"; then
    B_LISTE="$B_LISTE$NAME"$'\n'; B_N=$((B_N + 1))
  elif website "$NAME"; then
    W_LISTE="$W_LISTE$NAME"$'\n'; W_N=$((W_N + 1))
  else
    U_LISTE="$U_LISTE$NAME"$'\n'; U_N=$((U_N + 1))
  fi
done < <(cd "$QUELLE" && ls -A)

echo "=================================================================="
echo " Quelle: $QUELLE"
echo " Ziel:   $ZIEL"
echo "=================================================================="
echo
echo "BLEIBT beim Mail-Bot ................ $B_N Einträge"
echo "WANDERT ins Website-Projekt ......... $W_N Einträge"
echo "UNKLAR, bleibt vorerst liegen ....... $U_N Einträge"
echo

if [ "$U_N" -gt 0 ]; then
  echo "------------------------------------------------------------------"
  echo " UNKLAR -- diese fasse ich NICHT an. Bitte durchsehen:"
  echo "------------------------------------------------------------------"
  printf '%s' "$U_LISTE" | sed 's/^/   /'
  echo
fi

case "$MODUS" in
  trocken)
    echo "------------------------------------------------------------------"
    echo " Das wuerde ins Website-Projekt wandern:"
    echo "------------------------------------------------------------------"
    printf '%s' "$W_LISTE" | sed 's/^/   /' | head -60
    [ "$W_N" -gt 60 ] && echo "   ... und $((W_N - 60)) weitere"
    echo
    echo "------------------------------------------------------------------"
    echo " Das bleibt beim Mail-Bot:"
    echo "------------------------------------------------------------------"
    printf '%s' "$B_LISTE" | sed 's/^/   /'
    echo
    echo "=================================================================="
    echo " TROCKENLAUF -- nichts wurde geaendert."
    echo " Wenn die Einteilung stimmt:   bash $0 --machen"
    echo "=================================================================="
    ;;

  --machen)
    if [ "$W_N" -eq 0 ]; then echo "Nichts zu kopieren. Abbruch."; exit 1; fi
    mkdir -p "$ZIEL"
    echo "Kopiere (Originale bleiben vorerst liegen) ..."
    FEHLER=0
    while IFS= read -r NAME; do
      [ -z "$NAME" ] && continue
      if cp -Rp "$QUELLE/$NAME" "$ZIEL/$NAME" 2>/dev/null; then
        printf '.'
      else
        echo; echo "  FEHLER beim Kopieren: $NAME"; FEHLER=$((FEHLER + 1))
      fi
    done <<<"$W_LISTE"
    echo; echo

    # Arbeitsliste fuers Website-Projekt
    mkdir -p "$ZIEL/.claude"
    if [ ! -f "$ZIEL/.claude/worklist.md" ]; then
      cat >"$ZIEL/.claude/worklist.md" <<'LISTE_ENDE'
# Arbeitsliste Hotel Gebhard Website

## Offen

- [ ] Zimmer-Abschnitt: aria-label am nur 121 px hohen Ueberschriftenblock entfernen
- [ ] Wellness: von zwei ineinanderliegenden Bereichen gleicher Groesse den inneren entnennen
- [ ] Dritte Doppelung beheben, danach Messwerkzeug erneut laufen lassen und Ergebnis hier notieren

## Fertig

- [x] Messwerkzeug gebaut, das jede doppelte Bereichsnennung mit Position, Hoehe und Verschachtelung ausgibt
LISTE_ENDE
    fi

    cat >"$ZIEL/CLAUDE.md" <<'CM_ENDE'
# Hotel Gebhard -- Website

Dieses Projekt enthaelt ausschliesslich die Website-Arbeit: Framer-Custom-Code,
Seekda-CSS, TSX-Bausteine, SEO, Alt-Texte, Mess- und Pruefberichte.

Der Mail-Bot ist ein SEPARATES Projekt und liegt in ../Mail_Agent.
Niemals Dateien zwischen den beiden verschieben.

Stand und offene Punkte stehen in .claude/worklist.md. Nach jedem Schritt
dort abhaken und den Stand notieren -- das ueberlebt einen vollen Chat.
CM_ENDE

    # Geheimnisse schuetzen, falls hier je ein Git-Projekt entsteht
    [ -f "$ZIEL/.gitignore" ] || printf '.DS_Store\n' >"$ZIEL/.gitignore"
    if [ ! -f "$QUELLE/.gitignore" ]; then
      cat >"$QUELLE/.gitignore" <<'GI_ENDE'
# Zugangsdaten -- NIEMALS in ein Repository
credentials.json
credentials_old_backup.json
token.json
secret_key.txt
# Zustand
history.db
history.db-wal
history.db-shm
inquiries_log.jsonl
# Umgebung und Bauartefakte
venv/
.venv/
__pycache__/
build/
dist/
.DS_Store
GI_ENDE
      echo "Schutz angelegt: $QUELLE/.gitignore (Zugangsdaten ausgeschlossen)"
    fi

    echo "=================================================================="
    if [ "$FEHLER" -eq 0 ]; then
      echo " FERTIG. $W_N Einträge kopiert nach:"
      echo " $ZIEL"
    else
      echo " MIT $FEHLER FEHLERN abgeschlossen -- bitte oben nachsehen."
    fi
    echo "=================================================================="
    echo
    echo " Jetzt pruefen, dass beide Projekte laufen:"
    echo "   1. Mail-Bot starten wie gewohnt -- muss unveraendert gehen."
    echo "   2. cd $ZIEL && claude"
    echo
    echo " Erst wenn BEIDES laeuft, die Originale entfernen:"
    echo "   bash $0 --aufraeumen"
    echo
    echo " Bis dahin liegt alles doppelt. Das ist Absicht."
    echo
    echo " Noch offen: das Planungsmaterial vom Schreibtisch."
    echo "   bash $0 --schreibtisch          (zeigt nur)"
    echo "   bash $0 --schreibtisch-machen   (kopiert nach $ZIEL/strategie)"
    ;;

  --aufraeumen)
    if [ ! -d "$ZIEL" ]; then
      echo "FEHLER: $ZIEL gibt es nicht. Erst --machen ausfuehren."
      exit 1
    fi
    echo "Pruefe, ob jede Datei im Ziel angekommen ist ..."
    FEHLT=0
    while IFS= read -r NAME; do
      [ -z "$NAME" ] && continue
      [ -e "$ZIEL/$NAME" ] || { echo "  FEHLT im Ziel: $NAME"; FEHLT=$((FEHLT + 1)); }
    done <<<"$W_LISTE"

    if [ "$FEHLT" -gt 0 ]; then
      echo
      echo "ABBRUCH: $FEHLT Einträge fehlen im Ziel. Es wird nichts geloescht."
      exit 1
    fi
    echo "  alle $W_N Einträge vorhanden."
    echo
    echo "Es werden jetzt $W_N Einträge in $QUELLE geloescht."
    printf 'Zum Bestaetigen genau LOESCHEN eingeben: '
    read -r ANTWORT
    if [ "$ANTWORT" != "LOESCHEN" ]; then
      echo "Abgebrochen. Nichts geloescht."
      exit 1
    fi
    while IFS= read -r NAME; do
      [ -z "$NAME" ] && continue
      rm -rf "$QUELLE/$NAME" && printf '.'
    done <<<"$W_LISTE"
    echo; echo "Fertig. $QUELLE enthaelt jetzt nur noch den Mail-Bot."
    ;;

  *)
    echo "Unbekannte Angabe: $MODUS"
    echo
    echo "Erlaubt:"
    echo "  (ohne)                  Trockenlauf Mail_Agent -> Website-Projekt"
    echo "  --machen                kopiert die Website-Dateien"
    echo "  --aufraeumen            loescht die Originale nach Pruefung"
    echo "  --schreibtisch          Trockenlauf Planungsmaterial vom Desktop"
    echo "  --schreibtisch-machen   kopiert es nach <Ziel>/strategie"
    exit 1
    ;;
esac
