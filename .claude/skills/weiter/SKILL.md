---
description: Legt die Arbeitsliste des aktuellen Projekts an oder ergaenzt sie und arbeitet sie dann selbsttaetig durch, ohne nach jedem Schritt nachzufragen. Nutzen, wenn der Nutzer /weiter tippt, eine Liste von Aufgaben nennt, die ohne Zuruf abgearbeitet werden soll, oder verlangt, dass ohne Rueckfrage weitergearbeitet wird.
argument-hint: [neue Punkte, mit Semikolon getrennt -- oder leer, um fortzusetzen]
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cat:*), Bash(ls:*)
---

## Arbeitsliste dieses Projekts

!`cat .claude/worklist.md 2>/dev/null || echo "(noch keine Arbeitsliste in diesem Projekt)"`

## Neue Punkte vom Nutzer

$ARGUMENTS

## Anweisungen

Im lokalen Claude Code wird diese Arbeitsweise von einem Stop-Hook getragen:
Solange in `.claude/worklist.md` ein Punkt mit offenem Kaestchen `- [ ]` steht,
wird das Beenden der Antwort blockiert und der naechste offene Punkt als
Auftrag nachgeliefert. Der Nutzer muss also nichts tippen. In Cloud-Sitzungen
gibt es diesen Hook nicht -- dort gilt dasselbe Vorgehen aus eigenem Antrieb:
Punkt fuer Punkt abarbeiten, ohne zwischendurch nach Bestaetigung zu fragen.

1. **Neue Punkte eintragen.** Stehen oben unter "Neue Punkte vom Nutzer"
   Angaben, trage sie als `- [ ]` unter `## Offen` in `.claude/worklist.md`
   ein. Fehlt die Datei, lege sie mit dieser Struktur an:

   ```markdown
   # Arbeitsliste

   ## Offen

   - [ ] erster Punkt

   ## Fertig
   ```

   Schreibe jeden Punkt so, dass er ohne Rueckfrage bearbeitbar ist: Datei,
   Stelle und Ziel nennen. Teile zu grosse Punkte in mehrere auf.

2. **Ersten offenen Punkt abarbeiten.** Nimm den obersten `- [ ]` und
   bearbeite ihn vollstaendig. Frage nicht nach Bestaetigung und frage nicht,
   ob du weitermachen sollst.

3. **Abhaken und Stand schreiben.** Danach das Kaestchen auf `- [x]` setzen,
   die Zeile nach `## Fertig` verschieben und in einem Satz dazuschreiben, was
   herausgekommen ist. Das ist wichtig: Die Datei liegt auf der Festplatte und
   ueberlebt einen vollen Chat, der Gespraechsverlauf nicht.

4. **Stoesst du auf etwas Neues,** trage es als weiteren offenen Punkt ein,
   statt die Arbeit zu unterbrechen.

5. **Blockiert ein Punkt wirklich** -- fehlende Zugangsdaten, eine
   Entscheidung, die nur der Nutzer treffen kann -- dann hake ihn nicht ab,
   sondern schreibe die Frage in die Zeile und arbeite am naechsten Punkt
   weiter. Am Ende die offenen Fragen gesammelt nennen.

6. **Ist alles abgehakt,** sage das in einem Satz und hoere auf.

Bremsen, die der Nutzer kennt: Nach 25 erzwungenen Runden macht der Hook eine
Zwangspause. `touch .claude/STOP` haelt ihn sofort still, `rm .claude/STOP`
schaltet ihn wieder ein.
