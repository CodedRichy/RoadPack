-- RoadPack v2: emergency_contacts

CREATE TABLE emergency_contacts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      TEXT REFERENCES users(id) ON DELETE CASCADE,
    name         VARCHAR(100) NOT NULL,
    phone        VARCHAR(15) NOT NULL,
    relationship VARCHAR(30),
    priority     INT NOT NULL,
    alert_method VARCHAR(20)[] DEFAULT '{push,sms,call}',
    notified_at  TIMESTAMPTZ,
    opted_out    BOOLEAN DEFAULT false,
    is_app_user  BOOLEAN DEFAULT false,
    app_user_id  TEXT REFERENCES users(id),
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_emergency_contacts_user ON emergency_contacts(user_id);

ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY emergency_contacts_select ON emergency_contacts FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_insert ON emergency_contacts FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_update ON emergency_contacts FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_delete ON emergency_contacts FOR DELETE
  USING (user_id = requesting_user_id());
