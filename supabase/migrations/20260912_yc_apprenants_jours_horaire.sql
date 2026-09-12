-- ═══════════════════════════════════════════════════════════════════════════
-- YC_APPRENANTS — jours et horaire (déplacés depuis yc_formations)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : les jours de formation et l'horaire (heure de début/fin) sont en
-- réalité propres à chaque apprenant ou groupe, pas à la formation dans son
-- ensemble (une même formation peut avoir plusieurs créneaux selon les
-- apprenants). Le formulaire "Nouvelle formation" ne capture donc plus ces
-- informations (les colonnes jours_formation/heure_debut/heure_fin restent
-- sur yc_formations mais ne sont plus jamais renseignées) ; elles sont
-- désormais saisies dans le formulaire "Inscrire un apprenant" et stockées
-- sur yc_apprenants.
--
-- Tant que cette migration n'est pas appliquée : l'inscription d'un nouvel
-- apprenant échouera avec une erreur Postgrest explicite (colonnes
-- inconnues), affichée en toast rouge — aucun apprenant créé par erreur, pas
-- de reçu généré non plus dans ce cas.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table yc_apprenants
  add column if not exists jours_formation text,
  add column if not exists heure_debut time,
  add column if not exists heure_fin time;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Trois colonnes ajoutées sur yc_apprenants, toutes nullable, via ADD
--    COLUMN IF NOT EXISTS (idempotent) : jours_formation (TEXT, liste de
--    jours séparés par des virgules), heure_debut (TIME), heure_fin (TIME).
--    Ce sont les mêmes noms de colonnes que sur yc_formations (introduites
--    dans une migration précédente) mais portées ici par l'apprenant.
-- B. Aucun backfill : les apprenants déjà inscrits avant cette migration
--    gardent ces trois champs à NULL — le reçu et le récapitulatif du
--    formulaire n'affichent alors simplement pas la ligne horaire pour eux
--    (comportement dégradé propre, pas d'erreur).
-- C. Les colonnes homonymes sur yc_formations ne sont pas supprimées ni
--    modifiées (elles restent en base mais ne sont plus renseignées par
--    aucun chemin du code applicatif désormais).
-- D. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
