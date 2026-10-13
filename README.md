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
| Log Analytics Workspace ID (customer ID) | `<workspace-id>` |
| Patch management | Azure Update Manager |
| Existing change tracking | Change Tracking extensions reporting to `<log-analytics-workspace>` |

### Finding the Log Analytics Workspace ID

`<workspace-id>` is the Log Analytics **Workspace ID**, also returned by Azure
as the workspace `customerId`. It is a GUID that identifies the Log Analytics
data workspace to agents, ingestion endpoints, and connectivity tests.

It is not any of the following:

- The Azure subscription ID.
- The Microsoft Entra tenant ID.
- The full Azure resource ID beginning with `/subscriptions/...`.
- A workspace primary or secondary shared key.

To find it in the Azure portal:

1. Open **Azure portal** > **Log Analytics workspaces**.
2. Select the workspace named in `<log-analytics-workspace>`.
3. On **Overview**, copy **Workspace ID** from the workspace details.
4. If it is not displayed on Overview, open **Settings** > **Agents** and copy
   the Workspace ID shown with the agent connection information.

To retrieve it with Azure CLI:

```powershell
az monitor log-analytics workspace show `
  --resource-group "<workspace-resource-group>" `
  --workspace-name "<log-analytics-workspace>" `
  --query customerId `
  --output tsv
```

To retrieve it with Azure PowerShell:

```powershell
(Get-AzOperationalInsightsWorkspace `
  -ResourceGroupName "<workspace-resource-group>" `
  -Name "<log-analytics-workspace>").CustomerId.Guid
```

Some deployment steps instead require the workspace's full Azure resource ID.
Retrieve that separately:

```powershell
az monitor log-analytics workspace show `
  --resource-group "<workspace-resource-group>" `
  --workspace-name "<log-analytics-workspace>" `
  --query id `
  --output tsv
```

Use the `customerId` result wherever this repository says `<workspace-id>`.
Use the `id` result for parameters such as `WorkspaceResourceId`. The Workspace
ID is an identifier rather than a credential, but workspace shared keys are
secrets and must never be committed to this repository.

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

### VM Application package storage networking

The default packaging flow assumes that Azure Compute Gallery can reach the
package storage account through its public network endpoint. **Public network
access does not mean anonymous blob access.** Keep anonymous container and blob
access disabled. The recommended authentication model is a user-assigned
managed identity attached to the Compute Gallery with **Storage Blob Data
Contributor** on the package storage account. Microsoft currently documents
Contributor—not Storage Blob Data Reader—for publishing VM Applications with a
managed identity. Do not place account keys or SAS tokens in SRE Agent skills,
catalogs, prompts, or deployment output.

An existing approved storage account can be reused instead of creating a
deployment-specific account. Choose and validate one of these network models
during package publication:

1. **Public network endpoint:** Allow the Compute Gallery to reach the storage
   endpoint, keep anonymous blob access disabled, and authenticate with the
   Gallery managed identity.
2. **Network-restricted storage:** Reuse an account restricted to approved
   virtual networks and authenticate the Gallery with its managed identity.
   Administrative or package-upload clients located on-premises can reach a
   Blob private endpoint through site-to-site VPN or ExpressRoute private
   peering. Configure routing and private DNS so the storage hostname resolves
   to the private endpoint from those clients.

