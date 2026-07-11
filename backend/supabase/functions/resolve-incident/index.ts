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

  // Fetch incident
  const { data: incident } = await supabase
    .from('incidents')
    .select('id, user_id, status')
    .eq('id', incident_id)
    .single()

  if (!incident) {
    return new Response(JSON.stringify({ error: 'Incident not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (incident.status === 'resolved' || incident.status === 'cancelled') {
    return new Response(JSON.stringify({ error: 'Incident already resolved' }), {
      status: 409,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Authorization: victim or circle admin
  const isVictim = incident.user_id === userId
  let isCircleAdmin = false

  if (!isVictim) {
    // Check if user is admin of any circle containing the victim
    const { data: adminCheck } = await supabase.rpc('is_admin_of_shared_circle', {
      admin_uid: userId,
      member_uid: incident.user_id,
    })
    isCircleAdmin = adminCheck === true
  }

  if (!isVictim && !isCircleAdmin) {
    return new Response(JSON.stringify({ error: 'Not authorized to resolve' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const now = new Date().toISOString()

  // Resolve incident
  await supabase
    .from('incidents')
    .update({ status: 'resolved', resolved_at: now })
    .eq('id', incident_id)

  // Fetch resolver's name
  const { data: resolver } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single()

  // Broadcast resolution via Realtime
  const channel = supabase.channel(`incident:${incident_id}`)
  await channel.send({
    type: 'broadcast',
    event: 'resolved',
    payload: {
      resolved_by: resolver?.name ?? 'Someone',
      timestamp: now,
    },
  })

  return new Response(
    JSON.stringify({ status: 'resolved' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
