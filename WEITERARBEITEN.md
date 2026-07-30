# Durcharbeiten ohne Anstoßen

Das Problem: Claude erledigt einen Schritt, sagt „soll ich mit Punkt zwei
weitermachen?" und wartet. Jedes Mal muss jemand „ja, mach weiter" tippen.

Die Lösung heißt **Stop-Hook**. Das ist ein kleines Skript, das Claude Code
automatisch startet, sobald Claude eine Antwort beendet hat. Gibt das Skript
`{"decision":"block"}` zurück, darf Claude nicht aufhören und arbeitet sofort
weiter — mit dem Auftrag, den das Skript mitgibt. Niemand tippt etwas.

Das Skript sagt dabei nicht blind „mach weiter". Es liest die Arbeitsliste,
nimmt den ersten offenen Punkt und gibt **genau diesen Punkt** als Auftrag
zurück. Ist alles abgehakt, lässt es Claude in Ruhe fertig werden.

---

# Einbauen — drei Befehle

Einmal global einbauen. Danach gilt es für **alle Projekte und für Terminal
und Desktop-App gleichzeitig**, weil sich beide dieselben Einstellungen unter
`~/.claude/` teilen.

Terminal öffnen, diese drei Zeilen einzeln ausführen:

```bash
cd ~
git clone -b claude/schedulewakeup-loop-mechanism-epqh6j \
  https://github.com/mpregenzer-blip/imo-bot.git imo-bot-hook
bash ~/imo-bot-hook/.claude/hooks/global-einrichten.sh
```

Steht `imo-bot` bei dir schon lokal, reicht statt des Klonens:

```bash
cd ~/imo-bot
git pull origin claude/schedulewakeup-loop-mechanism-epqh6j
bash .claude/hooks/global-einrichten.sh
```

**Danach Claude Code neu starten** — Terminal und Desktop-App. Prüfen mit dem
Befehl `/hooks` in der Claude-Eingabezeile (nicht im Terminal!). Dort muss
unter `Stop` der Pfad `~/.claude/hooks/weiterarbeiten.sh` auftauchen.

Der Installer ist gefahrlos:

- Vorhandene `~/.claude/settings.json` wird zusammengeführt, nicht überschrieben.
  Andere Hooks, Rechte und Einstellungen bleiben erhalten.
- Er legt vorher `settings.json.sicherung` an.
- Ist die Datei kaputtes JSON, bricht er ab statt etwas zu zerstören.
- Zweimal ausführen schadet nicht — der Eintrag verdoppelt sich nicht.

## Wo genau was landet

| Datei | Zweck |
|---|---|
| `~/.claude/hooks/weiterarbeiten.sh` | der Hook, einmal für alles |
| `~/.claude/settings.json` | schaltet ihn ein, global |
| `<Projekt>/.claude/worklist.md` | die Arbeitsliste — das Steuerrad, pro Projekt |

Der globale Einbau ist deshalb unbedenklich, weil der Hook **ohne
`.claude/worklist.md` im Projekt gar nichts tut**. Er wird nur dort aktiv, wo
du bewusst eine Arbeitsliste anlegst.

---

# Benutzen

Im Projekt, das durcharbeiten soll — zum Beispiel `~/Mail_Agent`:

```bash
cd ~/Mail_Agent
mkdir -p .claude
printf '# Arbeitsliste\n\n- [ ] erster Punkt\n' > .claude/worklist.md
```

Die Liste ist eine gewöhnliche Markdown-Datei mit Kästchen:

```markdown
## Offen

- [ ] Zimmer-Abschnitt: doppelt benannten Überschriftenblock entfernen
- [ ] Wellness: zwei ineinanderliegende Bereiche, inneren entnennen
- [ ] Messwerkzeug erneut laufen lassen, Ergebnis in den Stand schreiben

## Fertig

- [x] Messwerkzeug gebaut
```

Ablauf: Claude beendet eine Antwort → der Hook findet den ersten offenen Punkt
→ er blockt und gibt diesen Punkt als nächsten Auftrag zurück → Claude
arbeitet ihn ab, hakt ihn mit `[x]` ab → nächste Runde. Alle Kästchen
abgehakt, Hook lässt durch, Claude ist fertig.

