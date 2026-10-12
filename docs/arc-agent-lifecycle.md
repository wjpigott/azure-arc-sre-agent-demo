# Arc Connected Machine Agent Lifecycle

## Purpose

Use Azure SRE Agent and the read-only lifecycle inventory to make Arc agent currency a governed lifecycle process. The lab intentionally contains current, approved-lag, aging, and out-of-support versions, making it suitable for a customer demonstration.

## Source of truth

`config/arc-agent-baseline.json` is the locally version-controlled policy input. Review it monthly against the official [Azure Connected Machine agent release notes](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-release-notes).

As of 2026-08-31:

| Policy value | Release |
| --- | --- |
| Current canary release | 1.67 |
| Approved standard release | 1.66 |
| Minimum supported release | 1.57 |

Microsoft supports only agent versions released within the preceding year. The policy intentionally permits one approved release of lag for standard systems after canary observation.

## Observed lab baseline

The read-only inventory was validated on 2026-08-31:

| Classification | Machines |
| --- | ---: |
| Current (1.67) | 12 |
| Approved lag (1.66) | 4 |
| Aging (1.57-1.65) | 5 |
| Out of support (1.53) | 1 |

`<out-of-support-agent-machine>` is the out-of-support test case. Existing automatic-upgrade settings vary across the lab; this is intentionally reported as context and is not changed by the lifecycle tooling.

## Read-only inventory

Run:

```powershell
.\scripts\Get-ArcAgentLifecycleReport.ps1 -SubscriptionId "<subscription-id>"
```

The script reads Arc resource inventory and compares each agent version with the tracked baseline. It reports existing automatic-upgrade settings but never changes them.

## Exceptions

Record only time-bound, approved exceptions in `config/arc-agent-exceptions.json`:

```json
{
  "exceptions": [
    {
      "machine": "example-server",
      "owner": "Platform Operations",
      "rationale": "Application compatibility validation in progress",
      "expiresOn": "2026-10-31"
    }
  ]
}
```

Expired exceptions automatically revert to the version-based classification. Planned-offline state is not an agent-version exception and should be handled separately in the fleet-health prompt.

## Demo sequence

1. Run the read-only lifecycle inventory and show current, approved-lag, aging, and out-of-support results.
2. Ask SRE Agent to produce a 30/60/90-day lifecycle plan using the same policy.
3. Select one noncritical Current-1 or aging machine as a canary candidate.
4. Have the agent propose an upgrade plan, including maintenance window, validation, and rollback considerations.
5. Require explicit approval before any upgrade. Validate Arc reconnectivity and telemetry after the approved action.

Do not enable automatic upgrades or update an agent until the customer-specific ring policy and change approval are established.
