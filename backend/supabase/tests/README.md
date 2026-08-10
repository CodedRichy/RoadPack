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
