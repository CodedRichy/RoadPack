import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyClerkJwt } from '../_shared/jwt.ts'

interface LocationRecord {
  timestamp: string
  coords: {
    latitude: number
    longitude: number
    speed: number | null
    heading: number | null
    accuracy: number | null
    altitude: number | null
  }
  activity?: { type: string }
  battery?: { level: number }
  is_heartbeat?: boolean
}

const JSON_HEADERS = { 'Content-Type': 'application/json' }

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: JSON_HEADERS,
    })
  }

  const token = authHeader.slice(7)
  let userId: string
  try {
    const { sub } = await verifyClerkJwt(token)
    userId = sub
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: JSON_HEADERS,
    })
  }

  let body: { location?: LocationRecord[] }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: JSON_HEADERS,
    })
  }

  const locations = body.location
  if (!locations || !Array.isArray(locations) || locations.length === 0) {
    return new Response(JSON.stringify({ error: 'No locations' }), {
      status: 422,
      headers: JSON_HEADERS,
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Filter out heartbeat-only entries (they only update device liveness)
  const gpsLocations = locations.filter((loc) => !loc.is_heartbeat)

  if (gpsLocations.length > 0) {
    const rows = gpsLocations.map((loc) => ({
      user_id: userId,
      point: `POINT(${loc.coords.longitude} ${loc.coords.latitude})`,
      speed: loc.coords.speed,
      heading: loc.coords.heading,
      accuracy: loc.coords.accuracy,
      altitude: loc.coords.altitude,
      battery_level:
        loc.battery?.level != null
          ? Math.round(loc.battery.level * 100)
          : null,
      activity: loc.activity?.type ?? null,
      source: 'gps',
      recorded_at: loc.timestamp,
      synced_at: new Date().toISOString(),
    }))

    const { error: insertError } = await supabase
      .from('location_history')
      .insert(rows)

    if (insertError) {
      console.error('location_history insert failed:', insertError.message)
      return new Response(JSON.stringify({ error: 'Insert failed' }), {
        status: 500,
        headers: JSON_HEADERS,
      })
    }
  }

  // Update device heartbeat
  const now = new Date().toISOString()
  const { data: existingDevice } = await supabase
    .from('devices')
    .select('id')
    .eq('user_id', userId)
    .order('last_heartbeat', { ascending: false, nullsFirst: false })
    .limit(1)
    .maybeSingle()

  if (existingDevice) {
    await supabase
      .from('devices')
      .update({ last_heartbeat: now })
      .eq('id', existingDevice.id)
  }

  return new Response(
    JSON.stringify({ status: 'ok', count: gpsLocations.length }),
    { headers: JSON_HEADERS },
  )
})
