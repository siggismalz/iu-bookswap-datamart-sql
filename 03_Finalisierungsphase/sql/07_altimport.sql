-- BookSwap: Altimport in eine neue Zieldatei, alternativ zu Datei 03.
-- Nur SQLite-CLI; Arbeitsordner 03_Finalisierungsphase.
-- Aufruf: sqlite3 -bail bookswap_altimport.sqlite ".read sql/07_altimport.sql"
-- Die Phase-2-Quelle wird mit mode=ro schreibgeschützt geöffnet; bei Bedarf URI anpassen.
.bail on
.read sql/01_schema.sql
ATTACH DATABASE 'file:../02_Erarbeitungs-Reflexionsphase/bookswap_phase2.sqlite?mode=ro' AS alt;

-- Quellstruktur, Integrität und bisherigen Zeitraum prüfen.
CREATE TEMP TABLE importpruefung(test TEXT PRIMARY KEY,ist INTEGER NOT NULL CHECK(ist=1));
INSERT INTO importpruefung VALUES('13 Quelltabellen',
 (SELECT count(*)=13 FROM alt.sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'));
INSERT INTO importpruefung VALUES('Erwartete Quelltabellen',
 (SELECT count(*)=13 FROM alt.sqlite_schema WHERE type='table' AND name IN
 ('adresse','benutzer','verlag','sprache','buch','autor','buch_autor','genre','buch_genre',
  'exemplar','abholzeit','ausleihe','bewertung')));
INSERT INTO importpruefung VALUES('Quellstruktur',
 EXISTS(SELECT 1 FROM pragma_table_info('exemplar','alt') WHERE cid=7 AND name='angeboten'));
INSERT INTO importpruefung VALUES('Quelle integer',
 (SELECT count(*)=1 AND min(integrity_check)='ok' FROM pragma_integrity_check(NULL,'alt')));
INSERT INTO importpruefung VALUES('Quell-Fremdschlüssel',
 NOT EXISTS(SELECT 1 FROM pragma_foreign_key_check(NULL,'alt')));
INSERT INTO importpruefung VALUES('Umstellung nach alter Historie',
 NOT EXISTS(SELECT 1 FROM alt.ausleihe WHERE beginn>'2026-10-14 00:00:00' OR rueckgabe>'2026-10-14 00:00:00'));

-- Altbestand übernehmen; aktuelle Angebotsversionen beginnen am 14.10.2026.
BEGIN IMMEDIATE;
INSERT INTO adresse SELECT * FROM alt.adresse;
INSERT INTO benutzer SELECT * FROM alt.benutzer;
INSERT INTO verlag SELECT * FROM alt.verlag;
INSERT INTO sprache SELECT * FROM alt.sprache;
INSERT INTO buch SELECT * FROM alt.buch;
INSERT INTO autor SELECT * FROM alt.autor;
INSERT INTO buch_autor SELECT * FROM alt.buch_autor;
INSERT INTO genre SELECT * FROM alt.genre;
INSERT INTO buch_genre SELECT * FROM alt.buch_genre;
INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id)
 SELECT exemplar_id,buch_id,eigentuemer_id,zustand,exemplar_id FROM alt.exemplar;
INSERT INTO angebot_version(angebot_version_id,exemplar_id,versionsnummer,gueltig_von,max_tage,versand,abholadresse_id,angeboten)
 SELECT exemplar_id,exemplar_id,1,'2026-10-14 00:00:00',max_tage,versand,abholadresse_id,angeboten FROM alt.exemplar;
INSERT INTO abholzeit SELECT * FROM alt.abholzeit;

-- Frühere Bedingungen bleiben NULL/unbekannt; keine Reservierungen erfinden.
INSERT INTO ausleihe(ausleihe_id,exemplar_id,entleiher_id,beginn,faellig,rueckgabe,weg,angebot_version_id,reservierung_id,bedingungen_status)
 SELECT ausleihe_id,exemplar_id,entleiher_id,beginn,faellig,rueckgabe,weg,NULL,NULL,'unbekannt' FROM alt.ausleihe;
INSERT INTO bewertung SELECT * FROM alt.bewertung;

-- Alle Regeln vor COMMIT aktivieren und den Import prüfen.
.read sql/02_regeln.sql
INSERT INTO importpruefung VALUES('Ziel-Fremdschlüssel',NOT EXISTS(SELECT 1 FROM pragma_foreign_key_check()));
INSERT INTO importpruefung VALUES('Keine erfundenen Altbedingungen',
 NOT EXISTS(SELECT 1 FROM ausleihe WHERE bedingungen_status<>'unbekannt' OR angebot_version_id IS NOT NULL OR reservierung_id IS NOT NULL));
COMMIT;
DETACH DATABASE alt;
DROP TABLE temp.importpruefung;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT ausleihe_id,bedingungen_status,max_tage,versand,abholadresse_id
FROM v_ausleihbedingungen ORDER BY ausleihe_id;
