-- RoadPack v2: audit_log + generic trigger function + trigger attachments

CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor_id    TEXT,
    subject_id  TEXT,
    action      VARCHAR(50) NOT NULL,
    detail      JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_subject ON audit_log(subject_id);

-- Generic audit trigger: logs old/new row state with action name from TG_ARGV[0]
CREATE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (actor_id, subject_id, action, detail)
    VALUES (
        requesting_user_id(),
        COALESCE(NEW.user_id, OLD.user_id),
        TG_ARGV[0],
        jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Attach audit triggers to security-sensitive tables

CREATE TRIGGER audit_circle_members_insert
  AFTER INSERT ON circle_members
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('circle_member_added');

CREATE TRIGGER audit_circle_members_delete
  AFTER DELETE ON circle_members
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('circle_member_removed');

CREATE TRIGGER audit_consents_insert
  AFTER INSERT ON consents
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('consent_granted');

CREATE TRIGGER audit_consents_update
  AFTER UPDATE ON consents
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('consent_updated');

-- Audit log RLS: users see only events where they are the actor

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_log_select ON audit_log FOR SELECT
  USING (actor_id = requesting_user_id());

-- INSERT: via SECURITY DEFINER trigger only; no direct user inserts
-- No UPDATE or DELETE: audit trail is immutable
