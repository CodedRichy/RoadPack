import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface IncidentPacket {
  type: string
  lat: number
  lng: number
  speed: number | null
  heading: number | null
  ts: number
  battery: number | null
}

function validatePacket(body: unknown): { valid: boolean; error?: string; packet?: IncidentPacket } {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Missing body' }
  const p = body as Record<string, unknown>

  if (p.type !== 'sos') return { valid: false, error: 'type must be sos' }
  if (typeof p.lat !== 'number' || p.lat < -90 || p.lat > 90) return { valid: false, error: 'invalid lat' }
  if (typeof p.lng !== 'number' || p.lng < -180 || p.lng > 180) return { valid: false, error: 'invalid lng' }
  if (typeof p.ts !== 'number') return { valid: false, error: 'missing ts' }

  const ageMs = Date.now() - p.ts * 1000
  if (ageMs > 5 * 60 * 1000) return { valid: false, error: 'timestamp stale (>5 min)' }

  return {
    valid: true,
    packet: {
      type: p.type as string,
      lat: p.lat as number,
      lng: p.lng as number,
      speed: typeof p.speed === 'number' ? p.speed : null,
      heading: typeof p.heading === 'number' ? p.heading : null,
      ts: p.ts as number,
      battery: typeof p.battery === 'number' ? Math.min(100, Math.max(0, p.battery)) : null,
    },
  }
}

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

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Service client for writes that bypass RLS
  const serviceClient = createClient(supabaseUrl, serviceRoleKey)

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

  // Validate payload
  let body: unknown
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const validation = validatePacket(body)
  if (!validation.valid || !validation.packet) {
    return new Response(JSON.stringify({ error: validation.error }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const packet = validation.packet

  // Rate limit: max 3 active incidents
  const { count, error: countError } = await serviceClient
    .from('incidents')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .not('status', 'in', '("cancelled","resolved")')

  if (countError) {
    console.error('incidents count query failed:', countError.message)
    return new Response(JSON.stringify({ error: 'DB error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if ((count ?? 0) >= 3) {
    return new Response(JSON.stringify({ error: 'Too many active incidents' }), {
      status: 429,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Insert incident
  const { data: incident, error: insertError } = await serviceClient
    .from('incidents')
    .insert({
      user_id: userId,
      type: 'sos',
      location: `POINT(${packet.lng} ${packet.lat})`,
      speed_at_event: packet.speed,
      status: 'dispatched',
      sensor_data: { heading: packet.heading, battery: packet.battery },
    })
    .select('id')
    .single()

  if (insertError || !incident) {
    console.error('incident insert failed:', insertError?.message)
    return new Response(JSON.stringify({ error: 'Failed to create incident' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const incidentId = incident.id

  // Fetch emergency contacts
  const { data: contacts, error: contactsError } = await serviceClient
    .from('emergency_contacts')
    .select('*')
    .eq('user_id', userId)
    .eq('opted_out', false)
    .order('priority')

  if (contactsError) {
    console.error('contacts fetch failed:', contactsError.message)
    return new Response(JSON.stringify({ error: 'Failed to fetch contacts' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (!contacts || contacts.length === 0) {
    return new Response(
      JSON.stringify({ incident_id: incidentId, status: 'dispatched', warning: 'no_contacts' }),
      { status: 201, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // Fetch user profile
  const { data: profile } = await serviceClient
    .from('users')
    .select('name, phone')
    .eq('id', userId)
    .single()

  // Insert cascade_jobs row
  const { error: jobError } = await serviceClient.from('cascade_jobs').insert({ incident_id: incidentId })
  if (jobError) console.error('cascade_jobs insert failed:', incidentId, jobError.message)

  // Fire-and-forget: invoke alert-cascade
  const cascadeUrl = `${supabaseUrl}/functions/v1/alert-cascade`
  // @ts-ignore — EdgeRuntime is a Supabase-specific global
  EdgeRuntime.waitUntil(
    fetch(cascadeUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        incident_id: incidentId,
        contacts,
        user_profile: profile ?? { name: 'Unknown', phone: '' },
        location: { lat: packet.lat, lng: packet.lng },
      }),
    }).catch((err) => console.error('Failed to invoke alert-cascade:', err))
  )

  return new Response(
    JSON.stringify({ incident_id: incidentId, status: 'dispatched' }),
    { status: 201, headers: { 'Content-Type': 'application/json' } },
  )
})
