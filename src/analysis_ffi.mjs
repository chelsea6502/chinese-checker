export function getOrigin() {
  return globalThis.location?.origin ?? "";
}

// jieba-wasm Chinese word segmentation.
// Loads WASM asynchronously on module init; falls back to char-by-char if not ready.
let cutFn = null;

import('/jieba/jieba_rs_wasm.js')
  .then(async (jieba) => {
    await jieba.default('/jieba/jieba_rs_wasm_bg.wasm');
    cutFn = jieba.cut;
  })
  .catch(e => {
    console.error("Failed to initialize jieba-wasm:", e);
  });

// Returns segments joined by newlines so Gleam can string.split them.
export function segmentChinese(text) {
  if (!text) return "";
  if (cutFn) {
    return cutFn(text, false).join("\n");
  }
  // Fallback: character-by-character
  return [...text].join("\n");
}
