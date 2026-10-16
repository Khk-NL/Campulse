#!/usr/bin/env bash
set -euo pipefail
test "$EUID" -eq 0 || { echo 'Run with sudo'; exit 1; }
commit="${1:?Usage: update-community.sh SOURCE_COMMIT}"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full commit'; exit 1; }
root=/opt/campus/pocketbase
test -f "$root/pb_data/data.db"
test -x "$root/pocketbase"
file="${2:-1790210010_forge_community.js}"
[[ "$file" =~ ^179021001[01]_forge_[a-z_]+\.js$ || "$file" == '1790210012_user_relationships.js' || "$file" == '1790210013_campus_square.js' ]] || { echo 'Expected a supported migration'; exit 1; }
staging=$(mktemp -d /tmp/campulse-community.XXXXXX)
node=/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node
curl --fail --silent --show-error --retry 2 --connect-timeout 15 --max-time 60 \
  "https://api.github.com/repos/Khk-NL/Campulse/contents/deploy/pocketbase/pb_migrations/$file?ref=$commit" -o "$staging/source.json"
"$node" -e 'const fs=require("node:fs"),crypto=require("node:crypto");const row=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));if(row.encoding!=="base64")throw Error("Expected base64");const data=Buffer.from(row.content,"base64");const hash=crypto.createHash("sha1").update(`blob ${data.length}\0`).update(data).digest("hex");if(hash!==row.sha)throw Error("Blob mismatch");fs.writeFileSync(process.argv[2],data);' "$staging/source.json" "$staging/$file"
"$node" --check "$staging/$file"
if [[ -f "$root/pb_migrations/$file" ]]; then
  cmp "$root/pb_migrations/$file" "$staging/$file" || { echo 'Installed migration differs; inspect before continuing'; exit 1; }
fi
backup="/opt/campus/backups/community-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$backup"
# Stop only PocketBase while copying SQLite/WAL and attachments consistently.
trap 'systemctl start campus-pocketbase' EXIT
systemctl stop campus-pocketbase
cp -a "$root/pb_data" "$root/pb_migrations" "$backup/"
test -s "$backup/pb_data/data.db"
install -m 0644 "$staging/$file" "$root/pb_migrations/$file"
cd "$root"
sudo -u campus ./pocketbase migrate up
systemctl start campus-pocketbase
systemctl is-active --quiet campus-pocketbase
trap - EXIT
curl --fail --silent --show-error --retry 3 --retry-connrefused --max-time 15 http://127.0.0.1:8090/api/health
printf '\nCommunity source: %s\nBackup: %s\n' "$commit" "$backup"
