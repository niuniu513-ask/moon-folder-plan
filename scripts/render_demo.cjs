'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {render} = require('./report.cjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'moonfolder-preview-'));
try {
  for (const name of ['课程讲义.pdf', '旅行照片.jpg', '会议纪要.docx', '项目源码.zip', 'data.json', '便签.txt', '.hidden']) {
    fs.writeFileSync(path.join(root, name), 'Synthetic demo bytes: ' + name);
  }
  fs.mkdirSync(path.join(root, '子目录'));
  const report = JSON.parse(execFileSync(process.execPath,
    [path.join(__dirname, 'moonfolder.cjs'), 'preview', root], {encoding: 'utf8'}));
  const output = path.join(__dirname, '../docs/demo-preview.html');
  fs.mkdirSync(path.dirname(output), {recursive: true});
  fs.writeFileSync(output, render(report, '示例目录 · 虚构文件，不含个人资料'));
  console.log(output);
} finally {
  if (!root.startsWith(path.join(os.tmpdir(), 'moonfolder-preview-'))) throw new Error('Unexpected temporary root');
  fs.rmSync(root, {recursive: true, force: true});
}
