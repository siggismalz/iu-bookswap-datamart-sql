-- BookSwap: 29 Trigger und 5 Sichten, nach 01 ausführen.
-- Zusammengehörige Änderungen mit BEGIN IMMEDIATE/COMMIT, bei Fehler ROLLBACK.
-- RAISE(ABORT) verwirft die fehlerhafte Anweisung einschließlich ihrer Trigger.
-- Kein eigener Transaktionsrahmen: 07 aktiviert die Regeln vor seinem COMMIT.
-- Exemplar und Eigentum bleiben stabil; nur die neueste eigene Version ist aktuell.
CREATE TRIGGER exemplar_update BEFORE UPDATE ON exemplar BEGIN
 SELECT RAISE(ABORT,'EXEMPLAR_HISTORIE') WHERE
  NEW.exemplar_id<>OLD.exemplar_id OR NEW.buch_id<>OLD.buch_id OR NEW.eigentuemer_id<>OLD.eigentuemer_id;
 SELECT RAISE(ABORT,'AKTUELLE_VERSION') WHERE NEW.aktuelle_version_id IS NOT
  (SELECT angebot_version_id FROM angebot_version WHERE exemplar_id=OLD.exemplar_id ORDER BY versionsnummer DESC LIMIT 1);
 SELECT RAISE(ABORT,'EXEMPLAR_LAUFEND') WHERE NEW.zustand<>OLD.zustand AND (
  EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND rueckgabe IS NULL)
  OR EXISTS(SELECT 1 FROM reservierung WHERE exemplar_id=OLD.exemplar_id AND status='bestaetigt'));
END;

CREATE TRIGGER exemplar_delete BEFORE DELETE ON exemplar
WHEN EXISTS(SELECT 1 FROM angebot_version WHERE exemplar_id=OLD.exemplar_id)
BEGIN SELECT RAISE(ABORT,'EXEMPLAR_HISTORIE'); END;

CREATE TRIGGER exemplar_replace BEFORE INSERT ON exemplar
WHEN EXISTS(SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id)
BEGIN SELECT RAISE(ABORT,'EXEMPLAR_HISTORIE'); END;

-- Versionen folgen zeitlich aufeinander. Laufende Vorgänge sperren Änderungen.
CREATE TRIGGER angebot_version_insert BEFORE INSERT ON angebot_version BEGIN
 SELECT RAISE(ABORT,'ANGEBOT_HISTORIE') WHERE EXISTS(
  SELECT 1 FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id);
 SELECT RAISE(ABORT,'VERSION_REIHENFOLGE') WHERE NEW.versionsnummer<>
  coalesce((SELECT max(versionsnummer)+1 FROM angebot_version WHERE exemplar_id=NEW.exemplar_id),1)
  OR EXISTS(SELECT 1 FROM angebot_version WHERE exemplar_id=NEW.exemplar_id AND gueltig_von>=NEW.gueltig_von);
 SELECT RAISE(ABORT,'VERSION_RUECKDATIERT') WHERE EXISTS(
  SELECT 1 FROM reservierung WHERE exemplar_id=NEW.exemplar_id AND status_am>NEW.gueltig_von)
  OR EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=NEW.exemplar_id AND coalesce(rueckgabe,beginn)>NEW.gueltig_von);
 SELECT RAISE(ABORT,'EXEMPLAR_LAUFEND') WHERE
  EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=NEW.exemplar_id AND rueckgabe IS NULL)
  OR EXISTS(SELECT 1 FROM reservierung WHERE exemplar_id=NEW.exemplar_id AND status='bestaetigt');
 SELECT RAISE(ABORT,'ANGEBOT_KATALOG') WHERE NEW.angeboten=1 AND (
  NOT EXISTS(SELECT 1 FROM exemplar e JOIN buch_autor b ON b.buch_id=e.buch_id WHERE e.exemplar_id=NEW.exemplar_id)
  OR NOT EXISTS(SELECT 1 FROM exemplar e JOIN buch_genre b ON b.buch_id=e.buch_id WHERE e.exemplar_id=NEW.exemplar_id));
END;

CREATE TRIGGER angebot_version_aktuell AFTER INSERT ON angebot_version BEGIN
 UPDATE exemplar SET aktuelle_version_id=NEW.angebot_version_id WHERE exemplar_id=NEW.exemplar_id;
END;

CREATE TRIGGER angebot_version_update BEFORE UPDATE ON angebot_version
BEGIN SELECT RAISE(ABORT,'ANGEBOT_UNVERAENDERLICH'); END;

