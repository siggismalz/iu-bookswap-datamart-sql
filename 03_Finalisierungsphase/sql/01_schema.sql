-- BookSwap: 16 Tabellen, 74 Attribute und 16 angelegte Indizes.
-- Neue, leere Datenbank; danach 02 und 03 in derselben Verbindung ausführen.
-- SQLite ab 3.45; die Nähesuche braucht zusätzlich Mathematikfunktionen.
-- Die PRAGMAs bei jeder neuen Verbindung vor BEGIN setzen. Zeiten sind UTC.
PRAGMA foreign_keys=ON;
PRAGMA recursive_triggers=ON;
BEGIN IMMEDIATE;

-- Adressen mit Koordinaten für die Nähesuche.
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

-- Mitglieder: E-Mail in ASCII und Kleinschreibung; keine Zustellprüfung.
CREATE TABLE benutzer (
 benutzer_id INTEGER PRIMARY KEY,
 name TEXT NOT NULL CHECK (name = trim(name) AND length(name)>0),
 email TEXT NOT NULL UNIQUE CHECK (
   email = lower(email) AND email NOT GLOB '*[^!-~]*'
   AND email LIKE '_%@_%._%' AND length(email)-length(replace(email,'@',''))=1),
 adresse_id INTEGER NOT NULL REFERENCES adresse(adresse_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) STRICT;

-- Verlag, Sprache und Buch beschreiben die Ausgabe.
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

-- Autoren und Genres werden über Zuordnungstabellen angebunden.
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

-- Exemplar im Besitz eines Mitglieds; eigene aktuelle Version ist Pflicht.
-- Der gegenseitige Verweis wird erst bei COMMIT geprüft.
CREATE TABLE exemplar (
 exemplar_id INTEGER PRIMARY KEY,
 buch_id INTEGER NOT NULL REFERENCES buch(buch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 eigentuemer_id INTEGER NOT NULL REFERENCES benutzer(benutzer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 zustand TEXT NOT NULL CHECK (zustand IN ('neu','gut','gebraucht')),
 aktuelle_version_id INTEGER NOT NULL,
 FOREIGN KEY(aktuelle_version_id,exemplar_id)
 REFERENCES angebot_version(angebot_version_id,exemplar_id) DEFERRABLE INITIALLY DEFERRED
) STRICT;

-- Angebotsbedingungen bleiben unverändert; Änderungen erzeugen eine neue Version.
-- Das Gültigkeitsende ergibt sich aus der Folgeversion.
CREATE TABLE angebot_version (
 angebot_version_id INTEGER PRIMARY KEY,
 exemplar_id INTEGER NOT NULL REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 versionsnummer INTEGER NOT NULL CHECK(versionsnummer>=1),
 gueltig_von TEXT NOT NULL CHECK(length(gueltig_von)=19 AND substr(gueltig_von,1,4) BETWEEN '0001' AND '9999'
   AND datetime(gueltig_von,'+0 seconds') IS NOT NULL AND datetime(gueltig_von,'+0 seconds')=gueltig_von),
 max_tage INTEGER NOT NULL CHECK(max_tage BETWEEN 1 AND 365),
 versand INTEGER NOT NULL CHECK(versand IN(0,1)),
 abholadresse_id INTEGER NOT NULL REFERENCES adresse(adresse_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 angeboten INTEGER NOT NULL CHECK(angeboten IN(0,1)),
 UNIQUE(exemplar_id,versionsnummer),
 UNIQUE(exemplar_id,gueltig_von),
 UNIQUE(angebot_version_id,exemplar_id)
) STRICT;

-- Anfragen blockieren nicht; erst eine Bestätigung reserviert das Exemplar.
CREATE TABLE reservierung (
 reservierung_id INTEGER PRIMARY KEY,
 exemplar_id INTEGER NOT NULL REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 entleiher_id INTEGER NOT NULL REFERENCES benutzer(benutzer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 angebot_version_id INTEGER NOT NULL,
 angefragt_am TEXT NOT NULL CHECK(length(angefragt_am)=19 AND substr(angefragt_am,1,4) BETWEEN '0001' AND '9999'
   AND datetime(angefragt_am,'+0 seconds') IS NOT NULL AND datetime(angefragt_am,'+0 seconds')=angefragt_am),
 status TEXT NOT NULL CHECK(status IN('angefragt','bestaetigt','umgesetzt','abgelehnt','storniert')),
 status_am TEXT NOT NULL CHECK(length(status_am)=19 AND substr(status_am,1,4) BETWEEN '0001' AND '9999'
   AND datetime(status_am,'+0 seconds') IS NOT NULL AND datetime(status_am,'+0 seconds')=status_am AND status_am>=angefragt_am),
 weg TEXT NOT NULL CHECK(weg IN('abholung','post')),
 FOREIGN KEY(angebot_version_id,exemplar_id) REFERENCES angebot_version(angebot_version_id,exemplar_id)
 ON DELETE RESTRICT ON UPDATE RESTRICT
) STRICT;

-- Die Trigger speichern jeden Statuswechsel einmal.
CREATE TABLE reservierungsereignis (
 ereignis_id INTEGER PRIMARY KEY,
 reservierung_id INTEGER NOT NULL REFERENCES reservierung(reservierung_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 status_von TEXT CHECK(status_von IN('angefragt','bestaetigt')),
 status_nach TEXT NOT NULL CHECK(status_nach IN('angefragt','bestaetigt','umgesetzt','abgelehnt','storniert')),
 zeitpunkt TEXT NOT NULL CHECK(length(zeitpunkt)=19 AND substr(zeitpunkt,1,4) BETWEEN '0001' AND '9999'
   AND datetime(zeitpunkt,'+0 seconds') IS NOT NULL AND datetime(zeitpunkt,'+0 seconds')=zeitpunkt),
 CHECK(status_von IS NULL OR status_von<>status_nach),
 UNIQUE(reservierung_id,status_nach)
) STRICT;

-- Abholfenster [von,bis); Zeiten im Format YYYY-MM-DD HH:MM:SS (UTC).
-- Die Datumsprüfung weist auch ungültige Kalendertage ab.
CREATE TABLE abholzeit (
 abholzeit_id INTEGER PRIMARY KEY,
 exemplar_id INTEGER NOT NULL REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 von TEXT NOT NULL CHECK (length(von)=19 AND substr(von,1,4) BETWEEN '0001' AND '9999'
   AND datetime(von,'+0 seconds') IS NOT NULL AND datetime(von,'+0 seconds')=von),
 bis TEXT NOT NULL CHECK (length(bis)=19 AND substr(bis,1,4) BETWEEN '0001' AND '9999'
   AND datetime(bis,'+0 seconds') IS NOT NULL AND datetime(bis,'+0 seconds')=bis AND bis>von),
 UNIQUE (exemplar_id, von, bis)
) STRICT;

-- Neue Leihen verweisen auf Reservierung und vereinbarte Version.
-- Nur der Altimport darf unbekannte Bedingungen mit NULL speichern.
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
 weg TEXT NOT NULL DEFAULT 'abholung' CHECK (weg IN ('abholung','post')),
 angebot_version_id INTEGER,
 reservierung_id INTEGER UNIQUE REFERENCES reservierung(reservierung_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 bedingungen_status TEXT NOT NULL CHECK(bedingungen_status IN('versioniert','unbekannt')),
 CHECK((bedingungen_status='versioniert' AND angebot_version_id IS NOT NULL AND reservierung_id IS NOT NULL)
    OR (bedingungen_status='unbekannt' AND angebot_version_id IS NULL AND reservierung_id IS NULL)),
 FOREIGN KEY(angebot_version_id,exemplar_id) REFERENCES angebot_version(angebot_version_id,exemplar_id)
 ON DELETE RESTRICT ON UPDATE RESTRICT
) STRICT;

-- Höchstens eine Bewertung je abgeschlossener Ausleihe.
CREATE TABLE bewertung (
 bewertung_id INTEGER PRIMARY KEY,
 ausleihe_id INTEGER NOT NULL UNIQUE REFERENCES ausleihe(ausleihe_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 sterne INTEGER NOT NULL CHECK (sterne BETWEEN 1 AND 5),
 kommentar TEXT
) STRICT;

-- 14 Suchindizes und 2 eindeutige Indizes; laufende Vorgänge bleiben eindeutig.
CREATE UNIQUE INDEX uq_ausleihe_laufend ON ausleihe(exemplar_id) WHERE rueckgabe IS NULL;

-- Suchwege für Ausleihen, Katalog und Orte; Nutzen am Abfrageplan prüfen.
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

-- Höchstens eine bestätigte Reservierung je Exemplar.
CREATE UNIQUE INDEX uq_reservierung_bestaetigt ON reservierung(exemplar_id) WHERE status='bestaetigt';
CREATE INDEX ix_reservierung_entleiher ON reservierung(entleiher_id,angefragt_am);
CREATE INDEX ix_reservierung_exemplar ON reservierung(exemplar_id,status);
CREATE INDEX ix_ausleihe_version ON ausleihe(angebot_version_id);
COMMIT;
