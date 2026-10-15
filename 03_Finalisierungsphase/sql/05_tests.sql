-- Sechs Nutzungsszenarien auf einer Kopie der Beispieldatenbank.
-- Alles in einer Verbindung ausführen; CHECK meldet fehlerhafte Erwartungen.
-- Am Ende werden alle Änderungen zurückgerollt.
-- CLI: sqlite3 -bail bookswap.sqlite ".read sql/05_tests.sql"
PRAGMA foreign_keys=ON;
PRAGMA recursive_triggers=ON;
CREATE TEMP TABLE testergebnis(test TEXT PRIMARY KEY,ist INTEGER NOT NULL CHECK(ist=1));
BEGIN IMMEDIATE;

-- Gemeinsame Ausgangsdaten für alle sechs Fälle.
INSERT INTO adresse VALUES(9001,'Teststraße','1','10000','Testort','DE',52.0,13.0);
INSERT INTO adresse VALUES(9002,'Andere Straße','2','10001','Testort','DE',52.1,13.1);
INSERT INTO exemplar VALUES(9000,1,1,'gut',9000);
INSERT INTO angebot_version VALUES(9000,9000,1,'2026-01-01 00:00:00',14,0,9001,1);
INSERT INTO abholzeit VALUES(9000,9000,'2026-01-02 09:00:00','2026-01-02 18:00:00');

