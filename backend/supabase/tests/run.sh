#!/usr/bin/env bash
# Runs the pgTAP suite against a throwaway Postgres with PostGIS, pg_cron and
# pgTAP. Uses the supabase/postgres image directly rather than `supabase start`
# so the suite does not depend on a running local stack.
#
#   bash backend/supabase/tests/run.sh
#
# Requires Docker.

set -euo pipefail

IMAGE="${ROADPACK_PG_IMAGE:-public.ecr.aws/supabase/postgres:17.6.1.158}"
NAME="${ROADPACK_PG_CONTAINER:-roadpack-pgtest}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MIG="$ROOT/backend/supabase/migrations"
TESTS="$ROOT/backend/supabase/tests"

dexec() { MSYS_NO_PATHCONV=1 docker exec "$NAME" "$@"; }

if ! docker inspect "$NAME" >/dev/null 2>&1; then
  echo "starting $NAME ($IMAGE)"
  docker run -d --name "$NAME" -e POSTGRES_PASSWORD=postgres "$IMAGE" >/dev/null
fi
docker start "$NAME" >/dev/null 2>&1 || true

for _ in $(seq 1 60); do
  if dexec pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done

# Fresh schema every run: the migrations are the source of truth, not whatever
# state a previous run left behind.
# FORCE: the pg_cron background worker holds a connection to the test database.
dexec psql -U supabase_admin -d postgres -q \
  -c "DROP DATABASE IF EXISTS roadpack_test WITH (FORCE)" >/dev/null
dexec psql -U postgres -q -c "CREATE DATABASE roadpack_test" >/dev/null

# pg_cron refuses to install outside the database named in cron.database_name,
# and migrations 00005/00014 schedule jobs. Point it at the test database.
# The setting is postmaster-level, so it needs a restart, not a reload. It
# persists in postgresql.auto.conf, so this is a one-time cost per container.
current="$(dexec psql -U postgres -d postgres -t -A -c 'SHOW cron.database_name' | tr -d '\r')"
if [ "$current" != "roadpack_test" ]; then
  dexec psql -U supabase_admin -d postgres -q \
    -c "ALTER SYSTEM SET cron.database_name = 'roadpack_test'" >/dev/null
  docker restart "$NAME" >/dev/null
  for _ in $(seq 1 60); do
    if dexec pg_isready -U postgres >/dev/null 2>&1; then break; fi
    sleep 1
  done
  sleep 3
fi

# Must clear first: docker cp into an existing directory nests the source
# inside it, which would silently run yesterday's migrations.
dexec rm -rf /mig /tests
docker cp "$MIG" "$NAME:/mig" >/dev/null
docker cp "$TESTS" "$NAME:/tests" >/dev/null

for f in "$MIG"/*.sql; do
  b="$(basename "$f")"
  if ! dexec psql -U postgres -d roadpack_test -v ON_ERROR_STOP=1 -q -f "/mig/$b" >/dev/null 2>/tmp/mig_err; then
    echo "MIGRATION FAILED: $b"
    cat /tmp/mig_err
    exit 1
  fi
done

status=0
for f in "$TESTS"/*.test.sql; do
  b="$(basename "$f")"
  echo "== $b"
  dexec psql -U postgres -d roadpack_test -q -t -A -f "/tests/$b" || status=1
done
exit $status
