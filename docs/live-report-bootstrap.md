# Selected Live Report Blueprints

These two reusable authoring blueprints preserve the sections of the selected
software update tracker and Arc priority/lifecycle reports without publishing
their exported machine inventory, workspace names, timestamps or embedded images.

| Blueprint | Authoring instructions | Intended view |
| --- | --- | --- |
| Third-Party Software Update Tracker | [Prompt](../reports/third-party-software-update-tracker.prompt.txt) | Summary, priority updates, searchable inventory, per-machine chart, version references |
| Arc Priority & Lifecycle | [Prompt](../reports/arc-priority-lifecycle.prompt.txt) | Priority queue, patch/maintenance readiness, lifecycle, capacity, reliability and configuration |

The [catalog](../config/live-report-catalog.json) records required runtime
bindings, data sources, defaults, source files and acceptance checks.
It is **an authoring catalog, not an ARM template or a report import API payload**.
No repository script currently consumes it to create reports automatically.

## Why the exports are references, not deployments

Both supplied HTML exports are static snapshots: no scripts, connector calls
or original live queries are present. Their appearance and section names can
guide authoring, but they cannot restore live refresh or reproduce the original
query implementation. Do not upload the raw exports to GitHub.

Microsoft's [Live Reports documentation](https://learn.microsoft.com/azure/sre-agent/live-reports)
describes authoring through the agent and static HTML download. These blueprints
do not assume an undocumented create/import endpoint. Fully unattended creation
still requires verification of a supported API or another approved authoring
mechanism in the target agent.

## New-deployment setup

1. Deploy telemetry and inventory prerequisites, create the agent, and configure
   the approved Azure and Log Analytics read connectors.
2. Resolve `runtimeBindings` from the catalog into a private deployment copy.
   Use the Log Analytics customer ID for the connector's `workspace` value, not
   its ARM resource ID. Confirm subscription/tenant authentication, Arc resource
   group scope, and the mapping of Arc names to inventory `Computer` values.
   An empty planned-offline list means none are configured; do not inherit lab
   machine names. Keep actual values and generated report IDs out of GitHub.
3. Review lookback windows, freshness thresholds, version baselines, exceptions
   and the capacity policy. The supplied numeric defaults are starting points,
   not a universal support or alert policy. Resolve the memory-pressure policy
   and source freshness thresholds before treating those sections as complete.
4. For DEV/TEST, use `<displayName> - <DEV-or-TEST> - <deployment-id>`.
   Production can use the canonical display name. Check existing reports and
   private saved IDs before creating a duplicate; do not overwrite reports in
   another scope just because their display name is similar.
5. In `sre.azure.com`, select **Live Reports > New report** and provide the
   selected prompt with `<resolved-report-name>` replaced, the resolved
   bindings, and the referenced query/baseline content. Review and approve only
   expected read tools. Report authoring requires read/write access on the
   agent, but source resources and connectors remain read-only.
6. Replace `TargetMachines` in the
   [current software inventory query](../queries/third-party-software-inventory-current.kql)
   with approved inventory names. Validate the remaining priority/lifecycle
   queries in the authoring thread; the original queries are absent from the
   export. Missing schemas or permissions must be reported, not worked around
   with broader unapproved access.
7. Open and reload each saved report. Validate representative rows against
   source queries, record the report ID/name/scope/blueprint version privately,
   and retain the authoring thread. A prepared prompt is not a created report.

## Required behavior corrections

Preserve the selected layout, not erroneous snapshot conclusions:

- The tracker snapshot labels a newer Chrome version outdated against an older
  reference. Numeric installed `>` approved comparison must be `AheadOfPolicy`,
  never an update/downgrade request. No approved baseline means `NeedsReview`.
  The existing [version 1 query](../queries/third-party-software-live-report-v1.kql)
  is historical capture, not the classification engine for this blueprint.
- The tracker displays 500 inventory entries. The export does not prove whether
  the connector result was capped. Show limit/partial-result state, distinguish
  installation rows from distinct products/machines, and derive cards, chart
  and priority counts from the same data and filters.
- The lifecycle snapshot has a fresh page timestamp alongside older Azure
  resource and maintenance evidence. Show retrieval and observation time per
  source. Historical run failures must not become current fleet failures
  without fresh verification of scope and run state.
- Keep source failures, missing data, stale observations, missing baselines
  and untracked products visible; none is equivalent to healthy/current.

## Acceptance and automation boundary

Require both reports to exist in the intended agent, reopen successfully,
retrieve the approved scope, and show their source freshness and query errors.
Test null baselines, a newer installed version, stale inventory, a disconnected
machine, planned offline, a missing table, and a partial result. Confirm that
there are no remediation buttons or write-capable data tools.

These are public-safe blueprints for post-deployment authoring and a future
bootstrap implementation. They are not yet verified live report definitions
for a new environment. Do not mark automatic deployment complete until a
supported creation mechanism is implemented and saved reports are validated.

Validate the repository blueprint contract without accessing Azure:

```powershell
.\tests\Test-LiveReportBlueprints.ps1
```

This checks the catalog and source references, not saved-report creation,
rendering, connector access or the runtime classification implementation.
