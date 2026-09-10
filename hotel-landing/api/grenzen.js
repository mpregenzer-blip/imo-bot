// ---------------------------------------------------------------
// Missbrauchsschutz, damit niemand den Bot leerlaufen lässt und du
// die Rechnung zahlst. Drei Schranken, alle hier einstellbar.
//
// Wichtig zu wissen: dieser Zähler lebt im Arbeitsspeicher der
// laufenden Server-Instanz. Vercel startet je nach Andrang mehrere
// davon, dann zählt jede für sich. Das hält normale Neugier und
// gelangweiltes Herumtippen auf, aber keinen entschlossenen Angriff.
// Die harte Schranke dafür ist die Vercel Firewall, siehe README.
// ---------------------------------------------------------------

export const GRENZEN = {
  kurz: { fragen: 8,  fenster: 10 * 60 * 1000 },        // pro Besucher in 10 Minuten
  tag:  { fragen: 30, fenster: 24 * 60 * 60 * 1000 },   // pro Besucher in 24 Stunden
  haus: { fragen: 250 },                                // alle zusammen pro Kalendertag
};

const besucher = new Map();          // ip -> Zeitstempel der Fragen
const MAX_BESUCHER = 5000;           // Speicher deckeln
let haus = { datum: "", anzahl: 0 };

export function herkunft(req) {
  const kette = req.headers["x-forwarded-for"];
  if (typeof kette === "string" && kette.length) return kette.split(",")[0].trim();
  if (Array.isArray(kette) && kette.length) return String(kette[0]).trim();
  return req.headers["x-real-ip"] || req.socket?.remoteAddress || "unbekannt";
}

function heute() {
  return new Date().toISOString().slice(0, 10);
}

// Gibt null zurück, wenn die Frage durchgehen darf,
// sonst { grund, text, sekunden }.
export function pruefen(ip) {
  const jetzt = Date.now();

  if (haus.datum !== heute()) haus = { datum: heute(), anzahl: 0 };
  if (haus.anzahl >= GRENZEN.haus.fragen) {
    return {
      grund: "haus",
      text: "Der Assistent hat für heute genug geredet. Schreib uns direkt an info@hotel-gebhard.at, wir antworten persönlich.",
      sekunden: 3600,
    };
  }

  if (besucher.size > MAX_BESUCHER) besucher.clear();

  const alt = besucher.get(ip) || [];
  const frisch = alt.filter((t) => jetzt - t < GRENZEN.tag.fenster);

  const imFenster = frisch.filter((t) => jetzt - t < GRENZEN.kurz.fenster);
  if (imFenster.length >= GRENZEN.kurz.fragen) {
    const frei = GRENZEN.kurz.fenster - (jetzt - imFenster[0]);
    besucher.set(ip, frisch);
    return {
      grund: "kurz",
      text: "Das waren jetzt viele Fragen auf einmal. Warte ein paar Minuten oder schreib uns direkt an info@hotel-gebhard.at.",
      sekunden: Math.ceil(frei / 1000),
    };
  }

  if (frisch.length >= GRENZEN.tag.fragen) {
    besucher.set(ip, frisch);
    return {
      grund: "tag",
      text: "Für heute ist hier Schluss. Schreib uns an info@hotel-gebhard.at, dann kümmert sich jemand persönlich darum.",
      sekunden: 3600,
    };
  }

  frisch.push(jetzt);
  besucher.set(ip, frisch);
  haus.anzahl += 1;
  return null;
}

// Wenn die Antwort gar nicht zustande kam, soll die Frage dem Gast
// nicht angerechnet werden. Sonst sperrt ihn ein Ausfall aus.
export function zuruecknehmen(ip) {
  const liste = besucher.get(ip);
  if (liste && liste.length) liste.pop();
  if (haus.anzahl > 0) haus.anzahl -= 1;
}
