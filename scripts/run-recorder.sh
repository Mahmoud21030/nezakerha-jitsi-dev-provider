#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime recordings
export DISPLAY=:99

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

record_seconds=$(( MAX_MINUTES * 60 ))

rc=0
timeout --signal=INT "$record_seconds" ffmpeg -y   -thread_queue_size 1024   -f x11grab -framerate 25 -video_size 1280x720 -i :99.0   -thread_queue_size 1024   -f pulse -i recording.monitor   -c:v libx264 -preset veryfast -crf 25 -pix_fmt yuv420p   -c:a aac -b:a 128k   -movflags +faststart   "recordings/$SESSION_ID.mp4" > runtime/ffmpeg.log 2>&1 || rc=$?

kill "$room_pid" 2>/dev/null || true
wait "$room_pid" 2>/dev/null || true

if [[ "$rc" != "0" && "$rc" != "124" ]]; then
  cat runtime/ffmpeg.log
  echo "::error::FFmpeg failed with code $rc."
  exit "$rc"
fi
