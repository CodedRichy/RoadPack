import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getChannel, buildAlertPayload } from '../_shared/channels.ts'

interface CascadeInput {
  incident_id: string
  contacts: Array<{
    id: string
    name: string
    phone: string
    is_app_user: boolean
    app_user_id: string | null
    alert_method: string[]
  }>
  user_profile: { name: string; phone: string }
  location: { lat: number; lng: number }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

serve(async (req) => {
  try {
    return await handleRequest(req)
  } catch (err) {
    console.error('alert-cascade: unhandled error', err)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: err instanceof Error ? err.message : String(err),
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})

async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const input: CascadeInput = await req.json()
  const { incident_id, contacts, user_profile, location } = input

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
  )

  async function isIncidentActive(): Promise<boolean> {
    const { data } = await supabase
      .from('incidents')
      .select('status')
      .eq('id', incident_id)
      .single()
    return data?.status === 'dispatched' || data?.status === 'escalated'
  }

  async function isContactAcknowledged(contactId: string): Promise<boolean> {
    const { data } = await supabase
      .from('incident_alerts')
      .select('acknowledged_at')
      .eq('incident_id', incident_id)
      .eq('contact_id', contactId)
      .not('acknowledged_at', 'is', null)
      .limit(1)
    return (data?.length ?? 0) > 0
  }

  async function sendChannel(
    channelType: 'push' | 'sms' | 'call',
    contactId: string,
    payload: ReturnType<typeof buildAlertPayload>,
  ): Promise<void> {
    // Insert queued row
    const { data: alertRow } = await supabase
      .from('incident_alerts')
      .insert({
        incident_id,
        contact_id: contactId,
        channel: channelType,
        status: 'queued',
      })
      .select('id')
      .single()

    if (!alertRow) return

    try {
      const channel = getChannel(channelType)
      const result = await channel.send(payload)

      await supabase
        .from('incident_alerts')
        .update({
          status: result.success ? 'sent' : 'failed',
          sent_at: new Date().toISOString(),
          error: result.error ?? null,
        })
        .eq('id', alertRow.id)
    } catch (err) {
      await supabase
        .from('incident_alerts')
        .update({
          status: 'failed',
          error: err instanceof Error ? err.message : String(err),
        })
        .eq('id', alertRow.id)
    }
  }

  // Process each contact sequentially by priority
  for (const contact of contacts) {
    if (!await isIncidentActive()) break

    const payload = buildAlertPayload(
      { name: contact.name, phone: contact.phone },
      user_profile,
      location,
      incident_id,
    )

    // Push (t=0s) — only if contact has the app
    if (contact.is_app_user && contact.app_user_id) {
      await sendChannel('push', contact.id, payload)
    }

    // SMS (t=+5s)
    await delay(5000)
    if (!await isIncidentActive()) break
    if (await isContactAcknowledged(contact.id)) continue
    await sendChannel('sms', contact.id, payload)

    // Voice (t=+30s from start, so +25s after SMS)
    await delay(25000)
    if (!await isIncidentActive()) break
    if (await isContactAcknowledged(contact.id)) continue
    await sendChannel('call', contact.id, payload)
  }

  // Mark cascade complete
  await supabase
    .from('cascade_jobs')
    .update({ completed_at: new Date().toISOString() })
    .eq('incident_id', incident_id)

  return new Response(
    JSON.stringify({ status: 'completed', incident_id }),
    { headers: { 'Content-Type': 'application/json' } },
  )
}
