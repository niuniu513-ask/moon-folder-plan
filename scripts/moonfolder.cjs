#!/usr/bin/env node
'use strict';
const path = require('node:path');
const fs = require('node:fs');
globalThis.moonFolderHost = require('./file_host.cjs');
const binary = path.join(__dirname, '../_build/js/release/build/cmd/files/files.js');
if (!fs.existsSync(binary)) {
  console.error('Build first: moon build cmd/files --target js --release --deny-warn');
  process.exitCode = 1;
} else {
  try { require(binary); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
