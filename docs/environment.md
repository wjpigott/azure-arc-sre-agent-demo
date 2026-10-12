# Environment Baseline

Last updated: 2026-08-31

## Azure resources

| Capability | Resource or configuration |
| --- | --- |
| Azure Arc | `Microsoft.HybridCompute/machines` in `<monitoring-resource-group>` and `<arc-resource-group>` |
| Central health and change workspace | `<log-analytics-workspace>` (`<monitoring-resource-group>`, Central US) |
| Azure Monitor Agent | Present on representative connected Windows and Linux Arc hosts |
| Change Tracking | `ChangeTracking-Windows` and `ChangeTracking-Linux` extensions reporting to `<log-analytics-workspace>` |
| Patch management | Azure Update Manager with environment-specific maintenance configurations |
| Security/governance | Azure Policy assignments provision Guest Configuration for Windows and Linux; the ManagedOps initiative supplies Azure Monitor and Change Tracking DCR references |

## Intentional exclusions at the first rollout

- `<planned-offline-linux-machine>`: offline by design at the time of rollout.
- `<planned-offline-windows-machine>`: offline by design at the time of rollout.

## SRE telemetry baseline

The SRE DCRs are intentionally distinct from the existing Change Tracking DCR:

| DCR | Target OS | Destination | Evidence |
| --- | --- | --- | --- |
| `SRE-Windows-Telemetry` | Windows Arc machines | `<log-analytics-workspace>` | CPU, memory, disk, uptime, Application/System error and critical events, Windows Update operational warning/error/critical events |
| `SRE-Linux-Telemetry` | Linux Arc machines | `<log-analytics-workspace>` | CPU, memory, disk, syslog warning through emergency |

This separation makes operational monitoring independently auditable and reversible without disturbing Change Tracking.
