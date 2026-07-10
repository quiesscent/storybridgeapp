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

// Press Tab to enable accessibility tree
await page.keyboard.press('Tab');
await new Promise(r => setTimeout(r, 2000));

// Check the accessibility tree
const accessibility = await page.accessibility.snapshot();
console.log('Accessibility tree:', JSON.stringify(accessibility, null, 2).substring(0, 2000));

// Look for "Continue as guest" button
const findNode = (node, name) => {
  if (!node) return null;
  if (node.name?.toLowerCase().includes(name.toLowerCase())) return node;
  if (node.children) {
    for (const child of node.children) {
      const found = findNode(child, name);
      if (found) return found;
    }
  }
  return null;
};

if (accessibility) {
  const guestBtn = findNode(accessibility, 'guest');
  console.log('Guest button:', guestBtn);
}

await browser.close();
