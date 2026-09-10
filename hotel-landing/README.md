# Winter-Landingpage mit Gästebot

Eigenständige Kampagnenseite für den Winter 2026/27 plus ein Chatfenster,
das Gästefragen zum Haus beantwortet. Läuft auf Vercel, unabhängig von Framer.

```
index.html                 die Seite, alles in einer Datei
schriften/                 Fraunces und Inter Tight, lokal statt von Google
api/chat.js                die Server-Funktion, die Claude fragt
api/wissen.js              was der Bot über das Haus weiss   ← das pflegst du
api/grenzen.js             Missbrauchsschutz                 ← Zahlen anpassbar
DATENSCHUTZ-BAUSTEIN.md    Text für eure Datenschutzerklärung
```

## Stand der Inhalte

Eingetragen und geprüft:

- Adresse, Telefon, E-Mail: Via-Claudia-Augusta 36, 6533 Fiss, +43 5476 6617,
  info@hotel-gebhard.at. **Bitte gegenlesen.** Die Daten stammen aus öffentlichen
  Verzeichnissen, weil hotel-gebhard.at aus der Bauumgebung nicht erreichbar war.
- Skigebiet: 214 Pistenkilometer, 68 Bahnen, höchster Punkt 2828 Meter.

Bewusst offen gelassen, weil nicht erfindbar:

- **Der Preis** steht auf „Preis auf Anfrage". Das ist eine gültige Aussage, die
  Seite kann so online gehen. Sobald der Winterpreis feststeht, steht in
  `index.html` direkt darüber ein Kommentar mit der fertigen Zeile zum Einsetzen.

## Auf Vercel stellen

Diesen Teil kann ich nicht für dich erledigen, dafür braucht es deinen Login und
deine Kreditkarte. Es sind fünf Minuten.

1. Konto auf vercel.com anlegen, mit GitHub verbinden.
2. **Add New → Project**, dieses Repository wählen.
3. **Root Directory** auf `hotel-landing` setzen. Wird gern übersehen, sonst
   findet Vercel nichts.
4. Unter **Environment Variables** eintragen:

   | Name | Wert |
   |---|---|
   | `ANTHROPIC_API_KEY` | dein Schlüssel von console.anthropic.com |

   Der Schlüssel bleibt auf dem Server, er taucht nie im Browser des Gastes auf.
5. **Deploy**.
6. Eigene Adresse unter **Settings → Domains**, zum Beispiel
   `winter.hotel-gebhard.at`. Vercel sagt dir den DNS-Eintrag.

## Missbrauchsschutz

Eingebaut in `api/grenzen.js`, drei Schranken:

| Schranke | Wert | Wofür |
|---|---|---|
| pro Besucher, kurz | 8 Fragen in 10 Minuten | bremst Herumtippen, stört echte Gäste nicht |
| pro Besucher, Tag | 30 Fragen in 24 Stunden | Obergrenze für einen Anschluss |
| ganzes Haus | 250 Antworten pro Tag | deckelt die Tagesrechnung |

Wer gebremst wird, bekommt einen freundlichen deutschen Satz mit dem Hinweis auf
info@hotel-gebhard.at, keine Fehlermeldung. Wenn die Antwort technisch scheitert,
wird sie dem Gast nicht angerechnet.

**Was das nicht kann:** Der Zähler lebt im Arbeitsspeicher der laufenden
Server-Instanz. Vercel startet bei Andrang mehrere davon, dann zählt jede für sich.
Gegen gelangweilte Besucher reicht das. Gegen jemanden, der es wirklich darauf
anlegt, nicht.

Die harte Schranke dafür kostet nichts und wird im Vercel-Dashboard geklickt,
nicht programmiert: **Firewall → Rate Limiting → Add Rule**

- Pfad `/api/chat`, Methode POST
- 20 Anfragen pro Minute je IP, Aktion: Deny
- zweite Regel: 200 Anfragen pro Stunde je IP

Das läuft vor der Funktion und kostet dich damit auch dann nichts, wenn jemand
dagegenrennt. Empfehlung: sofort mit einrichten.

## Datenschutz

Unter dem Chatfenster steht ein Hinweis, der auf
`hotel-gebhard.at/datenschutz.html` verlinkt. **Dieser Abschnitt muss dort auch
wirklich stehen**, sonst zeigt der Link ins Leere.

Den fertigen Textentwurf findest du in `DATENSCHUTZ-BAUSTEIN.md`. Er deckt ab,
welche Daten übermittelt werden, an wen, wie lange und auf welcher Grundlage.
Er erwähnt auch die IP-Adresse, die der Missbrauchsschutz kurz im Speicher hält.
Bitte von der Person gegenlesen lassen, die eure Datenschutzerklärung betreut.

Zusätzlich in der Anthropic Console einen Auftragsverarbeitungsvertrag
abschließen (Settings, Data Processing Addendum).

## Was das kostet

Vercel ist in dieser Grösse kostenlos. Bezahlt wird pro Antwort des Bots.

Grobe Rechnung, eine Antwort umfasst Frage, Gesprächsverlauf und Antworttext:

| Modell | pro Antwort | 80 Antworten am Tag | bei vollem Tageslimit (250) |
|---|---|---|---|
| `claude-opus-5` (eingestellt) | ca. 2 Cent | ca. 48 € im Monat | ca. 150 € im Monat |
| `claude-haiku-4-5` | ca. 0,4 Cent | ca. 10 € im Monat | ca. 30 € im Monat |

Modell wechseln: eine Zeile in `api/chat.js`.

```js
const MODELL = "claude-haiku-4-5";   // statt claude-opus-5
```

**Empfehlung:** In der Anthropic Console unter Billing ein Monatslimit von **60 €**
setzen. Das ist die einzige Grenze, die wirklich hart greift, unabhängig von allem
Code. Nach dem ersten Monat siehst du die echten Zahlen und kannst nachjustieren.

Ob Opus oder Haiku ist deine Entscheidung. Für Standardfragen nach Frühstückszeiten
und Familienzimmern reicht Haiku locker. Opus schreibt merklich besser, wenn eine
Frage ungewöhnlich ist. Mein Vorschlag: mit Opus starten, nach vier Wochen in die
Abrechnung schauen.

## Lokal ausprobieren

```bash
cd hotel-landing
npm install
npx vercel dev
```

Ohne `ANTHROPIC_API_KEY` läuft die Seite, aber der Bot antwortet mit einer
Fehlermeldung. Das ist normal.
