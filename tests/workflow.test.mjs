import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const root = new URL('../', import.meta.url)
const read = name => readFile(new URL(name, root), 'utf8')

test('workflow keeps one-session one-job lifecycle with callbacks and direct upload', async () => {
  const workflow = await read('.github/workflows/provider.yml')
  assert.match(workflow, /concurrency:\s*[\s\S]*group: live-\$\{\{ inputs\.session_id \}\}/)
  assert.match(workflow, /live_id:/)
  assert.match(workflow, /callback_url:/)
  assert.match(workflow, /DEV_LIVE_CALLBACK_SECRET/)
  assert.match(workflow, /DEV_LIVE_RECORDER_SECRET/)
  assert.match(workflow, /provider-callback\.py provider_ready/)
  assert.match(workflow, /provider-callback\.py uploading/)
  assert.match(workflow, /upload-recording\.py/)
  assert.match(workflow, /provider-callback\.py completed/)
  assert.match(workflow, /provider-callback\.py failed/)
})

test('recorder polls the scoped control endpoint and finalizes ffmpeg', async () => {
  const script = await read('scripts/run-recorder.sh')
  assert.match(script, /RECORDER_TOKEN/)
  assert.match(script, /\/control/)
  assert.match(script, /stopRequested/)
  assert.match(script, /kill -INT "\$ffmpeg_pid"/)
})

test('recording bytes upload to signed storage urls instead of callback body', async () => {
  const script = await read('scripts/upload-recording.py')
  assert.match(script, /recording\/start/)
  assert.match(script, /recording\/\{asset_id\}\/part/)
  assert.match(script, /upload_url = signed\["url"\]/)
  assert.match(script, /telegram-chunked/)
  assert.match(script, /s3-multipart/)
  assert.match(script, /recording\/\{asset_id\}\/complete/)
})

test('callback is HMAC signed and recorder credential is scoped', async () => {
  const callback = await read('scripts/provider-callback.py')
  const token = await read('scripts/make-recorder-token.py')
  assert.match(callback, /hmac\.new\(secret\.encode\(\), body, hashlib\.sha256\)/)
  assert.match(callback, /X-Nezakerha-Signature/)
  assert.match(token, /"liveId": live_id/)
  assert.match(token, /"providerSessionId": session_id/)
  assert.match(token, /"exp":/)
  assert.match(token, /hmac\.new\(secret\.encode\(\), encoded\.encode\(\), hashlib\.sha256\)/)
})
