-- ═══════════════════════════════════════════════════════════════════════════
-- CATALOGUE_PRODUITS — ajout colonne photo_url
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : les cartes fournisseurs de l'annuaire affichent désormais une
-- photo (ou un placeholder 🏗️) par produit du catalogue. Colonne vérifiée
-- comme absente en relisant 20260716_fournisseur_profil_catalogue.sql et
-- 20260803_catalogue_produits.sql (seules nom_produit/unite/prix_gnf/
-- disponible/ordre/description existent sur catalogue_produits à ce jour).
--
-- Tant que cette migration n'est pas appliquée, le code JS continue de
-- fonctionner : p.photo_url sera simplement undefined pour tous les
-- produits, et l'annuaire affiche le placeholder 🏗️ à la place — même
-- principe de repli que les autres colonnes optionnelles de ce fichier.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE catalogue_produits
  ADD COLUMN IF NOT EXISTS photo_url TEXT DEFAULT NULL;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée (photo_url TEXT, nullable, DEFAULT NULL) via ADD
--    COLUMN IF NOT EXISTS — idempotent, sans danger si déjà présente.
-- B. Aucune régression : tous les produits existants gardent
--    photo_url = NULL, ce que le JS traite déjà comme "pas de photo" →
--    placeholder 🏗️ affiché, jamais une image cassée.
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- D. Upload : bucket 'Photos' déjà existant (utilisé pour tout le site),
--    chemin catalogue/{fournisseurId}/{timestamp}.{ext} — aucun nouveau
--    bucket créé.
-- ═══════════════════════════════════════════════════════════════════════════
