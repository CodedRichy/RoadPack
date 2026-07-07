// SMS Webhook — MSG91 delivery receipts and acknowledgment callbacks
// Updates incident_alerts status (delivered/read/failed)
// Parses SMS reply "OK" as acknowledgment

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
