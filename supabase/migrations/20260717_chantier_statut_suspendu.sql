-- ═══════════════════════════════════════════════════════════════════════════
-- CHANTIERS — ajout de la valeur 'suspendu' à statut
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : la fiche détail chantier de l'onglet admin "Chantiers" ajoute
-- des actions [Suspendre]/[Reprendre]. Le schéma réel de chantiers.statut
-- (20260714_registre_chantier.sql ligne 192) n'autorise que 3 valeurs :
-- 'en_etude', 'en_cours', 'termine' — 'suspendu' n'existe pas et un
-- UPDATE avec cette valeur échouerait (violation de la contrainte CHECK).
-- Cette migration ajoute 'suspendu' à la liste, même pattern exact que
-- 20260716_espace_statut_en_attente.sql (déjà appliqué pour clients/
-- fournisseurs_materiaux/superviseurs) : la contrainte CHECK d'origine
-- n'a pas de nom explicite (déclarée en ligne sur la colonne), donc le nom
-- réel est retrouvé dynamiquement via pg_constraint/pg_attribute avant
-- suppression — jamais deviné.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

DO $$
DECLARE
  v_nom_contrainte TEXT;
BEGIN
  SELECT con.conname INTO v_nom_contrainte
  FROM pg_constraint con
  WHERE con.conrelid = 'chantiers'::regclass
    AND con.contype = 'c'
    AND con.conkey = ARRAY[
      (SELECT attnum FROM pg_attribute WHERE attrelid = 'chantiers'::regclass AND attname = 'statut')
    ]::smallint[];

  IF v_nom_contrainte IS NULL THEN
    RAISE EXCEPTION 'Aucune contrainte CHECK trouvée sur chantiers.statut — vérifier le schéma avant de continuer.';
  END IF;

  EXECUTE format('ALTER TABLE chantiers DROP CONSTRAINT %I', v_nom_contrainte);
  RAISE NOTICE 'chantiers : contrainte % supprimée', v_nom_contrainte;
END $$;

ALTER TABLE chantiers
  ADD CONSTRAINT chantiers_statut_check
    CHECK (statut IN ('en_etude','en_cours','termine','suspendu'));

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Le nom de la contrainte n'est jamais deviné pour le DROP : retrouvé
--    dynamiquement via pg_constraint/pg_attribute pour la colonne `statut`
--    de `chantiers`, quel que soit son nom réel.
-- B. DEFAULT inchangé ('en_etude') — seule la liste de valeurs autorisées
--    par la CHECK change, +'suspendu'.
-- C. Aucune colonne, table, trigger touché à part cette contrainte CHECK.
--    En particulier fn_gerer_solde_registre (trigger BEFORE INSERT sur
--    registre_transactions) n'est pas concerné : il ne réagit qu'à
--    type_operation, jamais à chantiers.statut.
-- D. Tant que cette migration n'est pas exécutée, les boutons [Suspendre]/
--    [Reprendre] de l'onglet admin "Chantiers" échoueront avec un message
--    d'erreur explicite (contrainte CHECK violée) — pas de crash silencieux,
--    mais pas de repli non plus : ce n'est pas une colonne optionnelle,
--    c'est une action qui nécessite cette migration pour fonctionner.
-- ═══════════════════════════════════════════════════════════════════════════
