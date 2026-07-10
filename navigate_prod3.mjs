import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

await page.goto('http://localhost:42014/', { waitUntil: 'networkidle0', timeout: 30000 });
await new Promise(r => setTimeout(r, 12000));

// Use JS to click the accessibility button
await page.evaluate(() => {
  const btn = document.querySelector('flt-semantics-placeholder');
  if (btn) btn.dispatchEvent(new MouseEvent('click', { bubbles: true }));
});
await new Promise(r => setTimeout(r, 3000));

// Find all flt-semantics elements with text content
const semantics = await page.evaluate(() => {
  const elems = document.querySelectorAll('flt-semantics, flt-semantics-container');
  const items = [];
  elems.forEach(el => {
    const label = el.getAttribute('aria-label');
    const role = el.getAttribute('role');
    const style = el.getAttribute('style') || '';
    if (label) items.push({ tag: el.tagName, role, label, style: style.substring(0, 100) });
  });
  return items;
});
console.log('Semantic elements:', semantics.length);
semantics.forEach(s => console.log(' ', s.role, '|', s.label, '|', s.style.substring(0, 50)));

await browser.close();
