# Deploy Azure SRE Agent

## Purpose

Deploy a governed, read-only Azure SRE Agent for the Azure Arc lab. The initial agent investigates and reports; it does not restart machines, deploy patches, run commands, or upgrade Arc agents.

## Prerequisites

| Requirement | Status |
| --- | --- |
| Subscription | `<subscription-name>` (`<subscription-id>`) |
| Deployment access | Owner and User Access Administrator |
| `Microsoft.App` | Registered |
| `Microsoft.CloudHealth` | Registered |
| Recommended region | Central US |
| Browser/network access | `*.azuresre.ai` must support HTTPS and WebSockets |

## Portal deployment

1. Open [Azure SRE Agent](https://sre.azure.com) and sign in to the lab tenant.
2. Select **Create agent**.
3. Set **Subscription** to `<subscription-name>`.
4. Create resource group `<sre-agent-resource-group>`.
5. Set **Agent name** to `<sre-agent-name>`.
6. Select **Central US** as the region.
7. Select an available model provider shown for this subscription and region.
8. Select **Create new** for Application Insights. This monitoring instance is for agent telemetry; it is separate from `<log-analytics-workspace>`.
9. Review and select **Create**. Provisioning normally takes two to five minutes.

## Initial least-privilege configuration

After deployment, select **Set up your agent** and configure these sources:

| Setup card | Configuration |
| --- | --- |
| Logs | Add the `<log-analytics-workspace>` Log Analytics workspace |
| Azure resources | The dedicated Arc lab subscription was added with read access |
| Code | Optional for the infrastructure-only first phase; connect this repository after it is pushed to an accessible provider |

Use a dedicated subscription only when all resources in it are in scope. The portal assigns the agent managed identity the Reader, Log Analytics Reader, and Monitoring Reader roles it needs for initial investigation. Otherwise, reduce access to the specific resource groups that contain the monitored Arc resources.

## Initial safety settings

- Set the global agent default and the first scheduled task to **Review** mode.
- Do not add Privileged resource access.
- Do not connect remediation tools, Azure CLI write skills, or Run Command.
- Do not configure Teams or email notifications until their content and recipients have been approved.

## First scheduled task

Create a daily task called `Arc Fleet Daily Health` with this instruction:

```text
Review Azure Arc machines in <monitoring-resource-group> and <arc-resource-group>. Identify unexpected
disconnections, stale heartbeats, disks under 15% free, CPU or memory pressure, uptime
over 30 days, Windows critical/error events, Linux warning-or-higher syslog, and missing
critical/security updates. Treat <planned-offline-linux-machine> and <planned-offline-windows-machine> as planned offline unless
instructed otherwise. Review Arc Connected Machine agent versions against the approved
rollout policy. Separate approved one-version lag from risky drift and temporary
exceptions. Rank findings, cite evidence, explain likely root cause, and recommend a safe
next action. Do not make changes.
```

Set it to run daily, select **Review** mode, and have results remain in the agent portal for the initial validation period.

## Post-deployment validation

Create or reconcile the selected software tracker and Arc priority/lifecycle
reports using [live-report-bootstrap.md](live-report-bootstrap.md).
The authoring catalog and prompts do not create saved reports automatically;
validate source access and save the generated IDs privately after authoring.

Ask the agent:

```text
Check <log-analytics-workspace> for errors in the last 24 hours and summarize the health of my Arc fleet.
```

Confirm that it can access `<log-analytics-workspace>`, distinguishes planned-offline machines from unexpected outages, and cites telemetry evidence. Observe the scheduled task for two to four weeks before considering approval-gated remediation.
