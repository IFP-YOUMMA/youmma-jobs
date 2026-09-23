-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — statut de paiement "rembourse" + horodatage de préparation
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ Déjà exécuté manuellement dans Supabase le 23/09/2026 — présent ici à
-- titre de documentation uniquement. NE PAS RELANCER.
--
-- CONTEXTE : l'annulation d'une commande déjà payée peut désormais donner
-- lieu à un remboursement au client ; la commande doit alors pouvoir porter
-- un statut de paiement dédié plutôt que de rester marquée "paye" à tort.
-- Par ailleurs, l'étape "Préparée" de la frise de suivi n'avait jusqu'ici
-- aucun horodatage propre (contrairement à Reçue/Assignée/En livraison/
-- Livrée) ; date_preparation comble ce manque pour les commandes créées à
-- partir de cette migration (les commandes existantes restent à NULL).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table gn_commandes drop constraint if exists gn_commandes_paiement_statut_check;
alter table gn_commandes add constraint gn_commandes_paiement_statut_check
  check (paiement_statut in ('du','paye','rembourse'));

alter table gn_commandes add column if not exists date_preparation timestamptz;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Contrainte CHECK de gn_commandes.paiement_statut élargie de ('du','paye')
--    à ('du','paye','rembourse') — DROP puis ADD du même nom de contrainte
--    (nom par défaut généré par Postgres pour un CHECK inline sur cette
--    colonne), idempotent via IF EXISTS.
-- B. Nouvelle colonne gn_commandes.date_preparation (timestamptz, nullable,
--    pas de défaut) — ADD COLUMN IF NOT EXISTS, idempotent. Les commandes
--    existantes conservent NULL ; renseignée uniquement pour les commandes
--    marquées "préparée" après l'application de cette migration.
-- C. Aucune donnée modifiée, aucune autre table/colonne/contrainte touchée.
-- ═══════════════════════════════════════════════════════════════════════════
