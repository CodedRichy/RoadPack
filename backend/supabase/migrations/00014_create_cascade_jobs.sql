-- RoadPack v2: cascade job tracking + pg_cron escalation schedule

-- Enable pg_cron and pg_net extensions (idempotent)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE TABLE cascade_jobs (
    incident_id  UUID PRIMARY KEY REFERENCES incidents(id) ON DELETE CASCADE,
    started_at   TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    retry_count  INT DEFAULT 0
);

ALTER TABLE cascade_jobs ENABLE ROW LEVEL SECURITY;
-- No client-facing policies. Service role only.

-- pg_cron job: invoke escalation-check Edge Function every minute
SELECT cron.schedule(
  'escalation-check',
  '* * * * *',
  $$SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/escalation-check',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'Content-Type', 'application/json'
    )
  )$$
);
