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

# --- Vorgeschichte, falls hier schon ein Repository liegt ---
# Eine Datei, die aus dem Ordner geloescht wurde, steckt weiterhin in der
# Git-Vorgeschichte und wuerde beim Push mitgehen. Die Pruefung des
# Arbeitsordners allein hat das nicht gesehen.
if [ -d .git ]; then
  echo
  echo "   Es liegt schon eine Git-Vorgeschichte vor -- pruefe auch die."
  VG_STOPP=0

  VG_DATEIEN="$(git log --all --name-only --pretty=format: 2>/dev/null \
    | sort -u | grep -E '^(.*/)?(credentials.*\.json|token\.json|secret_key\.txt|\.env|id_rsa|id_ed25519|.*\.pem|.*\.key|.*\.p12)$' || true)"
  if [ -n "$VG_DATEIEN" ]; then
    printf '%s\n' "$VG_DATEIEN" | while IFS= read -r F; do
      [ -n "$F" ] && echo "   ABBRUCH-GRUND: $F steckt in der Vorgeschichte"
    done
    VG_STOPP=1
  fi

  VG_INHALT="$(git log --all -p 2>/dev/null | grep -cE -e "$GEHEIM" || true)"
  VG_INHALT="${VG_INHALT:-0}"
  case "$VG_INHALT" in ''|*[!0-9]*) VG_INHALT=0 ;; esac
  if [ "$VG_INHALT" -gt 0 ]; then
    echo "   ABBRUCH-GRUND: $VG_INHALT Stellen in der Vorgeschichte sehen wie"
    echo "                  Zugangsdaten aus."
    VG_STOPP=1
  fi

  if [ "$VG_STOPP" -eq 1 ]; then
    STOPP=1
    echo
    echo "   Loesung: Dieses Projekt ist eine Kopie, die Vorgeschichte braucht"
    echo "            niemand. Am einfachsten neu anfangen:"
    echo "              rm -rf \"$PROJEKT/.git\""
    echo "            Danach dieses Skript erneut starten."
  else
    echo "   Vorgeschichte ist sauber."
  fi
fi

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
# Eine vorhandene .gitignore wird NICHT uebergangen -- fehlende Schutzzeilen
# werden ergaenzt. Sonst erbt das Projekt eine Datei, die nur .DS_Store kennt,
# und eine spaeter hinzukommende .env waere ungeschuetzt.
PFLICHT='credentials*.json
token.json
secret_key.txt
.env
.env.*
!.env.example
*.pem
*.key
*.p12
.DS_Store
.claude/.weiter-zaehler
.claude/STOP'

if [ ! -f .gitignore ]; then
  printf '# Zugangsdaten -- niemals einchecken\n' >.gitignore
  printf '%s\n' "$PFLICHT" >>.gitignore
  echo "   angelegt."
else
  FEHLT=""
  while IFS= read -r Z; do
    [ -z "$Z" ] && continue
    grep -qxF -- "$Z" .gitignore || FEHLT="$FEHLT$Z"$'\n'
  done <<<"$PFLICHT"
  if [ -z "$FEHLT" ]; then
    echo "   existiert und ist vollstaendig."
  else
    ANZ_F="$(printf '%s' "$FEHLT" | grep -c . || true)"; ANZ_F="${ANZ_F:-0}"
    {
      printf '\n# Ergaenzt von veroeffentlichen.sh -- Zugangsdaten schuetzen\n'
      printf '%s' "$FEHLT"
    } >>.gitignore
    echo "   existierte, $ANZ_F fehlende Schutzzeilen ergaenzt:"
    printf '%s' "$FEHLT" | sed 's/^/      /'
  fi
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
