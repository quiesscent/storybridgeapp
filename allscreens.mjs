import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

// Load directly to /library/ginger-giraffe for detail page
await page.goto('http://localhost:42013/#/library/ginger-giraffe', { waitUntil: 'networkidle0', timeout: 30000 });
await new Promise(r => setTimeout(r, 20000));
await page.screenshot({ path: '/tmp/detail_screen.png' });
console.log('Detail screenshot saved');

await browser.close();
