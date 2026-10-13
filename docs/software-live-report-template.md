# Reusable Software Lifecycle Live Report Template

## What the existing report proves

The generated `Third-Party Software Update Tracker` is a valid Azure SRE Agent Live Report pattern:

1. Query Change Tracking software inventory from the `ConfigurationData` table.
2. Normalize product names and remove operating-system update noise.
3. Compare recognized software against a curated version reference.
4. Present a priority queue, searchable inventory, per-machine concentration, and reference-version transparency.

Reading software data needs a Log Analytics connector and read permission to the
target workspace. Creating or updating the report also requires authoring
permissions on the agent. Neither operation needs direct access to guest machines.

## Selected software tracker blueprint

The selected newer export preserves the summary cards, priority updates,
full inventory, per-machine chart and version-reference sections, but contains
no scripts, live queries or connector calls. It cannot be imported as a live
definition. Use the [authoring prompt](../reports/third-party-software-update-tracker.prompt.txt)
and [bootstrap guide](live-report-bootstrap.md) to reconstruct and validate
the view in a new agent. The [catalog](../config/live-report-catalog.json)
also includes the selected Arc Priority & Lifecycle report.

## Connector contract

The report calls the SRE Agent Monitor Workspace Log Query tool. The environment-specific values below must be replaced when sharing the pattern:

| Parameter | Purpose |
| --- | --- |
| `subscription` | Subscription containing the target Log Analytics workspace |
| `resource-group` | Resource group containing the workspace |
| `workspace` | Log Analytics workspace customer ID |
| `table` | `ConfigurationData` |
| `hours` | Inventory lookback window; use at least the inventory collection interval |
| `limit` | Maximum result count; tune to fleet size |

The captured version 1 report query is maintained in [third-party-software-live-report-v1.kql](../queries/third-party-software-live-report-v1.kql). It is **Log Analytics KQL**, not Azure Resource Graph (ARG) KQL: `ConfigurationData` exists only in the `<log-analytics-workspace>` Log Analytics workspace. Its query shape is:

```kusto
ConfigurationData
| where ConfigDataType == 'Software'
| where Publisher !has 'Microsoft'
| where SoftwareName !has 'Update for'
    and SoftwareName !has 'Security Update'
    and SoftwareName !has 'Hotfix for'
    and SoftwareName !has 'Definition Update'
| summarize arg_max(TimeGenerated, *) by Computer, SoftwareName
| project Computer, SoftwareName, CurrentVersion, Publisher, SoftwareType, TimeGenerated
| sort by Publisher asc, SoftwareName asc, Computer asc
```

The repository's curated alternative is [third-party-software-lifecycle.kql](../queries/third-party-software-lifecycle.kql). It limits output to products selected for lifecycle reporting.
For the selected full-inventory tracker, use
[third-party-software-inventory-current.kql](../queries/third-party-software-inventory-current.kql)
with the approved `Computer` list. It retains untracked products and chooses
the latest observation per machine/software/publisher/type rather than
classifying against the captured query's embedded versions.

## Captured query limitations

The version 1 report has embedded `case()` rules that use exact version equality. Preserve it as the generated-report artifact, but do not reuse those rules unchanged for a customer deployment:

| Rule | Limitation | Safer interpretation |
| --- | --- | --- |
| Java 8 | `CurrentVersion !has '503'` is a broad string test and assumes 8u503 is the approved baseline. | Compare a parsed Java update version against a vendor-verified approved version. |
| 7-Zip, Acrobat, Chrome | `!=` flags versions newer than the embedded target as outdated. | Use semantic version comparison: installed `<` approved target. |
| `Publisher !has 'Microsoft'` | Marks all other third-party products as untracked, not current. | Keep `Untracked` and explicitly state that it means currency has not been assessed. |
| Inventory freshness | No inventory-age threshold is included. | Add stale/absent inventory status before making a lifecycle decision. |

The report's presentation-level `VERSION_DB` contains the same point-in-time targets. Copy verified values into `config/third-party-software-baseline.json`, with the vendor source and review date, before treating a status as operationally authoritative.

## Version-reference database

The embedded JavaScript `VERSION_DB` in the generated report is the product-currency decision layer. Maintain it as version-controlled data instead: [third-party-software-baseline.json](../config/third-party-software-baseline.json).

Before setting a product's `approvedVersion`:

1. Verify the version in the vendor's authoritative release notes.
2. Record the source and review date.
3. Record the product-specific risk classification and update policy.
4. Use `needs review` when no approved version exists.

Do not treat a generated report's embedded version as authoritative. The reported Chrome release date in the original investigation was later than the report date, which demonstrates why an unverified web lookup or model assertion must not become an operational baseline.

## Sharing the pattern

1. Deploy Change Tracking and Inventory plus AMA to target Arc machines.
2. Confirm `ConfigurationData` software inventory is fresh in the target Log Analytics workspace.
3. Connect that workspace to an Azure SRE Agent with read-only permissions.
4. Copy the Live Report prompt from [third-party-software-live-report.md](third-party-software-live-report.md).
5. Replace connector scope values in the report with the target environment values.
6. Populate only vendor-verified version baselines.
7. Keep the report read-only; use it to recommend a change, not execute software updates.

## What must not be shared verbatim

- Subscription IDs, workspace IDs, tenant identifiers, or machine inventories.
- Unverified version/release claims.
- Application-specific software lists where they reveal customer implementation details.
- Any write-capable tool permissions.
