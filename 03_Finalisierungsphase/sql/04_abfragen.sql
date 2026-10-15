-- Beispiele für die fertige Datenbank; diese Abfragen ändern keine Daten.
PRAGMA foreign_keys=ON;
PRAGMA recursive_triggers=ON;

-- Q01 Aktuell verfügbare Bücher mit Abholort.
SELECT exemplar_id,titel,max_tage,versand,ort,latitude,longitude,angebot_version_id
FROM v_verfuegbare_buecher ORDER BY exemplar_id;

-- Q02 Frühere Ausleihen mit den damals vereinbarten Bedingungen.
SELECT ausleihe_id,exemplar_id,beginn,faellig,rueckgabe,bedingungen_status,
 versionsnummer,max_tage,versand,abholadresse_id,strasse,hausnummer,ort
FROM v_ausleihbedingungen WHERE exemplar_id=1 ORDER BY beginn;

-- Q03 Angebotsversionen und ihre Gültigkeitszeiträume.
SELECT exemplar_id,versionsnummer,gueltig_von,gueltig_bis,max_tage,versand,abholadresse_id
FROM v_angebot_intervalle WHERE exemplar_id IN(1,20) ORDER BY exemplar_id,versionsnummer;

-- Q04 Anfragen und alle protokollierten Statuswechsel.
SELECT r.reservierung_id,r.exemplar_id,r.entleiher_id,r.angebot_version_id,r.status,
 e.status_von,e.status_nach,e.zeitpunkt
FROM reservierung r JOIN reservierungsereignis e ON e.reservierung_id=r.reservierung_id
ORDER BY r.reservierung_id,e.ereignis_id;

-- Q05 Reservierungen für Exemplar 16 und seine Verfügbarkeit.
SELECT r.reservierung_id,r.entleiher_id,r.status,r.status_am,
 EXISTS(SELECT 1 FROM v_verfuegbare_buecher b WHERE b.exemplar_id=r.exemplar_id) AS verfuegbar
FROM reservierung r WHERE r.exemplar_id=16 ORDER BY r.reservierung_id;

-- Q06 Anfrage und aktuelle Angebotsversion vergleichen.
SELECT r.reservierung_id,r.exemplar_id,r.status,r.angebot_version_id,
 e.aktuelle_version_id,r.angebot_version_id=e.aktuelle_version_id AS version_aktuell
FROM reservierung r JOIN exemplar e ON e.exemplar_id=r.exemplar_id
WHERE r.exemplar_id=20 ORDER BY r.reservierung_id;

-- Q07 Überfällige, noch nicht zurückgegebene Bücher.
SELECT l.ausleihe_id,l.exemplar_id,l.faellig,l.rueckgabe,
 EXISTS(SELECT 1 FROM v_verfuegbare_buecher b WHERE b.exemplar_id=l.exemplar_id) AS verfuegbar
FROM ausleihe l WHERE l.rueckgabe IS NULL AND l.faellig<'2026-10-20 00:00:00'
ORDER BY l.ausleihe_id;

-- Q08 Bücher mit Autorennamen (Join über drei Tabellen).
SELECT b.buch_id,b.titel,a.name AS autor
FROM buch b JOIN buch_autor x ON x.buch_id=b.buch_id JOIN autor a ON a.autor_id=x.autor_id
ORDER BY b.buch_id,a.autor_id;

-- Q09 Anzahl und Durchschnitt der Bewertungen.
SELECT buch_id,titel,anzahl,round(durchschnitt,2) AS durchschnitt
FROM v_buchbewertungen ORDER BY buch_id;

-- Q10 Tabellen, Speichergröße und Integrität.
SELECT count(*) AS tabellen FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%';
PRAGMA page_size;
PRAGMA page_count;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'abholzeit' AS tabelle,count(*) AS zeilen FROM abholzeit
UNION ALL SELECT 'adresse',count(*) FROM adresse
UNION ALL SELECT 'angebot_version',count(*) FROM angebot_version
UNION ALL SELECT 'ausleihe',count(*) FROM ausleihe
UNION ALL SELECT 'autor',count(*) FROM autor
UNION ALL SELECT 'benutzer',count(*) FROM benutzer
UNION ALL SELECT 'bewertung',count(*) FROM bewertung
UNION ALL SELECT 'buch',count(*) FROM buch
UNION ALL SELECT 'buch_autor',count(*) FROM buch_autor
UNION ALL SELECT 'buch_genre',count(*) FROM buch_genre
UNION ALL SELECT 'exemplar',count(*) FROM exemplar
UNION ALL SELECT 'genre',count(*) FROM genre
UNION ALL SELECT 'reservierung',count(*) FROM reservierung
UNION ALL SELECT 'reservierungsereignis',count(*) FROM reservierungsereignis
UNION ALL SELECT 'sprache',count(*) FROM sprache
UNION ALL SELECT 'verlag',count(*) FROM verlag;
SELECT (SELECT page_size FROM pragma_page_size()) *
       (SELECT page_count FROM pragma_page_count()) AS datenbank_bytes;

-- Q11 Bücher im Umkreis: Breite, Länge und Radius in VALUES ändern.
-- Benötigt SQLite-Mathematikfunktionen; Entfernungen sind Luftlinien.
WITH eingabe(lat,lon,radius_km) AS (
 VALUES(52.52,13.405,2.0)
), parameter AS (
 SELECT lat,lon,radius_km FROM eingabe
 WHERE typeof(lat) IN ('integer','real') AND lat BETWEEN -90 AND 90
 AND typeof(lon) IN ('integer','real') AND lon BETWEEN -180 AND 180
 AND typeof(radius_km) IN ('integer','real') AND radius_km BETWEEN 0 AND 1.0e100
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
