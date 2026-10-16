'use strict';
// Failure injection at the physical adapter boundary, without production switches.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const host = require('./file_host.cjs');
const {render} = require('./report.cjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'moonfolder-host-'));
try {
  fs.writeFileSync(path.join(root, 'a.txt'), 'alpha');
  fs.writeFileSync(path.join(root, 'b.txt'), 'beta');
  const plan = {schema: 'moon-folder-plan-v1', items: [
    {source: 'a.txt', destination: 'Documents/a.txt', category: 'Documents', size: '5'},
    {source: 'b.txt', destination: 'Documents/b.txt', category: 'Documents', size: '4'},
  ]};
  const before = fs.readdirSync(root);
  const bad = JSON.parse(JSON.stringify(plan));
  bad.items[0].destination = '../outside';
  assert.throws(() => host.execute(root, JSON.stringify(bad)), /Invalid category/);
  assert.deepEqual(fs.readdirSync(root), before);
  const stale = JSON.parse(JSON.stringify(plan));
  stale.items[0].size = '99';
  assert.throws(() => host.execute(root, JSON.stringify(stale)), /Source changed/);
  assert.deepEqual(fs.readdirSync(root), before);

  const copy = fs.copyFileSync;
  let calls = 0;
  fs.copyFileSync = (...args) => {
    calls++;
    if (calls === 2) throw new Error('injected disk failure');
    return copy(...args);
  };
  try { assert.throws(() => host.execute(root, JSON.stringify(plan)), /recovery receipt/); }
  finally { fs.copyFileSync = copy; }
  const batch = fs.readdirSync(root).find(name => name.startsWith('MoonFolderPlan-'));
  const receipt = path.join(root, batch, 'receipt.json');
  assert.equal(JSON.parse(fs.readFileSync(receipt)).state, 'incomplete');
  assert.equal(JSON.parse(host.undo(receipt)).removed_copies, 1);
  assert.equal(fs.readFileSync(path.join(root, 'a.txt'), 'utf8'), 'alpha');
  assert.equal(fs.readFileSync(path.join(root, 'b.txt'), 'utf8'), 'beta');
  // A valid receipt can exceed 2 MiB at the declared 4096-entry limit.
  const largeReceipt = JSON.parse(fs.readFileSync(receipt));
  largeReceipt.audit_note = 'x'.repeat(2200000);
  fs.writeFileSync(receipt, JSON.stringify(largeReceipt));
  assert.equal(JSON.parse(host.undo(receipt)).removed_copies, 0);
  const html = render({items: [], skipped: [{name: '<script>alert(1)</script>', reason: 'unknown'}], total_bytes: '0'}, '<script>root</script>');
  assert(!html.includes('<script>alert(1)</script>'));
  assert(!html.includes('<script>root</script>'));
  assert(html.includes('&lt;script&gt;'));
  console.log('host failure injection: passed (invalid paths, stale plan, partial copy recovery)');
} finally {
  // This verified, directly-created temporary tree contains synthetic data only.
  if (!root.startsWith(path.join(os.tmpdir(), 'moonfolder-host-'))) throw new Error('Unexpected temporary root');
  fs.rmSync(root, {recursive: true, force: true});
}
