// emergency-contact-notice handler: FR-024 one-time notice.
// The invariant under test is "possibly late, never possibly twice".
//
//   deno test --allow-read --allow-env backend/supabase/tests/contact_notice_handler.test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  type ContactRow,
  type Deps,
  handleNotice,
} from '../functions/emergency-contact-notice/handler.ts'
import { type ChannelResult } from '../functions/_shared/channels.ts'

const OWNER = 'user_owner'
const CONTACT_ID = '11111111-1111-1111-1111-111111111111'
const CLAIMED_AT = '2026-09-08T10:00:00.000Z'

function contact(overrides: Partial<ContactRow> = {}): ContactRow {
  return {
    id: CONTACT_ID,
    user_id: OWNER,
    name: 'Ammu',
    phone: '+919876543210',
    opted_out: false,
    notified_at: CLAIMED_AT,
    ...overrides,
  }
}

interface Harness {
  deps: Deps
  sends: Array<{ phone: string; message: string; dlt: string }>
  releases: string[]
}

function harness(opts: {
  row?: ContactRow | null
  lookupThrows?: boolean
  sendResult?: ChannelResult
  sendThrows?: boolean
  releaseThrows?: boolean
  jwtSub?: string
  jwtThrows?: boolean
} = {}): Harness {
  const sends: Harness['sends'] = []
  const releases: string[] = []

  const deps: Deps = {
    store: {
      getContact(_id) {
        if (opts.lookupThrows) return Promise.reject(new Error('db down'))
        return Promise.resolve(opts.row === undefined ? contact() : opts.row)
      },
      releaseClaim(id) {
        if (opts.releaseThrows) return Promise.reject(new Error('release failed'))
        releases.push(id)
        return Promise.resolve()
      },
    },
    sender: {
      sendText(phone, message, dlt) {
        if (opts.sendThrows) return Promise.reject(new Error('carrier timeout'))
        sends.push({ phone, message, dlt })
        return Promise.resolve(
          opts.sendResult ?? { success: true, provider_id: 'sms_mock_1' },
        )
      },
    },
    verifyJwt(_token) {
      if (opts.jwtThrows) return Promise.reject(new Error('bad token'))
      return Promise.resolve({ sub: opts.jwtSub ?? OWNER })
    },
  }

  return { deps, sends, releases }
}

function request(body: unknown, auth = 'Bearer t', method = 'POST'): Request {
  return new Request('https://edge.test/emergency-contact-notice', {
    method,
    headers: auth ? { Authorization: auth } : {},
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  })
}

const VALID = { contact_id: CONTACT_ID, phone: '+919876543210', name: 'Ammu', listed_by: 'Rahul' }

Deno.test('rejects non-POST', async () => {
  const h = harness()
  assertEquals((await handleNotice(request(null, 'Bearer t', 'GET'), h.deps)).status, 405)
})

Deno.test('rejects missing and invalid tokens', async () => {
  assertEquals((await handleNotice(request(VALID, ''), harness().deps)).status, 401)
  assertEquals(
    (await handleNotice(request(VALID), harness({ jwtThrows: true }).deps)).status,
    401,
  )
})

Deno.test('rejects incomplete payloads', async () => {
  const h = harness()
  assertEquals((await handleNotice(request({ listed_by: 'R' }), h.deps)).status, 422)
  assertEquals(
    (await handleNotice(request({ contact_id: CONTACT_ID }), h.deps)).status,
    422,
  )
  assertEquals(h.sends.length, 0)
})

Deno.test('404 for an unknown contact, 503 when the lookup fails', async () => {
  assertEquals(
    (await handleNotice(request(VALID), harness({ row: null }).deps)).status,
    404,
  )
  assertEquals(
    (await handleNotice(request(VALID), harness({ lookupThrows: true }).deps)).status,
    503,
  )
})

Deno.test('only the owner can trigger a notice', async () => {
  const h = harness({ jwtSub: 'user_someone_else' })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 403)
  assertEquals(h.sends.length, 0)
  assertEquals(h.releases.length, 0)
})

Deno.test('sends when the claim is held', async () => {
  const h = harness()
  const res = await handleNotice(request({ ...VALID, lang: 'ml' }), h.deps)
  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.status, 'sent')
  assertEquals(body.lang, 'ml')
  assertEquals(body.encoding, 'UCS-2')
  assert(body.segments <= 2)
  assertEquals(h.sends.length, 1)
  assert(h.sends[0].message.includes('Rahul'))
  assert(h.sends[0].message.includes('STOP'))
  assertEquals(h.releases.length, 0)
})

Deno.test('the database phone wins over a client-supplied one', async () => {
  const h = harness()
  await handleNotice(request({ ...VALID, phone: '+910000000000' }), h.deps)
  assertEquals(h.sends[0].phone, '+919876543210')
})

Deno.test('opted-out contacts are skipped and the claim is kept', async () => {
  const h = harness({ row: contact({ opted_out: true }) })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 200)
  assertEquals((await res.json()).reason, 'opted_out')
  assertEquals(h.sends.length, 0)
  // Releasing here would let a later run message someone who said stop.
  assertEquals(h.releases.length, 0)
})

Deno.test('never twice: refuses to send when the claim is not held', async () => {
  const h = harness({ row: contact({ notified_at: null }) })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 409)
  assertEquals((await res.json()).status, 'not_claimed')
  assertEquals(h.sends.length, 0)
})

Deno.test('possibly late: a failed send releases the claim for retry', async () => {
  const h = harness({ sendResult: { success: false, error: 'carrier rejected' } })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 502)
  const body = await res.json()
  assertEquals(body.status, 'send_failed')
  assertEquals(body.released, true)
  assertEquals(h.releases, [CONTACT_ID])
})

Deno.test('a throwing sender is treated as a failed send, not a success', async () => {
  const h = harness({ sendThrows: true })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 502)
  assertEquals(h.releases, [CONTACT_ID])
})

Deno.test('a failed release is reported, never masked as success', async () => {
  const h = harness({ sendResult: { success: false, error: 'x' }, releaseThrows: true })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 502)
  assertEquals((await res.json()).released, false)
})

Deno.test('a contact with no phone releases the claim and does not send', async () => {
  const h = harness({ row: contact({ phone: '' }) })
  const res = await handleNotice(request(VALID), h.deps)
  assertEquals(res.status, 422)
  assertEquals(h.sends.length, 0)
  assertEquals(h.releases, [CONTACT_ID])
})

Deno.test('unknown lang falls back to English rather than failing', async () => {
  const h = harness()
  const res = await handleNotice(request({ ...VALID, lang: 'ta' }), h.deps)
  assertEquals((await res.json()).lang, 'en')
})
