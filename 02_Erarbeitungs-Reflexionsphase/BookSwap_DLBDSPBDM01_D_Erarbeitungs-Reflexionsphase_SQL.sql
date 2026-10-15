-- BookSwap Phase 2: vollständiger Aufbau und ergänzende SQL-Nachweise.
-- Nur in einer neuen, leeren Datenbank mit SQLite ab 3.45 ausführen.
-- Die Teile 01 bis 04 sind hier enthalten; nicht zusätzlich importieren.
-- Bei Fehler abbrechen und ROLLBACK ausführen, sonst den Aufbau mit COMMIT beenden.
-- Danach folgen fünf inaktive Ergänzungen. Nur den gewünschten Blockinhalt
-- ohne äußere Kommentarzeichen in einen separaten SQL-Editor kopieren.
-- Tests einzeln zurückrollen; Benchmark-Daten nur in einer eigenen Kopie nutzen.
-- foreign_keys und recursive_triggers müssen vor BEGIN aktiv sein.
PRAGMA foreign_keys=ON;
PRAGMA recursive_triggers=ON;
BEGIN IMMEDIATE;

PRAGMA foreign_keys = ON;
PRAGMA recursive_triggers = ON;

-- Adressen, Mitglieder und Buchkatalog.
CREATE TABLE adresse (
 adresse_id INTEGER PRIMARY KEY,
 strasse TEXT NOT NULL CHECK (strasse = trim(strasse) AND length(strasse)>0),
 hausnummer TEXT NOT NULL CHECK (hausnummer = trim(hausnummer) AND length(hausnummer)>0),
 plz TEXT NOT NULL CHECK (plz = trim(plz) AND length(plz)>0),
 ort TEXT NOT NULL CHECK (ort = trim(ort) AND length(ort)>0),
 land TEXT NOT NULL DEFAULT 'DE' CHECK (land GLOB '[A-Z][A-Z]'),
 latitude REAL NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude REAL NOT NULL CHECK (longitude BETWEEN -180 AND 180)
) STRICT;

