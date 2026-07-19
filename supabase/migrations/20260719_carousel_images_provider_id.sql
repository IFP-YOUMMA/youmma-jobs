-- ═══════════════════════════════════════════════════════════════════════════
-- CAROUSEL_IMAGES — photos "à la une" soumises par les prestataires
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration SÉPARÉE des précédentes (aucune modifiée rétroactivement) — à
-- exécuter manuellement dans l'éditeur SQL Supabase. Je ne l'exécute pas
-- moi-même.
--
-- ⚠️ ÉCART PAR RAPPORT À LA DEMANDE : la demande visait une table
-- "featured_images (image_url, titre, statut, provider_id, ordre,
-- created_at)". Cette table n'existe nulle part dans index.html (vérifié
-- par grep) — le vrai système "Images à la une" (panel admin, carrousel
-- page d'accueil) utilise déjà une table carousel_images avec les colonnes
-- id, url (pas image_url), titre, ordre, actif (BOOLEAN, pas de colonne
-- statut TEXT), created_at (voir _carouselShowSQL() dans index.html pour
-- le schéma exact déjà en place). Réutiliser cette table réelle plutôt que
-- d'en créer une nouvelle en double évite deux systèmes de carrousel
-- parallèles. "Insertion directe statut='actif'" se traduit avec la
-- colonne actif déjà existante (actif:true), qui remplit exactement le
-- même rôle.
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

ALTER TABLE carousel_images
  ADD COLUMN IF NOT EXISTS provider_id UUID REFERENCES providers(id);

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. 1 colonne ajoutée à carousel_images via ADD COLUMN IF NOT EXISTS
--    (idempotent, sans danger si déjà présente) : provider_id UUID,
--    nullable, référence providers(id). Les images déjà ajoutées par
--    l'admin (formulaire "Ajouter une image" existant, inchangé) gardent
--    provider_id = NULL : elles continuent de s'afficher exactement comme
--    avant, aucune régression sur le carrousel existant.
-- B. Aucune colonne "statut" ajoutée — la colonne actif (BOOLEAN, déjà
--    utilisée par _carouselToggleActif()/_carouselRenderAdmin() etc.)
--    remplit déjà ce rôle ; le code JS (_dashAjouterUne côté prestataire,
--    _admin*) écrit actif:true à la création, exactement l'équivalent de
--    "statut='actif' sans validation" demandé.
-- C. Grâce à cette FK, PostgREST permet la sélection embarquée
--    .select('*, providers(prenom,nom)') utilisée par
--    _carouselLoadProvAdmin() côté admin, sans jointure manuelle.
-- D. Aucune colonne, table, contrainte ou trigger existant modifié — le
--    formulaire admin "Ajouter une image" et le carrousel public
--    (#expInit, page d'accueil) continuent de fonctionner sans changement.
-- ═══════════════════════════════════════════════════════════════════════════
