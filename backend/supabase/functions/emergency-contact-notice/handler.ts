// FR-024: when someone lists you as their emergency contact you get exactly one
// SMS telling you so, with a way to opt out.
//
// Concurrency model — the chosen failure mode is POSSIBLY LATE, NEVER POSSIBLY
// TWICE. The client claims the send first with a conditional
//   UPDATE emergency_contacts SET notified_at = now()
//    WHERE id = $1 AND notified_at IS NULL
// and only then calls this function. So:
//   * we refuse to send when the claim is not held (409) — an unclaimed send is
//     a send that can happen twice;
//   * on send failure we release the claim so a later attempt can retry;
//   * on any doubt about whether the message went out we KEEP the claim, which
//     costs a lost notice, not a duplicate one.
//
// The handler is separated from `index.ts` so it can be unit-tested without
// binding a port.

import {
  MAX_SEGMENTS,
  dltTemplateId,
  measureNotice,
  normalizeLang,
  renderNotice,
} from './notice.ts'
import { type TextSmsSender } from './sms.ts'

const JSON_HEADERS = { 'Content-Type': 'application/json' }

export interface ContactRow {
  id: string
  user_id: string
  name: string | null
  phone: string
  opted_out: boolean | null
  notified_at: string | null
}

export interface ContactStore {
  getContact(id: string): Promise<ContactRow | null>
  /** Undo the client's claim so the notice can be retried later. */
  releaseClaim(id: string): Promise<void>
}

export interface Deps {
  store: ContactStore
  sender: TextSmsSender
  verifyJwt(token: string): Promise<{ sub: string }>
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS })
}

export async function handleNotice(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'Missing auth token' }, 401)
  }

  let userId: string
  try {
    const { sub } = await deps.verifyJwt(authHeader.slice(7))
    userId = sub
  } catch {
    return json({ error: 'Invalid token' }, 401)
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Invalid JSON' }, 422)
  }

  const contactId = typeof body.contact_id === 'string' ? body.contact_id : ''
  const listedBy = body.listed_by
  if (!contactId) return json({ error: 'Missing contact_id' }, 422)
  if (typeof listedBy !== 'string' || listedBy.trim().length === 0) {
    return json({ error: 'Missing listed_by' }, 422)
  }

  const lang = normalizeLang(body.lang)

  let contact: ContactRow | null
  try {
    contact = await deps.store.getContact(contactId)
  } catch (err) {
    console.error('[contact-notice] contact lookup failed', err)
    return json({ error: 'Lookup failed' }, 503)
  }
  if (!contact) return json({ error: 'Contact not found' }, 404)

  // Only the person who listed the contact may trigger their notice.
  if (contact.user_id !== userId) return json({ error: 'Forbidden' }, 403)

  // Consent gate: an opted-out contact is never messaged again. The claim is
  // deliberately left in place — releasing it would let a later run re-send.
  if (contact.opted_out === true) {
    return json({ status: 'skipped', reason: 'opted_out' })
  }

  // No claim held means a concurrent sender may also be about to send, or that
  // the notice already went out and the row was reset. Either way, refusing is
  // the "never twice" side of the trade.
  if (contact.notified_at === null) {
    return json({ status: 'not_claimed', reason: 'claim_not_held' }, 409)
  }

  // The row is authoritative for the phone number; a client-supplied `phone`
  // that disagrees with the database must not be able to redirect the message.
  const phone = contact.phone
  if (!phone) {
    await releaseQuietly(deps, contactId)
    return json({ error: 'Contact has no phone number' }, 422)
  }

  const message = renderNotice(lang, listedBy)
  const info = measureNotice(lang, listedBy)
  if (info.segments > MAX_SEGMENTS) {
    // FR-104 is a hard constraint; this is a guard against a future copy edit,
    // not an expected runtime path. Release so nothing is silently swallowed.
    console.error(
      `[contact-notice] FR-104 violation: ${lang} rendered ${info.segments} segments`,
    )
    await releaseQuietly(deps, contactId)
    return json({ error: 'Message exceeds segment budget', lang }, 500)
  }

  let sent: { success: boolean; provider_id?: string; error?: string }
  try {
    sent = await deps.sender.sendText(phone, message, dltTemplateId(lang))
  } catch (err) {
    console.error('[contact-notice] send threw', err)
    sent = { success: false, error: err instanceof Error ? err.message : String(err) }
  }

  if (!sent.success) {
    const released = await releaseQuietly(deps, contactId)
    return json(
      { status: 'send_failed', released, error: sent.error ?? 'unknown' },
      502,
    )
  }

  return json({
    status: 'sent',
    contact_id: contactId,
    lang,
    encoding: info.encoding,
    segments: info.segments,
    provider_id: sent.provider_id ?? null,
    dlt_template_id: dltTemplateId(lang),
  })
}

/**
 * Release the claim, never throwing. A failed release is only a lost notice
 * (the row stays claimed and is never retried) — strictly better than the
 * alternative of reporting success we do not have.
 */
async function releaseQuietly(deps: Deps, contactId: string): Promise<boolean> {
  try {
    await deps.store.releaseClaim(contactId)
    return true
  } catch (err) {
    console.error('[contact-notice] claim release failed', err)
    return false
  }
}
