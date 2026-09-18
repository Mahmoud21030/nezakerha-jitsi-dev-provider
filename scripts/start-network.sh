#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime

pinggy --type udp -l 10000 > runtime/pinggy-udp.log 2>&1 &
echo $! > runtime/pinggy-udp.pid

udp_endpoint=""
for _ in $(seq 1 60); do
  udp_endpoint="$(grep -Eo 'udp://[^[:space:]]+:[0-9]+' runtime/pinggy-udp.log | head -n 1 || true)"
  [[ -n "$udp_endpoint" ]] && break
  sleep 1
done

if [[ -z "$udp_endpoint" ]]; then
  echo "::error::Pinggy UDP endpoint was not created."
  cat runtime/pinggy-udp.log || true
  exit 1
fi

udp_host="$(printf '%s' "$udp_endpoint" | sed -E 's#udp://([^:]+):([0-9]+).*#\1#')"
udp_port="$(printf '%s' "$udp_endpoint" | sed -E 's#udp://([^:]+):([0-9]+).*#\2#')"
udp_ip="$(getent ahostsv4 "$udp_host" | awk 'NR==1{print $1}')"

if [[ -z "$udp_ip" || -z "$udp_port" ]]; then
  echo "::error::Unable to resolve Pinggy UDP endpoint."
  exit 1
fi

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -R 80:127.0.0.1:8000 \
  nokey@localhost.run > runtime/localhost-run.log 2>&1 &
echo $! > runtime/http-tunnel.pid

meet_url=""
for _ in $(seq 1 90); do
  meet_url="$(grep -Eo 'https://[^[:space:]"<>]+' runtime/localhost-run.log | sed -E 's/[[:punct:]]$//' | head -n 1 || true)"
  if [[ "$meet_url" == https://* ]]; then
    break
  fi
  meet_url=""
  if ! kill -0 "$(cat runtime/http-tunnel.pid)" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [[ -z "$meet_url" ]]; then
  echo "::error::localhost.run HTTPS endpoint was not created."
  cat runtime/localhost-run.log || true
  exit 1
fi

echo "meet_url=$meet_url" >> "$GITHUB_OUTPUT"
echo "jvb_public_ip=$udp_ip" >> "$GITHUB_OUTPUT"
echo "jvb_public_port=$udp_port" >> "$GITHUB_OUTPUT"

echo "Meeting HTTPS endpoint ready."
echo "JVB UDP endpoint ready on public port $udp_port."
