-- Datenmengen und Indizes vergleichen (SQLite-CLI).
-- Nur neue Testdateien verwenden; Arbeitsordner: 03_Finalisierungsphase.
-- sqlite3 -bail -cmd ".parameter set :anzahl 1000" performance_1000.sqlite ".read sql/06_performance.sql"
-- Den Aufruf mit 10000 und 100000 wiederholen; Standard: 1000 Ausleihen.
-- A erzeugt Daten. B bis D auch einzeln auf einer Kopie der Demo ausführen.
-- SQLite >=3.45, Mathematikfunktionen und dbstat werden benötigt.
-- Zehn Ausleihen je Exemplar, neue Bedingungen nach Runde 5, 1 % noch offen.
-- Alle Daten sind synthetisch; Zeitwerte folgen der UTC-Konvention.
-- Nach dem Aufwärmen: je 30 vollständige Abfragen in derselben Verbindung.
-- .eqp on zeigt Pläne, .stats vmstep zählt Rechenschritte, .mode off blendet Zeilen aus.
-- .timer misst CLI-Lesezeit; alte Zeiten anderer Clients sind nicht direkt vergleichbar.
-- Temporäre Views sparen Wiederholungen und ändern das gespeicherte Schema nicht.
.bail on
.timer off
.stats off
.read sql/01_schema.sql
.read sql/02_regeln.sql
.print A: synthetischen Bestand erzeugen
CREATE TEMP TABLE umfang(
 n INTEGER NOT NULL CHECK(n IN(1000,10000,100000)),
 personen INTEGER NOT NULL,orte INTEGER NOT NULL,buecher INTEGER NOT NULL,exemplare INTEGER NOT NULL
);
INSERT INTO umfang SELECT coalesce(:anzahl,1000),max(20,coalesce(:anzahl,1000)/100),
 max(10,coalesce(:anzahl,1000)/1000),max(20,coalesce(:anzahl,1000)/50),coalesce(:anzahl,1000)/10;
CREATE TEMP TABLE nummer(i INTEGER PRIMARY KEY);
WITH RECURSIVE folge(i) AS (VALUES(1) UNION ALL SELECT i+1 FROM folge
 WHERE i<(SELECT max(personen,orte,buecher,exemplare) FROM umfang))
INSERT INTO nummer SELECT i FROM folge;
BEGIN IMMEDIATE;
INSERT INTO adresse SELECT i,'Benchmarkstraße',cast(i AS TEXT),printf('%05d',10000+i),
 'Benchmarkort','DE',48+(i%100)*0.03,7+(i%70)*0.03 FROM nummer WHERE i<=(SELECT orte FROM umfang);
INSERT INTO benutzer SELECT i,'Person '||i,'bench'||i||'@example.invalid',
 1+i%(SELECT orte FROM umfang) FROM nummer WHERE i<=(SELECT personen FROM umfang);
INSERT INTO verlag SELECT i,'verlag '||i FROM nummer WHERE i<=20;
INSERT INTO autor SELECT i,'autor '||i FROM nummer WHERE i<=20;
INSERT INTO genre SELECT i,'genre '||i FROM nummer WHERE i<=20;
INSERT INTO sprache SELECT i,'lang'||i,'Sprache '||i FROM nummer WHERE i<=10;
INSERT INTO buch SELECT i,'Benchmarkbuch '||i,2000+i%27,1+i%20,1+i%10
 FROM nummer WHERE i<=(SELECT buecher FROM umfang);
INSERT INTO buch_autor SELECT i,1+i%20 FROM nummer WHERE i<=(SELECT buecher FROM umfang);
INSERT INTO buch_genre SELECT i,1+i%20 FROM nummer WHERE i<=(SELECT buecher FROM umfang);
-- Exemplar und erste Version gemeinsam anlegen; der zirkuläre FK ist bis COMMIT verzögert.
INSERT INTO exemplar SELECT i,1+i%(SELECT buecher FROM umfang),1+i%(SELECT personen FROM umfang),
 'gut',i FROM nummer WHERE i<=(SELECT exemplare FROM umfang);
INSERT INTO angebot_version SELECT i,i,1,'2026-01-01 00:00:00',7,1,
 1+i%(SELECT orte FROM umfang),1 FROM nummer WHERE i<=(SELECT exemplare FROM umfang);
INSERT INTO abholzeit SELECT i,i,'2026-01-02 09:00:00','2026-01-02 18:00:00'
 FROM nummer WHERE i<=(SELECT exemplare FROM umfang);
