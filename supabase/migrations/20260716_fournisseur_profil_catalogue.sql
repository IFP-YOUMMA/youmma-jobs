-- ═══════════════════════════════════════════════════════════════════════════
-- PROFILS FOURNISSEURS PUBLICS + CATALOGUE PRODUITS
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE de 20260714_registre_chantier.sql et des migrations
-- 20260716_* qui suivent (aucune modifiée rétroactivement) — à exécuter
-- manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas moi-même.
--
-- ⚠️ CONSTAT IMPORTANT découvert en relisant la page #construire avant de
-- coder (demandé) : une section "Nos fournisseurs partenaires" existe DÉJÀ
-- dans index.html (fonctions _pcChargerFournisseurs / _pcFournisseurCardHTML
-- / _pcOuvrirFournisseurModal / _pcChargerCatalogue), écrite lors d'une
-- phase antérieure de ce projet, AVANT la vérification rigoureuse du
-- schéma effectuée depuis. Ce code existant est actuellement cassé :
--   - il filtre .eq('actif', true) sur fournisseurs_materiaux — cette
--     colonne n'existe pas (la vraie colonne est `statut` TEXT, vérifié
--     dans 20260714_registre_chantier.sql ligne 158) ;
--   - il lit f.specialite et f.adresse — ces colonnes n'existent pas non
--     plus sur fournisseurs_materiaux (seules ville/commune existent) ;
--   - il interroge une table `catalogue_materiaux` (nom_produit,
--     prix_unitaire, photo_url, disponible) qui n'a jamais été créée par
--     aucune migration de ce repo — table fantôme, jamais réelle.
-- Résultat en production : la requête `.eq('actif', true)` échoue
-- silencieusement (colonne inconnue), la grille retombe sur un tableau
-- statique de 3 fournisseurs d'exemple (_PC_FOURNISSEURS_FALLBACK), et le
-- catalogue affiche toujours "en cours de mise à jour" faute de table.
-- Cette migration crée le VRAI schéma (colonnes ci-dessous + table
-- catalogue_produits) ; le code JS (parties B et C, fournies séparément)
-- corrige _pcChargerFournisseurs/_pcFournisseurCardHTML/_pcChargerCatalogue
-- pour consommer ce schéma réel au lieu de l'ancien schéma fantôme —
-- une seule version cohérente, pas une deuxième section en parallèle.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. fournisseurs_materiaux — colonnes du profil public
-- ─────────────────────────────────────────────────────────────────────────
-- profil_public : décision du fournisseur lui-même (toggle dans son
-- tableau de bord #espace) — indépendant de `statut` (validation admin).
-- Un fournisseur peut être statut='actif' (compte validé) et
-- profil_public=false (n'a pas encore choisi/voulu être visible) :
-- l'affichage public exige les DEUX conditions réunies.

ALTER TABLE fournisseurs_materiaux ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE fournisseurs_materiaux ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE fournisseurs_materiaux ADD COLUMN IF NOT EXISTS profil_public BOOLEAN NOT NULL DEFAULT false;


-- ─────────────────────────────────────────────────────────────────────────
-- 2. catalogue_produits — remplace la table fantôme catalogue_materiaux
-- ─────────────────────────────────────────────────────────────────────────
-- prix_gnf en NUMERIC(14,0) comme demandé (pas BIGINT, contrairement au
-- reste du registre chantier qui utilise BIGINT pour les montants — GNF
-- restant sans sous-unité, les deux types stockent des entiers sans perte;
-- NUMERIC(14,0) suit ici littéralement la définition demandée).

CREATE TABLE IF NOT EXISTS catalogue_produits (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fournisseur_id uuid NOT NULL REFERENCES fournisseurs_materiaux(id) ON DELETE CASCADE,
  nom_produit    TEXT NOT NULL,
  unite          TEXT,
  prix_gnf       NUMERIC(14,0),
  disponible     BOOLEAN NOT NULL DEFAULT true,
  ordre          INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_catalogue_fournisseur ON catalogue_produits(fournisseur_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 3. RLS — recommandation : LAISSER DÉSACTIVÉE (pas de policy créée)
-- ─────────────────────────────────────────────────────────────────────────
-- Rien n'est exécuté ici (aucun ENABLE ROW LEVEL SECURITY, aucun CREATE
-- POLICY) — cohérent avec chantiers/comptes_materiaux/registre_transactions
-- qui sont TOUTES en RLS désactivée dans ce projet (voir section 11 de
-- 20260714_registre_chantier.sql : ce site n'utilise pas Supabase Auth,
-- toutes les requêtes passent par la clé anon, la sécurité réelle est
-- côté application).
--
-- Pourquoi ne PAS activer RLS + policy SELECT USING (true) ici, même si
-- la clause "comme leads_construction" est tentante :
--   - USING (true) est aussi permissif que RLS désactivée : dans les deux
--     cas, n'importe qui disposant de la clé anon (visible dans le code
--     source de la page, donc pas un secret) peut lire TOUTE la table,
--     y compris les fournisseurs avec profil_public=false. Le filtre
--     profil_public/statut n'a jamais été une protection réelle au niveau
--     base — seulement un filtre d'affichage côté app, exactement comme
--     pour les autres tables du registre. Activer RLS ici n'apporterait
--     aucune garantie supplémentaire, juste une migration de plus.
--   - Une VRAIE protection nécessiterait une policy plus fine que
--     USING (true), par exemple :
--       USING (fournisseur_id IN (
--         SELECT id FROM fournisseurs_materiaux
--         WHERE profil_public = true AND statut = 'actif'
--       ))
--     — mais ce n'est pas ce qui a été demandé ("USING (true)
--     uniquement"), et ajouter cette policy sans Supabase Auth pour
--     distinguer les rôles reste cohérent avec les limites déjà actées
--     pour tout le registre chantier.
-- Recommandation : ne rien activer maintenant. Si une vraie confidentialité
-- devient nécessaire plus tard (ex. état intermédiaire "en attente
-- d'approbation admin" pour le profil public), ce sera l'occasion d'une
-- politique RLS plus fine que USING (true), pas ce correctif.

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 3 colonnes ajoutées à fournisseurs_materiaux via ADD COLUMN IF NOT
--    EXISTS (idempotent, sans danger si déjà présentes) : description,
--    photo_url, profil_public (DEFAULT false — un fournisseur existant ne
--    devient PAS public automatiquement, il doit explicitement activer
--    le toggle dans son tableau de bord).
-- B. catalogue_produits créée telle que spécifiée, remplace la table
--    fantôme catalogue_materiaux qu'aucune migration n'a jamais créée.
-- C. RLS volontairement non activée — recommandation motivée en section 3
--    ci-dessus, cohérente avec le reste du registre chantier.
-- D. Le code JS existant de #construire (_pcChargerFournisseurs,
--    _pcFournisseurCardHTML, _pcOuvrirFournisseurModal, _pcChargerCatalogue)
--    référence encore l'ancien schéma fantôme (actif/specialite/adresse/
--    catalogue_materiaux) — corrigé séparément dans index.html (parties B
--    et C de cette réponse), pas dans ce fichier SQL.
-- ═══════════════════════════════════════════════════════════════════════════
