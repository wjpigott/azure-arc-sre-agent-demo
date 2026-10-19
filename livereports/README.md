# Azure SRE Agent Live Reports - deployment guide

This folder holds the current Live Report definitions for the
[Azure Arc SRE Agent Demo](../README.md). Each one is a
portable `*.livereport.json` bundle. The bundles contain no environment-specific data:
- Subscription, workspace and resource group are `__PLACEHOLDER__`s that you fill in at install time.
- Machine names in the built-in demo data are pseudonyms such as `WIN-SRV-01`.

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
| [`../.github/workflows/validate-live-reports.yml`](../.github/workflows/validate-live-reports.yml) | Repository CI. Verifies bundles, blocks real IDs or GUIDs, and runs the template tests. |

| Bundle | Report |
|---|---|
| `arc-fleet-operations-cleaned` | Fleet inventory, telemetry coverage, resource pressure, failures, agent versions and priority actions. |
| `arc-priority-lifecycle-cleaned` | Priority action queue, patch and maintenance readiness, lifecycle, performance and reliability. |
| `third-party-software-update-tracker-cleaned` | Third-party app versions compared with vendor latest. No built-in data. Recommended for new environments. |
| `third-party-software-update-tracker-demo-snapshot-cleaned` | The same tracker with a pseudonymized demo snapshot, shown only if the live query fails. |

## Prerequisites

1. **An Azure SRE Agent.** You need the **SRE Agent Administrator** or **Standard User** role on it.
2. **A Log Analytics workspace** that receives data from your machines:
   - Heartbeat, Perf and Event for the fleet and priority reports.
   - `ConfigurationData` from Change Tracking & Inventory for the tracker.
3. **Access for the agent.** Its managed identity needs **Log Analytics Reader** (or Reader) on the
   workspace or its resource group.
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

## After installing - check it works

- The report opens without a red error box.
- **Trackers:** the header shows **Data: LIVE**. *Data: SNAPSHOT* means the live query failed and the demo
  snapshot is showing. *Data: UNAVAILABLE* means the query failed and the report has no snapshot. The
  banner gives the reason in both cases.
- **Fleet and priority reports:** the machine counts match your environment. See "Customizing the demo
  data" below.

## Customizing the demo data

The fleet and priority reports combine live Log Analytics queries with a built-in machine list. In the
cleaned bundles that list holds pseudonymized demo machines (`WIN-SRV-NN`, `LNX-SRV-NN`). Until you replace
it with your own machines, they will show as missing or offline.

| Report | Built-in constants to edit |
|---|---|
| Fleet Operations | `FLEET` (name, os, agent, rg) and `PLANNED_OFFLINE` |
| Priority & Lifecycle | `MACHINES`, `FAILED_EXTS`, `SQL_INSTANCES`, `PATCH_ASSESS`, `MAINT`, `PLANNED_OFFLINE` and `ARG_TS` (snapshot date) |
| Tracker (Demo Snapshot) | `SNAPSHOT`, `SNAP_T` and `SNAPSHOT_TAKEN` (fallback only; can be emptied) |

The easiest way to customize is to install the report first, then ask your agent:
> Open the Live Report "<name>". Replace the FLEET and PLANNED_OFFLINE constants with my Arc machines from Azure
> Resource Graph, and save a new version. Don't change anything else.

The tracker without built-in data (`third-party-software-update-tracker-cleaned`) needs no
customization.

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

## Troubleshooting

| Symptom | Fix |
|---|---|
| `FAIL ... required values not set` | Add the missing `--set name=value`. Run `bindings` to see which values the bundle needs. |
| `htmlSha256 mismatch` | The bundle was edited by hand. Re-export it, or restore it from git. |
| `No {REPORT_NONCE} placeholder found` | You exported a downloaded or rendered copy. Export from GetReport's `htmlPath` instead. |
| Report shows "Query error" or "Failed to load" | Check the workspace ID and the agent's Log Analytics Reader role, and run the query in Log Analytics. |
| Tracker shows few machines | Run `templates/third-party-software-tracker/queries/inventory-coverage.kql` and check the Change Tracking DCR and AMA. |
| `install` returns 401 | The token must have audience `https://azuresre.dev`, and you need thread-write access on the agent. |
| Everything in the tracker is "outdated" | The reference versions are stale. See the template README for how to update them. |
