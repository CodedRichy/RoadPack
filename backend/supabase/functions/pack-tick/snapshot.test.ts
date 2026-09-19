// Snapshot privacy guard (PM-53, TRD 7.2) and the position hook's additivity.
//
// Run: deno test --allow-read backend/supabase/functions/pack-tick/

import {
  assert,
  assertEquals,
  assertThrows,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  assertAnonymous,
  assertCoarsened,
  serializeSnapshot,
  snapshotObjectPath,
  SnapshotPrivacyError,
  type Snapshot,
} from './snapshot.ts'
import { projectPackPositions } from './pack_position.ts'

function member(over: Record<string, unknown> = {}) {
  return {
    member_key: 'Ab3-_xY9Qz12',
    display_name: 'Ravi',
    role: 'rider',
    chainage_m: 41200,
    position: [10.0231, 76.341] as [number, number],
    precision_m: 50,
    gap_from_leader_m: -4200,
    gap_from_leader_s: 420,
    gap_estimated: false,
    display_state: 'ok',
    status: 'refueling',
    status_auto: false,
    stale: false,
    off_route: false,
    off_route_m: null,
    updated_at: '2026-08-10T09:14:02Z',
    ...over,
  }
}

const SNAP = (): Snapshot => ({
  ride_id: '3f8c0a1e-1111-2222-3333-444455556666',
  name: 'Sunday run',
  status: 'active',
  generated_at: '2026-08-10T09:14:05Z',
  stale_threshold_s: 90,
  route: { polyline: '_p~iF~ps|U', length_m: 184320 },
  // deno-lint-ignore no-explicit-any
  members: [member() as any],
})

Deno.test('a clean snapshot serialises', () => {
  const out = JSON.parse(serializeSnapshot(SNAP()))
  assertEquals(out.members[0].display_name, 'Ravi')
  assertEquals(out.members[0].precision_m, 50)
})

Deno.test('an all-digit member key does not trip the phone heuristic', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).member_key = '481625093714'
  const out = JSON.parse(serializeSnapshot(s))
  assertEquals(out.members[0].member_key, '481625093714')
})

Deno.test('an omitted viewer_count serialises rather than failing', () => {
  const s = SNAP()
  assertEquals(JSON.parse(serializeSnapshot(s)).viewer_count, undefined)
  s.viewer_count = 4
  assertEquals(JSON.parse(serializeSnapshot(s)).viewer_count, 4)
})

Deno.test('PM-53: a user id anywhere in the payload refuses to publish', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).user_id = 'user_2abc'
  assertThrows(() => serializeSnapshot(s), SnapshotPrivacyError, 'user_id')
})

Deno.test('PM-53: a nested identity leak is still caught', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s as any).debug = { last_writer: { userId: 'user_2abc' } }
  assertThrows(() => serializeSnapshot(s), SnapshotPrivacyError)
})

Deno.test('PM-53: a phone-shaped string refuses to publish, whatever it is called', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).display_name = 'Ravi +919876543210'
  assertThrows(() => serializeSnapshot(s), SnapshotPrivacyError, 'phone-shaped')
})

Deno.test('PM-53: emergency contact data refuses to publish', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s as any).contacts = []
  assertThrows(() => serializeSnapshot(s), SnapshotPrivacyError, 'contacts')
})

Deno.test('PM-53: a position published without a stated precision is refused', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).precision_m = null
  assertThrows(() => assertCoarsened(s), SnapshotPrivacyError, 'precision')
})

Deno.test('PM-53: a position published at finer than 50 m is refused', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).precision_m = 5
  assertThrows(() => assertCoarsened(s), SnapshotPrivacyError)
})

Deno.test('a member with no position yet needs no precision', () => {
  const s = SNAP()
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).position = null
  // deno-lint-ignore no-explicit-any
  ;(s.members[0] as any).precision_m = null
  assertCoarsened(s)
})

Deno.test('the anonymous walker tolerates nulls and empty structures', () => {
  assertAnonymous(null)
  assertAnonymous({ a: [], b: {}, c: null })
})

Deno.test('the object key is derived from the token only, and validated', () => {
  assertEquals(snapshotObjectPath('03vaWZyGRn1_iaRJGqSoVA'), '03vaWZyGRn1_iaRJGqSoVA.json')
  assertThrows(() => snapshotObjectPath('../../etc/passwd'), SnapshotPrivacyError)
  assertThrows(() => snapshotObjectPath('short'), SnapshotPrivacyError)
})

// ---------------------------------------------------------------------------
// location-ingest additivity
// ---------------------------------------------------------------------------

