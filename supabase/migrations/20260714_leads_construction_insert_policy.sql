-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER TEL QUEL.
-- Corrige le blocage constaté en test réel sur https://slawwbhlakilnviwzyrb.supabase.co :
-- POST /rest/v1/leads_construction (clé anon) → 401 / code 42501
-- "new row violates row-level security policy for table leads_construction"
--
-- RLS est déjà activée sur la table telle que déployée (sinon cette erreur
-- ne serait pas possible), mais sans policy d'INSERT pour le rôle anon —
-- donc le formulaire public "Construire avec YOUMMA JOBS" ne peut créer
-- aucun lead. Cette migration ajoute uniquement l'INSERT public demandé,
-- même pattern que les autres tables du site qui acceptent des soumissions
-- anonymes (ex. provider_photos : policies permissives USING/WITH CHECK (true),
-- pas de Supabase Auth sur ce site — voir la discussion RLS de
-- 20260714_registre_chantier.sql pour le contexte complet).
--
-- Portée volontairement limitée à l'INSERT (c'est tout ce qui a été demandé) :
-- aucune policy SELECT n'est ajoutée ici. À ce jour, index.html ne lit jamais
-- leads_construction (aucun écran admin dessus) — si un futur écran admin
-- doit lister les leads via la clé anon, il faudra une policy SELECT
-- supplémentaire à ce moment-là.

-- ⚠️ CORRECTIF : `CREATE POLICY IF NOT EXISTS` n'est pas une syntaxe SQL
-- valide (contrairement à CREATE TABLE/INDEX) — la première version de ce
-- fichier utilisait ce pattern (copié de provider_photos.sql) et a très
-- probablement échoué en silence sur la ligne CREATE POLICY, expliquant
-- pourquoi l'INSERT anonyme échouait encore après "application" de la
-- policy. Pattern correct et idempotent ci-dessous : DROP POLICY IF EXISTS
-- (qui lui supporte IF EXISTS) suivi d'un CREATE POLICY simple.

ALTER TABLE leads_construction ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "leads_construction_insert_public" ON leads_construction;

CREATE POLICY "leads_construction_insert_public"
  ON leads_construction FOR INSERT
  WITH CHECK (true);
