-- Ajout colonne caption sur provider_photos (si la table existe déjà sans cette colonne)
ALTER TABLE provider_photos ADD COLUMN IF NOT EXISTS caption TEXT;