// deno-lint-ignore no-explicit-any
function fakeDb(opts: { memberships?: any[]; rides?: any[]; rpcThrows?: boolean }) {
  const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
  const db = {
    rpc(fn: string, args: Record<string, unknown>) {
      rpcCalls.push({ fn, args })
      if (opts.rpcThrows) return Promise.resolve({ data: null, error: { message: 'induced' } })
      return Promise.resolve({ data: [{ chainage_m: 4200, off_route: false }], error: null })
    },
    from(table: string) {
      const rows = table === 'pack_ride_members' ? (opts.memberships ?? []) : (opts.rides ?? [])
      const chain = {
        select: () => chain,
        eq: () => chain,
        is: () => chain,
        in: () => chain,
        limit: () => chain,
        then: (res: (v: unknown) => void) => res({ data: rows, error: null }),
      }
      return chain
    },
  }
  return { db, rpcCalls }
}

const FIX = [{ lat: 10.02, lng: 76.34, at: '2026-08-10T09:14:00Z' }]
const silent = { error: () => {} }

Deno.test('a user in no pack ride is untouched by the position hook', async () => {
  const { db, rpcCalls } = fakeDb({ memberships: [] })
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', FIX, silent)
  assertEquals(r, { ride_id: null, projected: 0, breadcrumbs: 0 })
  assertEquals(rpcCalls.length, 0, 'no pack work is done for a non-pack user')
})

Deno.test('a member of a ride that is not active is untouched', async () => {
  const { db, rpcCalls } = fakeDb({ memberships: [{ ride_id: 'r1', role: 'rider' }], rides: [] })
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', FIX, silent)
  assertEquals(r.projected, 0)
  assertEquals(rpcCalls.length, 0)
})

Deno.test('a rider in an active ride is projected, without breadcrumbs', async () => {
  const { db, rpcCalls } = fakeDb({
    memberships: [{ ride_id: 'r1', role: 'rider' }],
    rides: [{ id: 'r1' }],
  })
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', FIX, silent)
  assertEquals(r.projected, 1)
  assertEquals(r.breadcrumbs, 0)
  assertEquals(rpcCalls.map((c) => c.fn), ['fn_pack_project_member'])
})

Deno.test('the leader also lays a breadcrumb, which is what the time gap reads', async () => {
  const { db, rpcCalls } = fakeDb({
    memberships: [{ ride_id: 'r1', role: 'leader' }],
    rides: [{ id: 'r1' }],
  })
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', FIX, silent)
  assertEquals(r.breadcrumbs, 1)
  assertEquals(rpcCalls.map((c) => c.fn), ['fn_pack_project_member', 'fn_pack_record_breadcrumb'])
})

Deno.test('an RPC failure degrades the pack view and never throws at ingest', async () => {
  const { db } = fakeDb({
    memberships: [{ ride_id: 'r1', role: 'leader' }],
    rides: [{ id: 'r1' }],
    rpcThrows: true,
  })
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', FIX, silent)
  assertEquals(r.projected, 0)
  assertEquals(r.breadcrumbs, 0)
})

Deno.test('a totally broken client is caught rather than failing the ingest request', async () => {
  const broken = { rpc: () => { throw new Error('boom') },
                   from: () => { throw new Error('boom') } }
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(broken as any, 'u1', FIX, silent)
  assertEquals(r.ride_id, null)
})

Deno.test('only the last 10 fixes of a batch are projected, so a backfill cannot stall ingest', async () => {
  const { db, rpcCalls } = fakeDb({
    memberships: [{ ride_id: 'r1', role: 'rider' }],
    rides: [{ id: 'r1' }],
  })
  const many = Array.from({ length: 40 }, (_, i) => ({
    lat: 10, lng: 76, at: new Date(Date.UTC(2026, 7, 10, 9, 0, i)).toISOString(),
  }))
  // deno-lint-ignore no-explicit-any
  const r = await projectPackPositions(db as any, 'u1', many, silent)
  assertEquals(r.projected, 10)
  assert(String(rpcCalls[0].args.p_at).endsWith('09:00:30.000Z'),
    'the newest fixes are the ones projected')
})

// ---------------------------------------------------------------------------
// location-ingest call site
// ---------------------------------------------------------------------------

const INGEST = await Deno.readTextFile(
  new URL('../location-ingest/index.ts', import.meta.url),
)

Deno.test('the location-ingest change is additive only', () => {
  assert(INGEST.includes('projectPackPositions('), 'the hook is wired in')
  // The pre-existing behaviour must still be exactly there.
  assert(INGEST.includes("from('location_history')"))
  assert(INGEST.includes("from('devices')"))
  assert(INGEST.includes("JSON.stringify({ status: 'ok', count: gpsLocations.length })"))
  // And the hook cannot turn a good write into a 500.
  const hookAt = INGEST.indexOf('projectPackPositions(')
  const guardAt = INGEST.lastIndexOf('try {', hookAt)
  assert(guardAt > -1 && guardAt < hookAt, 'the hook sits inside its own error boundary')
})
