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
  await page.goto('http://localhost:42014/', { waitUntil: 'networkidle0' });
  
  console.log('Waiting 20 seconds...');
  await new Promise(r => setTimeout(r, 20000));

  const bodyHtml = await page.evaluate(() => {
    return document.body.innerHTML;
  });
  console.log('Body HTML length:', bodyHtml.length);
  console.log('Body HTML (first 1000 chars):', bodyHtml.substring(0, 1000));
  console.log('Body HTML (last 1000 chars):', bodyHtml.substring(bodyHtml.length - 1000));

  await browser.close();
})();