CREATE TRIGGER angebot_version_delete BEFORE DELETE ON angebot_version
BEGIN SELECT RAISE(ABORT,'ANGEBOT_HISTORIE'); END;

-- Genutzte Adressen bleiben unverändert; ein neuer Abholort braucht eine neue Zeile.
CREATE TRIGGER adresse_historie_update BEFORE UPDATE ON adresse
WHEN EXISTS(SELECT 1 FROM angebot_version WHERE abholadresse_id=OLD.adresse_id)
BEGIN SELECT RAISE(ABORT,'ADRESSE_HISTORIE'); END;

CREATE TRIGGER adresse_historie_delete BEFORE DELETE ON adresse
WHEN EXISTS(SELECT 1 FROM angebot_version WHERE abholadresse_id=OLD.adresse_id)
BEGIN SELECT RAISE(ABORT,'ADRESSE_HISTORIE'); END;

-- Aktive Angebote behalten mindestens einen Autor und ein Genre.
CREATE TRIGGER autor_zuordnung_delete BEFORE DELETE ON buch_autor
WHEN EXISTS(SELECT 1 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id
 WHERE e.buch_id=OLD.buch_id AND v.angeboten=1)
 AND NOT EXISTS(SELECT 1 FROM buch_autor WHERE buch_id=OLD.buch_id AND autor_id<>OLD.autor_id)
BEGIN SELECT RAISE(ABORT,'LETZTER_AUTOR'); END;

CREATE TRIGGER autor_zuordnung_update BEFORE UPDATE ON buch_autor WHEN NEW.buch_id<>OLD.buch_id
 AND EXISTS(SELECT 1 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id
 WHERE e.buch_id=OLD.buch_id AND v.angeboten=1)
 AND NOT EXISTS(SELECT 1 FROM buch_autor WHERE buch_id=OLD.buch_id AND autor_id<>OLD.autor_id)
BEGIN SELECT RAISE(ABORT,'LETZTER_AUTOR'); END;

CREATE TRIGGER genre_zuordnung_delete BEFORE DELETE ON buch_genre
WHEN EXISTS(SELECT 1 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id
 WHERE e.buch_id=OLD.buch_id AND v.angeboten=1)
 AND NOT EXISTS(SELECT 1 FROM buch_genre WHERE buch_id=OLD.buch_id AND genre_id<>OLD.genre_id)
BEGIN SELECT RAISE(ABORT,'LETZTES_GENRE'); END;

CREATE TRIGGER genre_zuordnung_update BEFORE UPDATE ON buch_genre WHEN NEW.buch_id<>OLD.buch_id
 AND EXISTS(SELECT 1 FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id
 WHERE e.buch_id=OLD.buch_id AND v.angeboten=1)
 AND NOT EXISTS(SELECT 1 FROM buch_genre WHERE buch_id=OLD.buch_id AND genre_id<>OLD.genre_id)
BEGIN SELECT RAISE(ABORT,'LETZTES_GENRE'); END;

-- Anfragen beziehen sich auf das aktuelle Angebot; die Bestätigung prüft die Belegung.
CREATE TRIGGER reservierung_insert BEFORE INSERT ON reservierung BEGIN
 SELECT RAISE(ABORT,'RESERVIERUNG_HISTORIE') WHERE EXISTS(
  SELECT 1 FROM reservierung WHERE reservierung_id=NEW.reservierung_id);
 SELECT RAISE(ABORT,'RESERVIERUNG_START') WHERE NEW.status<>'angefragt' OR NEW.status_am<>NEW.angefragt_am;
 SELECT RAISE(ABORT,'SELBSTAUSLEIHE') WHERE EXISTS(
  SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id AND eigentuemer_id=NEW.entleiher_id);
 SELECT RAISE(ABORT,'VERSION_NICHT_AKTUELL') WHERE NEW.angebot_version_id IS NOT
  (SELECT aktuelle_version_id FROM exemplar WHERE exemplar_id=NEW.exemplar_id);
 SELECT RAISE(ABORT,'VERSION_ZEIT') WHERE NEW.angefragt_am<
  (SELECT gueltig_von FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id);
 SELECT RAISE(ABORT,'KEIN_ANGEBOT') WHERE EXISTS(
  SELECT 1 FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id AND angeboten=0);
 SELECT RAISE(ABORT,'VERSAND_NICHT_ERLAUBT') WHERE NEW.weg='post' AND EXISTS(
  SELECT 1 FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id AND versand=0);
END;

