#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime recordings
export DISPLAY=:99

xvfb_pid=""
room_pid=""
ffmpeg_pid=""

cleanup() {
  [[ -n "$room_pid" ]] && kill "$room_pid" 2>/dev/null || true
  [[ -n "$ffmpeg_pid" ]] && kill -INT "$ffmpeg_pid" 2>/dev/null || true
  [[ -n "$xvfb_pid" ]] && kill "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT

Xvfb :99 -screen 0 1280x720x24 -ac +extension RANDR > runtime/xvfb.log 2>&1 &
xvfb_pid=$!
echo "$xvfb_pid" > runtime/xvfb.pid
sleep 2

pulseaudio --start --exit-idle-time=-1
pactl load-module module-null-sink sink_name=recording sink_properties=device.description=Recording >/dev/null
pactl set-default-sink recording

node scripts/room-test.mjs > runtime/room-test.log 2>&1 &
room_pid=$!
echo "$room_pid" > runtime/room-test.pid

for _ in $(seq 1 90); do
  if grep -q "ROOM_TEST_READY" runtime/room-test.log 2>/dev/null; then
    break
  fi
  if ! kill -0 "$room_pid" 2>/dev/null; then
    cat runtime/room-test.log
    echo "::error::Room test exited before becoming ready."
    exit 1
  fi
  sleep 1
done

if ! grep -q "ROOM_TEST_READY" runtime/room-test.log 2>/dev/null; then
  cat runtime/room-test.log
  echo "::error::Room test did not become ready."
  exit 1
fi

python3 scripts/provider-callback.py recording

record_seconds=$(( MAX_MINUTES * 60 ))
deadline=$(( $(date +%s) + record_seconds ))

ffmpeg -y \
  -thread_queue_size 1024 \
  -f x11grab -framerate 25 -video_size 1280x720 -i :99.0 \
  -thread_queue_size 1024 \
  -f pulse -i recording.monitor \
  -c:v libx264 -preset veryfast -crf 25 -pix_fmt yuv420p \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  "recordings/$SESSION_ID.mp4" > runtime/ffmpeg.log 2>&1 &
ffmpeg_pid=$!

control_url=""
if [[ -n "${CALLBACK_URL:-}" ]]; then
  control_url="${CALLBACK_URL%/callback}/control"
fi

while kill -0 "$ffmpeg_pid" 2>/dev/null; do
  now="$(date +%s)"
  if [[ "$now" -ge "$deadline" ]]; then
    kill -INT "$ffmpeg_pid" 2>/dev/null || true
    break
  fi

  if [[ -n "$control_url" && -n "${RECORDER_TOKEN:-}" ]]; then
    control_json="$(curl -fsS --max-time 10 -H "Authorization: Bearer $RECORDER_TOKEN" "$control_url" 2>/dev/null || true)"
    if [[ -n "$control_json" ]] && python3 -c 'import json,sys; raise SystemExit(0 if json.loads(sys.stdin.read()).get("stopRequested") else 1)' <<<"$control_json"; then
      echo "Stop requested by Nezakerha; finalizing recording."
      touch runtime/stop-requested
      kill -INT "$ffmpeg_pid" 2>/dev/null || true
      break
    fi
  fi
  sleep 5
done

rc=0
wait "$ffmpeg_pid" || rc=$?
ffmpeg_pid=""

kill "$room_pid" 2>/dev/null || true
wait "$room_pid" 2>/dev/null || true
room_pid=""

if [[ "$rc" != "0" && "$rc" != "130" && "$rc" != "255" ]]; then
  cat runtime/ffmpeg.log
  echo "::error::FFmpeg failed with code $rc."
  exit "$rc"
fi
