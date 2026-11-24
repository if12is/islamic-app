// Runs inside the app's WebView and talks to Dart over the `TilawaChannel`
// JavaScript channel. Everything the page sends is one JSON string:
//   {t: 'progress'|'ready'|'listening'|'level'|'position'|'checker'|'done'|'error', ...}
// Dart calls the functions on `window.host`.
import { createTilawa } from "@tilawa/core/web";

const post = (message) => {
  try {
    TilawaChannel.postMessage(JSON.stringify(message));
  } catch (_) {
    /* the page outlived the app's channel; nothing to tell */
  }
};

const fail = (stage, e) =>
  post({ t: "error", stage, name: (e && e.name) || "Error", message: String((e && e.message) || e) });

let tilawa = null;
let session = null;
let mic = null;
let unsubscribe = null;

// Models are already on disk behind the local mirror, so the Cache API would
// only hold a second copy.
const memoryStorage = () => ({
  get: async () => null,
  put: async () => {},
  delete: async () => {},
  keys: async () => [],
});

const slimWord = (w) => (w ? { s: w.surah, a: w.ayah, w: w.word } : null);

const onEvent = (e) => {
  if (e.type === "position") {
    post({
      t: "position",
      state: e.state,
      expected: slimWord(e.expected),
      observed: e.observed.slice(0, 1).map((o) => ({
        word: slimWord(o.word),
        confidence: o.confidence,
      })),
    });
  } else if (e.type === "checker") {
    post({
      t: "checker",
      id: e.id,
      state: e.state,
      errorClass: e.errorClass,
      location: slimWord(e.location),
      confidence: e.confidence,
    });
  }
};

window.host = {
  /**
   * Warm the model. `assetBase` is the app's local mirror of
   * https://tilawa.dev/v1/ (the Dart side downloaded it beforehand); when it
   * is given nothing is cached a second time in the WebView.
   * `tier` is "auto" | "full" | "lite".
   */
  async load(tier, assetBase) {
    try {
      tilawa = await createTilawa({
        tier: tier || "auto",
        ...(assetBase ? { assetBase, storage: memoryStorage() } : {}),
        threads: 1,
        onProgress: (p) => post({ t: "progress", stage: p.stage, fraction: p.fraction, fromCache: p.fromCache }),
      });
      post({ t: "ready", tier: tilawa.model.tier, backend: tilawa.model.backend });
    } catch (e) {
      fail("load", e);
    }
  },

  /**
   * `passage` is null for free recitation, or {surah, fromAyah, toAyah} for a
   * known passage.
   */
  async start(passage) {
    try {
      await this.stop(true);
      session = passage
        ? tilawa.startMemorization(passage, { confirm: { after: "next-word" } })
        : tilawa.startFreeRecitation();
      unsubscribe = session.subscribe(onEvent);
      const options = { onLevel: (db) => post({ t: "level", db }) };
      mic = await tilawa.listen(session, options);
      post({ t: "listening" });
    } catch (e) {
      fail("microphone", e);
    }
  },

  /** Closes the microphone, then the session, and reports the confirmed mistakes. */
  async stop(silent) {
    const current = session;
    try {
      if (mic) await mic.stop();
    } catch (e) {
      if (!silent) fail("stop", e);
    }
    mic = null;
    if (unsubscribe) unsubscribe();
    unsubscribe = null;
    session = null;
    if (!current) return;
    const mistakes = current.mistakes().map((m) => ({
      id: m.id,
      errorClass: m.errorClass,
      location: slimWord(m.location),
    }));
    try {
      current.dispose();
    } catch (_) {}
    if (!silent) post({ t: "done", mistakes });
  },

  async dispose() {
    await this.stop(true);
    if (tilawa) await tilawa.dispose();
    tilawa = null;
  },
};

post({ t: "booted" });
