-- ═══════════════════════════════════════════════════════════════════════════
-- LEADS_CONSTRUCTION — ajout ville + budget_estime
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : formulaire "Démarrer votre projet" de #construire enrichi
-- (ville/quartier du chantier + budget estimé, servant aussi à orienter vers
-- une formule Essentiel/Confort/Prestige). Colonnes vérifiées en direct
-- contre la base réelle (requêtes SELECT ciblées) : ville et budget_estime
-- n'existent pas sur leads_construction — seules nom/telephone/pays/
-- nature_projet/description/statut existent (20260714_registre_chantier.sql).
-- budget_estime est stocké en TEXT (valeurs 'essentiel'/'confort'/'prestige'/
-- 'inconnu' issues du <select> du formulaire, pas un montant), pour rester
-- cohérent avec le choix qualitatif du formulaire plutôt qu'un montant
-- numérique précis que le visiteur ne connaît pas forcément.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE leads_construction
  ADD COLUMN IF NOT EXISTS ville TEXT,
  ADD COLUMN IF NOT EXISTS budget_estime TEXT;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 2 colonnes ajoutées (ville TEXT, budget_estime TEXT), toutes deux
--    nullables, sans DEFAULT. Aucune régression sur les lignes existantes.
-- B. Le formulaire existant (envoyerLeadConstruire(), remplacé par
--    cstrEnvoyerDemande() dans index.html) insère déjà nom/telephone/
--    description/statut — inchangés ici, seuls ville/budget_estime
--    s'ajoutent au payload.
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
-- ═══════════════════════════════════════════════════════════════════════════
