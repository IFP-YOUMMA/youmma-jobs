-- ═══════════════════════════════════════════════════════════════════════════
-- REGISTRE_TRANSACTIONS — photo_sortie_url (nouveau dashboard fournisseur)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : le nouveau dashboard fournisseur (#dashboardFournisseurV2)
-- exige une photo à la confirmation d'une demande de sortie de matériaux.
-- Cette colonne n'existait pas — le flux réel existant (_espaceTraiterSortie(),
-- append-only : INSERT d'une ligne type_operation='sortie_confirmee' avec
-- reference_transaction_id vers la demande d'origine) n'écrit aujourd'hui
-- que chantier_id/compte_id/type_operation/montant_gnf/materiau/quantite/
-- unite/reference_transaction_id/fournisseur_id/description. Ajout purement
-- additif sur la ligne de CONFIRMATION (pas sur la demande d'origine), sans
-- toucher au trigger fn_gerer_solde_registre (BEFORE INSERT) qui gère le
-- solde — cette colonne est purement descriptive, hors de son périmètre.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE registre_transactions
  ADD COLUMN IF NOT EXISTS photo_sortie_url TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée à registre_transactions via ADD COLUMN IF NOT EXISTS
--    (idempotent, sans danger si déjà présente) : photo_sortie_url TEXT,
--    nullable, sans DEFAULT.
-- B. Toutes les lignes existantes gardent cette colonne à NULL — aucune
--    régression sur l'affichage ou les requêtes existantes.
-- C. Aucune colonne, table, contrainte ou trigger existant modifié — en
--    particulier fn_gerer_solde_registre continue de fonctionner à
--    l'identique, cette colonne n'entre dans aucun de ses calculs.
-- ═══════════════════════════════════════════════════════════════════════════
