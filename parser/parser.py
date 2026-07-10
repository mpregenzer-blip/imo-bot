#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IMO-BOT E-Mail-Parser
=====================
Liest die Immobilien-Alert-Mails aus dem Gmail-Postfach (immo.preg@gmail.com),
extrahiert Objekte, ordnet sie einer Kategorie zu, schaetzt die Miete,
entfernt Duplikate und schreibt sie nach daten/objekte.json.

WICHTIG - Sicherheit:
  Alle Zugangsdaten kommen ausschliesslich aus Umgebungsvariablen (GitHub Secrets),
  niemals im Code. Benoetigt wird ein Gmail-APP-PASSWORT (nicht das normale Passwort),
  dazu muss die 2-Schritt-Bestaetigung aktiv sein.

Umgebungsvariablen:
  IMAP_HOST        z.B. imap.gmail.com
  IMAP_USER        z.B. immo.preg@gmail.com
  IMAP_PASS        Gmail App-Passwort (16 Zeichen)
  ALERT_TO         (optional) Empfaenger fuer Treffer-Mail, z.B. m.pregenzer@gmx.at
  SMTP_HOST/USER/PASS (optional) fuer den Versand der Alert-Mail

Hinweis zur Text-Erkennung:
  Jedes Portal formatiert seine Mails anders. Die Regex-Extraktion unten ist ein
  funktionierender Startpunkt und wird anhand echter Alert-Mails feinjustiert.
  Bis dahin lieber ein Objekt zu wenig als falsche Daten -> unsichere Treffer
  werden mit "pruefen": true markiert statt geraten.
