// Inbound-SMS opt-out recognition, and proof that adding it did not disturb the
// existing incident-acknowledgement path in sms-webhook.
//
//   deno test --allow-read backend/supabase/tests/contact_notice_optout.test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { isOptOut } from '../functions/emergency-contact-notice/optout.ts'

Deno.test('opt-out: carrier-standard English keywords', () => {
  for (const k of ['STOP', 'stop', ' Stop ', 'STOP.', 'UNSUBSCRIBE', 'unsub', 'CANCEL', 'QUIT', 'END', 'OPTOUT', 'opt out']) {
    assert(isOptOut(k), `expected "${k}" to opt out`)
  }
})

Deno.test('opt-out: Hindi and Malayalam equivalents', () => {
  for (const k of ['बंद', 'बंद करो', 'रोको', 'band', 'BAND KARO', 'roko', 'നിർത്തുക', 'വേണ്ട', 'venda', 'NIRTHUKA']) {
    assert(isOptOut(k), `expected "${k}" to opt out`)
  }
  // Devanagari danda and double danda are stripped like a full stop.
  assert(isOptOut('बंद।'))
  assert(isOptOut('रोको॥'))
})

// The load-bearing test: an inbound message that is NOT an opt-out must keep
// flowing to the acknowledgement path exactly as it did before.
Deno.test('opt-out: acknowledgement replies are never diverted', () => {
  for (const k of ['OK', 'ok', ' Ok ', 'OK.', 'okay']) {
    assertEquals(isOptOut(k), false, `"${k}" must reach the ack path`)
  }
})

Deno.test('opt-out: free text containing a keyword is not an opt-out', () => {
  for (
    const k of [
      'did he stop?',
      'STOP THE CAR HE IS HURT',
      'I am on my way, please stop calling me later',
      'reply STOP to opt out',
      'unsubscribe me from the other thing',
      '',
      '   ',
    ]
  ) {
    assertEquals(isOptOut(k), false, `"${k}" must not opt out`)
  }
})

Deno.test('opt-out: non-string payloads are inert', () => {
  assertEquals(isOptOut(undefined), false)
  assertEquals(isOptOut(null), false)
  assertEquals(isOptOut(42), false)
  assertEquals(isOptOut({ message: 'STOP' }), false)
})

// Structural proof that the edit to sms-webhook was additive: the original
// acknowledgement logic is still present, verbatim, and the opt-out branch
// returns before ever reaching it.
Deno.test('sms-webhook: existing acknowledgement path is untouched', async () => {
  const src = await Deno.readTextFile(
    new URL('../functions/sms-webhook/index.ts', import.meta.url),
  )

  for (
    const fragment of [
      "if (normalizedMessage !== 'OK') {",
      "JSON.stringify({ status: 'ignored' })",
      ".eq('channel', 'sms')",
      ".is('acknowledged_at', null)",
      "update({ acknowledged_at: now, ack_method: 'sms' })",
      "update({ first_ack_at: now })",
      "JSON.stringify({ status: 'acknowledged', count: alertIds.length })",
      "body.type === 'delivery_receipt'",
    ]
  ) {
    assert(src.includes(fragment), `acknowledgement path lost: ${fragment}`)
  }

  // The opt-out branch is self-contained and precedes the ack check.
  const optOutAt = src.indexOf('if (isOptOut(message)) {')
  const ackAt = src.indexOf("if (normalizedMessage !== 'OK') {")
  assert(optOutAt > 0, 'opt-out branch missing')
  assert(optOutAt < ackAt, 'opt-out branch must be evaluated before the ack check')
  assert(
    src.slice(optOutAt, ackAt).includes("status: 'opted_out'"),
    'opt-out branch must return its own response',
  )
  // Exactly one acknowledgement path, i.e. it was not duplicated or forked.
  assertEquals(src.split("ack_method: 'sms'").length - 1, 1)
})
