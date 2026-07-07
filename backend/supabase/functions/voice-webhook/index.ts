// Voice Webhook — Exotel TTS/IVR callbacks
// Captures IVR keypress acknowledgments
// Updates incident_alerts with ack_method: 'ivr'

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
