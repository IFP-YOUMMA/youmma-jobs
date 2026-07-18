-- ═══════════════════════════════════════════════════════════════════════════
-- ABONNEMENT & CRÉDITS PRESTATAIRES — CHAP CHAP PAY
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : ce système est VOLONTAIREMENT distinct du système d'abonnement
-- existant (providers.abonnement_actif / abonnement_fin / essai_actif,
-- table paiements_log, fonctions creerPaiementAbonnement/lancerPaiementAbonnement/
-- verifierPaiement déjà présentes dans index.html). Celui-ci gérait un
-- abonnement simple lié à l'essai gratuit de 3 jours. Le nouveau système
-- (subscription_end / credits / paiements_youmma) ajoute en parallèle un
-- modèle crédits-à-l'usage (5 000 GNF/action) en plus de l'abonnement
-- illimité — aucune table ni colonne existante n'est renommée, supprimée ou
-- réutilisée pour éviter de casser le système en place. Les deux coexistent :
-- l'ancien reste utilisé par l'écran "Payer mon abonnement" existant, le
-- nouveau alimente uniquement les 4 actions gatées par checkAcces() ajoutées
-- dans ce lot (recevoir mission, devis vocal, badge PDF, téléphone client)
-- et le nouveau bloc "Mon abonnement & crédits" du dashboard prestataire.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE providers
  ADD COLUMN IF NOT EXISTS subscription_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS credits INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_depense_gnf INTEGER DEFAULT 0;

CREATE TABLE IF NOT EXISTS paiements_youmma (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id       UUID REFERENCES providers(id),
  type              TEXT CHECK (type IN ('abonnement','credit')),
  montant_gnf       INTEGER,
  credits_achetes   INTEGER DEFAULT 0,
  duree_jours       INTEGER DEFAULT 0,
  statut            TEXT DEFAULT 'en_attente' CHECK (statut IN ('en_attente','valide','echoue')),
  chapchappay_ref   TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  valide_le         TIMESTAMPTZ
);

-- Index sur les colonnes filtrées/jointes par le code JS (non demandés
-- explicitement, mais indispensables pour éviter des scans complets à
-- chaque chargement du dashboard — même pratique que toutes les migrations
-- précédentes de ce projet).
CREATE INDEX IF NOT EXISTS idx_paiements_youmma_provider_id ON paiements_youmma(provider_id);
CREATE INDEX IF NOT EXISTS idx_paiements_youmma_statut ON paiements_youmma(statut);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 3 colonnes ajoutées à providers via ADD COLUMN IF NOT EXISTS (idempotent,
--    sans danger si déjà présentes) : subscription_end (NULL par défaut —
--    aucun prestataire existant n'a d'accès illimité tant qu'il ne paie pas),
--    credits INTEGER DEFAULT 0, total_depense_gnf INTEGER DEFAULT 0.
-- B. 1 table créée exactement telle que spécifiée (mêmes noms, mêmes
--    colonnes, mêmes types) — n'existait pas déjà sous ce nom. Distincte de
--    la table paiements_log existante (autre schéma, autre usage — liée à
--    l'ancien système abonnement_actif/abonnement_fin).
-- C. 2 index ajoutés sur les colonnes réellement filtrées par le code JS
--    (provider_id pour l'historique des paiements, statut pour le callback
--    de validation) — seul ajout non explicitement listé dans la demande,
--    purement défensif.
-- D. RLS non activée, cohérent avec le reste du projet (pas de Supabase
--    Auth, sécurité côté application uniquement).
-- E. Tant que cette migration n'est pas exécutée, checkAcces() dans
--    index.html laisse volontairement passer sans bloquer (SELECT sur une
--    colonne inexistante renvoie une erreur Supabase, interceptée par un
--    try/catch qui appelle le callback sans gate) — comportement demandé
--    explicitement, aucune régression pour les prestataires en attendant
--    l'exécution manuelle de cette migration.
-- F. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
