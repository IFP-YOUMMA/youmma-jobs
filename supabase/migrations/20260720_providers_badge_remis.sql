-- ═══════════════════════════════════════════════════════════════════════════
-- PROVIDERS — badge_remis (déblocage du téléchargement du badge PDF)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : jusqu'ici, le bouton "Télécharger mon badge PDF" du dashboard
-- prestataire s'affichait dès que statut='valide' ET matricule renseigné.
-- Nouvelle règle métier : le badge ne doit être téléchargeable qu'une fois
-- que l'admin a physiquement remis le badge au prestataire (après validation
-- + réception des 50 000 GNF + formation faite — ces 3 conditions sont
-- vérifiées hors-ligne par l'admin, badge_remis est la seule coché par lui
-- dans le panel une fois qu'elles sont toutes réunies). Colonne DEFAULT
-- FALSE : aucun prestataire existant ne débloque son badge rétroactivement.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE providers
  ADD COLUMN IF NOT EXISTS badge_remis BOOLEAN DEFAULT FALSE;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée à providers via ADD COLUMN IF NOT EXISTS (idempotent,
--    sans danger si déjà présente) : badge_remis BOOLEAN DEFAULT FALSE. Tous
--    les prestataires existants (validés ou non) reçoivent FALSE : personne
--    ne débloque son badge automatiquement suite à cette migration.
-- B. Mise à TRUE uniquement par _adminToggleBadgeRemis() (panel admin, modal
--    "Voir le profil"), jamais par le code prestataire lui-même.
-- C. Tant que cette migration n'est pas exécutée, le SELECT optionnel
--    (COLS_OPT dans getDashboardData()) échoue silencieusement et retombe
--    sur COLS_BASE — badge_remis reste alors undefined, le bouton badge PDF
--    reste caché par défaut (comportement sûr, pas de régression côté accès
--    prématuré au badge).
-- D. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
