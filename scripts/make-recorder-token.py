#!/usr/bin/env python3
import base64, hashlib, hmac, json, os, time

secret = os.environ["RECORDER_SECRET"].strip()
live_id = os.environ["LIVE_ID"].strip()
session_id = os.environ["SESSION_ID"].strip()
max_minutes = max(5, min(55, int(os.getenv("MAX_MINUTES", "55"))))
payload = {
    "v": 1,
    "liveId": live_id,
    "providerSessionId": session_id,
    "exp": int(time.time()) + max_minutes * 60 + 1800,
}
raw = json.dumps(payload, separators=(",", ":")).encode()
encoded = base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
signature = base64.urlsafe_b64encode(
    hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).digest()
).rstrip(b"=").decode()
token = f"r1.{encoded}.{signature}"

print(f"::add-mask::{token}")
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as handle:
    handle.write(f"RECORDER_TOKEN={token}\n")
