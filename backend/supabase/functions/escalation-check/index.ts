import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)
  const results = { escalated: 0, retried: 0, finalized: 0 }

  // 1. Cascade retry: dispatched incidents with no alert rows after 60s
  const sixtySecondsAgo = new Date(Date.now() - 60_000).toISOString()
  const { data: stuckIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'dispatched')
    .lt('created_at', sixtySecondsAgo)

  if (stuckIncidents) {
    for (const incident of stuckIncidents) {
      // Check if any alerts exist
      const { count } = await supabase
        .from('incident_alerts')
        .select('id', { count: 'exact', head: true })
        .eq('incident_id', incident.id)

      if ((count ?? 0) === 0) {
        // Check retry count
        const { data: job } = await supabase
          .from('cascade_jobs')
          .select('retry_count')
          .eq('incident_id', incident.id)
          .single()

        const retryCount = job?.retry_count ?? 0
        if (retryCount >= 3) {
          // Give up
          await supabase
            .from('incidents')
            .update({ status: 'cancelled', cancelled_reason: 'cascade_failed' })
            .eq('id', incident.id)
          continue
        }

        // Retry: fetch contacts and re-invoke cascade
        const { data: contacts } = await supabase
          .from('emergency_contacts')
          .select('*')
          .eq('user_id', incident.user_id)
          .eq('opted_out', false)
          .order('priority')

        const { data: profile } = await supabase
          .from('users')
          .select('name, phone')
          .eq('id', incident.user_id)
          .single()

        if (contacts && contacts.length > 0) {
          // Increment retry count
          await supabase
            .from('cascade_jobs')
            .update({ retry_count: retryCount + 1 })
            .eq('incident_id', incident.id)

          // Re-invoke cascade
          fetch(`${supabaseUrl}/functions/v1/alert-cascade`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              incident_id: incident.id,
              contacts,
              user_profile: profile ?? { name: 'Unknown', phone: '' },
              location: { lat: 0, lng: 0 },
            }),
          }).catch((err) => console.error('Retry cascade failed:', err))

          results.retried++
        }
      }
    }
  }

  // 2. Escalation: dispatched + no ack + >10 min
  const tenMinutesAgo = new Date(Date.now() - 10 * 60_000).toISOString()
  const { data: unackedIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'dispatched')
    .is('first_ack_at', null)
    .lt('created_at', tenMinutesAgo)

  if (unackedIncidents) {
    for (const incident of unackedIncidents) {
      // Update status to escalated
      await supabase
        .from('incidents')
        .update({ status: 'escalated' })
        .eq('id', incident.id)

      // Fetch contacts already alerted
      const { data: alertedContacts } = await supabase
        .from('incident_alerts')
        .select('contact_id')
        .eq('incident_id', incident.id)

      const alertedIds = new Set((alertedContacts ?? []).map((a: { contact_id: string }) => a.contact_id))

      // Fetch ALL emergency contacts (including lower-priority ones not yet alerted)
      const { data: allContacts } = await supabase
        .from('emergency_contacts')
        .select('*')
        .eq('user_id', incident.user_id)
        .eq('opted_out', false)
        .order('priority')

      const { data: profile } = await supabase
        .from('users')
        .select('name, phone')
        .eq('id', incident.user_id)
        .single()

      // Filter to un-alerted contacts
      const newContacts = (allContacts ?? []).filter(
        (c: { id: string }) => !alertedIds.has(c.id)
      )

      if (newContacts.length > 0) {
        fetch(`${supabaseUrl}/functions/v1/alert-cascade`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({
            incident_id: incident.id,
            contacts: newContacts,
            user_profile: profile ?? { name: 'Unknown', phone: '' },
            location: { lat: 0, lng: 0 },
          }),
        }).catch((err) => console.error('Escalation cascade failed:', err))
      }

      results.escalated++
    }
  }

  // 3. Final escalation: escalated + no ack + >20 min
  const twentyMinutesAgo = new Date(Date.now() - 20 * 60_000).toISOString()
  const { data: finalIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'escalated')
    .is('first_ack_at', null)
    .lt('created_at', twentyMinutesAgo)

  if (finalIncidents) {
    for (const incident of finalIncidents) {
      // Log final state — in production, push "Call 112 now" to all contacts
      console.log(`[escalation-check] FINAL: incident ${incident.id} — 20 min, no ack. Call 112.`)
      results.finalized++
    }
  }

  return new Response(
    JSON.stringify({ status: 'ok', ...results }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
