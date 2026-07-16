-- ═══════════════════════════════════════════════════════════════════════════
-- REGISTRE CHANTIER — MULTI-FOURNISSEUR PAR CHANTIER
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE de 20260714_registre_chantier.sql (non modifié
-- rétroactivement) — à exécuter manuellement dans l'éditeur SQL Supabase.
-- Je ne l'exécute pas moi-même.
--
-- CONTEXTE : un chantier peut désormais avoir PLUSIEURS fournisseurs de
-- matériaux en parallèle, chacun avec son propre compte matériaux (solde
-- indépendant, historique de transactions indépendant). Un fournisseur A
-- ne doit jamais voir les transactions du fournisseur B sur le même
-- chantier — seuls l'admin et le superviseur du chantier voient tout.
--
-- Tout le script (sections 1 à 5) est enveloppé dans BEGIN; ... COMMIT; :
-- toutes les instructions ci-dessous (DROP VIEW, DROP TRIGGER, le DO $$
-- de recherche/suppression de contrainte, ALTER TABLE, CREATE VIEW) sont
-- des DDL Postgres, donc transactionnelles. Si une étape échoue — par
-- exemple un CREATE VIEW qui référence une colonne inexistante — la
-- transaction entière est annulée automatiquement (ROLLBACK implicite) :
-- jamais d'état intermédiaire (vues supprimées, colonne déjà droppée,
-- mais rien recréé).
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 0. VÉRIFICATION AVANT MODIFICATION — nom réel de la contrainte UNIQUE
-- ─────────────────────────────────────────────────────────────────────────
-- comptes_materiaux.chantier_id a été déclarée `UUID NOT NULL UNIQUE
-- REFERENCES chantiers(id) ...` (contrainte UNIQUE de COLONNE, sans nom
-- explicite) dans 20260714_registre_chantier.sql, ligne 264. Sans nom
-- explicite, Postgres nomme automatiquement une contrainte UNIQUE de
-- colonne selon sa convention documentée : <table>_<colonne>_key. Un seul
-- UNIQUE existe sur cette table (pas de collision, pas de suffixe
-- numérique), donc le nom attendu est très exactement :
--
--     comptes_materiaux_chantier_id_key
--
-- ⚠️ Je n'ai pas de connexion SQL directe à la base en production dans
-- cette session (pas d'accès au catalogue Postgres live) — cette
-- déduction s'appuie uniquement sur la règle de nommage standard de
-- Postgres appliquée au texte exact déjà exécuté. Pour lever tout doute,
-- exécute d'abord seule cette requête et regarde le résultat avant de
-- lancer la suite :
--
--   SELECT conname
--   FROM pg_constraint
--   WHERE conrelid = 'comptes_materiaux'::regclass AND contype = 'u';
--
-- Par sécurité, le DROP réel (section 3) ne s'appuie PAS sur ce nom
-- deviné : il retrouve la contrainte dynamiquement par requête sur
-- pg_constraint avant de la supprimer, donc correct même si le nom réel
-- diverge de la prédiction ci-dessus.


BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. VUES DÉPENDANTES DE chantiers.fournisseur_id
-- ─────────────────────────────────────────────────────────────────────────
-- À retirer avant le DROP COLUMN (section 4), sinon Postgres refuse :
-- "cannot drop column ... other objects depend on it". Vérifié par
-- recherche du nom exact dans index.html : aucune des deux vues n'est
-- consommée par le frontend — recréées plus étroites sans risque de
-- casser l'UI (section 5).

DROP VIEW IF EXISTS v_facture_finale_chantier;
DROP VIEW IF EXISTS vue_facture_finale;


-- ─────────────────────────────────────────────────────────────────────────
-- 2. TRIGGER chantiers-level à retirer
-- ─────────────────────────────────────────────────────────────────────────
-- fn_verifier_fournisseur_actif() n'est PAS modifiée : elle est générique
-- (lit NEW.fournisseur_id quelle que soit la table appelante) et déjà
-- attachée à comptes_materiaux via trg_comptes_materiaux_verifier_
-- fournisseur (créée dans le fichier original, ligne 278 : "BEFORE INSERT
-- OR UPDATE OF fournisseur_id ON comptes_materiaux") — c'est EXACTEMENT le
-- contrôle "vérifie le fournisseur_id de comptes_materiaux au moment de
-- l'insert" demandé : il existait déjà avant cette migration, rien à
-- ajouter. Elle reste également attachée à contrats sans changement. Seul
-- le trigger posé sur chantiers (dont la colonne disparaît ci-dessous)
-- doit partir.

DROP TRIGGER IF EXISTS trg_chantiers_verifier_fournisseur ON chantiers;


-- ─────────────────────────────────────────────────────────────────────────
-- 3. comptes_materiaux : UNIQUE(chantier_id) → UNIQUE(chantier_id, fournisseur_id)
-- ─────────────────────────────────────────────────────────────────────────
-- Retrouve dynamiquement la contrainte UNIQUE portant sur la seule colonne
-- chantier_id (peu importe son nom réel) et la supprime.

DO $$
DECLARE
  v_nom_contrainte TEXT;
BEGIN
  SELECT con.conname INTO v_nom_contrainte
  FROM pg_constraint con
  WHERE con.conrelid = 'comptes_materiaux'::regclass
    AND con.contype = 'u'
    AND con.conkey = ARRAY[
      (SELECT attnum FROM pg_attribute WHERE attrelid = 'comptes_materiaux'::regclass AND attname = 'chantier_id')
    ]::smallint[];

  IF v_nom_contrainte IS NOT NULL THEN
    EXECUTE format('ALTER TABLE comptes_materiaux DROP CONSTRAINT %I', v_nom_contrainte);
    RAISE NOTICE 'Contrainte UNIQUE supprimée : %', v_nom_contrainte;
  ELSE
    RAISE NOTICE 'Aucune contrainte UNIQUE trouvée sur (chantier_id) seul — rien à supprimer (déjà migré ?).';
  END IF;
END $$;

ALTER TABLE comptes_materiaux
  ADD CONSTRAINT comptes_materiaux_chantier_fournisseur_key UNIQUE (chantier_id, fournisseur_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 4. chantiers.fournisseur_id devient redondant
-- ─────────────────────────────────────────────────────────────────────────
-- Un chantier n'a plus un seul fournisseur : cette information vit
-- désormais uniquement dans comptes_materiaux (une ligne par fournisseur
-- assigné à ce chantier). idx_chantiers_fournisseur_id est supprimé
-- automatiquement par Postgres avec la colonne (il ne porte que sur elle).

ALTER TABLE chantiers DROP COLUMN IF EXISTS fournisseur_id;


-- ─────────────────────────────────────────────────────────────────────────
-- 5. Recréation des 2 vues sans la notion "un seul fournisseur par chantier"
-- ─────────────────────────────────────────────────────────────────────────
-- v_facture_finale_chantier : le total facturé reste agrégé au niveau du
-- chantier entier (tous fournisseurs confondus) — comportement inchangé
-- pour ce total, seule la colonne fournisseur_id disparaît (elle n'existe
-- plus sur chantiers). Une ventilation par fournisseur nécessiterait de
-- regrouper par compte_id plutôt que par chantier_id — non demandé ici,
-- laissé pour une passe ultérieure si besoin.

CREATE OR REPLACE VIEW v_facture_finale_chantier AS
SELECT
  c.id                                                                       AS chantier_id,
  c.nom                                                                      AS chantier_nom,
  c.statut                                                                   AS chantier_statut,
  c.client_id,
  COALESCE(SUM(rt.montant_gnf) FILTER (WHERE rt.type_operation = 'sortie_confirmee'), 0) AS total_materiaux_sortis_gnf,
  COUNT(rt.id)                 FILTER (WHERE rt.type_operation = 'sortie_confirmee')     AS nb_sorties_confirmees
FROM chantiers c
LEFT JOIN registre_transactions rt ON rt.chantier_id = c.id
GROUP BY c.id, c.nom, c.statut, c.client_id;

-- vue_facture_finale : la jointure fournisseurs_materiaux via
-- ch.fournisseur_id n'a plus de sens (plusieurs fournisseurs possibles par
-- chantier) — retirée. rfc.validation_fournisseur_id (quel fournisseur a
-- validé LE rapport final) est une colonne indépendante de
-- rapport_final_chantier, non affectée par ce changement, conservée telle
-- quelle dans la vue.

CREATE OR REPLACE VIEW vue_facture_finale AS
SELECT
  rfc.id                          AS rapport_final_id,
  rfc.statut                      AS rapport_statut,
  rfc.periode_debut,
  rfc.periode_fin,
  rfc.nombre_jours_travail,

  ch.id                            AS chantier_id,
  ch.nom                           AS chantier_nom,
  ch.statut                        AS chantier_statut,
  ch.ville, ch.commune, ch.quartier, ch.adresse,

  cl.id                            AS client_id,
  cl.nom                           AS client_nom,
  cl.prenom                        AS client_prenom,
  cl.telephone                     AS client_telephone,

  sv.id                            AS superviseur_id,
  sv.nom                           AS superviseur_nom,
  sv.prenom                        AS superviseur_prenom,

  rfc.total_sorti_gnf,
  rfc.total_utilise_gnf,
  rfc.total_stock_gnf,

  rfc.total_verse_gnf,
  rfc.total_depense_gnf,
  rfc.solde_final_gnf,

  rfc.forfait_montant_gnf,
  rfc.forfait_paye_gnf,
  rfc.forfait_restant_gnf,

  rfc.validation_superviseur_at, rfc.validation_superviseur_note,
  rfc.validation_fournisseur_at, rfc.validation_fournisseur_note,
  rfc.validation_client_at,      rfc.validation_client_note,
  rfc.validation_admin_at,       rfc.validation_admin_note,

  rfc.litige_motif, rfc.litige_ouvert_par, rfc.litige_ouvert_at,
  rfc.litige_resolu_at, rfc.litige_resolution_note

FROM rapport_final_chantier rfc
JOIN chantiers ch                    ON ch.id = rfc.chantier_id
JOIN clients cl                      ON cl.id = ch.client_id
LEFT JOIN superviseurs sv            ON sv.id = ch.superviseur_id;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Nom de contrainte prédit : comptes_materiaux_chantier_id_key (règle de
--    nommage Postgres standard appliquée à une UNIQUE de colonne sans nom
--    explicite). Le DROP réel (section 3) est dynamique et ne dépend PAS
--    de cette prédiction — vérifie avec la requête de la section 0 si tu
--    veux confirmer avant d'exécuter.
-- B. fn_verifier_fournisseur_actif() : aucune modification. Générique,
--    déjà appelée sur comptes_materiaux (INSERT/UPDATE OF fournisseur_id,
--    inchangé) et sur contrats (inchangé) — les deux continuent de
--    fonctionner sans changement de code SQL.
-- C. v_facture_finale_chantier et vue_facture_finale : ni l'une ni
--    l'autre n'est consommée par index.html (vérifié par recherche du nom
--    exact dans le fichier) — recréées plus étroites sans casser de code
--    front existant.
-- D. rapport_final_chantier, contrats, registre_transactions : aucune
--    colonne modifiée dans ces tables, seules les 2 vues ci-dessus et le
--    couple chantiers/comptes_materiaux sont touchés.
-- E. cl.prenom / sv.prenom (vue_facture_finale) : vérifiés colonne par
--    colonne dans 20260714_registre_chantier.sql — clients.prenom (ligne
--    78) et superviseurs.prenom (ligne 121) existent tous les deux
--    (nullable). Les ~26 colonnes de rapport_final_chantier référencées
--    dans la vue (periode_debut, total_sorti_gnf, validation_*_at/_note,
--    litige_*, etc.) existent également telles quelles (lignes 763-827) —
--    aucune correction nécessaire sur ce point.
-- F. Sections 1 à 5 enveloppées dans BEGIN; ... COMMIT; — DDL Postgres
--    entièrement transactionnel, donc un échec sur n'importe quelle étape
--    (notamment le CREATE VIEW final) annule tout le bloc, jamais d'état
--    intermédiaire.
-- ═══════════════════════════════════════════════════════════════════════════
