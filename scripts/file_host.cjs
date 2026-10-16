'use strict';
// Physical I/O only. Classification, path choice, exclusions and collision
// numbering are computed by MoonBit. All copy actions preserve source files.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const MAX_ENTRIES = 4096;
const MAX_FILE = 1099511627776;
const BATCH = /^MoonFolderPlan-[0-9]{13}-[a-f0-9]{16}$/;

function directory(value) {
  const resolved = path.resolve(value);
  if (fs.lstatSync(resolved).isSymbolicLink()) throw new Error('Root must not be a symbolic link');
  const root = fs.realpathSync(resolved);
  if (!fs.statSync(root).isDirectory()) throw new Error('Expected directory');
  return root;
}

function regular(file, max = MAX_FILE) {
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size > max) {
    throw new Error('Expected bounded regular file: ' + file);
  }
  return stat;
}

function component(name) {
  if (typeof name !== 'string' || !name || name === '.' || name === '..' ||
      /[\x00-\x1f\x7f/\\:*?"<>|]/.test(name) || /[. ]$/.test(name) ||
      /^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\.|$)/i.test(name)) {
    throw new Error('Invalid path component');
  }
  return name;
}

function destination(batch, item) {
  component(item.source);
  if (typeof item.destination !== 'string') throw new Error('Invalid destination');
  const parts = item.destination.split('/');
  if (parts.length !== 2 || !/^[A-Za-z0-9_-]{1,32}$/.test(parts[0]) ||
      parts[0] !== item.category) throw new Error('Invalid category');
  parts.forEach(component);
  return path.join(batch, ...parts);
}

function folded(value) { return value.replace(/[A-Z]/g, c => c.toLowerCase()); }

function hash(file) {
  regular(file);
  const fd = fs.openSync(file, 'r');
  const digest = crypto.createHash('sha256');
  const buffer = Buffer.alloc(1024 * 1024);
  try {
    for (;;) {
      const count = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (!count) break;
      digest.update(buffer.subarray(0, count));
    }
  } finally { fs.closeSync(fd); }
  return digest.digest('hex');
}

function save(receipt, data) {
  const temporary = receipt + '.' + crypto.randomBytes(8).toString('hex') + '.tmp';
  fs.writeFileSync(temporary, JSON.stringify(data, null, 2), {flag: 'wx'});
  fs.renameSync(temporary, receipt);
}

function scan(value) {
  const root = directory(value);
  const names = fs.readdirSync(root);
  if (names.length > MAX_ENTRIES) throw new Error('At most 4096 immediate entries');
  const entries = names.map(name => {
    const stat = fs.lstatSync(path.join(root, name));
    return {name, size: String(stat.size), kind: stat.isSymbolicLink() ? 'symlink' :
      stat.isFile() ? 'file' : stat.isDirectory() ? 'directory' : 'other'};
  });
  return JSON.stringify(entries);
}

function execute(value, serialized) {
  const root = directory(value);
  const plan = JSON.parse(serialized);
  if (plan.schema !== 'moon-folder-plan-v1' || !Array.isArray(plan.items) ||
      plan.items.length > MAX_ENTRIES) throw new Error('Invalid plan');
  if (!plan.items.length) return JSON.stringify({copied: 0, receipt: null});
  const batchName = 'MoonFolderPlan-' + Date.now() + '-' + crypto.randomBytes(8).toString('hex');
  const batch = path.join(root, batchName);
  // Validate the entire plan before creating any directories.
  const sources = new Set(), targets = new Set();
  for (const item of plan.items) {
    const target = destination(batch, item);
    if (sources.has(item.source) || targets.has(folded(target))) throw new Error('Duplicate plan path');
    sources.add(item.source); targets.add(folded(target));
    const stat = regular(path.join(root, item.source));
    if (String(stat.size) !== item.size) throw new Error('Source changed since preview');
  }
  fs.mkdirSync(batch); // exclusive fresh batch: existing files are never overwritten
  const receipt = path.join(batch, 'receipt.json');
  const data = {schema: 'moon-folder-receipt-v1', root, batch: batchName,
    state: 'copying', items: plan.items.map(item => ({...item, sha256: null, state: 'pending'}))};
  save(receipt, data);
  try {
    for (const item of data.items) {
      const source = path.join(root, item.source), target = destination(batch, item);
      const before = regular(source);
      if (String(before.size) !== item.size) throw new Error('Source size changed');
      item.sha256 = hash(source);
      save(receipt, data); // expected content recorded before starting the copy
      const parent = path.dirname(target);
      if (!fs.existsSync(parent)) fs.mkdirSync(parent);
      if (!fs.lstatSync(parent).isDirectory() || fs.lstatSync(parent).isSymbolicLink()) throw new Error('Unsafe target directory');
      fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
      if (hash(target) !== item.sha256 || hash(source) !== item.sha256) throw new Error('Content changed during copy');
      const after = regular(source);
      if (after.size !== before.size || after.mtimeMs !== before.mtimeMs) throw new Error('Source changed during copy');
      item.state = 'copied';
      save(receipt, data);
    }
    data.state = 'complete'; save(receipt, data);
    return JSON.stringify({copied: data.items.length, batch, receipt, originals_preserved: true});
  } catch (error) {
    data.state = 'incomplete'; save(receipt, data);
    throw new Error(error.message + '; recovery receipt: ' + receipt);
  }
}

function undo(value) {
  const receipt = path.resolve(value);
  // 4096 entries with multibyte filenames and audit fields can exceed 2 MiB.
  regular(receipt, 8 * 1024 * 1024);
  const data = JSON.parse(fs.readFileSync(receipt, 'utf8'));
  if (data.schema !== 'moon-folder-receipt-v1' || !BATCH.test(data.batch) ||
      !Array.isArray(data.items) || data.items.length > MAX_ENTRIES || typeof data.root !== 'string') {
    throw new Error('Invalid receipt');
  }
  const root = directory(data.root), batch = path.join(root, data.batch);
  if (directory(batch) !== batch || receipt !== path.join(batch, 'receipt.json')) throw new Error('Receipt location mismatch');
  const pending = [], targets = new Set();
  for (const item of data.items) {
    const target = destination(batch, item);
    if (targets.has(folded(target))) throw new Error('Duplicate receipt destination');
    targets.add(folded(target));
    const parent = path.dirname(target);
    if (fs.existsSync(parent) && (!fs.lstatSync(parent).isDirectory() || fs.lstatSync(parent).isSymbolicLink())) {
      throw new Error('Unsafe copy directory');
    }
    if (!fs.existsSync(target)) continue;
    if (!/^[a-f0-9]{64}$/.test(item.sha256)) throw new Error('Missing content identity');
    // A changed copy or missing/changed original blocks the entire undo preflight.
    if (hash(target) !== item.sha256 || hash(path.join(root, component(item.source))) !== item.sha256) {
      throw new Error('Copy or original changed; no files removed');
    }
    pending.push({item, target});
  }
  for (const {item, target} of pending) {
    fs.unlinkSync(target);
    item.state = 'undone';
    save(receipt, data);
  }
  data.state = 'undone'; save(receipt, data);
  // Keep the receipt and empty directories for audit/recovery; never recursively delete.
  return JSON.stringify({removed_copies: pending.length, originals_preserved: true, receipt});
}

module.exports = {scan, execute, undo};
