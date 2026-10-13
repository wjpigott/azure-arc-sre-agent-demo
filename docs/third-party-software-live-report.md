# Third-Party Software Lifecycle Live Report

## Purpose

The SRE Agent Live Report created on 2026-09-03 demonstrates third-party software inventory and version-lifecycle reporting for Azure Arc-enabled servers.

The report consumes the `<log-analytics-workspace>` Change Tracking software inventory. Its `ConfigurationData` query must run through the Monitor Workspace Log Query connector or the Log Analytics query editor; it cannot run in Azure Resource Graph. It should present installed products, inventory freshness, version consistency, and version currency only when an approved target version is verified.

## Source-control boundary

Azure SRE Agent Live Reports preserve their report layout, approved tools, and revisions in the agent experience. Do not rely on an agent-generated report as the only copy of a production query or version policy.

The reusable artifacts are maintained here:

| Artifact | Purpose |
| --- | --- |
| `queries/third-party-software-live-report-v1.kql` | Exact query captured from the initial Azure SRE Agent Live Report. |
| `queries/third-party-software-lifecycle.kql` | Reusable inventory query for Acrobat, 7-Zip, Python, Java 8, Chrome, and Node.js. |
| `queries/third-party-software-inventory-current.kql` | Scoped full inventory for the selected tracker, with latest observations and no embedded version approvals. |
| `reports/third-party-software-update-tracker.prompt.txt` | Selected tracker layout and safe classification/refresh requirements. |
| `config/live-report-catalog.json` | Software and Arc priority/lifecycle authoring blueprints; not a deployment API payload. |
| `config/third-party-software-baseline.json` | Human-reviewed target versions and official vendor release-note sources. |
| `docs/third-party-software-inventory.md` | Inventory collection scope and limitations. |

If SRE Agent exposes the Live Report's generated query/configuration later, compare it with these artifacts and capture any useful refinements in the repository.
The copied HTML from the initial report confirms the Monitor Workspace Log Query contract and is distilled into [software-live-report-template.md](software-live-report-template.md) for reuse without lab-specific identifiers.
The selected newer HTML snapshot has no executable query or connector code.
Use the [bootstrap guide](live-report-bootstrap.md) and selected tracker prompt
to author that layout with current, approved data; do not publish or import
the raw inventory snapshot as a live report.

## Live Report prompt

```text
Create a read-only Live Report named "Third-Party Software Lifecycle".

Use <log-analytics-workspace> Change Tracking software inventory. Show a priority action list first,
then inventory details for Adobe Acrobat, 7-Zip, Python, Java 8, Google Chrome, Node.js,
and other selected third-party software.

For each product, show machine, installed version, publisher, inventory timestamp, and
inventory freshness. Identify inconsistent versions across equivalent machines.

Compare an installed version with an approved target only when the target is supported by
vendor-authoritative release documentation. Cite the source and verification date. When a
target version is not verified, classify currency as "needs review"; do not call it out of date.
Keep OS, Python virtual-environment, pip-package, user-profile application, and license
entitlement limitations explicit.

Use read-only tools only. Do not install, update, remove, or reconfigure software.
```

## Verify a target version

1. Review the listed vendor source and confirm the release and support posture.
2. Add the exact `approvedVersion` and a review date to `config/third-party-software-baseline.json`.
3. Record whether the release is a security, critical, or routine update.
4. Update the SRE Agent Live Report instruction only if the product-specific update policy changes.

Do not set automatic remediation from this report. The first follow-on action should be a human-approved update recommendation for one noncritical machine.
