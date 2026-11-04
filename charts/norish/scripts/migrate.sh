#!/bin/sh
# Postgres 18 keeps its data in /var/lib/postgresql/18/docker and exits if a
# 17 directory is still at the volume root. Dump that database, then move the
# files aside so 18 can initdb. Once PG_VERSION is gone from the root, this
# does nothing.
set -eu

root=/var/lib/postgresql

if [ ! -s "$root/PG_VERSION" ]; then
  exit 0
fi

version=$(cat "$root/PG_VERSION")
if [ "$version" != "17" ]; then
  printf 'found Postgres %s at the volume root; this step only moves 17\n' "$version" >&2
  exit 1
fi

mkdir -p /var/run/postgresql "$root/migrate"
chown postgres:postgres /var/run/postgresql "$root/migrate"

if ! gosu postgres pg_ctl -D "$root" -w -l /tmp/pg17.log \
  -o "-c listen_addresses='' -c unix_socket_directories=/var/run/postgresql" start; then
  cat /tmp/pg17.log >&2 || true
  exit 1
fi

gosu postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner --no-acl \
  -f "$root/migrate/norish.dump"
gosu postgres pg_ctl -D "$root" -w -m fast stop

if [ ! -s "$root/migrate/norish.dump" ]; then
  printf 'pg_dump wrote an empty file\n' >&2
  exit 1
fi

mkdir -p "$root/.pg17-aside"
for entry in "$root"/* "$root"/.[!.]* "$root"/..?*; do
  [ -e "$entry" ] || continue
  name=${entry##*/}
  case "$name" in
    migrate | .pg17-aside) continue ;;
  esac
  mv "$entry" "$root/.pg17-aside/"
done
