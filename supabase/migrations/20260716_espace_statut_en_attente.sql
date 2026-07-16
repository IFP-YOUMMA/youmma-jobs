-- ═══════════════════════════════════════════════════════════════════════════
-- ESPACE PROFESSIONNEL — ajout de la valeur 'en_attente' à statut
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE de 20260714_registre_chantier.sql (non modifié
-- rétroactivement) — à exécuter manuellement dans l'éditeur SQL Supabase.
-- Je ne l'exécute pas moi-même.
--
-- CONTEXTE : l'inscription libre sur #espace (clients/fournisseurs_
-- materiaux/superviseurs) réutilisait jusqu'ici 'suspendu'/'inactif' comme
-- proxy "en attente de première validation admin", faute d'une vraie
-- valeur dédiée — ce qui la rendait indiscernable d'une vraie suspension
-- a posteriori d'un compte déjà actif. Cette migration ajoute une valeur
-- 'en_attente' distincte aux 3 contraintes CHECK sur la colonne `statut`
-- (confirmé : c'est une colonne TEXT, il n'existe aucune colonne booléenne
-- "actif" sur ces 3 tables — vérifié dans 20260714_registre_chantier.sql
-- lignes 84, 123, 158).
--
-- Aucune des 3 contraintes CHECK visées n'a de nom explicite dans le fichier
-- d'origine (déclarées en ligne sur la colonne, ex. ligne 84 :
-- `statut TEXT NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','suspendu'))`).
-- Sans nom explicite, la convention de nommage Postgres produirait
-- <table>_<colonne>_check (donc très probablement clients_statut_check,
-- fournisseurs_materiaux_statut_check, superviseurs_statut_check — ce qui
-- correspond au nom proposé), mais par sécurité le DROP ci-dessous ne
-- s'appuie PAS sur ce nom deviné : il retrouve dynamiquement, pour chaque
-- table, la contrainte CHECK portant exactement sur la colonne `statut`
-- (via pg_constraint/pg_attribute, même méthode que
-- 20260716_registre_chantier_multi_fournisseur.sql pour la contrainte
-- UNIQUE de comptes_materiaux), puis la supprime par son vrai nom avant
-- d'ajouter la nouvelle version nommée explicitement.
--
-- Si aucune contrainte CHECK n'est trouvée sur une colonne statut (schéma
-- déjà modifié autrement, ou nom de colonne différent de ce qui est
-- attendu), le bloc DO $$ correspondant lève une exception explicite et
-- interrompt toute la transaction (BEGIN/COMMIT) plutôt que de continuer
-- sur une hypothèse fausse.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- clients.statut : ('actif','suspendu') → ('actif','suspendu','en_attente')
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_nom_contrainte TEXT;
BEGIN
  SELECT con.conname INTO v_nom_contrainte
  FROM pg_constraint con
  WHERE con.conrelid = 'clients'::regclass
    AND con.contype = 'c'
    AND con.conkey = ARRAY[
      (SELECT attnum FROM pg_attribute WHERE attrelid = 'clients'::regclass AND attname = 'statut')
    ]::smallint[];

  IF v_nom_contrainte IS NULL THEN
    RAISE EXCEPTION 'Aucune contrainte CHECK trouvée sur clients.statut — vérifier le schéma avant de continuer.';
  END IF;

  EXECUTE format('ALTER TABLE clients DROP CONSTRAINT %I', v_nom_contrainte);
  RAISE NOTICE 'clients : contrainte % supprimée', v_nom_contrainte;
END $$;

ALTER TABLE clients
  ADD CONSTRAINT clients_statut_check
    CHECK (statut IN ('actif','suspendu','en_attente'));


-- ─────────────────────────────────────────────────────────────────────────
-- fournisseurs_materiaux.statut : ('actif','suspendu') → (+'en_attente')
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_nom_contrainte TEXT;
BEGIN
  SELECT con.conname INTO v_nom_contrainte
  FROM pg_constraint con
  WHERE con.conrelid = 'fournisseurs_materiaux'::regclass
    AND con.contype = 'c'
    AND con.conkey = ARRAY[
      (SELECT attnum FROM pg_attribute WHERE attrelid = 'fournisseurs_materiaux'::regclass AND attname = 'statut')
    ]::smallint[];

  IF v_nom_contrainte IS NULL THEN
    RAISE EXCEPTION 'Aucune contrainte CHECK trouvée sur fournisseurs_materiaux.statut — vérifier le schéma avant de continuer.';
  END IF;

  EXECUTE format('ALTER TABLE fournisseurs_materiaux DROP CONSTRAINT %I', v_nom_contrainte);
  RAISE NOTICE 'fournisseurs_materiaux : contrainte % supprimée', v_nom_contrainte;
END $$;

ALTER TABLE fournisseurs_materiaux
  ADD CONSTRAINT fournisseurs_materiaux_statut_check
    CHECK (statut IN ('actif','suspendu','en_attente'));


-- ─────────────────────────────────────────────────────────────────────────
-- superviseurs.statut : ('actif','inactif') → (+'en_attente')
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_nom_contrainte TEXT;
BEGIN
  SELECT con.conname INTO v_nom_contrainte
  FROM pg_constraint con
  WHERE con.conrelid = 'superviseurs'::regclass
    AND con.contype = 'c'
    AND con.conkey = ARRAY[
      (SELECT attnum FROM pg_attribute WHERE attrelid = 'superviseurs'::regclass AND attname = 'statut')
    ]::smallint[];

  IF v_nom_contrainte IS NULL THEN
    RAISE EXCEPTION 'Aucune contrainte CHECK trouvée sur superviseurs.statut — vérifier le schéma avant de continuer.';
  END IF;

  EXECUTE format('ALTER TABLE superviseurs DROP CONSTRAINT %I', v_nom_contrainte);
  RAISE NOTICE 'superviseurs : contrainte % supprimée', v_nom_contrainte;
END $$;

ALTER TABLE superviseurs
  ADD CONSTRAINT superviseurs_statut_check
    CHECK (statut IN ('actif','inactif','en_attente'));

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Aucun des 3 noms de contrainte n'est deviné pour le DROP : chaque bloc
--    DO $$ interroge pg_constraint/pg_attribute pour trouver la contrainte
--    CHECK réellement posée sur la colonne `statut`, quel que soit son nom
--    réel. Le nom utilisé pour le ADD (clients_statut_check, etc.) est
--    la convention Postgres standard, cohérente avec le nom probable de
--    l'ancienne contrainte, mais peu importe : le DROP ne s'appuie jamais
--    dessus.
-- B. DEFAULT 'actif' inchangé sur les 3 tables — seule la liste de valeurs
--    autorisées par la CHECK change. Les inscriptions libres devront
--    explicitement passer statut='en_attente' (voir index.html), le
--    DEFAULT ne suffit pas seul.
-- C. Aucune colonne, aucune table, aucun trigger touché à part ces 3
--    contraintes CHECK — le reste du schéma de
--    20260714_registre_chantier.sql et de
--    20260716_registre_chantier_multi_fournisseur.sql est inchangé.
-- D. Enveloppé dans BEGIN; ... COMMIT; — DDL Postgres transactionnel,
--    même pattern que 20260716_registre_chantier_multi_fournisseur.sql :
--    si une des 3 tables ne peut pas être migrée (contrainte introuvable),
--    RAISE EXCEPTION annule tout le bloc, jamais d'état intermédiaire
--    (une table migrée, deux autres non).
-- ═══════════════════════════════════════════════════════════════════════════
