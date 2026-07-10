import puppeteer from 'puppeteer';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'shell',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--enable-unsafe-swiftshader'
    ],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844 });

  page.on('console', msg => {
    console.log(`[Browser Console] ${msg.text()}`);
  });
  page.on('pageerror', err => {
    console.error(`[Browser PageError] ${err.message}`);
  });

  console.log('Navigating to app...');
  await page.goto('http://localhost:8082/#/recording/ginger-giraffe?video=true', { waitUntil: 'networkidle0', timeout: 45000 });
  
  console.log('Waiting 15 seconds for bootstrap...');
  await new Promise(r => setTimeout(r, 15000));

  const bodyChildren = await page.evaluate(() => {
    return Array.from(document.body.children).map(el => el.tagName);
  });
  console.log('Body tag names:', bodyChildren);

  await browser.close();
})();