-- Vertragsfelder bleiben gleich; abgeschlossene Status werden nicht erneut geöffnet.
CREATE TRIGGER reservierung_update BEFORE UPDATE ON reservierung BEGIN
 SELECT RAISE(ABORT,'RESERVIERUNG_UNVERAENDERLICH') WHERE
  NEW.reservierung_id<>OLD.reservierung_id OR NEW.exemplar_id<>OLD.exemplar_id
  OR NEW.entleiher_id<>OLD.entleiher_id OR NEW.angebot_version_id<>OLD.angebot_version_id
  OR NEW.angefragt_am<>OLD.angefragt_am OR NEW.weg<>OLD.weg;
 SELECT RAISE(ABORT,'STATUS_UEBERGANG') WHERE NOT(
  (OLD.status='angefragt' AND NEW.status IN('bestaetigt','abgelehnt','storniert'))
  OR (OLD.status='bestaetigt' AND NEW.status IN('umgesetzt','storniert'))
  OR (OLD.status=NEW.status AND OLD.status_am=NEW.status_am));
 SELECT RAISE(ABORT,'STATUS_ZEIT') WHERE NEW.status_am<OLD.status_am;
 SELECT RAISE(ABORT,'VERSION_NICHT_AKTUELL') WHERE NEW.status='bestaetigt' AND NEW.angebot_version_id IS NOT
  (SELECT aktuelle_version_id FROM exemplar WHERE exemplar_id=NEW.exemplar_id);
 SELECT RAISE(ABORT,'EXEMPLAR_BELEGT') WHERE NEW.status='bestaetigt' AND (
  EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=NEW.exemplar_id AND rueckgabe IS NULL)
  OR EXISTS(SELECT 1 FROM reservierung WHERE exemplar_id=NEW.exemplar_id AND status='bestaetigt'
    AND reservierung_id<>OLD.reservierung_id));
 SELECT RAISE(ABORT,'STATUS_OHNE_AUSLEIHE') WHERE NEW.status='umgesetzt' AND NOT EXISTS(
  SELECT 1 FROM ausleihe WHERE reservierung_id=NEW.reservierung_id AND beginn=NEW.status_am);
 SELECT RAISE(ABORT,'RESERVIERUNG_BEREITS_UMGESETZT') WHERE NEW.status<>'umgesetzt' AND EXISTS(
  SELECT 1 FROM ausleihe WHERE reservierung_id=NEW.reservierung_id);
END;

CREATE TRIGGER reservierung_delete BEFORE DELETE ON reservierung
BEGIN SELECT RAISE(ABORT,'RESERVIERUNG_HISTORIE'); END;

-- Statuswechsel werden automatisch protokolliert.
CREATE TRIGGER reservierung_initialereignis AFTER INSERT ON reservierung BEGIN
 INSERT INTO reservierungsereignis(reservierung_id,status_von,status_nach,zeitpunkt)
 VALUES(NEW.reservierung_id,NULL,NEW.status,NEW.status_am);
END;

CREATE TRIGGER reservierung_statusereignis AFTER UPDATE OF status ON reservierung
WHEN NEW.status<>OLD.status BEGIN
 INSERT INTO reservierungsereignis(reservierung_id,status_von,status_nach,zeitpunkt)
 VALUES(NEW.reservierung_id,OLD.status,NEW.status,NEW.status_am);
END;

-- Ereignisse müssen zum letzten Status und Zeitpunkt passen und bleiben erhalten.
CREATE TRIGGER ereignis_insert BEFORE INSERT ON reservierungsereignis BEGIN
 SELECT RAISE(ABORT,'EREIGNIS_UNGUELTIG') WHERE NOT EXISTS(
  SELECT 1 FROM reservierung WHERE reservierung_id=NEW.reservierung_id
  AND status=NEW.status_nach AND status_am=NEW.zeitpunkt);
 SELECT RAISE(ABORT,'EREIGNIS_REIHENFOLGE') WHERE NEW.status_von IS NOT
  (SELECT status_nach FROM reservierungsereignis WHERE reservierung_id=NEW.reservierung_id ORDER BY ereignis_id DESC LIMIT 1);
 SELECT RAISE(ABORT,'EREIGNIS_START') WHERE NEW.status_von IS NULL AND NEW.status_nach<>'angefragt';
END;

CREATE TRIGGER ereignis_update BEFORE UPDATE ON reservierungsereignis
BEGIN SELECT RAISE(ABORT,'EREIGNIS_UNVERAENDERLICH'); END;

CREATE TRIGGER ereignis_delete BEFORE DELETE ON reservierungsereignis
BEGIN SELECT RAISE(ABORT,'EREIGNIS_HISTORIE'); END;

