-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — schéma initial (v1) : agents, produits, commandes, caisse, paramètres
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : nouvelle application YOUMMA GN (gestion commandes + livraison),
-- fichier autonome youmma-gn.html, même projet Supabase que YOUMMA JOBS /
-- YOUMMA CENTER, préfixe de table dédié gn_ pour rester complètement isolé
-- des tables yc_ existantes.
--
-- gn_caisse et gn_parametres sont ajoutées au schéma demandé (non fournies
-- dans le SQL initial du brief) car explicitement requises par les
-- sections 7 (module Caisse) et 10 (Paramètres, coordonnées entreprise)
-- de la demande — mêmes colonnes que leurs équivalents yc_caisse /
-- yc_parametres pour rester cohérent avec le reste du dépôt.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

create table if not exists gn_agents (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  telephone text not null unique,
  role text not null check (role in ('gerant','agent','livreur')),
  pin_hash text not null,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists gn_produits (
  id bigint generated always as identity primary key,
  nom text not null,
  categorie text,
  prix numeric not null,
  stock int not null default 0,
  photo_url text,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists gn_commandes (
  id uuid primary key default gen_random_uuid(),
  numero text unique not null,
  client_nom text not null,
  client_telephone text not null,
  client_adresse text not null,
  client_quartier text,
  lignes jsonb not null default '[]',
  total numeric not null default 0,
  mode_paiement text not null default 'cash' check (mode_paiement in ('cash','orange_money')),
  paiement_statut text not null default 'du' check (paiement_statut in ('du','paye')),
  statut text not null default 'recue' check (statut in ('recue','preparee','assignee','en_livraison','livree','echec','annulee')),
  livreur_id uuid references gn_agents(id),
  agent_creation text,
  date_creation timestamptz not null default now(),
  date_assignation timestamptz,
  date_debut_livraison timestamptz,
  date_livraison timestamptz,
  notes text
);

create index if not exists gn_commandes_statut_idx on gn_commandes (statut, date_creation desc);

-- Ajout (non fourni dans le brief initial, requis par la section 7) :
-- caisse GN, même structure que yc_caisse, colonne commande_id en plus pour
-- relier un encaissement de livraison à sa commande d'origine.
create table if not exists gn_caisse (
  id bigint generated always as identity primary key,
  date date not null default current_date,
  libelle text not null,
  type text not null check (type in ('entree','sortie')),
  montant numeric not null,
  mode_paiement text,
  categorie text,
  agent_nom text,
  commande_id uuid references gn_commandes(id),
  created_at timestamptz not null default now()
);

create index if not exists gn_caisse_date_idx on gn_caisse (date desc);

-- Ajout (non fourni dans le brief initial, requis par la section 10) :
-- paramètres clé/valeur, même modèle que yc_parametres (coordonnées de
-- l'entreprise pour un futur reçu de commande, compteur de numérotation
-- des commandes CMD-{année}-{NNNN}).
create table if not exists gn_parametres (
  cle text primary key,
  valeur text
);

alter table gn_agents disable row level security;
alter table gn_produits disable row level security;
alter table gn_commandes disable row level security;
alter table gn_caisse disable row level security;
alter table gn_parametres disable row level security;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Cinq tables créées, toutes via CREATE TABLE IF NOT EXISTS (idempotent) :
--    gn_agents, gn_produits, gn_commandes, gn_caisse, gn_parametres.
--    Trois d'entre elles (agents, produits, commandes) reprennent
--    exactement le SQL fourni dans le brief, sans modification.
-- B. gn_caisse et gn_parametres sont des AJOUTS de ma part (non présents
--    dans le SQL du brief) car les sections 7 et 10 de la demande les
--    exigent explicitement ; structure calquée sur yc_caisse / yc_parametres
--    pour cohérence avec le reste du dépôt. gn_caisse.commande_id référence
--    gn_commandes(id) pour tracer l'origine d'un encaissement de livraison.
-- C. gn_agents.role limité à ('gerant','agent','livreur') — pas de rôle
--    "comptable" ici (absent du périmètre YOUMMA GN décrit dans le brief).
-- D. gn_commandes.livreur_id référence gn_agents(id) ; aucune contrainte
--    n'empêche un agent non-livreur d'être référencé ici — la validation
--    du rôle est faite côté application (prise en charge réservée aux
--    comptes role='livreur').
-- E. Un index composite (statut, date_creation desc) sur gn_commandes
--    accélère les listes filtrées par statut, très fréquentes dans
--    l'application (commandes disponibles, mes livraisons, etc.).
-- F. RLS désactivée sur les 5 tables, à l'identique des tables yc_*
--    existantes de ce projet (accès contrôlé uniquement côté application
--    via la clé anon).
-- G. Aucune donnée insérée, aucune table/colonne/contrainte existante
--    modifiée — migration purement additive.
-- ═══════════════════════════════════════════════════════════════════════════
