const JSON_HEADERS = { 'Content-Type': 'application/json' }

export function verifyWebhookSecret(req: Request, envKey: string): Response | null {
  const expected = Deno.env.get(envKey)
  if (!expected) {
    console.error(`[webhook_auth] ${envKey} not configured`)
    return new Response(
      JSON.stringify({ error: 'Webhook secret not configured' }),
      { status: 500, headers: JSON_HEADERS },
    )
  }

  const provided = req.headers.get('X-Webhook-Secret')
  if (!provided || provided !== expected) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: JSON_HEADERS },
    )
  }

  return null
}