-- Neue Leihen brauchen eine passende Bestätigung; Altimport nur über Datei 07.
CREATE TRIGGER ausleihe_insert BEFORE INSERT ON ausleihe BEGIN
 SELECT RAISE(ABORT,'AUSLEIHE_HISTORIE') WHERE EXISTS(SELECT 1 FROM ausleihe WHERE ausleihe_id=NEW.ausleihe_id);
 SELECT RAISE(ABORT,'HISTORIE_NUR_MIGRATION') WHERE NEW.bedingungen_status<>'versioniert';
 SELECT RAISE(ABORT,'RESERVIERUNG_FEHLT') WHERE NOT EXISTS(
  SELECT 1 FROM reservierung r WHERE r.reservierung_id=NEW.reservierung_id AND r.status='bestaetigt'
   AND r.exemplar_id=NEW.exemplar_id AND r.entleiher_id=NEW.entleiher_id
   AND r.angebot_version_id=NEW.angebot_version_id AND r.weg=NEW.weg AND r.status_am<=NEW.beginn);
 SELECT RAISE(ABORT,'SELBSTAUSLEIHE') WHERE EXISTS(
  SELECT 1 FROM exemplar WHERE exemplar_id=NEW.exemplar_id AND eigentuemer_id=NEW.entleiher_id);
 SELECT RAISE(ABORT,'LEIHDAUER') WHERE unixepoch(NEW.faellig)-unixepoch(NEW.beginn)>
  (SELECT max_tage*86400 FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id);
 SELECT RAISE(ABORT,'VERSAND_NICHT_ERLAUBT') WHERE NEW.weg='post' AND EXISTS(
  SELECT 1 FROM angebot_version WHERE angebot_version_id=NEW.angebot_version_id AND versand=0);
 SELECT RAISE(ABORT,'ABHOLZEIT_FEHLT') WHERE NEW.weg='abholung' AND NOT EXISTS(
  SELECT 1 FROM abholzeit WHERE exemplar_id=NEW.exemplar_id AND von<=NEW.beginn AND NEW.beginn<bis);
 SELECT RAISE(ABORT,'AUSLEIHE_UEBERLAPPT') WHERE EXISTS(
  SELECT 1 FROM ausleihe a WHERE a.exemplar_id=NEW.exemplar_id
   AND (NEW.rueckgabe IS NULL OR a.beginn<NEW.rueckgabe)
   AND (a.rueckgabe IS NULL OR NEW.beginn<a.rueckgabe));
END;

-- Der Leiheintrag setzt die Reservierung im selben Vorgang um.
CREATE TRIGGER ausleihe_umsetzung AFTER INSERT ON ausleihe BEGIN
 UPDATE reservierung SET status='umgesetzt',status_am=NEW.beginn WHERE reservierung_id=NEW.reservierung_id;
END;

-- Vertragsdaten und verbuchte Rückgaben bleiben erhalten; keine Überschneidungen.
CREATE TRIGGER ausleihe_update BEFORE UPDATE ON ausleihe BEGIN
 SELECT RAISE(ABORT,'AUSLEIHE_UNVERAENDERLICH') WHERE
  NEW.ausleihe_id<>OLD.ausleihe_id OR NEW.exemplar_id<>OLD.exemplar_id OR NEW.entleiher_id<>OLD.entleiher_id
  OR NEW.beginn<>OLD.beginn OR NEW.faellig<>OLD.faellig OR NEW.weg<>OLD.weg
  OR NEW.angebot_version_id IS NOT OLD.angebot_version_id OR NEW.reservierung_id IS NOT OLD.reservierung_id
  OR NEW.bedingungen_status<>OLD.bedingungen_status;
 SELECT RAISE(ABORT,'RUECKGABE_UNVERAENDERLICH') WHERE OLD.rueckgabe IS NOT NULL AND NEW.rueckgabe IS NOT OLD.rueckgabe;
 SELECT RAISE(ABORT,'AUSLEIHE_UEBERLAPPT') WHERE EXISTS(
  SELECT 1 FROM ausleihe a WHERE a.exemplar_id=NEW.exemplar_id AND a.ausleihe_id<>OLD.ausleihe_id
   AND (NEW.rueckgabe IS NULL OR a.beginn<NEW.rueckgabe)
   AND (a.rueckgabe IS NULL OR NEW.beginn<a.rueckgabe));
END;

CREATE TRIGGER ausleihe_delete BEFORE DELETE ON ausleihe
BEGIN SELECT RAISE(ABORT,'AUSLEIHE_HISTORIE'); END;