"""

import os, re, ssl, json, imaplib, email, smtplib, datetime as dt
from email.header import decode_header
from email.mime.text import MIMEText
from pathlib import Path

try:
    import requests
except ImportError:
    requests = None
try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None

ROOT = Path(__file__).resolve().parents[1]
DATEN = ROOT / "daten"
OBJEKTE = DATEN / "objekte.json"
MIETPREISE = DATEN / "mietpreise.json"

HEUTE = dt.date.today()          # Datum wird vom Workflow gestellt (UTC)
ARCHIV_TAGE = 14

# ---------------------------------------------------------------- Hilfen

def log(*a):
    print("[imo-parser]", *a, flush=True)

def load_json(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default

def save_json(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

def decode_str(s):
    if not s:
        return ""
    out = []
    for txt, enc in decode_header(s):
        if isinstance(txt, bytes):
            out.append(txt.decode(enc or "utf-8", "ignore"))
        else:
            out.append(txt)
    return "".join(out)

# ---------------------------------------------------------------- Kategorie

def kategorie_aus_betreff(subject):
    s = (subject or "").lower()
    if "imo-a" in s or "vorsorge" in s:
        return "vorsorge"
    if "imo-b" in s or "studenten" in s or "mikroapart" in s:
        return "studenten"
    if "imo-c" in s or "mitarbeiter" in s or "personal" in s:
        return "mitarbeiter"
    return None   # unbekannt -> spaeter ueber Merkmale/Default

DEFAULT_LAGE = {
    "vorsorge":    {"ruhe":60,"schule":60,"nahversorgung":60,"oeffi":60,"natur":60},
    "studenten":   {"uni":60,"oeffi":60,"ausgehen":60,"nahversorgung":60},
    "mitarbeiter": {"arbeitsweg":60,"dorfleben":60,"oeffi":60,"nahversorgung":60},
}

# ---------------------------------------------------------------- Miet-Schaetzung

def schaetze_miete(kat, ort, qm):
    mp = load_json(MIETPREISE, {})
    ppqm = None
    if kat == "vorsorge":
        tab = mp.get("vorsorge_eur_pro_qm", {})
        ppqm = tab.get(ort, tab.get("_standard", 11.0))
    elif kat == "studenten":
        tab = mp.get("studenten_eur_pro_qm", {})
        ppqm = tab.get("Innsbruck <40 m2") if qm and qm < 40 else tab.get("Innsbruck 40-90 m2")
        ppqm = ppqm or tab.get("_standard", 18.0)
    elif kat == "mitarbeiter":
        tab = mp.get("mitarbeiter", {}).get("eur_pro_qm", {})
        ppqm = tab.get(ort, tab.get("_standard", 12.0))
    if not (ppqm and qm):
        return None
    return round(ppqm * qm)

# ---------------------------------------------------------------- E-Mail -> Text

def mail_text(msg):
    """Bevorzugt HTML (mehr Struktur), faellt auf Plaintext zurueck."""
    html, plain = None, None
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            disp = str(part.get("Content-Disposition") or "")
            if "attachment" in disp:
                continue
            try:
                payload = part.get_payload(decode=True)
                if payload is None:
                    continue
                charset = part.get_content_charset() or "utf-8"
                text = payload.decode(charset, "ignore")
            except Exception:
                continue
            if ctype == "text/html" and html is None:
                html = text
            elif ctype == "text/plain" and plain is None:
                plain = text
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            plain = payload.decode(msg.get_content_charset() or "utf-8", "ignore")
    return html, plain

# ---------------------------------------------------------------- Extraktion (Startpunkt, wird feinjustiert)

PREIS_RE = re.compile(r"(?:€|EUR)\s?([\d\.\s]{4,})", re.I)
QM_RE    = re.compile(r"([\d]{1,3}(?:[.,]\d)?)\s?(?:m²|m2|qm)", re.I)
ZIMMER_RE= re.compile(r"([\d](?:[.,]\d)?)\s?(?:zimmer|zi\b|-zi)", re.I)
PLZ_ORT_RE=re.compile(r"\b(\d{4})\s+([A-ZÄÖÜ][a-zäöüß\.\- ]{2,30})")

def zahl(s):
    if not s: return None
    s = s.replace(".", "").replace(" ", "").replace("\xa0", "").replace(",", ".")
    try:
        return float(s)
    except Exception:
        return None

def resolve_url(url):
    """Tracking-Redirect zur echten Inserats-URL aufloesen."""
    if not requests:
        return url
    try:
        r = requests.get(url, allow_redirects=True, timeout=15,
                         headers={"User-Agent": "Mozilla/5.0 (IMO-BOT)"})
        return r.url or url
    except Exception:
        return url

def extrahiere_objekte(html, plain, kat):
    """Bestmoegliche Extraktion. Gibt Liste von Objekt-Dicts zurueck.
       Unsichere Werte -> 'pruefen': True, statt zu raten."""
    objekte = []
    links = []
    text = plain or ""
    if html and BeautifulSoup:
        soup = BeautifulSoup(html, "html.parser")
        text = soup.get_text("\n")
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if re.search(r"(willhaben|immobilienscout24|immoscout|immmetrica|immometrica|derstandard|immo)", href, re.I):
                links.append(href)
    elif html:
        links = re.findall(r'href="(https?://[^"]+)"', html)
        text = re.sub(r"<[^>]+>", " ", html)

    # Fallback: mind. 1 Objekt pro Mail, wenn Kennzahlen gefunden werden
    preis = zahl((PREIS_RE.search(text) or [None, None])[1] if PREIS_RE.search(text) else None)
    qm    = zahl((QM_RE.search(text) or [None, None])[1] if QM_RE.search(text) else None)
    zi    = zahl((ZIMMER_RE.search(text) or [None, None])[1] if ZIMMER_RE.search(text) else None)
    plz, ort = None, None
    m = PLZ_ORT_RE.search(text)
    if m:
        plz, ort = m.group(1), m.group(2).strip()

    link = resolve_url(links[0]) if links else None
    if not (preis or link):
        return objekte  # nichts Brauchbares

    unsicher = not (preis and qm and ort)
    obj = {
        "kat": kat or "vorsorge",
        "titel": (ort and f"{int(zi) if zi else ''}-Zi {ort}".strip("- ")) or "Neues Objekt",
        "ort": ort or "",
        "plz": plz or "",
        "kaufpreis": int(preis) if preis else 0,
        "qm": int(qm) if qm else 0,
        "zimmer": int(zi) if zi else 0,
        "baujahr": 0,
        "makler": True,
        "einheiten": 0,
        "tage_online": 0,
        "preissenkung": False,
        "freizeit": "offen",
        "link": link or "",
        "quelle": "E-Mail",
        "pruefen": unsicher,
        "lage": dict(DEFAULT_LAGE.get(kat or "vorsorge")),
        "hist": [],
        "erstmals_gesehen": HEUTE.isoformat(),
    }
    m2 = schaetze_miete(obj["kat"], obj["ort"], obj["qm"])
    obj["miete"] = m2 or 0
    if obj["kat"] == "mitarbeiter" and obj["zimmer"]:
        obj["betten"] = max(2, obj["zimmer"])
    objekte.append(obj)
    return objekte

# ---------------------------------------------------------------- Dedup / Merge

def obj_id(o):
    base = (o.get("link") or "") + "|" + str(o.get("plz")) + "|" + str(o.get("qm")) + "|" + str(o.get("kaufpreis"))
    return "e" + str(abs(hash(base)) % (10**10))

def ist_duplikat(neu, bestand):
    for b in bestand:
        if neu.get("link") and b.get("link") and neu["link"] == b["link"]:
            return b
        if (neu.get("plz") and b.get("plz") == neu["plz"]
                and abs((b.get("qm") or 0) - (neu.get("qm") or 0)) <= 3
                and neu.get("kaufpreis") and b.get("kaufpreis")
                and abs(b["kaufpreis"] - neu["kaufpreis"]) / neu["kaufpreis"] <= 0.05):
            return b
    return None

def merge(neue, bestand):
    treffer_neu, treffer_preis = [], []
    for n in neue:
        b = ist_duplikat(n, bestand)
        if b:
            if n.get("kaufpreis") and b.get("kaufpreis") and n["kaufpreis"] != b["kaufpreis"]:
                b.setdefault("hist", []).append({"d": HEUTE.isoformat(), "p": n["kaufpreis"]})
                if n["kaufpreis"] < b["kaufpreis"]:
                    b["preissenkung"] = True
                    treffer_preis.append(b)
                b["kaufpreis"] = n["kaufpreis"]
        else:
            n["id"] = obj_id(n)
            n["hist"] = [{"d": HEUTE.isoformat(), "p": n["kaufpreis"]}] if n.get("kaufpreis") else []
            n["status"] = "aktiv"
            bestand.append(n)
            treffer_neu.append(n)
    return treffer_neu, treffer_preis

def archiv_cleanup(bestand):
    behalten = []
    for o in bestand:
        arch = o.get("archiviert_am")
        if arch:
            try:
                if (HEUTE - dt.date.fromisoformat(arch)).days > ARCHIV_TAGE:
                    continue
            except Exception:
                pass
        behalten.append(o)
    return behalten

# ---------------------------------------------------------------- IMAP

def hole_mails():
    host = os.environ.get("IMAP_HOST", "imap.gmail.com")
    user = os.environ.get("IMAP_USER")
    pw   = os.environ.get("IMAP_PASS")
    if not (user and pw):
        log("Keine IMAP-Zugangsdaten gesetzt (IMAP_USER/IMAP_PASS) - ueberspringe Mail-Abruf.")
        return []
    mails = []
    ctx = ssl.create_default_context()
    M = imaplib.IMAP4_SSL(host, ssl_context=ctx)
    M.login(user, pw)
    M.select("INBOX")
    seit = (HEUTE - dt.timedelta(days=1)).strftime("%d-%b-%Y")
    typ, data = M.search(None, f'(SINCE {seit})')
    ids = data[0].split() if data and data[0] else []
    log(f"{len(ids)} Mails seit {seit}")
    for i in ids:
        typ, md = M.fetch(i, "(RFC822)")
        if typ != "OK" or not md or not md[0]:
            continue
        msg = email.message_from_bytes(md[0][1])
        mails.append(msg)
    M.logout()
    return mails

# ---------------------------------------------------------------- Alert-Mail

def sende_alert(neu, preis):
    to = os.environ.get("ALERT_TO")
    host = os.environ.get("SMTP_HOST"); user = os.environ.get("SMTP_USER"); pw = os.environ.get("SMTP_PASS")
    if not (to and host and user and pw):
        log("Kein SMTP/ALERT_TO gesetzt - keine Alert-Mail.")
        return
    if not (neu or preis):
        return
    zeilen = ["Neue Treffer im IMO-Radar:", ""]
    for o in neu:
        zeilen.append(f"NEU  {o.get('ort','?')}  {o.get('kaufpreis',0):,} EUR  {o.get('qm','?')} m2  [{o.get('kat')}]  {o.get('link','')}")
    for o in preis:
        zeilen.append(f"PREIS gesenkt  {o.get('ort','?')}  jetzt {o.get('kaufpreis',0):,} EUR  {o.get('link','')}")
    zeilen += ["", "Dashboard oeffnen und pruefen. Keine Finanz-/Steuerberatung."]
    body = "\n".join(zeilen).replace(",", ".")
    m = MIMEText(body, "plain", "utf-8")
    m["Subject"] = f"IMO-Radar: {len(neu)} neu, {len(preis)} Preissenkung(en)"
    m["From"] = user; m["To"] = to
    with smtplib.SMTP_SSL(host, 465, context=ssl.create_default_context()) as s:
        s.login(user, pw)
        s.sendmail(user, [to], m.as_string())
    log("Alert-Mail gesendet.")

# ---------------------------------------------------------------- Main

def main():
    bestand = load_json(OBJEKTE, [])
    if not isinstance(bestand, list):
        bestand = []
    if any(o.get("quelle") == "Beispiel" for o in bestand):
        log("Beispiel-Objekte werden ab dem ersten echten Treffer ersetzt (bleiben bis dahin sichtbar).")

    neue_objekte = []
    for msg in hole_mails():
        subject = decode_str(msg.get("Subject"))
        kat = kategorie_aus_betreff(subject)
        html, plain = mail_text(msg)
        gefunden = extrahiere_objekte(html, plain, kat)
        if gefunden:
            log(f'  "{subject[:60]}" -> {len(gefunden)} Objekt(e), Kategorie={kat}')
            neue_objekte += gefunden

    if neue_objekte:
        bestand = [o for o in bestand if o.get("quelle") != "Beispiel"]

    treffer_neu, treffer_preis = merge(neue_objekte, bestand)
    bestand = archiv_cleanup(bestand)
    save_json(OBJEKTE, bestand)
    log(f"Fertig: {len(treffer_neu)} neu, {len(treffer_preis)} Preissenkung(en), {len(bestand)} gesamt.")

    try:
        sende_alert(treffer_neu, treffer_preis)
    except Exception as e:
        log("Alert-Mail fehlgeschlagen:", e)

if __name__ == "__main__":
    main()
