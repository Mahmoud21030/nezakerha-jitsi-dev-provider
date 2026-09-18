#!/usr/bin/env bash
set -euo pipefail

required=(SESSION_ID ROOM_NAME MAX_MINUTES PORTMAP_OVPN_B64 PORTMAP_PUBLIC_HOST PORTMAP_PUBLIC_PORT)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing required value: $name"
    exit 1
  fi
done

if ! [[ "$PORTMAP_PUBLIC_PORT" =~ ^[0-9]+$ ]] || (( PORTMAP_PUBLIC_PORT < 1 || PORTMAP_PUBLIC_PORT > 65535 )); then
  echo "::error::PORTMAP_PUBLIC_PORT must be a valid UDP port"
  exit 1
fi

if ! [[ "$MAX_MINUTES" =~ ^[0-9]+$ ]] || (( MAX_MINUTES < 1 || MAX_MINUTES > 300 )); then
  echo "::error::MAX_MINUTES must be between 1 and 300"
  exit 1
fi

if ! [[ "$ROOM_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "::error::ROOM_NAME may only contain letters, digits, underscore and dash"
  exit 1
fi

echo "Provider inputs validated for session $SESSION_ID"
