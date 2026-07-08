-- RoadPack v2: incidents + incident_alerts

CREATE TABLE incidents (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          TEXT REFERENCES users(id),
    type             VARCHAR(20) NOT NULL CHECK (type IN ('crash_detected','sos','inactivity','non_arrival','lost_contact')),
    severity         VARCHAR(10),
    confidence       REAL,
    location         GEOGRAPHY(POINT, 4326),
    speed_at_event   REAL,
    sensor_data      JSONB,
    status           VARCHAR(20) NOT NULL DEFAULT 'detected' CHECK (status IN ('detected','countdown','cancelled','dispatched','acknowledged','escalated','resolved')),
    cancelled_reason VARCHAR(50),
    media            JSONB,
    created_at       TIMESTAMPTZ DEFAULT now(),
    first_ack_at     TIMESTAMPTZ,
    resolved_at      TIMESTAMPTZ
);

CREATE INDEX idx_incidents_user ON incidents(user_id);
CREATE INDEX idx_incidents_status ON incidents(status) WHERE status NOT IN ('cancelled','resolved');

CREATE TABLE incident_alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id     UUID REFERENCES incidents(id) ON DELETE CASCADE,
    contact_id      UUID,
    channel         VARCHAR(10) NOT NULL CHECK (channel IN ('push','sms','call','whatsapp')),
    status          VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','delivered','read','failed')),
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    ack_method      VARCHAR(10),
    error           TEXT
);

CREATE INDEX idx_incident_alerts_incident ON incident_alerts(incident_id);

-- Helper: find emergency_contact IDs where this user is the linked app user
CREATE FUNCTION get_user_as_contact_ids(uid TEXT)
RETURNS SETOF UUID AS $$
  SELECT id FROM emergency_contacts WHERE app_user_id = uid
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Incidents RLS: own + circle members can view

ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY incidents_select ON incidents FOR SELECT
  USING (
    user_id = requesting_user_id()
    OR shares_circle_with(requesting_user_id(), user_id)
  );

CREATE POLICY incidents_insert ON incidents FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY incidents_update ON incidents FOR UPDATE
  USING (user_id = requesting_user_id());

-- No DELETE: incidents are permanent records

-- Incident Alerts RLS: user sees alerts for own incidents or where they are the contact

ALTER TABLE incident_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY incident_alerts_select ON incident_alerts FOR SELECT
  USING (
    incident_id IN (SELECT id FROM incidents WHERE user_id = requesting_user_id())
    OR contact_id IN (SELECT get_user_as_contact_ids(requesting_user_id()))
  );

-- INSERT/UPDATE/DELETE: service role only (Edge Functions manage alert lifecycle)
