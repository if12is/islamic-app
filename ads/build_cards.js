// Compose the store cards: one screenshot per card, in a phone, on the brand.
//
// Rendered through a browser rather than drawn with an image library, because
// the type is the point: the cards are set in Reem Kufi and Cairo, the app's
// own faces, loaded from the app's own asset folder. A card in a different
// typeface is a card for a different product.
//
//   node ads/build_cards.js
//
// Needs puppeteer-core and Google Chrome. Screens come from
// `python3 scripts/capture_screens.py`, or the puppeteer capture beside it.

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const ADS = __dirname;
const SCREENS = path.join(ADS, 'screens');
const OUT = path.join(ADS, 'cards');

// A 9:16 card at store-listing size, which is also what a story wants.
const WIDTH = 1080;
const HEIGHT = 1920;

// One line each. The title names the screen, the subtitle says what it is for
// — not what it contains, which the picture underneath is already saying.
const CARDS = [
  {
    file: 'home',
    title: 'يومك يبدأ من هنا',
    sub: 'الصلاة القادمة، وردك، وكل ما تحتاجه في شاشة واحدة',
  },
  {
    file: 'prayer_times',
    title: 'مواقيت الصلاة',
    sub: 'محسوبة على جهازك من موقعك — تعمل بلا إنترنت، وتسجّل كيف صلّيت',
  },
  {
    file: 'quran',
    title: 'المصحف كاملاً',
    sub: 'بالسور والأجزاء والأحزاب والصفحات، مع خطة ختمة تحسب وردك اليومي',
  },
  {
    file: 'azkar',
    title: 'الأذكار والتسبيح',
    sub: 'حصن المسلم كاملاً، وسبحة تعدّ معك وتحفظ ما سبّحت',
  },
  {
    file: 'wird',
    title: 'وردك اليومي',
    sub: 'أضف أي سورة أو جزء أو ذكر أو تسبيح إلى وردك، وتابعه كل يوم',
  },
  {
    // This shot is scrolled to where the add buttons are, so the caption is
    // about them rather than about the beads above them.
    file: 'azkar_tasbeeh',
    title: 'أضفه لوردك بضغطة',
    sub: 'من أي باب أذكار أو سورة أو تسبيح — يُصبح جزءاً من وردك اليومي',
  },
  {
    file: 'prayer_tools',
    title: 'كل ما حول الصلاة',
    sub: 'القبلة، جدول الشهر، أقرب المساجد، ووضع السفر',
  },
];

async function main() {
  fs.mkdirSync(OUT, { recursive: true });

  const missing = CARDS.filter(
    (c) => !fs.existsSync(path.join(SCREENS, `${c.file}.png`))
  );
  if (missing.length) {
    console.error(
      'Missing screenshots:',
      missing.map((c) => c.file).join(', '),
      '\nRun the capture script first.'
    );
    process.exit(1);
  }

  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    // The card loads the screenshots and the fonts off disk, which a browser
    // will not do from a file:// page without being told.
    args: ['--no-sandbox', '--allow-file-access-from-files'],
    defaultViewport: { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 },
  });

  const page = await browser.newPage();
  await page.goto('file://' + path.join(ADS, 'card.html'), {
    waitUntil: 'networkidle0',
  });

  for (const card of CARDS) {
    await page.evaluate(
      (c, dir) => {
        document.getElementById('title').textContent = c.title;
        document.getElementById('sub').textContent = c.sub;
        document.getElementById('shot').src = `${dir}/${c.file}.png`;
      },
      card,
      'screens'
    );

    // Wait for the screenshot itself to decode, or the card is composed
    // around an image that is not there yet.
    await page.evaluate(
      () =>
        new Promise((resolve) => {
          const img = document.getElementById('shot');
          if (img.complete && img.naturalWidth) return resolve();
          img.onload = resolve;
          img.onerror = resolve;
        })
    );
    await new Promise((r) => setTimeout(r, 400));

    const file = path.join(OUT, `${card.file}.png`);
    await page.screenshot({ path: file });
    const kb = (fs.statSync(file).size / 1024).toFixed(0);
    console.log(`  ${card.file.padEnd(16)} ${kb.padStart(6)} KB  ${card.title}`);
  }

  await browser.close();
  console.log(`\n${CARDS.length} cards in ${OUT}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
