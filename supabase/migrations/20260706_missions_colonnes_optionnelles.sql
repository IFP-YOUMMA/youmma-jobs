-- Rendre facultatives les colonnes de l'ancien système missions
-- Ces colonnes ne sont pas utilisées par le nouveau système client/devis
ALTER TABLE missions ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE missions ALTER COLUMN prestataire_id DROP NOT NULL;
ALTER TABLE missions ALTER COLUMN localisation DROP NOT NULL;
ALTER TABLE missions ALTER COLUMN duree DROP NOT NULL;
ALTER TABLE missions ALTER COLUMN mode DROP NOT NULL;
