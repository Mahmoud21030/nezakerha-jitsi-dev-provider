#!/usr/bin/env bash
set -euo pipefail

curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/" >/dev/null
curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/config.js" >/dev/null

cd runtime/docker-jitsi-meet
docker compose ps --status running | grep -q "jvb"
docker compose ps --status running | grep -q "jicofo"
docker compose ps --status running | grep -q "prosody"
docker compose ps --status running | grep -q "web"

echo "Provider smoke checks passed."
