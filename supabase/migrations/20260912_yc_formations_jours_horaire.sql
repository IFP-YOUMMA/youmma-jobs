-- ═══════════════════════════════════════════════════════════════════════════
-- YC_FORMATIONS — jours et horaire de formation
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : le formulaire "Nouvelle formation" (youmma-center.html) capture
-- désormais les jours de la semaine où la formation a lieu (cases à cocher
-- multiples) ainsi que l'heure de début et de fin des séances. Ces
-- informations sont affichées sur la carte formation, dans le formulaire
-- d'inscription (lecture seule) et sur le reçu de versement IFP YOUMMA.
--
-- Tant que cette migration n'est pas appliquée : la création d'une nouvelle
-- formation échouera avec une erreur Postgrest explicite (colonnes
-- inconnues), affichée en toast rouge — aucune formation créée par erreur.
-- Les formations déjà existantes restent inchangées et continuent de
-- fonctionner normalement (ces champs sont simplement absents de leur
-- affichage jusqu'à une éventuelle mise à jour manuelle).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table yc_formations
  add column if not exists jours_formation text,
  add column if not exists heure_debut time,
  add column if not exists heure_fin time;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Trois colonnes ajoutées sur yc_formations, toutes nullable, via ADD
--    COLUMN IF NOT EXISTS (idempotent) : jours_formation (TEXT, liste de
--    jours séparés par des virgules, ex. "Lundi,Mercredi,Vendredi"),
--    heure_debut (TIME), heure_fin (TIME).
-- B. Aucune valeur par défaut, aucun backfill : les formations créées avant
--    cette migration gardent ces trois champs à NULL — le front n'affiche
--    alors simplement pas la ligne "jours/horaire" sur leur carte, dans le
--    formulaire d'inscription ni sur le reçu (comportement dégradé propre,
--    pas d'erreur).
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
