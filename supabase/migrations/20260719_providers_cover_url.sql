-- ═══════════════════════════════════════════════════════════════════════════
-- PROVIDERS — photo de couverture (cover_url)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : distincte de fournisseurs_materiaux.photo_couverture_url
-- (20260717_fournisseur_photo_couverture.sql, autre table, autre système —
-- fournisseurs de matériaux du Registre Chantier, pas les prestataires du
-- répertoire public). cover_url est nullable : tant qu'un prestataire n'a
-- pas uploadé sa propre couverture, une image par défaut par catégorie/
-- métier est utilisée côté JS (_providerCoverUrl()), jamais stockée en base.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE providers
  ADD COLUMN IF NOT EXISTS cover_url TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée à providers via ADD COLUMN IF NOT EXISTS (idempotent,
--    sans danger si déjà présente) : cover_url, nullable, sans DEFAULT — un
--    prestataire existant n'a pas de couverture personnalisée tant qu'il
--    n'en uploade pas une (fallback visuel par catégorie géré en JS/CSS,
--    jamais écrit en base).
-- B. Tant que cette migration n'est pas exécutée, le SELECT optionnel
--    (COLS_OPT dans getDashboardData()) échoue silencieusement et retombe
--    sur COLS_BASE — cover_url reste alors undefined, _providerCoverUrl()
--    utilise systématiquement l'image par défaut, aucun crash.
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