Treat this as a packaging configuration choice, not an SRE Agent deployment
parameter. Verify package upload, Gallery publication, regional replication,
and canary installation before disabling an existing access path. See
[Publish VM applications using managed identity](https://learn.microsoft.com/azure/virtual-machines/vm-applications-publish-with-managed-identity)
and [Use private endpoints for Azure Storage](https://learn.microsoft.com/azure/storage/common/storage-private-endpoints).

### Discovery and deployment wrapper

Use `scripts/Start-ArcVmApplicationCanaryDeployment.ps1` as the operator and
SRE Agent entry point. It reads the reviewed deployment catalog and retrieves:

- The active subscription name and identifier.
- The pilot machine, connection state, resource group, and region.
- The Compute Gallery and its resource group and managed identity.
- The approved application, target version, rollback version, and deployment
  ring.
- The package source's existing storage account, subscription, and resource
  group, including storage hosted in another enabled subscription visible to
  the operator.
- The storage account's public-network and anonymous-blob-access settings.
- The Gallery managed identity's inherited and direct storage RBAC assignments.

The wrapper fails when a required value is missing, remains a placeholder, or
resolves ambiguously. It also fails when the Gallery has no user-assigned
managed identity or package storage permits anonymous blob access. It never
prints the package URL, SAS tokens, resource IDs, or storage credentials.
Normal deployment also fails when the Gallery identity lacks **Storage Blob
Data Contributor** on the package storage account.

Run a complete read-only preflight first:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "CHG-APP-CANARY-YYYYMMDD-NNN" `
  -WhatIf
```

After reviewing the resolved scope, run the same command without `-WhatIf`.
The wrapper passes only the catalog-approved values to the lower-level
assignment script. It discovers and validates existing storage for package
provenance; it does not create, modify, or delete the storage account.

If the preflight reports that the role is missing, review the target identity
and storage account, then explicitly approve the one-time RBAC setup:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "CHG-APP-CANARY-YYYYMMDD-NNN" `
  -AssignStorageBlobDataContributor `
  -WhatIf
```

Remove `-WhatIf` only after reviewing the proposed role assignment and
deployment. The switch creates the role at the storage-account scope; it does
not grant subscription-wide access. The calling identity must have permission
to create Azure role assignments. Subsequent deployments should omit the
switch because the wrapper will validate the existing assignment.

### Adding another catalog product

The wrapper is product-generic, but its default product is `7-Zip`. A Chrome
action must call it with a fixed product binding:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "CHG-CHROME-CANARY-YYYYMMDD-NNN" `
  -ProductName "Google Chrome" `
  -WhatIf
```

Do not expose `ProductName` as free-form SRE Agent input. Create a separate
Chrome action that accepts only `approvalId` and fixes `ProductName` to
`Google Chrome`.

The public catalog contains a blocked-by-default Chrome template. Before using
it, replace every Chrome placeholder with reviewed values. Keep these versions
separate:

- `vendorVersion`: the full four-part Chrome version, such as
  `Major.Minor.Build.Patch`.
- `galleryApplicationVersion`: a unique Azure Compute Gallery-compatible
  three-part version.

Do not truncate or increment Chrome versions automatically. Record and approve
the mapping so every Gallery version maps back to exactly one vendor artifact.
Also complete the immutable source, SHA-256, signer evidence, package file
name, install/remove commands, rollback version, target region, and pilot
machine before changing the staging status.

#### Chrome Enterprise MSI pilot

Use a **Chrome Enterprise standalone x64 MSI** for a machine-wide installation
on supported 64-bit Windows targets. The earlier EXE pilot started processes
but did not fully install Chrome; process launch or a successful Gallery
publication is not proof of installation.

Package the approved MSI with
[`Install-ChromeEnterpriseMsi.ps1`](scripts/Install-ChromeEnterpriseMsi.ps1)
and a reviewed, pinned copy of
[`Install-ChromeMsiPackage.example.ps1`](scripts/Install-ChromeMsiPackage.example.ps1).
The helper verifies the MSI SHA-256 and exact Authenticode signer, waits for
`msiexec`, writes a verbose log, and requires both machine-wide HKLM
registration and the expected Program Files executable version. It refuses
downgrades and treats reboot-required or unverifiable outcomes as incomplete,
not successful.

Reuse the existing `chromewin` Gallery application, but publish a **new**
three-part version for the MSI ZIP. Keep the failed EXE version intact for
investigation; do not treat it as a working rollback. A no-op remove command
such as `cmd /c exit 0` is not an uninstall or rollback implementation.

Assignments now use `treatFailureAsDeploymentFailure = true`. Complete the
blocked Chrome catalog entry, review the MSI ProductCode/removal behavior, and
validate the pilot with multiple non-administrator users before any broader
rollout. Existing per-user Chrome copies, browser profiles, and update policies
require separate review; the installer does not delete user data.

See the
[MSI packaging and validation steps](docs/arc-vm-applications-deployment.md#chrome-enterprise-msi-machine-wide-deployment).
Run the dependency-free mocked checks without installing Chrome:

```powershell
.\tests\Test-ChromeEnterpriseMsi.ps1
```

## Using `sre.azure.com`

This solution is intended to be operated through
[`sre.azure.com`](https://sre.azure.com) so that assessment, approvals,
packaging, deployment, and validation remain in one traceable thread. Keep the
agent in Review mode and attach only the read or narrowly scoped write tools
needed for the current step.

### What `sre.azure.com` is used for

Use `sre.azure.com` to:

- Assess Azure Arc machines before deployment.
- Verify Change Tracking and software-inventory coverage.
- Confirm the intended machine and rollout-ring scope.
- Prepare approved packages and publish VM Application artifacts when a
  separately reviewed packaging tool is attached.
- Request and review write actions before deployment.
- Validate assignment state, inventory evidence, and machine health after
  deployment.

### Prerequisites

Before using this workflow, confirm:

- The operator and agent connections are using the intended Azure scope.
- Target Arc machines are onboarded, connected, and visible.
- Required managed identities have least-privilege access to the Gallery and
  package storage.
- Azure Compute Gallery exists and is configured for VM Applications.
- Package storage is reachable by the Gallery publication flow.
- Change Tracking and software inventory are reporting for target machines.
- At least one noncritical pilot machine set is defined.
- Approved package versions, validation evidence, and rollback versions are
  recorded in the reviewed catalog.

### Recommended operator flow

1. Open [`sre.azure.com`](https://sre.azure.com).
2. Start a dedicated thread for the Arc VM Application change.
3. Ask the agent to assess the intended pilot machines before proposing a
   change.
4. Confirm inventory freshness, machine connectivity, region availability,
   and extension health.
5. Prepare the application artifact and publish it through the approved
   packaging process.
6. Create or update the Azure Compute Gallery VM Application version using a
   separately reviewed publishing action.
7. Review the proposed deployment scope, exact version, rollback version, and
   write action.
8. Approve deployment only for the intended pilot machines.
9. Verify assignment state, fresh inventory evidence, machine health, and the
   application-specific functional test in the same thread.

### Pilot-first approach

Do not start with the full fleet. Expand beyond the pilot only after:

- Package publication and Gallery version creation succeed.
- Gallery replication is complete in the target region.
- Pilot machines remain connected and healthy.
- Software inventory and a functional test confirm the expected result.
- Failure, rollback, and retest steps are understood and separately
  approval-gated.

### What is automated and what remains manual

The current solution automates or assists with:

- Arc machine and software-inventory assessment.
- Connectivity, extension, and deployment-readiness checks.
- Subscription, resource-group, Gallery, and package-storage discovery through
  the catalog-driven PowerShell wrapper.
- Exact-version deployment proposal generation.
- The narrowly scoped, approval-gated pilot assignment action.
- Post-deployment assignment and inventory validation.

Packaging, artifact upload, and Gallery application/version creation can be
automated only after separate least-privilege tools are implemented, reviewed,
and attached. They are not capabilities of the current deployment action.

Human review is always required for:

- Choosing and confirming deployment scope.
- Approving each write action.
- Confirming that package use and distribution are legally and operationally
  acceptable.
- Deciding whether to roll back, retry, or expand beyond the pilot.

### Known limitations

- Disconnected or powered-off Arc machines cannot be validated reliably.
- Software inventory can lag behind the actual installation state.
- Package-storage authentication, network rules, routing, or DNS can block
  publication.
- Gallery replication can delay regional availability.
- Vendor licensing or redistribution terms can restrict packaging.
- A reviewed action binding may cover only a subset of machines and must not be
  treated as fleet-wide authorization.

### Suggested prompt pattern

Start with a read-only assessment:

```text
Assess the approved pilot Arc machines for VM Application readiness.
Check connectivity, inventory freshness, extension health, current assignment,
target-version availability, and rollback readiness. Do not make any changes.
Return ReadyForHumanApproval, ManualReview, or NotReady for each machine with
the supporting evidence.
```

After reviewing the assessment, request a proposal rather than an immediate
deployment:

```text
Prepare the exact-version VM Application deployment proposal for only the
pilot machines classified ReadyForHumanApproval. Show the target and rollback
versions and the proposed write action, then wait for explicit approval.
Do not package, publish, deploy, retry, roll back, or expand the scope yet.
```

### Options for reducing approval pauses

Azure SRE Agent separates **resource permission** from **run mode**:

| Control | Options | Effect |
| --- | --- | --- |
| Managed-resource permission | `Reader`, `Privileged` | Determines what the agent is allowed to do. |
| Task or response-plan run mode | `Review`, `Autonomous` | Determines whether Azure infrastructure actions wait for approval. |

Changing only one control does not remove all pauses:

- `Privileged` plus `Review` lets the agent perform the action after an SRE
  Agent Administrator approves it.
- `Reader` plus `Autonomous` still cannot perform writes with its standing
  identity and can prompt for temporary on-behalf-of access.
- `Privileged` plus `Autonomous` can execute permitted actions without waiting
  for approval.

Use these operating patterns:

1. **Production deployment (recommended):** Keep the deployment action in
   Review mode with the smallest custom permission scope. This preserves the
   approval checkpoint.
2. **Autonomous assessment:** Run inventory, connectivity, and validation tasks
   autonomously with Reader access because they do not change resources.
3. **Trusted nonproduction deployment:** After repeated successful reviewed
   runs, use Autonomous mode only for a dedicated task or response plan whose
   action is fixed to the product, ring, and pilot resources.
4. **Split workflow:** Run packaging preflight and post-deployment validation
   autonomously, but keep package publication, RBAC changes, Gallery version
   creation, deployment, retry, and rollback in Review mode.

Do not grant broad subscription Contributor merely to avoid a pause. Prefer a
custom action and RBAC scope limited to the required Gallery application,
package storage operation, or selected VM Application assignments. Review mode
only gates Azure infrastructure operations; use
[Hooks](https://learn.microsoft.com/azure/sre-agent/agent-hooks) or
[Tool Access Policies](https://learn.microsoft.com/azure/sre-agent/tool-access-policies)
for governance over other tools and external actions.

See [Run modes in Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/run-modes)
and [Manage permissions for Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/manage-permissions).

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
