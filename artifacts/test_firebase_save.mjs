import puppeteer from "puppeteer";

// Helper to wait
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForSemanticText(page, text, timeoutMs = 30000) {
  const start = Date.now();
  console.log(`Waiting for text: "${text}"...`);
  while (Date.now() - start < timeoutMs) {
    const exists = await page.evaluate((txt) => {
      const host = document.querySelector("flt-semantics-host");
      if (!host) return false;
      const all = host.querySelectorAll("*");
      for (let i = all.length - 1; i >= 0; i--) {
        const el = all[i];
        const ariaLabel = el.getAttribute("aria-label") || "";
        const innerText = el.innerText || "";
        if (
          ariaLabel.toLowerCase().includes(txt.toLowerCase()) ||
          innerText.toLowerCase().includes(txt.toLowerCase())
        ) {
          return true;
        }
      }
      return false;
    }, text);

    if (exists) {
      console.log(`Found text: "${text}"`);
      return true;
    }
    await delay(1000);
  }
  throw new Error(`Timeout waiting for text: "${text}"`);
}

async function clickSemanticElementByText(page, text) {
  console.log(`Finding bounding box for text: "${text}"...`);
  const rect = await page.evaluate((txt) => {
    const host = document.querySelector("flt-semantics-host");
    if (!host) return null;
    const all = host.querySelectorAll("*");
    for (let i = all.length - 1; i >= 0; i--) {
      const el = all[i];
      const ariaLabel = el.getAttribute("aria-label") || "";
      const innerText = el.innerText || "";
      if (
        ariaLabel.toLowerCase().includes(txt.toLowerCase()) ||
        innerText.toLowerCase().includes(txt.toLowerCase())
      ) {
        const r = el.getBoundingClientRect();
        return {
          x: r.left + r.width / 2,
          y: r.top + r.height / 2,
          width: r.width,
          height: r.height,
        };
      }
    }
    return null;
  }, text);

  if (rect) {
    console.log(
      `Clicking semantic element center: (${rect.x}, ${rect.y}) with size ${rect.width}x${rect.height}`,
    );
    await page.mouse.click(rect.x, rect.y);
    return true;
  }
  console.warn(`WARNING: Bounding box not found for text: "${text}"`);
  return false;
}

