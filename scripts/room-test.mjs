import { chromium } from 'playwright';

const meetUrl = process.env.MEET_URL;
const roomName = process.env.ROOM_NAME;
if (!meetUrl || !roomName) throw new Error('MEET_URL and ROOM_NAME are required');

const domain = new URL(meetUrl).host;

function embedHtml(displayName, publish) {
  const config = {
    prejoinPageEnabled: false,
    startWithAudioMuted: !publish,
    startWithVideoMuted: !publish,
    disableDeepLinking: true,
    enableWelcomePage: false
  };
  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    html,body,#meet{margin:0;width:100%;height:100%;overflow:hidden;background:#111}
  </style>
</head>
<body>
  <div id="meet"></div>
  <script src="${meetUrl.replace(/\/$/, '')}/external_api.js"></script>
  <script>
    const api = new JitsiMeetExternalAPI(${JSON.stringify(domain)}, {
      roomName: ${JSON.stringify(roomName)},
      parentNode: document.getElementById('meet'),
      width: '100%',
      height: '100%',
      userInfo: { displayName: ${JSON.stringify(displayName)} },
      configOverwrite: ${JSON.stringify(config)}
    });
    api.addListener('videoConferenceJoined', () => console.log('JITSI_JOINED:${displayName}'));
    api.addListener('participantJoined', e => console.log('PARTICIPANT_JOINED:' + e.displayName));
    api.addListener('participantLeft', e => console.log('PARTICIPANT_LEFT:' + e.id));
    api.addListener('cameraError', e => console.log('CAMERA_ERROR:' + JSON.stringify(e)));
    api.addListener('micError', e => console.log('MIC_ERROR:' + JSON.stringify(e)));
  </script>
</body>
</html>`;
}

const recorder = await chromium.launch({
  headless: false,
  args: [
    '--no-sandbox',
    '--autoplay-policy=no-user-gesture-required',
    '--disable-dev-shm-usage'
  ]
});

let recorderJoined = false;
let publisherJoined = false;
let recorderSawPublisher = false;

const recorderPage = await recorder.newPage({ viewport: { width: 1280, height: 720 } });
recorderPage.on('console', m => {
  const value = m.text();
  console.log('RECORDER_CONSOLE ' + value);
  if (value.includes('JITSI_JOINED:QA Recorder')) recorderJoined = true;
  if (value.includes('PARTICIPANT_JOINED:QA Publisher')) recorderSawPublisher = true;
});
await recorderPage.setContent(embedHtml('QA Recorder', false), { waitUntil: 'domcontentloaded' });

const publisher = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox',
    '--autoplay-policy=no-user-gesture-required',
    '--disable-dev-shm-usage',
    '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream'
  ]
});

const publisherPage = await publisher.newPage({ viewport: { width: 640, height: 360 } });
publisherPage.on('console', m => {
  const value = m.text();
  console.log('PUBLISHER_CONSOLE ' + value);
  if (value.includes('JITSI_JOINED:QA Publisher')) publisherJoined = true;
});
await publisherPage.setContent(embedHtml('QA Publisher', true), { waitUntil: 'domcontentloaded' });

const deadline = Date.now() + 90000;
while (Date.now() < deadline) {
  if (recorderJoined && publisherJoined && recorderSawPublisher) break;
  await new Promise(r => setTimeout(r, 1000));
}

if (!recorderJoined || !publisherJoined || !recorderSawPublisher) {
  throw new Error(`Room readiness failed: recorder=${recorderJoined} publisher=${publisherJoined} recorderSawPublisher=${recorderSawPublisher}`);
}

await new Promise(r => setTimeout(r, 5000));
console.log('ROOM_TEST_READY');

const shutdown = async () => {
  await Promise.allSettled([publisher.close(), recorder.close()]);
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

await new Promise(() => {});
