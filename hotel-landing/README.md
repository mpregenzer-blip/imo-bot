# Winter-Landingpage mit Gästebot

Eine eigenständige Kampagnenseite für den Winter 2026/27 plus einen Chatbot,
der Gästefragen zum Haus beantwortet. Läuft auf Vercel, unabhängig von Framer.

## Was drin ist

```
index.html          die Seite selbst, alles in einer Datei
schriften/          Fraunces und Inter Tight, lokal statt von Google
api/chat.js         die Server-Funktion, die Claude fragt
api/wissen.js       was der Bot über das Haus weiss  ← das pflegst du
package.json        eine einzige Abhängigkeit
```

## Bevor die Seite live geht

Alles, was auf der Seite **gelb hinterlegt** ist, ist ein Platzhalter und muss raus.
Öffne `index.html` und such nach `class="todo"`:

- der Preis im Angebotsblock
- der Anreisezeitraum
- die Gehminuten zur Bahn
- die Telefonnummer

Ausserdem prüfen:

- **E-Mail-Adresse** im Abschnitt „Anfrage" (steht aktuell auf `info@hotel-gebhard.at`)
- **Zahlen zum Skigebiet** (214 km, 68 Lifte, 2820 m) auf serfaus-fiss-ladis.at gegenchecken
- **Impressum und Datenschutz** verlinken aktuell auf die Hauptseite. Das reicht rechtlich
  nur, wenn dort auch der Chatbot erwähnt ist. Siehe unten.

## Auf Vercel stellen

1. Konto auf vercel.com anlegen, mit GitHub verbinden.
2. **Add New → Project**, dieses Repository wählen.
3. Wichtig: unter **Root Directory** den Ordner `hotel-landing` auswählen.
   Sonst sucht Vercel im Hauptordner und findet nichts.
4. Unter **Environment Variables** eintragen:

   | Name | Wert |
   |---|---|
   | `ANTHROPIC_API_KEY` | dein Schlüssel von console.anthropic.com |

   Der Schlüssel bleibt auf dem Server. Er taucht nie im Browser des Gastes auf.
5. **Deploy**. Nach ein bis zwei Minuten läuft die Seite.
6. Eigene Adresse: **Settings → Domains**, zum Beispiel `winter.hotel-gebhard.at`.
   Vercel sagt dir, welchen DNS-Eintrag du beim Domain-Anbieter setzen musst.

## Den Bot füttern

`api/wissen.js` ist reiner Text, kein Code. Zwei Blöcke:

- **WISSEN** — was der Bot über das Haus weiss. Ergänze, was Gäste oft fragen.
- **HALTUNG** — wie er schreibt und woran er sich hält.

Der Abschnitt „WAS DU NICHT WEISST" ist bewusst so gebaut: Preise, freie Zimmer und
Termine stehen nicht drin, damit der Bot sie nicht erfinden kann. Er verweist stattdessen
auf die Rezeption. Wenn du dort etwas einträgst, musst du es auch aktuell halten,
sonst sagt der Bot irgendwann Falsches.

Nach jeder Änderung: committen und pushen. Vercel baut automatisch neu.

## Was das kostet

Vercel ist in dieser Grösse kostenlos. Der Chatbot kostet pro Antwort, abgerechnet
über Anthropic. Eingestellt ist `claude-opus-5`, das beste Modell. Wenn viele Gäste
den Bot nutzen und du günstiger fahren willst, änderst du in `api/chat.js` eine Zeile:

```js
const MODELL = "claude-haiku-4-5";   // statt claude-opus-5
```

Haiku kostet etwa ein Fünftel und reicht für Standardfragen locker. Deine Entscheidung.
Ein Ausgabelimit setzt du in der Anthropic Console unter Billing, damit nichts davonläuft.

## Was noch fehlt

Zwei Dinge, die vor einem echten Livegang dazugehören und bewusst nicht drin sind:

- **Missbrauchsschutz.** Aktuell kann jeder beliebig viele Anfragen schicken. Bei
  öffentlichem Traffic gehört eine Begrenzung pro Besucher davor, sonst zahlst du
  fremde Spielereien mit. Vercel bietet dafür KV oder Firewall-Regeln an.
- **Datenschutzhinweis.** Der Bot schickt die Frage des Gastes an einen Dienst in den
  USA. Das gehört in die Datenschutzerklärung, mit einem Satz, welche Daten
  übermittelt werden und wie lange sie gespeichert bleiben.

## Lokal ausprobieren

```bash
cd hotel-landing
npm install
npx vercel dev
```

Ohne `ANTHROPIC_API_KEY` in der Umgebung läuft die Seite, aber der Bot antwortet mit
einer Fehlermeldung. Das ist normal.
