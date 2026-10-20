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

## Confirm the destination before creating resources

For a new tenant, authenticate and inspect the CLI context:

```powershell
az login --tenant "<tenant-id>"
az account set --subscription "<subscription-id>"
az account show --subscription "<subscription-id>" `
  --query "{subscription:name,subscriptionId:id,tenantId:tenantId}" --output json
```

Separately verify the directory and subscription in the SRE browser. The CLI,
VS Code account, and browser can be signed into different tenants; changing one
does not switch the others. Use explicit `--subscription` on subsequent Azure
commands and stop if the destination differs from the approved scope.

Select the Arc pilot resources and telemetry workspace before creating the
agent. Record these distinct values privately:

- Tenant, subscription, Arc resource group, and pilot machine names.
- Arc telemetry workspace name, resource group, ARM resource ID, and customer
  ID GUID. Reports use the customer ID; DCRs use the ARM resource ID.
- Agent name, resource group, region, and managed identity.

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

The wizard may create a Log Analytics workspace for Application Insights.
That workspace holds agent-infrastructure telemetry; it is not automatically
configured to collect Arc machine data. Connect the workspace actually used by
the machines' DCRs, even if it is in a different resource group.

## Initial least-privilege configuration

After deployment, select **Set up your agent** and configure these sources:

| Setup card | Configuration |
| --- | --- |
| Logs | Add the `<log-analytics-workspace>` Log Analytics workspace |
| Azure resources | Add only the approved Arc resource groups or resources with read access |
| Code | Required for repository-based Live Report installation; optional when attaching bundles directly |

Use a whole subscription only when all resources in it are in scope. Inspect
the **actual** role assignments on the agent's user-assigned managed identity
after the wizard completes. In a clean-tenant deployment, the wizard created
**Monitoring Contributor** on the selected resource group; do not assume the
initial configuration is read-only.

For this read-only scenario, use scoped **Reader** on the monitored Arc
resources and **Log Analytics Reader** on their telemetry workspace. Add
Gallery Reader access only if application-version assessment needs it. Review
and remove unnecessary contributor assignments after verifying the replacement
read access. Do not grant subscription Contributor to resolve a query failure.
Review mode and Azure RBAC are separate controls: Review mode does not reduce
an identity's standing permissions.

## Connect this repository to the agent

Signing into GitHub through VS Code, `gh`, or local Git does **not** connect
the SRE Agent to a repository. For repository-based report installation:

1. Select **Set up your agent > Code > Connect repositories**, or open
   **Builder > Code Access > GitHub > Add repository** on an existing agent.
2. Enter `https://github.com/wjpigott/azure-arc-sre-agent-demo`.
3. Complete a supported authentication method, select the repository, and save
   the connection.
4. Wait for the repository to become available. Ask the agent to confirm the
   exact `codeRefs/<repo>` path and that it can read
   `livereports/live_report_bundle.py` and `livereports/reports`.
5. Use that verified path in the scripted installation commands. Do not assume
   a successful sign-in means the repository has been added or cloned.

### VS Code integrated browser and PAT authentication

In the tested VS Code integrated-browser deployment, a **Personal access token
(PAT)** was the usable connection option. Document this as a tested path, not a
universal product restriction: Microsoft also documents OAuth for github.com
when configured, and a bring-your-own GitHub App option.

If OAuth cannot be completed in the integrated browser, try the external
browser or select **Personal access token** in the agent's repository wizard.
Create the token in GitHub with access limited to the required repository and
permissions needed by the selected connection, set an expiration, and complete
any organization-required authorization. Enter it only in the connection
wizard's credential field. Never paste it into an agent conversation, commit
it, or put it in an install plan, command line, or deployment log. Rotate or
revoke it according to your organization's policy.

For production, evaluate a GitHub App rather than treating a personal token as
a permanent service identity. Follow Microsoft's current
[source-code connection guidance](https://learn.microsoft.com/azure/sre-agent/connect-code-service)
for authentication availability and permissions.

**No GitHub connection is required for attachment-based installation.** Attach
the bundle tool and report bundles directly, or prepare locally and attach the
HTML, as described in the [Live Report guide](../livereports/README.md).

## Enable Arc telemetry and inventory

Before interpreting reports, verify AMA and operational DCR associations on
the approved pilot. Enable
[Change Tracking & Inventory](third-party-software-inventory.md#first-time-setup-in-a-new-workspace)
separately for the software tracker. The repository telemetry script configures
operational DCRs only; it does not install AMA or enable inventory.

**Bulk-script boundary:** `Deploy-SreTelemetry.ps1` targets every connected Arc
machine in its selected subscription, changes the default CLI subscription,
and has no machine filter or `-WhatIf` mode. For a one-machine pilot, use
explicitly scoped DCR associations through Azure Monitor. The DCR resource
group parameter is not a target-machine filter.

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

Install the required Live Reports using the
[bundle deployment guide](../livereports/README.md). Choose chat attachment,
scripted installation through the chat API, or local preparation. For scripted
installation with this repository, use `codeRefs/<repo>/livereports/reports`
as the bundle path and `codeRefs/<repo>/livereports/live_report_bundle.py`
as the script path. Tool-access approval remains manual.

Use the current no-fallback fleet/priority bundles, which rebuild inventory
from accessible Arc resources in the bound subscription on every open.
Verify Resource Graph read access, telemetry scope and
[coverage limits](../livereports/README.md#current-infrastructure-rebuilds-and-coverage-limits).
If an existing report shows unfamiliar demo names, follow the
[replacement procedure](../livereports/README.md#replace-an-older-report-that-displays-unfamiliar-demo-machines);
reloading an old saved version does not replace its embedded data.

Treat these as separate validation gates:

1. **Deployed:** extensions, DCR associations, agent, and saved reports exist.
2. **Collecting:** fresh Heartbeat/Perf and `ConfigurationData` arrive in the
   intended workspace; missing Event records alone do not prove collection is
   broken because qualifying errors may not have occurred.
3. **Live-validated:** reopen and reload each report, confirm source access,
   actual machine counts and freshness, and test section interactions.

Reports can be saved before initial inventory arrives, but record runtime
validation as **pending**, not successful. Empty software results are not proof
that no applications are installed. Save generated report IDs privately.

Ask the agent:

```text
Check <log-analytics-workspace> for errors in the last 24 hours and summarize the health of my Arc fleet.
```

Confirm that it can access `<log-analytics-workspace>`, distinguishes planned-offline machines from unexpected outages, and cites telemetry evidence. Observe the scheduled task for two to four weeks before considering approval-gated remediation.
