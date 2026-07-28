-- ═══════════════════════════════════════════════════════════════════════════
-- APP_MESSAGES — message dynamique affiché aux prestataires (bandeau dashboard)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : remplace le bandeau "🚀 Accès gratuit jusqu'au 30 Septembre
-- 2026..." qui était codé en dur dans index.html (_dashUpdateUI()). Un seul
-- message peut être "actif" à la fois (géré côté JS admin : publier un
-- nouveau message désactive tous les précédents avant d'insérer). RLS
-- désactivée, comme le reste du projet (sauf leads_construction) — accès via
-- le client anon `sb` uniquement.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

CREATE TABLE IF NOT EXISTS app_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  contenu text NOT NULL,
  actif boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

INSERT INTO app_messages (contenu, actif)
VALUES ('Bienvenue dans la famille YOUMMA JOBS ! Complétez votre profil pour être prêt au lancement du 4 Septembre.', true);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Nouvelle table app_messages (id, contenu, actif, created_at) — aucune
--    table ni colonne existante modifiée.
-- B. 1 message inséré et marqué actif=true (celui qui remplace le bandeau de
--    lancement codé en dur). Tant que cette migration n'est pas exécutée,
--    le SELECT côté dashboard échoue silencieusement (try/catch côté JS) et
--    aucun bandeau ne s'affiche — pas de crash, juste une bannière absente.
-- C. Un seul enregistrement actif=true à la fois par convention applicative
--    (le bouton "Publier" du panel admin désactive tous les messages avant
--    d'insérer le nouveau) — pas de contrainte SQL UNIQUE ajoutée pour rester
--    simple, cohérent avec le style RLS-désactivée du reste du projet.
-- ═══════════════════════════════════════════════════════════════════════════
