# Database tests

pgTAP suites that run the real migrations against a throwaway Postgres.

```bash
bash backend/supabase/tests/run.sh
```

Requires Docker. The runner starts `supabase/postgres` (PostGIS + pg_cron +
pgTAP already inside), creates a fresh `roadpack_test` database, applies every
file in `../migrations` in order, then runs each `*.test.sql`. Each suite wraps
itself in `BEGIN … ROLLBACK`, so runs do not contaminate each other.

`supabase start` is deliberately not used: this repo's `config.toml` targets a
newer CLI than the one installed, and the suite should not depend on a full
local stack to check SQL.

## Suites

| File | Covers |
|---|---|
| `00017_pack_chainage.test.sql` | Pack Mode route-relative positioning: cumulative-distance integrity, chainage projection on straight / hairpin / self-crossing / out-and-back geometry, off-route detection, breadcrumb time gaps, gap suppression, and the pack RLS surface. |
| `00018_pack_lifecycle.test.sql` | Ride lifecycle: create / join / start / end / leave / role assignment, share-token issuance and revocation, status transitions, and the expiry sweep. |
| `00019_pack_tick.test.sql` | `pack-tick` support: aggregated gap computation, automatic status evaluation, `member_key` issuance and uniqueness, the anonymous viewer beacon, and snapshot lifecycle. |

## Deno suites

TypeScript tests for the edge functions. No Docker, no database.

```bash
deno test --allow-read --allow-env --allow-net \
  backend/supabase/functions/pack-tick/ \
  backend/supabase/tests/contact_notice_*.test.ts
```

| File | Covers |
|---|---|
| `functions/pack-tick/cascade_isolation.test.ts` | **The critical test in the suite** (TRD §5.2, PM-42). Asserts that a pack write which throws, rejects, or hangs cannot fail, alter, or delay the emergency alert cascade, that the pack push never reaches the cascade endpoint, that it carries no emergency-contact data, and — structurally, against the real source — that the production call site does not `await` it. |
| `functions/pack-tick/snapshot.test.ts` | Anonymous snapshot generation (PM-53). Refuses to publish a payload containing a user id, a phone-shaped string, or emergency-contact data anywhere in its structure, and refuses a position with no stated precision or finer than 50 m. Fail-closed by construction rather than by developer discipline. |
| `tests/contact_notice_handler.test.ts` | FR-024 claim-then-send semantics: possibly late, never twice. Claim release on send failure, opt-out skipped without releasing, DB row authoritative over a client-supplied phone. |
| `tests/contact_notice_segments.test.ts` | FR-104 SMS segment budget. Asserts EN / HI / ML each fit two segments, with Hindi and Malayalam measured as UCS-2 (67 chars per segment). Hindi has ~2 units of headroom, so this test is what stops a one-word copy edit silently pushing a safety SMS to three segments. |
| `tests/contact_notice_optout.test.ts` | STOP handling. Exact-keyword matching only, in English, Hindi and Malayalam, so "STOP THE CAR HE IS HURT" is not treated as an opt-out, plus a structural assertion that the existing acknowledgement path is unchanged. |

## How the geometry tests establish truth

Routes are **constructed**, not sampled from a map: `tst_walk` walks geodesic
steps with `ST_Project`, so the true chainage of vertex *k* is the sum of the
step lengths that built it, known independently of the code under test. A test
displaces a rider a known distance from a known vertex and asserts the
projection recovers that vertex's chainage.

Two tests are gates in the build-order sense — if they fail, route-relative
positioning does not work and nothing above it should be built:

- `hairpin GATE` — two anti-parallel legs 40 m apart, 1 km apart in chainage
- `crossing GATE` — a route that crosses itself, 0 m apart on the ground and
  1.8 km apart in chainage

Each is paired with a test proving the *unwindowed* search gets it wrong, so
the window is demonstrated to be load-bearing rather than assumed to be.