-- Genutzte Abholfenster dürfen nicht geändert oder gelöscht werden.
CREATE TRIGGER abholzeit_update BEFORE UPDATE ON abholzeit
WHEN EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND weg='abholung' AND beginn>=OLD.von AND beginn<OLD.bis)
BEGIN SELECT RAISE(ABORT,'ABHOLZEIT_HISTORIE'); END;

CREATE TRIGGER abholzeit_delete BEFORE DELETE ON abholzeit
WHEN EXISTS(SELECT 1 FROM ausleihe WHERE exemplar_id=OLD.exemplar_id AND weg='abholung' AND beginn>=OLD.von AND beginn<OLD.bis)
BEGIN SELECT RAISE(ABORT,'ABHOLZEIT_HISTORIE'); END;

-- Bewertungen erst nach Rückgabe.
CREATE TRIGGER bewertung_insert BEFORE INSERT ON bewertung
WHEN EXISTS(SELECT 1 FROM ausleihe WHERE ausleihe_id=NEW.ausleihe_id AND rueckgabe IS NULL)
BEGIN SELECT RAISE(ABORT,'BEWERTUNG_VOR_RUECKGABE'); END;

CREATE TRIGGER bewertung_update BEFORE UPDATE ON bewertung
WHEN EXISTS(SELECT 1 FROM ausleihe WHERE ausleihe_id=NEW.ausleihe_id AND rueckgabe IS NULL)
BEGIN SELECT RAISE(ABORT,'BEWERTUNG_VOR_RUECKGABE'); END;

-- Fünf Sichten für Gültigkeit, aktuelle Angebote, Verfügbarkeit und Bewertungen.
-- Das letzte Versionsintervall hat kein Ende (NULL).
CREATE VIEW v_angebot_intervalle AS
SELECT v.*,lead(gueltig_von) OVER(PARTITION BY exemplar_id ORDER BY versionsnummer) AS gueltig_bis
FROM angebot_version v;

CREATE VIEW v_aktuelle_angebote AS
SELECT e.exemplar_id,e.buch_id,e.eigentuemer_id,e.zustand,v.angebot_version_id,
 v.versionsnummer,v.gueltig_von,v.max_tage,v.versand,v.abholadresse_id,v.angeboten
FROM exemplar e JOIN angebot_version v ON v.angebot_version_id=e.aktuelle_version_id;

-- Laufende Leihen und Bestätigungen sperren; der Fälligkeitstermin gibt nichts frei.
CREATE VIEW v_verfuegbare_buecher AS
SELECT e.exemplar_id,b.buch_id,b.titel,e.eigentuemer_id,e.abholadresse_id,
 e.zustand,e.max_tage,e.versand,a.ort,a.latitude,a.longitude,e.angebot_version_id
FROM v_aktuelle_angebote e JOIN buch b ON b.buch_id=e.buch_id
JOIN adresse a ON a.adresse_id=e.abholadresse_id
WHERE e.angeboten=1 AND NOT EXISTS(
 SELECT 1 FROM ausleihe l WHERE l.exemplar_id=e.exemplar_id AND l.rueckgabe IS NULL)
 AND NOT EXISTS(SELECT 1 FROM reservierung r WHERE r.exemplar_id=e.exemplar_id AND r.status='bestaetigt');

-- Historische Verträge nutzen ihre Version; unbekannte Altbedingungen bleiben NULL.
CREATE VIEW v_ausleihbedingungen AS
SELECT l.ausleihe_id,l.exemplar_id,l.entleiher_id,l.beginn,l.faellig,l.rueckgabe,l.weg,
 l.bedingungen_status,l.angebot_version_id,v.versionsnummer,v.max_tage,v.versand,
 v.abholadresse_id,a.strasse,a.hausnummer,a.plz,a.ort,a.land,a.latitude,a.longitude
FROM ausleihe l LEFT JOIN angebot_version v ON v.angebot_version_id=l.angebot_version_id
LEFT JOIN adresse a ON a.adresse_id=v.abholadresse_id;

CREATE VIEW v_buchbewertungen AS
SELECT b.buch_id,b.titel,count(w.bewertung_id) AS anzahl,avg(w.sterne) AS durchschnitt
FROM buch b LEFT JOIN exemplar e ON e.buch_id=b.buch_id
LEFT JOIN ausleihe l ON l.exemplar_id=e.exemplar_id
LEFT JOIN bewertung w ON w.ausleihe_id=l.ausleihe_id GROUP BY b.buch_id,b.titel;
