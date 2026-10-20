'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const reports = [
  ['arc-fleet-operations', 'Live Arc fleet inventory, telemetry coverage, performance, failures, agent versions and priority actions. Rebuilt from currently accessible Azure resources in the selected subscription on every open; no embedded machines or fallback inventory.'],
  ['arc-priority-lifecycle', 'Live Arc priority queue, patch evidence, lifecycle inventory, performance and reliability. Rebuilt from currently accessible Azure resources in the selected subscription on every open; missing evidence is explicitly not assessed.']
];
const script = fs.readFileSync(path.join(__dirname, 'report.js'), 'utf8');
let stale = false;
for (const [name, description] of reports) {
  const file = path.join(__dirname, '..', '..', 'reports', name + '-cleaned.livereport.json');
  const bundle = JSON.parse(fs.readFileSync(file, 'utf8'));
  const template = fs.readFileSync(path.join(__dirname, name + '.html'), 'utf8');
  if (template.split('__REPORT_SCRIPT__').length !== 2) throw new Error('Expected one script marker in ' + name);
  const html = template.replace('__REPORT_SCRIPT__', () => script);
  const hash = crypto.createHash('sha256').update(html, 'utf8').digest('hex');
  if (bundle.spec.htmlSha256 === hash && bundle.metadata.description === description) continue;
  stale = true;
  if (process.argv.includes('--check')) {
    console.error('FAIL: rebuild ' + name + ' with node templates/arc-operations/build.js');
    continue;
  }
  bundle.spec.html = html;
  bundle.spec.htmlSha256 = hash;
  bundle.spec.htmlBytes = Buffer.byteLength(html, 'utf8');
  bundle.metadata.description = description;
  bundle.metadata.exportedAt = new Date().toISOString();
  bundle.metadata.exportedBy = 'templates/arc-operations/build.js';
  delete bundle.metadata.cleaned;
  for (const binding of bundle.bindings) {
    binding.occurrences = html.split(binding.value).length - 1;
    if (!binding.occurrences) throw new Error('Missing binding ' + binding.name);
  }
  bundle.warnings = [];
  fs.writeFileSync(file, JSON.stringify(bundle, null, 2) + '\n', 'utf8');
  console.log('Built ' + name);
}
if (stale && process.argv.includes('--check')) process.exitCode = 1;
