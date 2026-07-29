-- ═══════════════════════════════════════════════════════════════════════════
-- ADMIN CONSTRUCTION V2 — colonnes de contrôle granulaire + visites terrain
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : le nouveau dashboard admin "Construire" v2 réutilise autant que
-- possible l'infrastructure déjà en place (voir #admin-registre_chantier,
-- fonctions _rc*) plutôt que de la dupliquer. En particulier :
--   - Le blocage TOTAL d'un superviseur existe déjà via superviseurs.statut
--     ('actif'/'suspendu') — vérifié bloquant à la connexion OTP (index.html,
--     ~ligne 5701). Aucune nouvelle colonne acces_bloque* n'est ajoutée ici,
--     ce serait redondant.
--   - La traçabilité des actions admin existe déjà via la table admin_actions
--     (_logAdminAction()), utilisée sitewide. Aucune table
--     admin_actions_construction séparée n'est créée ici, on réutilise
--     admin_actions.
--   - chantiers.statut (en_etude/en_cours/termine/suspendu) et
--     commission_taux/commission_payee existent déjà (migrations
--     20260714_registre_chantier.sql, 20260717_chantier_statut_suspendu.sql,
--     20260717_commission_youmma.sql). Aucune colonne statut_admin/
--     avancement_pct/type_projet/localisation/niveau_service/
--     commission_fournisseur_payee n'est ajoutée : elles n'ont pas
--     d'équivalent réel utilisable et ne sont utilisées par aucun code.
--
-- Ce qui est réellement nouveau et absent du schéma actuel :
--   1. Contrôle GRANULAIRE par fonctionnalité (sorties/rapports/registre/
--      contact) sur un superviseur — le blocage actuel est tout-ou-rien.
--   2. Score/note libre attribué par l'admin à un superviseur.
--   3. Table visites_terrain (visites planifiées/effectuées par un agent
--      YOUMMA sur un chantier) — concept entièrement absent jusqu'ici.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- Contrôle d'accès granulaire + notation superviseur.
-- Toutes DEFAULT TRUE / 5.0 : aucun changement de comportement pour les
-- superviseurs existants tant que l'admin ne désactive rien explicitement.
ALTER TABLE superviseurs
  ADD COLUMN IF NOT EXISTS acces_sorties BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS acces_rapports BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS acces_registre BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS acces_contact BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS score_admin NUMERIC(3,1) DEFAULT 5.0,
  ADD COLUMN IF NOT EXISTS note_admin TEXT;

-- Visites terrain planifiées/effectuées par un agent YOUMMA sur un chantier.
CREATE TABLE IF NOT EXISTS visites_terrain (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chantier_id UUID REFERENCES chantiers(id),
  agent_nom TEXT,
  date_visite TIMESTAMPTZ,
  type_visite TEXT DEFAULT 'annoncee' CHECK (type_visite IN ('annoncee','surprise')),
  statut TEXT DEFAULT 'planifiee' CHECK (statut IN ('planifiee','effectuee','annulee')),
  rapport TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 6 colonnes ajoutées à superviseurs via ADD COLUMN IF NOT EXISTS
--    (idempotent) : acces_sorties/acces_rapports/acces_registre/
--    acces_contact (BOOLEAN DEFAULT TRUE), score_admin (NUMERIC(3,1)
--    DEFAULT 5.0), note_admin (TEXT). Aucune régression : tout superviseur
--    existant garde un accès complet par défaut.
-- B. 1 nouvelle table visites_terrain, avec CHECK sur type_visite/statut.
-- C. Volontairement PAS ajouté (redondant ou inexistant côté code) :
--    superviseurs.acces_bloque* (→ statut='suspendu' déjà bloquant),
--    admin_actions_construction (→ table admin_actions déjà utilisée),
--    chantiers.statut_admin/avancement_pct/type_projet/localisation/
--    niveau_service/commission_fournisseur_payee.
-- ═══════════════════════════════════════════════════════════════════════════
