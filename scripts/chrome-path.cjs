'use strict';
// Prints the absolute Chrome executable path resolved by puppeteer (reads .puppeteerrc.cjs).
// Exits non-zero if the resolved binary does not exist on disk.
const path = require('path');
const fs = require('fs');
const abs = path.resolve(require('puppeteer').executablePath());
if (!fs.existsSync(abs)) {
    process.exit(1);
}
process.stdout.write(abs);
