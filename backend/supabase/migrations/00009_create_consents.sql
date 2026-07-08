-- RoadPack v2: consent ledger (DPDPA 2023 compliance)

CREATE TABLE consents (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       TEXT REFERENCES users(id) ON DELETE CASCADE,
    consent_type  VARCHAR(40) NOT NULL CHECK (consent_type IN ('tracking','data_sharing_anon','sensor_upload','parental','institutional_circle','audio_capture')),
    granted_by    TEXT REFERENCES users(id),
    method        VARCHAR(20),
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at    TIMESTAMPTZ,
    version       VARCHAR(10)
);

CREATE INDEX idx_consents_user ON consents(user_id);

ALTER TABLE consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY consents_select ON consents FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY consents_insert ON consents FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

-- UPDATE: own rows only (for revoking via revoked_at)
CREATE POLICY consents_update ON consents FOR UPDATE
  USING (user_id = requesting_user_id());

-- No DELETE: consent history is permanent (audit trail)

-- Restrict updates to revoked_at only (consent audit trail integrity)
CREATE FUNCTION consents_restrict_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.consent_type != OLD.consent_type
     OR NEW.granted_by IS DISTINCT FROM OLD.granted_by
     OR NEW.method IS DISTINCT FROM OLD.method
     OR NEW.granted_at != OLD.granted_at
     OR NEW.version IS DISTINCT FROM OLD.version THEN
    RAISE EXCEPTION 'Only revoked_at may be updated on consent records';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER check_consent_update
  BEFORE UPDATE ON consents
  FOR EACH ROW EXECUTE FUNCTION consents_restrict_update();