(async () => {
  console.log("Launching browser with fake audio/video device flags...");
  const browser = await puppeteer.launch({
    executablePath: "/usr/bin/google-chrome",
    headless: "shell",
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--use-fake-device-for-media-stream",
      "--use-fake-ui-for-media-stream",
    ],
  });

  const page = await browser.newPage();
  await page.setCacheEnabled(false);
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

  let isAppReady = false;

  page.on("console", async (msg) => {
    try {
      const args = await Promise.all(
        msg.args().map(async (arg) => {
          try {
            const val = await arg.jsonValue();
            if (typeof val === "object" && val !== null) {
              return JSON.stringify(val);
            }
            return String(val);
          } catch (_) {
            return arg.toString();
          }
        }),
      );
      const logText = args.join(" ");
      if (logText.trim().length > 0) {
        console.log(
          `[BROWSER CONSOLE] ${msg.type().toUpperCase()}: ${logText}`,
        );
      }
      if (logText.includes("going to /auth")) {
        isAppReady = true;
      }
    } catch (_) {
      console.log(
        `[BROWSER CONSOLE] ${msg.type().toUpperCase()}: ${msg.text()}`,
      );
    }
  });

  page.on("pageerror", (err) => {
    console.error(`[BROWSER PAGE ERROR] ${err.toString()}`);
  });

  console.log("Navigating to app URL on port 8099...");
  await page.goto("http://localhost:8099/", {
    waitUntil: "load",
    timeout: 30000,
  });

  console.log("Waiting for GoRouter to load /auth screen...");
  const startWait = Date.now();
  while (!isAppReady && Date.now() - startWait < 30000) {
    await delay(500);
  }

  if (!isAppReady) {
    console.warn(
      'WARNING: Did not see "going to /auth" console log. Proceeding anyway...',
    );
  } else {
    console.log("SUCCESS: /auth screen is loaded!");
  }

  await delay(1000);

  console.log("Activating Flutter accessibility...");
  await page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el) el.click();
  });

  await delay(1000);
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step1_auth.png",
  });

  console.log('Clicking "Continue as guest"...');
  await clickSemanticElementByText(page, "Continue as guest");

  await waitForSemanticText(page, "Grandparent");
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step2_onboard_role.png",
  });

  console.log("Selecting Grandparent role...");
  await clickSemanticElementByText(page, "Grandparent");
  await delay(1000);

  console.log("Clicking Continue...");
  await clickSemanticElementByText(page, "Continue");

  await waitForSemanticText(page, "Skip for now");
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step3_onboard_loved.png",
  });

  console.log('Clicking "Skip for now"...');
  await clickSemanticElementByText(page, "Skip for now");

  await waitForSemanticText(page, "Library");
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step4_library.png",
  });

  console.log(
    "Navigating programmatically to setup check page for twinkle (in-memory hash navigation)...",
  );
  await page.evaluate(() => {
    window.location.hash = "#/setup/check/twinkle";
  });

  await waitForSemanticText(page, "Start recording");
  console.log("Waiting for camera checks to pass (10s)...");
  await delay(10000);
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step5_setup_check.png",
  });

  console.log('Clicking "Start recording"...');
  await clickSemanticElementByText(page, "Start recording");

  await waitForSemanticText(page, "How I wonder");
  console.log("Waiting for web recorder to initialize...");
  
  let recorderInitialized = false;
  for (let i = 0; i < 30; i++) {
    recorderInitialized = await page.evaluate(() => {
      return window.storybridgeRecorder && window.storybridgeRecorder.recording === true;
    });
    if (recorderInitialized) {
      console.log(`Web recorder initialized successfully after ${i}s!`);
      break;
    }
    await delay(1000);
  }
  if (!recorderInitialized) {
    console.warn("WARNING: Web recorder initialization timed out after 30s!");
  }

  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step6_recording_start.png",
  });

  // Page 1 is active (index 0 of 4)
  console.log("Page 1 of 4 active. Waiting 4s...");
  await delay(4000);
  console.log("Turning page to Page 2 (click right chevron)...");
  // Try clicking "Next page" semantically
  let clickedNext = await clickSemanticElementByText(page, "Next page");
  if (!clickedNext) {
    // Coordinate fallback for page turn
    await page.mouse.click(370, 422);
  }

  // Page 2 is active (index 1 of 4)
  await delay(4000);
  console.log("Page 2 of 4 active. Turning page to Page 3...");
  clickedNext = await clickSemanticElementByText(page, "Next page");
  if (!clickedNext) {
    await page.mouse.click(370, 422);
  }

  // Page 3 is active (index 2 of 4)
  await delay(4000);
  console.log("Page 3 of 4 active. Turning page to Page 4...");
  clickedNext = await clickSemanticElementByText(page, "Next page");
  if (!clickedNext) {
    await page.mouse.click(370, 422);
  }

  // Page 4 is active (index 3 of 4 — final page!)
  await delay(4000);
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step7_recording_final.png",
  });

  console.log("Dumping flt-semantics-host innerHTML before clicking Done:");
  const semanticsHtml = await page.evaluate(() => {
    const host = document.querySelector("flt-semantics-host");
    return host ? host.innerHTML : "No flt-semantics-host found";
  });
  console.log(semanticsHtml);

  console.log("Page 4 of 4 active. Stopping and saving recording...");

  let clickedDone = await clickSemanticElementByText(page, "Done");
  if (!clickedDone) {
    clickedDone = await clickSemanticElementByText(page, "save");
  }
  if (!clickedDone) {
    console.log("Fallback: Clicking bottom center for Done (195, 780)...");
    await page.mouse.click(195, 780);
  }

  console.log(
    "Waiting for composite processing and redirect to preview (25s)...",
  );
  await delay(25000);
  await page.screenshot({
    path: "/home/lewis/CascadeProjects/story_app/artifacts/test_step8_preview.png",
  });

  const currentUrl = await page.url();
  console.log(`Final URL: ${currentUrl}`);

  await browser.close();
})();
