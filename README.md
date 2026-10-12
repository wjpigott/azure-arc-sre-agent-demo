# Azure Arc SRE Agent Demo

An infrastructure-focused SRE agent demo for an Azure Arc-enabled Windows and Linux lab. The project establishes reliable fleet telemetry first, then adds a controlled, read-only agent interface that can summarize health, patch risk, reboot debt, disk pressure, and critical failures.

## Demo outcome

Demonstrate Azure SRE Agent as an infrastructure operations teammate for a mixed Azure Arc fleet. The agent should turn monitoring and management data into an evidence-based operational assessment, distinguish expected conditions from actionable risk, and propose safe remediation under explicit governance.

The core demonstration flow is:

1. A host-level or individual-machine problem occurs.
2. Azure SRE Agent correlates Arc connection state, heartbeats, performance, critical events, configuration drift, and Azure Update Manager results.
3. The agent explains the likely cause, impact, supporting evidence, and the safest next action.
4. A Live Report presents a repeatable `Arc Fleet Operations` view without regenerating a dashboard on every open.
5. The agent proposes an Azure operation only in Review mode; a human approves any patch, restart, or Run Command action.

### Initial operational questions

- Which Arc machines are unexpectedly disconnected or have stale telemetry?
- Which hosts have disk, CPU, or memory pressure?
- Which Windows or Linux hosts show recent high-severity operational errors?
- Which machines have missing security/critical updates or reboot debt?
- Which machines drift from required monitoring, security, and configuration baselines?
- Which Arc Connected Machine agents are outside the approved version policy?

### Customer strategy alignment

This demo maps to the customer's platform strategy:

| Customer theme | SRE Agent demonstration |
| --- | --- |
| Platform Health | A live fleet view that correlates Arc state, heartbeat, capacity, operational failures, patch posture, and configuration change evidence. |
| Proactive Lifecycle Management | Patch-assessment freshness, reboot debt, Arc agent version rings, and planned maintenance risk identified before a service issue. |
| New Capability and Increased Maturity | Repeatable telemetry baselines, controlled deployment rings, and evidence-cited operating procedures. |
| Platform Management Evolution | Governed AI-led incident investigation, problem-pattern identification, and approval-gated change recommendations. |

The first customer-facing scenario is **proactive fleet health and management-plane drift**: the agent identifies a meaningful infrastructure condition, distinguishes expected exceptions from risk, shows correlated evidence, and proposes a low-risk action. It does not need an application workload or autonomous repair to show value.

### Arc agent version policy

The demo deliberately supports controlled version lag. The goal is not "upgrade every machine immediately"; it is to identify risky drift while honoring a tested rollout process.

| Ring | Expected version posture |
| --- | --- |
| Canary/lab | Current production release, observed for 7-14 days |
| Standard production | One approved release behind is healthy |
| Sensitive or legacy | Temporary pinned exception with an owner and expiry |
| Security override | Accelerated upgrade only for confirmed critical security or reliability risk |

The agent must classify machines as approved lag, risky drift, or documented exception. Its findings should include the current release, approved target, machine version, ring, exception owner/expiry where applicable, and a recommended upgrade path. It must not upgrade an Arc agent without approval.

### Arc Connected Machine agent lifecycle

Arc agent lifecycle is a dedicated proactive-management demonstration, using the lab's intentionally outdated agents as realistic test cases. It shows that a healthy Azure Arc connection alone is not sufficient: the management-plane agent must also remain supported, current enough for the assigned rollout ring, and safely upgradeable.

| Lifecycle stage | SRE Agent behavior |
| --- | --- |
| Discover | Inventory each `Microsoft.HybridCompute/machines` agent version, OS, connection status, and last status change. |
| Compare | Compare every version with the documented current release, approved standard target, and minimum supported release. |
| Classify | Mark the result as current, approved lag, aging, out of support, or time-bound exception. |
| Prioritize | Elevate unsupported agents, vulnerable versions, and agents that block an Azure Arc capability; distinguish them from intentional Current-1 lag. |
| Plan | Produce a canary-to-standard upgrade sequence that respects patch rings, maintenance windows, owner, and rollback considerations. |
| Govern | Propose an upgrade only in Review mode. A human approves each change; the agent then validates reconnection and telemetry after upgrade. |

Use representative out-of-support and aging test machines to prove version classification and a proposed phased upgrade plan before any agent update is approved.

## Deployment inputs

