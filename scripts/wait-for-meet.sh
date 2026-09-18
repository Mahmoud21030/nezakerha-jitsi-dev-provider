#!/usr/bin/env bash
set -euo pipefail

room_url="${MEET_URL%/}/$ROOM_NAME"
for _ in $(seq 1 90); do
  if curl -fsS "$room_url" >/dev/null; then
    echo "Meeting endpoint reachable."
    exit 0
  fi
  sleep 2
done

echo "::error::Meeting endpoint never became reachable."
exit 1
