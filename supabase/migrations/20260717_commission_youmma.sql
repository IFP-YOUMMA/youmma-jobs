-- ═══════════════════════════════════════════════════════════════════════════
-- COMMISSION YOUMMA — colonnes sur chantiers
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : le calcul de la commission (15% du total versé sur un
-- chantier, seuil 50 000 000 GNF) se fait toujours côté JS en sommant les
-- registre_transactions en temps réel — ces 3 colonnes ne stockent que le
-- taux (modifiable par chantier, 15% par défaut) et l'état de paiement
-- (jamais le montant lui-même, qui reste toujours recalculé).
-- Tant que cette migration n'est pas exécutée, tout le code JS qui la
-- consomme (#espace client/superviseur, panel admin onglet Clients) retombe
-- silencieusement sur taux=15%/non payée sans jamais planter.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE chantiers
  ADD COLUMN IF NOT EXISTS commission_taux NUMERIC DEFAULT 15,
  ADD COLUMN IF NOT EXISTS commission_payee BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS commission_payee_le TIMESTAMPTZ;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 3 colonnes ajoutées à chantiers via ADD COLUMN IF NOT EXISTS
--    (idempotent, sans danger si déjà présentes) :
--    - commission_taux NUMERIC DEFAULT 15 (pourcentage, modifiable par
--      chantier si besoin plus tard — aucune UI d'édition ajoutée pour
--      l'instant, non demandée) ;
--    - commission_payee BOOLEAN DEFAULT FALSE ;
--    - commission_payee_le TIMESTAMPTZ (horodatage du paiement, rempli par
--      le code JS via NOW() applicatif au moment du clic admin).
-- B. Aucune colonne "montant commission" stockée : recalculé à chaque
--    affichage à partir des registre_transactions (versement_valide),
--    exactement comme demandé ("le calcul se fait toujours côté JS").
-- C. Aucune autre colonne, table, contrainte ou trigger touché.
-- ═══════════════════════════════════════════════════════════════════════════
