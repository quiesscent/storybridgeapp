import puppeteer from 'puppeteer';

(async () => {
  console.log('Launching browser with fake UI and devices for media stream...');
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'shell',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--enable-unsafe-swiftshader',
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream'
    ],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

  // Override clipboard API to intercept copy link action
  await page.evaluateOnNewDocument(() => {
    window.storybridgeCopiedText = "";
    navigator.clipboard.writeText = (text) => {
      window.storybridgeCopiedText = text;
      console.log("[QA Test Capture] Intercepted clipboard writeText: " + text);
      return Promise.resolve();
    };
    navigator.clipboard.readText = () => {
      return Promise.resolve(window.storybridgeCopiedText);
    };
  });

  page.on('console', msg => {
    const text = msg.text();
    console.log(`[App Console] ${text}`);
  });
  page.on('pageerror', e => {
    console.error(`[App Error] ${e.message}`);
  });

  const ensureSemanticsEnabled = async (p, contextName) => {
    console.log(`[QA System] Activating semantics for: ${contextName}...`);
    // Press Tab to move focus to the placeholder
    await p.keyboard.press('Tab');
    await new Promise(r => setTimeout(r, 500));

    // Force focus and click in DOM
    await p.evaluate(() => {
      const btn = document.querySelector('flt-semantics-placeholder');
      if (btn) {
        btn.focus();
        btn.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        console.log('[QA System] Focused and clicked semantics placeholder.');
      }
    });

    // Native Chromium accessibility trigger
    await p.accessibility.snapshot();
    await new Promise(r => setTimeout(r, 2000));
  };

  const printSemantics = async (p, stepName) => {
    await ensureSemanticsEnabled(p, stepName);
    const semantics = await p.evaluate(() => {
      const elems = document.querySelectorAll('flt-semantics, flt-semantics-container');
      const items = [];
      elems.forEach(el => {
        const label = el.getAttribute('aria-label');
        const role = el.getAttribute('role');
        const text = el.innerText || el.textContent || '';
        if (label || text.trim()) {
          items.push({ role, label, text: text.trim().substring(0, 100) });
        }
      });
      return items;
    });
    console.log(`\n--- Semantic Tree at ${stepName} ---`);
    semantics.forEach(s => {
      console.log(`  Role: ${s.role} | Label: ${s.label} | Text: ${s.text}`);
    });
    console.log(`------------------------------------\n`);
  };

  console.log('Navigating to landing/auth page...');
  await page.goto('http://localhost:42014/', { waitUntil: 'networkidle0', timeout: 30000 });
  await new Promise(r => setTimeout(r, 15000));

  await printSemantics(page, 'Auth Screen');

  console.log('Clicking "Continue as guest"...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Continue as guest'));
    if (btn) {
      btn.click();
      console.log('Guest button clicked.');
    } else {
      console.error('Guest button not found!');
    }
  });

  // Wait for redirect to /onboard/role
  await new Promise(r => setTimeout(r, 8000));
  await printSemantics(page, 'Role Onboarding Screen');

  console.log('Selecting "Parent" role...');
  await page.evaluate(() => {
    const chip = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Parent'));
    if (chip) {
      chip.click();
      console.log('Parent role selected.');
    } else {
      console.error('Parent chip not found!');
    }
  });
  await new Promise(r => setTimeout(r, 2000));

  console.log('Clicking Continue on Role Screen...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Continue →'));
    if (btn) {
      btn.click();
      console.log('Role Continue clicked.');
    } else {
      console.error('Role Continue button not found!');
    }
  });

  // Wait for redirect to /onboard/loved
  await new Promise(r => setTimeout(r, 6000));
  await printSemantics(page, 'Loved Ones Onboarding Screen');

  console.log('Clicking "Skip for now" on Loved Ones Screen...');
  await page.evaluate(() => {
    const skipBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Skip for now'));
    if (skipBtn) {
      skipBtn.click();
      console.log('Skip for now clicked.');
    } else {
      console.error('Skip for now button not found!');
    }
  });

  // Wait for redirect to /library
  await new Promise(r => setTimeout(r, 6000));
  await printSemantics(page, 'Library Screen');

  console.log('Navigating internally to ginger-giraffe recording page...');
  await page.evaluate(() => {
    window.location.hash = '#/recording/ginger-giraffe?video=true';
  });
  await new Promise(r => setTimeout(r, 12000));

  await printSemantics(page, 'Recording Start');

  console.log('Recording started automatically. Running 65-second session...');

  // Page 1 -> Page 2
  await new Promise(r => setTimeout(r, 15000));
  console.log('Turning to page 2...');
  await ensureSemanticsEnabled(page, 'Page 2 Turn');
  await page.evaluate(() => {
    const nextBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Next page');
    if (nextBtn) {
      nextBtn.click();
      console.log('[QA System] Next page clicked.');
    } else {
      console.error('[QA System] Next page button not found!');
    }
  });

  // Page 2 -> Page 3
  await new Promise(r => setTimeout(r, 15000));
  console.log('Turning to page 3...');
  await ensureSemanticsEnabled(page, 'Page 3 Turn');
  await page.evaluate(() => {
    const nextBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Next page');
    if (nextBtn) {
      nextBtn.click();
      console.log('[QA System] Next page clicked.');
    } else {
      console.error('[QA System] Next page button not found!');
    }
  });

  // Page 3 -> Page 4
  await new Promise(r => setTimeout(r, 15000));
  console.log('Turning to page 4...');
  await ensureSemanticsEnabled(page, 'Page 4 Turn');
  await page.evaluate(() => {
    const nextBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Next page');
    if (nextBtn) {
      nextBtn.click();
      console.log('[QA System] Next page clicked.');
    } else {
      console.error('[QA System] Next page button not found!');
    }
  });

  // Page 4 -> Page 5
  await new Promise(r => setTimeout(r, 15000));
  console.log('Turning to page 5...');
  await ensureSemanticsEnabled(page, 'Page 5 Turn');
  await page.evaluate(() => {
    const nextBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Next page');
    if (nextBtn) {
      nextBtn.click();
      console.log('[QA System] Next page clicked.');
    } else {
      console.error('[QA System] Next page button not found!');
    }
  });

  // Finish Recording
  await new Promise(r => setTimeout(r, 6000));
  console.log('Done recording. Saving... (Writing layoutModes assertion in app logs)');
  await ensureSemanticsEnabled(page, 'Save Recording Tap');
  await page.evaluate(() => {
    const saveBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Done — save recording');
    if (saveBtn) {
      saveBtn.click();
      console.log('[QA System] Save Recording clicked.');
    } else {
      console.error('[QA System] Save Recording button not found!');
    }
  });

  // Wait for draft screen redirection
  console.log('Waiting for draft compilation/redirection to edit page...');
  await new Promise(r => setTimeout(r, 15000));
  await printSemantics(page, 'Edit Screen');

  // On Edit screen, choose a layout format (e.g. Book-led)
  console.log('Selecting Book-led layout...');
  await page.evaluate(() => {
    const bookLedCard = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Book-led'));
    if (bookLedCard) {
      bookLedCard.click();
      console.log('[QA System] Selected Book-led layout.');
    } else {
      console.error('[QA System] Book-led layout card not found!');
    }
  });
  await new Promise(r => setTimeout(r, 2000));

  // Click Save & Share
  console.log('Clicking Save & Share...');
  await page.evaluate(() => {
    const shareBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Save & Share');
    if (shareBtn) {
      shareBtn.click();
      console.log('[QA System] Clicked Save & Share by label.');
    } else {
      const shareBtnText = Array.from(document.querySelectorAll('flt-semantics'))
        .find(el => el.textContent && el.textContent.includes('Save & Share'));
      if (shareBtnText) {
        shareBtnText.click();
        console.log('[QA System] Clicked Save & Share by text.');
      } else {
        console.error('[QA System] Save & Share button not found!');
      }
    }
  });

  // Wait for composition to complete and redirect to Preview screen
  console.log('Waiting for composition and redirect to Preview...');
  await new Promise(r => setTimeout(r, 20000));
  await printSemantics(page, 'Preview Screen');

  // Click Share Story to open sheet
  console.log('Opening Share Sheet...');
  await page.evaluate(() => {
    const shareStoryBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.getAttribute('aria-label') === 'Share Story' || (el.textContent && el.textContent.includes('Share Story')));
    if (shareStoryBtn) {
      shareStoryBtn.click();
      console.log('[QA System] Clicked Share Story.');
    } else {
      console.error('[QA System] Share Story button not found!');
    }
  });
  await new Promise(r => setTimeout(r, 5000));
  await printSemantics(page, 'Share Sheet Open');

  // Click Copy Share Link
  console.log('Clicking Copy Share Link...');
  await page.evaluate(() => {
    const copyLinkBtn = Array.from(document.querySelectorAll('flt-semantics'))
      .find(el => el.textContent && el.textContent.includes('Copy link') || el.textContent.includes('Link ready'));
    if (copyLinkBtn) {
      copyLinkBtn.click();
      console.log('[QA System] Clicked Copy link by text.');
    } else {
      const copyBtnSem = Array.from(document.querySelectorAll('flt-semantics'))
        .find(el => el.getAttribute('aria-label') === 'Copy link' || el.getAttribute('aria-label') === 'Link ready — tap to copy');
      if (copyBtnSem) {
        copyBtnSem.click();
        console.log('[QA System] Clicked Copy link by label.');
      } else {
        console.error('[QA System] Copy link button not found!');
      }
    }
  });
  await new Promise(r => setTimeout(r, 3000));

  // Retrieve URL from clipboard override
  const copiedUrl = await page.evaluate(() => window.storybridgeCopiedText);
  console.log('SUCCESS: Intercepted Share Link is:', copiedUrl);

  // Navigate to copied link
  if (copiedUrl) {
    const localUrl = copiedUrl.replace('https://storybridgeapp.co.uk', 'http://localhost:42014');
    console.log('Navigating to local watch link:', localUrl);
    const watchPage = await browser.newPage();
    await watchPage.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
    await watchPage.goto(localUrl, { waitUntil: 'networkidle0', timeout: 30000 });
    await new Promise(r => setTimeout(r, 10000));
    await printSemantics(watchPage, 'Watch Screen');
    console.log('Watch screen loaded successfully!');
  } else {
    console.error('ERROR: Could not retrieve Copied Share Link!');
  }

  await browser.close();
  console.log('QA Flow Finished!');
})();
