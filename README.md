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

## First deployment in a new tenant

The historical lab evidence and completed checklist entries in this repository
are not proof that a new environment is ready. Use this order:

1. **Confirm Azure scope in both places.** Check the Azure CLI tenant and
   subscription, then separately check the directory and subscription selected
   in the SRE browser. Switching the CLI does not switch the browser.
2. **Prepare a pilot and telemetry workspace.** Select explicitly approved Arc
   machines and a Log Analytics workspace for their data. The workspace created
   for the SRE Agent's Application Insights is not automatically the Arc
   telemetry destination.
3. **Enable collection before interpreting reports.** Install AMA, associate
   the operational telemetry DCR, and enable Change Tracking & Inventory with
   its own DCR. The [clean-workspace inventory steps](docs/third-party-software-inventory.md#first-time-setup-in-a-new-workspace)
   cover prerequisites and ingestion checks. The telemetry script alone does
   not install these extensions or enable inventory.
4. **Create and configure the agent.** Follow the
   [agent deployment guide](docs/deploy-azure-sre-agent.md). Keep Review mode and
   inspect the actual RBAC assignments rather than assuming the wizard granted
   read-only access.
5. **Connect GitHub for repository-based installation.** Use the agent's
   **Code** setup card or **Builder > Code Access > GitHub**. VS Code's GitHub
   sign-in is separate. In the tested VS Code integrated-browser setup, PAT was
   the usable authentication option; see the
   [GitHub/PAT guidance](docs/deploy-azure-sre-agent.md#connect-this-repository-to-the-agent).
   Attaching report bundles directly is an alternative that needs no repository
   connection.
6. **Prepare and save the three reports.** Start with the no-snapshot software
   tracker, Fleet Operations, and Priority & Lifecycle. Follow the
   [bundle guide](livereports/README.md), replace all demo evidence, and approve
   only the read-only Log Analytics query tool.
7. **Validate separately from deployment.** A saved report or successful
   extension does not prove live ingestion. Reopen and reload each report,
   check machine counts and freshness, and label validation pending if the
   initial inventory has not arrived.

**Pilot scope warning:** the current
[`Deploy-SreTelemetry.ps1`](scripts/Deploy-SreTelemetry.ps1) associates DCRs with
**all connected Arc machines in the selected subscription**. It has no
machine/resource-group targeting or `-WhatIf` mode. Do not use it for a
single-machine pilot in a shared subscription; use explicitly scoped DCR
associations instead.

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

## Applications and install/uninstall commands

The deployment catalog currently covers **7-Zip** (`7zipexe`) and **Google
Chrome Enterprise x64 MSI** (`chromewin`). Chrome is an application in this
demo, not just an inventory item. Its successful pilot verified vendor version
`155.0.8059.40`, mapped explicitly to Gallery version `155.0.8059`; this is
historical deployment evidence, not approval to deploy that version elsewhere.
The public Chrome catalog remains blocked until artifact and scope placeholders
are reviewed and resolved.

| Application | Deployment status | Install command | Uninstall command |
| --- | --- | --- | --- |
| Google Chrome Enterprise x64 MSI | Machine-wide MSI pilot verified; live removal and multi-user validation are not yet recorded as tested. | Approved MSI ZIP and pinned launcher; commands below. | Guarded MSI helper with the approved ProductCode and exact version; command below. |
| 7-Zip | Catalog-driven Canary target `26.03.0`; retained rollback assignment `0.0.4`. | Read the exact Gallery version's install action before deployment. The recorded fragment `ren 7z2603 7z2603.zip` needs filename validation; it is not a complete install recipe. | No verified complete remove command is recorded in this repository. Inspect and review the Gallery remove action before use. |
| Adobe Acrobat | Inventory/baseline assessment only. | Not recorded or approved. | Not recorded or approved. |
| Python | Inventory/baseline assessment only. | Not recorded or approved. | Not recorded or approved. |
| Oracle Java 8 | Inventory/baseline assessment only. | Not recorded or approved. | Not recorded or approved. |

Inventory coverage does not imply installation or removal support. Do not
substitute guessed silent switches, a different installer type, or a no-op
remove command. All changes require approval of the exact artifact and target.

### Chrome install and uninstall

Run as SYSTEM or an elevated administrator on supported x64 Windows. From the
approved package directory, the install helper accepts:

```powershell
.\Install-ChromeEnterpriseMsi.ps1 `
  -MsiPath ".\GoogleChromeStandaloneEnterprise64.msi" `
  -ExpectedVersion "<approved-four-part-chrome-version>" `
  -ExpectedSha256 "<approved-msi-sha256>" `
  -ExpectedSignerSubject "<exact-approved-authenticode-signer-subject>"
```

For the Gallery install/update action, package the helper, approved MSI, and a
reviewed pinned launcher named `Install-Chrome.ps1` together. The Windows
`cmd.exe` command is:

```text
tar.exe -xf chrome-enterprise-msi.zip && powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Install-Chrome.ps1
```

For removal, use the helper from the extracted approved package:

```powershell
.\Install-ChromeEnterpriseMsi.ps1 -Uninstall `
  -ProductCode "<approved-msi-product-code-in-braces>" `
  -ExpectedVersion "<approved-four-part-chrome-version>"
```

For a Gallery remove action, extract the ZIP first and invoke that helper with
`powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File`,
passing the same reviewed ProductCode and version.

The helper waits for these underlying MSI commands and verifies the result;
these are documented for reference, not a replacement for its hash, signer,
version, registration, and post-install/removal checks:

```text
msiexec.exe /i "<approved-msi>" /qn /norestart ALLUSERS=1 REBOOT=ReallySuppress /L*v "<local-log>"
msiexec.exe /x <approved-msi-product-code-in-braces> /qn /norestart REBOOT=ReallySuppress /L*v "<local-log>"
```

Neither operation automatically reboots. Exit code `3010` requires a separately
approved reboot and revalidation. Removal preserves browser profiles and is
recovery to an absent machine-wide installation, not a downgrade or verified
rollback. See the [Chrome MSI packaging and validation guide](docs/arc-vm-applications-deployment.md#chrome-enterprise-msi-machine-wide-deployment).

### Inspect the exact Gallery package commands

This read-only command retrieves the configured commands for either application.
Use `7zipexe` or `chromewin` and an explicitly approved three-part version:

```powershell
az sig gallery-application version show `
  --subscription "<subscription-id>" `
  --resource-group "<gallery-resource-group>" `
  --gallery-name "<gallery-name>" `
  --application-name "<gallery-application-name>" `
  --version-name "<approved-three-part-gallery-version>" `
  --query "publishingProfile.manageActions.{install:install,update:update,uninstall:remove}" `
  --output json
```

Review package filenames, installer type, exit-code handling, and actual removal
behavior before using the returned commands. A configured command is not proof
that it works. Assignment rollback and package uninstall are different operations;
see the [7-Zip canary preflight](docs/7zip-vm-application-canary.md#package-command-preflight).

## Deployment inputs

| Item | Value |
| --- | --- |
| Azure subscription | `<subscription-name>` |
| Subscription ID | `<subscription-id>` |
| Primary resource group | `<monitoring-resource-group>` |
| Primary Log Analytics workspace | `<log-analytics-workspace>` |
| Log Analytics Workspace ID (customer ID) | `<workspace-id>` |
| Patch management | Azure Update Manager |
| Change Tracking & Inventory | Existing or newly enabled extensions and inventory DCR reporting to `<log-analytics-workspace>`; verify fresh `ConfigurationData` |

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
  --subscription "<subscription-id>" `
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
  --subscription "<subscription-id>" `
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
See [livereports/README.md](livereports/README.md) for the current Live Report bundles, installation options, editable tracker source, and validation steps.
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
The MSI helper also supports `-Uninstall -ProductCode "<approved-guid-in-braces>"
-ExpectedVersion "<approved-four-part-version>"`. It verifies the exact
registration before removal and checks absence afterward, without deleting user
profiles or inventory. This is recovery to an absent installation, not a
Chrome downgrade; pilot-test removal before calling recovery verified.
Keep a candidate returned by a rolling vendor download excluded from Gallery
latest-version selection, and approve its exact version before assignment.

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
.\tests\Test-ArcVmApplicationStorageRole.ps1
```

#### Direct CLI assignment of a staged MSI version

Once the reviewed MSI ZIP is staged in private blob storage and its Gallery
version has finished replication, **assign that version to the pilot**. Do not
download a rolling MSI on the machine, republish the failed EXE version, or
uninstall Chrome just to reset inventory.

The successful pilot used Chrome Enterprise MSI **155.0.8059.40**, explicitly
mapped to Gallery version **155.0.8059**. These are deployment evidence, not a
default approval policy or a promise that Google's current download still
contains that version. The public Chrome catalog remains blocked until you
approve your own artifact and deployment scope.

The CLI used for the pilot did not expose an
`az connectedmachine application add` command. The working alternative is
**`az rest --method put`** against the Arc machine's application resource. This
creates or updates that one assignment; it does not upload the MSI or create
the Gallery version. The ZIP, pinned launcher, and Gallery install/update
commands must already be configured as described in the
[MSI packaging instructions](docs/arc-vm-applications-deployment.md#chrome-enterprise-msi-machine-wide-deployment).

After approving the exact machine, version, target-region replication, and
recovery plan, replace the placeholders and run this PowerShell example:

```powershell
$ErrorActionPreference = "Stop"
$subscriptionId = "<subscription-id>"
$machineResourceGroup = "<arc-machine-resource-group>"
$machineName = "<pilot-machine>"
$galleryResourceGroup = "<gallery-resource-group>"
$galleryName = "<gallery-name>"
$applicationName = "chromewin"
$galleryVersion = "<approved-three-part-gallery-version>"
$targetRegion = "<target-region>"

$machineId = "/subscriptions/$subscriptionId/resourceGroups/$machineResourceGroup/providers/Microsoft.HybridCompute/machines/$machineName"
$versionId = "/subscriptions/$subscriptionId/resourceGroups/$galleryResourceGroup/providers/Microsoft.Compute/galleries/$galleryName/applications/$applicationName/versions/$galleryVersion"
$assignmentUri = "https://management.azure.com$machineId/applications/$applicationName`?api-version=2026-02-01-preview"

$machine = az rest --subscription $subscriptionId --method get `
    --url "https://management.azure.com$machineId`?api-version=2024-07-10" `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Unable to read the pilot machine." }
if ($machine.properties.status -ne "Connected" -or $machine.location -ne $targetRegion) {
    throw "Pilot must be Connected in the approved target region."
}

$version = az rest --subscription $subscriptionId --method get `
    --url "https://management.azure.com$versionId`?api-version=2024-03-03" `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Unable to read the approved Gallery version." }
if ($version.properties.provisioningState -ne "Succeeded") {
    throw "Gallery version is not ready."
}

$body = @{
    location = $targetRegion
    properties = @{
        packageReferenceId = $versionId
        order = 0
        treatFailureAsDeploymentFailure = $true
    }
} | ConvertTo-Json -Depth 5

$bodyPath = Join-Path $env:TEMP ("arc-msi-assignment-" + [guid]::NewGuid().ToString("N") + ".json")
[IO.File]::WriteAllText($bodyPath, $body)
try {
    az rest --subscription $subscriptionId --method put `
        --url $assignmentUri --body "@$bodyPath" --output none
    if ($LASTEXITCODE -ne 0) { throw "Arc application assignment failed." }
}
finally {
    Remove-Item -LiteralPath $bodyPath -Force
}

az rest --subscription $subscriptionId --method get --url $assignmentUri --output json
if ($LASTEXITCODE -ne 0) { throw "Unable to read assignment status." }
```

The JSON file avoids Windows command-line quoting problems with inline bodies.
The PUT is asynchronous: `Updating` is not installation success. Wait for the
assignment to reach `Succeeded`, then independently verify the expected
Program Files `chrome.exe` version, HKLM MSI ProductCode/version, and a
successful MSI log under `%ProgramData%\SrePackageDeployment\Logs`. The pilot
verified all three, including MSI return code `0`; the operator subsequently
confirmed it worked. Interactive multi-user validation and live uninstall
recovery are separate checks.

This direct path does **not** run the wrapper's catalog, identity/RBAC, or
rollback checks. Review existing assignments and the genuine recovery action
before approving the write. Only the named application on the named machine
is changed; it is not a fleet rollout. Keep the version excluded from Gallery
latest-version selection until broader rollout is approved.

**Resource Graph subscription/tenant context:** an `AccessDenied` response can
come from authenticating to a different tenant than the requested query scope.
The pilot needed no new RBAC grants; this scoped command worked:

```powershell
az graph query --subscription $subscriptionId --subscriptions $subscriptionId `
    -q resources --first 1 --output json
```

`--subscription` selects the authentication context; `--subscriptions` selects
the query scope. The wrappers currently use the active CLI context, so confirm
it matches the deployment subscription before using them. Do not grant broad
Reader/Owner access just to work around a context mismatch.

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

#### Set the SRE Agent default mode to Autonomous

The default is stored in Azure on the `Microsoft.App/agents` resource as
`properties.actionConfiguration.mode`; it is not a repository configuration
file or a subscription-wide setting. Changing it does not change Azure RBAC,
the action access level, or tool access policies. A task or response plan with
an explicit mode can override this fallback. To change a specific task or
response plan, edit its **Agent autonomy level** in the SRE Agent UI.

**The command that saves the change is `az rest --method patch`**, shown in
the second PowerShell block below. Its JSON body sets the following property
(and also includes the existing action identity and access level to preserve
them):

```json
{
  "properties": {
    "actionConfiguration": {
      "mode": "Autonomous"
    }
  }
}
```

The first block sets `$mode = "Autonomous"` and reads the current action
configuration. In the second block, `$configuration.mode = $mode` sets
`properties.actionConfiguration.mode` to `Autonomous` in the PATCH body.
The final `az resource show --query` command only verifies the result; it
does not change the mode. Run both PowerShell blocks in the same session.

For a trusted nonproduction agent, use the following PowerShell procedure to
change the default to `Autonomous`. Set the destination explicitly and confirm
the agent before applying the change:

```powershell
$subscriptionId = "<subscription-id>"
$resourceGroup = "<sre-agent-resource-group>"
$agentName = "<sre-agent-name>"
$mode = "Autonomous" # Use "Review" to restore approval pauses.
$agentId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.App/agents/$agentName"
$apiVersion = "2026-01-01"

az account show --subscription $subscriptionId `
  --query "{subscription:name,subscriptionId:id,tenantId:tenantId}" --output json
if ($LASTEXITCODE -ne 0) { throw "Unable to verify the subscription." }

$configurationJson = az resource show --ids $agentId --api-version $apiVersion `
  --query properties.actionConfiguration --output json
if ($LASTEXITCODE -ne 0) { throw "Unable to read the agent configuration." }
$configuration = $configurationJson | ConvertFrom-Json
if ($null -eq $configuration) { throw "The agent has no action configuration." }
$configuration | Format-List
```

After confirming the destination and existing configuration, apply a narrow
PATCH that preserves the current action identity and access level:

```powershell
$configuration.mode = $mode
$patch = @{
  properties = @{
    actionConfiguration = $configuration
  }
} | ConvertTo-Json -Depth 10
$patchFile = [System.IO.Path]::GetTempFileName()
try {
  [System.IO.File]::WriteAllText($patchFile, $patch)
  az rest --method patch `
    --url "https://management.azure.com$agentId`?api-version=$apiVersion" `
    --body "@$patchFile" --output none
  if ($LASTEXITCODE -ne 0) { throw "Unable to update the agent run mode." }
}
finally {
  Remove-Item -LiteralPath $patchFile
}

az resource show --ids $agentId --api-version $apiVersion `
  --query "{name:name,mode:properties.actionConfiguration.mode,accessLevel:properties.actionConfiguration.accessLevel,provisioningState:properties.provisioningState,runningState:properties.runningState}" `
  --output json
if ($LASTEXITCODE -ne 0) { throw "Unable to verify the agent run mode." }
```

Verify that `mode` matches the requested value, `provisioningState` reaches
`Succeeded`, and `runningState` is `Running`. If provisioning is still
`InProgress`, repeat the final read until it completes; a successful PATCH
request alone does not prove provisioning finished. To roll back, set `$mode`
to `Review` and repeat the procedure, reading the current configuration again.

Use this targeted PATCH rather than `az resource update --set` for this
change. In the tested deployment, the generic update resubmitted an
Application Insights configuration whose connection string was not returned
by the read API, causing `InvalidApplicationInsightsConfiguration` ("The
AppId and ConnectionString fields must be provided together"). The narrow
PATCH avoids resubmitting unrelated settings.

## Azure SRE Agent setup

Deploy `<sre-agent-name>` in `<sre-agent-resource-group>`. Give it a Log Analytics connector for `<log-analytics-workspace>` and read access to the intended Arc scope.
See the [first-time setup and GitHub connection instructions](docs/deploy-azure-sre-agent.md)
before attempting repository-based report installation.

### Live Reports

[livereports/](livereports/) is the source of truth for report definitions and
deployment. Its [deployment guide](livereports/README.md) covers installation,
updates, export, sanitization, and troubleshooting. The portable
`*.livereport.json` bundles carry saved HTML, CSS, JavaScript, tool permissions,
and integrity metadata; they are not the portal's static **Download HTML** exports.

| Bundle | Purpose |
| --- | --- |
| [Arc Fleet Operations](livereports/reports/arc-fleet-operations-cleaned.livereport.json) | Fleet inventory, telemetry coverage, resource pressure, failures, agent versions, and priority actions. |
| [Arc Priority & Lifecycle](livereports/reports/arc-priority-lifecycle-cleaned.livereport.json) | Priority queue, patch/maintenance readiness, lifecycle, performance, and reliability. |
| [Third-Party Software Update Tracker](livereports/reports/third-party-software-update-tracker-cleaned.livereport.json) | Windows application versions compared with a dated vendor-latest reference; no embedded inventory. Recommended for new environments. |

Prerequisites: Python 3.8+ for the bundle tool, report-authoring access on the
target SRE Agent, and **Log Analytics Reader** for its identity on the workspace.
All bundles allow only `system-mcp-monitor_monitor_workspace_log_query`.
Fleet/priority reports also need Reader access to the intended Arc resources
for current Azure Resource Graph inventory.
Fleet reports need Heartbeat, Perf, and Event; the tracker needs Change Tracking
`ConfigurationData`. Check inventory coverage with the
[coverage query](livereports/templates/third-party-software-tracker/queries/inventory-coverage.kql).
For a new workspace, complete
[Change Tracking & Inventory setup](docs/third-party-software-inventory.md#first-time-setup-in-a-new-workspace)
first. Reports may be saved while ingestion is pending, but should not be
described as live-validated until their queries return the expected data.

Choose an installation path:

1. **In chat:** attach
   [live_report_bundle.py](livereports/live_report_bundle.py) and the selected
   bundle to the target SRE Agent. Follow the deployment guide's `prepare`
   prompt with your subscription, workspace customer ID, and workspace resource
   group. Ask the agent to call **SaveReport** from the generated install plan
   without editing or regenerating the HTML.
2. **From a workstation:** connect this repository to the target agent, then use
   the tool's `install` command. For this repository, use
   `--repo-path codeRefs/<repo>/livereports/reports` and
   `--script-path codeRefs/<repo>/livereports/live_report_bundle.py`.
   Start with `--dry-run`; Azure CLI authentication is required. The command
   uses the chat API, not a direct report-import REST endpoint.
3. **Prepare locally:** from the repository root, run:

   ```powershell
   py -3 .\livereports\live_report_bundle.py prepare `
     .\livereports\reports\third-party-software-update-tracker-cleaned.livereport.json `
     --set "subscription=<subscription-id>" `
     --set "workspace=<workspace-customer-id>" `
     --set "resourceGroup=<workspace-resource-group>" `
     --drop-suffix " - Cleaned" --name-prefix "Test - " `
     --out-dir .\Temp\livereport-install
   ```

   Attach the generated HTML and use the name, description, and allowed tools
   from the generated install plan. Keep all prepared files and report IDs
   outside source control.

Review and approve the tool-access prompt for each report. Open it from
**Live Reports**, then select **Reload** to verify live data. For trackers,
require **Data: LIVE**; **UNAVAILABLE** is not successful live access.
Use `--report-id <existing-id>` for an intentional new version, rather than
creating duplicates or overwriting another environment's report.

**Reports rebuild from current infrastructure, with no demo fleet fallback.**
Fleet and priority bundles discover accessible Arc resources in the selected
subscription on every open/reload and filter telemetry to those exact ARM
resource IDs. They no longer contain pseudonymized machine lists, saved
maintenance failures, demonstration findings or planned-offline exceptions.
Missing evidence is unavailable/not assessed, not compliant. Read the
[scope and coverage limits](livereports/README.md#current-infrastructure-rebuilds-and-coverage-limits)
before operational use.

**Existing installed reports must be updated.** A repository update or browser
reload cannot replace an old saved report's embedded data. Follow the
[replacement procedure](livereports/README.md#replace-an-older-report-that-displays-unfamiliar-demo-machines)
to save a new version of the existing report ID, then verify the current
version against the intended subscription. The optional demo-snapshot tracker
bundle was removed; replace it with the no-snapshot tracker.

The tracker is read-only, not a software installer. Its dated vendor-latest
reference is separate from the approved ring targets in
[third-party-software-baseline.json](config/third-party-software-baseline.json);
review the [editable template guide](livereports/templates/third-party-software-tracker/README.md)
before updating references or treating findings as an approved change.

Validate bundles and tracker logic without Azure:

```powershell
py -3 .\livereports\live_report_bundle.py verify ".\livereports\reports\*.livereport.json"
node .\livereports\templates\third-party-software-tracker\tests\run-tests.js
```

The root [validation workflow](.github/workflows/validate-live-reports.yml)
also checks that public bundles retain placeholders and contain no real GUIDs.

The following providers were registered before deployment:

```powershell
az provider register --subscription "<subscription-id>" --namespace Microsoft.App
az provider register --subscription "<subscription-id>" --namespace Microsoft.CloudHealth
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

### Extension lifecycle prompt addition

For an extension lifecycle assessment, add the following text to the daily-task
instructions or use it when intentionally extending an installed report:

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
- Change Tracking remains independent. Existing collection continues unchanged;
  a new environment must enable it separately for software inventory and any
  other approved change categories.

## Deploy or reconcile telemetry

Run PowerShell from this repository after authenticating with Azure CLI.
**This command targets every connected Arc machine in the subscription**, not
just a pilot or the DCR's resource group. It changes the default CLI
subscription, creates/updates the two operational DCRs, and associates them;
it does not install AMA or Change Tracking. Review and approve that scope first.
There is no built-in `-WhatIf` or machine filter.

```powershell
.\scripts\Deploy-SreTelemetry.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DcrResourceGroup "<monitoring-resource-group>" `
  -WorkspaceResourceId "/subscriptions/<subscription-id>/resourceGroups/<workspace-resource-group>/providers/Microsoft.OperationalInsights/workspaces/<log-analytics-workspace>"
```

The script intentionally skips disconnected hosts; run it again after a host
reconnects only if the same subscription-wide scope remains approved. For a
pilot, add the applicable DCR association to each explicitly selected Arc
resource through Azure Monitor instead of running this bulk script.

## Validate ingestion

Use the query in [queries/telemetry-ingestion.kql](queries/telemetry-ingestion.kql) in the `<log-analytics-workspace>` workspace. New associations can take several minutes to begin flowing.

## SRE agent boundary

Deploy Azure SRE Agent as the primary demo surface. Connect it to the selected Azure resources, Azure Monitor, and Log Analytics using managed identity and RBAC. Start with scheduled tasks, incident investigation, and Live Reports; add custom skills or tools only where product-native capabilities do not cover the scenario.

Keep the agent read-only and in **Review** mode initially. Do not grant arbitrary Log Analytics query execution or direct remediation permissions. Any restart, patch deployment, Arc agent upgrade, or Run Command action must be separately approval-gated.

## Next steps

1. Install or update the required [Live Report bundles](livereports/README.md), bind the intended subscription/workspace, and validate the rebuilt current inventory and each section against its source data. Use `--name-prefix "Test - "` for deployment-validation reports.
2. Create the first scheduled task: `Arc Fleet Daily Health`, retaining results in the agent portal during the validation period.
3. Add the approved Arc agent version baseline, deployment rings, support horizon, and exception registry to this repository.
4. Add an Azure Monitor health model and alert that opens a read-only agent investigation for fleet degradation.
5. Use the out-of-date lab agents to validate a canary-to-standard Arc agent upgrade recommendation without making changes.
6. After two to four weeks of useful findings, add a single approval-gated remediation workflow such as a patch assessment or Arc agent upgrade.
