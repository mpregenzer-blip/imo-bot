#!/bin/bash
# Macht aus einem Projektordner ein Git-Repository -- aber erst nach einer
# Sicherheitspruefung. Findet es Zugangsdaten, bricht es ab und legt nichts an.
#
#   bash veroeffentlichen.sh                        # Standard: Hotel_Gebhard_Web
#   bash veroeffentlichen.sh /pfad/zum/projekt
#
# Das Skript pusht NICHT selbst. Es bereitet alles vor und gibt dir die zwei
# Zeilen aus, die du nach dem Anlegen des Repositorys auf GitHub brauchst.

set -u

PROJEKT="${1:-$HOME/Programme/Claude/Hotel_Gebhard_Web}"
BENUTZER="${BENUTZER:-mpregenzer-blip}"

if [ ! -d "$PROJEKT" ]; then
  echo "FEHLER: $PROJEKT gibt es nicht."
  echo "Erst die Trennung ausfuehren, oder Pfad angeben:"
  echo "  bash $0 /pfad/zum/projekt"
  exit 1
fi
cd "$PROJEKT" || exit 1
PROJEKT="$PWD"
NAME="$(basename "$PROJEKT")"

echo "=================================================================="
echo " Projekt: $PROJEKT"
echo "=================================================================="
echo

# ==================================================== 1. Sicherheitspruefung
echo "1. Sicherheitspruefung"
echo "----------------------"
STOPP=0

# --- Dateien, die niemals in ein Repository gehoeren ---
for MUSTER in credentials.json credentials_old_backup.json token.json \
              secret_key.txt .env id_rsa id_ed25519; do
  while IFS= read -r F; do
    [ -z "$F" ] && continue
    echo "   ABBRUCH-GRUND: $F"
    STOPP=1
  done < <(find . -name "$MUSTER" -not -path './.git/*' 2>/dev/null)
done
while IFS= read -r F; do
  [ -z "$F" ] && continue
  echo "   ABBRUCH-GRUND: $F (privater Schluessel)"
  STOPP=1
done < <(find . \( -name '*.pem' -o -name '*.p12' -o -name '*.key' \) \
         -not -path './.git/*' 2>/dev/null)

# --- Inhalte, die nach Zugangsdaten aussehen ---
# Das Muster MUSS mit -e uebergeben werden: es beginnt mit Bindestrichen, und
# grep haelt es sonst fuer eine Option. Genau daran ist diese Pruefung schon
# einmal still gescheitert -- deshalb wird der Rueckgabewert jetzt geprueft.
GEHEIM='-----BEGIN [A-Z ]*PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{36}'
GEHEIM="$GEHEIM"'|github_pat_[0-9A-Za-z_]{22,}|sk-[0-9A-Za-z]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}'
GEHEIM="$GEHEIM"'|"client_secret"|"refresh_token"|"private_key"'

# suchen <Beschreibung> <grep-Argumente...> -- bricht ab, wenn grep selbst
# scheitert (Rueckgabewert ab 2), statt das Ergebnis als "nichts gefunden"
# durchzuwinken.
suchen() {
  local ZWECK="$1"; shift
  local AUS RC
  AUS="$(grep "$@" 2>&1)"; RC=$?
  if [ "$RC" -ge 2 ]; then
    echo "   ABBRUCH-GRUND: Die Pruefung '$ZWECK' ist selbst fehlgeschlagen:"
    printf '%s\n' "$AUS" | sed 's/^/      /' | head -3
    STOPP=1
    return
  fi
  [ "$RC" -eq 1 ] && return   # nichts gefunden
  while IFS= read -r F; do
    [ -z "$F" ] && continue
    echo "   ABBRUCH-GRUND: $F  ($ZWECK)"
    STOPP=1
  done <<<"$AUS"
}

suchen "Zugangsdaten im Text" -rIlE -e "$GEHEIM" . --exclude-dir=.git
suchen "Mail-Bot-Code, nicht Website" -rIlE \
  -e 'import (imaplib|smtplib)|google\.oauth2|msal|from googleapiclient' \
  . --include='*.py' --exclude-dir=.git

