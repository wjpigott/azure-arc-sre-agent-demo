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
   - For a new tenant/workspace, complete the
     [first-time inventory setup](../docs/third-party-software-inventory.md#first-time-setup-in-a-new-workspace).
     The telemetry DCR script does not install AMA or enable Change Tracking.
     Use the Arc telemetry workspace, not automatically the workspace created
     for the SRE Agent's Application Insights.
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

## After installing - check it works

- The report opens without a red error box.
- **Trackers:** the header shows **Data: LIVE**. *Data: SNAPSHOT* means the live query failed and the demo
  snapshot is showing. *Data: UNAVAILABLE* means the query failed and the report has no snapshot. The
  banner gives the reason in both cases.
- **Fleet and priority reports:** the machine counts match your environment. See "Customizing the demo
  data" below.
- Check timestamps and test section expand/collapse controls, not just whether
  the report opens. A successful save, bundle checksum, or extension deployment
  is not proof of live data or working browser interactions.
- If initial inventory is pending, record **deployed, data validation pending**.
  It is valid to save the three reports first and validate later, but empty
  results must not be reported as proof of compliance or no installed software.

## Customizing the demo data

The fleet and priority reports combine live Log Analytics queries with a built-in machine list. In the
cleaned bundles that list holds pseudonymized demo machines (`WIN-SRV-NN`, `LNX-SRV-NN`). Until you replace
it with your own machines, they will show as missing or offline.

| Report | Built-in constants to edit |
|---|---|
| Fleet Operations | `FLEET` (name, os, agent, rg), `PLANNED_OFFLINE`, static card text, and standing demonstration priority actions |
| Priority & Lifecycle | `MACHINES`, `FAILED_EXTS`, `SQL_INSTANCES`, `PATCH_ASSESS`, `MAINT`, `PLANNED_OFFLINE`, `ARG_TS` (snapshot date), visible source timestamps, maintenance/reboot narrative, and the dated agent reference |
| Tracker (Demo Snapshot) | `SNAPSHOT`, `SNAP_T` and `SNAPSHOT_TAKEN` (fallback only; can be emptied) |

Customize before operational use. Ask the agent:
> Prepare the fleet and priority reports for only my approved Arc scope. Query
> current resource evidence and replace the constants listed above. Remove
> standing demo priority actions and old maintenance/reboot narrative; replace
> them only with verified destination evidence. If patch, maintenance or SQL
> evidence is unavailable, say unknown/not assessed, not compliant. Update
> visible timestamps and planned-offline card text. Preserve layout, nonce,
> tool-response decoding and FQDN matching. Use nonce-safe listeners for section
> controls. Re-export and verify any modified bundle before preparing it. If
> updating an installed report, save a new version of its existing report ID.

The tracker without built-in data (`third-party-software-update-tracker-cleaned`) needs no
fleet-snapshot customization; it still needs environment bindings, live inventory,
and review of its dated vendor reference.

## Known fleet and priority bundle limitations

The current published bundles are portable **demo definitions**, not a fully
automated clean-tenant bootstrap. Binding subscription/workspace/resource group
does not replace all embedded evidence.

- **Fleet:** standing actions include old machine-specific lifecycle findings,
  patch-coverage counts, and a fixed missing-DCR count. Remove or rebuild these
  for the destination. The dynamic phrase "no AMA heartbeat - missing DCR"
  also overstates the evidence: missing heartbeat alone cannot establish the
  cause. Verify extensions, DCR associations, destination, and ingestion before
  claiming a missing DCR.
- **Priority:** old maintenance failures and reboot-status narrative remain
  outside the snapshot constants. Replace them as well; clearing `MAINT` or
  `PATCH_ASSESS` alone is insufficient.
- **Priority controls:** five inline `onclick` section handlers conflict with
  the report's nonce CSP. Replace them with `data-*` attributes and
  `addEventListener` calls inside the existing nonce-bearing script; do not
  weaken CSP or remove `{REPORT_NONCE}`. Verify the controls after saving.
- The bundles already include tool-response envelope decoding and normalized
  short-host/FQDN matching. Preserve these when customizing.

These limitations were corrected in private, destination-specific copies
during deployment. Those copies contain environment data and are not the
public bundles. The documentation does not imply the public HTML is fixed.
Current CI verifies integrity, placeholders and tracker logic; it does not
prove fleet/priority narrative correctness or browser interaction behavior.

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
| Repository path is missing under `codeRefs` | Connect the repository inside the SRE Agent, not just VS Code; verify authentication, repository selection, and clone/index readiness. |
| OAuth cannot complete in VS Code's integrated browser | Try the external browser or the supported PAT connection option. Follow the agent setup guide; never paste the token into chat. |
| Fresh workspace has no `ConfigurationData` | Complete Change Tracking solution/table, extension and DCR setup, then allow for the configured collection interval. |
| Fleet reports missing DCRs despite fresh telemetry | Check demo standing actions and actual DCR associations; missing heartbeat is not proof of missing DCR. |
| Priority sections do not expand/collapse | Replace CSP-blocked inline handlers with nonce-safe event listeners and re-export the source. |
| `install` returns 401 | The token must have audience `https://azuresre.dev`, and you need thread-write access on the agent. |
| Everything in the tracker is "outdated" | The reference versions are stale. See the template README for how to update them. |
