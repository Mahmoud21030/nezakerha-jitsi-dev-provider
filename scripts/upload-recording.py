#!/usr/bin/env python3
import json, os, pathlib, sys, urllib.request, urllib.error

session_id = os.environ["SESSION_ID"]
callback_url = os.environ["CALLBACK_URL"].strip()
token = os.environ["RECORDER_TOKEN"].strip()
recording = pathlib.Path("recordings") / f"{session_id}.mp4"
if not recording.is_file() or recording.stat().st_size <= 0:
    raise SystemExit("Recording file is missing.")

api_root = callback_url.rsplit("/callback", 1)[0]
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "User-Agent": "nezakerha-jitsi-recorder/1.0",
}

def json_request(url, method="POST", payload=None):
    data = json.dumps(payload or {}, separators=(",", ":")).encode()
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=45) as response:
        return json.loads(response.read().decode() or "{}")

asset_id = None
try:
    started = json_request(f"{api_root}/recording/start")
    asset = started["asset"]
    asset_id = asset["id"]
    mode = asset["uploadMode"]
    if mode not in ("telegram-chunked", "s3-multipart"):
        raise RuntimeError(f"Unsupported recorder upload mode: {mode}")
    part_size = int(asset.get("partSize") or 8 * 1024 * 1024)
    limit = int(asset.get("uploadLimitBytes") or 0)
    total_size = recording.stat().st_size
    if limit and total_size > limit:
        raise RuntimeError("Recording exceeds upload limit.")

    completed_parts = []
    with recording.open("rb") as source:
        part_number = 1
        while True:
            chunk = source.read(part_size)
            if not chunk:
                break
            signed = json_request(f"{api_root}/recording/{asset_id}/part", payload={"partNumber": part_number})
            upload_url = signed["url"]
            upload_method = "POST" if mode == "telegram-chunked" else "PUT"
            req = urllib.request.Request(
                upload_url,
                data=chunk,
                method=upload_method,
                headers={"Content-Type": "application/octet-stream", "User-Agent": "nezakerha-jitsi-recorder/1.0"},
            )
            with urllib.request.urlopen(req, timeout=120) as response:
                response_body = response.read()
                if mode == "telegram-chunked":
                    uploaded = json.loads(response_body.decode() or "{}")
                    if not uploaded.get("ok"):
                        raise RuntimeError("Telegram gateway upload failed.")
                    json_request(
                        f"{api_root}/recording/{asset_id}/part",
                        method="PUT",
                        payload={
                            "partNumber": part_number,
                            "fileId": uploaded.get("fileId", ""),
                            "messageId": uploaded.get("messageId", 0),
                            "size": uploaded.get("size", len(chunk)),
                        },
                    )
                else:
                    etag = response.headers.get("ETag") or response.headers.get("etag")
                    if not etag:
                        raise RuntimeError("Multipart upload response did not include ETag.")
                    completed_parts.append({"partNumber": part_number, "etag": etag})
            print(f"Uploaded recording part {part_number} ({len(chunk)} bytes).")
            part_number += 1

    completed = json_request(
        f"{api_root}/recording/{asset_id}/complete",
        payload={"parts": completed_parts, "size": total_size},
    )
    ready = completed.get("asset") or {}
    if ready.get("status") != "ready":
        raise RuntimeError("Recording asset did not become ready.")

    output = os.getenv("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"recording_asset_id={asset_id}\n")
    print(f"Recording upload complete: {asset_id}")
except Exception:
    if asset_id:
        try:
            json_request(f"{api_root}/recording/{asset_id}/abort")
        except Exception:
            pass
    raise
