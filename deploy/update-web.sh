#!/usr/bin/env bash
# Incremental static-client deployment. Existing websites and databases stay in place.
set -euo pipefail
test "$EUID" -eq 0 || { echo 'Run with sudo.' >&2; exit 1; }
archive=${1:?Usage: update-web.sh /absolute/path/Campulse-Web.zip}
test -f "$archive"
public=/opt/campus/pocketbase/pb_public
test -d "$public"
stage=$(mktemp -d /opt/campus/web-stage.XXXXXX)
unzip -q "$archive" -d "$stage"
test -f "$stage/index.html"
test -f "$stage/main.dart.js"
test -f "$stage/version.json"
grep -q '<base href="/app/">' "$stage/index.html"
chmod -R a+rX "$stage"
backup="/opt/campus/backups/web-$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$backup"
if [[ -e "$public/app" ]]; then mv "$public/app" "$backup/app"; fi
if ! mv "$stage" "$public/app"; then
  if [[ -e "$backup/app" ]]; then mv "$backup/app" "$public/app"; fi
  exit 1
fi
printf 'Web deployed. Recovery point: %s\n' "$backup"
