-- ═══════════════════════════════════════════════════════════════════════════
-- RAPPORTS JOURNALIERS + NOTIFICATIONS CLIENT
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : ces 4 tables sont NOUVELLES — vérifié qu'aucune ne porte le
-- même nom qu'une table déjà existante dans ce projet (notamment
-- rapport_final_chantier / rapport_final_lignes, tables différentes créées
-- par 20260714_registre_chantier.sql pour un tout autre usage — bilan
-- consolidé matériaux/financier en fin de chantier, avec workflow de
-- validation à 4 étapes — sans lien avec le suivi photo au jour le jour
-- implémenté ici).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

CREATE TABLE IF NOT EXISTS rapports_journaliers (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chantier_id    UUID REFERENCES chantiers(id),
  superviseur_id UUID REFERENCES superviseurs(id),
  date_rapport   DATE DEFAULT CURRENT_DATE,
  commentaire    TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rapport_journalier_photos (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rapport_id UUID REFERENCES rapports_journaliers(id),
  photo_url  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rapport_journalier_commentaires (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rapport_id UUID REFERENCES rapports_journaliers(id),
  auteur     TEXT,
  auteur_id  UUID,
  message    TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications_client (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id  UUID REFERENCES clients(id),
  type       TEXT,
  titre      TEXT,
  message    TEXT,
  rapport_id UUID REFERENCES rapports_journaliers(id),
  lu         BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index sur les colonnes utilisées dans les WHERE/JOIN du code JS (non
-- demandés explicitement, mais indispensables pour éviter des scans complets
-- à chaque chargement de dashboard — même pratique que toutes les
-- migrations précédentes de ce projet).
CREATE INDEX IF NOT EXISTS idx_rapports_journaliers_chantier_id ON rapports_journaliers(chantier_id);
CREATE INDEX IF NOT EXISTS idx_rapports_journaliers_superviseur_id ON rapports_journaliers(superviseur_id);
CREATE INDEX IF NOT EXISTS idx_rapport_journalier_photos_rapport_id ON rapport_journalier_photos(rapport_id);
CREATE INDEX IF NOT EXISTS idx_rapport_journalier_commentaires_rapport_id ON rapport_journalier_commentaires(rapport_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_client_id ON notifications_client(client_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_rapport_id ON notifications_client(rapport_id);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 4 tables créées exactement telles que spécifiées (mêmes noms, mêmes
--    colonnes, mêmes types) — aucune n'existait déjà sous ce nom.
-- B. RLS non activée, cohérent avec le reste du registre chantier (voir
--    section 3 de 20260716_fournisseur_profil_catalogue.sql pour le
--    raisonnement complet : ce site n'utilise pas Supabase Auth, la
--    sécurité réelle est côté application).
-- C. 6 index ajoutés sur les colonnes FK réellement filtrées/jointes par le
--    code JS (chantier_id, superviseur_id, rapport_id, client_id) — seul
--    ajout non explicitement listé dans la demande, purement défensif.
-- D. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
