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

  console.log('Navigating to app...');
  await page.goto('http://localhost:42014/#/recording/ginger-giraffe?video=true', { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 15000));

  // Enable semantics
  await page.accessibility.snapshot();
  await page.evaluate(() => {
    const btn = document.querySelector('flt-semantics-placeholder');
    if (btn) btn.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });
  await new Promise(r => setTimeout(r, 3000));

  const accessibility = await page.accessibility.snapshot();
  console.log('Accessibility Tree:\n', JSON.stringify(accessibility, null, 2));

  await browser.close();
})();
