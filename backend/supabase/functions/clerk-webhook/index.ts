import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface WebhookEvent {
  type: string
  data: {
    id: string
    first_name?: string | null
    last_name?: string | null
    phone_numbers?: Array<{ phone_number: string }>
    email_addresses?: Array<{ email_address: string }>
  }
}

async function verifyWebhookSignature(
  payload: string,
  headers: Headers,
  secret: string,
): Promise<boolean> {
  const svixId = headers.get('svix-id')
  const svixTimestamp = headers.get('svix-timestamp')
  const svixSignature = headers.get('svix-signature')

  if (!svixId || !svixTimestamp || !svixSignature) return false

  const timestampNum = parseInt(svixTimestamp, 10)
  const now = Math.floor(Date.now() / 1000)
  if (Math.abs(now - timestampNum) > 300) return false

  const secretBytes = Uint8Array.from(
    atob(secret.startsWith('whsec_') ? secret.slice(6) : secret),
    (c) => c.charCodeAt(0),
  )

  const toSign = new TextEncoder().encode(`${svixId}.${svixTimestamp}.${payload}`)
  const key = await crypto.subtle.importKey(
    'raw',
    secretBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, toSign)
  const computedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))

  const expectedSignatures = svixSignature.split(' ')
  return expectedSignatures.some((sig) => {
    const sigValue = sig.startsWith('v1,') ? sig.slice(3) : sig
    return sigValue === computedSig
  })
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const webhookSecret = Deno.env.get('CLERK_WEBHOOK_SECRET')
  if (!webhookSecret) {
    return new Response('Webhook secret not configured', { status: 500 })
  }

  const payload = await req.text()
  const isValid = await verifyWebhookSignature(payload, req.headers, webhookSecret)
  if (!isValid) {
    return new Response('Invalid signature', { status: 401 })
  }

  const event: WebhookEvent = JSON.parse(payload)

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const userId = event.data.id
  const phone = event.data.phone_numbers?.[0]?.phone_number ?? ''
  const firstName = event.data.first_name ?? ''
  const lastName = event.data.last_name ?? ''
  const name = [firstName, lastName].filter(Boolean).join(' ') || phone || 'User'

  if (event.type === 'user.created') {
    const { error } = await supabase.from('users').insert({
      id: userId,
      phone,
      name,
    })

    if (error) {
      console.error('Insert failed:', error.message)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  } else if (event.type === 'user.updated') {
    const { error } = await supabase
      .from('users')
      .update({ phone, name })
      .eq('id', userId)

    if (error) {
      console.error('Update failed:', error.message)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  } else {
    return new Response(JSON.stringify({ status: 'ignored', type: event.type }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(
    JSON.stringify({ status: 'ok' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
