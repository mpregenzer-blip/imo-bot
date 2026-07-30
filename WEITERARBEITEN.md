# Durcharbeiten ohne Anstoßen

Das Problem: Claude erledigt einen Schritt, sagt „soll ich mit Punkt zwei
weitermachen?" und wartet. Jedes Mal muss jemand „ja, mach weiter" tippen.

Die Lösung heißt **Stop-Hook**. Das ist ein kleines Skript, das Claude Code
automatisch startet, sobald Claude eine Antwort beendet hat. Gibt das Skript
`{"decision":"block"}` zurück, darf Claude nicht aufhören und arbeitet sofort
weiter — mit dem Auftrag, den das Skript mitgibt. Niemand tippt etwas.

Wichtig: Das Skript entscheidet nicht „weiter, weil ich Lust habe", sondern
**„weiter, solange in der Arbeitsliste noch etwas offen ist"**. Deshalb hört es
auch von selbst auf, wenn die Arbeit fertig ist.

## Einrichten

Im Projekt, in dem gearbeitet werden soll — also dort, wo die Dateien liegen:

```
bash /Pfad/zu/imo-bot/.claude/hooks/einrichten.sh ~/Mail_Agent
```

Danach Claude Code in dem Projekt neu starten. Das Skript legt drei Dinge an:

| Datei | Zweck |
|---|---|
| `.claude/hooks/weiterarbeiten.sh` | der Hook selbst |
| `.claude/worklist.md` | die Arbeitsliste — das Steuerrad |
| `.claude/settings.local.json` | schaltet den Hook ein |

## Benutzen

Die Arbeitsliste ist eine gewöhnliche Markdown-Datei mit Kästchen:

```markdown
## Offen

- [ ] Zimmer-Abschnitt: doppelt benannten Überschriftenblock entfernen
- [ ] Wellness: zwei ineinanderliegende Bereiche, inneren entnennen
- [ ] Danach Messwerkzeug erneut laufen lassen, Ergebnis in den Stand schreiben

## Fertig

- [x] Messwerkzeug gebaut
```

Ablauf: Claude beendet eine Antwort → der Hook findet den ersten offenen Punkt
→ er blockt und gibt genau diesen Punkt als nächsten Auftrag zurück → Claude
arbeitet ihn ab, hakt ihn mit `[x]` ab → nächste Runde. Sind alle Kästchen
abgehakt, lässt der Hook durch und Claude darf fertig werden.

Ein Punkt sollte eine Runde Arbeit sein und ohne Rückfrage bearbeitbar: Datei,
Stelle, Ziel. „Aufräumen" ist ein schlechter Punkt, „in `index.html` beim
Zimmer-Abschnitt das `aria-label` am 121-px-Block entfernen" ist ein guter.

## Bremsen

Drei Sicherungen, damit daraus keine Endlosschleife wird:

**Rundenlimit.** Nach 25 erzwungenen Runden macht der Hook eine Zwangspause
und meldet das. Ein beliebiges Wort setzt den Lauf fort. Anders einstellen:

```
export WEITER_MAX_RUNDEN=50
```

**Notbremse.** Hält den Hook sofort still, ohne ihn zu deinstallieren:

```
touch .claude/STOP     # aus
rm .claude/STOP        # wieder an
```

**Keine Liste, kein Zwang.** Ohne `.claude/worklist.md` mischt sich der Hook
überhaupt nicht ein. Löschen oder umbenennen reicht.

## Was der Hook nicht kann

Er hält Claude innerhalb einer laufenden Sitzung am Arbeiten. Er startet keine
neue Sitzung. Wenn du Claude Code beendest, ist Schluss — der Hook wartet
darauf, dass Claude antwortet, und ohne laufende Sitzung antwortet niemand.

Die echte Grenze ist ohnehin nicht der Anstoß, sondern der volle Chat. Genau
dagegen hilft die Arbeitsliste: sie steht auf der Festplatte, nicht im
Gesprächsverlauf. Nach einer Zusammenfassung liest der Hook dieselbe Datei und
gibt denselben nächsten Punkt aus. Der Stand überlebt.

## Wirklich unbeaufsichtigt: die zwei Stufen darüber

**Kopflos in einer Schleife** — Claude ohne Oberfläche, gesteuert von der
Shell. Läuft, solange das Terminal offen ist, und braucht keine Eingabe:

```bash
for i in $(seq 1 20); do
  claude -p "Arbeite den ersten offenen Punkt in .claude/worklist.md ab, \
hake ihn ab und schreibe den Stand dazu. Wenn alles abgehakt ist, \
antworte nur FERTIG." | tee -a lauf.log | grep -q FERTIG && break
done
```

Das ersetzt den Hook nicht, es ist der andere Weg zum selben Ziel: Die Schleife
liegt außen in der Shell statt innen im Hook. Für Nachtläufe auf dem Mac lässt
sich das über `launchd` zu einer festen Zeit starten.

**Serverseitige Zeitpläne** — nur in Claude Code im Browser, nicht im Terminal.
Dort laufen Aufträge in Anthropics Umgebung weiter, auch wenn Rechner und App
aus sind. Das ist die einzige Variante, die einen geschlossenen Laptop übersteht.
