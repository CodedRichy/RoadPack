import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Call status update: { provider_id, call_status, recipient_phone }
  if (body.type === 'call_status') {
    const { call_status, recipient_phone } = body
    console.log(`[voice-webhook] Call to ${recipient_phone}: ${call_status}`)

    // Map Exotel statuses to our statuses
    const statusMap: Record<string, string> = {
      answered: 'delivered',
      completed: 'delivered',
      busy: 'failed',
      'no-answer': 'failed',
      failed: 'failed',
    }

    const mappedStatus = statusMap[call_status] ?? 'failed'

    // Find active call alerts for this phone
    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', recipient_phone)

    if (contacts && contacts.length > 0) {
      const contactIds = contacts.map((c: { id: string }) => c.id)
      await supabase
        .from('incident_alerts')
        .update({
          status: mappedStatus,
          delivered_at: mappedStatus === 'delivered' ? new Date().toISOString() : null,
        })
        .in('contact_id', contactIds)
        .eq('channel', 'call')
        .eq('status', 'sent')
    }

    return new Response(JSON.stringify({ status: 'ok' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // IVR keypress: { recipient_phone, digit }
  if (body.type === 'ivr_keypress') {
    const { recipient_phone, digit } = body

    if (digit !== '1' && digit !== '2') {
      return new Response(JSON.stringify({ status: 'ignored' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', recipient_phone)

    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ status: 'unknown_caller' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const contactIds = contacts.map((c: { id: string }) => c.id)
    const now = new Date().toISOString()

    // Both digit 1 and 2 count as acknowledgment
    const { data: alerts } = await supabase
      .from('incident_alerts')
      .select('id, incident_id')
      .in('contact_id', contactIds)
      .eq('channel', 'call')
      .is('acknowledged_at', null)

    if (alerts && alerts.length > 0) {
      const alertIds = alerts.map((a: { id: string }) => a.id)
      await supabase
        .from('incident_alerts')
        .update({ acknowledged_at: now, ack_method: 'ivr' })
        .in('id', alertIds)

      const incidentIds = [...new Set(alerts.map((a: { incident_id: string }) => a.incident_id))]
      for (const iid of incidentIds) {
        await supabase
          .from('incidents')
          .update({ first_ack_at: now })
          .eq('id', iid)
          .is('first_ack_at', null)
      }
    }

    return new Response(JSON.stringify({ status: 'acknowledged', digit }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ status: 'unknown_type' }), {
    status: 400,
    headers: { 'Content-Type': 'application/json' },
  })
})
