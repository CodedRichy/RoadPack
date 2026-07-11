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

  // Delivery receipt: { provider_id, status, delivered_at }
  if (body.type === 'delivery_receipt') {
    const { provider_id, status } = body
    // Phase 1: mock providers don't store provider_id on alert rows,
    // so we can't correlate delivery receipts to specific alerts yet.
    // When real SMS providers are integrated, match by provider_id column.
    console.log(`[sms-webhook] Delivery receipt: ${provider_id} -> ${status}`)

    return new Response(JSON.stringify({ status: 'ok' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Inbound SMS reply: { sender_phone, message }
  if (body.type === 'inbound_sms') {
    const { sender_phone, message } = body
    const normalizedMessage = String(message ?? '').trim().toUpperCase()

    if (normalizedMessage !== 'OK') {
      return new Response(JSON.stringify({ status: 'ignored' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Find emergency contact by phone
    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', sender_phone)

    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ status: 'unknown_sender' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const contactIds = contacts.map((c: { id: string }) => c.id)
    const now = new Date().toISOString()

    // Find active incident_alerts for these contacts via SMS channel
    const { data: alerts } = await supabase
      .from('incident_alerts')
      .select('id, incident_id')
      .in('contact_id', contactIds)
      .eq('channel', 'sms')
      .is('acknowledged_at', null)

    if (!alerts || alerts.length === 0) {
      return new Response(JSON.stringify({ status: 'no_active_alerts' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Acknowledge all matching alerts
    const alertIds = alerts.map((a: { id: string }) => a.id)
    await supabase
      .from('incident_alerts')
      .update({ acknowledged_at: now, ack_method: 'sms' })
      .in('id', alertIds)

    // Set first_ack_at on each incident
    const incidentIds = [...new Set(alerts.map((a: { incident_id: string }) => a.incident_id))]
    for (const iid of incidentIds) {
      await supabase
        .from('incidents')
        .update({ first_ack_at: now })
        .eq('id', iid)
        .is('first_ack_at', null)
    }

    return new Response(JSON.stringify({ status: 'acknowledged', count: alertIds.length }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ status: 'unknown_type' }), {
    status: 400,
    headers: { 'Content-Type': 'application/json' },
  })
})
