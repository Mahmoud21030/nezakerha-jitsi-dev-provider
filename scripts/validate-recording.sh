#!/usr/bin/env bash
set -euo pipefail

file="recordings/$SESSION_ID.mp4"
test -s "$file"

duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file")"
video_codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$file")"
audio_codec="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$file")"

echo "duration=$duration"
echo "video_codec=$video_codec"
echo "audio_codec=$audio_codec"

min_duration="10"
if [[ -f runtime/stop-requested ]]; then min_duration="1"; fi
python3 - "$duration" "$min_duration" <<'PY'
import sys
duration=float(sys.argv[1]); minimum=float(sys.argv[2])
if duration < minimum:
    raise SystemExit(f"recording too short: {duration:.2f}s < {minimum:.2f}s")
PY

test -n "$video_codec"
test -n "$audio_codec"

grep -q "ROOM_TEST_READY" runtime/room-test.log
grep -q "JITSI_JOINED:QA Recorder" runtime/room-test.log
grep -q "JITSI_JOINED:QA Publisher" runtime/room-test.log

echo "Recording validation passed."
