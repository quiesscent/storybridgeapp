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
await new Promise(r => setTimeout(r, 15000));

// Click "Enable accessibility" button (it's at -1,-1 in the DOM, but accessible)
const enableBtn = await page.$('flt-semantics-placeholder[aria-label="Enable accessibility"]');
if (enableBtn) {
  await enableBtn.click();
  console.log('Clicked Enable accessibility');
} else {
  console.log('No enable accessibility button');
}
await new Promise(r => setTimeout(r, 3000));

// Now try to find "Continue as guest" in accessibility tree
const accessibility = await page.accessibility.snapshot();
const findNode = (node, name) => {
  if (!node) return null;
  if (node.name?.toLowerCase().includes(name.toLowerCase())) return node;
  if (node.children) for (const c of node.children) { const f = findNode(c, name); if (f) return f; }
  return null;
};

const guestNode = accessibility ? findNode(accessibility, 'guest') : null;
console.log('Guest node:', guestNode);

// Alternatively, look for all buttons
const findAllButtons = (node, results = []) => {
  if (!node) return results;
  if (node.role === 'button' || node.role === 'link') results.push({ role: node.role, name: node.name });
  if (node.children) for (const c of node.children) findAllButtons(c, results);
  return results;
};
const buttons = accessibility ? findAllButtons(accessibility) : [];
console.log('All buttons:', buttons);

await browser.close();
