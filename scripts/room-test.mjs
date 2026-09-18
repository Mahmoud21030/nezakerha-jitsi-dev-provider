import { chromium } from 'playwright';

const meetUrl = process.env.MEET_URL;
const roomName = process.env.ROOM_NAME;

if (!meetUrl || !roomName) {
  throw new Error('MEET_URL and ROOM_NAME are required');
}

function roomUrl({ publish }) {
  const args = [
    'config.prejoinPageEnabled=false',
    'config.p2p.enabled=false',
    `config.startWithAudioMuted=${publish ? 'false' : 'true'}`,
    `config.startWithVideoMuted=${publish ? 'false' : 'true'}`,
    `config.channelLastN=${publish ? '0' : '-1'}`,
    'config.disableDeepLinking=true'
  ];

  return `${meetUrl.replace(/\/$/, '')}/${roomName}#${args.join('&')}`;
}

async function waitJoined(page, label) {
  await page.waitForFunction(
    () => Boolean(window.APP?.conference?.isJoined?.()),
    undefined,
    { timeout: 90000 }
  );

  await page.evaluate(name => {
    try {
      window.APP?.conference?.changeLocalDisplayName?.(name);
    } catch {}
  }, label);

  console.log(`JITSI_JOINED:${label}`);
}

const recorder = await chromium.launch({
  headless: false,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--autoplay-policy=no-user-gesture-required',
    '--disable-dev-shm-usage'
  ]
});

const recorderPage = await recorder.newPage({ viewport: { width: 1280, height: 720 } });
recorderPage.on('console', message => {
  const value = message.text();
  if (/error|failed|ice|conference/i.test(value)) {
    console.log('RECORDER_CONSOLE ' + value);
  }
});

await recorderPage.goto(roomUrl({ publish: false }), {
  waitUntil: 'domcontentloaded',
  timeout: 120000
});

const publisher = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--autoplay-policy=no-user-gesture-required',
    '--disable-dev-shm-usage',
    '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream'
  ]
});

const publisherPage = await publisher.newPage({ viewport: { width: 640, height: 360 } });
publisherPage.on('console', message => {
  const value = message.text();
  if (/error|failed|ice|conference/i.test(value)) {
    console.log('PUBLISHER_CONSOLE ' + value);
  }
});

await publisherPage.goto(roomUrl({ publish: true }), {
  waitUntil: 'domcontentloaded',
  timeout: 120000
});

await Promise.all([
  waitJoined(recorderPage, 'QA Recorder'),
  waitJoined(publisherPage, 'QA Publisher')
]);

await recorderPage.waitForFunction(
  () => Number(window.APP?.conference?.membersCount || 0) >= 2,
  undefined,
  { timeout: 90000 }
);

const members = await recorderPage.evaluate(() => Number(window.APP?.conference?.membersCount || 0));
console.log(`RECORDER_MEMBERS:${members}`);

await new Promise(resolve => setTimeout(resolve, 8000));
await recorderPage.screenshot({ path: 'runtime/recorder-ready.png' });

console.log('ROOM_TEST_READY');

const shutdown = async () => {
  await Promise.allSettled([
    publisherPage.evaluate(() => window.APP?.conference?.hangup?.()).catch(() => {}),
    recorderPage.evaluate(() => window.APP?.conference?.hangup?.()).catch(() => {})
  ]);
  await Promise.allSettled([publisher.close(), recorder.close()]);
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

await new Promise(() => {});
