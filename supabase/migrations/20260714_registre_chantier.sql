-- ═══════════════════════════════════════════════════════════════════════════
-- REGISTRE CHANTIER — "Construire avec YOUMMA JOBS"
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER TEL QUEL.
-- Ce fichier n'a pas été appliqué à la base. Il est fourni pour relecture.
--
-- Lire d'abord le résumé des choix arbitraires et questions ouvertes tout en
-- bas du fichier (section "QUESTIONS OUVERTES") avant de valider.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 0. CONSTAT SUR L'EXISTANT (contexte pour comprendre les choix ci-dessous)
-- ─────────────────────────────────────────────────────────────────────────
-- - Aucune table "clients" n'existait dans le repo avant cette migration.
--   Les "clients" du système missions/devis actuel sont de simples champs
--   texte (client_nom, client_telephone) dans `missions`, pas des comptes
--   authentifiés — pas de conflit de nommage avec la table `clients` créée
--   ici.
-- - `providers` est LE modèle prestataire (métier, catégorie, essai_actif,
--   abonnement_actif/fin, statut, doc_cni, etc.). L'authentification de tout
--   le site est "maison" : téléphone + PIN hashé en SHA-256 côté client
--   (colonne password_hash), session stockée en localStorage + best-effort
--   dans `provider_sessions(provider_id, token)`. Il n'y a PAS de Supabase
--   Auth (pas de auth.uid()) — voir section RLS plus bas, c'est important.
-- - Un système d'OTP SMS générique existe déjà : table `verification_codes
--   (phone, code, expires_at, used, created_at)`. Réutilisé pour DEUX
--   usages dans ce fichier : (a) l'authentification de clients/
--   superviseurs/fournisseurs_materiaux (téléphone + code, PAS de mot de
--   passe/PIN pour ces 3 tables — contrairement à `providers` qui a un
--   vrai password_hash), et (b) la confirmation de signature de contrat.
-- - Décision validée : fournisseurs, superviseurs et clients sont chacun une
--   table dédiée, indépendante de `providers` (voir sections 2 à 4). Un
--   fournisseur du Registre Chantier a son propre couple abonnement_actif /
--   abonnement_fin (30 jours, renouvelable) — mécanisme analogue à celui de
--   `providers` mais désormais porté par sa propre table, pas partagé.


-- ─────────────────────────────────────────────────────────────────────────
-- 1. LEADS (haut de funnel, pas de compte)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS leads_construction (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  nom           TEXT NOT NULL,
  telephone     TEXT NOT NULL,
  pays          TEXT,
  nature_projet TEXT,
  description   TEXT,
  statut        TEXT NOT NULL DEFAULT 'nouveau'
                  CHECK (statut IN ('nouveau','contacte','qualifie','converti','perdu'))
);

CREATE INDEX IF NOT EXISTS idx_leads_construction_statut    ON leads_construction(statut);
CREATE INDEX IF NOT EXISTS idx_leads_construction_telephone ON leads_construction(telephone);


-- ─────────────────────────────────────────────────────────────────────────
-- 2. CLIENTS (comptes authentifiés, propriétaires d'un chantier)
-- ─────────────────────────────────────────────────────────────────────────
-- Renommée `clients_construction` → `clients` (décision validée). Auth par
-- OTP SMS (téléphone + code via la table `verification_codes` déjà en
-- place, jamais de mot de passe) — pas de colonne password_hash ici,
-- contrairement à `providers` qui utilise un vrai PIN/mot de passe.
-- `user_id` est un lien optionnel vers auth.users : ce site n'utilise pas
-- Supabase Auth comme mécanisme principal (OTP SMS partout), mais la
-- colonne reste disponible si un client venait à avoir un compte
-- Supabase Auth par un autre biais.

CREATE TABLE IF NOT EXISTS clients (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  lead_id       UUID REFERENCES leads_construction(id) ON DELETE SET NULL,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  nom           TEXT NOT NULL,
  prenom        TEXT,
  telephone     TEXT NOT NULL UNIQUE,
  email         TEXT,
  ville         TEXT,
  commune       TEXT,
  adresse       TEXT,
  statut        TEXT NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','suspendu'))
);

CREATE INDEX IF NOT EXISTS idx_clients_telephone ON clients(telephone);

-- fn_set_updated_at() est définie plus bas (section 5, réutilisée par
-- chantiers/contrats/rapport_final_chantier) — la table clients est créée
-- avant, donc ce trigger est rattaché juste après la définition de la
-- fonction pour respecter l'ordre de dépendance (voir plus bas, "Trigger
-- clients.updated_at").

-- Sessions, même pattern que provider_sessions (best-effort, non bloquant)
CREATE TABLE IF NOT EXISTS client_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id   UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  token       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_client_sessions_client_id ON client_sessions(client_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 3. SUPERVISEURS
-- ─────────────────────────────────────────────────────────────────────────
-- Table dédiée, confirmée. Un superviseur n'a ni métier/catégorie, ni
-- essai/abonnement, ni fiche publique dans l'annuaire — c'est un rôle
-- opérationnel interne au chantier, pas une offre de service. Il PEUT être
-- rattaché à un compte provider existant via `provider_id` (nullable) si la
-- même personne est aussi inscrite comme prestataire — purement informatif.
-- Auth par OTP SMS comme `clients` (téléphone + verification_codes), pas de
-- mot de passe : aucune colonne password_hash ici.

CREATE TABLE IF NOT EXISTS superviseurs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider_id   UUID REFERENCES providers(id) ON DELETE SET NULL,
  nom           TEXT NOT NULL,
  prenom        TEXT,
  telephone     TEXT NOT NULL UNIQUE,
  statut        TEXT NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','inactif'))
);

CREATE INDEX IF NOT EXISTS idx_superviseurs_telephone ON superviseurs(telephone);

CREATE TABLE IF NOT EXISTS superviseur_sessions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  superviseur_id UUID NOT NULL REFERENCES superviseurs(id) ON DELETE CASCADE,
  token          TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_superviseur_sessions_superviseur_id ON superviseur_sessions(superviseur_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 4. FOURNISSEURS DE MATÉRIAUX (table dédiée)
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️ CHANGEMENT DE CAP par rapport à la v1 de ce fichier : le brouillon
-- précédent faisait du "fournisseur" un `providers` existant + un flag
-- (fournisseur_materiaux_actif). Décision validée cette fois : table
-- dédiée `fournisseurs_materiaux`, complètement indépendante de `providers`.
-- Ce fichier ne contient donc plus l'ALTER TABLE providers / le flag — ils
-- sont remplacés par la table ci-dessous. Le fournisseur porte désormais
-- son propre abonnement_actif/abonnement_fin (30 jours, renouvelable),
-- indépendant de celui des prestataires. Auth par OTP SMS comme
-- clients/superviseurs (téléphone + verification_codes), pas de colonne
-- password_hash.

CREATE TABLE IF NOT EXISTS fournisseurs_materiaux (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  nom_entreprise    TEXT NOT NULL,
  telephone         TEXT NOT NULL UNIQUE,
  ville             TEXT,
  commune           TEXT,
  statut            TEXT NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','suspendu')),
  abonnement_actif  BOOLEAN NOT NULL DEFAULT false,
  abonnement_fin    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_fournisseurs_materiaux_telephone ON fournisseurs_materiaux(telephone);

CREATE TABLE IF NOT EXISTS fournisseur_materiaux_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fournisseur_id  UUID NOT NULL REFERENCES fournisseurs_materiaux(id) ON DELETE CASCADE,
  token           TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fournisseur_materiaux_sessions_fournisseur_id ON fournisseur_materiaux_sessions(fournisseur_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 5. CHANTIERS
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS chantiers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  client_id        UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
  superviseur_id   UUID REFERENCES superviseurs(id) ON DELETE SET NULL,
  fournisseur_id   UUID REFERENCES fournisseurs_materiaux(id) ON DELETE SET NULL,  -- un seul fournisseur généraliste par chantier (simple colonne, pas de table de jointure)
  nom              TEXT NOT NULL,
  ville            TEXT,
  commune          TEXT,
  quartier         TEXT,
  adresse          TEXT,
  description      TEXT,
  budget_estime    BIGINT,
  statut           TEXT NOT NULL DEFAULT 'en_etude' CHECK (statut IN ('en_etude','en_cours','termine')),
  date_debut       DATE,
  date_fin_prevue  DATE,
  date_fin_reelle  DATE
);

CREATE INDEX IF NOT EXISTS idx_chantiers_client_id      ON chantiers(client_id);
CREATE INDEX IF NOT EXISTS idx_chantiers_superviseur_id ON chantiers(superviseur_id);
CREATE INDEX IF NOT EXISTS idx_chantiers_fournisseur_id ON chantiers(fournisseur_id);
CREATE INDEX IF NOT EXISTS idx_chantiers_statut         ON chantiers(statut);

-- Un chantier ne peut être assigné qu'à un fournisseur au statut 'actif'.
-- Ne vérifie PAS l'abonnement ici — le blocage abonnement reste uniquement
-- sur la signature de contrat (section 8, décision validée).
CREATE OR REPLACE FUNCTION fn_verifier_fournisseur_actif()
RETURNS TRIGGER AS $$
DECLARE
  v_statut TEXT;
BEGIN
  IF NEW.fournisseur_id IS NOT NULL THEN
    SELECT statut INTO v_statut FROM fournisseurs_materiaux WHERE id = NEW.fournisseur_id;
    IF v_statut IS DISTINCT FROM 'actif' THEN
      RAISE EXCEPTION 'Le fournisseur % n''est pas actif', NEW.fournisseur_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chantiers_verifier_fournisseur
  BEFORE INSERT OR UPDATE OF fournisseur_id ON chantiers
  FOR EACH ROW EXECUTE FUNCTION fn_verifier_fournisseur_actif();

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chantiers_updated_at
  BEFORE UPDATE ON chantiers
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- Trigger clients.updated_at (colonne ajoutée section 2 ; rattaché ici car
-- fn_set_updated_at() n'existe qu'à partir de cette ligne).
CREATE TRIGGER trg_clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────
-- 6. COMPTES MATÉRIAUX (une ardoise par chantier)
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️ CHANGEMENT DE CAP : la v1 de ce fichier ne stockait jamais de solde
-- (toujours recalculé depuis registre_transactions). Décision validée
-- cette fois : `solde_gnf` devient une colonne maintenue en cache par le
-- trigger de la section 7, complétée par `solde_reserve` pour le mécanisme
-- de réservation des sorties demandées mais pas encore confirmées.
--   - solde_gnf     : solde confirmé (versements validés − sorties confirmées).
--   - solde_reserve : montant actuellement "gelé" par des sorties_demandee
--                     en attente de confirmation ou de rejet.
--   - solde disponible pour une NOUVELLE demande = solde_gnf − solde_reserve.
-- La fonction `solde_compte_materiaux_recalcule()` (section 7) reste
-- disponible pour recalculer indépendamment ce solde depuis le registre et
-- détecter une éventuelle divergence — c'est le "recalcul de contrôle" qui
-- servait d'alternative dans la v1.

CREATE TABLE IF NOT EXISTS comptes_materiaux (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  chantier_id    UUID NOT NULL UNIQUE REFERENCES chantiers(id) ON DELETE RESTRICT,
  fournisseur_id UUID NOT NULL REFERENCES fournisseurs_materiaux(id) ON DELETE RESTRICT,
  statut         TEXT NOT NULL DEFAULT 'ouvert' CHECK (statut IN ('ouvert','cloture')),
  closed_at      TIMESTAMPTZ,
  -- ⚠️ Ajout non explicitement demandé : CHECK (>= 0) défensif sur les deux
  -- colonnes de solde, pour qu'une erreur de logique applicative ne puisse
  -- jamais faire passer un compte en négatif silencieusement. Dis-moi si tu
  -- préfères les retirer.
  solde_gnf      BIGINT NOT NULL DEFAULT 0 CHECK (solde_gnf >= 0),
  solde_reserve  BIGINT NOT NULL DEFAULT 0 CHECK (solde_reserve >= 0)
);

CREATE INDEX IF NOT EXISTS idx_comptes_materiaux_fournisseur_id ON comptes_materiaux(fournisseur_id);

CREATE TRIGGER trg_comptes_materiaux_verifier_fournisseur
  BEFORE INSERT OR UPDATE OF fournisseur_id ON comptes_materiaux
  FOR EACH ROW EXECUTE FUNCTION fn_verifier_fournisseur_actif();


-- ─────────────────────────────────────────────────────────────────────────
-- 7. REGISTRE_TRANSACTIONS (cœur du système — append-only)
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️ Renommages effectués pour coller aux noms utilisés dans tes 10
-- décisions (le brouillon précédent utilisait `type` et `montant`) :
--   - colonne `type`    → `type_operation`
--   - colonne `montant` → `montant_gnf`

CREATE TABLE IF NOT EXISTS registre_transactions (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  chantier_id               UUID NOT NULL REFERENCES chantiers(id) ON DELETE RESTRICT,
  compte_id                 UUID NOT NULL REFERENCES comptes_materiaux(id) ON DELETE RESTRICT,
  type_operation            TEXT NOT NULL CHECK (type_operation IN (
                               'versement_declare',  -- client déclare montant+date
                               'versement_valide',   -- fournisseur confirme
                               'versement_rejete',   -- fournisseur refuse le versement déclaré
                               'sortie_demandee',    -- superviseur demande X unités d'un matériau
                               'sortie_confirmee',   -- fournisseur valide la sortie, montant déduit
                               'sortie_rejetee'      -- fournisseur refuse la sortie, réservation libérée
                             )),
  montant_gnf               BIGINT NOT NULL CHECK (montant_gnf > 0),
  materiau                  TEXT,     -- requis pour sortie_demandee / sortie_confirmee / sortie_rejetee
  quantite                  BIGINT,
  unite                     TEXT,
  description               TEXT,
  -- pointe versement_declare (pour versement_valide) ou sortie_demandee
  -- (pour sortie_confirmee / sortie_rejetee)
  reference_transaction_id  UUID REFERENCES registre_transactions(id) ON DELETE RESTRICT,

  -- Acteur qui a fait l'action : exactement une des 3 colonnes selon le
  -- type_operation. Modélisé en 3 FK nullables (plutôt qu'une paire
  -- générique acteur_type/acteur_id) pour garder une vraie contrainte de
  -- clé étrangère par rôle — Postgres ne permet pas une FK polymorphe propre.
  client_id                 UUID REFERENCES clients(id) ON DELETE RESTRICT,
  superviseur_id             UUID REFERENCES superviseurs(id) ON DELETE RESTRICT,
  fournisseur_id             UUID REFERENCES fournisseurs_materiaux(id) ON DELETE RESTRICT,

  CONSTRAINT chk_registre_acteur_coherent CHECK (
    (type_operation = 'versement_declare' AND client_id      IS NOT NULL AND superviseur_id IS NULL AND fournisseur_id IS NULL)
    OR (type_operation = 'versement_valide' AND fournisseur_id IS NOT NULL AND client_id      IS NULL AND superviseur_id IS NULL)
    -- Symétrique à versement_valide : c'est le fournisseur qui rejette un
    -- versement déclaré par le client (montant erroné, jamais reçu, etc.).
    OR (type_operation = 'versement_rejete' AND fournisseur_id IS NOT NULL AND client_id      IS NULL AND superviseur_id IS NULL)
    OR (type_operation = 'sortie_demandee'  AND superviseur_id IS NOT NULL AND client_id      IS NULL AND fournisseur_id IS NULL)
    OR (type_operation = 'sortie_confirmee' AND fournisseur_id IS NOT NULL AND client_id      IS NULL AND superviseur_id IS NULL)
    -- ⚠️ Ajout non explicitement demandé (toujours pas confirmé) : je
    -- considère que c'est le fournisseur qui rejette une sortie (symétrique
    -- à sortie_confirmee). Dis-moi si c'est plutôt le superviseur qui doit
    -- pouvoir annuler sa propre demande.
    OR (type_operation = 'sortie_rejetee'   AND fournisseur_id IS NOT NULL AND client_id      IS NULL AND superviseur_id IS NULL)
  ),
  CONSTRAINT chk_registre_sortie_materiau CHECK (
    type_operation NOT IN ('sortie_demandee','sortie_confirmee','sortie_rejetee')
    OR (materiau IS NOT NULL AND quantite IS NOT NULL AND unite IS NOT NULL)
  ),
  CONSTRAINT chk_registre_reference_requise CHECK (
    -- reference_transaction_id obligatoire pour toute ligne de validation
    -- ou de rejet : il faut toujours savoir QUELLE ligne de demande
    -- (versement_declare ou sortie_demandee) est traitée.
    type_operation NOT IN ('versement_valide','versement_rejete','sortie_confirmee','sortie_rejetee')
    OR reference_transaction_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_registre_transactions_chantier_id    ON registre_transactions(chantier_id);
CREATE INDEX IF NOT EXISTS idx_registre_transactions_compte_id      ON registre_transactions(compte_id);
CREATE INDEX IF NOT EXISTS idx_registre_transactions_type_operation ON registre_transactions(type_operation);
CREATE INDEX IF NOT EXISTS idx_registre_transactions_reference      ON registre_transactions(reference_transaction_id);

-- Append-only : aucune UPDATE ni DELETE, jamais, pour personne (y compris
-- via le rôle service_role côté back-office — si une correction est
-- nécessaire un jour, elle doit passer par une transaction inverse, pas par
-- une modification de l'historique).
CREATE OR REPLACE FUNCTION fn_registre_transactions_immuable()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'registre_transactions est en append-only : UPDATE/DELETE interdits (id=%)',
    COALESCE(OLD.id, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registre_transactions_no_update
  BEFORE UPDATE ON registre_transactions
  FOR EACH ROW EXECUTE FUNCTION fn_registre_transactions_immuable();

CREATE TRIGGER trg_registre_transactions_no_delete
  BEFORE DELETE ON registre_transactions
  FOR EACH ROW EXECUTE FUNCTION fn_registre_transactions_immuable();

-- Recalcul indépendant du solde confirmé à partir du registre (somme des
-- versements validés − somme des sorties confirmées). Sert désormais de
-- fonction de CONTRÔLE pour détecter une divergence avec la valeur mise en
-- cache dans comptes_materiaux.solde_gnf (qui est maintenue par le trigger
-- ci-dessous), plutôt que de source de vérité unique comme dans la v1.
CREATE OR REPLACE FUNCTION solde_compte_materiaux_recalcule(p_compte_id UUID)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(
    CASE
      WHEN type_operation = 'versement_valide'  THEN montant_gnf
      WHEN type_operation = 'sortie_confirmee'  THEN -montant_gnf
      ELSE 0
    END
  ), 0)
  FROM registre_transactions
  WHERE compte_id = p_compte_id;
$$ LANGUAGE sql STABLE;

-- Cœur de la mécanique du registre : tient à jour comptes_materiaux.solde_gnf
-- et .solde_reserve au fil des insertions, et bloque toute sortie_demandee
-- dont le montant dépasse le solde disponible (solde_gnf − solde_reserve).
--   - versement_declare → aucun effet (solde_gnf ne bouge QUE sur validation,
--                         jamais sur une simple ligne de demande/déclaration)
--   - versement_valide  → solde_gnf += montant_gnf
--   - versement_rejete  → aucun effet (le versement déclaré n'avait jamais
--                         été ajouté au solde, rien à retirer)
--   - sortie_demandee   → vérifie (solde_gnf − solde_reserve) >= montant_gnf,
--                         puis solde_reserve += montant_gnf
--   - sortie_confirmee  → solde_gnf -= montant_gnf ET solde_reserve -= montant_gnf
--   - sortie_rejetee    → solde_reserve -= montant_gnf (solde_gnf inchangé)
-- Le SELECT ... FOR UPDATE sur la branche sortie_demandee verrouille la
-- ligne comptes_materiaux le temps de la transaction : ça règle le problème
-- de la v1 où deux demandes simultanées pouvaient, ensemble, dépasser le
-- solde réel avant qu'aucune ne soit confirmée.
CREATE OR REPLACE FUNCTION fn_gerer_solde_registre()
RETURNS TRIGGER AS $$
DECLARE
  v_solde_gnf     BIGINT;
  v_solde_reserve BIGINT;
BEGIN
  IF NEW.type_operation = 'versement_valide' THEN
    UPDATE comptes_materiaux
      SET solde_gnf = solde_gnf + NEW.montant_gnf
      WHERE id = NEW.compte_id;

  ELSIF NEW.type_operation = 'sortie_demandee' THEN
    SELECT solde_gnf, solde_reserve INTO v_solde_gnf, v_solde_reserve
      FROM comptes_materiaux WHERE id = NEW.compte_id FOR UPDATE;

    IF (v_solde_gnf - v_solde_reserve) < NEW.montant_gnf THEN
      RAISE EXCEPTION 'Solde disponible insuffisant sur le compte % : disponible=%, montant demandé=%',
        NEW.compte_id, (v_solde_gnf - v_solde_reserve), NEW.montant_gnf;
    END IF;

    UPDATE comptes_materiaux
      SET solde_reserve = solde_reserve + NEW.montant_gnf
      WHERE id = NEW.compte_id;

  ELSIF NEW.type_operation = 'sortie_confirmee' THEN
    UPDATE comptes_materiaux
      SET solde_gnf     = solde_gnf - NEW.montant_gnf,
          solde_reserve = solde_reserve - NEW.montant_gnf
      WHERE id = NEW.compte_id;

  ELSIF NEW.type_operation = 'sortie_rejetee' THEN
    UPDATE comptes_materiaux
      SET solde_reserve = solde_reserve - NEW.montant_gnf
      WHERE id = NEW.compte_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registre_transactions_gerer_solde
  BEFORE INSERT ON registre_transactions
  FOR EACH ROW EXECUTE FUNCTION fn_gerer_solde_registre();


-- ─────────────────────────────────────────────────────────────────────────
-- 8. CONTRATS
-- ─────────────────────────────────────────────────────────────────────────
-- Une seule table pour les 2 types de contrat évoqués :
--   - type='materiaux'       : contrat client ↔ fournisseur (matériaux)
--   - type='forfait_service' : contrat client ↔ YOUMMA (Assistance/Suivi/Gestion)
-- Modélisés dans UNE table avec des colonnes conditionnelles (contrainte
-- CHECK ci-dessous) plutôt que 2 tables séparées, car ce sont deux
-- variantes du même concept "contrat rattaché à un chantier, avec un cycle
-- de signature identique". Les tranches de paiement du forfait_service
-- vivent dans une table enfant dédiée (section 9) puisqu'il peut y en avoir
-- plusieurs par contrat.
--
-- Signature v1 (pas de signature électronique réelle) :
--   bouton "J'accepte" + OTP SMS de confirmation, en réutilisant la table
--   `verification_codes` déjà en place (phone/code/expires_at/used) — pas
--   besoin d'une nouvelle table OTP. Le contrat garde juste la trace de
--   l'horodatage + un booléen "OTP vérifié" pour chaque partie.
--
-- Le blocage "abonnement expiré" reste ICI UNIQUEMENT (décision validée) :
-- il ne s'applique pas à registre_transactions (versement_valide /
-- sortie_confirmee), qui reste utilisable sur un chantier déjà en cours
-- même si l'abonnement du fournisseur a expiré depuis.

CREATE TABLE IF NOT EXISTS contrats (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  chantier_id                     UUID NOT NULL REFERENCES chantiers(id) ON DELETE RESTRICT,
  type                            TEXT NOT NULL CHECK (type IN ('materiaux','forfait_service')),
  statut                          TEXT NOT NULL DEFAULT 'brouillon'
                                     CHECK (statut IN ('brouillon','en_attente_signature','signe','annule')),
  contenu                         TEXT,             -- texte du contrat généré / conditions
  montant                         BIGINT,           -- montant contrat matériaux OU montant forfait
  formule_service                 TEXT CHECK (formule_service IN ('assistance','suivi','gestion')),
  fournisseur_id                  UUID REFERENCES fournisseurs_materiaux(id) ON DELETE RESTRICT,  -- requis si type='materiaux'

  -- Téléphone de chaque partie au moment de la signature (capture figée,
  -- volontairement distincte de clients.telephone / fournisseurs_materiaux.telephone
  -- qui peuvent changer après coup) : trace exactement quel numéro a reçu et
  -- validé le code OTP pour CE contrat, même si le numéro change plus tard
  -- dans le profil du client ou du fournisseur.
  contact_client                  TEXT,
  -- Code OTP en clair, présent UNIQUEMENT entre l'envoi et la validation :
  -- purgé (mis à NULL) automatiquement dès que signature_client_otp_verifie
  -- passe à true — voir trg_contrats_purger_code_sms plus bas. Jamais
  -- conservé en clair après usage.
  code_sms_client                 TEXT,
  signature_client_at             TIMESTAMPTZ,
  signature_client_otp_verifie    BOOLEAN NOT NULL DEFAULT false,
  -- "partie2" = fournisseur si type='materiaux', YOUMMA (staff/admin) si type='forfait_service'
  contact_partie2                 TEXT,
  code_sms_partie2                TEXT,  -- même purge automatique, voir trg_contrats_purger_code_sms
  signature_partie2_at            TIMESTAMPTZ,
  signature_partie2_otp_verifie   BOOLEAN NOT NULL DEFAULT false,

  CONSTRAINT chk_contrat_champs_par_type CHECK (
    (type = 'materiaux'       AND fournisseur_id IS NOT NULL AND formule_service IS NULL)
    OR
    (type = 'forfait_service' AND formule_service IS NOT NULL AND fournisseur_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_contrats_chantier_id    ON contrats(chantier_id);
CREATE INDEX IF NOT EXISTS idx_contrats_fournisseur_id ON contrats(fournisseur_id);
CREATE INDEX IF NOT EXISTS idx_contrats_statut         ON contrats(statut);

CREATE TRIGGER trg_contrats_updated_at
  BEFORE UPDATE ON contrats
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_contrats_verifier_fournisseur
  BEFORE INSERT OR UPDATE OF fournisseur_id ON contrats
  FOR EACH ROW EXECUTE FUNCTION fn_verifier_fournisseur_actif();

-- Purge du code SMS en clair dès validation : ne doit JAMAIS rester lisible
-- une fois utilisé. Se déclenche quand signature_client_otp_verifie ou
-- signature_partie2_otp_verifie passe de false à true, et met NULL le
-- code_sms_* correspondant via un UPDATE imbriqué sur la même ligne, dans
-- la même transaction que la validation (comportement par défaut des
-- triggers Postgres — pas besoin de transaction séparée).
-- Sécurité anti-boucle : l'UPDATE imbriqué déclenche à nouveau ce trigger,
-- mais lors de ce second passage OLD et NEW ont la même valeur pour les
-- deux booléens (rien n'a changé depuis le premier UPDATE), donc la clause
-- WHEN est fausse et la fonction ne s'exécute pas une seconde fois.
CREATE OR REPLACE FUNCTION fn_purger_code_sms_valide()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE contrats
    SET code_sms_client  = CASE WHEN NEW.signature_client_otp_verifie  AND NOT OLD.signature_client_otp_verifie  THEN NULL ELSE code_sms_client  END,
        code_sms_partie2 = CASE WHEN NEW.signature_partie2_otp_verifie AND NOT OLD.signature_partie2_otp_verifie THEN NULL ELSE code_sms_partie2 END
    WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_contrats_purger_code_sms
  AFTER UPDATE ON contrats
  FOR EACH ROW
  WHEN (
    (NEW.signature_client_otp_verifie  AND NOT OLD.signature_client_otp_verifie)
    OR (NEW.signature_partie2_otp_verifie AND NOT OLD.signature_partie2_otp_verifie)
  )
  EXECUTE FUNCTION fn_purger_code_sms_valide();

-- Règle : le fournisseur doit avoir un abonnement actif pour VALIDER
-- (signer) un contrat matériaux. Se déclenche uniquement au passage à
-- statut='signe' pour un contrat de type 'materiaux'. C'EST le seul
-- endroit du fichier où l'abonnement du fournisseur est vérifié.
CREATE OR REPLACE FUNCTION fn_verifier_abonnement_fournisseur_signature()
RETURNS TRIGGER AS $$
DECLARE
  v_abo_ok BOOLEAN;
BEGIN
  IF NEW.type = 'materiaux' AND NEW.statut = 'signe'
     AND (TG_OP = 'INSERT' OR OLD.statut IS DISTINCT FROM 'signe') THEN
    SELECT (abonnement_actif AND abonnement_fin > now()) INTO v_abo_ok
    FROM fournisseurs_materiaux WHERE id = NEW.fournisseur_id;
    IF v_abo_ok IS NOT TRUE THEN
      RAISE EXCEPTION 'Le fournisseur % n''a pas d''abonnement actif : contrat non signable', NEW.fournisseur_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_contrats_verifier_abonnement
  BEFORE INSERT OR UPDATE ON contrats
  FOR EACH ROW EXECUTE FUNCTION fn_verifier_abonnement_fournisseur_signature();


-- ─────────────────────────────────────────────────────────────────────────
-- 9. TRANCHES DE PAIEMENT DU FORFAIT SERVICE
-- ─────────────────────────────────────────────────────────────────────────
-- Ce flux client → YOUMMA est distinct du registre matériaux (client →
-- fournisseur), donc PAS mélangé dans registre_transactions qui est
-- spécifiquement l'ardoise matériaux d'un fournisseur donné.

CREATE TABLE IF NOT EXISTS forfait_service_tranches (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  contrat_id     UUID NOT NULL REFERENCES contrats(id) ON DELETE CASCADE,
  ordre          INT NOT NULL,
  montant        BIGINT NOT NULL CHECK (montant > 0),
  date_prevue    DATE,
  statut         TEXT NOT NULL DEFAULT 'a_payer' CHECK (statut IN ('a_payer','payee')),
  date_paiement  TIMESTAMPTZ,
  UNIQUE (contrat_id, ordre)
);

CREATE INDEX IF NOT EXISTS idx_forfait_service_tranches_contrat_id ON forfait_service_tranches(contrat_id);


-- ─────────────────────────────────────────────────────────────────────────
-- 10. FIN DE CHANTIER — facture finale consolidée
-- ─────────────────────────────────────────────────────────────────────────

-- Fonction : montant total facturé (matériaux sortis confirmés) pour 1 chantier
CREATE OR REPLACE FUNCTION facture_finale_chantier(p_chantier_id UUID)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(montant_gnf), 0)
  FROM registre_transactions
  WHERE chantier_id = p_chantier_id AND type_operation = 'sortie_confirmee';
$$ LANGUAGE sql STABLE;

-- Vue : facture finale de tous les chantiers, avec contexte
CREATE OR REPLACE VIEW v_facture_finale_chantier AS
SELECT
  c.id                                                                       AS chantier_id,
  c.nom                                                                      AS chantier_nom,
  c.statut                                                                   AS chantier_statut,
  c.client_id,
  c.fournisseur_id,
  COALESCE(SUM(rt.montant_gnf) FILTER (WHERE rt.type_operation = 'sortie_confirmee'), 0) AS total_materiaux_sortis_gnf,
  COUNT(rt.id)                 FILTER (WHERE rt.type_operation = 'sortie_confirmee')     AS nb_sorties_confirmees
FROM chantiers c
LEFT JOIN registre_transactions rt ON rt.chantier_id = c.id
GROUP BY c.id, c.nom, c.statut, c.client_id, c.fournisseur_id;


-- ═══════════════════════════════════════════════════════════════════════════
-- 11. RLS — PROPOSITION EN COMMENTAIRE, NON ACTIVÉE
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ IMPORTANT avant même de discuter des policies : ce site n'utilise PAS
-- Supabase Auth. Toutes les requêtes passent par la clé anon, avec une
-- authentification "maison" (téléphone+PIN, session en localStorage). Il
-- n'y a donc pas de auth.uid() exploitable côté Postgres. C'est déjà le cas
-- pour les tables existantes : la policy de provider_photos est littéralement
-- `USING (true)` — la sécurité réelle est faite côté application, pas par
-- RLS. Deux options pour le Registre Chantier (qui manipule de l'argent,
-- donc un enjeu plus élevé que des photos de profil) :
--
--   (a) Rester cohérent avec l'existant : RLS activée mais policies
--       permissives (USING (true)), contrôle d'accès entièrement côté
--       application. Simple, rapide, mais pas de vraie garantie DB.
--   (b) Adopter Supabase Auth pour ce module (clients/superviseurs/
--       fournisseurs se connectent via auth.users, JWT avec claims de
--       rôle), ce qui permettrait des policies RÉELLEMENT restrictives
--       (auth.uid() = client_id, etc.). Plus robuste vu que ça touche à
--       de l'argent, mais gros écart architectural avec le reste du site,
--       et nécessite un plan de migration/coexistence avec l'auth actuelle.
--
-- Toujours pas tranché (décision "RLS reste commentée" confirmée) — les
-- policies ci-dessous sont écrites dans l'esprit de l'option (b) pour
-- montrer l'intention d'accès, à adapter/simplifier selon l'option retenue.
-- RIEN n'est exécuté : ni ENABLE ROW LEVEL SECURITY, ni CREATE POLICY.
--
-- ALTER TABLE leads_construction ENABLE ROW LEVEL SECURITY;
--   -- Pas de lecture publique : seul le staff YOUMMA (admin) accède aux leads.
--   -- CREATE POLICY "leads_admin_all" ON leads_construction
--   --   FOR ALL USING (is_admin());  -- fonction/claim à définir
--
-- ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "client_lit_son_propre_compte" ON clients
--   --   FOR SELECT USING (id = auth.uid());
--   -- CREATE POLICY "admin_all_clients" ON clients
--   --   FOR ALL USING (is_admin());
--
-- ALTER TABLE superviseurs ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "superviseur_lit_son_propre_compte" ON superviseurs
--   --   FOR SELECT USING (id = auth.uid());
--   -- CREATE POLICY "admin_all_superviseurs" ON superviseurs
--   --   FOR ALL USING (is_admin());
--
-- ALTER TABLE fournisseurs_materiaux ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "fournisseur_lit_son_propre_compte" ON fournisseurs_materiaux
--   --   FOR SELECT USING (id = auth.uid());
--   -- CREATE POLICY "admin_all_fournisseurs_materiaux" ON fournisseurs_materiaux
--   --   FOR ALL USING (is_admin());
--
-- ALTER TABLE chantiers ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "client_voit_son_chantier" ON chantiers
--   --   FOR SELECT USING (client_id = auth.uid());
--   -- CREATE POLICY "superviseur_voit_ses_chantiers_assignes" ON chantiers
--   --   FOR SELECT USING (superviseur_id = auth.uid());
--   -- CREATE POLICY "fournisseur_voit_ses_chantiers_assignes" ON chantiers
--   --   FOR SELECT USING (fournisseur_id = auth.uid());
--   -- CREATE POLICY "admin_all_chantiers" ON chantiers
--   --   FOR ALL USING (is_admin());
--
-- ALTER TABLE comptes_materiaux ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "fournisseur_voit_ses_ardoises" ON comptes_materiaux
--   --   FOR SELECT USING (fournisseur_id = auth.uid());
--   -- CREATE POLICY "client_voit_ardoise_de_son_chantier" ON comptes_materiaux
--   --   FOR SELECT USING (chantier_id IN (SELECT id FROM chantiers WHERE client_id = auth.uid()));
--   -- CREATE POLICY "superviseur_voit_ardoise_de_ses_chantiers" ON comptes_materiaux
--   --   FOR SELECT USING (chantier_id IN (SELECT id FROM chantiers WHERE superviseur_id = auth.uid()));
--   -- CREATE POLICY "admin_all_comptes_materiaux" ON comptes_materiaux
--   --   FOR ALL USING (is_admin());
--
-- ALTER TABLE registre_transactions ENABLE ROW LEVEL SECURITY;
--   -- Lecture : mêmes règles que comptes_materiaux (client/superviseur/
--   -- fournisseur du chantier concerné + admin).
--   -- CREATE POLICY "lecture_transactions_parties_prenantes" ON registre_transactions
--   --   FOR SELECT USING (
--   --     fournisseur_id = auth.uid()
--   --     OR client_id = auth.uid()
--   --     OR superviseur_id = auth.uid()
--   --     OR chantier_id IN (SELECT id FROM chantiers
--   --                         WHERE client_id = auth.uid()
--   --                            OR superviseur_id = auth.uid()
--   --                            OR fournisseur_id = auth.uid())
--   --     OR is_admin()
--   --   );
--   -- Écriture : chaque rôle ne peut insérer QUE le type_operation qui lui
--   -- correspond, avec sa propre identité comme acteur (empêche un client
--   -- de créer une ligne "sortie_confirmee" par exemple).
--   -- CREATE POLICY "client_declare_versement" ON registre_transactions
--   --   FOR INSERT WITH CHECK (type_operation = 'versement_declare' AND client_id = auth.uid());
--   -- CREATE POLICY "fournisseur_valide_ou_traite_sortie" ON registre_transactions
--   --   FOR INSERT WITH CHECK (type_operation IN ('versement_valide','sortie_confirmee','sortie_rejetee') AND fournisseur_id = auth.uid());
--   -- CREATE POLICY "superviseur_demande_sortie" ON registre_transactions
--   --   FOR INSERT WITH CHECK (type_operation = 'sortie_demandee' AND superviseur_id = auth.uid());
--   -- (Pas de policy UPDATE/DELETE : les triggers d'immutabilité bloquent
--   --  déjà tout le monde, RLS n'a rien à faire ici.)
--
-- ALTER TABLE contrats ENABLE ROW LEVEL SECURITY;
--   -- CREATE POLICY "parties_prenantes_voient_contrat" ON contrats
--   --   FOR SELECT USING (
--   --     fournisseur_id = auth.uid()
--   --     OR chantier_id IN (SELECT id FROM chantiers
--   --                         WHERE client_id = auth.uid() OR superviseur_id = auth.uid())
--   --     OR is_admin()
--   --   );
--   -- CREATE POLICY "admin_all_contrats" ON contrats FOR ALL USING (is_admin());
--
-- ALTER TABLE forfait_service_tranches ENABLE ROW LEVEL SECURITY;
--   -- Mêmes ayants droit que le contrat parent.
--   -- CREATE POLICY "parties_prenantes_voient_tranches" ON forfait_service_tranches
--   --   FOR SELECT USING (
--   --     contrat_id IN (SELECT id FROM contrats WHERE chantier_id IN
--   --       (SELECT id FROM chantiers WHERE client_id = auth.uid() OR superviseur_id = auth.uid()))
--   --     OR is_admin()
--   --   );


-- ─────────────────────────────────────────────────────────────────────────
-- 12. RAPPORT FINAL DE CHANTIER
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠️ Demandé comme "à ajouter après le bloc rapports_journaliers" : ce bloc
-- n'existe PAS dans le fichier (aucune table de rapports journaliers n'a
-- jamais été créée ici — vérifié, aucune occurrence de "journalier" avant
-- cette section). Je l'ai donc inséré directement avant "QUESTIONS
-- OUVERTES", qui est la seule partie de la consigne de positionnement que
-- je pouvais honorer sans inventer une table qui n'a pas été demandée.
-- Dis-moi si une table de rapports journaliers doit aussi être créée.

-- 12.1 Rapport final — un seul par chantier, jamais supprimé. Les
-- statuts avancent en cascade (voir trigger de transition ci-dessous) ;
-- une fois 'valide_admin' ou 'litige_resolu' atteint, la ligne est
-- verrouillée par trg_block_rapport_final (point 3 de la demande).
CREATE TABLE IF NOT EXISTS rapport_final_chantier (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  chantier_id                     UUID NOT NULL UNIQUE REFERENCES chantiers(id) ON DELETE RESTRICT,

  statut                          TEXT NOT NULL DEFAULT 'genere' CHECK (statut IN (
                                     'genere',
                                     'valide_superviseur',
                                     'valide_fournisseur',
                                     'valide_client',
                                     'valide_admin',
                                     'litige',
                                     'litige_resolu'
                                   )),

  -- Période couverte par le rapport
  periode_debut                   DATE,
  periode_fin                     DATE,
  nombre_jours_travail             INT,

  -- Totaux consolidés matériaux, en valeur GNF
  total_sorti_gnf                 BIGINT NOT NULL DEFAULT 0,
  total_utilise_gnf               BIGINT NOT NULL DEFAULT 0,
  total_stock_gnf                 BIGINT NOT NULL DEFAULT 0,

  -- Bilan financier
  total_verse_gnf                 BIGINT NOT NULL DEFAULT 0,
  total_depense_gnf               BIGINT NOT NULL DEFAULT 0,
  solde_final_gnf                 BIGINT NOT NULL DEFAULT 0,

  -- Forfait YOUMMA (service), rapproché du contrat forfait_service du chantier
  forfait_montant_gnf             BIGINT NOT NULL DEFAULT 0,
  forfait_paye_gnf                BIGINT NOT NULL DEFAULT 0,
  forfait_restant_gnf             BIGINT GENERATED ALWAYS AS (forfait_montant_gnf - forfait_paye_gnf) STORED,

  -- Validation des 4 parties
  validation_superviseur_id       UUID REFERENCES superviseurs(id),
  validation_superviseur_at       TIMESTAMPTZ,
  validation_superviseur_note     TEXT,

  validation_fournisseur_id       UUID REFERENCES fournisseurs_materiaux(id),
  validation_fournisseur_at       TIMESTAMPTZ,
  validation_fournisseur_note     TEXT,

  validation_client_id            UUID REFERENCES clients(id),
  validation_client_at            TIMESTAMPTZ,
  validation_client_note          TEXT,

  -- ⚠️ Pas de FK sur validation_admin_id : aucune table `admins` n'existe
  -- dans ce repo (l'accès admin du site n'est pas géré par une table en
  -- base à ce jour). Colonne laissée en UUID libre — à relier plus tard si
  -- une vraie table d'administrateurs voit le jour.
  validation_admin_id             UUID,
  validation_admin_at             TIMESTAMPTZ,
  validation_admin_note           TEXT,

  -- Gestion litige — champs déduits du seul mot "gestion litige" de la
  -- demande, à ajuster si tu avais un modèle plus précis en tête.
  litige_motif                    TEXT,
  litige_ouvert_par               TEXT CHECK (litige_ouvert_par IN ('client','fournisseur','superviseur','admin')),
  litige_ouvert_at                TIMESTAMPTZ,
  litige_resolu_at                TIMESTAMPTZ,
  litige_resolution_note          TEXT
);

CREATE INDEX IF NOT EXISTS idx_rapport_final_chantier_statut ON rapport_final_chantier(statut);
-- ⚠️ Pas d'index séparé sur (chantier_id) : la contrainte UNIQUE ci-dessus
-- crée déjà automatiquement un index unique sur cette colonne — un
-- CREATE INDEX supplémentaire dessus serait un doublon inutile. Dis-moi si
-- tu voulais quand même un index nommé explicitement pour une raison
-- particulière.

CREATE TRIGGER trg_rapport_final_chantier_updated_at
  BEFORE UPDATE ON rapport_final_chantier
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- Cascade de statuts : n'autorise que les transitions décrites dans la
-- demande (genere → valide_superviseur → valide_fournisseur →
-- valide_client → valide_admin, plus le aiguillage vers litige/litige_resolu
-- depuis n'importe laquelle des 4 étapes normales). Une simple CHECK sur la
-- liste de valeurs ne suffisait pas à empêcher un saut direct
-- genere → valide_admin par exemple — d'où ce trigger, ajouté de moi-même
-- pour honorer le mot "cascade" de la demande.
CREATE OR REPLACE FUNCTION fn_verifier_transition_rapport_final()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NOT (
         (OLD.statut = 'genere'             AND NEW.statut IN ('valide_superviseur','litige'))
      OR (OLD.statut = 'valide_superviseur' AND NEW.statut IN ('valide_fournisseur','litige'))
      OR (OLD.statut = 'valide_fournisseur' AND NEW.statut IN ('valide_client','litige'))
      OR (OLD.statut = 'valide_client'      AND NEW.statut IN ('valide_admin','litige'))
      OR (OLD.statut = 'litige'             AND NEW.statut = 'litige_resolu')
    ) THEN
      RAISE EXCEPTION 'Transition de statut invalide sur rapport_final_chantier % : % → %',
        OLD.id, OLD.statut, NEW.statut;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rapport_final_verifier_transition
  BEFORE UPDATE ON rapport_final_chantier
  FOR EACH ROW EXECUTE FUNCTION fn_verifier_transition_rapport_final();

-- Point 3 de la demande : verrouillage total une fois un statut terminal
-- atteint ('valide_admin' ou 'litige_resolu'). Contrôle le statut AVANT la
-- modification (OLD.statut), donc bloque aussi bien une tentative de
-- changer encore le statut qu'une tentative de modifier n'importe quelle
-- autre colonne de la ligne une fois verrouillée.
CREATE OR REPLACE FUNCTION fn_bloquer_rapport_final_verrouille()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.statut IN ('valide_admin','litige_resolu') THEN
    RAISE EXCEPTION 'rapport_final_chantier % est verrouillé (statut %) : plus aucune modification possible',
      OLD.id, OLD.statut;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_rapport_final
  BEFORE UPDATE ON rapport_final_chantier
  FOR EACH ROW EXECUTE FUNCTION fn_bloquer_rapport_final_verrouille();

-- "Jamais supprimé" (comme pour registre_transactions) : DELETE totalement
-- bloqué, sans condition de statut. Pas nommé explicitement dans la
-- demande — ajouté par symétrie avec trg_registre_transactions_no_delete.
CREATE OR REPLACE FUNCTION fn_rapport_final_no_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'rapport_final_chantier ne peut jamais être supprimé (id=%)', OLD.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rapport_final_no_delete
  BEFORE DELETE ON rapport_final_chantier
  FOR EACH ROW EXECUTE FUNCTION fn_rapport_final_no_delete();


-- 12.2 Lignes du rapport final — cumul par matériau sur tout le chantier.
-- Contrairement à registre_transactions, ces lignes ne sont pas append-only
-- : ce sont des cumuls consolidés destinés à être recalculés/mis à jour
-- tant que le rapport parent n'est pas verrouillé. Pas de trigger de
-- blocage dédié ici (non demandé) — si le rapport parent est verrouillé,
-- ça n'empêche pas techniquement une modification directe d'une ligne ;
-- dis-moi si tu veux le même verrouillage en cascade sur cette table.
CREATE TABLE IF NOT EXISTS rapport_final_lignes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  rapport_final_id   UUID NOT NULL REFERENCES rapport_final_chantier(id) ON DELETE CASCADE,
  -- Dénormalisé volontairement (redondant avec rapport_final_id →
  -- rapport_final_chantier.chantier_id) : demandé explicitement dans la
  -- liste de colonnes, utile pour filtrer/indexer directement par chantier
  -- sans passer par une jointure.
  chantier_id        UUID NOT NULL REFERENCES chantiers(id) ON DELETE RESTRICT,
  materiau            TEXT NOT NULL,
  unite               TEXT NOT NULL,
  total_sorti         BIGINT NOT NULL DEFAULT 0,
  total_utilise       BIGINT NOT NULL DEFAULT 0,
  stock_final         BIGINT GENERATED ALWAYS AS (total_sorti - total_utilise) STORED,
  prix_unitaire_gnf   BIGINT,
  -- ⚠️ Pas GENERATED (seul stock_final l'était dans la demande) : le calcul
  -- exact (basé sur total_sorti ou total_utilise × prix_unitaire_gnf) n'est
  -- pas précisé, donc laissé en colonne libre plutôt que de deviner la
  -- formule dans une colonne générée.
  montant_total_gnf   BIGINT,

  -- Ajout non demandé : évite deux lignes pour le même matériau sur un
  -- même rapport.
  UNIQUE (rapport_final_id, materiau)
);

CREATE INDEX IF NOT EXISTS idx_rapport_final_lignes_rapport_final_id ON rapport_final_lignes(rapport_final_id);


-- 12.3 Vue facture finale — jointure complète pour affichage
CREATE OR REPLACE VIEW vue_facture_finale AS
SELECT
  rfc.id                          AS rapport_final_id,
  rfc.statut                      AS rapport_statut,
  rfc.periode_debut,
  rfc.periode_fin,
  rfc.nombre_jours_travail,

  ch.id                            AS chantier_id,
  ch.nom                           AS chantier_nom,
  ch.statut                        AS chantier_statut,
  ch.ville, ch.commune, ch.quartier, ch.adresse,

  cl.id                            AS client_id,
  cl.nom                           AS client_nom,
  cl.prenom                        AS client_prenom,
  cl.telephone                     AS client_telephone,

  fm.id                            AS fournisseur_id,
  fm.nom_entreprise                AS fournisseur_nom_entreprise,
  fm.telephone                     AS fournisseur_telephone,

  sv.id                            AS superviseur_id,
  sv.nom                           AS superviseur_nom,
  sv.prenom                        AS superviseur_prenom,

  -- Bilan matériaux
  rfc.total_sorti_gnf,
  rfc.total_utilise_gnf,
  rfc.total_stock_gnf,

  -- Bilan financier
  rfc.total_verse_gnf,
  rfc.total_depense_gnf,
  rfc.solde_final_gnf,

  -- Forfait YOUMMA
  rfc.forfait_montant_gnf,
  rfc.forfait_paye_gnf,
  rfc.forfait_restant_gnf,

  -- Dates + notes de validation des 4 parties
  rfc.validation_superviseur_at, rfc.validation_superviseur_note,
  rfc.validation_fournisseur_at, rfc.validation_fournisseur_note,
  rfc.validation_client_at,      rfc.validation_client_note,
  rfc.validation_admin_at,       rfc.validation_admin_note,

  rfc.litige_motif, rfc.litige_ouvert_par, rfc.litige_ouvert_at,
  rfc.litige_resolu_at, rfc.litige_resolution_note

FROM rapport_final_chantier rfc
JOIN chantiers ch                    ON ch.id = rfc.chantier_id
JOIN clients cl                      ON cl.id = ch.client_id
LEFT JOIN fournisseurs_materiaux fm  ON fm.id = ch.fournisseur_id
LEFT JOIN superviseurs sv            ON sv.id = ch.superviseur_id;
-- LEFT JOIN sur fournisseur/superviseur : chantiers.fournisseur_id et
-- .superviseur_id sont nullables (chantier en_etude pas encore assigné).
-- JOIN simple sur clients : chantiers.client_id est NOT NULL.


-- ═══════════════════════════════════════════════════════════════════════════
-- QUESTIONS OUVERTES / CHOIX ARBITRAIRES À VALIDER
-- ═══════════════════════════════════════════════════════════════════════════
-- Statut des 10 points de ta dernière demande : tous appliqués. Le détail
-- de ce qui a effectivement changé par rapport à la version précédente est
-- dans le résumé donné en dehors de ce fichier (chat). Points restant
-- ouverts ou ajoutés par moi lors de cette passe :
--
-- A. Point 1 ("fournisseurs_materiaux… déjà correct, ne pas changer") : ce
--    n'était PAS le cas dans le fichier précédent (qui utilisait
--    providers.fournisseur_materiaux_actif). J'ai créé la table dédiée
--    telle que décrite. Si "déjà correct" voulait dire autre chose, dis-le
--    moi.
--
-- B. Point 5 : `solde_gnf` et `montant_gnf` n'existaient pas non plus tels
--    quels (le solde n'était jamais stocké, et la colonne s'appelait
--    `montant`). J'ai ajouté `comptes_materiaux.solde_gnf`, renommé
--    `montant` → `montant_gnf`, et fait en sorte que solde_gnf soit
--    incrémenté sur versement_valide (sinon aucune sortie ne serait jamais
--    finançable) — ce dernier point n'était pas explicite dans ta demande,
--    à confirmer.
--
-- C. Point 6 : renommé `type` → `type_operation` (ta phrase "CHECK de
--    type_operation" suggérait ce nom). Confirme si tu voulais garder `type`
--    et juste ajouter la valeur 'sortie_rejetee'.
--
-- D. Acteur de 'sortie_rejetee' supposé être le fournisseur (symétrique à
--    sortie_confirmee) — à confirmer si c'est plutôt le superviseur qui doit
--    pouvoir retirer sa propre demande.
--
-- E. `reference_transaction_id` rendue obligatoire aussi pour
--    'sortie_rejetee' (nécessaire pour que le trigger sache quelle
--    réservation libérer côté audit/traçabilité, même si le calcul du
--    solde_reserve utilise directement montant_gnf de la ligne rejetée).
--
-- F. `quantite` (registre_transactions) est aussi passée en BIGINT suite au
--    "partout" de la décision 8 — ça rend les quantités de matériaux
--    strictement entières (plus de m³ ou kg fractionnaires). À confirmer
--    que c'est voulu.
--
-- G. `contrats.montant` et `forfait_service_tranches.montant` sont passés en
--    BIGINT mais PAS renommés en `montant_gnf` (seul le montant de
--    registre_transactions était explicitement visé par le renommage).
--    Dis-moi si tu veux le même suffixe partout pour la cohérence.
--
-- H. CHECK (>= 0) ajoutés sur comptes_materiaux.solde_gnf et .solde_reserve
--    (défensif, pas demandé explicitement).
--
-- I. `solde_compte_materiaux_recalcule()` (ex-`solde_compte_materiaux()`)
--    n'est plus la source de vérité mais une fonction de contrôle — aucun
--    job de réconciliation automatique n'est mis en place, juste la
--    fonction, à appeler manuellement ou depuis un futur écran admin.
--
-- J. RLS : toujours entièrement commentée, aucune décision prise sur
--    Supabase Auth (a) vs policies permissives (b) — cf. section 11.
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- CORRECTIONS DEMANDÉES (passe suivante) — 6 points vérifiés, statut ci-dessous
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. AJOUTÉ : 'versement_rejete' manquait dans type_operation (on avait
--    sortie_rejetee mais pas son équivalent côté versement) — ajouté avec
--    la même contrainte d'acteur (fournisseur) que versement_valide, et
--    reference_transaction_id désormais obligatoire pour ce type aussi.
--    Le registre reste 100% event-sourced : aucune colonne "statut" n'a
--    jamais existé sur registre_transactions, donc rien à changer côté
--    immutabilité (déjà garantie par les triggers no_update/no_delete).
--
-- 2. DÉJÀ PRÉSENT : le champ d'auto-référence existe sous le nom
--    `reference_transaction_id` (pas `transaction_liee_id`) — non renommé,
--    consigne étant de ne rien changer d'autre. Permet bien une requête du
--    type "sorties en attente depuis plus de X jours" :
--      SELECT sd.* FROM registre_transactions sd
--      WHERE sd.type_operation = 'sortie_demandee'
--        AND sd.created_at < now() - interval '3 days'
--        AND NOT EXISTS (
--          SELECT 1 FROM registre_transactions r
--          WHERE r.reference_transaction_id = sd.id
--        );
--
-- 3. DÉJÀ CORRECT : vérifié dans fn_gerer_solde_registre() ET dans
--    solde_compte_materiaux_recalcule() — les deux ne font varier/sommer
--    que versement_valide (+) et sortie_confirmee (−). Les lignes de
--    demande/déclaration (versement_declare, sortie_demandee) et les rejets
--    n'ont jamais d'effet sur solde_gnf. Commentaire du trigger complété
--    pour lister explicitement les 6 types et confirmer ce point par écrit.
--
-- 4. COMPLÉTÉ (passe suivante) : `contact_client` et `contact_partie2` (TEXT)
--    ajoutés sur contrats — le "moment d'acceptation" (signature_*_at) et
--    la vérification OTP (signature_*_otp_verifie) existaient déjà pour les
--    deux parties, seul le numéro de téléphone manquait (y compris pour le
--    client, pas seulement la partie 2).
--    Sur la question du code SMS en clair (laissée ouverte juste au-dessus) :
--    ajout de `code_sms_client`/`code_sms_partie2` + trigger
--    `trg_contrats_purger_code_sms` qui les met à NULL automatiquement dès
--    que le `*_otp_verifie` correspondant passe à true, dans la même
--    transaction. Le code ne reste donc en clair QUE le temps strictement
--    nécessaire à sa vérification, jamais après.
--
-- 5. NE S'APPLIQUE PAS À CE FICHIER : `montant_forfait_service` n'a jamais
--    été sur `chantiers` ici (c'était une particularité de l'autre brouillon
--    comparé au tour précédent) — chez nous il est déjà uniquement sur
--    `contrats.montant` pour type='forfait_service', donc déjà versionnable
--    par nature (une nouvelle ligne contrats = une renégociation). Rien à
--    déplacer.
--
-- 6. CONFIRMÉ INCHANGÉ : le modèle 3 FK nullables (client_id/superviseur_id/
--    fournisseur_id) + CHECK "exactement une non-nulle" reste tel quel sur
--    registre_transactions, étendu au nouveau type versement_rejete selon
--    le même principe. Pas de colonne uuid générique sans FK introduite.
--
-- Statuts toujours en TEXT + CHECK (pas d'ENUM) et solde bloquant toujours
-- vérifié en trigger BEFORE INSERT : aucun des deux n'a été touché, comme
-- demandé.
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- DEMANDE "AJOUTER TABLE CLIENTS" — déjà présente, 4 points vérifiés
-- ═══════════════════════════════════════════════════════════════════════════
-- La demande décrivait une table `clients` et un `chantiers.client_id` à
-- créer/migrer — les deux existent déjà ici depuis plusieurs passes
-- (section 2 et section 5). Statut des 4 points :
--
-- 1. Table clients : déjà présente. Complétée avec les colonnes réellement
--    absentes et pertinentes : `email`, `adresse`, `updated_at` (+ trigger
--    trg_clients_updated_at, rattaché après la définition de
--    fn_set_updated_at() puisque clients est créée avant dans le fichier).
--    MISE À JOUR (passe suivante) : `user_id UUID REFERENCES auth.users(id)`
--    finalement ajouté (nullable) sur demande explicite — ce site n'utilise
--    toujours pas Supabase Auth comme mécanisme principal, mais la colonne
--    reste disponible en réserve. Voir aussi le retrait de password_hash
--    sur clients/superviseurs/fournisseurs_materiaux plus bas (auth par OTP
--    SMS pour ces 3 tables, pas par mot de passe).
--
-- 2. chantiers.client_id : déjà `UUID NOT NULL REFERENCES clients(id)`
--    depuis sa création — il n'y a jamais eu client_telephone/
--    client_user_id sur chantiers dans CE fichier (particularité de
--    l'autre brouillon comparé precédemment). Rien à migrer.
--
-- 3. contrats : PAS changé. `contact_client` (ajouté il y a 2 passes) est
--    délibérément un instantané du téléphone AU MOMENT de la signature,
--    distinct de clients.telephone qui peut changer après coup — le
--    transformer en FK vers clients(id) ferait perdre cette traçabilité
--    figée (une FK résoudrait toujours le téléphone ACTUEL via jointure).
--    Le lien de propriété client↔contrat existe déjà, via
--    contrats.chantier_id → chantiers.client_id.
--
-- 4. RLS : `clients` est déjà dans la liste commentée (section 11), avec
--    policies déjà rédigées. Rien à ajouter.
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- CORRECTIF AUTH — retrait password_hash, ajout clients.user_id
-- ═══════════════════════════════════════════════════════════════════════════
-- Erreur de conception identifiée et corrigée : clients, superviseurs et
-- fournisseurs_materiaux avaient chacun un `password_hash TEXT NOT NULL`,
-- calqué par erreur sur le pattern de `providers` (qui, lui, utilise
-- vraiment un PIN/mot de passe hashé). ⚠️ Ce projet authentifie ces 3
-- rôles par OTP SMS (téléphone + code via `verification_codes`, déjà
-- réutilisée par ailleurs dans ce fichier pour la signature de contrat),
-- jamais par mot de passe. Colonne `password_hash` retirée des 3 tables ;
-- aucune colonne de remplacement n'est nécessaire côté schéma puisque
-- `verification_codes` est générique (clé = numéro de téléphone, pas
-- besoin d'une colonne dédiée sur chaque table de rôle).
--
-- `clients.user_id UUID REFERENCES auth.users(id)` (nullable) ajouté sur
-- demande explicite — annule le refus argumenté dans la section
-- précédente ("PAS ajouté"). Toujours pas de Supabase Auth comme
-- mécanisme principal sur ce site, mais la colonne existe désormais en
-- réserve pour `clients` spécifiquement (pas étendue à superviseurs/
-- fournisseurs_materiaux, non demandé).
--
-- Confirmé inchangés à cette passe : les 3 FK nullables + CHECK "exactement
-- une non-nulle" sur registre_transactions (chk_registre_acteur_coherent),
-- et le trigger trg_contrats_purger_code_sms (purge du code SMS en clair
-- dès validation OTP, sur contrats — sans rapport avec l'auth des 3 tables
-- ci-dessus, portée volontairement distincte).
-- ═══════════════════════════════════════════════════════════════════════════
