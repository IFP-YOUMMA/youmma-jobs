-- ═══════════════════════════════════════════════════════════════════════════
-- YOUMMA GN — paramètres entreprise + numéro de facture stable par commande
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : ajout d'une facture imprimable pour chaque commande YOUMMA GN.
-- Cette migration (a) renseigne gn_parametres avec les coordonnées de
-- l'entreprise nécessaires à l'en-tête/pied de la facture, et (b) ajoute la
-- colonne gn_commandes.numero_facture pour que le numéro de facture reste
-- stable entre deux impressions de la même commande (généré une seule fois,
-- au premier clic sur « Facture », puis réutilisé).
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

alter table gn_commandes add column if not exists numero_facture text;

insert into gn_parametres (cle, valeur) values
  ('enseigne', 'YOUMMA GN'),
  ('raison_sociale', 'YOUMMA SARLU'),
  ('slogan', 'Votre marché en ligne'),
  ('adresse', 'Lambanyi, Conakry, Guinée'),
  ('telephone', '+224 620 53 82 90'),
  ('email', 'contact.youmma@gmail.com'),
  ('rccm', 'GN.TCC.2025.B.00304'),
  ('nif', '836306043'),
  ('pied_legal', 'YOUMMA SARLU · Siège social : Quartier Lambanyi, Commune de Ratoma, Conakry · RCCM : GN.TCC.2025.B.00304 · NIF : 836306043'),
  ('couleur_principale', '#2D2D6B'),
  ('couleur_accent', '#E85D04'),
  ('signataire_nom', 'Bah Mamadou'),
  ('signataire_titre', 'Directeur Général'),
  ('dernier_facture_numero_2026', '0'),
  ('logo_url', '')
on conflict (cle) do nothing;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. ALTER TABLE ... ADD COLUMN IF NOT EXISTS (idempotent) : gn_commandes
--    gagne une colonne numero_facture (text, nullable). Les commandes déjà
--    existantes gardent cette colonne à NULL — la facture leur générera un
--    numéro au premier clic, comme pour une commande neuve.
-- B. INSERT ... ON CONFLICT (cle) DO NOTHING sur gn_parametres : idempotent,
--    ne modifie jamais une valeur déjà présente (si l'un de ces paramètres
--    a déjà été personnalisé via la page Paramètres, il n'est pas écrasé).
-- C. 'logo_url' est inséré vide ('') — le logo réel sera envoyé plus tard
--    par l'utilisateur depuis la page Paramètres (upload vers le bucket
--    Storage gn-assets), pas codé en dur ici.
-- D. 'dernier_facture_numero_2026' initialisé à '0' : la première facture
--    générée sera donc FAC-GN-2026-0001. Si l'année change avant la
--    première facture, calculerProchainNumeroFactureGN() traite l'absence
--    de clé pour la nouvelle année comme 0 (aucune migration supplémentaire
--    n'est nécessaire au changement d'année).
-- E. Aucune table, contrainte ou donnée existante modifiée en dehors de cet
--    ajout — migration purement additive.
-- ═══════════════════════════════════════════════════════════════════════════
