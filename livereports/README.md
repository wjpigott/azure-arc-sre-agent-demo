# Azure SRE Agent Live Reports - deployment guide

This folder holds the current Live Report definitions for the
[Azure Arc SRE Agent Demo](../README.md). Each one is a
portable `*.livereport.json` bundle. The bundles contain no environment-specific data:
- Subscription, workspace and resource group are `__PLACEHOLDER__`s that you fill in at install time.
- There is no embedded machine inventory or demo fallback. Fleet and priority
  reports query current Azure resources on every open; the tracker queries live software inventory.

A bundle carries the report's saved source (HTML, CSS, JS, CSP) byte-for-byte, so the layout after install
is the same as the original. It is **not** the portal's "Download HTML" file, which is a static snapshot
that cannot be installed.

## Repository contents

| Path | Purpose |
|---|---|
| `reports/*.livereport.json` | Installable report bundles (see the table below). |
| `live_report_bundle.py` | Install, verify and export tool. Python 3.8+, standard library only. |
| `livereport-bundle.schema.json` | JSON Schema of the bundle format (`sreagent.livereport/v1`). |
| `templates/third-party-software-tracker/` | Editable source of the tracker, with KQL queries and offline tests. |
| `templates/arc-operations/` | Editable fleet/priority layouts, shared live-query logic, bundle builder and regression tests. |
| [`../.github/workflows/validate-live-reports.yml`](../.github/workflows/validate-live-reports.yml) | Repository CI. Verifies bundles, blocks real IDs or GUIDs, checks generated source, and runs the template tests. |

| Bundle | Report |
|---|---|
| `arc-fleet-operations-cleaned` | Fleet inventory, telemetry coverage, resource pressure, failures, agent versions and priority actions. |
| `arc-priority-lifecycle-cleaned` | Priority action queue, patch and maintenance readiness, lifecycle, performance and reliability. |
| `third-party-software-update-tracker-cleaned` | Third-party app versions compared with vendor latest. No built-in data. Recommended for new environments. |

## Prerequisites

