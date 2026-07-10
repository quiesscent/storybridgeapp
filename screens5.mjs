import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
await page.goto('http://localhost:42013/#/recording/ginger-giraffe', { 
  waitUntil: 'domcontentloaded', timeout: 30000 
});
await new Promise(r => setTimeout(r, 22000));
await page.screenshot({ path: '/tmp/recording_screen.png' });
console.log('Recording saved');
await page.close();

const page2 = await browser.newPage();
await page2.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
await page2.goto('http://localhost:42013/#/setup/text/ginger-giraffe', { 
  waitUntil: 'domcontentloaded', timeout: 30000 
});
await new Promise(r => setTimeout(r, 22000));
await page2.screenshot({ path: '/tmp/setup_screen.png' });
console.log('Setup saved');

await browser.close();
