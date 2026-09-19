/* Local-development only.
 *
 * The sample snapshots in ./sample carry symbolic timestamps instead of real
 * ones, because a fixture with a baked ISO date is stale the moment it is
 * written -- and a viewer that renders every fixture as "frozen, 3 weeks ago"
 * is useless for working on the live states.
 *
 * This resolves those symbols at fetch time, and ONLY when config.USE_SAMPLES
 * is on (file:// or localhost). It never runs against a real snapshot: a real
 * snapshot's timestamps are the truth and rewriting them would be exactly the
 * dishonesty this whole viewer is built to avoid.
 *
 *   REPLACED_AT_LOAD -> now
 *   STALE_<n>M       -> n minutes ago
 *   STALE_<n>S       -> n seconds ago
 */

function resolve(value, nowMs) {
  if (typeof value !== 'string') return value;
  if (value === 'REPLACED_AT_LOAD') return new Date(nowMs).toISOString();
  const m = /^STALE_(\d+)([MS])$/.exec(value);
  if (!m) return value;
  const seconds = Number(m[1]) * (m[2] === 'M' ? 60 : 1);
  return new Date(nowMs - seconds * 1000).toISOString();
}

export function hydrateFixture(body, nowMs = Date.now()) {
  if (!body || typeof body !== 'object') return body;
  const out = { ...body, generated_at: resolve(body.generated_at, nowMs) };
  if (Array.isArray(body.members)) {
    out.members = body.members.map((m) => ({
      ...m,
      updated_at: resolve(m.updated_at, nowMs),
    }));
  }
  return out;
}
