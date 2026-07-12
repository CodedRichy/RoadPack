import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const JSON_HEADERS = { 'Content-Type': 'application/json' }

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  if (authHeader !== `Bearer ${serviceKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceKey,
  )

  const now = new Date()
  const currentDay = now.getDay() === 0 ? 7 : now.getDay()
  const currentMinutes = now.getHours() * 60 + now.getMinutes()

  const { data: routes, error: routesError } = await supabase
    .from('known_routes')
    .select(
      'id, user_id, name, destination, typical_start, typical_duration, days_active, non_arrival_enabled',
    )
    .eq('non_arrival_enabled', true)

  if (routesError || !routes) {
    console.error('Failed to fetch routes:', routesError?.message)
    return new Response(JSON.stringify({ status: 'error' }), {
      status: 500,
      headers: JSON_HEADERS,
    })
  }

  let checkedCount = 0
  let alertedCount = 0

  for (const route of routes) {
    const daysActive: number[] = route.days_active ?? []
    if (!daysActive.includes(currentDay)) continue

    if (!route.typical_start || !route.typical_duration) continue

    const [startH, startM] = route.typical_start.split(':').map(Number)
    const startMinutes = startH * 60 + startM

    const durationMatch = String(route.typical_duration).match(
      /(\d+):(\d+):(\d+)/,
    )
    let durationMinutes = 30
    if (durationMatch) {
      durationMinutes =
        parseInt(durationMatch[1]) * 60 + parseInt(durationMatch[2])
    }

    const { data: user } = await supabase
      .from('users')
      .select('non_arrival_delay_min, non_arrival_enabled')
      .eq('id', route.user_id)
      .single()

    if (!user || !user.non_arrival_enabled) continue

    const delayMin: number = user.non_arrival_delay_min ?? 15
    const expectedArrivalMin = startMinutes + durationMinutes + delayMin

    if (
      currentMinutes < expectedArrivalMin ||
      currentMinutes > expectedArrivalMin + 30
    )
      continue

    checkedCount++

    const dest = route.destination
    if (!dest) continue

    const thirtyMinAgo = new Date(
      now.getTime() - 30 * 60 * 1000,
    ).toISOString()
    const { data: nearDest } = await supabase.rpc('check_near_destination', {
      uid: route.user_id,
      dest_point: dest,
      radius_m: 500,
      since: thirtyMinAgo,
    })

    if (nearDest) continue

    const { data: activeIncident } = await supabase
      .from('incidents')
      .select('id')
      .eq('user_id', route.user_id)
      .eq('type', 'non_arrival')
      .not('status', 'in', '("cancelled","resolved")')
      .limit(1)
      .maybeSingle()

    if (activeIncident) continue

    const { data: incident, error: incidentError } = await supabase
      .from('incidents')
      .insert({
        user_id: route.user_id,
        type: 'non_arrival',
        location: dest,
        status: 'detected',
        sensor_data: { route_id: route.id, route_name: route.name },
      })
      .select('id')
      .single()

    if (incidentError || !incident) {
      console.error('Failed to create incident:', incidentError?.message)
      continue
    }

    await supabase.from('cascade_jobs').insert({
      incident_id: incident.id,
      delay_seconds: 300,
    })

    console.log(
      `[non-arrival] Check-in push queued for user ${route.user_id}, incident ${incident.id}`,
    )
    alertedCount++
  }

  return new Response(
    JSON.stringify({
      status: 'ok',
      checked: checkedCount,
      alerted: alertedCount,
    }),
    { headers: JSON_HEADERS },
  )
})