CREATE TABLE benutzer (
 benutzer_id INTEGER PRIMARY KEY,
 name TEXT NOT NULL CHECK (name = trim(name) AND length(name)>0),
 email TEXT NOT NULL UNIQUE CHECK (
   email = lower(email) AND email NOT GLOB '*[^!-~]*'
   AND email LIKE '_%@_%._%' AND length(email)-length(replace(email,'@',''))=1),
 adresse_id INTEGER NOT NULL REFERENCES adresse(adresse_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) STRICT;

CREATE TABLE verlag (
 verlag_id INTEGER PRIMARY KEY,
 name TEXT NOT NULL CHECK (name = trim(name) AND length(name)>0)
) STRICT;
CREATE TABLE sprache (
 sprache_id INTEGER PRIMARY KEY,
 code TEXT NOT NULL UNIQUE CHECK (code = trim(code) AND length(code)>0),
 name TEXT NOT NULL UNIQUE CHECK (name = trim(name) AND length(name)>0)
) STRICT;
CREATE TABLE buch (
 buch_id INTEGER PRIMARY KEY,
 titel TEXT NOT NULL CHECK (titel = trim(titel) AND length(titel)>0),
 jahr INTEGER NOT NULL CHECK (jahr BETWEEN 1 AND 9999),
 verlag_id INTEGER NOT NULL REFERENCES verlag(verlag_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 sprache_id INTEGER NOT NULL REFERENCES sprache(sprache_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) STRICT;
CREATE TABLE autor (
 autor_id INTEGER PRIMARY KEY,
 name TEXT NOT NULL CHECK (name = trim(name) AND length(name)>0)
) STRICT;
CREATE TABLE buch_autor (
 buch_id INTEGER NOT NULL REFERENCES buch(buch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 autor_id INTEGER NOT NULL REFERENCES autor(autor_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 PRIMARY KEY (buch_id, autor_id)
) STRICT;
CREATE TABLE genre (
 genre_id INTEGER PRIMARY KEY,
 name TEXT NOT NULL UNIQUE CHECK (name = trim(name) AND length(name)>0)
) STRICT;
CREATE TABLE buch_genre (
 buch_id INTEGER NOT NULL REFERENCES buch(buch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 genre_id INTEGER NOT NULL REFERENCES genre(genre_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 PRIMARY KEY (buch_id, genre_id)
) STRICT;
-- Exemplare mit Angebotsbedingungen; diese Phase versioniert Bedingungen noch nicht.
CREATE TABLE exemplar (
 exemplar_id INTEGER PRIMARY KEY,
 buch_id INTEGER NOT NULL REFERENCES buch(buch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 eigentuemer_id INTEGER NOT NULL REFERENCES benutzer(benutzer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 abholadresse_id INTEGER NOT NULL REFERENCES adresse(adresse_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 zustand TEXT NOT NULL CHECK (zustand IN ('neu','gut','gebraucht')),
 max_tage INTEGER NOT NULL CHECK (max_tage BETWEEN 1 AND 365),
 versand INTEGER NOT NULL DEFAULT 0 CHECK (versand IN (0,1)),
 angeboten INTEGER NOT NULL DEFAULT 0 CHECK (angeboten IN (0,1))
) STRICT;
-- Abholfenster und Ausleihen; Zeiten sind kanonische UTC-Werte.
CREATE TABLE abholzeit (
 abholzeit_id INTEGER PRIMARY KEY,
 exemplar_id INTEGER NOT NULL REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 von TEXT NOT NULL CHECK (length(von)=19 AND substr(von,1,4) BETWEEN '0001' AND '9999'
   AND datetime(von,'+0 seconds') IS NOT NULL AND datetime(von,'+0 seconds')=von),
 bis TEXT NOT NULL CHECK (length(bis)=19 AND substr(bis,1,4) BETWEEN '0001' AND '9999'
   AND datetime(bis,'+0 seconds') IS NOT NULL AND datetime(bis,'+0 seconds')=bis AND bis>von),
 UNIQUE (exemplar_id, von, bis)
) STRICT;
CREATE TABLE ausleihe (
 ausleihe_id INTEGER PRIMARY KEY,
 exemplar_id INTEGER NOT NULL REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 entleiher_id INTEGER NOT NULL REFERENCES benutzer(benutzer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 beginn TEXT NOT NULL CHECK (length(beginn)=19 AND substr(beginn,1,4) BETWEEN '0001' AND '9999'
   AND datetime(beginn,'+0 seconds') IS NOT NULL AND datetime(beginn,'+0 seconds')=beginn),
 faellig TEXT NOT NULL CHECK (length(faellig)=19 AND substr(faellig,1,4) BETWEEN '0001' AND '9999'
   AND datetime(faellig,'+0 seconds') IS NOT NULL AND datetime(faellig,'+0 seconds')=faellig AND faellig>beginn),
 rueckgabe TEXT CHECK (rueckgabe IS NULL OR (length(rueckgabe)=19
   AND substr(rueckgabe,1,4) BETWEEN '0001' AND '9999'
   AND datetime(rueckgabe,'+0 seconds') IS NOT NULL
   AND datetime(rueckgabe,'+0 seconds')=rueckgabe AND rueckgabe>=beginn)),
 weg TEXT NOT NULL DEFAULT 'abholung' CHECK (weg IN ('abholung','post'))
) STRICT;
-- Höchstens eine Bewertung je abgeschlossener Ausleihe.
CREATE TABLE bewertung (
 bewertung_id INTEGER PRIMARY KEY,
 ausleihe_id INTEGER NOT NULL UNIQUE REFERENCES ausleihe(ausleihe_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 sterne INTEGER NOT NULL CHECK (sterne BETWEEN 1 AND 5),
 kommentar TEXT
) STRICT;

-- Angebote brauchen Autor und Genre; benutzte Stammdaten bleiben geschützt.
CREATE TRIGGER exemplar_angebot_insert BEFORE INSERT ON exemplar WHEN NEW.angeboten=1
BEGIN
 SELECT RAISE(ABORT,'ANGEBOT_KATALOG') WHERE
  NOT EXISTS (SELECT 1 FROM buch_autor WHERE buch_id=NEW.buch_id)
  OR NOT EXISTS (SELECT 1 FROM buch_genre WHERE buch_id=NEW.buch_id);
END;
CREATE TRIGGER exemplar_angebot_update BEFORE UPDATE ON exemplar WHEN NEW.angeboten=1
BEGIN
 SELECT RAISE(ABORT,'ANGEBOT_KATALOG') WHERE
  NOT EXISTS (SELECT 1 FROM buch_autor WHERE buch_id=NEW.buch_id)
  OR NOT EXISTS (SELECT 1 FROM buch_genre WHERE buch_id=NEW.buch_id);
END;
CREATE TRIGGER exemplar_historie_update BEFORE UPDATE ON exemplar
BEGIN
 SELECT RAISE(ABORT,'EXEMPLAR_HISTORIE') WHERE
  (NEW.exemplar_id<>OLD.exemplar_id OR NEW.buch_id<>OLD.buch_id OR NEW.eigentuemer_id<>OLD.eigentuemer_id)
  AND EXISTS (SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id);
 SELECT RAISE(ABORT,'EXEMPLAR_LAUFEND') WHERE
  (NEW.abholadresse_id<>OLD.abholadresse_id OR NEW.max_tage<>OLD.max_tage OR NEW.versand<>OLD.versand
   OR NEW.angeboten<>OLD.angeboten OR NEW.zustand<>OLD.zustand)
  AND EXISTS (SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND rueckgabe IS NULL);
END;
CREATE TRIGGER exemplar_historie_delete BEFORE DELETE ON exemplar
WHEN EXISTS (SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id)
BEGIN SELECT RAISE(ABORT,'EXEMPLAR_HISTORIE'); END;

CREATE TRIGGER autor_zuordnung_delete BEFORE DELETE ON buch_autor
WHEN EXISTS (SELECT 1 FROM exemplar WHERE buch_id=OLD.buch_id AND angeboten=1)
 AND NOT EXISTS (SELECT 1 FROM buch_autor WHERE buch_id=OLD.buch_id AND autor_id<>OLD.autor_id)
BEGIN SELECT RAISE(ABORT,'LETZTER_AUTOR'); END;
CREATE TRIGGER autor_zuordnung_update BEFORE UPDATE ON buch_autor WHEN NEW.buch_id<>OLD.buch_id
 AND EXISTS (SELECT 1 FROM exemplar WHERE buch_id=OLD.buch_id AND angeboten=1)
 AND NOT EXISTS (SELECT 1 FROM buch_autor WHERE buch_id=OLD.buch_id AND autor_id<>OLD.autor_id)
BEGIN SELECT RAISE(ABORT,'LETZTER_AUTOR'); END;
CREATE TRIGGER genre_zuordnung_delete BEFORE DELETE ON buch_genre
WHEN EXISTS (SELECT 1 FROM exemplar WHERE buch_id=OLD.buch_id AND angeboten=1)
 AND NOT EXISTS (SELECT 1 FROM buch_genre WHERE buch_id=OLD.buch_id AND genre_id<>OLD.genre_id)
BEGIN SELECT RAISE(ABORT,'LETZTES_GENRE'); END;
CREATE TRIGGER genre_zuordnung_update BEFORE UPDATE ON buch_genre WHEN NEW.buch_id<>OLD.buch_id
 AND EXISTS (SELECT 1 FROM exemplar WHERE buch_id=OLD.buch_id AND angeboten=1)
 AND NOT EXISTS (SELECT 1 FROM buch_genre WHERE buch_id=OLD.buch_id AND genre_id<>OLD.genre_id)
BEGIN SELECT RAISE(ABORT,'LETZTES_GENRE'); END;

-- Ausleihregeln: Eigentum, Angebot, Frist, Versand, Abholfenster und Überschneidung.
CREATE TRIGGER ausleihe_insert BEFORE INSERT ON ausleihe
BEGIN
 SELECT RAISE(ABORT,'SELBSTAUSLEIHE') WHERE EXISTS (
  SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id AND eigentuemer_id=NEW.entleiher_id);
 SELECT RAISE(ABORT,'KEIN_ANGEBOT') WHERE EXISTS (
  SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id AND angeboten=0);
 SELECT RAISE(ABORT,'LEIHDAUER') WHERE unixepoch(NEW.faellig)-unixepoch(NEW.beginn) >
  (SELECT max_tage*86400 FROM exemplar WHERE exemplar_id=NEW.exemplar_id);
 SELECT RAISE(ABORT,'VERSAND_NICHT_ERLAUBT') WHERE NEW.weg='post' AND EXISTS (
  SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id AND versand=0);
 SELECT RAISE(ABORT,'ABHOLZEIT_FEHLT') WHERE NEW.weg='abholung' AND NOT EXISTS (
  SELECT 1 FROM abholzeit WHERE exemplar_id=NEW.exemplar_id AND von<=NEW.beginn AND NEW.beginn<bis);
 -- Laufende Intervalle reichen nach +unendlich, nicht bloß bis zur Fälligkeit.
 SELECT RAISE(ABORT,'AUSLEIHE_UEBERLAPPT') WHERE EXISTS (
  SELECT 1 FROM ausleihe a WHERE a.exemplar_id=NEW.exemplar_id
  AND (NEW.rueckgabe IS NULL OR a.beginn<NEW.rueckgabe)
  AND (a.rueckgabe IS NULL OR NEW.beginn<a.rueckgabe));
END;
-- Vertragsdaten und Rückgaben bleiben erhalten.
CREATE TRIGGER ausleihe_update BEFORE UPDATE ON ausleihe
BEGIN
 SELECT RAISE(ABORT,'AUSLEIHE_UNVERAENDERLICH') WHERE
  NEW.ausleihe_id<>OLD.ausleihe_id OR NEW.exemplar_id<>OLD.exemplar_id
  OR NEW.entleiher_id<>OLD.entleiher_id OR NEW.beginn<>OLD.beginn
  OR NEW.faellig<>OLD.faellig OR NEW.weg<>OLD.weg;
 SELECT RAISE(ABORT,'RUECKGABE_UNVERAENDERLICH') WHERE OLD.rueckgabe IS NOT NULL
  AND NEW.rueckgabe IS NOT OLD.rueckgabe;
 SELECT RAISE(ABORT,'AUSLEIHE_UEBERLAPPT') WHERE EXISTS (
  SELECT 1 FROM ausleihe a WHERE a.exemplar_id=NEW.exemplar_id AND a.ausleihe_id<>OLD.ausleihe_id
  AND (NEW.rueckgabe IS NULL OR a.beginn<NEW.rueckgabe)
  AND (a.rueckgabe IS NULL OR NEW.beginn<a.rueckgabe));
END;
CREATE TRIGGER ausleihe_delete BEFORE DELETE ON ausleihe
BEGIN SELECT RAISE(ABORT,'AUSLEIHE_HISTORIE'); END;
-- Bereits genutzte Abholfenster und Adressen bleiben geschützt.
CREATE TRIGGER abholzeit_update BEFORE UPDATE ON abholzeit
WHEN EXISTS (SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND weg='abholung'
 AND beginn>=OLD.von AND beginn<OLD.bis)
BEGIN SELECT RAISE(ABORT,'ABHOLZEIT_HISTORIE'); END;
CREATE TRIGGER abholzeit_delete BEFORE DELETE ON abholzeit
WHEN EXISTS (SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND weg='abholung'
 AND beginn>=OLD.von AND beginn<OLD.bis)
BEGIN SELECT RAISE(ABORT,'ABHOLZEIT_HISTORIE'); END;
CREATE TRIGGER adresse_historie_update BEFORE UPDATE ON adresse
WHEN EXISTS (SELECT 1 FROM exemplar e JOIN ausleihe a ON a.exemplar_id=e.exemplar_id
 WHERE e.abholadresse_id=OLD.adresse_id)
BEGIN SELECT RAISE(ABORT,'ADRESSE_HISTORIE'); END;
-- Bewertungen erst nach Rückgabe.
CREATE TRIGGER bewertung_insert BEFORE INSERT ON bewertung
WHEN EXISTS (SELECT 1 FROM ausleihe WHERE ausleihe_id=NEW.ausleihe_id AND rueckgabe IS NULL)
BEGIN SELECT RAISE(ABORT,'BEWERTUNG_VOR_RUECKGABE'); END;
CREATE TRIGGER bewertung_update BEFORE UPDATE ON bewertung
WHEN EXISTS (SELECT 1 FROM ausleihe WHERE ausleihe_id=NEW.ausleihe_id AND rueckgabe IS NULL)
BEGIN SELECT RAISE(ABORT,'BEWERTUNG_VOR_RUECKGABE'); END;

-- Ein laufender Vorgang je Exemplar; weitere Indizes unterstützen gezielte Suchen.
CREATE UNIQUE INDEX uq_ausleihe_laufend ON ausleihe(exemplar_id) WHERE rueckgabe IS NULL;
CREATE INDEX ix_ausleihe_exemplar_beginn ON ausleihe(exemplar_id,beginn);
CREATE INDEX ix_ausleihe_entleiher_beginn ON ausleihe(entleiher_id,beginn);
CREATE INDEX ix_benutzer_adresse ON benutzer(adresse_id);
CREATE INDEX ix_buch_verlag ON buch(verlag_id);
CREATE INDEX ix_buch_sprache ON buch(sprache_id);
CREATE INDEX ix_buch_autor_autor ON buch_autor(autor_id,buch_id);
CREATE INDEX ix_buch_genre_genre ON buch_genre(genre_id,buch_id);
CREATE INDEX ix_exemplar_buch ON exemplar(buch_id);
CREATE INDEX ix_exemplar_eigentuemer ON exemplar(eigentuemer_id);
CREATE INDEX ix_exemplar_adresse ON exemplar(abholadresse_id);
CREATE INDEX ix_adresse_koordinaten ON adresse(latitude,longitude);

-- Fiktiver Grundbestand; feste Werte für reproduzierbare Abfragen.
INSERT INTO adresse VALUES
 (1,'Testweg','1','10115','Teststadt','DE',52.52,13.405),
 (2,'Lesegasse','2','10115','Teststadt','DE',52.525,13.41),
 (3,'Papierweg','3','10115','Teststadt','DE',52.53,13.415),
 (4,'Buchplatz','4','10115','Teststadt','DE',52.54,13.43),
 (5,'Seitenweg','5','10115','Teststadt','DE',52.60,13.50),
 (6,'Wortweg','6','20000','Fernstadt','DE',53.55,10.0),
 (7,'Satzweg','7','30000','Weststadt','DE',48.14,11.58),
 (8,'Inselweg','8','00008','Ostinsel','FJ',0.0,179.9),
 (9,'Inselweg','9','00009','Westinsel','FJ',0.0,-179.9),
 (10,'Polarweg','10','00010','Polarstation','NO',90.0,0.0),
 (11,'Polarring','11','00011','Polarstation','NO',90.0,150.0),
 (12,'Nullweg','12','00012','Nullinsel','GH',0.0,0.0);
INSERT INTO benutzer VALUES
 (1,'Mira Test','mira@example.invalid',1),(2,'Noah Test','noah@example.invalid',2),
 (3,'Alina Test','alina@example.invalid',3),(4,'Emil Test','emil@example.invalid',4),
 (5,'Lina Test','lina@example.invalid',5),(6,'Oskar Test','oskar@example.invalid',6),
 (7,'Sami Test','sami@example.invalid',7),(8,'Jona Test','jona@example.invalid',8),
 (9,'Nora Test','nora@example.invalid',9),(10,'Tara Test','tara@example.invalid',10),
 (11,'Elin Test','elin@example.invalid',11),(12,'Robin Test','robin@example.invalid',12);
INSERT INTO verlag VALUES
 (1,'Demo Nordlicht'),(2,'Demo Seitenwind'),(3,'Demo Papierwald'),(4,'Demo Wortstrom'),
 (5,'Demo Leseraum'),(6,'Demo Buchinsel'),(7,'Demo Kapitel'),(8,'Demo Tintenhaus'),
 (9,'Demo Federweg'),(10,'Demo Schriftgarten');
INSERT INTO sprache VALUES
 (1,'de','Deutsch'),(2,'en','Englisch'),(3,'fr','Französisch'),(4,'es','Spanisch'),
 (5,'it','Italienisch'),(6,'pt','Portugiesisch'),(7,'nl','Niederländisch'),
 (8,'sv','Schwedisch'),(9,'pl','Polnisch'),(10,'da','Dänisch');
INSERT INTO buch VALUES
 (1,'Der Garten am Testfluss',2020,1,1),(2,'A Map of Paper',2021,2,2),
 (3,'La maison des pages',2022,3,3),(4,'El camino del libro',2023,4,4),
 (5,'Il giardino di carta',2020,5,5),(6,'O vento das letras',2021,6,6),
 (7,'Het papieren eiland',2022,7,7),(8,'Bokens väg',2023,8,8),
 (9,'Papierowy ogród',2024,9,9),(10,'Bogens have',2025,10,10),
 (11,'Wege durch Teststadt',2026,1,1),(12,'Die stille Sternwarte',2026,2,1);
INSERT INTO autor VALUES
 (1,'Ari Muster'),(2,'Bo Muster'),(3,'Cleo Muster'),(4,'Dara Muster'),(5,'Eli Muster'),
 (6,'Fara Muster'),(7,'Gero Muster'),(8,'Hedi Muster'),(9,'Ivo Muster'),(10,'Jule Muster');
INSERT INTO buch_autor VALUES
 (1,1),(1,2),(2,2),(3,3),(4,4),(5,5),(6,6),(7,7),(8,8),(9,9),(10,10),(11,1),(12,2);
INSERT INTO genre VALUES
 (1,'Roman'),(2,'Krimi'),(3,'Fantasy'),(4,'Sachbuch'),(5,'Lyrik'),
 (6,'Abenteuer'),(7,'Biografie'),(8,'Science-Fiction'),(9,'Kinderbuch'),(10,'Reise');
INSERT INTO buch_genre VALUES
 (1,1),(1,6),(2,2),(3,3),(4,4),(5,5),(6,6),(7,7),(8,8),(9,9),(10,10),(11,10),(12,8);
INSERT INTO exemplar VALUES
 (1,1,1,1,'gut',14,0,1),(2,2,2,2,'neu',14,1,1),
 (3,3,3,3,'gebraucht',21,0,1),(4,4,4,4,'gut',21,1,1),
 (5,5,5,5,'neu',30,0,1),(6,6,6,6,'gut',30,1,1),
 (7,7,7,7,'gebraucht',14,0,1),(8,8,8,8,'gut',14,1,1),
 (9,9,9,9,'neu',21,0,1),(10,10,10,10,'gut',21,1,1),
 (11,11,11,11,'gut',14,0,1),(12,12,12,12,'neu',14,1,1),
 (13,1,1,1,'gut',14,0,1),(14,2,2,2,'gut',14,1,1),
 (15,3,3,3,'gut',14,0,1),(16,4,4,4,'gut',14,1,1),
 (17,5,5,5,'gut',14,0,1),(18,6,6,6,'gut',14,1,1),
 (19,7,7,7,'gut',14,0,1),(20,8,8,8,'gut',14,1,1),
 (21,9,9,9,'gut',14,0,1),(22,10,10,10,'gut',14,1,1),
 (23,11,11,11,'gut',14,0,1),(24,12,12,12,'gut',14,1,0);
INSERT INTO abholzeit (abholzeit_id,exemplar_id,von,bis)
 SELECT exemplar_id,exemplar_id,'2026-09-01 09:00:00','2026-09-01 18:00:00' FROM exemplar;
INSERT INTO abholzeit (abholzeit_id,exemplar_id,von,bis)
 SELECT 100+exemplar_id,exemplar_id,'2026-10-03 09:00:00','2026-10-03 18:00:00' FROM exemplar;
INSERT INTO ausleihe VALUES
 (1,1,2,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-16 10:00:00','abholung'),
 (2,2,3,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','post'),
 (3,3,4,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','abholung'),
 (4,4,5,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','post'),
 (5,5,6,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','abholung'),
 (6,6,7,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','post'),
 (7,7,8,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','abholung'),
 (8,8,9,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','post'),
 (9,9,10,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','abholung'),
 (10,10,11,'2026-09-01 10:00:00','2026-09-15 10:00:00','2026-09-10 10:00:00','post'),
 (11,11,12,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'abholung'),
 (12,12,1,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'post');
INSERT INTO bewertung VALUES
 (1,1,5,'Spannender Testroman'),(2,2,4,'Gut lesbar'),(3,3,3,'Ruhige Geschichte'),
 (4,4,5,'Hilfreiche Darstellung'),(5,5,4,NULL),(6,6,3,'Solides Abenteuer'),
 (7,7,4,'Interessante Perspektive'),(8,8,5,'Anregende Zukunftsidee'),
 (9,9,4,'Kurze Kapitel'),(10,10,3,NULL);

-- Verfügbarkeit und Durchschnittsbewertungen werden durch Sichten abgeleitet.
CREATE VIEW v_verfuegbare_buecher AS
SELECT e.exemplar_id,b.buch_id,b.titel,e.eigentuemer_id,e.abholadresse_id,
       e.zustand,e.max_tage,e.versand,a.ort,a.latitude,a.longitude
FROM exemplar e JOIN buch b ON b.buch_id=e.buch_id
JOIN adresse a ON a.adresse_id=e.abholadresse_id
WHERE e.angeboten=1 AND NOT EXISTS (
 SELECT 1 FROM ausleihe l WHERE l.exemplar_id=e.exemplar_id AND l.rueckgabe IS NULL);
CREATE VIEW v_buchbewertungen AS
SELECT b.buch_id,b.titel,COUNT(w.bewertung_id) AS anzahl,AVG(w.sterne) AS durchschnitt
FROM buch b LEFT JOIN exemplar e ON e.buch_id=b.buch_id
LEFT JOIN ausleihe l ON l.exemplar_id=e.exemplar_id
LEFT JOIN bewertung w ON w.ausleihe_id=l.ausleihe_id
GROUP BY b.buch_id,b.titel;

COMMIT;
PRAGMA integrity_check;
PRAGMA foreign_key_check;

-- BOOKSWAP-SUPPLEMENTS-BEGIN v1

-- BOOKSWAP-SECTION-BEGIN 05_queries
/*
-- Benannte SELECTs einzeln auf dem Grundbestand ausführen; Kennungen beibehalten.

-- query: J1
SELECT b.buch_id,b.titel,a.name AS autor
FROM buch b JOIN buch_autor ba USING(buch_id) JOIN autor a USING(autor_id)
WHERE b.buch_id=1 ORDER BY a.autor_id;

-- query: J2
SELECT b.titel,e.exemplar_id,a.latitude,a.longitude
FROM buch b JOIN exemplar e USING(buch_id) JOIN adresse a ON a.adresse_id=e.abholadresse_id
WHERE e.exemplar_id=13;

-- query: J3
SELECT u.name,l.ausleihe_id,e.exemplar_id,l.beginn,l.rueckgabe
FROM benutzer u JOIN ausleihe l ON l.entleiher_id=u.benutzer_id
JOIN exemplar e USING(exemplar_id) WHERE u.benutzer_id=2 ORDER BY l.beginn;

-- query: KARTE
SELECT exemplar_id,titel,latitude,longitude FROM v_verfuegbare_buecher
WHERE latitude BETWEEN 52.51 AND 52.54 AND longitude BETWEEN 13.40 AND 13.43
ORDER BY exemplar_id;

-- query: BEWERTUNGEN
SELECT * FROM v_buchbewertungen WHERE anzahl>0 ORDER BY durchschnitt DESC,buch_id;

-- query: FAELLIG
SELECT ausleihe_id,exemplar_id,faellig FROM ausleihe
WHERE rueckgabe IS NULL AND faellig<'2026-10-18 00:00:00' ORDER BY ausleihe_id;
*/
-- BOOKSWAP-SECTION-END 05_queries

-- BOOKSWAP-SECTION-BEGIN 05_nearby
/*
-- Numerische Parameter :lat, :lon, :radius_km; SQLite-Math erforderlich.
-- Beispiel: 52.52, 13.405, 2 ergibt IDs 1, 13, 2, 14, 3, 15.
-- Sphärische Luftlinie mit 6371 km Erdradius; ungültige Parameter ergeben keine Treffer.
-- Breitenband als Vorfilter, Haversine-Distanz mit Rundungstoleranz.

WITH parameter AS (
 SELECT :lat AS lat,:lon AS lon,:radius_km AS radius_km
 WHERE typeof(:lat) IN ('integer','real') AND :lat BETWEEN -90 AND 90
 AND typeof(:lon) IN ('integer','real') AND :lon BETWEEN -180 AND 180
 AND typeof(:radius_km) IN ('integer','real') AND :radius_km BETWEEN 0 AND 1.0e100
), kandidaten AS (
 SELECT v.*,p.radius_km,
   CASE WHEN abs(v.latitude)=90 AND v.latitude=p.lat THEN 0.0 ELSE
   pow(sin(radians(v.latitude-p.lat)/2),2)
   +cos(radians(p.lat))*cos(radians(v.latitude))*pow(sin(radians(v.longitude-p.lon)/2),2)
   END AS h
 FROM parameter p JOIN v_verfuegbare_buecher v
 ON v.latitude BETWEEN max(-90,p.lat-degrees(p.radius_km/6371.0)-1e-10)
                       AND min(90,p.lat+degrees(p.radius_km/6371.0)+1e-10)
), distanzen AS (
 SELECT exemplar_id,titel,latitude,longitude,radius_km,
        12742.0*asin(sqrt(min(1.0,max(0.0,h)))) AS entfernung_km
 FROM kandidaten
)
SELECT exemplar_id,titel,latitude,longitude,entfernung_km FROM distanzen
WHERE entfernung_km<=radius_km+1e-9 ORDER BY entfernung_km,exemplar_id;
*/
-- BOOKSWAP-SECTION-END 05_nearby

-- BOOKSWAP-SECTION-BEGIN 06_tests
/*
-- Jeweils genau einen Fall ab -- case: auf dem Grundbestand ausführen.
-- PRAGMAs vor SAVEPOINT aktivieren. Vorher: SAVEPOINT einzeltest;
-- Danach, auch bei erwartetem Fehler: ROLLBACK TO einzeltest; RELEASE einzeltest;
-- rows bezeichnet den JSON-Sollwert, error den erwarteten Fehlertext.
-- Die letzte Anweisung prüft den Fall. Niemals den gesamten Katalog importieren.

-- case: SELF_INSERT | error | SELBSTAUSLEIHE
INSERT INTO ausleihe VALUES(100,13,1,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'abholung');

-- case: SELF_UPDATE | error | AUSLEIHE_UNVERAENDERLICH
UPDATE ausleihe SET entleiher_id=12 WHERE ausleihe_id=12;

-- case: INACTIVE | error | KEIN_ANGEBOT
INSERT INTO ausleihe VALUES(100,24,1,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'post');

-- case: DURATION_EXACT | rows | [[1209600]]
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'abholung');
SELECT unixepoch(faellig)-unixepoch(beginn) FROM ausleihe WHERE ausleihe_id=100;

-- case: DURATION_PLUS_SECOND | error | LEIHDAUER
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-17 10:00:01',NULL,'abholung');

-- case: DURATION_UPDATE | error | AUSLEIHE_UNVERAENDERLICH
UPDATE ausleihe SET faellig='2027-01-01 00:00:00' WHERE ausleihe_id=12;

-- case: DURATION_ZERO | error | CHECK constraint failed
INSERT INTO ausleihe VALUES(100,14,3,'2026-10-03 10:00:00','2026-10-03 10:00:00',NULL,'post');

-- case: PARALLEL | error | AUSLEIHE_UEBERLAPPT
INSERT INTO ausleihe VALUES(100,12,2,'2026-10-04 10:00:00','2026-10-10 10:00:00',NULL,'post');

-- case: HISTORIC_OVERLAP | error | AUSLEIHE_UEBERLAPPT
INSERT INTO ausleihe VALUES(100,2,4,'2026-09-02 10:00:00','2026-09-05 10:00:00','2026-09-04 10:00:00','post');

-- case: HISTORIC_ENCLOSE | error | AUSLEIHE_UEBERLAPPT
INSERT INTO ausleihe VALUES(100,2,4,'2026-08-31 10:00:00','2026-09-14 10:00:00','2026-09-20 10:00:00','post');

-- case: ADJACENT | rows | [[2]]
INSERT INTO ausleihe VALUES(100,2,4,'2026-09-10 10:00:00','2026-09-20 10:00:00','2026-09-15 10:00:00','post');
SELECT COUNT(*) FROM ausleihe WHERE exemplar_id=2;

-- case: OVERLAP_BY_UPDATE | error | AUSLEIHE_UNVERAENDERLICH
UPDATE ausleihe SET exemplar_id=12 WHERE ausleihe_id=11;

-- case: POST_VALID | rows | [["post"]]
INSERT INTO ausleihe VALUES(100,14,3,'2026-10-03 23:00:00','2026-10-04 23:00:00',NULL,'post');
SELECT weg FROM ausleihe WHERE ausleihe_id=100;

-- case: POST_FORBIDDEN | error | VERSAND_NICHT_ERLAUBT
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-10 10:00:00',NULL,'post');

-- case: PICKUP_START | rows | [["abholung"]]
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 09:00:00','2026-10-10 09:00:00',NULL,'abholung');
SELECT weg FROM ausleihe WHERE ausleihe_id=100;

-- case: PICKUP_LAST_SECOND | rows | [[1]]
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 17:59:59','2026-10-10 17:59:59',NULL,'abholung');
SELECT COUNT(*) FROM ausleihe WHERE ausleihe_id=100;

-- case: PICKUP_END_EXCLUDED | error | ABHOLZEIT_FEHLT
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 18:00:00','2026-10-10 18:00:00',NULL,'abholung');

-- case: PICKUP_MISSING | error | ABHOLZEIT_FEHLT
DELETE FROM abholzeit WHERE exemplar_id=13;
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-10 10:00:00',NULL,'abholung');

-- case: PICKUP_TRIPLE_UNIQUE | error | UNIQUE constraint failed
INSERT INTO abholzeit VALUES(999,13,'2026-10-03 09:00:00','2026-10-03 18:00:00');

-- case: PICKUP_SAME_START_OTHER_END | rows | [[3]]
INSERT INTO abholzeit VALUES(999,13,'2026-10-03 09:00:00','2026-10-03 19:00:00');
SELECT COUNT(*) FROM abholzeit WHERE exemplar_id=13;

-- case: PICKUP_INVERTED | error | CHECK constraint failed
INSERT INTO abholzeit VALUES(999,13,'2026-10-03 09:00:00','2026-10-03 08:00:00');

-- case: PICKUP_HISTORY_DELETE | error | ABHOLZEIT_HISTORIE
DELETE FROM abholzeit WHERE abholzeit_id=1;

-- case: PICKUP_HISTORY_UPDATE | error | ABHOLZEIT_HISTORIE
UPDATE abholzeit SET bis='2026-09-01 09:30:00' WHERE abholzeit_id=1;

-- case: RATING_EARLY | error | BEWERTUNG_VOR_RUECKGABE
INSERT INTO bewertung VALUES(100,12,4,'Zu früh');

-- case: RATING_UPDATE_EARLY | error | BEWERTUNG_VOR_RUECKGABE
UPDATE bewertung SET ausleihe_id=12 WHERE bewertung_id=1;

-- case: RETURN_THEN_RATE | rows | [[5]]
UPDATE ausleihe SET rueckgabe='2026-10-05 10:00:00' WHERE ausleihe_id=12;
INSERT INTO bewertung VALUES(100,12,5,'Zurückgegeben');
SELECT sterne FROM bewertung WHERE bewertung_id=100;

-- case: RATING_TWICE | error | UNIQUE constraint failed
INSERT INTO bewertung VALUES(100,1,4,NULL);

-- case: RETURN_LATE | rows | [[1]]
UPDATE ausleihe SET rueckgabe='2026-11-01 10:00:00' WHERE ausleihe_id=12;
SELECT rueckgabe>faellig FROM ausleihe WHERE ausleihe_id=12;

-- case: RETURN_BEFORE_BEGIN | error | CHECK constraint failed
UPDATE ausleihe SET rueckgabe='2026-10-02 10:00:00' WHERE ausleihe_id=12;

-- case: RETURN_REOPEN | error | RUECKGABE_UNVERAENDERLICH
UPDATE ausleihe SET rueckgabe=NULL WHERE ausleihe_id=1;

-- case: RETURN_CHANGE | error | RUECKGABE_UNVERAENDERLICH
UPDATE ausleihe SET rueckgabe='2026-09-18 10:00:00' WHERE ausleihe_id=1;

-- case: CONTRACT_DELETE | error | AUSLEIHE_HISTORIE
DELETE FROM ausleihe WHERE ausleihe_id=12;

-- case: CONTRACT_REPLACE | error | AUSLEIHE_HISTORIE
INSERT OR REPLACE INTO ausleihe VALUES(2,14,3,'2026-10-03 23:00:00','2026-10-04 23:00:00',NULL,'post');

-- case: OWNER_HISTORY | error | EXEMPLAR_HISTORIE
UPDATE exemplar SET eigentuemer_id=2 WHERE exemplar_id=1;

-- case: BOOK_HISTORY | error | EXEMPLAR_HISTORIE
UPDATE exemplar SET buch_id=2 WHERE exemplar_id=1;

-- case: CONDITIONS_RUNNING | error | EXEMPLAR_LAUFEND
UPDATE exemplar SET versand=0 WHERE exemplar_id=12;

-- case: CONDITIONS_FUTURE | rows | [[1]]
UPDATE exemplar SET max_tage=1 WHERE exemplar_id=2;
SELECT COUNT(*) FROM ausleihe WHERE ausleihe_id=2 AND faellig='2026-09-15 10:00:00';

-- case: ADDRESS_HISTORY | error | ADRESSE_HISTORIE
UPDATE adresse SET latitude=50 WHERE adresse_id=1;

-- case: DRAFT_ALLOWED | rows | [[0]]
INSERT INTO buch VALUES(100,'Entwurf',2026,1,1);
INSERT INTO exemplar VALUES(100,100,1,1,'gut',14,0,0);
SELECT angeboten FROM exemplar WHERE exemplar_id=100;

-- case: DRAFT_ACTIVATE | error | ANGEBOT_KATALOG
INSERT INTO buch VALUES(100,'Entwurf',2026,1,1);
INSERT INTO exemplar VALUES(100,100,1,1,'gut',14,0,0);
UPDATE exemplar SET angeboten=1 WHERE exemplar_id=100;

-- case: DRAFT_INSERT_ACTIVE | error | ANGEBOT_KATALOG
INSERT INTO buch VALUES(100,'Entwurf',2026,1,1);
INSERT INTO exemplar VALUES(100,100,1,1,'gut',14,0,1);

-- case: LAST_AUTHOR_DELETE | error | LETZTER_AUTOR
DELETE FROM buch_autor WHERE buch_id=2;

-- case: LAST_AUTHOR_UPDATE | error | LETZTER_AUTOR
UPDATE buch_autor SET buch_id=12 WHERE buch_id=2;

-- case: LAST_GENRE_DELETE | error | LETZTES_GENRE
DELETE FROM buch_genre WHERE buch_id=2;

-- case: LAST_GENRE_UPDATE | error | LETZTES_GENRE
UPDATE buch_genre SET buch_id=12 WHERE buch_id=2;

-- case: AUTHOR_ONE_REMAINS | rows | [[1]]
DELETE FROM buch_autor WHERE buch_id=1 AND autor_id=2;
SELECT COUNT(*) FROM buch_autor WHERE buch_id=1;

-- case: BAD_CALENDAR | error | CHECK constraint failed
INSERT INTO abholzeit VALUES(999,13,'2026-02-30 10:00:00','2026-03-03 10:00:00');

-- case: LEAP_VALID | rows | [[1]]
INSERT INTO abholzeit VALUES(999,13,'2024-02-29 10:00:00','2024-02-29 11:00:00');
SELECT COUNT(*) FROM abholzeit WHERE abholzeit_id=999;

-- case: BAD_TIME | error | CHECK constraint failed
INSERT INTO abholzeit VALUES(999,13,'2026-10-03 24:00:00','2026-10-04 01:00:00');

-- case: BAD_DATE_NULL_RESULT | error | CHECK constraint failed
INSERT INTO abholzeit VALUES(999,13,'2026-99-03 10:00:00','2026-10-04 01:00:00');

-- case: FRACTION_STARS | error | cannot store REAL value in INTEGER column
UPDATE bewertung SET sterne=3.5 WHERE bewertung_id=1;

-- case: ASCII_MAIL_NORMALIZATION | error | CHECK constraint failed
INSERT INTO benutzer VALUES(100,'Demo','MIRA@example.invalid',1);

-- case: MAIL_DUPLICATE | error | UNIQUE constraint failed
INSERT INTO benutzer VALUES(100,'Demo','mira@example.invalid',1);

-- case: LIFECYCLE | rows | [[1]]
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'abholung');
UPDATE ausleihe SET rueckgabe='2026-10-04 10:00:00' WHERE ausleihe_id=100;
SELECT COUNT(*) FROM v_verfuegbare_buecher WHERE exemplar_id=13;

-- case: VIEW_RUNNING_HIDDEN | rows | [[0]]
INSERT INTO ausleihe VALUES(100,13,2,'2026-10-03 10:00:00','2026-10-17 10:00:00',NULL,'abholung');
SELECT COUNT(*) FROM v_verfuegbare_buecher WHERE exemplar_id=13;
*/
-- BOOKSWAP-SECTION-END 06_tests

-- BOOKSWAP-SECTION-BEGIN 07_benchmark_data
/*
-- 12000 zusätzliche Testorte, Exemplare und abgeschlossene Leihen.
-- Nur in einer separaten, frisch aufgebauten Kopie; Trigger eingeschaltet lassen.
-- Dies erzeugt Messdaten und gehört nicht zum normalen Grundbestand.

WITH RECURSIVE n(i) AS (VALUES(1) UNION ALL SELECT i+1 FROM n WHERE i<12000)
INSERT INTO adresse
 SELECT 10000+i,'Benchmarkweg',CAST(i AS TEXT),'00000','Benchmark','DE',
        -80.0+(i%16000)/100.0,-179.0+((i*37)%35800)/100.0 FROM n;
INSERT INTO exemplar
 SELECT adresse_id,1,1,adresse_id,'gut',14,1,1 FROM adresse WHERE adresse_id>10000;
INSERT INTO ausleihe
 SELECT exemplar_id,exemplar_id,2+(exemplar_id%11),
        '2026-01-01 10:00:00','2026-01-15 10:00:00','2026-01-10 10:00:00','post'
 FROM exemplar WHERE exemplar_id>10000;
*/
-- BOOKSWAP-SECTION-END 07_benchmark_data

-- BOOKSWAP-SECTION-BEGIN 08_screenshot_queries
/*
-- 13 lesende Bildschirmnachweise: SELECTs einzeln auf dem Grundbestand ausführen.
-- COUNT(*) OVER() zeigt die Gesamtzahl vor der auf fünf Zeilen begrenzten Anzeige.
-- Die screenshot-Kennungen gehören zu den unveränderten Originalaufnahmen.

-- screenshot: 01_adresse.png
SELECT adresse_id,ort,latitude,longitude,
 COUNT(*) OVER() AS anzahl
FROM adresse ORDER BY adresse_id LIMIT 5;

-- screenshot: 02_benutzer.png
SELECT benutzer_id,name,email,adresse_id,
 COUNT(*) OVER() AS anzahl
FROM benutzer ORDER BY benutzer_id LIMIT 5;

-- screenshot: 03_verlag.png
SELECT verlag_id,name,
 COUNT(*) OVER() AS anzahl
FROM verlag ORDER BY verlag_id LIMIT 5;

-- screenshot: 04_sprache.png
SELECT sprache_id,code,name,
 COUNT(*) OVER() AS anzahl
FROM sprache ORDER BY sprache_id LIMIT 5;

-- screenshot: 05_buch.png
SELECT buch_id,titel,jahr,verlag_id,sprache_id,
 COUNT(*) OVER() AS anzahl
FROM buch ORDER BY buch_id LIMIT 5;

-- screenshot: 06_autor.png
SELECT autor_id,name,
 COUNT(*) OVER() AS anzahl
FROM autor ORDER BY autor_id LIMIT 5;

-- screenshot: 07_buch_autor.png
SELECT buch_id,autor_id,
 COUNT(*) OVER() AS anzahl
FROM buch_autor ORDER BY buch_id,autor_id LIMIT 5;

-- screenshot: 08_genre.png
SELECT genre_id,name,
 COUNT(*) OVER() AS anzahl
FROM genre ORDER BY genre_id LIMIT 5;

-- screenshot: 09_buch_genre.png
SELECT buch_id,genre_id,
 COUNT(*) OVER() AS anzahl
FROM buch_genre ORDER BY buch_id,genre_id LIMIT 5;

-- screenshot: 10_exemplar.png
SELECT exemplar_id,buch_id,eigentuemer_id,versand,angeboten,
 COUNT(*) OVER() AS anzahl
FROM exemplar ORDER BY exemplar_id LIMIT 5;

-- screenshot: 11_abholzeit.png
SELECT abholzeit_id,exemplar_id,von,bis,
 COUNT(*) OVER() AS anzahl
FROM abholzeit ORDER BY abholzeit_id LIMIT 5;

-- screenshot: 12_ausleihe.png
SELECT ausleihe_id,exemplar_id,entleiher_id,weg,rueckgabe,
 COUNT(*) OVER() AS anzahl
FROM ausleihe ORDER BY ausleihe_id LIMIT 5;

-- screenshot: 13_bewertung.png
SELECT bewertung_id,ausleihe_id,sterne,
 COUNT(*) OVER() AS anzahl
FROM bewertung ORDER BY bewertung_id LIMIT 5;
*/
-- BOOKSWAP-SECTION-END 08_screenshot_queries

-- BOOKSWAP-SUPPLEMENTS-END v1
