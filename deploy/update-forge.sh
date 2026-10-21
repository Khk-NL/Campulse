#!/usr/bin/env bash
# Upgrade the project library from a verified source snapshot, preserving the existing installation.
set -euo pipefail
test "$EUID" -eq 0 || { echo 'Run with sudo.' >&2; exit 1; }
source_dir=$(realpath "${1:?Usage: update-forge.sh VERIFIED_SOURCE_DIRECTORY}")
runtime=/opt/campus/ai-gateway
pocketbase=/opt/campus/pocketbase
export PATH=/opt/campus/runtime/node-v22.23.3-linux-x64/bin:$PATH
test -f "$pocketbase/pb_data/data.db"
test -f "$source_dir/apps/ai-gateway/src/forge.mjs"
test -f "$source_dir/deploy/pocketbase/pb_migrations/1790210014_forge_library.js"
for directory in src test; do
  test -d "$source_dir/apps/ai-gateway/$directory" || { echo "Missing gateway source directory: $directory" >&2; exit 1; }
done
for file in forge.test.mjs server.test.mjs; do test -f "$source_dir/apps/ai-gateway/test/$file"; done
# This feature adds no npm dependency. A changed lockfile needs its own dependency upgrade.
cmp "$source_dir/apps/ai-gateway/package-lock.json" "$runtime/package-lock.json"
for file in server.mjs forge.mjs; do node --check "$source_dir/apps/ai-gateway/src/$file"; done
stage=$(mktemp -d /opt/campus/forge-check.XXXXXX)
cp -R "$source_dir/apps/ai-gateway/src" "$source_dir/apps/ai-gateway/test" "$stage/"
cp "$source_dir/apps/ai-gateway/package.json" "$source_dir/apps/ai-gateway/package-lock.json" "$stage/"
ln -s "$runtime/node_modules" "$stage/node_modules"
chown -R campus:campus "$stage"
cd "$stage"
sudo -u campus "$(command -v node)" --test test/forge.test.mjs test/server.test.mjs
backup="/opt/campus/backups/forge-library-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$backup"
cp -a "$runtime" "$backup/ai-gateway"
install -d -m 0700 "$backup/admin-assets"
cp -a "$pocketbase/pb_public/assets/admin-client.mjs" "$pocketbase/pb_public/assets/admin.mjs" "$backup/admin-assets/"
systemctl stop campus-pocketbase
trap 'systemctl start campus-pocketbase' EXIT
cp -a "$pocketbase/pb_data" "$pocketbase/pb_migrations" "$backup/"
cmp "$pocketbase/pb_data/data.db" "$backup/pb_data/data.db"
migration=1790210014_forge_library.js
if [[ -f "$pocketbase/pb_migrations/$migration" ]]; then
  cmp "$pocketbase/pb_migrations/$migration" "$source_dir/deploy/pocketbase/pb_migrations/$migration"
fi
install -m 0644 "$source_dir/deploy/pocketbase/pb_migrations/$migration" "$pocketbase/pb_migrations/$migration"
restore_database() {
  result=$?
  trap - EXIT
  # Preserve the failed attempt while restoring the stopped, consistent snapshot.
  systemctl stop campus-pocketbase
  mv "$pocketbase/pb_data" "$backup/failed-pb_data"
  mv "$pocketbase/pb_migrations" "$backup/failed-pb_migrations"
  cp -a "$backup/pb_data" "$backup/pb_migrations" "$pocketbase/"
  systemctl start campus-pocketbase
  exit "$result"
}
trap restore_database EXIT
cd "$pocketbase"
sudo -u campus ./pocketbase migrate up
systemctl start campus-pocketbase
trap - EXIT
install -d -m 0755 "$runtime/test"
systemctl stop campus-ai
restore_gateway() {
  result=$?
  trap - EXIT
  cp -a "$backup/ai-gateway/src/." "$runtime/src/"
  for file in admin-client.mjs admin.mjs; do
    cp -a "$backup/admin-assets/$file" "$pocketbase/pb_public/assets/$file"
  done
  systemctl restart campus-ai
  exit "$result"
}
trap restore_gateway EXIT
for file in server.mjs forge.mjs; do
  install -o root -g campus -m 0644 "$source_dir/apps/ai-gateway/src/$file" "$runtime/src/$file"
done
install -o root -g campus -m 0644 "$source_dir/apps/ai-gateway/test/forge.test.mjs" "$runtime/test/forge.test.mjs"
install -o root -g campus -m 0644 "$source_dir/apps/ai-gateway/test/server.test.mjs" "$runtime/test/server.test.mjs"
for file in admin-client.mjs admin.mjs; do
  install -m 0644 "$source_dir/deploy/pocketbase/pb_public/assets/$file" "$pocketbase/pb_public/assets/$file"
done
systemctl start campus-ai
systemctl is-active campus-pocketbase campus-ai
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 --max-time 15 http://127.0.0.1:8090/api/health
# This endpoint intentionally requires a user session; 401 confirms the new route is listening.
gateway_status=$(curl --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 --max-time 15 \
  --output /dev/null --write-out '%{http_code}' http://127.0.0.1:8787/v1/forge/status)
test "$gateway_status" = 401
trap - EXIT
printf '\nProject library deployed. Recovery point: %s\n' "$backup"
