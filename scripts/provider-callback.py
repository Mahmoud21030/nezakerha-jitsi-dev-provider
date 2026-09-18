#!/usr/bin/env python3
import hashlib, hmac, json, os, sys, time, urllib.request, urllib.error

status = sys.argv[1] if len(sys.argv) > 1 else ""
callback_url = os.getenv("CALLBACK_URL", "").strip()
secret = os.getenv("CALLBACK_SECRET", "").strip()
session_id = os.getenv("SESSION_ID", "").strip()
run_id = os.getenv("GITHUB_RUN_ID", "").strip()

if not callback_url or not secret:
    print(f"Callback not configured; skipping {status}.")
    sys.exit(0)

payload = {"sessionId": session_id, "status": status}
if run_id:
    payload["runId"] = run_id
meeting_url = os.getenv("MEET_URL", "").strip()
if status == "provider_ready" and meeting_url:
    payload["meetingUrl"] = meeting_url
recording_status = os.getenv("RECORDING_STATUS", "").strip()
if recording_status:
    payload["recordingStatus"] = recording_status
asset_id = os.getenv("RECORDING_ASSET_ID", "").strip()
if asset_id:
    payload["recordingAssetId"] = asset_id
failure = os.getenv("FAILURE_REASON", "").strip()
if failure:
    payload["failureReason"] = failure[:180]

body = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode()
signature = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

last_error = None
for attempt in range(3):
    try:
        req = urllib.request.Request(
            callback_url,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "X-Nezakerha-Signature": signature,
                "User-Agent": "nezakerha-jitsi-dev-provider/1.0",
            },
        )
        with urllib.request.urlopen(req, timeout=20) as response:
            if response.status < 200 or response.status >= 300:
                raise RuntimeError(f"callback HTTP {response.status}")
        print(f"Callback delivered: {status}")
        sys.exit(0)
    except Exception as exc:
        last_error = exc
        if attempt < 2:
            time.sleep(2 ** attempt)

raise SystemExit(f"Callback failed for {status}: {last_error}")
