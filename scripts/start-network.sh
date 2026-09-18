#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime

pinggy --type udp -l 10000 > runtime/pinggy.log 2>&1 &
echo $! > runtime/pinggy.pid

udp_endpoint=""
for _ in $(seq 1 60); do
  udp_endpoint="$(grep -Eo 'udp://[^[:space:]]+:[0-9]+' runtime/pinggy.log | head -n 1 || true)"
  [[ -n "$udp_endpoint" ]] && break
  sleep 1
done

if [[ -z "$udp_endpoint" ]]; then
  echo "::error::Pinggy UDP endpoint was not created."
  cat runtime/pinggy.log || true
  exit 1
fi

udp_host="$(printf '%s' "$udp_endpoint" | sed -E 's#udp://([^:]+):([0-9]+).*#\1#')"
udp_port="$(printf '%s' "$udp_endpoint" | sed -E 's#udp://([^:]+):([0-9]+).*#\2#')"
udp_ip="$(getent ahostsv4 "$udp_host" | awk 'NR==1{print $1}')"

if [[ -z "$udp_ip" || -z "$udp_port" ]]; then
  echo "::error::Unable to resolve Pinggy UDP endpoint."
  exit 1
fi

/tmp/cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8000 > runtime/cloudflared.log 2>&1 &
echo $! > runtime/cloudflared.pid

meet_url=""
for _ in $(seq 1 60); do
  meet_url="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' runtime/cloudflared.log | head -n 1 || true)"
  [[ -n "$meet_url" ]] && break
  sleep 1
done

if [[ -z "$meet_url" ]]; then
  echo "::error::Cloudflare Quick Tunnel URL was not created."
  tail -n 80 runtime/cloudflared.log || true
  exit 1
fi

echo "meet_url=$meet_url" >> "$GITHUB_OUTPUT"
echo "jvb_public_ip=$udp_ip" >> "$GITHUB_OUTPUT"
echo "jvb_public_port=$udp_port" >> "$GITHUB_OUTPUT"

echo "Meeting web endpoint ready."
echo "JVB UDP endpoint ready on public port $udp_port."
