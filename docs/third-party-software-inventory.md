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

Check guest resource headroom before installing monitoring extensions or
running updates. For a small Windows demo with AMA, Change Tracking, and AUM,
4 vCPUs and 8 GB RAM is a practical starting point if the Hyper-V host has
capacity, not a Microsoft minimum or a guarantee of ingestion. A 2 GB guest
can have little headroom for these concurrent workloads. Resize through a
planned shutdown after active installation/extension operations finish;
additional resources do not repair an invalid workspace log type.

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

## Windows Arc AMA recovery

Use this only for an explicitly approved Windows Arc pilot with persistent
missing inventory and evidence of AMA routing/upload failures. A single empty
query or startup pipe error is not a reason to reinstall an agent.

### Separate collection, handoff, and ingestion

| Evidence | What it establishes |
| --- | --- |
| Collector lists applications or patches | Local discovery works; it does not prove delivery. |
| `Sending software data to output handler` | The collector attempted a handoff, not confirmed workspace ingestion. |
| Missing `CAgentStream_CloudAgentInfo_AzureMonitorAgent` pipe | AMA's local settings endpoint was unavailable at that timestamp. Correlate with boot and AMA start times. |
| Missing `CONFIG_CHANGE_BLOB` output stream | A Change Tracking stream was unavailable at that timestamp; inspect current effective configuration rather than adding duplicate rules. |
| `CONFIG_DATA_BLOB_V2` is not a valid workspace log type | Inventory routing/ingestion rejected the internal type. Investigate AMA and workspace registration; the error alone does not identify which side is faulty. |
| Old agent-version path or package-consistency warning | Preserve the full message and timestamp, then compare with current executable paths. An old path alone does not prove the current runtime is corrupt. |
| Extension provisioning `Succeeded` or fresh Heartbeat | Extension deployment or ordinary AMA ingestion works, not necessarily inventory. |
| Fresh `ConfigurationData` software rows for the pilot | The inventory path is functioning. |

The DCR uses `Microsoft-ConfigurationData` and
`Microsoft-ConfigurationChange`; do not substitute internal names such as
`CONFIG_DATA_BLOB_V2`, create custom lookalike tables, or add another Change
Tracking DCR to bypass an error.

Useful Windows Arc locations:

- Collector and handler logs:
  `C:\Packages\Plugins\Microsoft.Azure.ChangeTrackingAndInventory.ChangeTracking-Windows\<version>\cta_windows_agent.log`
  and `cta_windows_handler.log` in the same directory.
- AMA effective DCR configuration:
  `C:\Resources\Directory\AMADataStore\mcs\configchunks`.
- AMA configuration logs:
  `C:\Resources\Directory\AMADataStore\Configuration`.
- Extension logs:
  `C:\ProgramData\GuestConfig\extension_logs`.

Use the installed version rather than assuming a folder name. Preserve relevant
logs before repair, keep diagnostics outside the repository, and redact
credentials and environment identifiers before sharing. Compare timestamps with
their explicit UTC offsets; collector time may differ from the operator's time
zone. Avoid unbounded TSF conversions or dumping full software payloads into
Run Command output.

### Controlled AMA-only reinstallation

This interrupts **all AMA-collected telemetry** temporarily. It does not reboot
the guest or require deleting Change Tracking, DCRs, associations, or workspace
tables. It is not an AUM patch repair. Coordinate with active maintenance and
keep the guest running until removal, reinstallation, and verification finish.

The following workstation procedure applies to default Arc system-assigned
authentication with **no custom public or protected extension settings**. For
custom proxy/identity settings or secrets, recover the approved deployment
configuration first: ARM reads do not return protected setting values. Do not
overwrite such an installation with an empty-settings example.

