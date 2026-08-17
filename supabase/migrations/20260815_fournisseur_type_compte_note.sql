-- ═══════════════════════════════════════════════════════════════════════════
-- FOURNISSEURS_MATERIAUX — type_compte + note_moyenne (badges annuaire)
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : les nouveaux badges de carte fournisseur dans l'annuaire
-- (index.html, annuaireChargerFournisseurs()) demandent un type de compte
-- (particulier/usine/entreprise) et une note moyenne. Ni l'une ni l'autre
-- colonne n'existe sur fournisseurs_materiaux — vérifié en relisant TOUTES
-- les migrations touchant cette table (20260714_registre_chantier.sql,
-- 20260716_fournisseur_profil_catalogue.sql,
-- 20260717_fournisseur_photo_couverture.sql,
-- 20260803_admin_gestion_comptes.sql). note_moyenne existe déjà, mais
-- UNIQUEMENT sur providers (artisans, ajoutée par
-- 20260720_missions_declarees_avis_clients.sql) — ce n'est pas la même
-- colonne, providers et fournisseurs_materiaux restant deux tables
-- distinctes sans aucun lien.
--
-- Tant que cette migration n'est pas appliquée, le code JS lit ces deux
-- colonnes via un SELECT séparé et isolé (try/catch), donc l'annuaire
-- fournisseur reste pleinement fonctionnel sans elles : les badges
-- retombent simplement sur leurs valeurs par défaut ("🏢 Entreprise",
-- "⭐ Nouveau").
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE fournisseurs_materiaux
  ADD COLUMN IF NOT EXISTS type_compte TEXT DEFAULT 'entreprise'
    CHECK (type_compte IN ('particulier','usine','entreprise')),
  ADD COLUMN IF NOT EXISTS note_moyenne NUMERIC(3,1) DEFAULT 0;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 2 colonnes ajoutées, toutes deux ADD COLUMN IF NOT EXISTS (idempotent) :
--    - type_compte TEXT DEFAULT 'entreprise', CHECK IN
--      ('particulier','usine','entreprise') — DEFAULT 'entreprise' choisi
--      pour matcher exactement le repli déjà écrit côté JS ("sinon
--      (entreprise ou null) → Entreprise"), donc aucun fournisseur existant
--      ne change de badge après application de cette migration.
--    - note_moyenne NUMERIC(3,1) DEFAULT 0 — même type que
--      providers.note_moyenne, pour rester cohérent avec la convention déjà
--      posée ailleurs dans le schéma, bien qu'il s'agisse d'une colonne
--      indépendante sur une table différente. DEFAULT 0 : le JS interprète
--      déjà 0/absent comme "note_moyenne existe et > 0 ? ... : ⭐ Nouveau",
--      donc aucune fausse note affichée pour les fournisseurs existants.
-- B. Rien d'autre modifié : aucune colonne, contrainte, table ou trigger
--    existant touché. RLS non activée, cohérent avec le reste de
--    fournisseurs_materiaux (voir 20260716_fournisseur_profil_catalogue.sql
--    section 3 pour la justification déjà actée sur cette table).
-- C. Alimentation de note_moyenne : hors périmètre de cette migration —
--    aucun système d'avis/notation n'existe pour les fournisseurs de
--    matériaux à ce jour (à la différence des artisans, avis_clients/
--    missions_declarees). La colonne est prête, mais restera à 0 tant
--    qu'un tel système n'est pas construit séparément.
-- ═══════════════════════════════════════════════════════════════════════════
