-- ═══════════════════════════════════════════════════════════════════════════
-- CLIENTS — mot de passe (compte créé par l'admin, sans SMS)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- CONTEXTE : le flux d'inscription libre (client s'inscrit lui-même) reste
-- entièrement basé sur l'OTP SMS existant (table verification_codes),
-- inchangé par cette migration. Ces 3 colonnes ne servent QUE au flux
-- alternatif "admin crée le compte client directement" (panel admin, modal
-- "Créer un client") : le mot de passe '0000' et doit_changer_mdp=TRUE sont
-- attribués explicitement par le code JS au moment de l'INSERT admin — PAS
-- par un DEFAULT au niveau de la colonne (voir point A ci-dessous, écart
-- volontaire par rapport à la demande initiale, pour une raison de sécurité).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS mot_de_passe TEXT,
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS doit_changer_mdp BOOLEAN DEFAULT FALSE;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. ⚠️ ÉCART VOLONTAIRE PAR RAPPORT À LA DEMANDE : mot_de_passe est ajouté
--    SANS "DEFAULT '0000'" (contrairement au texte fourni). Avec un DEFAULT
--    au niveau colonne, TOUT client déjà inscrit via OTP (des centaines,
--    potentiellement) se serait vu attribuer rétroactivement le mot de
--    passe '0000' — et le nouveau mode de connexion par mot de passe leur
--    aurait alors été utilisable par QUICONQUE connaissant leur numéro de
--    téléphone (souvent public/partagé), sans qu'ils n'aient jamais choisi
--    ni même connu ce mot de passe. C'est une faille de sécurité, pas un
--    détail : elle aurait ouvert l'accès à des comptes clients existants à
--    des tiers. Le code JS (_admCreerClientValider) fixe explicitement
--    mot_de_passe='0000' UNIQUEMENT à la création par l'admin — les
--    clients existants gardent mot_de_passe=NULL, et
--    "WHERE mot_de_passe = MDP" ne peut jamais matcher NULL en SQL, donc le
--    mode "connexion par mot de passe" reste strictement inutilisable pour
--    eux tant qu'ils n'ont pas de mot de passe explicitement défini.
-- B. created_by_admin BOOLEAN DEFAULT FALSE — TRUE uniquement pour les
--    comptes créés depuis le panel admin (mis explicitement à TRUE par le
--    code JS ; DEFAULT FALSE ici est sans risque, c'est une simple
--    étiquette informative, pas un secret).
-- C. doit_changer_mdp BOOLEAN DEFAULT FALSE — TRUE à la création par
--    l'admin (fixé explicitement par le code JS), repassé à FALSE dès que
--    le client change son mot de passe depuis la bannière de premier accès.
--    DEFAULT FALSE ici est également sans risque : un client existant sans
--    mot de passe ne verra jamais la bannière (elle ne s'affiche que si
--    doit_changer_mdp=TRUE, jamais activé pour eux).
-- D. Aucune colonne, table, contrainte ou trigger existant modifié. Le flux
--    OTP (verification_codes, _espaceEnvoyerCode/_espaceValiderCode) n'est
--    ni touché ni consommé par cette migration.
-- ═══════════════════════════════════════════════════════════════════════════
