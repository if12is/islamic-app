// Photograph the app's screens from the web build.
//
// Headless Chrome's --screenshot with --virtual-time-budget never got past the
// splash: Flutter runs a continuous rAF loop, so the page is never idle, and
// the shot lands on whatever is on screen when the budget expires. Driving the
// browser gives a real wall-clock wait instead of a guess, and lets a screen be
// reached by tapping through the app the way a person would.
//
//   npm i puppeteer-core
//   flutter build web --release
//   python3 -m http.server 8899 --directory build/web &
//   OUT=ads/screens node scripts/shoot.js

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BASE = process.env.BASE || 'http://127.0.0.1:8899/';
const OUT = process.env.OUT || './screens';
const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null;

// A phone at three times the density, which is what a store listing wants.
const WIDTH = 390;
const HEIGHT = 844;
const SCALE = 3;

// Flutter's SharedPreferences on the web is localStorage under this prefix.
const PREFIX = 'flutter.';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Slots are pixel positions, left to right. The bar is laid out right to left,
// so the first destination in the code sits at the far right and the order in
// pixels is the reverse of the order in the list:
//
//   pixel 0        1        2        3        4
//         prayer   quran    home     azkar    wird
//
// Reading it the other way round crossed the Quran and the Azkar screens, and
// three cards came out captioned as the wrong feature.
const NAV_Y = HEIGHT - 52;
const SLOT = WIDTH / 5;
const nav = (slot) => ({ x: SLOT * (slot + 0.5), y: NAV_Y });

// Measured off a screenshot rather than guessed. The header controls sit
// higher than they look: the tile runs y 20 to 46, so a tap at y 46 lands on
// its bottom edge and, more often, on nothing — which is why every screen
// behind Settings came back as the home screen.
const THEME_TOGGLE = { x: WIDTH - 26, y: 33 };
const PROFILE = { x: 26, y: 33 };

// The back arrow of a pushed page, which in Arabic points right.
const BACK = { x: WIDTH - 26, y: 33 };

/**
 * Each screen is a small script: where to tap, how far to scroll, how long to
 * wait. Written as data rather than as code so a screen that comes out wrong
 * is one line to correct, and so the list reads as what it produces.
 *
 *   nav      the bottom-bar slot to start from
 *   steps    taps and scrolls, in order
 *   dark     shoot this one in the dark theme
 */
const SCREENS = [
  // ---- the five destinations -------------------------------------------
  { name: 'home', nav: 2 },
  { name: 'prayer_times', nav: 0 },
  { name: 'quran', nav: 1 },
  { name: 'azkar', nav: 3 },
  { name: 'wird', nav: 4 },

  // ---- scrolled, where the part worth showing is not at the top --------
  { name: 'azkar_cards', nav: 3, steps: [{ scroll: 560 }] },
  { name: 'quran_index', nav: 1, steps: [{ scroll: 420 }] },
  { name: 'prayer_tools', nav: 0, steps: [{ scroll: 1700 }] },
  { name: 'prayer_log', nav: 0, steps: [{ scroll: 380 }] },

  // ---- the reader, which is the app's largest screen --------------------
  {
    name: 'reader',
    nav: 1,
    steps: [{ scroll: 420 }, { tap: { x: 200, y: 470 } }, { wait: 2500 }],
  },

  // Settings itself, which is also the reference for where its rows sit.
  { name: 'settings', nav: 2, steps: [{ tap: PROFILE }, { wait: 2200 }] },
  {
    name: 'settings_tools',
    nav: 2,
    steps: [{ tap: PROFILE }, { wait: 2000 }, { scroll: 620 }, { wait: 900 }],
  },

  // ---- the tools behind Settings ---------------------------------------
  // The rows are a fixed list, so their y positions are predictable once the
  // profile header and the two cards above them are accounted for.
  // Row positions measured off `settings_tools`, not guessed: with the page
  // scrolled 620 the tools land at 495, 588, 682 and 769, and Broadcasts is
  // below the fold until the scroll goes further.
  {
    name: 'notification_center',
    nav: 2,
    steps: [{ tap: PROFILE }, { wait: 2000 }, { scroll: 620 }, { tap: { x: 195, y: 495 } }, { wait: 2600 }],
  },
  {
    name: 'hijri_calendar',
    nav: 2,
    steps: [{ tap: PROFILE }, { wait: 2000 }, { scroll: 620 }, { tap: { x: 195, y: 682 } }, { wait: 2600 }],
  },
  {
    name: 'zakat',
    nav: 2,
    steps: [{ tap: PROFILE }, { wait: 2000 }, { scroll: 620 }, { tap: { x: 195, y: 769 } }, { wait: 2600 }],
  },
  {
    // Broadcasts is one row below Zakat, which puts it off the fold at 620.
    // Two scrolls rather than one big one: the positions above were measured
    // at 620, so keeping that step and adding to it keeps them usable.
    name: 'broadcasts',
    nav: 2,
    steps: [
      { tap: PROFILE },
      { wait: 2000 },
      { scroll: 620 },
      { scroll: 200 },
      { tap: { x: 195, y: 757 } },
      { wait: 3200 },
    ],
  },

  // ---- the dark theme, because half the app is that ---------------------
  { name: 'home_dark', nav: 2, dark: true },
  { name: 'quran_dark', nav: 1, dark: true, steps: [{ scroll: 420 }] },
];

