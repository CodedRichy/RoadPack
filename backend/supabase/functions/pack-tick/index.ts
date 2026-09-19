// pack-tick — the 5 s aggregate tick (TRD 6.2, 7.2, 8.4)
//
// One server tick, two transports:
//   1. ONE aggregated Realtime broadcast per ride, carrying every member's
//      exact state. Not one message per member: TRD 6.2 costs a naive
//      per-rider broadcast at ~648,000 Realtime messages per 6 h ride, which
//      is roughly three rides a month on the free tier. The aggregate is
//      ~47,500 -- a ~14x reduction, and it is the reason this feature is
//      economically viable at all.
//   2. ONE coarsened snapshot object per ride, written to Storage. Anonymous
//      viewers poll the CDN, so viewer count does not touch Realtime cost and
//      never consumes a WebSocket connection -- which is the ceiling that
//      actually breaks during the viral moment this feature is designed to
//      cause.
//
// Invoked by pg_cron every 5 s (migration 00019), and directly by
// incident-receive for an immediate push inside the crash countdown.
//
// Bodies accepted:
//   {}                          tick every active ride
//   { ride_id }                 tick one ride
//   { user_id, reason }         tick the ride that user is in, now
//   { sweep: true }             sweep orphaned snapshot objects (TRD 8.4)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  SNAPSHOT_BUCKET,
  serializeSnapshot,
  snapshotObjectPath,
  type Snapshot,
} from './snapshot.ts'

const JSON_HEADERS = { 'Content-Type': 'application/json' }

interface TickResult {
  ride_id: string
  share_token: string
  status_changed: number
  tick: Record<string, unknown>
  snapshot: Snapshot | null
}

/**
 * One broadcast for the whole ride. Sent over the Realtime HTTP endpoint
 * rather than a WebSocket: a cron-driven isolate that lives for milliseconds
 * has no business opening a socket, and the HTTP path is billed the same.
 */
async function broadcastTick(
  supabaseUrl: string,
  serviceRoleKey: string,
  rideId: string,
  payload: Record<string, unknown>,
  reason: string,
): Promise<boolean> {
  const res = await fetch(`${supabaseUrl}/realtime/v1/api/broadcast`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      messages: [
        {
          topic: `pack:${rideId}`,
          event: 'pack_tick',
          private: true,
          payload: { ...payload, reason },
        },
      ],
    }),
  })
  if (!res.ok) {
    console.error(`[pack-tick] broadcast failed for ${rideId}: ${res.status} ${await res.text()}`)
  }
  return res.ok
}

// deno-lint-ignore no-explicit-any
async function tickRide(supabase: any, supabaseUrl: string, serviceRoleKey: string,
                        rideId: string, reason: string) {
  const { data, error } = await supabase.rpc('fn_pack_tick', { p_ride_id: rideId })
  if (error) {
    console.error(`[pack-tick] fn_pack_tick failed for ${rideId}:`, error.message)
    return { ride_id: rideId, ok: false }
  }
  const result = data as TickResult | null
  if (!result) return { ride_id: rideId, ok: false }

  await broadcastTick(supabaseUrl, serviceRoleKey, rideId, result.tick, reason)

  const objectPath = snapshotObjectPath(result.share_token)

  if (result.snapshot === null) {
    // Not publishable any more: ended, expired, or revoked. The object must
    // go, not merely stop being refreshed (TRD 8.1) -- a stale snapshot left
    // on a CDN is exactly the live feed the rider believes they switched off.
    const { error: rmErr } = await supabase.storage.from(SNAPSHOT_BUCKET).remove([objectPath])
    if (rmErr) console.error(`[pack-tick] snapshot delete failed for ${rideId}:`, rmErr.message)
    return { ride_id: rideId, ok: true, published: false, deleted: true }
  }

  // serializeSnapshot throws rather than publish a payload carrying identity
  // or an uncoarsened position (PM-53).
  let body: string
  try {
    body = serializeSnapshot(result.snapshot)
  } catch (err) {
    console.error(`[pack-tick] REFUSED to publish snapshot for ${rideId}:`, String(err))
    return { ride_id: rideId, ok: false, published: false, refused: true }
  }

  const { error: upErr } = await supabase.storage
    .from(SNAPSHOT_BUCKET)
    .upload(objectPath, new Blob([body], { type: 'application/json' }), {
      upsert: true,
      contentType: 'application/json',
      // Viewers poll every 5 s; a longer CDN life would serve them a position
      // the pack has already moved past.
      cacheControl: '5',
    })
  if (upErr) console.error(`[pack-tick] snapshot upload failed for ${rideId}:`, upErr.message)

  return {
    ride_id: rideId,
    ok: true,
    published: !upErr,
    status_changed: result.status_changed,
    members: result.snapshot.members.length,
  }
}

