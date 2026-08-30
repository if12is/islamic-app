// Photograph the app's screens from the web build.
//
// Headless Chrome's --screenshot with --virtual-time-budget never got past the
// splash: Flutter runs a continuous rAF loop, so the page is never idle, and
// the shot lands on whatever is on screen when the budget expires. Driving the
// browser gives a real wall-clock wait instead of a guess, and lets each screen
// be reached by tapping the nav bar the way a person would.

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BASE = process.env.BASE || 'http://127.0.0.1:8899/';
const OUT = process.env.OUT || './screens';

// A phone at three times the density, which is what a store listing wants.
const WIDTH = 390;
const HEIGHT = 844;
const SCALE = 3;

// Flutter's SharedPreferences on the web is localStorage under this prefix.
const PREFIX = 'flutter.';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// The bar is at the bottom, five slots wide, with the middle one raised.
// Tapping it is how a person changes screen, and it is the only way in: the
// destinations are an IndexedStack behind a provider, so there is no URL.
//
// Visual order is right-to-left, and the raised centre is home.
const NAV_Y = HEIGHT - 52;
const SLOT = WIDTH / 5;
const tapAt = (slot) => ({ x: SLOT * (slot + 0.5), y: NAV_Y });

// The theme toggle is the header's leading slot, which in a right-to-left
// layout is the top right. Tapping it is how the light theme gets set: the
// web SharedPreferences encoding is an implementation detail of a plugin, and
// seeding it by hand is a guess, while pressing the button is what a person
// does and cannot be wrong.
const THEME_TOGGLE = { x: WIDTH - 28, y: 46 };

// Slots are pixel positions, left to right. The bar is laid out right to left,
// so the first destination in the code sits at the far right and the order in
// pixels is the reverse of the order in the list:
//
//   pixel 0        1        2        3        4
//         prayer   quran    home     azkar    wird
//
// Reading it the other way round crossed the Quran and the Azkar screens, and
// three cards came out captioned as the wrong feature.
const SCREENS = [
  { name: 'home', slot: 2, settle: 3500 },
  { name: 'prayer_times', slot: 0, settle: 3500 },
  { name: 'quran', slot: 1, settle: 3500 },
  { name: 'azkar', slot: 3, settle: 3500 },
  { name: 'wird', slot: 4, settle: 3500 },
  // Scrolled, because the part of these screens worth showing is not the part
  // that happens to be at the top.
  { name: 'azkar_tasbeeh', slot: 3, settle: 3000, scroll: 560 },
  { name: 'quran_juz', slot: 1, settle: 3000, scroll: 420 },
  { name: 'prayer_tools', slot: 0, settle: 3200, scroll: 1700 },
];

async function main() {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--hide-scrollbars', '--disable-lcd-text'],
    defaultViewport: {
      width: WIDTH,
      height: HEIGHT,
      deviceScaleFactor: SCALE,
      isMobile: true,
      hasTouch: true,
    },
  });

  const page = await browser.newPage();

  // Seed before the app boots: past onboarding, light theme, and a name so the
  // header is not showing an empty state in a listing.
  await page.evaluateOnNewDocument((prefix) => {
    const set = (k, v) => localStorage.setItem(prefix + k, v);
    set('is_first_launch', 'false');
    set('seasonal_intro_enabled', 'false');
    set('theme_mode', 'ThemeMode.light');
    set('user_display_name', 'أحمد');
    set('user_city', 'دمنهور، البحيرة، مصر');
    set('user_latitude', '31.0345728');
    set('user_longitude', '30.4676864');
    set('location_is_manual', 'true');
  }, PREFIX);

  console.log('loading', BASE);
  await page.goto(BASE, { waitUntil: 'networkidle2', timeout: 120000 });

  // The splash waits 600ms and then hands over; the first real frame needs the
  // canvas kit and the fonts. Twelve seconds is generous and costs nothing.
  await sleep(12000);

  // The app opens dark by default. A store listing wants the light theme,
  // which is what most people see and what the cards are built on.
  await page.mouse.click(THEME_TOGGLE.x, THEME_TOGGLE.y);
  await sleep(2500);

  for (const screen of SCREENS) {
    const { x, y } = tapAt(screen.slot);
    try {
      await page.mouse.click(x, y);
      await sleep(900);
      if (screen.scroll) {
        // Scroll the body, then let the list settle before the shutter.
        await page.mouse.move(WIDTH / 2, HEIGHT / 2);
        await page.mouse.wheel({ deltaY: screen.scroll });
      }
    } catch (e) {
      console.log('  tap failed', screen.name, e.message);
    }
    await sleep(screen.settle);

    const file = path.join(OUT, `${screen.name}.png`);
    await page.screenshot({ path: file });
    const kb = (fs.statSync(file).size / 1024).toFixed(0);
    console.log(`  ${screen.name.padEnd(16)} ${kb.padStart(6)} KB`);
  }

  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
