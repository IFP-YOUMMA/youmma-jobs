-- ═══════════════════════════════════════════════════════════════════════════
-- ADMIN — GESTION DES COMPTES (création directe + suivi centralisé)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE / ÉCARTS PAR RAPPORT À LA DEMANDE INITIALE :
--   - La demande visait une table `fournisseurs` : elle n'existe pas. Le
--     Registre Chantier utilise `fournisseurs_materiaux` (colonne nom =
--     nom_entreprise, pas nom) — voir 20260714_registre_chantier.sql. Cette
--     migration cible donc fournisseurs_materiaux, pas fournisseurs.
--   - clients.statut / fournisseurs_materiaux.statut / superviseurs.statut
--     existent déjà (CHECK 'actif'/'suspendu'/'en_attente' pour les deux
--     premières, 'actif'/'inactif'/'en_attente' — PAS 'suspendu' — pour
--     superviseurs ; voir 20260716_espace_statut_en_attente.sql). Aucune
--     colonne ni contrainte statut n'est donc re-déclarée ici, pour éviter
--     toute divergence avec le vocabulaire déjà en place.
--   - clients.mot_de_passe / created_by_admin / doit_changer_mdp existent
--     déjà (20260719_clients_mdp_admin.sql). Seule derniere_connexion est
--     réellement nouvelle pour clients.
--   - superviseurs et fournisseurs_materiaux n'ont aucune colonne mot de
--     passe à ce jour (authentification OTP SMS uniquement jusqu'ici, voir
--     20260714_registre_chantier.sql) : mot_de_passe/created_by_admin/
--     doit_changer_mdp/derniere_connexion sont entièrement nouvelles pour
--     ces deux tables. Le mode de connexion par mot de passe pour
--     fournisseurs/superviseurs n'existe pas encore côté JS — cette
--     migration prépare seulement le schéma, la connexion par mot de passe
--     pour ces deux rôles reste à implémenter séparément si besoin (hors
--     périmètre de "créer un compte depuis l'admin").
--   - superviseurs.provider_id (lien optionnel vers un compte prestataire)
--     existe déjà et n'est pas touché.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

-- clients : seule derniere_connexion est nouvelle (mot_de_passe/
-- created_by_admin/doit_changer_mdp déjà ajoutées par
-- 20260719_clients_mdp_admin.sql — IF NOT EXISTS les laisse intactes).
ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS mot_de_passe TEXT,
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS doit_changer_mdp BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS derniere_connexion TIMESTAMPTZ;

-- superviseurs : les 4 colonnes sont nouvelles.
ALTER TABLE superviseurs
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS mot_de_passe TEXT,
  ADD COLUMN IF NOT EXISTS doit_changer_mdp BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS derniere_connexion TIMESTAMPTZ;

-- fournisseurs_materiaux (PAS "fournisseurs", table inexistante) : les 4
-- colonnes sont nouvelles.
ALTER TABLE fournisseurs_materiaux
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS mot_de_passe TEXT,
  ADD COLUMN IF NOT EXISTS doit_changer_mdp BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS derniere_connexion TIMESTAMPTZ;

-- Historique des alertes envoyées par l'admin à un compte, tous types
-- confondus (compte_type/compte_id en polymorphe applicatif, pas de FK —
-- même limite que ailleurs dans ce fichier, 3 tables cibles possibles).
CREATE TABLE IF NOT EXISTS alertes_comptes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  compte_type TEXT NOT NULL CHECK (compte_type IN ('client','fournisseur','superviseur')),
  compte_id UUID NOT NULL,
  message TEXT NOT NULL,
  envoye_par UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alertes_comptes_compte ON alertes_comptes(compte_type, compte_id);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. clients : +1 colonne réellement nouvelle (derniere_connexion) ; les 3
--    autres existaient déjà, IF NOT EXISTS ne change rien pour elles.
-- B. superviseurs et fournisseurs_materiaux : +4 colonnes chacune
--    (created_by_admin, mot_de_passe, doit_changer_mdp, derniere_connexion),
--    toutes nouvelles. Aucune régression : DEFAULT FALSE partout, tout
--    compte existant garde un comportement inchangé (mot_de_passe reste
--    NULL tant que l'admin n'en fixe pas un explicitement côté JS — même
--    principe de sécurité que 20260719_clients_mdp_admin.sql : jamais de
--    DEFAULT '0000' au niveau colonne).
-- C. 1 nouvelle table alertes_comptes + 1 index composite.
-- D. Aucune colonne/contrainte statut touchée sur les 3 tables (déjà
--    posées par les migrations précédentes, vocabulaires différents entre
--    superviseurs et les deux autres — voir contexte ci-dessus).
-- E. Aucune autre colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
