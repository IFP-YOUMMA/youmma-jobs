-- ═══════════════════════════════════════════════════════════════════════════
-- YC_APPRENANTS — suivi complet (tranches, planning, statut) + reçus IFP YOUMMA
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : refonte complète de la page Formations (youmma-center.html).
-- L'inscription d'un apprenant capture désormais son planning personnalisé
-- (durée, fréquence, heures/séance) et son échéancier de paiement en deux
-- tranches (50 % à l'inscription, 50 % à mi-parcours), avec un statut de
-- progression dédié (inscrit → en_cours → évaluation → attesté), distinct du
-- statut générique existant. Le reçu de versement imprimable (IFP YOUMMA)
-- est numéroté séquentiellement par année via une clé yc_parametres.
--
-- Tant que cette migration n'est pas appliquée :
--   - L'inscription d'un nouvel apprenant échouera avec une erreur Postgrest
--     explicite (colonnes inconnues), affichée en toast rouge — aucun
--     apprenant créé par erreur.
--   - Les actions "Présence" et "Modifier" sur un apprenant existant
--     échoueront de la même façon si elles touchent une colonne manquante.
--   - Le reçu se génère et s'affiche normalement même sans la ligne
--     dernier_rec_numero_2026 (le compteur démarre alors implicitement à 0
--     côté JS) ; l'INSERT proposé ci-dessous ne fait qu'amorcer la séquence
--     pour l'année en cours de façon explicite.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table yc_apprenants
  add column if not exists duree_mois numeric,
  add column if not exists frequence_semaine int,
  add column if not exists heures_seance numeric,
  add column if not exists tranche1_montant numeric,
  add column if not exists tranche1_date date,
  add column if not exists tranche2_montant numeric,
  add column if not exists tranche2_date date,
  add column if not exists tranche2_payee boolean not null default false,
  add column if not exists statut_apprenant text not null default 'inscrit',
  add column if not exists nb_presences int not null default 0;

insert into yc_parametres (cle, valeur) values
  ('dernier_rec_numero_2026', '0')
on conflict (cle) do nothing;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Dix colonnes visées sur yc_apprenants via ADD COLUMN IF NOT EXISTS
--    (idempotent) : duree_mois, frequence_semaine, heures_seance,
--    tranche1_montant, tranche1_date, tranche2_montant, tranche2_date,
--    tranche2_payee (bool, défaut false), statut_apprenant (text, défaut
--    'inscrit') sont réellement nouvelles. nb_presences existe déjà
--    (utilisée depuis la première version de la page Formations) : avec
--    IF NOT EXISTS, Postgres ignore silencieusement toute la clause pour
--    une colonne déjà présente — le NOT NULL DEFAULT 0 demandé ici ne sera
--    donc PAS rétroactivement appliqué à la colonne existante (pas de
--    risque d'échec sur d'éventuelles valeurs NULL existantes, mais pas de
--    contrainte ajoutée non plus). Si l'ajout effectif de cette contrainte
--    est souhaité, il faudra un ALTER COLUMN dédié (hors scope ici).
-- B. Aucun backfill sur les autres colonnes : les apprenants déjà inscrits
--    avant cette migration gardent duree_mois/frequence_semaine/etc. à NULL
--    et statut_apprenant à 'inscrit' par défaut — leur affichage sur la
--    nouvelle vue détail montrera des tranches vides ("—") jusqu'à une
--    éventuelle mise à jour manuelle.
-- C. Un seul INSERT ... ON CONFLICT DO NOTHING dans yc_parametres, pour la
--    clé dernier_rec_numero_2026 : n'écrase rien si la clé existe déjà
--    (idempotent, sûr à ré-exécuter).
-- D. Aucune colonne, table, contrainte ou trigger existant modifié en dehors
--    de nb_presences (voir point A). L'ancienne colonne générique `statut`
--    sur yc_apprenants n'est pas touchée et reste inutilisée par le nouveau
--    code (remplacée par statut_apprenant pour l'affichage).
-- ═══════════════════════════════════════════════════════════════════════════