| Item | Value |
| --- | --- |
| Azure subscription | `<subscription-name>` |
| Subscription ID | `<subscription-id>` |
| Primary resource group | `<monitoring-resource-group>` |
| Primary Log Analytics workspace | `<log-analytics-workspace>` |
| Workspace ID | `<workspace-id>` |
| Patch management | Azure Update Manager |
| Existing change tracking | Change Tracking extensions reporting to `<log-analytics-workspace>` |

See [docs/environment.md](docs/environment.md) for the tracked environment baseline and [docs/deployment-history.md](docs/deployment-history.md) for the initial telemetry rollout.
See [docs/deploy-azure-sre-agent.md](docs/deploy-azure-sre-agent.md) for the first agent deployment and least-privilege configuration.
See [docs/customer-demo-catalog.md](docs/customer-demo-catalog.md) for customer-aligned demonstrations across Platform Health, Proactive Lifecycle Management, New Capability and Increased Maturity, and Platform Management Evolution.
Track build status in [docs/demo-checklist.md](docs/demo-checklist.md). See [docs/arc-agent-lifecycle.md](docs/arc-agent-lifecycle.md) for the version policy, exceptions, and safe upgrade-demo sequence.
See [docs/arc-extension-lifecycle.md](docs/arc-extension-lifecycle.md) for separate extension inventory and automatic-upgrade policy.
See [docs/ama-no-telemetry-runbook.md](docs/ama-no-telemetry-runbook.md) for diagnosis when AMA and its DCR are healthy in Azure but data is absent from `<log-analytics-workspace>`.
See [docs/on-prem-operations-scenarios.md](docs/on-prem-operations-scenarios.md) for cluster-aware maintenance and other on-premises reliability scenarios.
See [docs/third-party-software-inventory.md](docs/third-party-software-inventory.md) for software inventory scope, SRE Agent prompt, and collection boundaries.
See [docs/third-party-software-live-report.md](docs/third-party-software-live-report.md) for the reusable software-lifecycle Live Report prompt and version-baseline process.
See [docs/software-live-report-template.md](docs/software-live-report-template.md) for a sanitized pattern that can be reused in another SRE Agent environment.
See [docs/software-remediation-staging.md](docs/software-remediation-staging.md) for the approval-gated package-staging and notification workflow.
See [docs/arc-vm-applications-deployment.md](docs/arc-vm-applications-deployment.md) for the preferred Azure Arc VM Applications deployment path.
See [docs/7zip-vm-application-canary.md](docs/7zip-vm-application-canary.md) for the one-machine, approval-gated 7-Zip canary assessment and deployment.

## Azure SRE Agent setup

Deploy `<sre-agent-name>` in `<sre-agent-resource-group>`. Give it a Log Analytics connector for `<log-analytics-workspace>` and read access to the intended Arc scope.

After creating the `Arc Fleet Operations` Live Report, record its generated ID outside this public repository. The live report refreshes through its approved Azure resource and Log Analytics tools; downloaded HTML is a portable point-in-time artifact and should be reviewed for environment identifiers before sharing.

Use `Arc Fleet Operations` for the canonical report. For deployment validation, create a separate report named `Arc Fleet Operations - DEV - <deployment-id>` or `Arc Fleet Operations - TEST - <deployment-id>` so each run is distinguishable and does not overwrite the canonical report.

The following providers were registered before deployment:

```powershell
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.CloudHealth
```

The agent must stay in **Review** mode with no privileged/remediation tools during the initial demonstration period.

### Initial fleet-health prompt

Use this prompt in a new SRE Agent chat:

```text
Act as the read-only SRE for my Azure Arc lab. Review Azure Arc machines across this
subscription and correlate their Azure resource state with <log-analytics-workspace> telemetry from the last
24 hours.

Report:
- Connected, disconnected, and stale-heartbeat machines
- Machines with disk free space under 15%, sustained CPU or memory pressure, or uptime over
  30 days
- Recent Windows Application/System critical or error events and Linux warning-or-higher syslog
- Azure Update Manager patch assessment findings, including missing critical/security updates
  and reboot-required state
- Azure Arc Connected Machine agent-version drift against the current production release

Treat <planned-offline-linux-machine> and <planned-offline-windows-machine> as planned offline unless I say otherwise. Separate expected
conditions from actionable risk. Rank findings by severity, cite evidence and timestamps,
explain likely cause, and recommend a safe next action.

Do not modify resources, deploy patches, restart machines, or upgrade agents.
```

### Proactive lifecycle prompt

Use this prompt for the lifecycle demonstration:

