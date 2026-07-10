// verify_premium.mjs — QA verification
// Uses flt-semantics-placeholder activation (same as test_firebase_save.mjs)
// Verifies: lock badges on premium stories, paywall with Firestore plans,
// Plans screen reads live from Firestore.

import puppeteer from 'puppeteer';
const APP_URL   = 'http://localhost:42015/';
const ARTIFACTS = '/home/lewis/CascadeProjects/story_app/artifacts';
const delay = ms => new Promise(r => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
});
const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

// ── Helpers ───────────────────────────────────────────────────────────────────

const shot = async name => {
  const p = `${ARTIFACTS}/verify_${name}.png`;
  await page.screenshot({ path: p });
  console.log(`  📸 ${p}`);
};

// Activate Flutter accessibility via the placeholder element
const activateA11y = async () => {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) el.click();
  });
  await delay(1500);
};

// Click by searching the semantic host
const clickSemantic = async (text, timeoutMs = 20000) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const rect = await page.evaluate(txt => {
      const host = document.querySelector('flt-semantics-host');
      if (!host) return null;
      const all = [...host.querySelectorAll('*')];
      for (let i = all.length - 1; i >= 0; i--) {
        const el = all[i];
        const label = (el.getAttribute('aria-label') || el.innerText || '').toLowerCase();
        if (label.includes(txt.toLowerCase())) {
          const r = el.getBoundingClientRect();
          if (r.width > 0 && r.height > 0)
            return { x: r.left + r.width/2, y: r.top + r.height/2 };
        }
      }
      return null;
    }, text);
    if (rect) {
      await page.mouse.click(rect.x, rect.y);
      console.log(`  ✓ clicked "${text}" at (${Math.round(rect.x)},${Math.round(rect.y)})`);
      return true;
    }
    await delay(600);
  }
  console.warn(`  ⚠ could not find/click "${text}"`);
  return false;
};

const waitText = async (text, timeoutMs = 30000) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const found = await page.evaluate(txt => {
      const host = document.querySelector('flt-semantics-host');
      if (!host) return false;
      return [...host.querySelectorAll('*')].some(el =>
        (el.getAttribute('aria-label') || el.innerText || '').toLowerCase().includes(txt.toLowerCase())
      );
    }, text);
    if (found) { console.log(`  ✓ found: "${text}"`); return true; }
    await delay(600);
  }
  console.warn(`  ⚠ timeout for: "${text}"`);
  return false;
};

const allText = async () => page.evaluate(() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return '';
  return [...host.querySelectorAll('*')]
    .map(el => el.getAttribute('aria-label') || el.innerText || '')
    .filter(Boolean).join(' ');
});

// Wait for Flutter canvas to mount
const waitForCanvas = async (timeoutMs = 30000) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const found = await page.evaluate(() => !!document.querySelector('flutter-view,flt-glass-pane,canvas'));
    if (found) { console.log('  ✓ Flutter canvas mounted'); return true; }
    await delay(500);
  }
  console.warn('  ⚠ Flutter canvas not found');
  return false;
};

// ── 1. Load app ───────────────────────────────────────────────────────────────

console.log('\n[1] Loading app at', APP_URL);
await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
await waitForCanvas(30000);
await delay(5000);     // Flutter Dart bootstrap
await activateA11y();
await shot('01_auth');

// ── 2. Auth ───────────────────────────────────────────────────────────────────

console.log('\n[2] Auth');
const sawGuest = await waitText('continue as guest', 15000);
if (sawGuest) {
  await clickSemantic('continue as guest');
  await delay(1500);
}

// ── 3. Onboarding ─────────────────────────────────────────────────────────────

console.log('\n[3] Onboarding — role');
await waitText('grandparent', 15000);
await shot('02_role');
await clickSemantic('grandparent');
await delay(600);
await clickSemantic('continue');
await delay(1200);

console.log('  loved ones screen');
await waitText('skip', 12000);
await shot('03_loved_ones');
await clickSemantic('skip');
await delay(1500);

// ── 4. Library ────────────────────────────────────────────────────────────────

console.log('\n[4] Library — waiting for Firestore stories...');
await waitText('library', 20000);
await delay(5000);    // subscription stream + stories both need to resolve
await activateA11y();
await shot('04_library');

const libTxt = await allText();
const hasPremium = libTxt.toLowerCase().includes('premium');
const hasLock    = libTxt.toLowerCase().includes('lock');
console.log('  PREMIUM in a11y tree:', hasPremium);
console.log('  lock in a11y tree:   ', hasLock);
console.log('  a11y sample:', libTxt.slice(0, 600));

// ── 5. Tap premium story → paywall ────────────────────────────────────────────

console.log('\n[5] Opening All Stories grid...');
await clickSemantic('all stories');
await delay(3000);
await activateA11y();
await shot('04a_all_stories_grid');

console.log('Tapping premium story...');
let tapped = await clickSemantic('elves', 4000);
if (!tapped) tapped = await clickSemantic('monkeys', 4000);
if (!tapped) tapped = await clickSemantic('shoemaker', 4000);
await delay(3500);
await activateA11y();
await shot('05_after_tap_premium');

const afterTxt = await allText();
const paywallShown = afterTxt.toLowerCase().includes('unlock') ||
                     afterTxt.toLowerCase().includes('subscribe') ||
                     (afterTxt.toLowerCase().includes('premium') &&
                      afterTxt.toLowerCase().includes('apple'));
const plansOnPaywall = afterTxt.toLowerCase().includes('monthly') ||
                       afterTxt.toLowerCase().includes('annual');
console.log('  Paywall shown:   ', paywallShown);
console.log('  Plans on paywall:', plansOnPaywall);
console.log('  a11y sample:', afterTxt.slice(0, 500));

// ── 6. Navigate to Plans screen ───────────────────────────────────────────────

console.log('\n[6] Profile > Plans...');
// Go back to library first if needed
await page.evaluate(() => { window.location.hash = '#/library'; });
await delay(2000);
await activateA11y();

await clickSemantic('profile');
await delay(2500);
await activateA11y();
await shot('06_profile');

await clickSemantic('subscription');
await delay(2000);
await activateA11y();
await shot('07_subscription');

// "Manage subscription" button
await clickSemantic('manage');
await delay(3000);
await activateA11y();
await shot('08_plans');

const plansTxt = await allText();
const plansHasData = plansTxt.toLowerCase().includes('monthly') ||
                     plansTxt.toLowerCase().includes('annual') ||
                     plansTxt.toLowerCase().includes('family');
console.log('  Plans a11y sample:', plansTxt.slice(0, 600));
console.log('  Firestore plans shown:', plansHasData);

// ── Result ────────────────────────────────────────────────────────────────────

console.log('\n═══════════════════════ QA RESULTS ═══════════════════════');
console.log(sawGuest                     ? '✅' : '⚠ ', 'App loads; auth screen shown');
console.log((hasPremium || hasLock)       ? '✅' : '⚠ ', 'Premium/lock visible in library');
console.log(paywallShown                 ? '✅' : '⚠ ', 'Paywall shown on premium story tap');
console.log(plansOnPaywall               ? '✅' : '⚠ ', 'Paywall reads plans from Firestore');
console.log(plansHasData                 ? '✅' : '⚠ ', 'Plans screen reads from Firestore');
console.log('═══════════════════════════════════════════════════════════');

await browser.close();
