-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — module Fournisseurs / dépôt-vente
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : certains produits vendus par YOUMMA GN appartiennent à un
-- fournisseur tiers en dépôt-vente (YOUMMA encaisse le prix de vente client,
-- puis doit reverser au fournisseur son prix par unité vendue). Cette
-- migration ajoute la table des fournisseurs, les colonnes de rattachement
-- sur gn_produits, et la table des paiements versés aux fournisseurs.
--
-- Tant que cette migration n'est pas appliquée : cocher « Marchandise en
-- dépôt-vente » sur un produit échouera avec une erreur Postgrest explicite
-- (colonnes/table inconnues), affichée en toast rouge — aucune donnée
-- corrompue dans ce cas. Les produits déjà existants ne sont pas affectés
-- (depot_vente vaut false par défaut).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

create table if not exists gn_fournisseurs (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  telephone text,
  categorie text,
  notes text,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

alter table gn_produits
  add column if not exists depot_vente boolean not null default false,
  add column if not exists fournisseur_id uuid references gn_fournisseurs(id),
  add column if not exists prix_fournisseur numeric;

create table if not exists gn_fournisseur_paiements (
  id bigint generated always as identity primary key,
  fournisseur_id uuid not null references gn_fournisseurs(id),
  montant numeric not null,
  note text,
  agent_nom text,
  created_at timestamptz not null default now()
);

alter table gn_fournisseurs disable row level security;
alter table gn_fournisseur_paiements disable row level security;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Nouvelle table gn_fournisseurs (identité + coordonnées + notes libres),
--    RLS désactivée comme les autres tables gn_* de ce projet.
-- B. gn_produits gagne trois colonnes (idempotent, ADD COLUMN IF NOT
--    EXISTS) : depot_vente (bool, défaut false — aucun produit existant
--    n'est basculé en dépôt-vente automatiquement), fournisseur_id (FK
--    nullable vers gn_fournisseurs), prix_fournisseur (numeric nullable —
--    ce que YOUMMA doit au fournisseur par unité vendue, distinct du prix
--    de vente client déjà existant sur gn_produits.prix).
-- C. Nouvelle table gn_fournisseur_paiements : chaque ligne est un
--    versement fait par YOUMMA à un fournisseur (montant, note libre,
--    agent qui a enregistré le paiement). fournisseur_id est NOT NULL —
--    tout paiement doit être rattaché à un fournisseur existant.
-- D. Aucun changement sur gn_commandes ici : la colonne lignes (jsonb)
--    existante accueillera simplement des clés supplémentaires
--    (fournisseur_id, prix_fournisseur) pour les lignes de produits en
--    dépôt-vente, gérées entièrement côté application sans migration de
--    schéma (jsonb est déjà flexible).
-- E. Aucune donnée, contrainte ou colonne existante modifiée en dehors de
--    ces ajouts — migration purement additive, idempotente.
-- ═══════════════════════════════════════════════════════════════════════════
