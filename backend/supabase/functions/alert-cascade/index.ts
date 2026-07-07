// Alert Cascade — Push -> SMS -> Voice call orchestration
// Receives: incident_id
// Dispatches alerts to all emergency contacts via FCM, MSG91, Exotel
// Tracks per-channel delivery status in incident_alerts table

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