1. **An Azure SRE Agent.** You need the **SRE Agent Administrator** or **Standard User** role on it.
2. **A Log Analytics workspace** that receives data from your machines:
   - Heartbeat, Perf and Event for the fleet and priority reports.
   - `ConfigurationData` from Change Tracking & Inventory for the tracker.
   - For a new tenant/workspace, complete the
     [first-time inventory setup](../docs/third-party-software-inventory.md#first-time-setup-in-a-new-workspace).
     The telemetry DCR script does not install AMA or enable Change Tracking.
     Use the Arc telemetry workspace, not automatically the workspace created
     for the SRE Agent's Application Insights.
3. **Access for the agent.** Its managed identity needs **Log Analytics Reader** (or Reader) on the
   workspace or its resource group. Fleet/priority reports also require **Reader**
   on the intended Arc resources for Azure Resource Graph inventory queries.
4. **The query tool.** The agent must have the built-in tool `system-mcp-monitor_monitor_workspace_log_query`.
   Every report is read-only and calls only this tool.
5. **These values from your environment:**

| Value | Where to find it | `--set` name |
|---|---|---|
| Subscription ID | Workspace > Overview > Subscription ID | `subscription` |
| Workspace ID (customer ID GUID) | Workspace > Overview > Workspace ID | `workspace` |
| Resource group of the workspace | Workspace > Overview > Resource group | `resourceGroup` |

To list the values a bundle needs, run `python3 live_report_bundle.py bindings reports/<file>.livereport.json`.

## Install - Option A: in chat (simplest)

1. Open your SRE Agent and start a new chat.
2. Attach **`live_report_bundle.py`** and the **`reports/<name>.livereport.json`** bundle(s) you want.
3. Send this message, filling in your values:

   > Run `python3 live_report_bundle.py prepare <bundle-file> --drop-suffix " - Cleaned"
   > --set subscription=<SUBSCRIPTION_ID> --set workspace=<WORKSPACE_ID> --set resourceGroup=<RESOURCE_GROUP>
   > --out-dir tmp/livereport-install`.
   > If it reports FAIL, stop and show me the output. Otherwise, for each entry in
   > tmp/livereport-install/install-plan.json call SaveReport with htmlPath, name, description and allowedTools
   > exactly as listed. Do not edit or regenerate the HTML.

4. Approve the one-time **tool-access** prompt for each report.
5. Open the report from **Live Reports**.

Tips:
- Add `--name-prefix "Test - "` for a trial install. Leave out `--drop-suffix` if you want to keep " - Cleaned" in the names.
- `prepare` refuses to continue while any `__PLACEHOLDER__` is unset, so a report can't be installed half-configured.

## Install - Option B: scripted, from your workstation

Use this when the repository is connected to the target agent as a code repository, so the agent sees it
under `codeRefs/<repo>/`. You need the Azure CLI and `az login`.
Run local commands in this guide from `livereports/`. For this parent repository,
the agent-side paths include `livereports/` as shown below.

**First agent setup:** connect the repository through **Code > Connect
repositories** or **Builder > Code Access > GitHub** and confirm the exact
`codeRefs` path. Signing into GitHub in VS Code does not connect the SRE Agent.
PAT was the usable option in the tested VS Code integrated-browser deployment;
OAuth and GitHub App availability depend on the supported connection and
environment. See the [GitHub/PAT setup guide](../docs/deploy-azure-sre-agent.md#connect-this-repository-to-the-agent).
Keep tokens out of chat, files, and commands. Options A and C do not require a
repository connection.

```bash
python3 live_report_bundle.py install \
  --agent-id /subscriptions/<agent-sub>/resourceGroups/<agent-rg>/providers/Microsoft.App/agents/<agent-name> \
  --repo-path codeRefs/<repo>/livereports/reports \
  --script-path codeRefs/<repo>/livereports/live_report_bundle.py \
  --bundle third-party-software-update-tracker-cleaned.livereport.json \
  --set subscription=<SUBSCRIPTION_ID> --set workspace=<WORKSPACE_ID> --set resourceGroup=<RESOURCE_GROUP> \
  --drop-suffix " - Cleaned"
```

- Repeat `--bundle` to install several reports in one go.
- Add `--dry-run` first to see the exact API calls and the message sent to the agent, without making any calls.
- The command calls the documented SRE Agent data-plane API: it starts a thread, polls it, and lists pending
  approvals. Token audience is `https://azuresre.dev`.
- Tool-access approvals are **not** automated. Approve them in the portal on the thread the script prints.

## Install - Option C: prepare locally, then attach the HTML

```bash
python3 live_report_bundle.py prepare reports/<name>.livereport.json --drop-suffix " - Cleaned" \
  --set subscription=<SUBSCRIPTION_ID> --set workspace=<WORKSPACE_ID> --set resourceGroup=<RESOURCE_GROUP> \
  --out-dir out/
```

Attach `out/<name>.html` in chat and ask the agent to save it as a Live Report. Use the name, description and
allowedTools from `out/install-plan.json`, and tell it not to modify the HTML.
**The prepared HTML contains your IDs, so do not commit `out/`.**

## Updating a report that is already installed

Pass the existing report ID, so a new **version** is saved instead of a second report:
- In chat: ask the agent to "list my live reports", then add `--report-id <id>` to the `prepare` command
  (one bundle at a time).
- Scripted: add `--report-id <id>` to `install`.

### Replace an older report that displays unfamiliar demo machines

Older fleet and priority bundles contained pseudonymized sample names such as
`WIN-SRV-07`, plus saved patch, extension, SQL and maintenance findings. Those
names were embedded demo data, not evidence of access to another network.
The former optional tracker demo-snapshot bundle has also been removed.

**Updating this repository does not update an installed report.** Reloading an
old version still executes its old saved HTML. For each affected installed report:

1. Connect or refresh the repository in the target agent so it can read the
   updated bundles, or attach the current bundle and deployment tool.
2. List reports and confirm the existing report ID, destination subscription,
   and telemetry workspace. Use the fleet/priority bundle matching that report;
   replace a demo-snapshot tracker with `third-party-software-update-tracker-cleaned`.
3. Prepare one report at a time, preserving its existing ID. For example, from
   the repository root in PowerShell:

   ```powershell
   py -3 .\livereports\live_report_bundle.py prepare `
     .\livereports\reports\arc-priority-lifecycle-cleaned.livereport.json `
     --set "subscription=<subscription-id>" `
     --set "workspace=<workspace-customer-id>" `
     --set "resourceGroup=<workspace-resource-group>" `
     --report-id "<existing-report-id>" --drop-suffix " - Cleaned" `
     --out-dir .\Temp\livereport-install
   ```

4. Ask the target agent to call **SaveReport** with the HTML, existing report ID
   and other fields from the generated install plan, without regenerating the
   HTML or inserting example machines. Approve tool access if requested.
5. Open the newly saved **current version**, reload, and compare its machine
   names and count with accessible Arc resources in the selected subscription.
   Check a query-failure case: it must show unavailable/not assessed, never a
   demo fleet. If Resource Graph returns no accessible inventory, verify scope
   and permissions rather than filling in guessed names.

## After installing - check it works

- The report opens without a red error box.
- **Tracker:** the header shows **Data: LIVE**. *Data: UNAVAILABLE* means the query
  failed or inventory is unavailable; no demo snapshot should be displayed.
- **Fleet and priority reports:** names and machine counts match current accessible
  Arc resources in the bound subscription. The workspace/resource-group bindings
  select telemetry, not an Arc resource-group filter. Verify that this
  subscription-wide inventory scope is intended.
- Check timestamps and test section expand/collapse controls, not just whether
  the report opens. A successful save, bundle checksum, or extension deployment
  is not proof of live data or working browser interactions.
- If initial inventory is pending, record **deployed, data validation pending**.
  It is valid to save the three reports first and validate later, but empty
  results must not be reported as proof of compliance or no installed software.

## Current infrastructure rebuilds and coverage limits

Fleet and priority reports use the existing read-only Log Analytics query tool
with [Azure Resource Graph cross-service queries](https://learn.microsoft.com/azure/azure-monitor/logs/azure-monitor-data-explorer-proxy#query-data-in-azure-resource-graph-by-using-arg-preview):

- On each open/reload, `arg("").Resources` discovers currently accessible
  `Microsoft.HybridCompute/machines` in the bound subscription. There is no
  saved fleet manifest, planned-offline list, standing demo action or fallback.
- All Heartbeat, Perf, Event, Syslog and ConfigurationChange queries are filtered
  to those exact current ARM resource IDs. Hostname-only matching is not used:
  duplicate short names, FQDNs, unrelated workspace hosts and deleted resources
  cannot add machines to the report.
- Extensions, SQL inventory, patch assessments and patch installation runs are
  queried from current Resource Graph records and matched back to the same
  resource IDs. Unavailable queries are labeled explicitly; empty records do
  not establish coverage or compliance.
- Arc connection state comes from current resource properties, not AMA
  heartbeat age. Missing heartbeats do not establish a missing DCR.
- Planned-offline exceptions, maintenance schedules, assessment freshness,
  lifecycle support, ESU entitlement and reboot debt are **not assessed**.
  Observed version strings are not labeled current/unsupported using an old
  hardcoded vendor reference. Review these separately against approved policy.
- Resource Graph returns only resources the identity can read, may lag ARM
  changes, and can obscure cross-service errors. An empty inventory is shown
  as unavailable/not assessed. A query reaching 1,000 records is rejected
  rather than presenting a truncated fleet as complete. Use a narrower
  deployment scope or extend pagination before operational use at that size.
- All telemetry is limited to the selected workspace. Records lacking a
  matching `_ResourceId` are excluded, even if their computer name matches.

The tracker also has no fallback inventory; it still requires live Change
Tracking data and review of its dated vendor reference.

### Editing and rebuilding the fleet/priority bundles

Edit `templates/arc-operations/arc-fleet-operations.html`,
`arc-priority-lifecycle.html` and the shared `report.js`, then run from
`livereports/`:

```powershell
node .\templates\arc-operations\build.js
node .\templates\arc-operations\build.js --check
node .\templates\arc-operations\tests\run-tests.js
python .\live_report_bundle.py verify "reports/*.livereport.json"
```

The builder normalizes source line endings to LF, embeds the script in the nonce-bearing HTML and refreshes bundle
checksums, byte counts, binding occurrences and descriptions. CI checks source
parity and regression scenarios for response envelopes, scope isolation, empty
and failed queries, priority thresholds and section controls. Installation and
runtime validation in the destination agent remain separate steps.

## Verify bundles before installing or merging

```bash
python3 live_report_bundle.py verify "reports/*.livereport.json"     # checksum, CSP nonce, allowed tools, SRI
python3 live_report_bundle.py bindings "reports/*.livereport.json"   # values to --set at install
```

`verify` fails if the HTML was changed after export (checksum mismatch), if it looks like a downloaded or
rendered copy (no `{REPORT_NONCE}`), or if it calls a tool that isn't in its allowedTools.

## Adding your own reports to this repo

Do these steps inside your SRE Agent workspace.

1. Ask the agent to check out each report: "Run ListReports and GetReport for my reports, and write their
   metadata to reports-meta.json".
2. Export them:
   ```bash
   python3 live_report_bundle.py export --meta reports-meta.json --out bundles/
   ```
   Bundles in `bundles/` contain real values. They are git-ignored, so never commit them.
3. Write a local redaction map, `redaction-map.local.txt` (also git-ignored), with one `original => replacement`
   line per value to hide. Include machine names, other resource groups, domains, and names that appear in text.
4. Clean the bundles:
   ```bash
   python3 live_report_bundle.py clean "bundles/*.livereport.json" --map redaction-map.local.txt --out reports/
   ```
   `clean` turns the bound values into `__PLACEHOLDER__`s and replaces the mapped values with pseudonyms.
   It fails if any original value survives or if the report's JavaScript no longer parses. Report names get " - Cleaned".
5. Review the diff, run `verify`, and open a pull request. CI runs the same checks.

Sanitizing identifiers is not enough to make a report operationally portable:
pseudonymized machines are still sample data. Do not publish embedded
environment snapshots or fallback fleets. Replace them with scoped live queries
and explicit unavailable states, as in the current fleet/priority source.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `FAIL ... required values not set` | Add the missing `--set name=value`. Run `bindings` to see which values the bundle needs. |
| `htmlSha256 mismatch` | The bundle was edited by hand. Re-export it, or restore it from git. |
| `No {REPORT_NONCE} placeholder found` | You exported a downloaded or rendered copy. Export from GetReport's `htmlPath` instead. |
| Report shows "Query error" or "Failed to load" | Check the workspace ID and the agent's Log Analytics Reader role, and run the query in Log Analytics. |
| Tracker shows few machines | Run `templates/third-party-software-tracker/queries/inventory-coverage.kql` and check the Change Tracking DCR and AMA. |
| Repository path is missing under `codeRefs` | Connect the repository inside the SRE Agent, not just VS Code; verify authentication, repository selection, and clone/index readiness. |
| OAuth cannot complete in VS Code's integrated browser | Try the external browser or the supported PAT connection option. Follow the agent setup guide; never paste the token into chat. |
| Fresh workspace has no `ConfigurationData` | Complete Change Tracking solution/table, extension and DCR setup, then allow for the configured collection interval. |
| Report shows unfamiliar demo machine names | Replace the installed report's current version using the updated no-fallback bundle; reloading old HTML does not remove embedded data. |
| Fleet reports missing DCRs despite fresh telemetry | Upgrade the old report and inspect actual DCR associations; current bundles do not infer missing DCRs from heartbeat alone. |
| Priority sections do not expand/collapse | Upgrade to the current bundle with nonce-safe click/keyboard listeners, then verify the current saved version. |
| `install` returns 401 | The token must have audience `https://azuresre.dev`, and you need thread-write access on the agent. |
| Everything in the tracker is "outdated" | The reference versions are stale. See the template README for how to update them. |
