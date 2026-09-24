-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — connexion fournisseur (PIN, même modèle que gn_agents) +
-- demandes de retrait
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CHANGEMENT DE DIRECTION PAR RAPPORT AU BROUILLON PRÉCÉDENT (fichier
-- supprimé) : on abandonne Supabase Auth + RLS pour les fournisseurs. Le
-- fournisseur se connecte EXACTEMENT comme gérant/agent/livreur aujourd'hui
-- : téléphone + PIN à 4 chiffres, hashé en SHA-256 côté client (fonction
-- hashPin() déjà existante, réutilisée telle quelle), comparé au pin_hash
-- stocké en base, session gardée en sessionStorage. Même modèle de
-- confiance que gn_agents : RLS reste désactivée, n'importe qui possédant
-- la clé anon (publique) peut toujours interagir directement avec Supabase
-- en contournant l'application cliente — exactement comme c'est déjà le
-- cas aujourd'hui pour gérant/agent/livreur. Ce n'est plus un système
-- d'isolation appliqué par la base, seulement un contrôle d'accès côté
-- application, cohérent avec le reste de l'app.
--
-- CONTEXTE métier : donner à chaque fournisseur un accès en lecture à ses
-- produits en dépôt-vente (vendus / restants), son solde à recevoir, et lui
-- permettre de soumettre une demande de retrait que le gérant valide
-- (partiellement ou totalement) depuis la page Fournisseurs existante.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. gn_fournisseurs : PIN de connexion, même colonne/mécanisme que
--    gn_agents.pin_hash (SHA-256 calculé côté client par hashPin(), jamais
--    le PIN en clair envoyé ni stocké).
-- ───────────────────────────────────────────────────────────────────────────
-- Nullable : un fournisseur existant, créé avant cette migration, n'a pas
-- encore de PIN — il n'aura simplement pas accès au portail jusqu'à ce que
-- le gérant lui en définisse un (cf. section 4, même flux que "Réinitialiser
-- le PIN" déjà existant pour un agent).
ALTER TABLE gn_fournisseurs
  ADD COLUMN IF NOT EXISTS pin_hash text;

-- Recommandation additionnelle (pas explicitement demandée, à valider par
-- vous — supprimez ce bloc si vous préférez ne pas l'appliquer) : le login
-- existant fait un .eq('telephone', tel).maybeSingle() sur gn_agents, qui
-- suppose un téléphone unique (gn_agents.telephone est d'ailleurs "unique"
-- dans le schéma d'origine). gn_fournisseurs.telephone est aujourd'hui
-- optionnel et NON unique (le champ "Téléphone" du formulaire "Nouveau
-- fournisseur" n'est même pas obligatoire) : si deux fournisseurs partagent
-- ou omettent le même numéro, la recherche par téléphone au login devient
-- ambiguë. Cet index unique partiel (ignore les NULL) empêche seulement les
-- DOUBLONS futurs sur un numéro renseigné, sans toucher aux fournisseurs
-- existants qui n'en ont pas :
CREATE UNIQUE INDEX IF NOT EXISTS gn_fournisseurs_telephone_unique
  ON gn_fournisseurs (telephone)
  WHERE telephone IS NOT NULL;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. gn_fournisseur_retraits : demandes de retrait — conception inchangée
--    par rapport au brouillon précédent, indépendante du mécanisme d'auth.
-- ───────────────────────────────────────────────────────────────────────────
-- montant_verse : NULL tant que non traitée. Un retrait partiel (ex. 50 000
--   validés sur une demande de 100 000) passe DIRECTEMENT à 'validee' avec
--   montant_verse = 50 000 — la demande est close/soldée, pas "en attente
--   pour le reste". Si le fournisseur veut le solde restant, il soumettra
--   une NOUVELLE demande (le solde global reste calculé normalement, cf.
--   section 4, indépendamment des demandes déjà traitées).
-- caisse_id : lien vers l'écriture gn_caisse (sortie) créée quand le
--   paiement est validé.
-- Contrainte statut<->montant_verse : un retrait 'validee' DOIT avoir un
--   montant_verse renseigné ; un retrait 'en_attente' ou 'refusee' ne doit
--   PAS en avoir (NULL = "rien n'a été versé pour cette demande").
CREATE TABLE IF NOT EXISTS gn_fournisseur_retraits (
  id bigint generated always as identity primary key,
  fournisseur_id uuid not null references gn_fournisseurs(id),
  montant_demande numeric not null check (montant_demande > 0),
  montant_verse numeric check (montant_verse is null or montant_verse >= 0),
  statut text not null default 'en_attente' check (statut in ('en_attente','validee','refusee')),
  note text,
  note_traitement text,
  date_demande timestamptz not null default now(),
  date_traitement timestamptz,
  traite_par text,
  caisse_id bigint references gn_caisse(id),
  created_at timestamptz not null default now(),
  constraint gn_fournisseur_retraits_montant_verse_coherent
    check ((statut = 'validee') = (montant_verse is not null))
);

CREATE INDEX IF NOT EXISTS gn_fournisseur_retraits_fournisseur_idx
  ON gn_fournisseur_retraits (fournisseur_id, date_demande desc);

ALTER TABLE gn_fournisseur_retraits DISABLE ROW LEVEL SECURITY;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. gn_fournisseur_paiements : lien vers le retrait d'origine — inchangé
--    par rapport au brouillon précédent.
-- ───────────────────────────────────────────────────────────────────────────
-- Un retrait validé génère désormais UNE LIGNE DANS gn_fournisseur_paiements
-- (comme un paiement manuel classique fait depuis "Effectuer un paiement"
-- sur la page Fournisseurs), en plus de la ligne gn_caisse — pour apparaître
-- dans le même historique. retrait_id permet de retrouver, pour un paiement
-- donné, s'il provient d'une demande de retrait ou d'un versement manuel
-- classique (NULL dans ce second cas).
--
-- Ordre d'insertion recommandé pour l'application (à câbler à
-- l'implémentation, PAS codé ici), pour rester cohérent avec
-- enregistrerPaiementFournisseur() déjà existant (qui insère d'abord
-- gn_fournisseur_paiements, puis gn_caisse) :
--   1. INSERT INTO gn_fournisseur_paiements
--        (fournisseur_id, montant, note, agent_nom, retrait_id)
--      VALUES (f.id, montantVerse, 'Retrait validé — ' || f.nom, session.nom, retrait.id)
--      RETURNING id                                   -> paiementId
--   2. INSERT INTO gn_caisse
--        (date, libelle, type, montant, categorie, agent_nom)
--      VALUES (today(), 'Retrait fournisseur — ' || f.nom, 'sortie', montantVerse, 'fournisseur', session.nom)
--      RETURNING id                                   -> caisseId
--   3. UPDATE gn_fournisseur_retraits
--      SET statut = 'validee', montant_verse = montantVerse,
--          date_traitement = now(), traite_par = session.nom, caisse_id = caisseId
--      WHERE id = retrait.id
-- Les 3 étapes doivent être faites de façon cohérente côté application (dans
-- l'ordre, en gérant l'échec d'une étape intermédiaire) — point à traiter à
-- l'implémentation.
ALTER TABLE gn_fournisseur_paiements
  ADD COLUMN IF NOT EXISTS retrait_id bigint REFERENCES gn_fournisseur_retraits(id);

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Garde-fou de solde — contrainte d'INTÉGRITÉ APPLICATIVE, PAS un rempart
--    de sécurité.
-- ───────────────────────────────────────────────────────────────────────────
-- IMPORTANT : sans RLS (comme sur toutes les tables gn_*), ce trigger ne
-- protège PAS contre un utilisateur malveillant qui appellerait Supabase
-- directement avec la clé anon en contournant l'application — cette
-- personne pourrait tout aussi bien insérer n'importe quelle ligne
-- directement, ou modifier gn_fournisseur_retraits après coup, exactement
-- comme elle pourrait déjà le faire sur gn_agents, gn_caisse, etc. Le
-- garde-fou ci-dessous sert uniquement à éviter qu'un BUG applicatif (ex.
-- mauvais calcul de solde côté JS, appel concurrent, oubli de
-- vérification) laisse insérer une demande de retrait incohérente — un
-- filet de sécurité fonctionnel, pas une barrière contre une attaque
-- délibérée.
--
-- Solde disponible = total vendu au fournisseur (agrégé depuis
-- gn_commandes.lignes, même logique que la page Fournisseurs existante)
-- MOINS total déjà payé (gn_fournisseur_paiements — inclut les retraits
-- déjà validés, cf. section 3, donc une seule soustraction suffit, pas de
-- double décompte) MOINS les demandes déjà 'en_attente' pour ce même
-- fournisseur (les 'validee' ne sont pas à soustraire une seconde fois :
-- déjà comptées dans "payé").
CREATE OR REPLACE FUNCTION gn_fournisseur_ventes_totales(p_fournisseur_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(
    COALESCE((l->>'qte')::numeric, 0) * COALESCE((l->>'prix_fournisseur')::numeric, 0)
  ), 0)
  FROM gn_commandes c, jsonb_array_elements(c.lignes) AS l
  WHERE c.statut NOT IN ('annulee', 'echec')
    AND (l->>'fournisseur_id')::uuid = p_fournisseur_id;
$$;

CREATE OR REPLACE FUNCTION gn_fournisseur_solde_du(p_fournisseur_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT gn_fournisseur_ventes_totales(p_fournisseur_id)
    - COALESCE(
        (SELECT SUM(montant) FROM gn_fournisseur_paiements WHERE fournisseur_id = p_fournisseur_id),
        0
      );
$$;

CREATE OR REPLACE FUNCTION gn_fournisseur_retrait_verifier_solde()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_solde numeric;
  v_en_attente numeric;
  v_disponible numeric;
BEGIN
  v_solde := gn_fournisseur_solde_du(NEW.fournisseur_id);
  SELECT COALESCE(SUM(montant_demande), 0) INTO v_en_attente
    FROM gn_fournisseur_retraits
    WHERE fournisseur_id = NEW.fournisseur_id AND statut = 'en_attente';
  v_disponible := v_solde - v_en_attente;
  IF NEW.montant_demande > v_disponible THEN
    RAISE EXCEPTION 'Montant demandé (%) supérieur au solde disponible (%).', NEW.montant_demande, v_disponible;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS gn_fournisseur_retraits_verifier_solde ON gn_fournisseur_retraits;
CREATE TRIGGER gn_fournisseur_retraits_verifier_solde
  BEFORE INSERT ON gn_fournisseur_retraits
  FOR EACH ROW
  EXECUTE FUNCTION gn_fournisseur_retrait_verifier_solde();

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. gn_fournisseurs gagne pin_hash (text, nullable — même colonne/même
--    algorithme que gn_agents.pin_hash, calculé côté client par hashPin()
--    déjà existant). Aucune colonne existante modifiée. + un index unique
--    partiel sur telephone (ignore les NULL) : addition non demandée
--    explicitement mais recommandée pour que le login par téléphone reste
--    fiable — à supprimer du script si vous préférez ne pas l'appliquer.
-- B. Nouvelle table gn_fournisseur_retraits (RLS désactivée, comme le reste
--    des tables gn_*) : une demande = une ligne, statut
--    en_attente/validee/refusee, montant_verse renseigné seulement à la
--    validation (peut être < montant_demande pour un retrait partiel, qui
--    ferme directement la demande), caisse_id relie la demande à
--    l'écriture gn_caisse générée par le gérant lors du versement.
--    Contrainte CHECK garantissant que statut='validee' <=> montant_verse
--    renseigné.
-- C. gn_fournisseur_paiements gagne retrait_id (nullable) : un retrait
--    validé insère désormais une ligne ici (comme un paiement manuel
--    classique) en plus de la ligne gn_caisse — ordre exact documenté en
--    section 3, à câbler côté application à l'implémentation.
-- D. Garde-fou de solde (trigger BEFORE INSERT) : rejette une demande dont
--    le montant dépasse le solde disponible (vendu - payé - en attente).
--    Explicitement documenté comme une contrainte d'INTÉGRITÉ, pas un
--    rempart de SÉCURITÉ — RLS reste désactivée sur toutes les tables gn_*,
--    donc quiconque possède la clé anon peut toujours contourner
--    l'application cliente, exactement comme c'est déjà le cas aujourd'hui
--    pour gn_agents. Ce trigger protège seulement contre un bug applicatif.
-- E. PAS de RLS activée, PAS de table/colonne liée à auth.users, PAS de
--    fonction d'activation/claim — mécanisme d'authentification identique à
--    gn_agents (téléphone + PIN vérifié côté client, session en
--    sessionStorage).
-- F. Aucune donnée existante modifiée, aucune colonne supprimée — migration
--    purement additive, idempotente (IF NOT EXISTS / CREATE OR REPLACE /
--    DROP TRIGGER IF EXISTS partout où c'est possible).
-- ═══════════════════════════════════════════════════════════════════════════
