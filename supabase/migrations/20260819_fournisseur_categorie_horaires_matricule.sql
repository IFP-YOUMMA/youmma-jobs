-- ═══════════════════════════════════════════════════════════════════════════
-- FOURNISSEURS_MATERIAUX — categorie, horaires, zone_livraison, matricule
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : le profil public fournisseur (annuaire, catalogue plein écran,
-- profil dashboard, admin) affiche désormais une catégorie d'activité, des
-- horaires d'ouverture, une zone de livraison et un matricule YOUMMA
-- (format souhaité YMF-000001). Aucune des 4 colonnes n'existe à ce jour —
-- vérifié en relisant toutes les migrations touchant fournisseurs_materiaux
-- (20260714_registre_chantier.sql, 20260716_fournisseur_profil_catalogue.sql,
-- 20260717_fournisseur_photo_couverture.sql, 20260803_admin_gestion_comptes.sql,
-- 20260815_fournisseur_type_compte_note.sql).
--
-- matricule reste volontairement NULL pour tous les fournisseurs existants —
-- aucune génération automatique (format YMF-XXXXXX) n'est demandée dans cette
-- migration : le code JS n'affiche le matricule que s'il est renseigné,
-- jamais de valeur inventée. Une éventuelle génération/attribution en masse
-- est hors périmètre, à traiter séparément si besoin.
--
-- Tant que cette migration n'est pas appliquée, le code JS continue de
-- fonctionner : ces 4 champs seront simplement absents/undefined pour tous
-- les fournisseurs, et chaque élément d'UI conditionné dessus (catégorie,
-- matricule, horaires, zone de livraison) reste masqué proprement.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE fournisseurs_materiaux
  ADD COLUMN IF NOT EXISTS categorie TEXT,
  ADD COLUMN IF NOT EXISTS horaires TEXT,
  ADD COLUMN IF NOT EXISTS zone_livraison TEXT,
  ADD COLUMN IF NOT EXISTS matricule TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_fournisseurs_materiaux_matricule
  ON fournisseurs_materiaux(matricule) WHERE matricule IS NOT NULL;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 4 colonnes ajoutées, toutes TEXT nullables, via ADD COLUMN IF NOT EXISTS
--    (idempotent) : categorie, horaires, zone_livraison, matricule.
-- B. Index unique partiel sur matricule (ignore les NULL) pour éviter tout
--    doublon le jour où des matricules seront attribués — n'empêche pas les
--    fournisseurs sans matricule (NULL) de coexister.
-- C. Aucune valeur par défaut, aucun backfill, aucune génération de
--    matricule : tous les fournisseurs existants gardent ces 4 champs à
--    NULL jusqu'à saisie manuelle (formulaire "Modifier mon profil" pour
--    categorie/horaires/zone_livraison) ou attribution future du matricule
--    (mécanisme non couvert ici).
-- D. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
