// THE CRITICAL TEST IN THE SUITE (TRD 11, PM-42).
//
// An induced failure in the Pack Mode write must leave the emergency alert
// cascade completely unaffected. The database half of this guarantee is proven
// in backend/supabase/tests/00019_pack_tick.test.sql section E; this is the
// edge-function half.
//
// Run: deno test --allow-read backend/supabase/functions/pack-tick/

import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { firePackIncidentPush } from './pack_notify.ts'

const silent = { error: () => {} }
const BASE = { supabaseUrl: 'https://x.supabase.co', serviceRoleKey: 'srk', userId: 'u1',
               incidentId: 'i1', reason: 'incident' as const }

// A stand-in for the part of incident-receive that matters: fire the pack side
// effect, then dispatch the cascade. The assertions are about what survives.
async function incidentPipeline(packFetch: typeof fetch) {
  const cascadeCalls: Array<{ url: string; body: unknown }> = []
  const cascadeFetch = (url: string | URL | Request, init?: RequestInit) => {
    cascadeCalls.push({ url: String(url), body: JSON.parse(String(init?.body ?? '{}')) })
    return Promise.resolve(new Response('{}', { status: 200 }))
  }

  // 1. pack side effect -- fire and forget, exactly as incident-receive does it
  firePackIncidentPush({
    ...BASE,
    fetchImpl: packFetch,
    waitUntil: (p) => { void p.catch(() => {}) },
    logger: silent,
  })

  // 2. cascade dispatch -- unchanged behaviour
  await cascadeFetch(`${BASE.supabaseUrl}/functions/v1/alert-cascade`, {
    method: 'POST',
    body: JSON.stringify({ incident_id: 'i1', contacts: [{ id: 'c1' }] }),
  })

  return cascadeCalls
}

Deno.test('CASCADE ISOLATION: a pack write that throws synchronously does not reach the caller', () => {
  const boom = (() => { throw new Error('induced pack failure') }) as unknown as typeof fetch
  // No try/catch here on purpose: if this throws, the test fails, and that is
  // exactly the production failure we are guarding against.
  const returned = firePackIncidentPush({ ...BASE, fetchImpl: boom, logger: silent,
                                          waitUntil: (p) => { void p.catch(() => {}) } })
  assertEquals(returned, undefined, 'the side effect must return void, never a promise to await')
})

Deno.test('CASCADE ISOLATION: a pack write that rejects does not reach the caller', async () => {
  const rejecting = (() => Promise.reject(new Error('induced pack failure'))) as unknown as typeof fetch
  const calls = await incidentPipeline(rejecting)
  assertEquals(calls.length, 1, 'the cascade still dispatched')
  assertStringIncludes(calls[0].url, '/functions/v1/alert-cascade')
  assertEquals((calls[0].body as { incident_id: string }).incident_id, 'i1',
    'the cascade payload is byte-for-byte what it would have been')
})

Deno.test('CASCADE ISOLATION: a pack write that never resolves does not delay the cascade', async () => {
  const hanging = (() => new Promise<Response>(() => {})) as unknown as typeof fetch
  const started = performance.now()
  const calls = await incidentPipeline(hanging)
  const elapsed = performance.now() - started
  assertEquals(calls.length, 1, 'the cascade still dispatched')
  assert(elapsed < 250, `the cascade waited ${elapsed.toFixed(0)}ms on a hung pack write`)
})

Deno.test('CASCADE ISOLATION: the pack push never touches the cascade endpoint', async () => {
  const seen: string[] = []
  const spy = ((url: string | URL | Request) => {
    seen.push(String(url))
    return Promise.resolve(new Response('{}', { status: 200 }))
  }) as unknown as typeof fetch

  const done = new Promise<void>((resolve) => {
    firePackIncidentPush({ ...BASE, fetchImpl: spy, logger: silent,
                           waitUntil: (p) => { void p.finally(resolve) } })
  })
  await done

  assertEquals(seen.length, 1)
  assertStringIncludes(seen[0], '/functions/v1/pack-tick')
  assert(!seen.some((u) => u.includes('alert-cascade')),
    'the pack path must not be able to invoke, retry, or duplicate the cascade')
})

Deno.test('CASCADE ISOLATION: the push carries no emergency-contact data', async () => {
  let body: Record<string, unknown> = {}
  const spy = ((_u: string | URL | Request, init?: RequestInit) => {
    body = JSON.parse(String(init?.body ?? '{}'))
    return Promise.resolve(new Response('{}', { status: 200 }))
  }) as unknown as typeof fetch

  await new Promise<void>((resolve) => {
    firePackIncidentPush({ ...BASE, fetchImpl: spy, logger: silent,
                           waitUntil: (p) => { void p.finally(resolve) } })
  })

  assertEquals(Object.keys(body).sort(), ['incident_id', 'reason', 'user_id'])
})

// ---------------------------------------------------------------------------
// Structural assertions on the real incident-receive source.
//
// The behavioural tests above prove the primitive is safe. These prove the
// production call site actually uses it that way -- an `await` added in front
// of the call in a later edit would pass every test above and still couple the
// cascade to Pack Mode.
// ---------------------------------------------------------------------------

const SRC = await Deno.readTextFile(
  new URL('../incident-receive/index.ts', import.meta.url),
)

Deno.test('CASCADE ISOLATION: the production call site does not await the pack push', () => {
  assertStringIncludes(SRC, 'firePackIncidentPush({')
  assert(!/await\s+firePackIncidentPush/.test(SRC),
    'the pack push must never be awaited on the incident path')
  assert(!/firePackIncidentPush\([^)]*\)\s*\.\s*then/.test(SRC),
    'the pack push must not be chained into the incident path')
})

Deno.test('CASCADE ISOLATION: the pack push fires before the cascade is invoked', () => {
  const packAt = SRC.indexOf('firePackIncidentPush(')
  const cascadeAt = SRC.indexOf('/functions/v1/alert-cascade')
  assert(packAt > -1 && cascadeAt > -1)
  assert(packAt < cascadeAt,
    'the pack is told on receipt, inside the 30 s countdown, not after dispatch')
})

Deno.test('CASCADE ISOLATION: the existing cascade invocation is untouched', () => {
  assertStringIncludes(SRC, 'EdgeRuntime.waitUntil(')
  assertStringIncludes(SRC, 'cascade_jobs')
  assertStringIncludes(SRC, "Failed to invoke alert-cascade")
  assertStringIncludes(SRC, 'const cascadeUrl = `${supabaseUrl}/functions/v1/alert-cascade`')
})
