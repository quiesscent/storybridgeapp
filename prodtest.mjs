import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

const logs = [];
page.on('console', msg => logs.push(`[${msg.type()}] ${msg.text().substring(0, 100)}`));
page.on('pageerror', e => logs.push(`[ERR] ${e.message}`));

console.log('Loading production build...');
await page.goto('http://localhost:42014/', { waitUntil: 'networkidle0', timeout: 30000 });
await new Promise(r => setTimeout(r, 15000));

await page.screenshot({ path: '/tmp/prod_screen.png' });
console.log('Screenshot saved');

console.log('Errors:', logs.filter(l => l.includes('[ERR]') || l.includes('[error]')).slice(0,5));

await browser.close();
