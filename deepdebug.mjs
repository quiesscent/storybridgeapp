import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'shell',
  args: ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage',
    '--enable-webgl','--ignore-gpu-blocklist','--enable-gpu-rasterization'],
});

const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });

// Monitor all console output
const allLogs = [];
page.on('console', msg => allLogs.push(`[${msg.type()}] ${msg.text()}`));
page.on('pageerror', e => allLogs.push(`[PAGEERROR] ${e.message}`));

await page.goto('http://localhost:42013/', { waitUntil: 'networkidle0', timeout: 30000 });
await new Promise(r => setTimeout(r, 20000));

// Check WebGL status
const webgl = await page.evaluate(() => {
  const c = document.createElement('canvas');
  const gl = c.getContext('webgl') || c.getContext('experimental-webgl');
  return gl ? `WebGL available: ${gl.getParameter(gl.RENDERER)}` : 'WebGL NOT available';
});
console.log('WebGL check:', webgl);

// Get pixel colors from the story tile areas
// First story tile is roughly at (100, 450) in 390x844 viewport
const tilePixels = await page.evaluate(() => {
  const glassPane = document.querySelector('flt-glass-pane');
  if (!glassPane?.shadowRoot) return 'no shadow';
  const canvas = glassPane.shadowRoot.querySelector('canvas');
  if (!canvas) return 'no canvas';
  
  const ctx = canvas.getContext('2d');
  if (!ctx) return 'no 2d ctx (CanvasKit uses WebGL)';
  
  // Try reading from WebGL context
  const gl = canvas.getContext('webgl') || canvas.getContext('webgl2');
  if (!gl) return 'no gl context';
  
  // Read pixel at story tile location (scaled by devicePixelRatio=2)
  const x = 100 * 2, y = 350 * 2;
  const pixels = new Uint8Array(4);
  gl.readPixels(x, canvas.height - y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
  return `pixel at (${x/2},${y/2}): rgba(${pixels[0]},${pixels[1]},${pixels[2]},${pixels[3]})`;
});
console.log('Canvas pixel:', tilePixels);

console.log('\nConsole logs (image-related):');
allLogs.filter(l => l.toLowerCase().includes('image') || l.toLowerCase().includes('decode') || l.toLowerCase().includes('error') || l.toLowerCase().includes('fail'))
  .forEach(l => console.log(' ', l));

await page.screenshot({ path: '/tmp/deep_debug.png' });
await browser.close();
