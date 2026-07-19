'use strict';
// Keep puppeteer's downloaded Chrome inside the repo (gitignored) instead of
// the shared home cache, so `make chrome` is self-contained and reproducible.
module.exports = {
    cacheDirectory: './.cache',
};
