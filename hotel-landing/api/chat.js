// ---------------------------------------------------------------
// Serverless-Funktion auf Vercel. Nimmt die Frage vom Gast entgegen,
// fragt Claude und schickt die Antwort Wort für Wort zurück.
// Der API-Schlüssel liegt nur hier auf dem Server, nie im Browser.
// ---------------------------------------------------------------

import Anthropic from "@anthropic-ai/sdk";
import { WISSEN, HALTUNG } from "./wissen.js";
import { pruefen, herkunft, zuruecknehmen } from "./grenzen.js";

const client = new Anthropic();

const MODELL = "claude-opus-5";
const MAX_ZEICHEN = 600;   // pro Frage
const MAX_TURNS = 12;      // wie viel Gesprächsverlauf mitgeschickt wird

const SYSTEM = `${HALTUNG}\n\n---\n\nWAS DU ÜBER DAS HAUS WEISST\n${WISSEN}`;

function saeubern(rohe) {
  if (!Array.isArray(rohe)) return [];
  const sauber = [];
  for (const eintrag of rohe.slice(-MAX_TURNS)) {
    if (!eintrag || typeof eintrag.content !== "string") continue;
    if (eintrag.role !== "user" && eintrag.role !== "assistant") continue;
    const text = eintrag.content.trim().slice(0, MAX_ZEICHEN);
    if (!text) continue;
    sauber.push({ role: eintrag.role, content: text });
  }
  // Claude erwartet, dass das Gespräch mit dem Gast anfängt und aufhört.
  while (sauber.length && sauber[0].role !== "user") sauber.shift();
  while (sauber.length && sauber[sauber.length - 1].role !== "user") sauber.pop();
  return sauber;
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Nur POST." });
    return;
  }

  const verlauf = saeubern(req.body && req.body.messages);
  if (!verlauf.length) {
    res.status(400).json({ error: "Keine Frage erhalten." });
    return;
  }

  const ip = herkunft(req);
  const gebremst = pruefen(ip);
  if (gebremst) {
    res.setHeader("Retry-After", String(gebremst.sekunden));
    res.status(429).json({ error: gebremst.text });
    return;
  }

  res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");

  const schick = (paket) => res.write(`data: ${JSON.stringify(paket)}\n\n`);

  try {
    const stream = client.messages.stream({
      model: MODELL,
      max_tokens: 800,
      output_config: { effort: "low" },
      system: [
        { type: "text", text: SYSTEM, cache_control: { type: "ephemeral" } },
      ],
      messages: verlauf,
    });

    for await (const ereignis of stream) {
      if (
        ereignis.type === "content_block_delta" &&
        ereignis.delta.type === "text_delta"
      ) {
        schick({ text: ereignis.delta.text });
      }
    }

    const fertig = await stream.finalMessage();
    if (fertig.stop_reason === "refusal") {
      schick({ text: "\n\nDazu sage ich lieber nichts. Frag mich etwas zum Haus oder zur Region." });
    }

    res.write("data: [DONE]\n\n");
    res.end();
  } catch (fehler) {
    console.error("Chat fehlgeschlagen:", fehler);
    zuruecknehmen(ip);
    if (res.headersSent) {
      schick({ error: "abgebrochen" });
      res.end();
    } else {
      res.status(502).json({ error: "Der Assistent ist gerade nicht erreichbar." });
    }
  }
}
