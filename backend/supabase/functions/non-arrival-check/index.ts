// Non-Arrival Check (Cron) — Expected arrival monitoring (FR-042/043)
// Checks known_routes for overdue arrivals
// Triggers user check-in prompt, escalates to circle if no response

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve((_req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
