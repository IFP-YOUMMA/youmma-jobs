-- ═══════════════════════════════════════════════════════════════════════════
-- PROVIDERS — doit_changer_mdp (compte créé par l'admin, PIN par défaut 0000)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : l'inscription normale (inscrirePrestataire) reste inchangée —
-- le prestataire choisit lui-même son code PIN à l'inscription. Cette
-- colonne sert uniquement au flux "admin crée le compte prestataire
-- directement" (panel admin, modal "Créer un prestataire") : le PIN par
-- défaut 0000 est hashé via hashPassword() (même fonction SHA-256 que
-- l'inscription normale et connexionPrestataire()) et écrit explicitement
-- dans password_hash par le code JS au moment de l'INSERT admin —
-- doit_changer_mdp=TRUE force alors une bannière "Changez votre code PIN
-- par défaut" au premier accès du prestataire sur son tableau de bord.
-- Contrairement à clients.mot_de_passe (voir 20260719_clients_mdp_admin.sql),
-- aucun problème de sécurité ici : password_hash existe déjà et est
-- toujours renseigné pour tout prestataire (inscription normale OU admin),
-- cette colonne n'est qu'un simple indicateur, DEFAULT FALSE ne change
-- l'accès de personne.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE providers
  ADD COLUMN IF NOT EXISTS doit_changer_mdp BOOLEAN DEFAULT FALSE;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée à providers via ADD COLUMN IF NOT EXISTS (idempotent,
--    sans danger si déjà présente) : doit_changer_mdp BOOLEAN DEFAULT FALSE.
--    Tous les prestataires existants (inscrits normalement) reçoivent
--    FALSE : ils ne voient jamais la nouvelle bannière, aucun changement
--    de comportement pour eux.
-- B. Mise à TRUE uniquement par _admCreerPrestataireValider() (panel admin)
--    au moment de la création, jamais par l'inscription normale. Remise à
--    FALSE par _dashChangerPin() dès que le prestataire change son PIN
--    depuis la bannière.
-- C. Aucune colonne, table, contrainte ou trigger existant modifié.
--    password_hash n'est pas une colonne nouvelle (déjà utilisée par
--    inscrirePrestataire()/connexionPrestataire()) — cette migration
--    n'y touche pas, elle ajoute seulement l'indicateur doit_changer_mdp.
-- ═══════════════════════════════════════════════════════════════════════════
