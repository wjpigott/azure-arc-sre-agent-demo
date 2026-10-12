# AMA Installed but No Telemetry Runbook

## Scope

Use this runbook when an Azure Arc machine has all three Azure-side conditions but emits no `<log-analytics-workspace>` data:

1. Arc connection state is `Connected`.
2. Azure Monitor Agent extension provisioning is `Succeeded`.
3. The expected SRE data collection rule is associated.

## Example condition

Apply this runbook when an affected machine has no `Heartbeat`, `Perf`, or `Event` records in `<log-analytics-workspace>` during the preceding 24 hours.

## Read-only diagnosis

On the affected Windows host, inspect the Azure Monitor Agent without changing configuration:

```powershell
Get-Service AzureMonitorAgent
Get-WinEvent -LogName "Microsoft-AzureMonitor-Agent/Operational" -MaxEvents 100 |
  Select-Object TimeCreated, Id, LevelDisplayName, Message
Get-ChildItem "C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent" -Recurse -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 20 FullName, LastWriteTime, Length
Test-NetConnection -ComputerName "<workspace-id>.ods.opinsights.azure.com" -Port 443
```

Replace `<workspace-id>` with the Log Analytics workspace customer ID.

Check:

- The `AzureMonitorAgent` service is running.
- The operational log reports that the DCR was received and does not show authentication, TLS, proxy, or ingestion errors.
- Extension logs continue to update after the DCR association.
- TCP 443 to the workspace ingestion endpoint is reachable through the host's intended proxy/firewall path.

## Decision path

| Evidence | Likely cause | Safe next action |
| --- | --- | --- |
| Service stopped or operational errors | Local AMA service/extension issue | Capture error evidence; repair only through an approved change. |
| DCR absent from operational logs | Association pickup failure | Wait for propagation, then reassociate only through an approved change. |
| TLS, proxy, DNS, or TCP failure | Egress configuration issue | Correct the approved network/proxy policy; do not bypass it locally. |
| Service and egress healthy but no records | DCR source/configuration issue | Validate the DCR schema and data sources against a known-good machine. |

This is a useful Platform Health demonstration: Azure resource state alone can look healthy while the observability data plane is unavailable. The SRE Agent should report it as a telemetry coverage degradation, not as a healthy monitored server.
