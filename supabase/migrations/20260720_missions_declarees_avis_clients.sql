-- ═══════════════════════════════════════════════════════════════════════════
-- MISSIONS_DECLAREES + AVIS_CLIENTS — déclaration de missions par les
-- prestataires et notation des clients via lien à token unique
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : distinct du système "missions" existant (offres d'emploi que les
-- prestataires consultent/acceptent, panel admin "Gestion des Missions").
-- missions_declarees est un système séparé : le prestataire déclare
-- lui-même avoir effectué un travail pour un client donné (nom+téléphone),
-- l'admin valide et génère un lien de notation à usage unique
-- (avis_clients.token) envoyé au client par WhatsApp/SMS. RLS désactivée,
-- comme le reste du projet — accès via le client anon `sb` uniquement,
-- la page de notation (#noter/{token}) n'a aucune authentification.
--
-- nb_missions / note_moyenne / nb_avis existent déjà sur providers (utilisés
-- depuis longtemps par getProviders()/getDashboardData()) — les
-- ADD COLUMN IF NOT EXISTS ci-dessous sont donc des no-op sans danger,
-- gardés uniquement pour que cette migration reste exécutable seule sur une
-- base qui ne les aurait pas encore.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

CREATE TABLE IF NOT EXISTS missions_declarees (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider_id uuid REFERENCES providers(id),
  client_nom text NOT NULL,
  client_telephone text NOT NULL,
  description text,
  statut text DEFAULT 'en_attente',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS avis_clients (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mission_id uuid REFERENCES missions_declarees(id),
  provider_id uuid REFERENCES providers(id),
  token text UNIQUE DEFAULT gen_random_uuid()::text,
  note integer CHECK (note >= 1 AND note <= 5),
  commentaire text,
  token_used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE missions_declarees DISABLE ROW LEVEL SECURITY;
ALTER TABLE avis_clients DISABLE ROW LEVEL SECURITY;

-- Colonnes stats sur providers (déjà présentes en pratique, voir contexte ci-dessus)
ALTER TABLE providers ADD COLUMN IF NOT EXISTS nb_missions integer DEFAULT 0;
ALTER TABLE providers ADD COLUMN IF NOT EXISTS note_moyenne numeric(3,1) DEFAULT 0;
ALTER TABLE providers ADD COLUMN IF NOT EXISTS nb_avis integer DEFAULT 0;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 2 nouvelles tables : missions_declarees (déclaration prestataire) et
--    avis_clients (une ligne par lien de notation, créée par l'admin au
--    moment de la validation, token unique auto-généré).
-- B. RLS désactivée sur les deux, cohérent avec le reste du projet.
-- C. providers.nb_missions/note_moyenne/nb_avis : ADD COLUMN IF NOT EXISTS
--    no-op si déjà présentes (c'est le cas dans cette base).
-- D. Aucune table ni colonne existante modifiée.
-- ═══════════════════════════════════════════════════════════════════════════