if [ "$STOPP" -eq 1 ]; then
  echo
  echo "=================================================================="
  echo " ABGEBROCHEN. Es wurde NICHTS angelegt und nichts veraendert."
  echo
  echo " Diese Dateien gehoeren nicht in ein Repository. Entferne sie aus"
  echo " $PROJEKT (sie bleiben im Mail-Agent-Ordner erhalten) und starte"
  echo " dieses Skript erneut."
  echo "=================================================================="
  exit 1
fi
echo "   keine Zugangsdaten gefunden."

# --- Hinweise, die kein Abbruch sind ---
HINWEIS=0
while IFS= read -r F; do
  [ -z "$F" ] && continue
  [ "$HINWEIS" -eq 0 ] && { echo; echo "   HINWEIS, kein Abbruch:"; HINWEIS=1; }
  echo "   - $F enthaelt Mess- oder Konto-Kennungen (GA4/GTM). Kein Geheimnis,"
  echo "     aber ein Grund, das Repository privat zu halten."
done < <(grep -rIlE -e 'GTM-[A-Z0-9]{6,}|G-[A-Z0-9]{8,}|UA-[0-9]{4,}' \
         . --exclude-dir=.git 2>/dev/null | head -5)

# ============================================================ 2. .gitignore
echo
echo "2. .gitignore"
echo "-------------"
if [ -f .gitignore ]; then
  echo "   existiert schon, unveraendert gelassen."
else
  cat >.gitignore <<'GI_ENDE'
# Zugangsdaten -- niemals einchecken
credentials*.json
token.json
secret_key.txt
.env
*.pem
*.key

# macOS
.DS_Store

# Zustand des Weiterarbeiten-Hooks
.claude/.weiter-zaehler
.claude/STOP
GI_ENDE
  echo "   angelegt."
fi

# ================================================== 3. Repository vorbereiten
echo
echo "3. Repository vorbereiten"
echo "-------------------------"
if [ -d .git ]; then
  echo "   ist schon ein Repository."
else
  git init -q -b main || { echo "   FEHLER bei git init"; exit 1; }
  echo "   angelegt (Zweig main)."
fi

git add -A || { echo "   FEHLER bei git add"; exit 1; }
ANZ="$(git diff --cached --name-only | grep -c . || true)"; ANZ="${ANZ:-0}"

if [ "$ANZ" -eq 0 ]; then
  echo "   nichts Neues einzutragen."
else
  git commit -q -m "Hotel Gebhard Website: Stand vom Umzug in ein eigenes Repository" \
    || { echo "   FEHLER beim Commit -- ist git user.name/user.email gesetzt?"; \
         echo "   git config --global user.name \"Michael Pregenzer\""; \
         echo "   git config --global user.email \"m.pregenzer@gmx.at\""; exit 1; }
  echo "   $ANZ Dateien eingetragen."
fi

# ===================================================== 4. Was du jetzt tust
cat <<EOF

==================================================================
 Bereit. Jetzt zwei Schritte, die nur du machen kannst.
==================================================================

 SCHRITT A -- Repository auf GitHub anlegen

   Im Browser oeffnen:   https://github.com/new

   Name:        $NAME
   Sichtbarkeit: PRIVATE  <-- wichtig, nicht Public
   "Add a README", ".gitignore" und "license": alle AUS lassen

   Dann auf "Create repository".

 SCHRITT B -- Diese zwei Zeilen hier im Terminal

   cd $PROJEKT
   git remote add origin https://github.com/$BENUTZER/$NAME.git
   git push -u origin main

 Beim Push fragt GitHub nach Benutzername und Passwort. Als Passwort
 gilt NICHT dein Kontopasswort, sondern ein Token:
   https://github.com/settings/tokens  ->  "Generate new token (classic)"
   Haekchen bei "repo" genuegt. Token kopieren und als Passwort einsetzen.

 Danach kommst du von jedem Geraet an das Projekt -- auch vom Handy.

==================================================================
EOF
