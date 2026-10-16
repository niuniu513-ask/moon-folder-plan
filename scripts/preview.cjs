#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {render} = require('./report.cjs');
if (process.argv.length !== 4) {
  console.error('usage: node scripts/preview.cjs DIRECTORY NEW_REPORT.html');
  process.exitCode = 1;
} else {
  try {
    const root = path.resolve(process.argv[2]);
    const plan = JSON.parse(execFileSync(process.execPath,
      [path.join(__dirname, 'moonfolder.cjs'), 'preview', root],
      {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024}));
    fs.writeFileSync(process.argv[3], render(plan, root), {flag: 'wx'});
    console.log('Preview saved: ' + path.resolve(process.argv[3]));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
