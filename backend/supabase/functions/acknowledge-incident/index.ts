import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Extract user_id from JWT
  const token = authHeader.slice(7)
  let userId: string
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    userId = payload.sub
    if (!userId) throw new Error('no sub claim')
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { incident_id } = await req.json()
  if (!incident_id) {
    return new Response(JSON.stringify({ error: 'Missing incident_id' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Find this user's contact IDs
  const { data: contacts } = await supabase
    .from('emergency_contacts')
    .select('id')
    .eq('app_user_id', userId)

  if (!contacts || contacts.length === 0) {
    return new Response(JSON.stringify({ error: 'Not a contact for this incident' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const contactIds = contacts.map((c: { id: string }) => c.id)
  const now = new Date().toISOString()

  // Update all matching incident_alerts rows
  const { error: updateError } = await supabase
    .from('incident_alerts')
    .update({ acknowledged_at: now, ack_method: 'app' })
    .eq('incident_id', incident_id)
    .in('contact_id', contactIds)
    .is('acknowledged_at', null)

  if (updateError) {
    return new Response(JSON.stringify({ error: 'Failed to acknowledge' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Set first_ack_at on incident if this is the first ack
  await supabase
    .from('incidents')
    .update({ first_ack_at: now })
    .eq('id', incident_id)
    .is('first_ack_at', null)

  // Fetch acknowledger's name for broadcast
  const { data: acker } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single()

  // Broadcast ack via Realtime
  const channel = supabase.channel(`incident:${incident_id}`)
  await channel.send({
    type: 'broadcast',
    event: 'ack',
    payload: {
      contact_name: acker?.name ?? 'Someone',
      method: 'app',
      timestamp: now,
    },
  })

  return new Response(
    JSON.stringify({ status: 'acknowledged' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
