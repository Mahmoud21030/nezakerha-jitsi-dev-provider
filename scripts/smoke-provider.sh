#!/usr/bin/env bash
set -euo pipefail

curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/" >/dev/null
curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/config.js" >/dev/null

browser_body="$(mktemp)"
curl -fsS --retry 20 --retry-delay 2 \
  -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140 Safari/537.36' \
  "$MEET_URL/" -o "$browser_body"
if ! grep -qiE 'jitsi|config\.js|app\.bundle' "$browser_body"; then
  echo "::error::Browser-like request did not return the Jitsi page through the HTTP tunnel."
  rm -f "$browser_body"
  exit 1
fi
rm -f "$browser_body"
echo "Browser-like request reaches Jitsi through the public HTTPS tunnel."

cd runtime/docker-jitsi-meet

for _ in $(seq 1 30); do
  running="$(docker compose ps --status running --services | sort | tr '\n' ' ')"
  if grep -qw web <<<"$running" &&
     grep -qw prosody <<<"$running" &&
     grep -qw jicofo <<<"$running" &&
     grep -qw jvb <<<"$running"; then
    sleep 8
    running2="$(docker compose ps --status running --services | sort | tr '\n' ' ')"
    if grep -qw web <<<"$running2" &&
       grep -qw prosody <<<"$running2" &&
       grep -qw jicofo <<<"$running2" &&
       grep -qw jvb <<<"$running2"; then
      echo "Provider smoke checks passed with all core services stable."
      exit 0
    fi
  fi
  sleep 2
done

echo "::error::Jitsi core services are not stably running."
docker compose ps
docker compose logs --tail=160 web prosody jicofo jvb
exit 1
