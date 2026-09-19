// Snapshot serialisation and the last-line privacy guard.
//
// The coarsening and the exclusion of identity happen in the database
// (migration 00019, fn_pack_member_payload). This module does not re-implement
// either; it refuses to publish a payload that failed to do them.
//
// Why guard something the database already guarantees: the object this writes
// is world-readable by anyone holding a URL, and PM-53 is not a preference. If
// a future schema change adds a column to the snapshot builder and someone
// forgets which of the two payloads is the public one, the correct outcome is
// a loud failure and a stale snapshot, not a silent leak.

export const SNAPSHOT_BUCKET = 'packs'

/** Keys that must never appear anywhere in an anonymous snapshot. */
export const FORBIDDEN_KEYS = [
  'user_id',
  'userId',
  'phone',
  'phone_number',
  'email',
  'emergency_contacts',
  'contacts',
  'device_id',
  'clerk_id',
] as const

// Anything that looks like a phone number, however it got there.
//
// Scoped deliberately: a naive "ten or more digits" rule fires on the ride's
// own UUID (whose last group is twelve hex digits) and on ISO timestamps, and
// a guard that cries wolf gets deleted by the next person to hit it. The run
// must be a standalone token -- not embedded in a longer identifier -- and a
// UUID is excluded outright.
const PHONE_LIKE = /(?:^|[^0-9A-Za-z_-])\+?\d[\d\s-]{8,14}\d(?![0-9A-Za-z_-])/
const UUID_LIKE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

// Values that are opaque random tokens by construction. A 12-character random
// key can come up all digits, which would trip the phone heuristic and refuse
// to publish an entirely correct snapshot. Their opacity is guaranteed at
// generation, not by inspection.
const OPAQUE_KEYS = new Set(['member_key'])

export interface SnapshotMember {
  /** Opaque, stable for the life of the ride. The client's marker identity. */
  member_key: string
  display_name: string
  role: string
  chainage_m: number | null
  position: [number, number] | null
  precision_m: number | null
  gap_from_leader_m: number | null
  gap_from_leader_s: number | null
  gap_estimated: boolean
  display_state: string
  status: string
  status_auto: boolean
  stale: boolean
  off_route: boolean
  off_route_m: number | null
  updated_at: string | null
}

export interface Snapshot {
  ride_id: string
  name: string | null
  status: string
  generated_at: string
  stale_threshold_s: number
  route: { polyline: string; length_m: number }
  /** Absent when no beacon-capable viewer has been seen on this ride. */
  viewer_count?: number
  members: SnapshotMember[]
}

export class SnapshotPrivacyError extends Error {}

export function snapshotObjectPath(shareToken: string): string {
  // The token is generated URL-safe by fn_pack_share_token, but the object key
  // is derived from data, so it is validated rather than trusted.
  if (!/^[A-Za-z0-9_-]{16,64}$/.test(shareToken)) {
    throw new SnapshotPrivacyError(`refusing to write an object for a malformed share token`)
  }
  return `${shareToken}.json`
}

/**
 * Throws if the payload carries identity or uncoarsened positions.
 * Walks the whole structure -- a nested leak is still a leak.
 */
export function assertAnonymous(payload: unknown, path = '$'): void {
  if (payload === null || payload === undefined) return

  if (typeof payload === 'string') {
    if (UUID_LIKE.test(payload)) return
    if (PHONE_LIKE.test(payload)) {
      throw new SnapshotPrivacyError(`phone-shaped value at ${path}`)
    }
    return
  }

  if (Array.isArray(payload)) {
    payload.forEach((v, i) => assertAnonymous(v, `${path}[${i}]`))
    return
  }

  if (typeof payload === 'object') {
    for (const [k, v] of Object.entries(payload as Record<string, unknown>)) {
      if ((FORBIDDEN_KEYS as readonly string[]).includes(k)) {
        throw new SnapshotPrivacyError(`forbidden key "${k}" at ${path}`)
      }
      if (OPAQUE_KEYS.has(k) && typeof v === 'string') continue
      assertAnonymous(v, `${path}.${k}`)
    }
  }
}

/**
 * Every published member must state a precision, and it must be the coarse
 * one. A member with a position but no precision_m is an uncoarsened position
 * that slipped through the wrong payload builder.
 */
export function assertCoarsened(snapshot: Snapshot, minPrecisionM = 50): void {
  for (const m of snapshot.members ?? []) {
    if (m.position === null || m.position === undefined) continue
    if (typeof m.precision_m !== 'number' || m.precision_m < minPrecisionM) {
      throw new SnapshotPrivacyError(
        `member "${m.display_name}" publishes a position at precision ${m.precision_m}`,
      )
    }
  }
}

/** Serialise for Storage, refusing to produce bytes that fail either guard. */
export function serializeSnapshot(snapshot: Snapshot): string {
  assertAnonymous(snapshot)
  assertCoarsened(snapshot)
  return JSON.stringify(snapshot)
}
