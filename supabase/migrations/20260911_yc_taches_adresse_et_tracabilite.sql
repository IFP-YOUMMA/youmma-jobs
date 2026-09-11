-- ═══════════════════════════════════════════════════════════════════════════
-- YC_TACHES — adresse client + traçabilité des étapes (qui fait quoi)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : la modale de tâche (youmma-center.html) gagne un champ "Adresse
-- du client" reporté automatiquement sur la facture générée depuis la tâche
-- (factureAcompteTache / factureFinaleTache). Par ailleurs, chaque carte
-- tâche affiche désormais une ligne d'historique ("Créée par … · Acompte
-- facturé par … · Démarrée par …") : ces nouvelles colonnes stockent l'agent
-- et l'horodatage de chaque étape. La création (agent_nom, déjà existant) et
-- la validation (comptable_nom / date_validation, déjà existants) réutilisent
-- les colonnes en place — seules les étapes "acompte facturé", "démarrée" et
-- "terminée" nécessitent de nouvelles colonnes.
--
-- Tant que cette migration n'est pas appliquée :
--   - client_adresse : creerTache() envoie déjà cette clé dans son payload
--     d'INSERT/UPDATE ; sans la colonne, la création/modification d'une
--     tâche échoue avec une erreur Postgrest explicite (toast rouge).
--   - demarre_par/demarre_le, termine_par/termine_le : changerStatutTache()
--     les inclut dans son UPDATE dès que le nouveau statut est 'en_cours' ou
--     'termine' ; sans les colonnes, ces transitions de statut échoueront
--     avec une erreur explicite (toast rouge), sans corrompre la tâche.
--   - acompte_facture_par/acompte_facture_le : saveDocument() les écrit sur
--     la tâche uniquement après avoir enregistré avec succès une facture
--     d'acompte (nature='acompte') liée à cette tâche ; sans les colonnes,
--     cette mise à jour finale échoue silencieusement en arrière-plan (elle
--     n'est pas dans le chemin critique de la sauvegarde du document, qui a
--     déjà réussi à ce stade) — la facture est bien créée, seule la ligne
--     d'historique de la carte n'affichera pas "Acompte facturé par …"
--     jusqu'à l'exécution de cette migration.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE yc_taches
  ADD COLUMN IF NOT EXISTS client_adresse TEXT,
  ADD COLUMN IF NOT EXISTS acompte_facture_par TEXT,
  ADD COLUMN IF NOT EXISTS acompte_facture_le TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS demarre_par TEXT,
  ADD COLUMN IF NOT EXISTS demarre_le TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS termine_par TEXT,
  ADD COLUMN IF NOT EXISTS termine_le TIMESTAMPTZ;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Sept colonnes ajoutées, toutes nullable, via ADD COLUMN IF NOT EXISTS
--    (idempotent) : client_adresse (TEXT), acompte_facture_par (TEXT),
--    acompte_facture_le (TIMESTAMPTZ), demarre_par (TEXT), demarre_le
--    (TIMESTAMPTZ), termine_par (TEXT), termine_le (TIMESTAMPTZ).
-- B. Aucune valeur par défaut, aucun backfill : toutes les tâches existantes
--    gardent ces champs à NULL — la ligne d'historique de leur carte
--    n'affichera alors que les étapes pour lesquelles une donnée existe déjà
--    (typiquement "Créée par …" via agent_nom, et "Validée par …" via
--    comptable_nom si la tâche est déjà validée), conformément au
--    comportement front qui n'affiche une étape que si son champ est
--    renseigné.
-- C. "Créée par" et "Validée par" réutilisent les colonnes existantes
--    agent_nom et comptable_nom/date_validation — aucune duplication.
-- D. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