```text
Review the Azure Arc fleet for proactive lifecycle risk over the next 90 days. Use machine
tags, Azure Update Manager, Arc Connected Machine agent versions, Azure Policy compliance,
<log-analytics-workspace> telemetry, and Change Tracking.

Identify unsupported or soon-to-be unsupported Windows/Linux versions; Arc Connected Machine
agents outside their approved rollout ring; missing critical/security updates; stale patch
assessments; reboot debt; approaching disk or memory capacity thresholds; required baseline
configuration drift; and certificate or management-plane issues.

For Arc agent lifecycle, classify each machine as current, approved one-version lag, aging, out
of support, or documented exception. Create a canary-to-standard upgrade recommendation for
outdated agents, respecting PatchRing, ArcAgentRing, MaintenanceWindow, and documented
exceptions. Group findings into 30, 60, and 90 day actions. Do not make changes.
```

### Live Report prompt

Use this prompt to create the reusable dashboard:

```text
Create a Live Report named "Arc Fleet Operations" for my Azure Arc lab.

Use the connected Azure subscription and <log-analytics-workspace> workspace. Build a deterministic
operations dashboard that refreshes its data each time it opens. Include fleet inventory,
telemetry coverage, patch posture, resource pressure, operational failures, Arc Connected
Machine agent versions, recent Change Tracking changes, and a ranked evidence-cited priority
action list.

Treat <planned-offline-linux-machine> and <planned-offline-windows-machine> as planned offline unless I say otherwise. Use read-only
tools only. Do not modify resources, restart machines, deploy patches, or upgrade agents.
```

### Extension lifecycle prompt addition

The original SRE Agent health and Live Report prompts do not explicitly require extension lifecycle analysis. Add the following text to the Live Report or daily-task instructions:

```text
Include Arc extension lifecycle posture. Report extension provisioning failures, foundational
extensions where automatic upgrade is disabled, review-only extensions with automatic upgrade
enabled, and extensions with verified handler versions below the approved baseline. Do not call
a handler version out of date unless a publisher-verified approved version is available. Report
unknown-version currency as "needs review," not "out of date." Do not modify extensions.
```

## What is deployed

The `infra/dcr` definitions are read-only. They do not patch, restart, configure, or otherwise modify managed machines.

- Windows: CPU, available memory, logical-disk free space, system uptime, and critical/error Windows events.
- Linux: CPU, available memory, logical-disk free space, and warning-or-higher syslog.
- Existing Change Tracking remains independent and continues to collect inventory, services, software, and configuration changes.

## Deploy or reconcile telemetry

Run PowerShell from this repository after authenticating with Azure CLI:

```powershell
.\scripts\Deploy-SreTelemetry.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DcrResourceGroup "<monitoring-resource-group>" `
  -WorkspaceResourceId "/subscriptions/<subscription-id>/resourceGroups/<workspace-resource-group>/providers/Microsoft.OperationalInsights/workspaces/<log-analytics-workspace>"
```

The script creates or updates the two DCRs and associates the applicable rule with each currently connected Arc machine. It intentionally skips disconnected hosts; run it again after a host reconnects.

## Validate ingestion

Use the query in [queries/telemetry-ingestion.kql](queries/telemetry-ingestion.kql) in the `<log-analytics-workspace>` workspace. New associations can take several minutes to begin flowing.

## SRE agent boundary

Deploy Azure SRE Agent as the primary demo surface. Connect it to the selected Azure resources, Azure Monitor, and Log Analytics using managed identity and RBAC. Start with scheduled tasks, incident investigation, and Live Reports; add custom skills or tools only where product-native capabilities do not cover the scenario.

Keep the agent read-only and in **Review** mode initially. Do not grant arbitrary Log Analytics query execution or direct remediation permissions. Any restart, patch deployment, Arc agent upgrade, or Run Command action must be separately approval-gated.

## Next steps

1. Create or verify the `Arc Fleet Operations` Live Report and validate each section against the initial fleet-health investigation. Use the documented DEV or TEST suffix for deployment-validation reports.
2. Create the first scheduled task: `Arc Fleet Daily Health`, retaining results in the agent portal during the validation period.
3. Add the approved Arc agent version baseline, deployment rings, support horizon, and exception registry to this repository.
4. Add an Azure Monitor health model and alert that opens a read-only agent investigation for fleet degradation.
5. Use the out-of-date lab agents to validate a canary-to-standard Arc agent upgrade recommendation without making changes.
6. After two to four weeks of useful findings, add a single approval-gated remediation workflow such as a patch assessment or Arc agent upgrade.