/**
 * The Storage half of the lifecycle sweep (TRD 8.4). The database half
 * (fn_pack_sweep_expired) is already scheduled by migration 00018, but Postgres
 * cannot list a bucket, so an object whose ride ended while this function was
 * failing would otherwise outlive the ride forever.
 */
// deno-lint-ignore no-explicit-any
async function sweepOrphanSnapshots(supabase: any) {
  let removed = 0
  let scanned = 0
  let offset = 0
  const PAGE = 100

  for (;;) {
    const { data: objects, error } = await supabase.storage
      .from(SNAPSHOT_BUCKET)
      .list('', { limit: PAGE, offset })
    if (error) {
      console.error('[pack-tick] snapshot listing failed:', error.message)
      break
    }
    if (!objects || objects.length === 0) break
    scanned += objects.length

    const names: string[] = objects
      .map((o: { name: string }) => o.name)
      .filter((n: string) => n.endsWith('.json'))
    const tokens = names.map((n) => n.slice(0, -'.json'.length))

    if (tokens.length > 0) {
      const { data: orphans, error: rpcErr } = await supabase.rpc('fn_pack_orphan_tokens', {
        p_tokens: tokens,
      })
      if (rpcErr) {
        console.error('[pack-tick] orphan lookup failed:', rpcErr.message)
      } else if (orphans && orphans.length > 0) {
        const paths = (orphans as string[]).map((t) => `${t}.json`)
        const { error: rmErr } = await supabase.storage.from(SNAPSHOT_BUCKET).remove(paths)
        if (rmErr) console.error('[pack-tick] orphan delete failed:', rmErr.message)
        else removed += paths.length
      }
    }

    if (objects.length < PAGE) break
    offset += PAGE
  }

  return { swept: removed, scanned }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Service role only. This function reads exact positions for every rider on
  // the platform; it is never reachable with a user token.
  if (req.headers.get('Authorization') !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)

  let body: { ride_id?: string; user_id?: string; reason?: string; sweep?: boolean } = {}
  try {
    body = (await req.json()) ?? {}
  } catch {
    body = {}
  }

  const url = new URL(req.url)
  if (body.sweep === true || url.searchParams.get('sweep') === '1') {
    const swept = await sweepOrphanSnapshots(supabase)
    return new Response(JSON.stringify({ status: 'ok', ...swept }), { headers: JSON_HEADERS })
  }

  const reason = body.reason ?? 'tick'
  let rideIds: string[] = []

  if (body.ride_id) {
    rideIds = [body.ride_id]
  } else if (body.user_id) {
    // The immediate-push path from incident-receive. The status itself was
    // already written by the database trigger; this only decides which ride
    // to broadcast.
    const { data: members } = await supabase
      .from('pack_ride_members')
      .select('ride_id')
      .eq('user_id', body.user_id)
      .is('left_at', null)
    const candidateIds = (members ?? []).map((m: { ride_id: string }) => m.ride_id)
    if (candidateIds.length > 0) {
      const { data: rides } = await supabase
        .from('pack_rides')
        .select('id')
        .in('id', candidateIds)
        .eq('status', 'active')
      rideIds = (rides ?? []).map((r: { id: string }) => r.id)
    }
  } else {
    const { data: ids, error } = await supabase.rpc('fn_pack_active_ride_ids')
    if (error) {
      console.error('[pack-tick] active ride lookup failed:', error.message)
      return new Response(JSON.stringify({ error: 'DB error' }), {
        status: 500,
        headers: JSON_HEADERS,
      })
    }
    rideIds = (ids ?? []) as string[]
  }

  // Rides are independent; one slow ride must not delay the rest of the pack
  // platform's 5 s budget.
  const results = await Promise.all(
    rideIds.map((id) =>
      tickRide(supabase, supabaseUrl, serviceRoleKey, id, reason).catch((err) => {
        console.error(`[pack-tick] ride ${id} threw:`, String(err))
        return { ride_id: id, ok: false }
      })
    ),
  )

  return new Response(
    JSON.stringify({ status: 'ok', reason, rides: results.length, results }),
    { headers: JSON_HEADERS },
  )
})
