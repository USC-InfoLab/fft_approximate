#!/usr/bin/env bash
# Admin-only install of fft_approximate into one database.
#
#   PG_CONFIG=/path/to/pg_config PGUSER=admin PGDATABASE=w4h ./install.sh
#
# Optional: PGHOST, PGPORT, PGPASSWORD. Run with --check to only verify access.
#
# This is a C extension: its code runs inside the Postgres server, so a bug can
# crash the server for every user. Postgres itself only lets a superuser run
# CREATE EXTENSION for it (the control file is not marked trusted). This script
# checks that up front so a non-admin gets a clear message instead of a
# permission error halfway through.
set -euo pipefail

cd "$(dirname "$0")"

if [ -z "${PG_CONFIG:-}" ]; then
  echo "Set PG_CONFIG to your server's pg_config (see README, step 0)." >&2
  exit 1
fi
if [ -z "${PGUSER:-}" ] || [ -z "${PGDATABASE:-}" ]; then
  echo "Set PGUSER and PGDATABASE (optional: PGHOST, PGPORT, PGPASSWORD)." >&2
  exit 1
fi
export PGUSER PGDATABASE

PSQL="$("$PG_CONFIG" --bindir)/psql"

is_super="$("$PSQL" -v ON_ERROR_STOP=1 -Atc "SELECT rolsuper FROM pg_roles WHERE rolname = current_user")"
if [ "$is_super" != "t" ]; then
  echo "Refusing to install: role '$PGUSER' is not a superuser on '$PGDATABASE'." >&2
  echo "fft_approximate is a C extension and must be installed by a database admin." >&2
  exit 1
fi
echo "OK: '$PGUSER' is a superuser on '$PGDATABASE'."

if [ "${1:-}" = "--check" ]; then
  exit 0
fi

make PG_CONFIG="$PG_CONFIG"
make PG_CONFIG="$PG_CONFIG" install
make PG_CONFIG="$PG_CONFIG" load
"$PSQL" -Atc "SELECT 'installed: ' || extname || ' ' || extversion FROM pg_extension WHERE extname = 'fft_approximate'"
