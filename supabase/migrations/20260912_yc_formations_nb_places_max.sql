-- ═══════════════════════════════════════════════════════════════════════════
-- YC_FORMATIONS — nb_places_max (catalogue général IFP YOUMMA)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : le formulaire "Nouvelle formation" (youmma-center.html) gagne
-- un champ optionnel "Places disponibles" (laisser vide = illimité), utilisé
-- par le nouveau document imprimable "Catalogue général des formations"
-- (colonne "Places" du tableau).
--
-- Tant que cette migration n'est pas appliquée : la création d'une nouvelle
-- formation échouera avec une erreur Postgrest explicite (colonne inconnue),
-- affichée en toast rouge — aucune formation créée par erreur. Les
-- formations déjà existantes continuent de fonctionner normalement ; le
-- catalogue affichera "Illimité" pour toutes tant que ce champ n'existe pas
-- (valeur NULL par défaut, comportement déjà géré côté front).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table yc_formations add column if not exists nb_places_max int;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Une colonne ajoutée, INT, nullable, via ADD COLUMN IF NOT EXISTS
--    (idempotent) : nb_places_max.
-- B. Aucune valeur par défaut, aucun backfill : les formations existantes
--    gardent ce champ à NULL, affiché comme "Illimité" dans le catalogue
--    (comportement front déjà en place, pas de régression).
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
