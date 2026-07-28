-- ═══════════════════════════════════════════════════════════════════════════
-- PROVIDERS — policy UPDATE publique (au cas où RLS serait activé sur cette table)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- ⚠️ IMPORTANT — À VÉRIFIER AVANT D'EXÉCUTER : aucune migration de ce dépôt
-- n'active jamais RLS sur `providers` (contrairement à provider_photos,
-- voir 20260708_provider_photos.sql, où RLS EST activée avec des policies
-- permissives). L'état RLS réel de `providers` a donc été configuré ailleurs
-- (dashboard Supabase, avant l'existence de ce dossier migrations) et n'est
-- pas visible depuis ce code. AVANT d'exécuter ce fichier, lancez d'abord :
--
--   SELECT relrowsecurity FROM pg_class WHERE relname = 'providers';
--   SELECT policyname, cmd FROM pg_policies WHERE tablename = 'providers';
--
-- Si relrowsecurity = false (RLS désactivée), cette migration est un no-op
-- inoffensif (une policy sans RLS active n'a aucun effet) — mais dans ce cas
-- le bug "photo_url reste NULL" a une AUTRE cause (à chercher via le
-- console.log('[UPDATE providers]', ...) ajouté dans uploadProviderPhoto(),
-- qui affichera exactement l'erreur ou le nombre de lignes affectées).
-- Si relrowsecurity = true ET qu'aucune policy UPDATE n'existe déjà pour
-- providers, cette migration est la cause probable et le correctif ci-dessous
-- s'applique.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

CREATE POLICY IF NOT EXISTS "providers update public"
  ON providers FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 policy ajoutée (idempotente via IF NOT EXISTS) : autorise n'importe
--    quel rôle (y compris anon) à UPDATE n'importe quelle ligne de
--    providers. Cohérent avec le modèle de confiance déjà en place ailleurs
--    dans ce projet (pas de Supabase Auth, sécurité gérée au niveau
--    applicatif, anon key partagée par tout le monde).
-- B. Aucune colonne, table, contrainte ou trigger existant modifié.
-- C. N'a d'effet que si RLS est réellement activée sur providers — voir
--    l'avertissement ci-dessus pour vérifier ce point avant d'exécuter.
-- ═══════════════════════════════════════════════════════════════════════════
