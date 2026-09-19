// The location-ingest -> pack seam (TRD 6.3, build-order step 5).
//
// Riders do not push to Realtime individually. Positions arrive through the
// existing batched location-ingest path; this projects them onto the ride's
// route so the next 5 s tick has something to compute gaps from.
//
// Additive by construction: a user in no active pack ride costs one indexed
// lookup and nothing else changes for them.

export interface PackFix {
  lat: number
  lng: number
  /** ISO timestamp of the fix, not of its arrival. */
  at: string
}

export interface PackPositionResult {
  ride_id: string | null
  projected: number
  breadcrumbs: number
}

// Structural type: whatever supabase-js hands us, without importing it here so
// this module stays unit-testable with a plain object.
export interface PackDbClient {
  // PromiseLike, not Promise: supabase-js returns a thenable query builder.
  // deno-lint-ignore no-explicit-any
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: any; error: any }>
  // deno-lint-ignore no-explicit-any
  from(table: string): any
}

/**
 * The oldest fixes in a batch are already superseded by the newest for display
 * purposes, but projecting a few of them keeps the windowed search kinematic
 * (00017 relies on a short elapsed time between fixes to separate hairpin
 * legs). Projecting all 10 of a 30 s batch costs little and keeps the window
 * tight; projecting only the newest would hand the projector a 30 s corridor.
 */
const MAX_FIXES = 10

/** Never throws. A pack projection failure must not fail position ingest. */
export async function projectPackPositions(
  supabase: PackDbClient,
  userId: string,
  fixes: PackFix[],
  logger: Pick<Console, 'error'> = console,
): Promise<PackPositionResult> {
  const empty: PackPositionResult = { ride_id: null, projected: 0, breadcrumbs: 0 }
  if (fixes.length === 0) return empty

  try {
    const { data: memberships, error: memberErr } = await supabase
      .from('pack_ride_members')
      .select('ride_id, role')
      .eq('user_id', userId)
      .is('left_at', null)

    if (memberErr || !memberships || memberships.length === 0) return empty

    const rideIds = memberships.map((m: { ride_id: string }) => m.ride_id)
    const { data: rides, error: rideErr } = await supabase
      .from('pack_rides')
      .select('id')
      .in('id', rideIds)
      .eq('status', 'active')
      .limit(1)

    if (rideErr || !rides || rides.length === 0) return empty

    const rideId: string = rides[0].id
    const role: string =
      memberships.find((m: { ride_id: string }) => m.ride_id === rideId)?.role ?? 'rider'

    const ordered = [...fixes]
      .sort((a, b) => Date.parse(a.at) - Date.parse(b.at))
      .slice(-MAX_FIXES)

    let projected = 0
    let breadcrumbs = 0

    for (const fix of ordered) {
      const { data, error } = await supabase.rpc('fn_pack_project_member', {
        p_ride_id: rideId,
        p_user_id: userId,
        p_pos: `POINT(${fix.lng} ${fix.lat})`,
        p_at: fix.at,
      })
      if (error) {
        logger.error('[pack] projection failed (non-fatal):', error.message ?? String(error))
        continue
      }
      projected++

      // Leader breadcrumbs are the ground truth the time-gap lookup reads
      // (TRD 4.4). Only an on-route projection is a fact worth recording.
      const row = Array.isArray(data) ? data[0] : data
      if (role === 'leader' && row && row.off_route === false && row.chainage_m != null) {
        const { error: crumbErr } = await supabase.rpc('fn_pack_record_breadcrumb', {
          p_ride_id: rideId,
          p_chainage_m: row.chainage_m,
          p_at: fix.at,
        })
        if (crumbErr) {
          logger.error('[pack] breadcrumb failed (non-fatal):', crumbErr.message ?? String(crumbErr))
        } else {
          breadcrumbs++
        }
      }
    }

    return { ride_id: rideId, projected, breadcrumbs }
  } catch (err) {
    logger.error('[pack] position hook failed (non-fatal):', String(err))
    return empty
  }
}
