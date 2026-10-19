# Third-Party Software Inventory

## What is available now

When enabled, Azure Change Tracking and Inventory writes installed-software
inventory into the `ConfigurationData` table in `<log-analytics-workspace>`.
The original lab already had this collection; a new tenant or workspace may
not. Azure SRE Agent can query that connected workspace and create
evidence-cited inventory, compliance, and lifecycle reports.

The inventory includes system-level software on Windows and installed packages on Linux. User-level software appears only while that user is signed in.

## First-time setup in a new workspace

Use one explicitly approved, connected Arc pilot before expanding collection.
Resource creation, extension installation, and Log Analytics ingestion can
incur charges; agree the scope and retention first.

1. **Choose the Arc telemetry workspace.** Record its name, resource group,
   ARM resource ID, and customer ID GUID. Do not select the SRE Agent's
   infrastructure/Application Insights workspace just because the wizard
   created it.
2. **Install and verify AMA** on the pilot, with the appropriate operational
   telemetry DCR associated to that machine and directed to the selected
   workspace. Verify Heartbeat/Perf ingestion independently of extension state.
3. **Enable Change Tracking & Inventory** on the Arc machine through its
   **Operations > Change tracking** experience, following the current
   [Microsoft quickstart](https://learn.microsoft.com/azure/azure-change-tracking-inventory/quickstart-monitor-changes-collect-inventory-azure-change-tracking-inventory).
   Select or verify the intended workspace and Change Tracking DCR. For a
   custom DCR, follow the
   [DCR creation guide](https://learn.microsoft.com/azure/azure-change-tracking-inventory/create-data-collection-rule).
4. **Check workspace prerequisites.** A fresh workspace needs the
   **ChangeTracking solution** and the built-in tables used by the selected
   DCR, including `ConfigurationData` and, when collecting changes,
   `ConfigurationChange`. Portal onboarding provisions the service
   prerequisites; custom ARM/CLI deployment must account for them explicitly.
5. **Verify the complete collection chain:** the OS-specific
   `ChangeTracking-Windows` or `ChangeTracking-Linux` extension, a Change
   Tracking DCR with software/inventory enabled, an association on the pilot,
   and the correct Log Analytics destination. Associate only one Change
   Tracking DCR per machine. Operational telemetry and Change Tracking use
   separate rules; an operational DCR alone does not collect software inventory.
6. **Limit collection to the requirement.** Enable software/inventory for the
   tracker. File contents, registry tracking, and service changes are separate
   collection choices, not prerequisites for a software-only report.
7. **Connect the agent to the workspace** and grant its managed identity
   scoped Log Analytics Reader access. Verify availability of
   `system-mcp-monitor_monitor_workspace_log_query` before saving reports.

### New-workspace errors

| Error or symptom | Check or action |
| --- | --- |
| DCR `InvalidOutputTable` | Initialize the required Change Tracking solution/tables before creating the DCR; verify that every output stream is supported by that workspace. |
| Table creation `SolutionNotActive` for `ConfigurationData` | Enable the ChangeTracking solution for the selected workspace first. |
| `ConfigurationChangeV2` is unavailable | Do not assume every stream in a sample template is available. Use the supported streams/tables required for the scenario, such as `Microsoft-ConfigurationData` and `Microsoft-ConfigurationChange`; do not create a custom lookalike table as a workaround. |
| Extension succeeds but `ConfigurationData` is empty | Check the DCR association, enabled collection categories, destination, elapsed collection interval, and AMA ingestion health. Do not interpret empty data as an empty software estate. |

### Verify actual ingestion

Use the workspace customer ID with the query API, not its ARM resource ID:

```powershell
az monitor log-analytics query `
  --subscription "<subscription-id>" `
  --workspace "<workspace-customer-id>" `
  --analytics-query "ConfigurationData | where TimeGenerated > ago(24h) | summarize Rows=count(), LastInventory=max(TimeGenerated) by Computer, ConfigDataType" `
  --output json
```

Check operational telemetry separately:

```kusto
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat=max(TimeGenerated) by Computer, _ResourceId
```

Confirm that the intended pilot appears, timestamps are fresh, and software
rows are present. Run the tracker's
[inventory query](../livereports/templates/third-party-software-tracker/queries/report-inventory.kql)
and [coverage query](../livereports/templates/third-party-software-tracker/queries/inventory-coverage.kql)
as the report-specific checks.

Initial collection and ingestion are asynchronous. The template used in the
clean-tenant deployment configured software collection at **1,800 seconds
(30 minutes)** and inventory collection at **36,000 seconds (10 hours)**.
Inspect the deployed rule's `softwareSettings` and `inventorySettings`; these
observed defaults are not an ingestion-time guarantee. Do not repeatedly
reinstall a healthy extension just because the first query is empty.

You can save all three Live Reports while waiting for initial inventory.
Record them as **deployed, data validation pending** until reopening/reloading
shows the expected live results. Use the no-snapshot tracker so demonstration
fallback data cannot be mistaken for successful collection.

## Validated lab evidence

On 2026-09-01, `<canary-machine>` reported Python 3.13.12 through `ConfigurationData` software inventory. This proves the basic third-party inventory scenario is available without a new agent or connector.

Use [queries/software-inventory.kql](../queries/software-inventory.kql) to inspect current inventory.
Use the tracker's
[inventory query](../livereports/templates/third-party-software-tracker/queries/report-inventory.kql)
for its Windows application dataset.

## SRE Agent prompt

```text
Create a read-only third-party software inventory report from <log-analytics-workspace> Change Tracking
inventory. For each Arc machine, identify installed Python runtimes, Adobe/Acrobat products,
and other selected third-party applications; report installed version, publisher, inventory
timestamp, and machines where inventory is stale or absent.

Compare installed versions only with approved version baselines that I provide. If no verified
baseline is available, label version currency as "needs review" rather than out of date.
Identify inconsistent versions across equivalent machine roles and recent software changes.
Do not install, update, remove, or reconfigure software.
```

## Boundaries

| Software type | Change Tracking inventory | Additional collection needed |
| --- | --- | --- |
| MSI/registry-registered Windows software | Usually available | None for inventory; add an approved version baseline to assess currency. |
| Linux distribution packages | Available | None for inventory; package-manager metadata is needed to assess available versions. |
| Portable Python | May be absent | Collect a controlled `python --version` result. |
| Python virtual environments and `pip` packages | Not reliably available | Collect `pip list --format=json` through an approved, read-only script into a custom Log Analytics table. |
| User-profile applications | Available only while the user is signed in | Use an approved inventory method if persistent coverage is required. |
| SaaS or licensed software entitlement | Not available from machine inventory alone | Connect the approved software asset-management or license source. |

## Recommended phased demo

1. Report installed Python runtimes and validate freshness using existing `ConfigurationData`.
2. Add Acrobat or another known third-party application to one noncritical lab machine and verify the inventory record appears.
3. Create a small approved-version baseline for one or two applications.
4. Demonstrate version consistency and drift findings in the SRE Agent Live Report.
5. Add Python virtual-environment/package inventory only when a customer scenario requires it; collect only the required package names and versions to control cost and exposure.

See the [Live Report deployment guide](../livereports/README.md) for installable
bundles and the [tracker template guide](../livereports/templates/third-party-software-tracker/README.md)
for maintaining the dated vendor-latest reference.

The tracker reference is not the approved-version policy in
[third-party-software-baseline.json](../config/third-party-software-baseline.json).
Before setting an `approvedVersion`, verify the vendor's authoritative release
notes and record the source, review date, and update risk. A missing approved
target means "needs review"; a report's embedded reference alone does not
authorize an update.
