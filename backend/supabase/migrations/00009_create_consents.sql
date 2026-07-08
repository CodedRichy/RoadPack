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