Ein Punkt sollte eine Runde Arbeit sein und ohne Rückfrage bearbeitbar: Datei,
Stelle, Ziel. „Aufräumen" ist ein schlechter Punkt, „in `index.html` beim
Zimmer-Abschnitt das `aria-label` am 121-px-Block entfernen" ist ein guter.

---

# Bremsen

Drei Sicherungen, damit daraus keine Endlosschleife wird:

**Rundenlimit.** Nach 25 erzwungenen Runden macht der Hook eine Zwangspause
und meldet das. Ein beliebiges Wort setzt den Lauf fort. Anders einstellen:

```bash
export WEITER_MAX_RUNDEN=50
```

**Notbremse.** Hält den Hook sofort still, ohne ihn zu deinstallieren:

```bash
touch .claude/STOP     # aus
rm .claude/STOP        # wieder an
```

**Keine Liste, kein Zwang.** Ohne `.claude/worklist.md` mischt sich der Hook
überhaupt nicht ein. Löschen oder umbenennen reicht.

## Ganz entfernen

```bash
rm ~/.claude/hooks/weiterarbeiten.sh
```

Und in `~/.claude/settings.json` den `Stop`-Eintrag löschen. Oder die vom
Installer angelegte Sicherung zurückholen:

```bash
mv ~/.claude/settings.json.sicherung ~/.claude/settings.json
```

---

# Wenn es nicht feuert

`/hooks` zeigt keinen `Stop`-Eintrag → Claude Code wurde nicht neu gestartet,
oder der Installer lief in einem anderen Benutzerkonto.

`/hooks` zeigt ihn, aber Claude bleibt trotzdem stehen → prüfe, ob die
Arbeitsliste im **richtigen** Projekt liegt und ob ein Kästchen wirklich offen
ist. Das Muster ist streng: `- [ ]` mit Leerzeichen in der Klammer. `- []`
ohne Leerzeichen wird nicht erkannt. Direkt testen:

```bash
cd ~/Mail_Agent
echo '{}' | CLAUDE_PROJECT_DIR="$PWD" ~/.claude/hooks/weiterarbeiten.sh
```

Erwartete Ausgabe ist `{"decision":"block", ...}` mit deinem Punkt darin.
Kommt `{"decision":"allow"}`, findet der Hook keinen offenen Punkt.

Manche Claude-Code-Fassungen erwarten Hooks verschachtelt. Wenn `/hooks` den
Eintrag gar nicht anzeigt, ersetze in `~/.claude/settings.json` den
`Stop`-Abschnitt durch diese Form und starte neu:

```json
"Stop": [
  { "hooks": [ { "type": "command", "command": "/Users/DEINNAME/.claude/hooks/weiterarbeiten.sh" } ] }
]
```

---

# Was der Hook nicht kann

Er hält Claude innerhalb einer **laufenden** Sitzung am Arbeiten. Er startet
keine neue Sitzung. Beendest du Claude Code, ist Schluss — der Hook wartet
darauf, dass Claude antwortet, und ohne Sitzung antwortet niemand.

Die echte Grenze ist ohnehin nicht der Anstoß, sondern der volle Chat. Genau
dagegen hilft die Arbeitsliste: sie steht auf der Festplatte, nicht im
Gesprächsverlauf. Nach einer Zusammenfassung liest der Hook dieselbe Datei und
gibt denselben nächsten Punkt aus. Der Stand überlebt.

## Die zwei Stufen darüber

**Kopflos in einer Schleife** — Claude ohne Oberfläche, gesteuert von der
Shell. Läuft, solange das Terminal offen ist, und braucht keine Eingabe:

```bash
cd ~/Mail_Agent
for i in $(seq 1 20); do
  claude -p "Arbeite den ersten offenen Punkt in .claude/worklist.md ab, \
hake ihn ab und schreibe den Stand dazu. Wenn alles abgehakt ist, \
antworte nur FERTIG." | tee -a lauf.log | grep -q FERTIG && break
done
```

Das ersetzt den Hook nicht, es ist der andere Weg zum selben Ziel: Die
Schleife liegt außen in der Shell statt innen im Hook. Für Nachtläufe lässt
sich das über `launchd` zu einer festen Zeit starten.

**Serverseitige Zeitpläne** — nur in Claude Code im Browser, nicht im
Terminal. Dort laufen Aufträge in Anthropics Umgebung weiter, auch wenn
Rechner und App aus sind. Die einzige Variante, die einen geschlossenen
Laptop übersteht.
