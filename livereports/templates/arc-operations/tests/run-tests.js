'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const os = require('node:os');
const {execFileSync} = require('node:child_process');

const root = path.join(__dirname, '..', '..', '..');
const subscription = '00000000-0000-0000-0000-000000000000';
const id = '/subscriptions/' + subscription + '/resourceGroups/approved/providers/Microsoft.HybridCompute/machines/current-node';
const otherId = id.replace(subscription, '11111111-1111-1111-1111-111111111111');
const inventory = [{ResourceId: id, Machine: 'current-node', Status: 'Connected', OS: 'Observed OS', Agent: 'Observed version', ResourceGroup: 'approved'}];
const liveRow = {ResourceId: id, Computer: 'current-node.example.test', LastSeen: new Date().toISOString(), AMA: 'observed-ama'};
const queries = [];

class Element {
  constructor() {
    this.children = [];
    this.textContent = '';
    this.dataset = {};
    this.listeners = {};
    this.attributes = {};
    this.classes = new Set();
    this.classList = {toggle: value => this.classes.has(value) ? this.classes.delete(value) : this.classes.add(value)};
  }
  appendChild(node) { this.children.push(node); return node; }
  prepend(node) { this.children.unshift(node); }
  replaceChildren(...nodes) { this.children = nodes; this.textContent = ''; }
  addEventListener(event, listener) { this.listeners[event] = listener; }
  setAttribute(name, value) { this.attributes[name] = value; }
  getContext() { return {}; }
}
function text(node) { return String(node.textContent) + ' ' + node.children.map(text).join(' '); }
function envelope(rows, shape) {
  if (shape === 'string') return JSON.stringify({status: '200', results: rows});
  if (shape === 'double') return JSON.stringify(JSON.stringify({results: rows}));
  if (shape === 'mcp') return {content: [{type: 'text', text: JSON.stringify({results: rows})}]};
  if (shape === 'tables') {
    const columns = Object.keys(rows[0] || {});
    return {tables: [{columns: columns.map(name => ({name})), rows: rows.map(row => columns.map(column => row[column]))}]};
  }
  return rows;
}

async function run(kind, options = {}) {
  const bundlePath = path.join(root, 'reports', kind + '-cleaned.livereport.json');
  const bundle = JSON.parse(fs.readFileSync(bundlePath, 'utf8'));
  const html = bundle.spec.html;
  assert(!/\b(?:WIN|LNX)-SRV-\d+\b|ARG snapshot|all 23 machines|maint-daily/.test(html), 'No embedded demo machines or findings');
  assert(!/\son\w+\s*=\s*["']/.test(html.replace(/<script[\s\S]*?<\/script>/g, '')), 'No inline event handlers');
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Element()]));
  const headers = [...html.matchAll(/data-section="([^"]+)"/g)].map(match => {
    const node = new Element();
    node.dataset.section = match[1];
    return node;
  });
  const body = new Element();
  const calls = [];
  const document = {
    getElementById: name => elements.get(name) || null,
    createElement: () => new Element(),
    querySelectorAll: () => headers,
    body
  };
  const callTool = async (tool, args) => {
    assert.equal(tool, 'system-mcp-monitor_monitor_workspace_log_query');
    assert.equal(args.subscription, subscription);
    calls.push(args);
    if (options.capture) queries.push(args);
    const q = args.query;
    if (q.startsWith('arg("").Resources | where type =~ "microsoft.hybridcompute/machines"')) {
      assert(q.includes('where subscriptionId =~ "' + subscription + '"'));
      if (options.inventoryError) throw new Error('inventory permission denied');
      if (options.garbage) return 'invalid response';
      if (options.partial) return {error: {message: 'Partial query failure'}, tables: [{columns: [], rows: []}]};
      return envelope(options.inventory || inventory, options.shape);
    }
    if (q.startsWith('arg("")')) {
      assert(q.includes('where subscriptionId =~ "' + subscription + '"'));
      if (options.graphError) throw new Error('resource evidence denied');
      if (options.extensionFailure && q.includes('machines/extensions')) return [{...liveRow, Extension: 'actual-extension', Status: 'Failed', Version: '1'}];
      return envelope([], options.shape);
    }
    assert(q.includes('ResourceId in~ (' + JSON.stringify(id.toLowerCase()) + ')'), 'Telemetry must use exact current resource IDs');
    assert(!q.includes('by Computer'), 'No hostname-only correlation across networks');
    if (options.heartbeatError && args.table === 'Heartbeat') throw new Error('heartbeat permission denied');
    if (options.perfError && args.table === 'Perf') return {status: 500, message: 'performance query failed'};
    if (options.emptyTelemetry) return envelope([], options.shape);
    if (args.table === 'Heartbeat') return envelope([liveRow, {...liveRow, ResourceId: otherId, Computer: 'other-network'}], options.shape);
    if (options.pressure && args.table === 'Perf' && q.includes('Free=')) {
      return [{...liveRow, Free: typeof options.pressure === 'number' ? options.pressure : 4.9, InstanceName: 'C:'}, {...liveRow, ResourceId: otherId, Free: 1, InstanceName: 'other-network'}];
    }
    return envelope([], options.shape);
  };
  const source = html.split('<script nonce="{REPORT_NONCE}">')[1].split('</script>')[0]
    .replaceAll('__SUBSCRIPTION_ID__', subscription)
    .replaceAll('__RESOURCE_GROUP__', 'workspace-rg')
    .replaceAll('__WORKSPACE__', 'workspace-id');
  await vm.runInNewContext(source, {document, window: {sreagent: {callTool}}, console}, {timeout: 5000});
  assert(!text(body).includes('Report rendering failed'), text(body));
  const allText = [...elements.values()].map(text).join(' ') + text(body);
  assert(!allText.includes('other-network'), 'Out-of-scope telemetry must never be displayed');
  return {elements, headers, calls, allText};
}

