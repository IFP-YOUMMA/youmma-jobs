-- Table des photos de prestataires (profil + réalisations)
CREATE TABLE IF NOT EXISTS provider_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id  UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  url          TEXT NOT NULL,
  type         TEXT NOT NULL DEFAULT 'realisation' CHECK (type IN ('profil','realisation')),
  caption      TEXT,
  ordre        INT  NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_provider_photos_provider_id ON provider_photos(provider_id);

-- RLS : prestataire lit/écrit ses propres photos ; service_role tout
ALTER TABLE provider_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "provider_photos_select_own"
  ON provider_photos FOR SELECT
  USING (true);

CREATE POLICY IF NOT EXISTS "provider_photos_insert_own"
  ON provider_photos FOR INSERT
  WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "provider_photos_delete_own"
  ON provider_photos FOR DELETE
  USING (true);
