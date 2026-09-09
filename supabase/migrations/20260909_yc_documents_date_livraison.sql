-- ═══════════════════════════════════════════════════════════════════════════
-- YC_DOCUMENTS — date_livraison
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : la modale "Nouveau document" (devis/facture) de youmma-center.html
-- affiche désormais un champ "Livraison prévue" (input date). Cette valeur doit
-- être persistée sur le document lui-même (pas seulement reportée sur la tâche
-- liée créée en option), pour pouvoir la relire à l'ouverture, la préremplir
-- lors d'une conversion devis → facture, et l'afficher dans l'aperçu imprimable.
--
-- Tant que cette migration n'est pas appliquée, le code JS continue de
-- fonctionner : l'insert dans yc_documents renverra simplement une erreur
-- Supabase (colonne inconnue) tant que la colonne n'existe pas — la sauvegarde
-- d'un document échouera avec un toast rouge explicite jusqu'à l'exécution
-- de cette migration.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE yc_documents
  ADD COLUMN IF NOT EXISTS date_livraison DATE;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Une colonne ajoutée, DATE, nullable, via ADD COLUMN IF NOT EXISTS
--    (idempotent) : date_livraison.
-- B. Aucune valeur par défaut, aucun backfill : tous les documents existants
--    gardent ce champ à NULL (vide pour les devis créés avant cette date,
--    conforme au comportement front qui n'affiche "Livraison : …" que si la
--    colonne est renseignée).
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
