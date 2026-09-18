# Nezakerha Temporary Jitsi Dev Provider

Development/QA-only temporary meeting provider.

## Runtime
- Provider runner: Jitsi Meet + JVB.
- Web endpoint: Cloudflare Quick Tunnel.
- Media endpoint: Portmap/OpenVPN UDP forwarding to JVB.
- Recorder runner: separate GitHub-hosted runner using Chromium + Xvfb + FFmpeg.
- The provider dispatches the recorder after the meeting endpoint is ready, so both runners run concurrently.

## Required GitHub repository secrets
- PORTMAP_OVPN_B64
- PORTMAP_PUBLIC_HOST
- PORTMAP_PUBLIC_PORT

Do not place Nezakerha production credentials in this public repository.

## Scope
This is a temporary development/QA provider, not a production backend.
