#!/usr/bin/env bash
set -euo pipefail

: "${MEET_URL:?MEET_URL is required}"
: "${JVB_PUBLIC_IP:?JVB_PUBLIC_IP is required}"
: "${JVB_PUBLIC_PORT:?JVB_PUBLIC_PORT is required}"

mkdir -p runtime
if [[ ! -d runtime/docker-jitsi-meet/.git ]]; then
  git clone --depth 1 https://github.com/jitsi/docker-jitsi-meet.git runtime/docker-jitsi-meet
fi

cd runtime/docker-jitsi-meet
cp env.example .env
./gen-passwords.sh
CONFIG_DIR="$PWD/.jitsi-cfg"
mkdir -p "$CONFIG_DIR"

cat >> .env <<EOF

CONFIG=$CONFIG_DIR
HTTP_PORT=8000
HTTPS_PORT=8443
TZ=UTC
PUBLIC_URL=$MEET_URL
ENABLE_AUTH=0
ENABLE_GUESTS=1
ENABLE_PREJOIN_PAGE=0
ENABLE_WELCOME_PAGE=0
ENABLE_P2P=0
ENABLE_HTTP_REDIRECT=0
DISABLE_HTTPS=1
JVB_PORT=10000
JVB_ADVERTISE_IPS=$JVB_PUBLIC_IP#$JVB_PUBLIC_PORT
EOF

docker compose up -d web prosody jicofo jvb

for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8000/ >/dev/null; then
    echo "Jitsi stack ready."
    exit 0
  fi
  sleep 2
done

docker compose ps
docker compose logs --tail=120 web jvb jicofo prosody
exit 1
