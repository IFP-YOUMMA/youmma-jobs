-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — correctif RLS : "new row violates row-level security policy
-- for table gn_fournisseur_paiements"
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- DIAGNOSTIC (vérifié par des requêtes réelles contre la base de production,
-- pas une supposition) :
-- Chaque migration gn_* de ce dépôt désactive explicitement la RLS à la
-- création de sa table ("disable row level security"), car ce projet n'a
-- jamais utilisé de policies pour l'app interne gérant/agent/livreur — la clé
-- anon a un accès complet, le contrôle d'accès est fait côté application
-- (session, rôles), pas côté base. C'est documenté en toutes lettres dans
-- 20260923_youmma_gn_fournisseur_retraits.sql.
--
-- J'ai testé une insertion réelle (anon key) sur chacune des 9 tables gn_* :
--   OK  (RLS désactivée, comme prévu) : gn_agents, gn_produits, gn_commandes,
--       gn_caisse, gn_parametres, gn_fournisseurs
--   CASSÉ (42501 "new row violates row-level security policy") :
--       gn_fournisseur_paiements, gn_fournisseur_depots,
--       gn_fournisseur_retraits
-- (test nettoyé immédiatement après coup — aucune ligne de test laissée en
-- base ; pour gn_fournisseur_retraits, un solde fictif a été créé via une
-- commande temporaire pour dépasser son trigger de garde-fou puis vérifier
-- la RLS séparément, la commande a été supprimée aussitôt après.)
--
-- Ces 3 tables sont exactement celles créées ou modifiées le plus récemment
-- (module retraits fournisseur). Aucune trace dans ce dépôt d'une policy
-- ajoutée intentionnellement pour elles — la cause la plus probable est un
-- clic sur "Enable RLS" depuis le Security Advisor du dashboard Supabase
-- (qui active RLS sans policy, bloquant tout accès par défaut), très
-- vraisemblablement déclenché par l'avertissement "RLS Disabled in Public"
-- que ce panneau affiche pour toute table exposée sans RLS — plausible pour
-- des tables "argent" comme celles-ci. Aucun code applicatif n'a changé
-- entre-temps ; il n'y a rien à corriger côté youmma-gn.html.
--
-- CORRECTIF : réaligner ces 3 tables sur le même modèle que les 6 autres
-- (RLS désactivée). Les ALTER TABLE ... DISABLE ROW LEVEL SECURITY ci-dessous
-- sur les 6 tables déjà correctes sont inclus par prudence — idempotents et
-- sans effet si déjà désactivée — pour que cette migration serve aussi de
-- filet si l'une d'elles était basculée par erreur plus tard.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE gn_fournisseur_paiements DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_fournisseur_depots DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_fournisseur_retraits DISABLE ROW LEVEL SECURITY;

-- Filet de sécurité (déjà correctes au moment de l'audit, incluses pour que
-- cette migration reste la référence complète "toutes les tables gn_*") :
ALTER TABLE gn_agents DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_produits DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_commandes DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_parametres DISABLE ROW LEVEL SECURITY;
ALTER TABLE gn_fournisseurs DISABLE ROW LEVEL SECURITY;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- APRÈS EXÉCUTION
-- ═══════════════════════════════════════════════════════════════════════════
-- Le Security Advisor du dashboard Supabase va très probablement re-signaler
-- ces 9 tables comme "RLS Disabled in Public" — c'est attendu et sans danger
-- dans le modèle de confiance actuel de cette app (documenté dans les
-- migrations précédentes) : IGNORER cet avertissement, ou le mettre en
-- sourdine pour ce projet, plutôt que de recliquer "Enable RLS" dessus, sous
-- peine de reproduire exactement ce blocage.
-- ═══════════════════════════════════════════════════════════════════════════
