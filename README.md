# IMO-BOT · Immobilien-Radar

Persönlicher Immobilien-Radar für den Portfolioaufbau (Boutique Hotel Gebhard, Tirol).
Dashboard + automatischer täglicher Abruf von Immobilien-Alerts per E-Mail.

> Alle Berechnungen sind Orientierung, **keine Finanz- oder Steuerberatung**. 🛠-Punkte mit Steuerberater klären.

## Was ist das?

- **`index.html`** – das Dashboard (läuft über GitHub Pages, öffnet sich von PC & Handy).
- **`daten/`** – die Daten: `objekte.json` (die Objekte), `mietpreise.json` (Mietschätzung), `config.json` (Parameter/Steuer­sätze).
- **`parser/`** – liest die Alert-Mails aus dem Gmail-Postfach und aktualisiert `objekte.json`.
- **`.github/workflows/daily.yml`** – lässt den Parser automatisch 2× täglich laufen.

## Einrichtung in 5 Schritten

### 1. Repo anlegen
Auf GitHub → **New repository** → Name z. B. `imo-bot` → **Private** → Create.
Dann alle Dateien aus diesem Ordner hochladen (**Add file → Upload files** → den ganzen Inhalt hineinziehen → Commit). Die Ordnerstruktur (`daten/`, `parser/`, `.github/`) muss erhalten bleiben.

### 2. Dashboard live schalten (GitHub Pages)
Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch: `main`, Ordner: `/ (root)` → Save.
Nach ein paar Minuten läuft das Dashboard unter `https://DEIN-NAME.github.io/imo-bot/`.
Diese Adresse dann am Mac in Safari öffnen → **Ablage → Zum Dock hinzufügen** = eigenes App-Icon.

### 3. Gmail-App-Passwort erstellen
Google-Konto (immo.preg@gmail.com) → **Sicherheit** → **2-Schritt-Bestätigung** aktivieren → **App-Passwörter** → neues erzeugen (16 Zeichen).
⚠️ Dieses App-Passwort **nie** in den Code oder in eine Nachricht schreiben – nur als Secret (nächster Schritt).

### 4. Secrets hinterlegen
Repo → **Settings → Secrets and variables → Actions → New repository secret**. Anlegen:

| Name | Wert |
|---|---|
| `IMAP_USER` | `immo.preg@gmail.com` |
| `IMAP_PASS` | das 16-stellige Gmail-App-Passwort |
| `ALERT_TO` | `m.pregenzer@gmx.at` *(wohin die Treffer-Mail geht, optional)* |
| `SMTP_HOST` | `smtp.gmail.com` *(optional, für Alert-Mail)* |
| `SMTP_USER` | `immo.preg@gmail.com` *(optional)* |
| `SMTP_PASS` | dasselbe App-Passwort *(optional)* |

### 5. Testen
Repo → **Actions** → Workflow „IMO Radar“ → **Run workflow** (manueller Start).
Läuft er grün durch, aktualisiert er `daten/objekte.json`, und das Dashboard zeigt die Treffer.

## Suchagenten (Datenquelle)
Bei ImmoMetrica, Willhaben und ImmoScout24 je eine gespeicherte Suche mit **täglicher** Benachrichtigung an `immo.preg@gmail.com`. Bezeichnung mit festem Präfix, damit die Kategorie automatisch erkannt wird:
- `IMO-A-Vorsorge`
- `IMO-B-Studenten`
- `IMO-C-Mitarbeiter`

## Noch feinzujustieren
Die Text-Erkennung im Parser (`parser/parser.py) ist ein Startpunkt. Sobald die erste echte Alert-Mail ankommt, wird sie an den realen Mailaufbau angepasst – unsichere Treffer werden bis dahin mit `"pruefen": true` markiert statt geraten.

## Kosten
ImmoMetrica ~25 €/Monat · GitHub (Actions + Pages, privat) 0 € · Gmail 0 €.
