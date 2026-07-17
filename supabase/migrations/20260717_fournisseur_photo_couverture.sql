-- ═══════════════════════════════════════════════════════════════════════════
-- FOURNISSEURS — photo de couverture du profil public
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE de 20260716_fournisseur_profil_catalogue.sql (non
-- modifiée rétroactivement) — à exécuter manuellement dans l'éditeur SQL
-- Supabase. Je ne l'exécute pas moi-même.
--
-- CONTEXTE : 20260716_fournisseur_profil_catalogue.sql a déjà ajouté
-- description/photo_url/profil_public à fournisseurs_materiaux. Cette
-- migration ajoute une colonne distincte pour la photo de couverture
-- (bandeau large, ratio ~3:1) affichée en haut du profil #espace et en
-- fond des cartes fournisseurs sur #construire — indépendante de
-- photo_url, qui reste la photo de profil (avatar rond).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE fournisseurs_materiaux
  ADD COLUMN IF NOT EXISTS photo_couverture_url TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Une seule colonne ajoutée, via ADD COLUMN IF NOT EXISTS (idempotent,
--    sans danger si déjà présente) : photo_couverture_url, nullable, sans
--    valeur par défaut — un fournisseur existant n'a pas de couverture tant
--    qu'il n'en uploade pas une (fallback dégradé visuel géré côté JS/CSS,
--    pas en base).
-- B. Aucune autre colonne, table, contrainte ou trigger touché — le reste
--    du schéma (20260714_registre_chantier.sql,
--    20260716_registre_chantier_multi_fournisseur.sql,
--    20260716_espace_statut_en_attente.sql,
--    20260716_fournisseur_profil_catalogue.sql) est inchangé.
-- C. RLS : non concerné (fournisseurs_materiaux reste en RLS désactivée,
--    cohérent avec le reste du registre chantier — voir section 3 de
--    20260716_fournisseur_profil_catalogue.sql pour le raisonnement complet).
-- D. Le code JS (#espace onglet "Mon profil" + cartes fournisseurs
--    #construire) est mis à jour séparément dans index.html, pas dans ce
--    fichier SQL.
-- ═══════════════════════════════════════════════════════════════════════════
