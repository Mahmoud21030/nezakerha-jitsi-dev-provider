#!/usr/bin/env bash
set -euo pipefail

curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/" >/dev/null
curl -fsS --retry 20 --retry-delay 2 "$MEET_URL/config.js" >/dev/null

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
