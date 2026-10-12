# Third-Party Software Inventory

## What is available now

Azure Change Tracking and Inventory already writes installed-software inventory into the `ConfigurationData` table in `<log-analytics-workspace>`. Azure SRE Agent can query that connected workspace and create evidence-cited inventory, compliance, and lifecycle reports.

The inventory includes system-level software on Windows and installed packages on Linux. User-level software appears only while that user is signed in.

## Validated lab evidence

On 2026-09-01, `<canary-machine>` reported Python 3.13.12 through `ConfigurationData` software inventory. This proves the basic third-party inventory scenario is available without a new agent or connector.

Use [queries/software-inventory.kql](../queries/software-inventory.kql) to inspect current inventory.
Use [queries/third-party-software-lifecycle.kql](../queries/third-party-software-lifecycle.kql) for the curated lifecycle-report dataset.

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

See [third-party-software-live-report.md](third-party-software-live-report.md) for the reusable Live Report prompt and version-baseline process.
