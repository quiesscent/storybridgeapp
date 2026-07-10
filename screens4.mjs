import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist'],
});

const newPage = async (url, waitMs, path) => {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });
  await new Promise(r => setTimeout(r, waitMs));
  await page.screenshot({ path });
  await page.close();
  console.log('Saved:', path);
};

// Recording screen
await newPage('http://localhost:42013/#/recording/ginger-giraffe', 20000, '/tmp/recording_screen.png');

// Setup text screen (shows story image)
await newPage('http://localhost:42013/#/setup/text/ginger-giraffe', 20000, '/tmp/setup_screen.png');

await browser.close();
