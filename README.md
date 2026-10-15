# BookSwap

BookSwap ist ein Studienprojekt für den Kurs „Data-Mart-Erstellung in SQL“.
Die SQLite-Datenbank speichert Bücher, Mitglieder, Ausleihen und Reservierungen.
Alle Beispieldaten sind frei erfunden.

## Ordner

- `01_Konzeptionsphase`: Anforderungen und Beschreibung des Datenmodells.
- `02_Erarbeitungs-Reflexionsphase`: Präsentation, Zusammenfassung, SQL-Datei und erste Datenbank.
- `03_Finalisierungsphase`: Abschlussbericht, Abstract, Anleitung, fertige Datenbank und Sammel-PDF.

## Datenbank öffnen

Die fertige Datenbank liegt unter `03_Finalisierungsphase/bookswap.sqlite`.
Sie lässt sich mit einem Programm für SQLite öffnen.

## Datenbank neu erstellen

Dafür wird SQLite ab Version 3.45 benötigt. Im Ordner `03_Finalisierungsphase`
wird dieser Befehl ausgeführt:

```powershell
sqlite3 -bail bookswap_neu.sqlite ".read sql/01_schema.sql" ".read sql/02_regeln.sql" ".read sql/03_beispieldaten.sql"
```

`bookswap_neu.sqlite` muss dabei eine neue Datei sein.
Für die Nähesuche muss SQLite Mathematikfunktionen unterstützen.

Die weiteren SQL-Dateien enthalten Abfragen, Tests, Vergleiche der Abfragezeiten
und den Import der älteren Datenbank. Die genaue Anleitung und die Hinweise zu
den Tests stehen im Phase-3-Dokument mit der Endung `_SQL.pdf`.
