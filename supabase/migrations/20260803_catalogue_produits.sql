-- ═══════════════════════════════════════════════════════════════════════════
-- CATALOGUE_PRODUITS — ajout colonne description
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- ÉCART PAR RAPPORT À LA DEMANDE INITIALE : la demande fournissait un
-- CREATE TABLE catalogue_produits complet (nom, unite, prix_unitaire,
-- statut 'en_stock'/'rupture', description). Cette table EXISTE DÉJÀ
-- (créée par 20260716_fournisseur_profil_catalogue.sql) avec un schéma
-- réel différent, déjà exploité par du code fonctionnel (onglet "Mon
-- catalogue" du dashboard fournisseur v2 + affichage sur le profil public
-- fournisseur) :
--   id, fournisseur_id, nom_produit, unite, prix_gnf, disponible (BOOLEAN),
--   ordre, created_at.
-- Créer une 2e table ou re-déclarer celle-ci avec des noms de colonnes
-- différents (nom/prix_unitaire/statut) aurait dupliqué un système déjà en
-- place et cassé le code existant qui lit nom_produit/prix_gnf/disponible.
-- Seule "description" manquait réellement : c'est la SEULE colonne ajoutée
-- ici. Le concept "statut en_stock/rupture" est couvert par la colonne
-- disponible (BOOLEAN) déjà existante — pas de colonne statut séparée.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE catalogue_produits
  ADD COLUMN IF NOT EXISTS description TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 seule colonne ajoutée (description TEXT, nullable, sans DEFAULT) sur
--    la table catalogue_produits déjà existante.
-- B. Aucune table créée, aucune colonne renommée, aucun schéma dupliqué.
-- C. Aucune régression : toutes les lignes existantes gardent
--    description = NULL, le code existant (dfoLoadCatalogue,
--    _espaceFournisseurChargerCatalogue, affichage profil public) continue
--    de fonctionner à l'identique sans modification.
-- ═══════════════════════════════════════════════════════════════════════════
