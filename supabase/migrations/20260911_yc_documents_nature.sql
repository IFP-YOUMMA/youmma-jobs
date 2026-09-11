-- ═══════════════════════════════════════════════════════════════════════════
-- YC_DOCUMENTS — nature (acompte / finale)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : le redesign de la page Tâches (youmma-center.html) introduit une
-- synergie tâche → factures : factureAcompteTache(tacheId) et
-- factureFinaleTache(tacheId) ouvrent le module document pré-rempli depuis
-- une tâche et enregistrent la facture générée avec tache_id (déjà une
-- colonne existante) et cette nouvelle colonne nature ('acompte' ou
-- 'finale'), pour permettre la logique anti-doublon (une seule facture
-- d'acompte et une seule facture finale par tâche) et l'affichage sur la
-- carte tâche ("Voir facture d'acompte" / badge "Facturée").
--
-- Tant que cette migration n'est pas appliquée, le code JS échoue de façon
-- explicite plutôt que silencieuse : saveDocument() envoie désormais la clé
-- nature (valeur null pour tout document hors flux tâche → facture) dans
-- chaque INSERT sur yc_documents, et la requête anti-doublon de
-- factureAcompteTache/factureFinaleTache filtre aussi sur cette colonne.
-- Sans la migration, toute création de document échoue avec l'erreur
-- Postgrest "column yc_documents.nature does not exist", affichée à l'agent
-- via un toast rouge — aucun document créé par erreur, pas de doublon
-- silencieux, juste un blocage visible jusqu'à l'exécution de l'ALTER
-- ci-dessous.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE yc_documents
  ADD COLUMN IF NOT EXISTS nature TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Une colonne ajoutée, TEXT, nullable, via ADD COLUMN IF NOT EXISTS
--    (idempotent) : nature. Valeurs attendues côté application : 'acompte',
--    'finale', ou NULL (documents créés hors du flux tâche → facture,
--    c'est-à-dire la quasi-totalité des documents existants).
-- B. Aucune valeur par défaut, aucun backfill, aucune contrainte CHECK :
--    tous les documents existants gardent nature = NULL (comportement
--    correct, puisqu'ils n'ont jamais été créés depuis une tâche).
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
