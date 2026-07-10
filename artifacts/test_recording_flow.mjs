import puppeteer from 'puppeteer';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'shell',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--use-fake-device-for-media-stream',
      '--use-fake-ui-for-media-stream',
    ],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

  // Listen to browser console and page errors
  page.on('console', (msg) => {
    console.log(`[BROWSER CONSOLE] ${msg.type().toUpperCase()}: ${msg.text()}`);
  });
  page.on('pageerror', (err) => {
    console.error(`[BROWSER PAGE ERROR] ${err.toString()}`);
  });

  console.log('Navigating to setup check page...');
  await page.goto('http://localhost:8080/#/setup/check/ginger-giraffe', {
    waitUntil: 'networkidle0',
    timeout: 30000,
  });

  console.log('Waiting for camera preview to initialize and permissions to pass...');
  await new Promise(r => setTimeout(r, 6000));
  await page.screenshot({ path: '/home/lewis/CascadeProjects/story_app/artifacts/setup_check_live.png' });
  console.log('Saved setup check screenshot.');

  // Click the start recording button
  // In setup_checks_screen.dart, the PillButton has the label 'Start recording →'
  console.log('Clicking "Start recording" button...');
  const buttons = await page.$$('div'); // Flutter renders divs
  let clickedStart = false;
  for (const btn of buttons) {
    const text = await page.evaluate(el => el.innerText, btn);
    if (text && text.includes('Start recording')) {
      await btn.click();
      clickedStart = true;
      console.log('Clicked Start recording button.');
      break;
    }
  }

  if (!clickedStart) {
    console.log('Could not find start button by text, performing fallback click at center coordinates...');
    await page.mouse.click(195, 750); // Click near the bottom center where the start button is
  }

  console.log('Waiting for recording screen to load and start recording...');
  await new Promise(r => setTimeout(r, 8000));
  await page.screenshot({ path: '/home/lewis/CascadeProjects/story_app/artifacts/recording_screen_live.png' });
  console.log('Saved recording screen screenshot.');

  // Turn page (click right chevron / near coordinates)
  console.log('Turning page...');
  await page.mouse.click(360, 422); // Click the right chevron on the screen
  await new Promise(r => setTimeout(r, 3000));
  await page.screenshot({ path: '/home/lewis/CascadeProjects/story_app/artifacts/recording_page2_live.png' });
  console.log('Saved page 2 screenshot.');

  // Stop recording: In recording_screen.dart, PillButton label is 'Done — save recording'
  console.log('Clicking "Done — save recording" button...');
  await page.mouse.click(195, 780); // Click near the bottom center where the Done button is
  
  console.log('Waiting for processing/saving to complete...');
  await new Promise(r => setTimeout(r, 12000));
  await page.screenshot({ path: '/home/lewis/CascadeProjects/story_app/artifacts/preview_screen_live.png' });
  console.log('Saved preview screen screenshot.');

  console.log('Checking current URL...');
  const currentUrl = await page.url();
  console.log(`Current URL: ${currentUrl}`);

  await browser.close();
})();
