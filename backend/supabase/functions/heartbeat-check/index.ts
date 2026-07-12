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

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, serviceKey)

  const now = new Date()
  const fifteenMinAgo = new Date(
    now.getTime() - 15 * 60 * 1000,
  ).toISOString()
  const currentDay = now.getDay() === 0 ? 7 : now.getDay()
  const currentMinutes = now.getHours() * 60 + now.getMinutes()

  const { data: staleDevices } = await supabase
    .from('devices')
    .select('user_id, last_heartbeat')
    .lt('last_heartbeat', fifteenMinAgo)
    .not('last_heartbeat', 'is', null)

  if (!staleDevices || staleDevices.length === 0) {
    return new Response(JSON.stringify({ status: 'ok', checked: 0 }), {
      headers: JSON_HEADERS,
    })
  }

  let alertedCount = 0

  for (const device of staleDevices) {
    const userId = device.user_id

    const { data: routes } = await supabase
      .from('known_routes')
      .select('id, typical_start, typical_duration, days_active')
      .eq('user_id', userId)

    if (!routes || routes.length === 0) continue

    const isCommuteTime = routes.some(
      (route: {
        typical_start: string | null
        typical_duration: string | null
        days_active: number[] | null
      }) => {
        if (!route.days_active?.includes(currentDay)) return false
        if (!route.typical_start) return false
        const [h, m] = route.typical_start.split(':').map(Number)
        const startMin = h * 60 + m
        const durationMatch = String(
          route.typical_duration ?? '00:30:00',
        ).match(/(\d+):(\d+)/)
        const durMin = durationMatch
          ? parseInt(durationMatch[1]) * 60 + parseInt(durationMatch[2])
          : 30
        return (
          currentMinutes >= startMin && currentMinutes <= startMin + durMin + 30
        )
      },
    )

    if (!isCommuteTime) continue

    const { data: existing } = await supabase
      .from('incidents')
      .select('id')
      .eq('user_id', userId)
      .eq('type', 'lost_contact')
      .not('status', 'in', '("cancelled","resolved")')
      .limit(1)
      .maybeSingle()

    if (existing) continue

    await supabase.from('incidents').insert({
      user_id: userId,
      type: 'lost_contact',
      status: 'detected',
      sensor_data: { last_heartbeat: device.last_heartbeat },
    })

    console.log(
      `[heartbeat-check] Lost contact: ${userId}, last heartbeat ${device.last_heartbeat}`,
    )
    alertedCount++
  }

  return new Response(
    JSON.stringify({
      status: 'ok',
      stale: staleDevices.length,
      alerted: alertedCount,
    }),
    { headers: JSON_HEADERS },
  )
})
