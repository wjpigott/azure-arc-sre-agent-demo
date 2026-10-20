(async function () {
  'use strict';
  const SUB = '__SUBSCRIPTION_ID__';
  const RG = '__RESOURCE_GROUP__';
  const WS = '__WORKSPACE__';
  const TOOL = 'system-mcp-monitor_monitor_workspace_log_query';
  const LIMIT = 1000;
  const priority = document.getElementById('s1') !== null;
  const byId = new Map();
  const findings = [];
  const failures = [];
  const now = new Date().toISOString();

  function element(tag, text, className) {
    const node = document.createElement(tag);
    if (text !== undefined && text !== null) node.textContent = String(text);
    if (className) node.className = className;
    return node;
  }
  function target(id) { return document.getElementById(id); }
  function message(id, text, error) {
    const container = target(id);
    container.replaceChildren(element('div', text, error ? 'error err-state' : 'empty empty-state'));
  }
  function table(id, headers, rows, append) {
    const container = target(id);
    if (!append) container.replaceChildren();
    if (!rows.length) {
      container.appendChild(element('div', 'No matching records returned; this is not proof of coverage or compliance.', 'empty empty-state'));
      return;
    }
    const node = element('table');
    const head = element('thead');
    const header = element('tr');
    headers.forEach(value => header.appendChild(element('th', value)));
    head.appendChild(header);
    node.appendChild(head);
    const body = element('tbody');
    rows.forEach(values => {
      const row = element('tr');
      values.forEach(value => row.appendChild(element('td', value == null || value === '' ? 'Unknown' : value)));
      body.appendChild(row);
    });
    node.appendChild(body);
    container.appendChild(node);
  }
  function heading(id, text) { target(id).appendChild(element('h3', text)); }
  function badge(id, text) { target(id).textContent = text; }
  function unwrap(value) {
    for (let depth = 0; depth < 6 && typeof value === 'string'; depth++) {
      try { value = JSON.parse(value); } catch { break; }
    }
    return value;
  }
  function decode(raw, depth = 0) {
    const value = unwrap(raw);
    if (depth > 8 || value == null) return null;
    if (Array.isArray(value)) {
      if (!value.length) return [];
      if (value.every(row => row && typeof row === 'object' && !Array.isArray(row) &&
        !('type' in row && 'text' in row) && !('columns' in row && 'rows' in row) &&
        !('error' in row) && !('isError' in row) && !('tables' in row))) return value;
      for (const item of value) {
        const rows = decode(item, depth + 1);
        if (rows !== null) return rows;
      }
      return null;
    }
    if (typeof value !== 'object') return null;
    if (value.isError || value.error || value.partialError || (value.status !== undefined && String(value.status) !== '200')) {
      throw new Error(String(value.message || (value.error && value.error.message) || value.error || 'Query failed or returned partial results'));
    }
    if (Array.isArray(value.columns) && Array.isArray(value.rows)) {
      const columns = value.columns.map(column => column.name || column.ColumnName || String(column));
      return value.rows.map(row => Array.isArray(row) ? Object.fromEntries(columns.map((column, index) => [column, row[index]])) : row);
    }
    for (const key of ['results', 'structuredContent', 'content', 'text', 'result', 'data', 'tables', 'value', 'rows']) {
      if (key in value) {
        const rows = decode(value[key], depth + 1);
        if (rows !== null) return rows;
      }
    }
    return null;
  }
  async function query(tableName, queryText, hours = 24) {
    const raw = await window.sreagent.callTool(TOOL, {
      subscription: SUB, 'resource-group': RG, workspace: WS,
      table: tableName, query: queryText, hours, limit: LIMIT
    });
    const rows = decode(raw);
    if (rows === null) throw new Error('Unrecognized query response for ' + tableName);
    if (rows.length >= LIMIT) throw new Error('Query reached the 1,000-record limit; narrow the scope before relying on this report.');
    return rows;
  }
  function resourceId(value) { return String(value || '').trim().toLowerCase(); }
  function machine(row) { return byId.get(resourceId(row.ResourceId)); }
  function name(row) { return machine(row).Machine; }
  function scoped(rows) { return rows.filter(row => byId.has(resourceId(row.ResourceId))); }
  function literal(value) { return JSON.stringify(String(value)); }
  async function telemetry(tableName, expression, hours = 24) {
    const ids = [...byId.keys()].map(literal).join(',');
    const prefix = tableName + ' | extend ResourceId=tolower(tostring(column_ifexists("_ResourceId", "")))' +
      ' | where ResourceId in~ (' + ids + ')';
    return scoped(await query(tableName, prefix + ' | ' + expression, hours));
  }
  async function graph(tableName, expression) {
    return scoped(await query(tableName, 'arg("").' + tableName +
      ' | where subscriptionId =~ ' + literal(SUB) + ' | ' + expression));
  }
  async function load(label, action) {
    try { return {rows: await action(), error: null}; }
    catch (error) {
      const text = label + ': ' + error.message;
      failures.push(text);
      return {rows: [], error: text};
    }
  }
  function show(id, result, headers, cells, append) {
    if (result.error) {
      if (!append) target(id).replaceChildren();
      target(id).appendChild(element('div', 'Unavailable / not assessed - ' + result.error, 'error err-state'));
    } else table(id, headers, result.rows.map(cells), append);
  }
  function finding(severity, row, condition, evidence, timestamp, action) {
    findings.push({severity, machine: name(row), condition, evidence, timestamp: timestamp || now, action});
  }

  document.querySelectorAll('[data-section]').forEach(header => {
    const toggle = () => target(header.dataset.section).classList.toggle('collapsed');
    header.tabIndex = 0;
    header.setAttribute('role', 'button');
    header.addEventListener('click', toggle);
    header.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); toggle(); }
    });
  });

  let machines;
  try {
    machines = await query('Resources',
      'arg("").Resources | where type =~ "microsoft.hybridcompute/machines"' +
      ' | where subscriptionId =~ ' + literal(SUB) +
      ' | project ResourceId=tolower(id), Machine=name, ResourceGroup=resourceGroup,' +
      ' Status=tostring(properties.status), OS=tostring(properties.osSku), Agent=tostring(properties.agentVersion)' +
      ' | order by ResourceId asc');
    const prefix = '/subscriptions/' + SUB.toLowerCase() + '/resourcegroups/';
    for (const row of machines) {
      const id = resourceId(row.ResourceId);
      if (!id.startsWith(prefix) || !/^\/subscriptions\/[^/]+\/resourcegroups\/[^/]+\/providers\/microsoft\.hybridcompute\/machines\/[^/]+$/.test(id) || !row.Machine) {
        throw new Error('Current inventory returned an invalid or out-of-scope Arc resource ID.');
      }
      byId.set(id, row);
    }
    machines = [...byId.values()];
    if (!machines.length) throw new Error('No accessible current Arc machines returned for the selected subscription. Verify the scope and Resource Graph read access; no sample inventory is displayed.');
  } catch (error) {
    const ids = priority ? ['s1', 's2', 's3', 's4', 's5'] :
      ['fleet-table', 'agent-table', 'resource-table', 'events-table', 'changes-table', 'syslog-table', 'priority-list'];
    ids.forEach(id => message(id, 'Unavailable / not assessed - ' + error.message, true));
    if (priority) {
      target('hdr-sub').textContent = 'Current infrastructure unavailable - no fallback inventory';
      ['s1-badge', 's2-badge', 's3-badge', 's4-badge', 's5-badge'].forEach(id => badge(id, 'not assessed'));
    } else target('refresh-time').textContent = 'Current infrastructure unavailable - no fallback inventory';
    return;
  }

  const [hb, disk, cpu, memory, events, syslog, changes, extensions, patch, installations, sql] = await Promise.all([
    load('Heartbeat', () => telemetry('Heartbeat', 'summarize arg_max(TimeGenerated, Version) by ResourceId | project ResourceId, LastSeen=TimeGenerated, AMA=Version', 48)),
    load('Disk', () => telemetry('Perf', 'where ObjectName in ("LogicalDisk", "Logical Disk") and CounterName in ("% Free Space", "% Used Space") and InstanceName != "_Total" | extend Free=iff(CounterName == "% Free Space", todouble(CounterValue), 100.0-todouble(CounterValue)) | summarize Free=round(avg(Free),1), LastSeen=max(TimeGenerated) by ResourceId, InstanceName')),
    load('CPU', () => telemetry('Perf', 'where ObjectName in ("Processor", "Processor Information") and CounterName == "% Processor Time" and InstanceName == "_Total" | summarize Average=round(avg(CounterValue),1), Peak=round(max(CounterValue),1), LastSeen=max(TimeGenerated) by ResourceId')),
    load('Memory', () => telemetry('Perf', 'where ObjectName == "Memory" and CounterName in ("Available MBytes", "% Used Memory") | summarize Average=round(avg(CounterValue),1), Minimum=round(min(CounterValue),1), LastSeen=max(TimeGenerated) by ResourceId, CounterName')),
    load('Windows events', () => telemetry('Event', 'where EventLevelName in ("Critical", "Error") | summarize Count=count(), LastSeen=max(TimeGenerated) by ResourceId, Source, EventID, EventLevelName', 48)),
    load('Syslog', () => telemetry('Syslog', 'where SeverityLevel in ("warning", "err", "crit", "alert", "emerg") | summarize Count=count(), LastSeen=max(TimeGenerated) by ResourceId, ProcessName, SeverityLevel', 48)),
    load('Configuration changes', () => telemetry('ConfigurationChange', 'summarize Count=count(), LastSeen=max(TimeGenerated) by ResourceId, ConfigChangeType', 168)),
    load('Extensions', () => graph('Resources', 'where type =~ "microsoft.hybridcompute/machines/extensions" | project ResourceId=tostring(split(tolower(id), "/extensions/")[0]), Extension=name, Status=tostring(properties.provisioningState), Version=tostring(properties.typeHandlerVersion)')),
    load('Patch assessments', () => graph('PatchAssessmentResources', 'where type =~ "microsoft.hybridcompute/machines/patchassessmentresults" | project ResourceId=tostring(split(tolower(id), "/patchassessmentresults/")[0]), Status=tostring(properties.status), AssessedAt=tostring(properties.lastModifiedDateTime), Critical=toint(properties.availablePatchCountByClassification.critical), Security=toint(properties.availablePatchCountByClassification.security), Reboot=tostring(properties.rebootPending)')),
    load('Patch installations', () => graph('PatchInstallationResources', 'where type =~ "microsoft.hybridcompute/machines/patchinstallationresults" | project ResourceId=tostring(split(tolower(id), "/patchinstallationresults/")[0]), Status=tostring(properties.status), LastSeen=tostring(properties.lastModifiedDateTime), Failed=toint(properties.failedPatchCount), Reboot=tostring(properties.rebootStatus)')),
    load('SQL inventory', () => graph('Resources', 'where type =~ "microsoft.azurearcdata/sqlserverinstances" | project ResourceId=tolower(tostring(properties.containerResourceId)), Instance=name, Version=tostring(properties.version), Edition=tostring(properties.edition)'))
  ]);
  const heartbeats = new Map(hb.rows.map(row => [resourceId(row.ResourceId), row]));
  machines.forEach(row => {
    if (row.Status === 'Disconnected') finding('high', row, 'Arc status: Disconnected', 'Current Resource Graph status', now, 'Check connectivity and the Arc agent; planned-offline status has not been assessed.');
    const heartbeat = heartbeats.get(resourceId(row.ResourceId));
    if (!hb.error && !heartbeat) finding('warning', row, 'No heartbeat in the last 48 hours', 'No matching resource ID in Heartbeat', now, 'Verify AMA, DCR associations and ingestion. A missing heartbeat does not prove a missing DCR.');
    else if (heartbeat && Date.now() - new Date(heartbeat.LastSeen).getTime() > 3600000) finding('warning', row, 'Heartbeat older than one hour', 'Heartbeat', heartbeat.LastSeen, 'Check agent health and ingestion delay.');
  });
  disk.rows.filter(row => row.Free != null && Number(row.Free) < 15).forEach(row =>
    finding(Number(row.Free) < 5 ? 'critical' : 'warning', row, 'Disk free space below 15%: ' + row.InstanceName, row.Free + '% average free over 24h', row.LastSeen, 'Review capacity and disk usage.'));
  cpu.rows.filter(row => row.Average != null && Number(row.Average) > 70).forEach(row =>
    finding('warning', row, 'Average CPU exceeds 70%', row.Average + '% average over 24h', row.LastSeen, 'Review workload and capacity.'));
  memory.rows.filter(row => row.Average != null && ((row.CounterName === 'Available MBytes' && Number(row.Average) < 1024) || (row.CounterName === '% Used Memory' && Number(row.Average) > 85))).forEach(row =>
    finding('warning', row, 'Memory pressure', row.CounterName + ': ' + row.Average, row.LastSeen, 'Review memory use and capacity.'));
  extensions.rows.filter(row => row.Status.toLowerCase() === 'failed').forEach(row =>
    finding('high', row, 'Extension provisioning failed: ' + row.Extension, 'Current extension provisioning state', now, 'Inspect extension logs before choosing remediation.'));
  patch.rows.filter(row => row.Status.toLowerCase() === 'failed').forEach(row =>
    finding('warning', row, 'Patch assessment failed', 'Current Update Manager assessment record', row.AssessedAt, 'Review assessment details and machine connectivity.'));
  installations.rows.filter(row => /failed/i.test(row.Status) || Number(row.Failed) > 0).forEach(row =>
    finding('high', row, 'Patch installation reports failures', row.Status + '; failed patches: ' + (row.Failed == null ? 'Unknown' : row.Failed), row.LastSeen, 'Review the specific Update Manager run; no fleet-wide failure is inferred.'));
  events.rows.forEach(row => finding(row.EventLevelName === 'Critical' ? 'high' : 'warning', row, 'Windows ' + row.EventLevelName + ' events', row.Source + ' / ' + row.EventID + ': ' + row.Count, row.LastSeen, 'Inspect the source events to establish the cause.'));
  syslog.rows.forEach(row => finding('warning', row, 'High-severity syslog', row.ProcessName + ' / ' + row.SeverityLevel + ': ' + row.Count, row.LastSeen, 'Inspect syslog to establish the cause.'));
  const rank = {critical: 0, high: 1, warning: 2};
  findings.sort((a, b) => rank[a.severity] - rank[b.severity]);
  const inventoryRows = machines.map(row => {
    const heartbeat = heartbeats.get(resourceId(row.ResourceId));
    return [row.Machine, row.ResourceGroup, row.OS, row.Agent, row.Status,
      hb.error ? 'Unavailable' : heartbeat ? heartbeat.AMA : 'Not observed',
      hb.error ? 'Unavailable' : heartbeat ? heartbeat.LastSeen : 'Not observed (48h)'];
  });
  const sourceNote = 'Current accessible Arc resources in subscription ' + SUB + ' | Queried ' + now +
    ' | No embedded inventory | Planned-offline exceptions and lifecycle currency not assessed';
  const coverageNote = 'Missing rows do not prove compliance. Telemetry is limited to the selected workspace and exact current Arc resource IDs; records without a matching resource ID are excluded.';
  const versionNote = 'Agent and OS versions are observed inventory, not a support verdict. Verify current vendor lifecycle references before declaring a version current, unsupported or ESU-covered.';
  const performance = [
    ['Disk free space (24h)', disk, ['Machine', 'Volume', 'Average free %', 'Last seen'], row => [name(row), row.InstanceName, row.Free, row.LastSeen]],
    ['CPU (24h)', cpu, ['Machine', 'Average %', 'Peak %', 'Last seen'], row => [name(row), row.Average, row.Peak, row.LastSeen]],
    ['Memory (24h)', memory, ['Machine', 'Counter', 'Average', 'Minimum', 'Last seen'], row => [name(row), row.CounterName, row.Average, row.Minimum, row.LastSeen]]
  ];
  const reliability = [
    ['Windows events (48h)', events, ['Machine', 'Source', 'Event ID', 'Level', 'Count', 'Last seen'], row => [name(row), row.Source, row.EventID, row.EventLevelName, row.Count, row.LastSeen]],
    ['Syslog (48h)', syslog, ['Machine', 'Process', 'Severity', 'Count', 'Last seen'], row => [name(row), row.ProcessName, row.SeverityLevel, row.Count, row.LastSeen]],
    ['Configuration changes (7d)', changes, ['Machine', 'Type', 'Count', 'Last seen'], row => [name(row), row.ConfigChangeType, row.Count, row.LastSeen]]
  ];
  function sections(id, items) {
    target(id).replaceChildren();
    items.forEach(([title, result, headers, cells]) => { heading(id, title); show(id, result, headers, cells, true); });
  }
  const findingsRows = findings.map(row => [row.severity, row.machine, row.condition, row.evidence, row.timestamp, 'Not established by this report', row.action]);
  function notices(id) {
    target(id).appendChild(element('div', coverageNote, 'note'));
    failures.forEach(text => target(id).appendChild(element('div', 'Unavailable / not assessed - ' + text, 'error err-state')));
  }

  if (priority) {
    target('hdr-sub').textContent = sourceNote + (failures.length ? ' | WARNING: some queries unavailable' : '');
    table('s1', ['Severity', 'Machine', 'Condition', 'Evidence', 'Timestamp', 'Likely cause', 'Next action'], findingsRows);
    notices('s1');
    badge('s1-badge', findings.length + ' observed findings' + (failures.length ? ' / incomplete' : ''));
    sections('s2', [
      ['Update Manager assessments', patch, ['Machine', 'Status', 'Critical', 'Security', 'Reboot pending', 'Assessed at'], row => [name(row), row.Status, row.Critical, row.Security, row.Reboot, row.AssessedAt]],
      ['Update Manager installation runs', installations, ['Machine', 'Status', 'Failed patches', 'Reboot', 'Last seen'], row => [name(row), row.Status, row.Failed, row.Reboot, row.LastSeen]]
    ]);
    target('s2').appendChild(element('div', 'Maintenance schedules, assessment freshness and reboot debt are not independently assessed. Review current Update Manager evidence before scheduling changes.', 'note'));
    badge('s2-badge', patch.error || installations.error ? 'incomplete / not assessed' : 'observed records only');
    table('s3', ['Machine', 'Resource group', 'OS', 'Arc agent', 'Arc status', 'AMA', 'Last heartbeat'], inventoryRows);
    heading('s3', 'Extensions');
    show('s3', extensions, ['Machine', 'Extension', 'State', 'Version'], row => [name(row), row.Extension, row.Status, row.Version], true);
    heading('s3', 'SQL inventory');
    show('s3', sql, ['Machine', 'Instance', 'Version', 'Edition'], row => [name(row), row.Instance, row.Version, row.Edition], true);
    target('s3').appendChild(element('div', versionNote, 'note'));
    badge('s3-badge', 'currency not assessed');
    sections('s4', performance);
    badge('s4-badge', [disk, cpu, memory].some(result => result.error) ? 'incomplete' : 'observed records only');
    sections('s5', reliability);
    notices('s5');
    badge('s5-badge', failures.length ? 'incomplete' : 'observed records only');
    const cards = [
      [machines.length, 'Current Arc machines', 'blue'],
      [machines.filter(row => row.Status === 'Connected').length, 'Arc connected', 'green'],
      ['Not assessed', 'Planned offline', 'gray'],
      ...['critical', 'high', 'warning'].map(severity => [findings.filter(row => row.severity === severity).length, severity + ' observed', 'amber'])
    ];
    cards.forEach(([value, label, color]) => {
      const card = element('div', null, 'stat-card ' + color);
      card.appendChild(element('div', value, 'val'));
      card.appendChild(element('div', label, 'lbl'));
      target('summary-bar').appendChild(card);
    });
    target('footer').textContent = 'Read-only | Current Resource Graph queries and scoped Log Analytics | No snapshot fallback';
  } else {
    target('refresh-time').textContent = 'Queried ' + now + (failures.length ? ' | WARNING: incomplete data' : '');
    table('fleet-table', ['Machine', 'Resource group', 'OS', 'Arc agent', 'Arc status', 'AMA', 'Last heartbeat'], inventoryRows);
    target('fleet-table').appendChild(element('div', sourceNote, 'note'));
    if (hb.error) target('fleet-table').appendChild(element('div', hb.error, 'error'));
    badge('c-connected', machines.filter(row => row.Status === 'Connected').length);
    badge('c-connected-d', 'of ' + machines.length + ' current accessible Arc resources');
    badge('c-disconnected', machines.filter(row => row.Status === 'Disconnected').length);
    badge('c-disconnected-d', 'Planned-offline status not assessed');
    badge('c-stale', hb.error ? 'Unavailable' : hb.rows.filter(row => Date.now() - new Date(row.LastSeen).getTime() > 3600000).length);
    badge('c-stale-d', 'Heartbeat older than one hour');
    badge('c-telem', hb.error ? 'Unavailable' : machines.length - heartbeats.size);
    badge('c-telem-d', 'No matching heartbeat (48h); cause not established');
    badge('c-p1', findings.filter(row => row.severity === 'critical').length);
    const versions = new Map();
    machines.forEach(row => { const version = row.Agent || 'Unknown'; versions.set(version, (versions.get(version) || 0) + 1); });
    table('agent-table', ['Observed Arc agent', 'Count', 'Currency'], [...versions].map(([version, count]) => [version, count, 'Not assessed']));
    target('agent-table').appendChild(element('div', versionNote, 'note'));
    if (typeof Chart === 'function') {
      new Chart(target('agent-chart').getContext('2d'), {
        type: 'doughnut',
        data: {labels: [...versions.keys()], datasets: [{data: [...versions.values()], backgroundColor: ['#0078d4', '#107c10', '#ca5010', '#8764b8']}]},
        options: {responsive: true}
      });
    } else target('agent-table').appendChild(element('div', 'Version chart unavailable; the inventory table remains available.', 'note'));
    sections('resource-table', performance);
    show('events-table', events, reliability[0][2], reliability[0][3]);
    show('syslog-table', syslog, reliability[1][2], reliability[1][3]);
    show('changes-table', changes, reliability[2][2], reliability[2][3]);
    table('priority-list', ['Severity', 'Machine', 'Condition', 'Evidence', 'Timestamp', 'Likely cause', 'Next action'], findingsRows);
    notices('priority-list');
  }
})().catch(error => {
  const node = document.createElement('div');
  node.className = 'error err-state';
  node.textContent = 'Report rendering failed - ' + error.message + '. Do not treat partial output as a complete assessment.';
  document.body.prepend(node);
});
