import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5.9.6'

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null

export async function verifyClerkJwt(token: string): Promise<{ sub: string }> {
  const clerkIssuer = Deno.env.get('CLERK_ISSUER_URL')
  if (!clerkIssuer) throw new Error('CLERK_ISSUER_URL not configured')

  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`${clerkIssuer}/.well-known/jwks.json`))
  }

  const { payload } = await jwtVerify(token, jwks, {
    issuer: clerkIssuer,
  })

  const sub = payload.sub
  if (!sub) throw new Error('Missing sub claim in JWT')
  return { sub }
}