async function run(page, screen) {
  if (screen.nav !== undefined) {
    const { x, y } = nav(screen.nav);
    await page.mouse.click(x, y);
    await sleep(1000);
  }

  for (const step of screen.steps || []) {
    if (step.tap) {
      await page.mouse.click(step.tap.x, step.tap.y);
      await sleep(900);
    }
    if (step.scroll) {
      await page.mouse.move(WIDTH / 2, HEIGHT / 2);
      await page.mouse.wheel({ deltaY: step.scroll });
      await sleep(700);
    }
    if (step.wait) {
      await sleep(step.wait);
    }
  }

  await sleep(2200);
}

/**
 * Get back to the shell, whatever page the last shot ended on.
 *
 * By reloading, not by tapping back. The back arrow of a pushed page and the
 * theme toggle of the shell are the same point on the screen — so a back tap
 * that arrives one page too late flips the theme instead, and the next four
 * screens come out in the wrong one. A reload cannot land on the wrong
 * control, and localStorage survives it, so nothing is lost but the seconds.
 */
async function reset(page) {
  await page.reload({ waitUntil: 'networkidle2', timeout: 120000 });
  await sleep(11000);
}


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

  // Seeded before the app boots: past onboarding, and a place so the header is
  // not showing an empty state in a listing.
  await page.evaluateOnNewDocument((prefix) => {
    const set = (k, v) => localStorage.setItem(prefix + k, v);
    set('is_first_launch', 'false');
    set('seasonal_intro_enabled', 'false');
    set('user_display_name', 'أحمد');
    set('user_city', 'دمنهور، البحيرة، مصر');
    set('user_latitude', '31.0345728');
    set('user_longitude', '30.4676864');
    set('location_is_manual', 'true');
  }, PREFIX);

  console.log('loading', BASE);
  await page.goto(BASE, { waitUntil: 'networkidle2', timeout: 120000 });

  // The splash waits 600ms and then hands over; the first real frame needs the
  // canvas kit and the fonts.
  await sleep(12000);

  // The app opens dark. Most of the cards want the light theme, so it is
  // switched once here and switched back for the two that do not — by tapping
  // the app's own control, because the web SharedPreferences encoding is an
  // implementation detail of a plugin and seeding it by hand is a guess.
  let dark = true;
  const setTheme = async (wantDark) => {
    if (dark === wantDark) return;
    await page.mouse.click(THEME_TOGGLE.x, THEME_TOGGLE.y);
    dark = wantDark;
    await sleep(2000);
  };
  await setTheme(false);

  const wanted = SCREENS.filter((s) => !ONLY || ONLY.includes(s.name));

  for (const screen of wanted) {
    try {
      await setTheme(!!screen.dark);
      await run(page, screen);

      const file = path.join(OUT, `${screen.name}.png`);
      await page.screenshot({ path: file });
      const kb = (fs.statSync(file).size / 1024).toFixed(0);
      console.log(`  ${screen.name.padEnd(20)} ${kb.padStart(6)} KB`);
    } catch (e) {
      console.log(`  ${screen.name.padEnd(20)} FAILED ${e.message}`);
    }
    await reset(page);
  }

  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
