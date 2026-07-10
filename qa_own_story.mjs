import puppeteer from 'puppeteer';

const DISPLAY = ':0';

const shot = async (page, name) => {
  const p = `/tmp/qa_${name}.png`;
  await page.screenshot({ path: p });
  console.log(`📸 ${name} → ${p}`);
};

const wait = (ms) => new Promise(r => setTimeout(r, ms));

// Click based on visual coordinate (mapped from 390x844 logical viewport)
const clickAt = async (page, x, y) => {
  await page.mouse.click(x, y);
  console.log(`  🖱️  clicked (${x}, ${y})`);
};

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: false,
    env: { ...process.env, DISPLAY },
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--window-size=390,844',
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream',
    ],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error(`[ERR] ${e.message.substring(0, 150)}`));
  page.on('console', m => {
    const t = m.text();
    if (!t.includes('GL Driver') && !t.includes('DDC') && !t.includes('TrustedTypes') && !t.includes('webGLVersion'))
      console.log(`  [app] ${t.substring(0, 120)}`);
  });

  // ── Step 1: Auth ─────────────────────────────────────────────────────
  console.log('\n══ STEP 1: Auth ══');
  await page.goto('http://localhost:8084/', { waitUntil: 'networkidle0', timeout: 30000 });
  await wait(12000);
  await shot(page, '01_auth');
  // "Continue as guest" button is approximately at bottom-center
  await clickAt(page, 195, 700);
  await wait(8000);

  // ── Step 2: Role ─────────────────────────────────────────────────────
  console.log('\n══ STEP 2: Role ══');
  await shot(page, '02_role');
  // "Parent" chip - top-left of wrap area
  await clickAt(page, 75, 280);
  await wait(500);
  // "Continue →" - bottom primary button
  await clickAt(page, 195, 760);
  await wait(5000);

  // ── Step 3: Loved Ones ───────────────────────────────────────────────
  console.log('\n══ STEP 3: Loved Ones ══');
  await shot(page, '03_loved_ones');
  // "Skip for now" - small link near bottom
  await clickAt(page, 195, 790);
  await wait(5000);

  // ── Step 4: Library ──────────────────────────────────────────────────
  console.log('\n══ STEP 4: Library ══');
  await shot(page, '04_library');
  // Navigate directly to /own-title
  const curUrl = await page.url();
  console.log('  Current URL:', curUrl);
  await page.evaluate(() => { window.location.hash = '#/own-title'; });
  await wait(4000);

  // ── Step 5: Own Title ────────────────────────────────────────────────
  console.log('\n══ STEP 5: Own Title ══');
  await shot(page, '05_own_title');
  // Click text field (centered in screen, below the heading)
  await clickAt(page, 195, 420);
  await wait(500);
  await page.keyboard.type('My bedtime story');
  await wait(800);
  await shot(page, '05b_typed');
  // "Continue →" button - bottom primary
  await clickAt(page, 195, 760);
  await wait(5000);

  // ── Step 6: Mic setup ────────────────────────────────────────────────
  console.log('\n══ STEP 6: Mic setup ══');
  await shot(page, '06_mic_before');
  // "Test microphone" secondary button - roughly center
  await clickAt(page, 195, 450);
  await wait(5000);
  await shot(page, '06b_mic_confirmed');
  // "Continue →" - bottom
  await clickAt(page, 195, 760);
  await wait(5000);

  // ── Step 7: Video setup ──────────────────────────────────────────────
  console.log('\n══ STEP 7: Video setup ══');
  await shot(page, '07_video');
  await wait(3000);
  await shot(page, '07b_camera_ready');
  // "Start recording →" - bottom primary
  await clickAt(page, 195, 760);
  await wait(12000);

  // ── Step 8: Recording ────────────────────────────────────────────────
  console.log('\n══ STEP 8: Recording ══');
  await shot(page, '08_recording');
  const finalUrl = await page.url();
  console.log('  Final URL:', finalUrl);

  await browser.close();
  console.log('\n✅ All screenshots saved to /tmp/qa_*.png');
})();