-- Hilfstabelle enthält nur den jeweils nächsten Nutzungsschritt, keine Fachhistorie.
CREATE TEMP TABLE schritt(
 exemplar_id INTEGER PRIMARY KEY,nummer INTEGER NOT NULL,person INTEGER NOT NULL,
 zeit TEXT NOT NULL,version INTEGER NOT NULL,tage INTEGER NOT NULL,laufend INTEGER NOT NULL
);

-- Runde 1: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+1,
 CASE WHEN e.eigentuemer_id=2 THEN 3 ELSE 2 END,datetime('2026-01-02 10:00:00','+0 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 2: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+2,
 CASE WHEN 3+(e.exemplar_id+1)%(SELECT personen-2 FROM umfang)=e.eigentuemer_id THEN 2
 ELSE 3+(e.exemplar_id+1)%(SELECT personen-2 FROM umfang) END,datetime('2026-01-02 10:00:00','+8 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 3: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+3,
 CASE WHEN e.eigentuemer_id=2 THEN 3 ELSE 2 END,datetime('2026-01-02 10:00:00','+16 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 4: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+4,
 CASE WHEN 3+(e.exemplar_id+3)%(SELECT personen-2 FROM umfang)=e.eigentuemer_id THEN 2
 ELSE 3+(e.exemplar_id+3)%(SELECT personen-2 FROM umfang) END,datetime('2026-01-02 10:00:00','+24 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 5: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+5,
 CASE WHEN e.eigentuemer_id=2 THEN 3 ELSE 2 END,datetime('2026-01-02 10:00:00','+32 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Nach fünf Rückgaben ändern sich Leihfrist und Abholadresse.
INSERT INTO angebot_version SELECT (SELECT exemplare FROM umfang)+e.exemplar_id,e.exemplar_id,2,
 datetime('2026-01-02 10:00:00','+39 days'),6,1,
 1+(e.exemplar_id+1)%(SELECT orte FROM umfang),1 FROM exemplar e ORDER BY e.exemplar_id;

-- Runde 6: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+6,
 CASE WHEN 3+(e.exemplar_id+5)%(SELECT personen-2 FROM umfang)=e.eigentuemer_id THEN 2
 ELSE 3+(e.exemplar_id+5)%(SELECT personen-2 FROM umfang) END,datetime('2026-01-02 10:00:00','+40 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 7: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+7,
 CASE WHEN e.eigentuemer_id=2 THEN 3 ELSE 2 END,datetime('2026-01-02 10:00:00','+48 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 8: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+8,
 CASE WHEN 3+(e.exemplar_id+7)%(SELECT personen-2 FROM umfang)=e.eigentuemer_id THEN 2
 ELSE 3+(e.exemplar_id+7)%(SELECT personen-2 FROM umfang) END,datetime('2026-01-02 10:00:00','+56 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 9: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+9,
 CASE WHEN e.eigentuemer_id=2 THEN 3 ELSE 2 END,datetime('2026-01-02 10:00:00','+64 days'),
 e.aktuelle_version_id,v.max_tage,0
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;

-- Runde 10: Anfrage, Bestätigung, Ausleihe, Rückgabe und ggf. Bewertung.
DELETE FROM schritt;
INSERT INTO schritt SELECT e.exemplar_id,(e.exemplar_id-1)*10+10,
 CASE WHEN 3+(e.exemplar_id+9)%(SELECT personen-2 FROM umfang)=e.eigentuemer_id THEN 2
 ELSE 3+(e.exemplar_id+9)%(SELECT personen-2 FROM umfang) END,datetime('2026-01-02 10:00:00','+72 days'),
 e.aktuelle_version_id,v.max_tage,(e.exemplar_id%10=0)
 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id ORDER BY e.exemplar_id;
INSERT INTO reservierung SELECT nummer,exemplar_id,person,version,zeit,'angefragt',zeit,'post' FROM schritt ORDER BY nummer;
UPDATE reservierung SET status='bestaetigt',status_am=(SELECT zeit FROM schritt WHERE nummer=reservierung_id)
 WHERE reservierung_id IN(SELECT nummer FROM schritt);
INSERT INTO ausleihe SELECT nummer,exemplar_id,person,zeit,datetime(zeit,'+'||tage||' days'),
 NULL,'post',version,nummer,'versioniert' FROM schritt ORDER BY nummer;
UPDATE ausleihe SET rueckgabe=(SELECT datetime(zeit,'+3 days') FROM schritt WHERE nummer=ausleihe_id)
 WHERE ausleihe_id IN(SELECT nummer FROM schritt WHERE laufend=0);
INSERT INTO bewertung SELECT nummer,nummer,1+nummer%5,'Synthetischer Benchmark'
 FROM schritt WHERE laufend=0 AND nummer%37=0 ORDER BY nummer;
CREATE TEMP TABLE aufbaupruefung(ist INTEGER NOT NULL CHECK(ist=1));
INSERT INTO aufbaupruefung SELECT (SELECT count(*) FROM ausleihe)=(SELECT n FROM umfang);
INSERT INTO aufbaupruefung SELECT NOT EXISTS(SELECT 1 FROM pragma_foreign_key_check());
COMMIT;
DROP TABLE temp.aufbaupruefung;
DROP TABLE temp.schritt;
DROP TABLE temp.nummer;
DROP TABLE temp.umfang;
ANALYZE;
VACUUM;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT count(*) AS leihen,sum(rueckgabe IS NULL) AS laufend FROM ausleihe;

-- B: Leseabfragen mit allen Indizes. Automatische Hilfsindizes abschalten.
PRAGMA automatic_index=OFF;
CREATE TEMP TABLE indexprobe(name TEXT PRIMARY KEY,wert NOT NULL);
INSERT INTO indexprobe SELECT 'ix_ausleihe_exemplar_beginn',exemplar_id FROM ausleihe WHERE exemplar_id IS NOT NULL
 GROUP BY exemplar_id ORDER BY count(*) ASC,exemplar_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_ausleihe_entleiher_beginn',entleiher_id FROM ausleihe WHERE entleiher_id IS NOT NULL
 GROUP BY entleiher_id ORDER BY count(*) ASC,entleiher_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_benutzer_adresse',adresse_id FROM benutzer WHERE adresse_id IS NOT NULL
 GROUP BY adresse_id ORDER BY count(*) ASC,adresse_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_buch_verlag',verlag_id FROM buch WHERE verlag_id IS NOT NULL
 GROUP BY verlag_id ORDER BY count(*) ASC,verlag_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_buch_sprache',sprache_id FROM buch WHERE sprache_id IS NOT NULL
 GROUP BY sprache_id ORDER BY count(*) ASC,sprache_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_buch_autor_autor',autor_id FROM buch_autor WHERE autor_id IS NOT NULL
 GROUP BY autor_id ORDER BY count(*) ASC,autor_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_buch_genre_genre',genre_id FROM buch_genre WHERE genre_id IS NOT NULL
 GROUP BY genre_id ORDER BY count(*) ASC,genre_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_exemplar_buch',buch_id FROM exemplar WHERE buch_id IS NOT NULL
 GROUP BY buch_id ORDER BY count(*) ASC,buch_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_exemplar_eigentuemer',eigentuemer_id FROM exemplar WHERE eigentuemer_id IS NOT NULL
 GROUP BY eigentuemer_id ORDER BY count(*) ASC,eigentuemer_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_angebot_adresse',abholadresse_id FROM angebot_version WHERE abholadresse_id IS NOT NULL
 GROUP BY abholadresse_id ORDER BY count(*) ASC,abholadresse_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_adresse_koordinaten',latitude FROM adresse WHERE latitude IS NOT NULL
 GROUP BY latitude ORDER BY count(*) ASC,latitude DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_reservierung_entleiher',entleiher_id FROM reservierung WHERE entleiher_id IS NOT NULL
 GROUP BY entleiher_id ORDER BY count(*) ASC,entleiher_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_reservierung_exemplar',exemplar_id FROM reservierung WHERE exemplar_id IS NOT NULL
 GROUP BY exemplar_id ORDER BY count(*) ASC,exemplar_id DESC LIMIT 1;
INSERT INTO indexprobe SELECT 'ix_ausleihe_version',angebot_version_id FROM ausleihe WHERE angebot_version_id IS NOT NULL
 GROUP BY angebot_version_id ORDER BY count(*) ASC,angebot_version_id DESC LIMIT 1;
-- Radius 5 km: Haversine, gültige Parameter, verfügbare Exemplare.
CREATE TEMP VIEW mess_radius_5 AS
WITH eingabe(lat,lon,radius_km) AS (
 VALUES(48.03,7.03,5.0)
), parameter AS (
 SELECT lat,lon,radius_km FROM eingabe
 WHERE typeof(lat) IN ('integer','real') AND lat BETWEEN -90 AND 90
 AND typeof(lon) IN ('integer','real') AND lon BETWEEN -180 AND 180
 AND typeof(radius_km) IN ('integer','real') AND radius_km BETWEEN 0 AND 1.0e100
), kandidaten AS (
 -- Breitenband vorfiltern; am gleichen Pol gilt h = 0.
 SELECT v.*,p.radius_km,
   CASE WHEN abs(v.latitude)=90 AND v.latitude=p.lat THEN 0.0 ELSE
   pow(sin(radians(v.latitude-p.lat)/2),2)
   +cos(radians(p.lat))*cos(radians(v.latitude))*pow(sin(radians(v.longitude-p.lon)/2),2)
   END AS h
 FROM parameter p JOIN v_verfuegbare_buecher v
 ON v.latitude BETWEEN max(-90,p.lat-degrees(p.radius_km/6371.0)-1e-10)
                       AND min(90,p.lat+degrees(p.radius_km/6371.0)+1e-10)
), distanzen AS (
 -- h begrenzen; 12742 = zweimal der Erdradius in km.
 SELECT exemplar_id,titel,latitude,longitude,radius_km,
        12742.0*asin(sqrt(min(1.0,max(0.0,h)))) AS entfernung_km
 FROM kandidaten
)
-- Nächstes Exemplar zuerst; bei Gleichstand nach exemplar_id.
SELECT exemplar_id,titel,latitude,longitude,entfernung_km FROM distanzen
WHERE entfernung_km<=radius_km+1e-9 ORDER BY entfernung_km,exemplar_id;

-- Abfragen einmal definieren; die Sortierung steht jeweils beim Aufruf.
CREATE TEMP VIEW probe_exemplar_leihen AS
SELECT exemplar_id,beginn
 FROM ausleihe
 WHERE exemplar_id=(SELECT wert FROM indexprobe WHERE name='ix_ausleihe_exemplar_beginn');
CREATE TEMP VIEW probe_person_leihen AS
SELECT entleiher_id,beginn
 FROM ausleihe
 WHERE entleiher_id=(SELECT wert FROM indexprobe WHERE name='ix_ausleihe_entleiher_beginn');
CREATE TEMP VIEW probe_person_ort AS
SELECT adresse_id
 FROM benutzer
 WHERE adresse_id=(SELECT wert FROM indexprobe WHERE name='ix_benutzer_adresse');
CREATE TEMP VIEW probe_buch_verlag AS
SELECT verlag_id
 FROM buch
 WHERE verlag_id=(SELECT wert FROM indexprobe WHERE name='ix_buch_verlag');
CREATE TEMP VIEW probe_buch_sprache AS
SELECT sprache_id
 FROM buch
 WHERE sprache_id=(SELECT wert FROM indexprobe WHERE name='ix_buch_sprache');
CREATE TEMP VIEW probe_autor_buecher AS
SELECT autor_id,buch_id
 FROM buch_autor
 WHERE autor_id=(SELECT wert FROM indexprobe WHERE name='ix_buch_autor_autor');
CREATE TEMP VIEW probe_genre_buecher AS
SELECT genre_id,buch_id
 FROM buch_genre
 WHERE genre_id=(SELECT wert FROM indexprobe WHERE name='ix_buch_genre_genre');
CREATE TEMP VIEW probe_buch_exemplare AS
SELECT buch_id
 FROM exemplar
 WHERE buch_id=(SELECT wert FROM indexprobe WHERE name='ix_exemplar_buch');
CREATE TEMP VIEW probe_eigentuemer AS
SELECT eigentuemer_id
 FROM exemplar
 WHERE eigentuemer_id=(SELECT wert FROM indexprobe WHERE name='ix_exemplar_eigentuemer');
CREATE TEMP VIEW probe_abholadresse AS
SELECT abholadresse_id
 FROM angebot_version
 WHERE abholadresse_id=(SELECT wert FROM indexprobe WHERE name='ix_angebot_adresse');
CREATE TEMP VIEW probe_koordinaten AS
SELECT latitude,longitude
 FROM adresse
 WHERE latitude=(SELECT wert FROM indexprobe WHERE name='ix_adresse_koordinaten');
CREATE TEMP VIEW probe_person_anfragen AS
SELECT entleiher_id,angefragt_am
 FROM reservierung
 WHERE entleiher_id=(SELECT wert FROM indexprobe WHERE name='ix_reservierung_entleiher');
CREATE TEMP VIEW probe_exemplar_anfragen AS
SELECT exemplar_id,status
 FROM reservierung
 WHERE exemplar_id=(SELECT wert FROM indexprobe WHERE name='ix_reservierung_exemplar');
CREATE TEMP VIEW probe_leihversion AS
SELECT angebot_version_id
 FROM ausleihe
 WHERE angebot_version_id=(SELECT wert FROM indexprobe WHERE name='ix_ausleihe_version');
CREATE TEMP VIEW mess_historie AS
SELECT ausleihe_id,exemplar_id,beginn,faellig,rueckgabe
 FROM ausleihe
 WHERE entleiher_id=2;
CREATE TEMP VIEW mess_verfuegbar AS
SELECT exemplar_id,titel
 FROM v_verfuegbare_buecher
 WHERE exemplar_id BETWEEN 1 AND 30;
CREATE TEMP VIEW mess_rechteck AS
SELECT adresse_id,latitude,longitude
 FROM adresse
 WHERE latitude BETWEEN 48 AND 48.1 AND longitude BETWEEN 7 AND 10;
.print ALLE INDIZES: Abfragepläne und VM-Schritte
.timer off
.stats vmstep
.mode off
.eqp on
.print ix_ausleihe_exemplar_beginn
SELECT * FROM probe_exemplar_leihen ORDER BY exemplar_id,beginn;
.print ix_ausleihe_entleiher_beginn
SELECT * FROM probe_person_leihen ORDER BY entleiher_id,beginn;
.print ix_benutzer_adresse
SELECT * FROM probe_person_ort ORDER BY adresse_id;
.print ix_buch_verlag
SELECT * FROM probe_buch_verlag ORDER BY verlag_id;
.print ix_buch_sprache
SELECT * FROM probe_buch_sprache ORDER BY sprache_id;
.print ix_buch_autor_autor
SELECT * FROM probe_autor_buecher ORDER BY autor_id,buch_id;
.print ix_buch_genre_genre
SELECT * FROM probe_genre_buecher ORDER BY genre_id,buch_id;
.print ix_exemplar_buch
SELECT * FROM probe_buch_exemplare ORDER BY buch_id;
.print ix_exemplar_eigentuemer
SELECT * FROM probe_eigentuemer ORDER BY eigentuemer_id;
.print ix_angebot_adresse
SELECT * FROM probe_abholadresse ORDER BY abholadresse_id;
.print ix_adresse_koordinaten
SELECT * FROM probe_koordinaten ORDER BY latitude,longitude;
.print ix_reservierung_entleiher
SELECT * FROM probe_person_anfragen ORDER BY entleiher_id,angefragt_am;
.print ix_reservierung_exemplar
SELECT * FROM probe_exemplar_anfragen ORDER BY exemplar_id,status;
.print ix_ausleihe_version
SELECT * FROM probe_leihversion ORDER BY angebot_version_id;
.print Personenhistorie
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
.print Verfügbare Exemplare
SELECT * FROM mess_verfuegbar ORDER BY exemplar_id;
.print Reservierungen einer Person
SELECT r.reservierung_id,r.status,v.max_tage FROM reservierung r JOIN angebot_version v
 ON v.angebot_version_id=r.angebot_version_id WHERE r.entleiher_id=3 ORDER BY r.angefragt_am,r.reservierung_id;
.print Koordinatenrechteck
SELECT * FROM mess_rechteck ORDER BY adresse_id;
.print Radius 5 km
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.eqp off
.stats off
.print ALLE INDIZES: 30 warme Zeiten für vollständige Historie und Radius
.mode off
.timer off
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.timer on
.print ALLE INDIZES: Personenhistorie, Wiederholungen 1 bis 30
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
.print ALLE INDIZES: Radius 5 km, Wiederholungen 1 bis 30
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.timer off
.mode list
SELECT (SELECT page_size FROM pragma_page_size())*(SELECT page_count FROM pragma_page_count()) AS dateigroesse_bytes;
SELECT name,sum(pgsize) AS bytes FROM dbstat GROUP BY name ORDER BY name;

-- C: nur die 14 gewöhnlichen Indizes entfernen. Daten bleiben identisch.
-- Die beiden eindeutigen Indizes und alle PK-/UNIQUE-Indizes bleiben bestehen.
.print OHNE GEWÖHNLICHE INDIZES
BEGIN IMMEDIATE;
DROP INDEX ix_ausleihe_exemplar_beginn;
DROP INDEX ix_ausleihe_entleiher_beginn;
DROP INDEX ix_benutzer_adresse;
DROP INDEX ix_buch_verlag;
DROP INDEX ix_buch_sprache;
DROP INDEX ix_buch_autor_autor;
DROP INDEX ix_buch_genre_genre;
DROP INDEX ix_exemplar_buch;
DROP INDEX ix_exemplar_eigentuemer;
DROP INDEX ix_angebot_adresse;
DROP INDEX ix_adresse_koordinaten;
DROP INDEX ix_reservierung_entleiher;
DROP INDEX ix_reservierung_exemplar;
DROP INDEX ix_ausleihe_version;
COMMIT;
ANALYZE;
VACUUM;
.print OHNE GEWÖHNLICHE INDIZES: Abfragepläne und VM-Schritte
.timer off
.stats vmstep
.mode off
.eqp on
.print ix_ausleihe_exemplar_beginn
SELECT * FROM probe_exemplar_leihen ORDER BY exemplar_id,beginn;
.print ix_ausleihe_entleiher_beginn
SELECT * FROM probe_person_leihen ORDER BY entleiher_id,beginn;
.print ix_benutzer_adresse
SELECT * FROM probe_person_ort ORDER BY adresse_id;
.print ix_buch_verlag
SELECT * FROM probe_buch_verlag ORDER BY verlag_id;
.print ix_buch_sprache
SELECT * FROM probe_buch_sprache ORDER BY sprache_id;
.print ix_buch_autor_autor
SELECT * FROM probe_autor_buecher ORDER BY autor_id,buch_id;
.print ix_buch_genre_genre
SELECT * FROM probe_genre_buecher ORDER BY genre_id,buch_id;
.print ix_exemplar_buch
SELECT * FROM probe_buch_exemplare ORDER BY buch_id;
.print ix_exemplar_eigentuemer
SELECT * FROM probe_eigentuemer ORDER BY eigentuemer_id;
.print ix_angebot_adresse
SELECT * FROM probe_abholadresse ORDER BY abholadresse_id;
.print ix_adresse_koordinaten
SELECT * FROM probe_koordinaten ORDER BY latitude,longitude;
.print ix_reservierung_entleiher
SELECT * FROM probe_person_anfragen ORDER BY entleiher_id,angefragt_am;
.print ix_reservierung_exemplar
SELECT * FROM probe_exemplar_anfragen ORDER BY exemplar_id,status;
.print ix_ausleihe_version
SELECT * FROM probe_leihversion ORDER BY angebot_version_id;
.print Personenhistorie
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
.print Verfügbare Exemplare
SELECT * FROM mess_verfuegbar ORDER BY exemplar_id;
.print Reservierungen einer Person
SELECT r.reservierung_id,r.status,v.max_tage FROM reservierung r JOIN angebot_version v
 ON v.angebot_version_id=r.angebot_version_id WHERE r.entleiher_id=3 ORDER BY r.angefragt_am,r.reservierung_id;
.print Koordinatenrechteck
SELECT * FROM mess_rechteck ORDER BY adresse_id;
.print Radius 5 km
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.eqp off
.stats off
.print OHNE GEWÖHNLICHE INDIZES: 30 warme Zeiten für vollständige Historie und Radius
.mode off
.timer off
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.timer on
.print OHNE GEWÖHNLICHE INDIZES: Personenhistorie, Wiederholungen 1 bis 30
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
SELECT * FROM mess_historie ORDER BY beginn,ausleihe_id;
.print OHNE GEWÖHNLICHE INDIZES: Radius 5 km, Wiederholungen 1 bis 30
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
SELECT * FROM mess_radius_5 ORDER BY entfernung_km,exemplar_id;
.timer off
.mode list
SELECT (SELECT page_size FROM pragma_page_size())*(SELECT page_count FROM pragma_page_count()) AS dateigroesse_bytes;
SELECT name,sum(pgsize) AS bytes FROM dbstat GROUP BY name ORDER BY name;

-- Suchindizes für die Einzelprüfung wieder anlegen.
BEGIN IMMEDIATE;
CREATE INDEX ix_ausleihe_exemplar_beginn ON ausleihe(exemplar_id,beginn);
CREATE INDEX ix_ausleihe_entleiher_beginn ON ausleihe(entleiher_id,beginn);
CREATE INDEX ix_benutzer_adresse ON benutzer(adresse_id);
CREATE INDEX ix_buch_verlag ON buch(verlag_id);
CREATE INDEX ix_buch_sprache ON buch(sprache_id);
CREATE INDEX ix_buch_autor_autor ON buch_autor(autor_id,buch_id);
CREATE INDEX ix_buch_genre_genre ON buch_genre(genre_id,buch_id);
CREATE INDEX ix_exemplar_buch ON exemplar(buch_id);
CREATE INDEX ix_exemplar_eigentuemer ON exemplar(eigentuemer_id);
CREATE INDEX ix_angebot_adresse ON angebot_version(abholadresse_id);
CREATE INDEX ix_adresse_koordinaten ON adresse(latitude,longitude);
CREATE INDEX ix_reservierung_entleiher ON reservierung(entleiher_id,angefragt_am);
CREATE INDEX ix_reservierung_exemplar ON reservierung(exemplar_id,status);
CREATE INDEX ix_ausleihe_version ON ausleihe(angebot_version_id);
COMMIT;
ANALYZE;
VACUUM;

-- D: je einen Index weglassen, danach per ROLLBACK wiederherstellen.
.timer off
.stats vmstep
.mode off
.eqp on
.print EINZELPRÜFUNG ix_ausleihe_exemplar_beginn: vorhanden
SELECT * FROM probe_exemplar_leihen ORDER BY exemplar_id,beginn;
SAVEPOINT indexvergleich;
DROP INDEX ix_ausleihe_exemplar_beginn;
ANALYZE;
.print EINZELPRÜFUNG ix_ausleihe_exemplar_beginn: entfernt
SELECT * FROM probe_exemplar_leihen ORDER BY exemplar_id,beginn;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_ausleihe_entleiher_beginn: vorhanden
SELECT * FROM probe_person_leihen ORDER BY entleiher_id,beginn;
SAVEPOINT indexvergleich;
DROP INDEX ix_ausleihe_entleiher_beginn;
ANALYZE;
.print EINZELPRÜFUNG ix_ausleihe_entleiher_beginn: entfernt
SELECT * FROM probe_person_leihen ORDER BY entleiher_id,beginn;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_benutzer_adresse: vorhanden
SELECT * FROM probe_person_ort ORDER BY adresse_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_benutzer_adresse;
ANALYZE;
.print EINZELPRÜFUNG ix_benutzer_adresse: entfernt
SELECT * FROM probe_person_ort ORDER BY adresse_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_buch_verlag: vorhanden
SELECT * FROM probe_buch_verlag ORDER BY verlag_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_buch_verlag;
ANALYZE;
.print EINZELPRÜFUNG ix_buch_verlag: entfernt
SELECT * FROM probe_buch_verlag ORDER BY verlag_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_buch_sprache: vorhanden
SELECT * FROM probe_buch_sprache ORDER BY sprache_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_buch_sprache;
ANALYZE;
.print EINZELPRÜFUNG ix_buch_sprache: entfernt
SELECT * FROM probe_buch_sprache ORDER BY sprache_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_buch_autor_autor: vorhanden
SELECT * FROM probe_autor_buecher ORDER BY autor_id,buch_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_buch_autor_autor;
ANALYZE;
.print EINZELPRÜFUNG ix_buch_autor_autor: entfernt
SELECT * FROM probe_autor_buecher ORDER BY autor_id,buch_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_buch_genre_genre: vorhanden
SELECT * FROM probe_genre_buecher ORDER BY genre_id,buch_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_buch_genre_genre;
ANALYZE;
.print EINZELPRÜFUNG ix_buch_genre_genre: entfernt
SELECT * FROM probe_genre_buecher ORDER BY genre_id,buch_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_exemplar_buch: vorhanden
SELECT * FROM probe_buch_exemplare ORDER BY buch_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_exemplar_buch;
ANALYZE;
.print EINZELPRÜFUNG ix_exemplar_buch: entfernt
SELECT * FROM probe_buch_exemplare ORDER BY buch_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_exemplar_eigentuemer: vorhanden
SELECT * FROM probe_eigentuemer ORDER BY eigentuemer_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_exemplar_eigentuemer;
ANALYZE;
.print EINZELPRÜFUNG ix_exemplar_eigentuemer: entfernt
SELECT * FROM probe_eigentuemer ORDER BY eigentuemer_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_angebot_adresse: vorhanden
SELECT * FROM probe_abholadresse ORDER BY abholadresse_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_angebot_adresse;
ANALYZE;
.print EINZELPRÜFUNG ix_angebot_adresse: entfernt
SELECT * FROM probe_abholadresse ORDER BY abholadresse_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_adresse_koordinaten: vorhanden
SELECT * FROM probe_koordinaten ORDER BY latitude,longitude;
SAVEPOINT indexvergleich;
DROP INDEX ix_adresse_koordinaten;
ANALYZE;
.print EINZELPRÜFUNG ix_adresse_koordinaten: entfernt
SELECT * FROM probe_koordinaten ORDER BY latitude,longitude;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_reservierung_entleiher: vorhanden
SELECT * FROM probe_person_anfragen ORDER BY entleiher_id,angefragt_am;
SAVEPOINT indexvergleich;
DROP INDEX ix_reservierung_entleiher;
ANALYZE;
.print EINZELPRÜFUNG ix_reservierung_entleiher: entfernt
SELECT * FROM probe_person_anfragen ORDER BY entleiher_id,angefragt_am;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_reservierung_exemplar: vorhanden
SELECT * FROM probe_exemplar_anfragen ORDER BY exemplar_id,status;
SAVEPOINT indexvergleich;
DROP INDEX ix_reservierung_exemplar;
ANALYZE;
.print EINZELPRÜFUNG ix_reservierung_exemplar: entfernt
SELECT * FROM probe_exemplar_anfragen ORDER BY exemplar_id,status;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.print EINZELPRÜFUNG ix_ausleihe_version: vorhanden
SELECT * FROM probe_leihversion ORDER BY angebot_version_id;
SAVEPOINT indexvergleich;
DROP INDEX ix_ausleihe_version;
ANALYZE;
.print EINZELPRÜFUNG ix_ausleihe_version: entfernt
SELECT * FROM probe_leihversion ORDER BY angebot_version_id;
ROLLBACK TO indexvergleich;
RELEASE indexvergleich;
.eqp off
.stats off
.timer off
.mode list
DROP VIEW temp.probe_exemplar_leihen;
DROP VIEW temp.probe_person_leihen;
DROP VIEW temp.probe_person_ort;
DROP VIEW temp.probe_buch_verlag;
DROP VIEW temp.probe_buch_sprache;
DROP VIEW temp.probe_autor_buecher;
DROP VIEW temp.probe_genre_buecher;
DROP VIEW temp.probe_buch_exemplare;
DROP VIEW temp.probe_eigentuemer;
DROP VIEW temp.probe_abholadresse;
DROP VIEW temp.probe_koordinaten;
DROP VIEW temp.probe_person_anfragen;
DROP VIEW temp.probe_exemplar_anfragen;
DROP VIEW temp.probe_leihversion;
DROP VIEW temp.mess_historie;
DROP VIEW temp.mess_verfuegbar;
DROP VIEW temp.mess_rechteck;
DROP TABLE temp.indexprobe;
DROP VIEW temp.mess_radius_5;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT count(*) AS gewoehnliche_indizes FROM sqlite_schema WHERE type='index' AND sql LIKE 'CREATE INDEX%';
SELECT name FROM sqlite_schema WHERE type='index' AND sql LIKE 'CREATE UNIQUE INDEX%' ORDER BY name;
-- Erwartet: 14 sowie uq_ausleihe_laufend und uq_reservierung_bestaetigt.
-- Entscheidung: Treffer und Reihenfolge vergleichen; Plan, VM-Schritte, Größe
-- und Schreibaufwand gemeinsam ansehen. Ein günstiger Filter beweist keinen
-- allgemeinen Zeitvorteil bei großer Ergebnismenge oder kleiner Datenmenge.
-- 30 Zeitwerte sortieren: Median Mittel aus Wert 15/16, P95 Wert 29 (nearest rank).
-- Schreiben separat auf Kopien messen: BEGIN IMMEDIATE + vollständiger Vorgang
-- + COMMIT, z.B. die SQL-Abläufe aus 05_tests (Anfrage/Umsetzung/Rückgabe/Version).
-- Ein ROLLBACK-Test ist kein dauerhaft gespeicherter Schreibbenchmark.
