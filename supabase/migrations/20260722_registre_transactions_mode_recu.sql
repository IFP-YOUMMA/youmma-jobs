-- ═══════════════════════════════════════════════════════════════════════════
-- REGISTRE_TRANSACTIONS — mode_transfert + recu_url (nouveau dashboard client)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : le nouveau dashboard client (#dashboardClientV2) demande, à la
-- déclaration d'un versement, un mode de transfert (Wave, Western Union,
-- Virement, Remise en main propre, Orange Money) et une photo du reçu —
-- deux informations qui n'existaient dans aucune colonne de
-- registre_transactions jusqu'ici (l'ancien formulaire _espaceCliDeclarerVersement()
-- n'écrit que chantier_id, compte_id, type_operation, montant_gnf,
-- description, client_id). Ajout purement additif, aucune colonne existante
-- touchée, aucun impact sur la contrainte chk_registre_acteur_coherent
-- (qui porte sur les colonnes *_id d'acteur, pas sur ces deux champs
-- descriptifs).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE registre_transactions
  ADD COLUMN IF NOT EXISTS mode_transfert TEXT,
  ADD COLUMN IF NOT EXISTS recu_url TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 2 colonnes ajoutées à registre_transactions via ADD COLUMN IF NOT EXISTS
--    (idempotent, sans danger si déjà présentes) : mode_transfert TEXT,
--    recu_url TEXT — toutes deux nullable, sans DEFAULT.
-- B. Toutes les lignes existantes (versements, sorties, etc. déjà en base)
--    gardent ces deux colonnes à NULL — aucune régression sur l'affichage
--    ou les requêtes existantes (_espaceCliChargerRegistreChantier(),
--    _espaceChargerClient(), etc. ne sélectionnent que les colonnes dont
--    elles ont besoin ou `*`, ce qui inclut simplement NULL pour l'existant).
-- C. Aucune colonne, table, contrainte (y compris chk_registre_acteur_coherent)
--    ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