-- Fall 1: Ausleihen, verspätet zurückgeben, erneut ausleihen
SAVEPOINT fall1;
INSERT INTO reservierung VALUES(9000,9000,2,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
INSERT INTO testergebnis VALUES('Anfrage blockiert nicht',(EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-02 10:00:00' WHERE reservierung_id=9000;
INSERT INTO testergebnis VALUES('Bestätigung blockiert',(NOT EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
INSERT INTO ausleihe VALUES(9000,9000,2,'2026-01-02 10:00:00','2026-01-16 10:00:00',NULL,'abholung',9000,9000,'versioniert');
INSERT INTO testergebnis VALUES('Umsetzung und drei Ereignisse',((SELECT status='umgesetzt' FROM reservierung WHERE reservierung_id=9000) AND (SELECT count(*)=3 FROM reservierungsereignis WHERE reservierung_id=9000)));
INSERT INTO testergebnis VALUES('NULL-Rückgabe blockiert',(NOT EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
UPDATE ausleihe SET rueckgabe='2026-01-18 10:00:00' WHERE ausleihe_id=9000;
INSERT INTO testergebnis VALUES('Späte Rückgabe gibt frei',(EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
INSERT INTO abholzeit VALUES(9001,9000,'2026-01-18 09:00:00','2026-01-18 18:00:00');
INSERT INTO reservierung VALUES(9001,9000,3,9000,'2026-01-18 10:00:00','angefragt','2026-01-18 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-18 10:00:00' WHERE reservierung_id=9001;
INSERT INTO ausleihe VALUES(9001,9000,3,'2026-01-18 10:00:00','2026-02-01 10:00:00',NULL,'abholung',9000,9001,'versioniert');
INSERT INTO testergebnis VALUES('Gleiche Grenze erlaubt zweite Leihe',((SELECT count(*)=2 FROM ausleihe WHERE exemplar_id=9000)));
SELECT '1: Ausleihen, verspätet zurückgeben, erneut ausleihen' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall1;
RELEASE fall1;

-- Fall 2: Bedingungen nach Rückgabe ändern, alte Bedingungen bleiben
SAVEPOINT fall2;
INSERT INTO reservierung VALUES(9000,9000,2,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-02 10:00:00' WHERE reservierung_id=9000;
INSERT INTO ausleihe VALUES(9000,9000,2,'2026-01-02 10:00:00','2026-01-16 10:00:00',NULL,'abholung',9000,9000,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-01-05 10:00:00' WHERE ausleihe_id=9000;
INSERT INTO angebot_version VALUES(9001,9000,2,'2026-01-06 00:00:00',7,1,9002,1);
INSERT INTO reservierung VALUES(9001,9000,3,9001,'2026-01-06 10:00:00','angefragt','2026-01-06 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-06 10:00:00' WHERE reservierung_id=9001;
INSERT INTO ausleihe VALUES(9001,9000,3,'2026-01-06 10:00:00','2026-01-13 10:00:00',NULL,'post',9001,9001,'versioniert');
INSERT INTO testergebnis VALUES('Historischer Vertrag behält 14/0/9001',((SELECT max_tage=14 AND versand=0 AND abholadresse_id=9001 FROM v_ausleihbedingungen WHERE ausleihe_id=9000)));
INSERT INTO testergebnis VALUES('Neuer Vertrag erhält 7/1/9002',((SELECT max_tage=7 AND versand=1 AND abholadresse_id=9002 FROM v_ausleihbedingungen WHERE ausleihe_id=9001)));
INSERT INTO testergebnis VALUES('Halboffene Versionsgrenze',((SELECT gueltig_bis='2026-01-06 00:00:00' FROM v_angebot_intervalle WHERE angebot_version_id=9000)));
SELECT '2: Bedingungen nach Rückgabe ändern, alte Bedingungen bleiben' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall2;
RELEASE fall2;

-- Fall 3: Zwei Anfragen, Bestätigung und Stornierung
SAVEPOINT fall3;
INSERT INTO reservierung VALUES(9000,9000,2,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
INSERT INTO reservierung VALUES(9001,9000,3,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-02 10:00:00' WHERE reservierung_id=9000;
INSERT INTO testergebnis VALUES('Genau eine bestätigt',((SELECT count(*)=1 FROM reservierung WHERE exemplar_id=9000 AND status='bestaetigt')));
UPDATE reservierung SET status='storniert',status_am='2026-01-02 11:00:00' WHERE reservierung_id=9000;
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-02 11:00:00' WHERE reservierung_id=9001;
INSERT INTO testergebnis VALUES('Andere Anfrage jetzt bestätigt',((SELECT status='bestaetigt' FROM reservierung WHERE reservierung_id=9001)));
INSERT INTO testergebnis VALUES('Storno protokolliert',(EXISTS(SELECT 1 FROM reservierungsereignis WHERE reservierung_id=9000 AND status_nach='storniert')));
SELECT '3: Zwei Anfragen, Bestätigung und Stornierung' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall3;
RELEASE fall3;

-- Fall 4: Versionswechsel zwischen Anfrage und Bestätigung
SAVEPOINT fall4;
INSERT INTO reservierung VALUES(9000,9000,2,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
INSERT INTO angebot_version VALUES(9001,9000,2,'2026-01-03 00:00:00',7,1,9002,1);
INSERT INTO testergebnis VALUES('Alte Anfrage bleibt an Version 1',((SELECT angebot_version_id=9000 FROM reservierung WHERE reservierung_id=9000)));
UPDATE reservierung SET status='storniert',status_am='2026-01-03 10:00:00' WHERE reservierung_id=9000;
INSERT INTO reservierung VALUES(9001,9000,2,9001,'2026-01-03 10:00:00','angefragt','2026-01-03 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-03 10:00:00' WHERE reservierung_id=9001;
INSERT INTO testergebnis VALUES('Neue Anfrage auf Version 2',((SELECT angebot_version_id=9001 AND status='bestaetigt' FROM reservierung WHERE reservierung_id=9001)));
SELECT '4: Versionswechsel zwischen Anfrage und Bestätigung' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall4;
RELEASE fall4;

-- Fall 5: Angebot aussetzen und wieder anbieten
SAVEPOINT fall5;
INSERT INTO angebot_version VALUES(9001,9000,2,'2026-01-02 00:00:00',14,0,9001,0);
INSERT INTO testergebnis VALUES('Ausgesetztes Angebot nicht verfügbar',(NOT EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
INSERT INTO angebot_version VALUES(9002,9000,3,'2026-01-03 00:00:00',14,0,9001,1);
INSERT INTO testergebnis VALUES('Neue angebotene Version verfügbar',(EXISTS(SELECT 1 FROM v_verfuegbare_buecher WHERE exemplar_id=9000)));
SELECT '5: Angebot aussetzen und wieder anbieten' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall5;
RELEASE fall5;

-- Fall 6: Zusammengehörige Änderung bewusst zurückrollen
SAVEPOINT fall6;
INSERT INTO reservierung VALUES(9000,9000,2,9000,'2026-01-02 10:00:00','angefragt','2026-01-02 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-01-02 10:00:00' WHERE reservierung_id=9000;
SAVEPOINT uebergabe;
INSERT INTO ausleihe VALUES(9000,9000,2,'2026-01-02 10:00:00','2026-01-16 10:00:00',NULL,'abholung',9000,9000,'versioniert');
INSERT INTO testergebnis VALUES('Vor Rollback umgesetzt',((SELECT status='umgesetzt' FROM reservierung WHERE reservierung_id=9000)));
ROLLBACK TO uebergabe;
RELEASE uebergabe;
INSERT INTO testergebnis VALUES('Vertrag zurückgerollt',(NOT EXISTS(SELECT 1 FROM ausleihe WHERE ausleihe_id=9000)));
INSERT INTO testergebnis VALUES('Bestätigung wiederhergestellt',((SELECT status='bestaetigt' FROM reservierung WHERE reservierung_id=9000)));
INSERT INTO testergebnis VALUES('Umsetzungsereignis zurückgerollt',((SELECT count(*)=2 FROM reservierungsereignis WHERE reservierung_id=9000)));
SELECT '6: Zusammengehörige Änderung bewusst zurückrollen' AS fall,'PASS' AS ergebnis;
ROLLBACK TO fall6;
RELEASE fall6;

ROLLBACK;
DROP TABLE temp.testergebnis;
PRAGMA foreign_key_check;
PRAGMA integrity_check;

-- Negative Fälle: EINZELN auf einer Kopie ausprobieren, NICHT als Batch.
-- Vorher PRAGMA foreign_keys=ON; PRAGMA recursive_triggers=ON;
-- Jede folgende auskommentierte Anweisung muss einen Fehler liefern und
-- darf keine Zeile verändern. Bei offener Transaktion danach ROLLBACK.

-- N01 Veraltete Anfrage 20 bestätigen: VERSION_NICHT_AKTUELL.
-- UPDATE reservierung SET status='bestaetigt',status_am='2026-10-06 10:00:00' WHERE reservierung_id=20;
-- N02 Parallel bestätigte Anfrage 18: EXEMPLAR_BELEGT.
-- UPDATE reservierung SET status='bestaetigt',status_am='2026-10-06 10:00:00' WHERE reservierung_id=18;
-- N03 Alte Angebotsbedingungen ändern: ANGEBOT_UNVERAENDERLICH.
-- UPDATE angebot_version SET max_tage=99 WHERE angebot_version_id=1;
-- N04 Historische Adresse ändern: ADRESSE_HISTORIE.
-- UPDATE adresse SET strasse='Geändert' WHERE adresse_id=1;
-- N05 Historischen Vertrag löschen: AUSLEIHE_HISTORIE.
-- DELETE FROM ausleihe WHERE ausleihe_id=1;
-- N06 Rückgabe ein zweites Mal ändern: RUECKGABE_UNVERAENDERLICH.
-- UPDATE ausleihe SET rueckgabe='2026-09-17 10:00:00' WHERE ausleihe_id=1;
-- N07 Per REPLACE die Historie überschreiben: ANGEBOT_HISTORIE.
-- INSERT OR REPLACE INTO angebot_version SELECT * FROM angebot_version WHERE angebot_version_id=1;
-- N08 NULL bei vorgeschriebener Dauer: NOT NULL.
-- INSERT INTO angebot_version VALUES(9999,20,3,'2026-10-07 00:00:00',NULL,1,8,1);
-- N09 Ungültiges Datum: CHECK (30. Februar).
-- INSERT INTO abholzeit VALUES(9999,1,'2026-02-30 10:00:00','2026-03-01 11:00:00');
-- N10 Unbekannte Altbedingungen als neue Leihe: HISTORIE_NUR_MIGRATION.
-- INSERT INTO ausleihe VALUES(9999,2,1,'2026-10-07 10:00:00','2026-10-08 10:00:00',NULL,'post',NULL,NULL,'unbekannt');
-- N11 Laufende Leihe darf auch nach Fälligkeit nicht erneut bestätigt werden.
-- BEGIN IMMEDIATE;
-- INSERT INTO reservierung VALUES(9999,12,1,12,'2026-10-20 10:00:00','angefragt','2026-10-20 10:00:00','post');
-- UPDATE reservierung SET status='bestaetigt',status_am='2026-10-20 10:00:00' WHERE reservierung_id=9999;
-- Erwartet EXEMPLAR_BELEGT, dann ROLLBACK;
-- N12 Fremder oder fehlender aktueller Versionszeiger: FK-Fehler bei COMMIT.
-- BEGIN IMMEDIATE;
-- INSERT INTO exemplar VALUES(9999,1,1,'gut',1);
-- COMMIT;
-- Erwartet FOREIGN KEY constraint failed, danach ROLLBACK;

-- Zwei Verbindungen: nur auf einer zusätzlichen Kopie der Beispieldatenbank.
-- Beide Fenster: PRAGMA foreign_keys=ON; PRAGMA recursive_triggers=ON;
--                PRAGMA busy_timeout=15000;
-- Vorbereitung in Fenster A (danach COMMIT):
-- BEGIN IMMEDIATE;
-- INSERT INTO reservierung VALUES(9991,18,2,18,'2026-10-06 10:00:00','angefragt','2026-10-06 10:00:00','post');
-- INSERT INTO reservierung VALUES(9992,18,3,18,'2026-10-06 10:00:00','angefragt','2026-10-06 10:00:00','post');
-- COMMIT;
-- Fenster A: BEGIN IMMEDIATE;
-- UPDATE reservierung SET status='bestaetigt',status_am='2026-10-06 11:00:00' WHERE reservierung_id=9991;
-- Fenster B: BEGIN IMMEDIATE; -- wartet, solange A die Schreibtransaktion hält
-- Fenster A: COMMIT;
-- Fenster B (nach Freigabe):
-- UPDATE reservierung SET status='bestaetigt',status_am='2026-10-06 11:00:00' WHERE reservierung_id=9992;
-- Erwartet EXEMPLAR_BELEGT; ROLLBACK;
-- SELECT count(*) FROM reservierung WHERE exemplar_id=18 AND status='bestaetigt';
-- Erwartet 1. BEGIN IMMEDIATE reserviert den Schreiber vor der fachlichen Prüfung.
-- SQLite erlaubt nur eine Schreibtransaktion zugleich; busy_timeout ist eine Wartefrist.
