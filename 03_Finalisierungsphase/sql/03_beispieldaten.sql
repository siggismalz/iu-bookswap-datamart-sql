-- BookSwap: fiktiver Beispielbestand, Stand 14.10.2026.
-- Nach 01 und 02 auf leeren Tabellen: 297 Zeilen, mindestens 10 je Tabelle.
-- Die Abläufe laufen mit aktiven Triggern; diese erzeugen die Statusereignisse.
PRAGMA foreign_keys=ON;
PRAGMA recursive_triggers=ON;
BEGIN IMMEDIATE;

-- Katalog und Mitglieder; alle Werte und Koordinaten sind Testdaten.
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

-- 24 Exemplare mit Angebotsversion und je zwei Abholfenstern.
INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(1,1,1,'gut',1);
INSERT INTO angebot_version VALUES(1,1,1,'2026-08-01 00:00:00',14,0,1,1);
INSERT INTO abholzeit VALUES(1,1,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(101,1,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(2,2,2,'gut',2);
INSERT INTO angebot_version VALUES(2,2,1,'2026-08-01 00:00:00',14,1,2,1);
INSERT INTO abholzeit VALUES(2,2,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(102,2,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(3,3,3,'gut',3);
INSERT INTO angebot_version VALUES(3,3,1,'2026-08-01 00:00:00',14,0,3,1);
INSERT INTO abholzeit VALUES(3,3,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(103,3,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(4,4,4,'gut',4);
INSERT INTO angebot_version VALUES(4,4,1,'2026-08-01 00:00:00',14,1,4,1);
INSERT INTO abholzeit VALUES(4,4,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(104,4,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(5,5,5,'gut',5);
INSERT INTO angebot_version VALUES(5,5,1,'2026-08-01 00:00:00',14,0,5,1);
INSERT INTO abholzeit VALUES(5,5,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(105,5,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(6,6,6,'gut',6);
INSERT INTO angebot_version VALUES(6,6,1,'2026-08-01 00:00:00',14,1,6,1);
INSERT INTO abholzeit VALUES(6,6,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(106,6,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(7,7,7,'gut',7);
INSERT INTO angebot_version VALUES(7,7,1,'2026-08-01 00:00:00',14,0,7,1);
INSERT INTO abholzeit VALUES(7,7,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(107,7,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(8,8,8,'gut',8);
INSERT INTO angebot_version VALUES(8,8,1,'2026-08-01 00:00:00',14,1,8,1);
INSERT INTO abholzeit VALUES(8,8,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(108,8,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(9,9,9,'gut',9);
INSERT INTO angebot_version VALUES(9,9,1,'2026-08-01 00:00:00',14,0,9,1);
INSERT INTO abholzeit VALUES(9,9,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(109,9,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(10,10,10,'gut',10);
INSERT INTO angebot_version VALUES(10,10,1,'2026-08-01 00:00:00',14,1,10,1);
INSERT INTO abholzeit VALUES(10,10,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(110,10,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(11,11,11,'gut',11);
INSERT INTO angebot_version VALUES(11,11,1,'2026-08-01 00:00:00',14,0,11,1);
INSERT INTO abholzeit VALUES(11,11,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(111,11,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(12,12,12,'gut',12);
INSERT INTO angebot_version VALUES(12,12,1,'2026-08-01 00:00:00',14,1,12,1);
INSERT INTO abholzeit VALUES(12,12,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(112,12,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(13,1,1,'gut',13);
INSERT INTO angebot_version VALUES(13,13,1,'2026-08-01 00:00:00',14,0,1,1);
INSERT INTO abholzeit VALUES(13,13,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(113,13,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(14,2,2,'gut',14);
INSERT INTO angebot_version VALUES(14,14,1,'2026-08-01 00:00:00',14,1,2,1);
INSERT INTO abholzeit VALUES(14,14,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(114,14,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(15,3,3,'gut',15);
INSERT INTO angebot_version VALUES(15,15,1,'2026-08-01 00:00:00',14,0,3,1);
INSERT INTO abholzeit VALUES(15,15,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(115,15,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(16,4,4,'gut',16);
INSERT INTO angebot_version VALUES(16,16,1,'2026-08-01 00:00:00',14,1,4,1);
INSERT INTO abholzeit VALUES(16,16,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(116,16,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(17,5,5,'gut',17);
INSERT INTO angebot_version VALUES(17,17,1,'2026-08-01 00:00:00',14,0,5,1);
INSERT INTO abholzeit VALUES(17,17,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(117,17,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(18,6,6,'gut',18);
INSERT INTO angebot_version VALUES(18,18,1,'2026-08-01 00:00:00',14,1,6,1);
INSERT INTO abholzeit VALUES(18,18,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(118,18,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(19,7,7,'gut',19);
INSERT INTO angebot_version VALUES(19,19,1,'2026-08-01 00:00:00',14,0,7,1);
INSERT INTO abholzeit VALUES(19,19,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(119,19,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(20,8,8,'gut',20);
INSERT INTO angebot_version VALUES(20,20,1,'2026-08-01 00:00:00',14,1,8,1);
INSERT INTO abholzeit VALUES(20,20,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(120,20,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(21,9,9,'gut',21);
INSERT INTO angebot_version VALUES(21,21,1,'2026-08-01 00:00:00',14,0,9,1);
INSERT INTO abholzeit VALUES(21,21,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(121,21,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(22,10,10,'gut',22);
INSERT INTO angebot_version VALUES(22,22,1,'2026-08-01 00:00:00',14,1,10,1);
INSERT INTO abholzeit VALUES(22,22,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(122,22,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(23,11,11,'gut',23);
INSERT INTO angebot_version VALUES(23,23,1,'2026-08-01 00:00:00',14,0,11,1);
INSERT INTO abholzeit VALUES(23,23,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(123,23,'2026-10-03 09:00:00','2026-10-03 18:00:00');

INSERT INTO exemplar(exemplar_id,buch_id,eigentuemer_id,zustand,aktuelle_version_id) VALUES(24,12,12,'gut',24);
INSERT INTO angebot_version VALUES(24,24,1,'2026-08-01 00:00:00',14,1,12,0);
INSERT INTO abholzeit VALUES(24,24,'2026-09-01 09:00:00','2026-09-01 18:00:00');
INSERT INTO abholzeit VALUES(124,24,'2026-10-03 09:00:00','2026-10-03 18:00:00');

-- Leihen 1 bis 12: Anfrage, Bestätigung und Übergabe; zehn davon mit Rückgabe.
INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(1,2,1,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=1;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(1,2,'2026-09-01 10:00:00','2026-09-15 10:00:00','abholung',1,1,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-16 10:00:00' WHERE ausleihe_id=1;
INSERT INTO bewertung VALUES(1,1,4,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(2,3,2,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=2;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(2,3,'2026-09-01 10:00:00','2026-09-15 10:00:00','post',2,2,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=2;
INSERT INTO bewertung VALUES(2,2,5,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(3,4,3,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=3;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(3,4,'2026-09-01 10:00:00','2026-09-15 10:00:00','abholung',3,3,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=3;
INSERT INTO bewertung VALUES(3,3,3,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(4,5,4,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=4;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(4,5,'2026-09-01 10:00:00','2026-09-15 10:00:00','post',4,4,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=4;
INSERT INTO bewertung VALUES(4,4,4,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(5,6,5,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=5;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(5,6,'2026-09-01 10:00:00','2026-09-15 10:00:00','abholung',5,5,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=5;
INSERT INTO bewertung VALUES(5,5,5,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(6,7,6,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=6;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(6,7,'2026-09-01 10:00:00','2026-09-15 10:00:00','post',6,6,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=6;
INSERT INTO bewertung VALUES(6,6,3,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(7,8,7,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=7;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(7,8,'2026-09-01 10:00:00','2026-09-15 10:00:00','abholung',7,7,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=7;
INSERT INTO bewertung VALUES(7,7,4,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(8,9,8,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=8;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(8,9,'2026-09-01 10:00:00','2026-09-15 10:00:00','post',8,8,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=8;
INSERT INTO bewertung VALUES(8,8,5,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(9,10,9,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=9;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(9,10,'2026-09-01 10:00:00','2026-09-15 10:00:00','abholung',9,9,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=9;
INSERT INTO bewertung VALUES(9,9,3,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(10,11,10,'2026-08-31 10:00:00','angefragt','2026-08-31 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-08-31 10:00:00' WHERE reservierung_id=10;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(10,11,'2026-09-01 10:00:00','2026-09-15 10:00:00','post',10,10,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-10 10:00:00' WHERE ausleihe_id=10;
INSERT INTO bewertung VALUES(10,10,4,'Fiktive Demo-Bewertung');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(11,12,11,'2026-10-02 10:00:00','angefragt','2026-10-02 10:00:00','abholung');
UPDATE reservierung SET status='bestaetigt',status_am='2026-10-02 10:00:00' WHERE reservierung_id=11;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(11,12,'2026-10-03 10:00:00','2026-10-17 10:00:00','abholung',11,11,'versioniert');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(12,1,12,'2026-10-02 10:00:00','angefragt','2026-10-02 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-10-02 10:00:00' WHERE reservierung_id=12;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(12,1,'2026-10-03 10:00:00','2026-10-17 10:00:00','post',12,12,'versioniert');

-- Exemplar 1 wird nach den Rückgaben erneut mit 7 und danach 21 Tagen angeboten.
INSERT INTO angebot_version(exemplar_id,versionsnummer,gueltig_von,
             max_tage,versand,abholadresse_id,angeboten) VALUES(1,2,'2026-09-17 00:00:00',7,1,2,1);

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(1,3,25,'2026-09-17 08:00:00','angefragt','2026-09-17 08:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-09-17 09:00:00' WHERE reservierung_id=13;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(1,3,'2026-09-17 10:00:00','2026-09-24 10:00:00','post',25,13,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-09-22 10:00:00' WHERE ausleihe_id=13;

INSERT INTO angebot_version(exemplar_id,versionsnummer,gueltig_von,
             max_tage,versand,abholadresse_id,angeboten) VALUES(1,3,'2026-09-23 00:00:00',21,1,3,1);

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(1,4,26,'2026-09-23 08:00:00','angefragt','2026-09-23 08:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-09-23 09:00:00' WHERE reservierung_id=14;
INSERT INTO ausleihe(exemplar_id,entleiher_id,beginn,faellig,weg,
             angebot_version_id,reservierung_id,bedingungen_status) VALUES(1,4,'2026-09-23 10:00:00','2026-10-14 10:00:00','post',26,14,'versioniert');
UPDATE ausleihe SET rueckgabe='2026-10-01 10:00:00' WHERE ausleihe_id=14;

-- Ablehnung, Stornierung, erneute Bestätigung und weitere offene Anfragen.
INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(14,1,14,'2026-10-04 10:00:00','angefragt','2026-10-04 10:00:00','post');
UPDATE reservierung SET status='abgelehnt',status_am='2026-10-04 11:00:00' WHERE reservierung_id=15;

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(16,1,16,'2026-10-04 10:00:00','angefragt','2026-10-04 10:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-10-04 11:00:00' WHERE reservierung_id=16;
UPDATE reservierung SET status='storniert',status_am='2026-10-04 12:00:00' WHERE reservierung_id=16;

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(16,2,16,'2026-10-04 13:00:00','angefragt','2026-10-04 13:00:00','post');
UPDATE reservierung SET status='bestaetigt',status_am='2026-10-04 14:00:00' WHERE reservierung_id=17;

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(16,3,16,'2026-10-04 15:00:00','angefragt','2026-10-04 15:00:00','post');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(18,1,18,'2026-10-04 10:00:00','angefragt','2026-10-04 10:00:00','post');

INSERT INTO reservierung(exemplar_id,entleiher_id,angebot_version_id,
            angefragt_am,status,status_am,weg) VALUES(20,1,20,'2026-10-04 10:00:00','angefragt','2026-10-04 10:00:00','post');

-- Eine neue Angebotsversion nach offener Anfrage; die alte Anfrage bleibt gespeichert.
INSERT INTO angebot_version(exemplar_id,versionsnummer,gueltig_von,
             max_tage,versand,abholadresse_id,angeboten) VALUES(20,2,'2026-10-05 00:00:00',7,1,8,1);
COMMIT;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