```powershell
$ErrorActionPreference = 'Stop'
$subscription = '<subscription-id>'
$resourceGroup = '<arc-resource-group>'
$machine = '<arc-machine-name>'
$machineId = "/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$machine"
$amaUrl = "https://management.azure.com${machineId}/extensions/AzureMonitorWindowsAgent?api-version=2024-07-10"
$associationsUrl = "https://management.azure.com${machineId}/providers/Microsoft.Insights/dataCollectionRuleAssociations?api-version=2023-03-11"
$backupBase = Join-Path $env:TEMP ("ama-repair-" + [guid]::NewGuid())

az rest --method get --url $amaUrl --output-file "$backupBase-before.json"
if ($LASTEXITCODE -ne 0) { throw 'Could not save AMA configuration.' }
az rest --method get --url $associationsUrl --output-file "$backupBase-associations.json"
if ($LASTEXITCODE -ne 0) { throw 'Could not save DCR associations.' }

$before = Get-Content -LiteralPath "$backupBase-before.json" -Raw | ConvertFrom-Json
if ($before.properties.publisher -ne 'Microsoft.Azure.Monitor' -or
    $before.properties.type -ne 'AzureMonitorWindowsAgent') {
    throw 'Unexpected extension identity; stop before removal.'
}
if ($before.properties.PSObject.Properties.Name -contains 'settings') {
    throw 'Custom/public settings require reviewing the original deployment first.'
}

$properties = @{}
foreach ($key in @('publisher', 'type', 'typeHandlerVersion',
                   'autoUpgradeMinorVersion', 'enableAutomaticUpgrade')) {
    $property = $before.properties.PSObject.Properties[$key]
    if ($null -ne $property) { $properties[$key] = $property.Value }
}
@{ location = $before.location; properties = $properties } |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath "$backupBase-reinstall.json" -Encoding ascii

az connectedmachine extension delete `
    --subscription $subscription --resource-group $resourceGroup `
    --machine-name $machine --extension-name AzureMonitorWindowsAgent --yes
if ($LASTEXITCODE -ne 0) { throw 'Removal failed; inspect state before continuing.' }

az rest --method put --url $amaUrl --body "@$backupBase-reinstall.json"
if ($LASTEXITCODE -ne 0) {
    throw 'Reinstall request failed; AMA must be explicitly recovered.'
}
az rest --method get --url $amaUrl `
    --query "properties.{state:provisioningState,version:typeHandlerVersion,status:instanceView.status}"
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect AMA reinstallation.' }
```

This preserves the installed version and upgrade flags rather than guessing a
new version. If an upgrade is required, select a supported publisher-approved
version separately. Do not copy read-only instance-view/status properties into
a reinstall request. The saved files are private recovery material, not files
to commit.

Removal and installation are asynchronous and may take several minutes.
The final GET above is a status snapshot, not a wait or health check. Continue
checking until the extension succeeds or reports a failure; a successful PUT,
an absent resource during removal, or `Creating` does not complete the repair.
Do not assume that an existing DCR association will automatically reinstall a
deleted AMA extension: explicitly reinstall it as above, or verify that the
approved onboarding/policy remediation actually ran.

If AMA stays `Creating` and a read-only Run Command stays `Unknown` with no
start time or output, confirm guest responsiveness and inspect the Arc
extension manager locally, including
`C:\ProgramData\GuestConfig\ext_mgr_logs\gc_ext.log`. Arc `Connected` does not
prove extension execution is healthy. Inspect the responsible Windows service
and executable before considering an approved restart; do not queue repeated
reinstalls or assume that a zero Run Command exit code means it executed.
Always check `instanceView.executionState`: ARM provisioning success can also
accompany an execution timeout.

### Validate recovery and know when to escalate

1. Confirm the reinstalled AMA extension succeeds and its processes start from
   the expected installed location. Do not manually remove old directories or
   delete `AMADataStore`.
2. Compare the machine's DCR associations with the saved snapshot. Keep the
   operational and Change Tracking rules and the intended workspace unchanged.
3. Verify fresh Heartbeat, effective Change Tracking configuration, and both
   the settings pipe and the `CAgentStream_ChangeTracking-Windows_*` data pipe.
   Pipe existence proves availability, not successful delivery.
4. Check collector and AMA messages **after** the repair timestamp. If a
   collector needs a separate service restart after AMA is ready, approve and
   record that action explicitly rather than restarting arbitrary Arc services.
   Inspect `Get-Service change_tracking_service` status and `CanStop` first.
   If stopping fails, inspect the final service state instead of retrying with
   force or killing processes. If fully stopped, restore the same collector
   service to Running; if it is pending, capture the error and plan an approved
   graceful guest restart rather than forcing termination.
5. Re-run the [ingestion checks](#verify-actual-ingestion). Scope results to
   the pilot's exact ARM resource ID and confirm fresh software records.
   `ingestion_time()` can help distinguish newly received rows from old data.
   AUM results are separate; do not expect one Change Tracking row per patch.
6. Record extension recovery and inventory recovery separately. If a fresh
   AMA installation still rejects `CONFIG_DATA_BLOB_V2` for the correct
   workspace, preserve timestamped errors, agent versions, DCR IDs, and
   workspace/table/solution provisioning evidence for Azure Monitor/Change
   Tracking support. Repeated reinstalls do not repair workspace-side stream
   registration.

See Microsoft's [AMA installation and management guidance](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-manage)
and [Change Tracking architecture](https://learn.microsoft.com/azure/azure-change-tracking-inventory/overview-monitoring-agent).

## Validated lab evidence

### 2026-10-20: AMA recovery checkpoint

On a Windows Arc pilot with 2 GB RAM, an explicit AMA-only reinstall preserved
handler version `1.45.0.0`, the original automatic-upgrade settings, and both
operational and Change Tracking DCR associations. Azure eventually reported
provisioning success. Local checks confirmed new `MonAgent*` processes under
the installed version and both required AMA pipes, followed by fresh workspace
Heartbeat records.

At that checkpoint, `ConfigurationData` and `ConfigurationChange` still had
no rows. This establishes **AMA recovery, not a confirmed inventory repair**
or proof that the previously quoted invalid-log-type error was resolved.
A subsequent targeted collector restart reported `StopServiceFailed`; no
forced termination was attempted. Treat its final service state as a separate
verification, not a successful restart.

The same investigation demonstrated why short diagnostic timeouts can mislead:
a 90-second Run Command returned only its initial timestamp before execution
timed out. Allow a bounded window that covers PowerShell startup and the actual
operation on the guest, and inspect execution state and exit code separately
from ARM provisioning. Longer timeouts or additional RAM are not proof of
successful inventory ingestion.

### Earlier inventory evidence

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
