#!/usr/bin/env bash
set +e

echo "=== resources ==="
free -h
df -h

echo "=== pinggy udp ==="
tail -n 80 runtime/pinggy-udp.log 2>/dev/null || true

echo "=== pinggy http ==="
tail -n 80 runtime/pinggy-http.log 2>/dev/null || true

echo "=== jitsi ==="
if [[ -d runtime/docker-jitsi-meet ]]; then
  cd runtime/docker-jitsi-meet
  docker compose ps
  docker compose logs --tail=100 jvb jicofo web prosody
fi
