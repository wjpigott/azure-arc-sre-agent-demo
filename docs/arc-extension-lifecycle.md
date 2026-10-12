# Arc Extension Lifecycle

## Purpose

Track the lifecycle posture of Azure Arc extensions independently from the Azure Connected Machine agent. A server can run a current Arc agent while a monitoring, security, management, or SQL extension is outdated, unhealthy, not configured for supported automatic upgrade, or unnecessary.

## Scope

The read-only tracker inventories every `Microsoft.HybridCompute/machines/extensions` resource in the lab subscription:

- Machine, extension, publisher, type, installed handler version, and provisioning state.
- Existing `enableAutomaticUpgrade` setting.
- The local policy classification from `config/arc-extension-baseline.json`.

It does not install, update, delete, or change an extension.

## Automatic upgrade policy

Automatic Extension Upgrade is configured separately for each supported extension. Azure rolls supported extension updates out gradually under Safe Deployment Practices and automatically rolls back failed upgrades.

| Extension category | Default policy | Reason |
| --- | --- | --- |
| Azure Monitor Agent | Required | Telemetry is a foundational service; prolonged version drift creates observability risk. |
| Change Tracking | Required | Required for configuration-drift evidence. |
| Defender for Endpoint | Required | Endpoint security should receive supported platform updates. |
| Windows Admin Center | Review | Validate gateway certificate and service health first; the lab has a real WAC certificate crash-loop example. |
| SQL Arc extension | Review | Confirm SQL is installed and the extension is healthy first; unnecessary instances currently exhibit crash loops. |
| Azure Update Manager extensions | Review | Change the setting only after verifying product support and the patch-ring strategy. |
| Other extensions | Unmanaged | Inventory and classify explicitly before enabling automatic upgrade. |

The policy is not a blanket auto-upgrade mandate. Customer-specific change-control and ring requirements always take priority.

## Observed lab baseline

The read-only inventory was validated on 2026-09-01:

| Classification | Instances |
| --- | ---: |
| Compliant | 57 |
| Review enabled setting | 28 |
| Unmanaged extension | 41 |
| Provisioning issue | 4 |

All 19 Azure Monitor Agent instances are in a `Succeeded` provisioning state and have automatic extension upgrade enabled. This includes AMA installations confirmed on `<canary-machine>`, `<windows-machine-1>`, `<windows-machine-2>`, and `<planned-offline-linux-machine>`.

## Version tracking limitation

Azure Resource Graph exposes installed handler versions, but it does not provide a single reliable "latest version" feed for every extension publisher. The tracker therefore flags configuration and provisioning policy gaps continuously. For a high-value extension, add an approved target version to the baseline after verifying the publisher's release documentation.

Use two distinct measures:

| Measure | Meaning |
| --- | --- |
| Confirmed version drift | Installed handler version is below a publisher-verified `approvedVersion` recorded in the baseline. |
| Needs upgrade attention | An extension has a provisioning failure or a required automatic-upgrade setting is disabled. This is actionable, but not proof that a newer handler exists. |

No handler target version is set initially. This avoids falsely calling an extension stale during Azure's phased Safe Deployment rollout. Add an `approvedVersion` to a policy entry only after reviewing the publisher's release notes.

## Read-only inventory

Run:

```powershell
.\scripts\Get-ArcExtensionLifecycleReport.ps1 -SubscriptionId "<subscription-id>"
```

Run the compact management report:

```powershell
.\scripts\Get-ArcExtensionLifecycleReport.ps1 -SubscriptionId "<subscription-id>" -Summary
```

To emit the summary for a dashboard, automation, or SRE Agent grounding workflow:

```powershell
.\scripts\Get-ArcExtensionLifecycleReport.ps1 -SubscriptionId "<subscription-id>" -Summary -AsJson
```

Use the output with Azure SRE Agent to investigate:

```text
Review Arc extension lifecycle posture. Prioritize extensions with provisioning failures,
required automatic-upgrade settings disabled, or review-only extensions enabled without
documented validation. Correlate extension failures with <log-analytics-workspace> errors and Change Tracking.
Do not modify extensions.
```

## SRE Agent prompt addition

Add this section when editing the `Arc Fleet Operations` Live Report or creating the daily health task:

```text
Include Arc extension lifecycle posture. Report extension provisioning failures, foundational
extensions where automatic upgrade is disabled, review-only extensions with automatic upgrade
enabled, and extensions with verified handler versions below the approved baseline. Do not call
a handler version out of date unless a publisher-verified approved version is available. Report
unknown-version currency as "needs review," not "out of date." Do not modify extensions.
```

## Next controlled change

The first candidate should be a noncritical machine with a required foundational extension whose automatic upgrade is disabled. Validate its health, enable the setting only with human approval, and confirm telemetry continues after the platform-controlled change.
