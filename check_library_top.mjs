import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
page.on('pageerror', e => console.error('[pageerror]', e.message.substring(0, 100)));

const enableSemantics = async () => {
  await page.keyboard.press('Tab');
  await page.evaluate(() => {
    const btn = document.querySelector('flt-semantics-placeholder');
    if (btn) { btn.focus(); btn.dispatchEvent(new MouseEvent('click', { bubbles: true })); }
  });
  await page.accessibility.snapshot();
  await new Promise(r => setTimeout(r, 1000));
};

// Click by aria-label OR textContent (Flutter web uses both)
const clickByLabel = async (label) => {
  const pos = await page.evaluate((lbl) => {
    const all = Array.from(document.querySelectorAll('flt-semantics'));
    // Prefer exact aria-label match, then fall back to textContent
    const el = all.find(e => e.getAttribute('aria-label') === lbl)
      || all.find(e => (e.textContent || '').trim().includes(lbl));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  }, label);
  if (!pos) { console.log(`❌ "${label}" not found`); return false; }
  console.log(`✅ Click "${label}" at (${pos.x.toFixed(0)}, ${pos.y.toFixed(0)})`);
  await page.mouse.click(pos.x, pos.y);
  return true;
};

// Click by partial text content on any flt-semantics element
const clickByText = async (text) => {
  const pos = await page.evaluate((t) => {
    const el = Array.from(document.querySelectorAll('flt-semantics'))
      .find(e => (e.textContent || '').includes(t));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  }, text);
  if (!pos) { console.log(`❌ text "${text}" not found`); return false; }
  console.log(`✅ Click text "${text}" at (${pos.x.toFixed(0)}, ${pos.y.toFixed(0)})`);
  await page.mouse.click(pos.x, pos.y);
  return true;
};

const url = async () => page.evaluate(() => window.location.hash);

// ── 1. Load app ────────────────────────────────────────────────────────────
console.log('Loading app...');
await page.goto('http://localhost:42015/', { waitUntil: 'networkidle0', timeout: 30000 });
await new Promise(r => setTimeout(r, 15000));
await enableSemantics();

// ── 2. Auth → Continue as guest ────────────────────────────────────────────
await clickByLabel('Continue as guest');
await new Promise(r => setTimeout(r, 12000)); // wait for anonymous Firebase auth
console.log('After guest:', await url());

// ── 3. Role screen: select Parent → Continue ──────────────────────────────
await enableSemantics();
await clickByLabel('Parent');
await new Promise(r => setTimeout(r, 1000));
await clickByText('Continue →');
await new Promise(r => setTimeout(r, 8000));
console.log('After role:', await url());

// ── 4. Loved ones: skip ────────────────────────────────────────────────────
await enableSemantics();
// Dump all buttons on this screen
const lovedBtns = await page.evaluate(() =>
  Array.from(document.querySelectorAll('flt-semantics'))
    .map(e => ({ role: e.getAttribute('role'), label: e.getAttribute('aria-label'), text: e.textContent.trim().substring(0,60) }))
    .filter(e => e.role === 'button' || e.text.includes('Skip') || e.text.includes('Done'))
);
console.log('Loved ones buttons:', JSON.stringify(lovedBtns.slice(0, 10)));

await clickByLabel('Skip for now') || await clickByText('Skip for now') || await clickByLabel('Skip') || await clickByText('Skip');
await new Promise(r => setTimeout(r, 8000));
console.log('After loved ones:', await url());

// ── 5. Library screen ─────────────────────────────────────────────────────
await enableSemantics();
await page.screenshot({ path: '/tmp/lib_library.png' });
console.log('Library screenshot saved → /tmp/lib_library.png');

// Dump all semantic labels on library screen
const libItems = await page.evaluate(() =>
  Array.from(document.querySelectorAll('flt-semantics'))
    .map(e => (e.getAttribute('aria-label') || e.textContent || '').trim())
    .filter(Boolean)
    .filter((v, i, a) => a.indexOf(v) === i) // dedupe
);
console.log('\n=== Library screen text ===');
libItems.slice(0, 50).forEach(i => console.log(' ', i.substring(0, 100)));

await browser.close();
