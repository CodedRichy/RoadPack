// The incident -> pack seam (TRD 5.2, PM-40 / PM-42).
//
// THE HIGHEST-SEVERITY CONSTRAINT IN THE PROJECT: nothing here may delay,
// alter, or fail the emergency alert cascade.
//
// The status write itself lives in the database (migration 00019, trigger
// `trg_pack_incident_sync`), so it happens for every writer of the incidents
// table and cannot be forgotten by a caller. This module is only the immediate
// PUSH: it asks pack-tick to broadcast now rather than up to 5 s from now,
// because the pack must be told inside the 30 s cancellable countdown -- they
// are the nearest possible responders and are often minutes closer than any
// emergency contact.
//
// Every design choice below exists to make failure here harmless:
//   * the function returns `void`, so a caller CANNOT await it by accident;
//   * the entire body is inside try/catch, so it cannot throw synchronously;
//   * the request carries an AbortSignal timeout, so a hung pack-tick cannot
//     hold the isolate open behind the cascade;
//   * the promise is handed to waitUntil (or left detached with .catch), never
//     to the request path;
//   * it never references the cascade URL, the contact list, or the incident
//     payload the cascade sends -- there is no shared state to corrupt.
//
// If this module does nothing at all, the pack still learns about the incident
// on the next 5 s tick. That is the designed degradation.

export type PackIncidentReason = 'incident' | 'incident_cleared'

export interface PackNotifyOptions {
  supabaseUrl: string
  serviceRoleKey: string
  userId: string
  incidentId: string
  reason: PackIncidentReason
  /** Injected for tests; defaults to global fetch. */
  fetchImpl?: typeof fetch
  /** Injected for tests; defaults to EdgeRuntime.waitUntil when present. */
  waitUntil?: (p: Promise<unknown>) => void
  /** Injected for tests. */
  logger?: Pick<Console, 'error'>
  timeoutMs?: number
}

const DEFAULT_TIMEOUT_MS = 3000

function defaultWaitUntil(p: Promise<unknown>): void {
  try {
    // @ts-ignore — EdgeRuntime is a Supabase-specific global
    if (typeof EdgeRuntime !== 'undefined' && EdgeRuntime?.waitUntil) {
      // @ts-ignore
      EdgeRuntime.waitUntil(p)
      return
    }
  } catch {
    // fall through to a detached promise
  }
  void p
}

/**
 * Fire-and-forget. Always returns undefined, immediately, whatever happens.
 */
export function firePackIncidentPush(opts: PackNotifyOptions): void {
  const log = opts.logger ?? console
  try {
    const doFetch = opts.fetchImpl ?? fetch
    const waitUntil = opts.waitUntil ?? defaultWaitUntil
    const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS

    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)

    const p = Promise.resolve()
      .then(() =>
        doFetch(`${opts.supabaseUrl}/functions/v1/pack-tick`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${opts.serviceRoleKey}`,
          },
          body: JSON.stringify({
            user_id: opts.userId,
            incident_id: opts.incidentId,
            reason: opts.reason,
          }),
          signal: controller.signal,
        })
      )
      .catch((err) => {
        // A degraded pack view. The cascade is untouched and the next tick
        // will carry the status anyway.
        log.error('[pack] immediate incident push failed (non-fatal):', String(err))
      })
      .finally(() => clearTimeout(timer))

    waitUntil(p)
  } catch (err) {
    // Reached only if something above threw before the promise existed --
    // a missing global, a broken injected dependency. Still not the cascade's
    // problem.
    try {
      log.error('[pack] incident push could not be started (non-fatal):', String(err))
    } catch {
      // Nothing left to do. Never rethrow from this function.
    }
  }
}
