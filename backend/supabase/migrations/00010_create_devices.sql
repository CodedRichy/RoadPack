-- RoadPack v2: device registry (FCM tokens, OEM battery optimization tracking)

CREATE TABLE devices (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              TEXT REFERENCES users(id) ON DELETE CASCADE,
    fcm_token            TEXT,
    oem                  VARCHAR(30),
    os_version           VARCHAR(20),
    app_version          VARCHAR(20),
    battery_opt_disabled BOOLEAN DEFAULT false,
    last_heartbeat       TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_devices_user ON devices(user_id);
CREATE INDEX idx_devices_heartbeat ON devices(last_heartbeat) WHERE last_heartbeat IS NOT NULL;

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY devices_select ON devices FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY devices_insert ON devices FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY devices_update ON devices FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY devices_delete ON devices FOR DELETE
  USING (user_id = requesting_user_id());
