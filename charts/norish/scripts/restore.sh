#!/bin/sh
# The Postgres image runs this after initdb, and only on a new data directory.
# The dump was taken from 17 by the migrate init container.
set -eu

dump=/var/lib/postgresql/migrate/norish.dump
if [ ! -s "$dump" ]; then
  exit 0
fi

# pg_dump omits CREATE SCHEMA public. Recreate it, and drop drizzle so the
# restore can create that schema itself.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
DROP SCHEMA IF EXISTS drizzle CASCADE;
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT ALL ON SCHEMA public TO public;
SQL
pg_restore --no-owner --no-acl --exit-on-error \
  --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" "$dump"
mv "$dump" /var/lib/postgresql/migrate/norish.dump.done