(async () => {
  let checks = 0;
  for (const kind of ['arc-fleet-operations', 'arc-priority-lifecycle']) {
    for (const shape of ['object', 'string', 'double', 'mcp', 'tables']) {
      const result = await run(kind, {shape, capture: kind === 'arc-priority-lifecycle' && shape === 'object'});
      assert(result.allText.includes('current-node'), 'Current infrastructure is displayed: ' + result.allText);
      assert(result.allText.includes('observed-ama'), 'FQDN telemetry correlates by resource ID');
      assert(result.allText.includes('not assessed') || result.allText.includes('Not assessed'));
      assert.equal(result.calls.length, 12);
      checks++;
    }
    for (const options of [{inventory: []}, {inventoryError: true}, {garbage: true}, {partial: true}, {inventory: Array(1000).fill(inventory[0])}, {inventory: [{...inventory[0], ResourceId: otherId}]}]) {
      const result = await run(kind, options);
      assert.equal(result.calls.length, 1, 'Do not query telemetry without a trusted current inventory');
      assert(result.allText.includes('Unavailable / not assessed'));
      assert(!result.allText.includes('No priority actions identified'));
      assert(!result.allText.includes('current-node'), 'No sample or partial inventory displayed on inventory failure');
      checks++;
    }
    const heartbeatError = await run(kind, {heartbeatError: true});
    assert(heartbeatError.allText.includes('heartbeat permission denied'));
    assert(!heartbeatError.allText.includes('No heartbeat in the last 48 hours'), 'Failed queries must not create per-machine telemetry findings');
    checks++;
    const perfError = await run(kind, {perfError: true});
    assert(perfError.allText.includes('performance query failed'));
    assert(!perfError.allText.includes('Disk free space below 15%'));
    checks++;
    const graphError = await run(kind, {graphError: true});
    assert(graphError.allText.includes('resource evidence denied'));
    checks++;
    const empty = await run(kind, {emptyTelemetry: true});
    assert(empty.allText.includes('No heartbeat in the last 48 hours'));
    assert(empty.allText.includes('does not prove a missing DCR'));
    checks++;
    const pressure = await run(kind, {pressure: true, extensionFailure: true});
    assert(pressure.allText.includes('Disk free space below 15%: C:'));
    assert(pressure.allText.includes('actual-extension'));
    assert(pressure.allText.includes('4.9% average free'));
    checks++;
    const boundary = await run(kind, {pressure: 15});
    assert(!boundary.allText.includes('Disk free space below 15%'));
    const warningBoundary = await run(kind, {pressure: 5});
    assert(warningBoundary.allText.includes('Disk free space below 15%'));
    const findingContainer = kind === 'arc-priority-lifecycle' ? 's1' : 'priority-list';
    assert(!text(warningBoundary.elements.get(findingContainer)).includes('critical'), 'Exactly 5% free is warning, not critical');
    checks += 2;
    const rebuilt = await run(kind, {inventory: [{...inventory[0], Machine: 'replacement-current-machine'}]});
    assert(rebuilt.allText.includes('replacement-current-machine'), 'A fresh open rebuilds current machine names');
    assert(!rebuilt.allText.includes('current-node'), 'Previously observed machine names are not retained');
    checks++;
    if (kind === 'arc-priority-lifecycle') {
      assert.equal(boundary.headers.length, 5);
      for (const header of boundary.headers) {
        const section = boundary.elements.get(header.dataset.section);
        header.listeners.click();
        assert(section.classes.has('collapsed'));
        header.listeners.keydown({key: 'Enter', preventDefault() {}});
        assert(!section.classes.has('collapsed'));
      }
      checks++;
    }
  }
  const buildFixture = fs.mkdtempSync(path.join(os.tmpdir(), 'arc-report-build-'));
  try {
    const templates = path.join(buildFixture, 'templates', 'arc-operations');
    const reports = path.join(buildFixture, 'reports');
    fs.mkdirSync(templates, {recursive: true});
    fs.mkdirSync(reports);
    fs.copyFileSync(path.join(root, 'templates', 'arc-operations', 'build.js'), path.join(templates, 'build.js'));
    for (const kind of ['arc-fleet-operations', 'arc-priority-lifecycle']) {
      const file = kind + '-cleaned.livereport.json';
      fs.copyFileSync(path.join(root, 'reports', file), path.join(reports, file));
    }
    for (const ending of ['\n', '\r\n']) {
      for (const file of ['arc-fleet-operations.html', 'arc-priority-lifecycle.html', 'report.js']) {
        const source = fs.readFileSync(path.join(root, 'templates', 'arc-operations', file), 'utf8').replace(/\r\n?/g, '\n');
        fs.writeFileSync(path.join(templates, file), source.replace(/\n/g, ending));
      }
      execFileSync(process.execPath, [path.join(templates, 'build.js'), '--check'], {stdio: 'pipe'});
      checks++;
    }
  } finally {
    fs.rmSync(buildFixture, {recursive: true});
  }
  if (process.argv.includes('--queries-out')) {
    const output = process.argv[process.argv.indexOf('--queries-out') + 1];
    fs.writeFileSync(output, JSON.stringify(queries, null, 2));
  }
  console.log('PASS ' + checks + ' Arc report regression scenarios (both dashboards, isolation, response envelopes, failures, empty results, findings, controls)');
})().catch(error => { console.error(error); process.exitCode = 1; });
