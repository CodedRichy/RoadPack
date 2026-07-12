import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyClerkJwt } from '../_shared/jwt.ts'

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

  let body: { incident_id: string; response: string }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: JSON_HEADERS,
    })
  }

  const { incident_id, response } = body
  if (!incident_id || !response) {
    return new Response(
      JSON.stringify({ error: 'Missing incident_id or response' }),
      { status: 422, headers: JSON_HEADERS },
    )
  }

  const validResponses = ['fine', 'running_late', 'need_help']
  if (!validResponses.includes(response)) {
    return new Response(JSON.stringify({ error: 'Invalid response' }), {
      status: 422,
      headers: JSON_HEADERS,
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data: incident } = await supabase
    .from('incidents')
    .select('id, status, type')
    .eq('id', incident_id)
    .eq('user_id', userId)
    .single()

  if (!incident) {
    return new Response(JSON.stringify({ error: 'Incident not found' }), {
      status: 404,
      headers: JSON_HEADERS,
    })
  }

  if (incident.status === 'resolved' || incident.status === 'cancelled') {
    return new Response(
      JSON.stringify({ error: 'Incident already closed' }),
      { status: 409, headers: JSON_HEADERS },
    )
  }

  const now = new Date().toISOString()

  switch (response) {
    case 'fine': {
      await supabase
        .from('incidents')
        .update({
          status: 'cancelled',
          cancelled_reason: 'user_confirmed_fine',
          resolved_at: now,
        })
        .eq('id', incident_id)
      break
    }
    case 'running_late': {
      await supabase
        .from('incidents')
        .update({
          status: 'cancelled',
          cancelled_reason: 'user_running_late',
          resolved_at: now,
        })
        .eq('id', incident_id)
      break
    }
    case 'need_help': {
      await supabase
        .from('incidents')
        .update({ status: 'dispatched' })
        .eq('id', incident_id)

      const { data: contacts } = await supabase
        .from('emergency_contacts')
        .select('*')
        .eq('user_id', userId)
        .eq('opted_out', false)
        .order('priority')

      const { data: profile } = await supabase
        .from('users')
        .select('name, phone')
        .eq('id', userId)
        .single()

      if (contacts && contacts.length > 0) {
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const svcKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const cascadeUrl = `${supabaseUrl}/functions/v1/alert-cascade`

        await fetch(cascadeUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${svcKey}`,
          },
          body: JSON.stringify({
            incident_id,
            contacts,
            user_profile: profile ?? { name: 'Unknown', phone: '' },
            location: null,
          }),
        }).catch((err: Error) =>
          console.error('Cascade invoke failed:', err),
        )
      }
      break
    }
  }

  return new Response(JSON.stringify({ status: 'ok', response }), {
    headers: JSON_HEADERS,
  })
})
