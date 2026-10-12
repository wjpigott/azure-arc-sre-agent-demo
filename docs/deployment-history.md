# Deployment Example

## Read-only SRE telemetry rollout

### Scope

- Subscription: `<subscription-id>`
- DCR resource group: `<monitoring-resource-group>`
- Destination: `<log-analytics-workspace>`

### Azure CLI commands used

```powershell
az account set --subscription '<subscription-id>'

az rest --method put `
  --url 'https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<monitoring-resource-group>/providers/Microsoft.Insights/dataCollectionRules/SRE-Windows-Telemetry?api-version=2023-03-11' `
  --body '@infra/dcr/SRE-Windows-Telemetry.json'

az rest --method put `
  --url 'https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<monitoring-resource-group>/providers/Microsoft.Insights/dataCollectionRules/SRE-Linux-Telemetry?api-version=2023-03-11' `
  --body '@infra/dcr/SRE-Linux-Telemetry.json'
```

The association payloads and a repeatable deployment script are stored under `infra/dcr` and `scripts`. Azure Resource Manager requires `Content-Type: application/json` for association requests.

### Verification

Confirm representative DCR associations on:

- `<monitoring-resource-group>/<windows-machine-2>` using `SRE-Windows-Telemetry`
- `<monitoring-resource-group>/<linux-machine-1>` using `SRE-Linux-Telemetry`
- `<arc-resource-group>/<canary-machine>` using `SRE-Windows-Telemetry`
