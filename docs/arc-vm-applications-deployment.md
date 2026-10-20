# Azure Arc VM Applications Deployment

## Decision

Use Azure Arc VM Applications as the deployment path:

```text
VS Code operator or CI publishes approved Azure Compute Gallery application versions
  -> SRE Agent assesses installed and assigned versions against an approved deployment ring
  -> SRE Agent confirms the selected Gallery version is available in the target region
  -> SRE Agent proposes an exact-version deployment
  -> human approves an exact machine and version
  -> VS Code operator or CI creates/updates the Arc VM Application assignment
  -> Azure Arc runs the application install command on the target machine
  -> SRE Agent verifies inventory, telemetry, and deployment state
```

Azure Compute Gallery VM Applications is the deployment, versioning, targeting,
and Azure Activity Log audit lane. External package locations are not exposed
to the SRE Agent.

## Customer-defined resource names

Customers choose their own Gallery and VM Application names, subject to Azure's
naming requirements. Names in historical lab examples are not deployment
requirements and must not be used to infer a customer's resources.

Configure `galleryName` and `galleryApplicationName` for each product in the
[deployment catalog](../config/arc-vm-application-deployment-catalog.json) after
discovering and confirming the intended application.
The software's `productName` is a separate catalog label; it need not match the
Gallery application name. Customers should be able to request "7zip" or "Chrome"
without supplying an ARM resource ID. Resolve exact IDs internally from Azure
discovery results for access checks and operator deployment commands. Explicitly
approve the target and rollback versions for the resolved application. Do not
rename existing resources or reuse a lab version mapping merely to match an
example.

### Discover applications from a product name

1. Start with the requested product name, the approved subscription/resource
   scope, any specified machine, and the customer's deployment catalog.
2. Discover Gallery applications using read-only Azure queries. Match the
   product label and application name case-insensitively, allowing punctuation
   differences such as `7zip` versus `7-Zip`. Names such as `7zipexe` or
   `chromewin` can be candidates, not required naming conventions. Where names
   are unrelated to the product, use a customer-approved catalog mapping rather
   than guessing from the name alone.
3. Use catalog mappings and the target machine's existing application assignment
   to establish the intended source. If multiple plausible candidates remain,
   show application, Gallery, resource group and region, then ask the customer
   which to use. Do not choose the first result or the highest version across
   unrelated applications. The customer selects a recognizable candidate, not
   a resource ID.
4. Resolve the selected application's exact ID from the returned resource,
   enumerate its versions, and check the approved ring target and replication.
   A unique name match is not package approval or authorization to deploy.
5. If nothing matches, report that result. If access is denied or discovery is
   incomplete, report that limitation rather than claiming the application
   does not exist or searching outside the approved scope.

Use Azure Resource Graph where available; if it does not return the application
resources, enumerate Galleries and their applications through the read-only
Compute Gallery APIs/CLI. Discovery requires Gallery/application reads at the
approved discovery scope; Reader on one known child application does not confer
parent Gallery enumeration. The
[catalog reader actions](../README.md#publishing-belongs-to-vs-code-or-ci)
cover discovery and version inspection without granting publishing writes.

The access helper still accepts exact resource IDs as an administrative safety
boundary. Pass the IDs resolved through discovery; this is not a requirement
for customers to paste IDs into normal SRE conversations. The deployment
wrapper resolves resources from configured catalog names; it does not itself
perform natural-language product matching.

## Version-selection policy

The SRE Agent must not equate "latest vendor release" with "approved target." The customer owns an explicit deployment catalog with one version per product and ring:

| Ring | Target behavior |
| --- | --- |
| Canary | A newly approved version, deployed first to selected noncritical machines. |
| Standard | The proven stable version; this can intentionally be one or more releases behind the vendor's newest release. |
| Legacy | A retained earlier version with a documented exception, compensating controls, review date, and owner. |

Each catalog record identifies the exact customer-selected Azure Compute
Gallery application version and supported regions. A Standard ring can remain
on an earlier approved version while a newer vendor release or Canary Gallery
version exists. The agent only recommends the catalog target for the machine's
ring.

## Assessment and deployment workflow

1. **Assess:** Resolve the requested product through the name-based discovery workflow above. Query Change Tracking inventory for installed software, Azure Resource Graph for Arc machines and existing VM Application assignments, and the approved deployment catalog.
2. **Select policy target:** Determine the machine's deployment ring and select the product's approved Gallery application version; never select the vendor's latest version automatically.
3. **Confirm availability:** Ensure the selected Gallery version is replicated to the Arc machine's Azure region and that the machine meets connectivity and Arc-agent prerequisites.
4. **Classify:** Mark each machine as `Compliant`, `UpgradeRecommended`, `NewInstallRecommended`, `AheadOfPolicyReview`, `ArtifactUnavailable`, or `ManualReview`.
5. **Propose:** For a valid recommendation, present product, installed version, assigned Gallery version, approved target version, machine/ring, maintenance window, and rollback Gallery version.
6. **Approve:** A human approves the exact machine and exact Gallery application version.
7. **Deploy:** The operator or CI creates or updates only the Arc VM Application assignment for that approved target. Read-only SRE does not perform this write.
8. **Verify:** Check application instance view, Azure Activity Log, Change Tracking inventory, and machine health before promoting the target version to the next ring.

If a machine already has a version newer than its ring target, do not downgrade it automatically. Mark it `AheadOfPolicyReview` and require an explicit compatibility or rollback decision.

## Why VM Applications is the preferred deployment path

- **Immutable version record:** Gallery application version.
- **Native deployment:** VM Application assignment on the Arc machine.
- **Upgrade control:** Update the assignment to a specific approved version.
- **Audit:** Azure Activity Log create/update operations.
- **Fleet inventory:** Azure Resource Graph.
- **Rollback:** Assign a retained prior Gallery application version.

## Important boundaries

- VM Applications on Arc is currently a preview feature. Use it only on noncritical lab machines until feature, support, and customer tenancy requirements are confirmed.
- Arc machine agent version must be 1.61 or newer.
- Each target must be connected, not expired, and able to reach the endpoints
  required by Azure Arc VM Applications.
- The gallery application version must be replicated to the Arc machine's Azure region.
- The package and install/uninstall commands belong to the Gallery application version. `application add` or `application update` assigns that prebuilt version to a machine.
- Do not use Run Command as the standard installer. Use it only for approved diagnostics, such as retrieving VM Application stdout/stderr after a failed deployment.
- Keep SRE read-only for the operator-owned workflow; do not grant publishing,
  machine assignment or guest Run Command writes. Autonomous mode does not
  confer those permissions. A separately approved agent-driven deployment pilot
  should use Review mode and a custom role limited to assignment/update on
  selected machines, not broad Contributor access.

Complete the [optional single-machine RBAC task](../README.md#optional-task-authorize-a-single-machine-application-pilot)
for read-only assessment or a separately approved agent-driven pilot. The
audit-first helper resolves the
configured action identity rather than assuming the system-assigned identity.
It defaults to read-only assessment access, reuses sufficient grants or creates
a narrow reader role on the selected machine, and assigns Gallery application
Reader only if missing. Machine assignment writes require a separate explicit
`-AccessMode Deployment` exception; do not enable it for strictly read-only SRE.
It also checks read access to the source resource group's own metadata and,
if absent, grants only `Microsoft.Resources/subscriptions/resourceGroups/read`
through a resource-group-scoped custom role. An application-scoped Reader grant
does not extend upward to that group. Use the exact application's versions
endpoint for enumeration, not a whole-resource-group resource listing.
Run Command read/write requires both `-AccessMode Deployment` and the separate
`-IncludeGuestRunCommand` opt-in for approved diagnostics; granting it
permits arbitrary guest commands, not just software-version reads. A role shown
in IAM is not proof that a previous 403 has cleared. Compare the actual denied
caller/action/scope, check propagation and denies, and verify from the agent.

### Operator-owned publishing

Publish approved packages from VS Code or CI with a separate operator/publisher
identity. The SRE identity needs Gallery catalog reads, not Gallery application
or version writes, for assessment. See the
[role separation and rollback guidance](../README.md#publishing-belongs-to-vs-code-or-ci).
Package-source access and integrity/replication checks belong to that reviewed
publishing process, not to SRE's standing role.

Use a new, explicitly approved version ID and stop if it already exists.
The ARM write permission also permits updates; it does not enforce immutability,
"only when asked", a maintenance window or an approval prompt in Autonomous mode.
Publication, package import/upload authorization and machine assignment are
separate operations. The SRE access helper grants no publishing permissions and does not publish or
deploy anything.

## Lab prerequisites

| Requirement | Current state or action |
| --- | --- |
| Feature enrollment | Confirm the active Azure scope is enabled for Arc VM Applications preview. |
| Arc agent | Verify target machine is at least 1.61. `<canary-machine>` is already newer. |
| Gallery | Use the customer's chosen `<gallery-name>`, `<gallery-application-name>` and approved version. Verify publication and replication; for a wrapper-based upgrade, also verify the existing assignment matches the catalog's approved rollback version. Do not assume the historical lab assignment exists. |
| Network | Allow target Arc machines outbound HTTPS to the endpoints required by Azure Arc VM Applications. |
| Package source | Use an application version already published through the customer's approved packaging process. |
| Gallery replication | Publish/replicate the application version to each target Arc machine region, such as West Central US or Central US. |
| Target | Start with one noncritical, connected x64 Windows Arc machine. |
| Agent authorization | Complete the [audit, preview and apply commands](../README.md#optional-task-authorize-a-single-machine-application-pilot) for the configured action identity. Default to read-only machine/application metadata, source application/version reads, source group metadata read and managed-resource scope. Machine writes/Run Command are a separate deployment exception, not prerequisites for assessment. |

## First demo: 7-Zip 26.03

### Clean-tenant first-install boundary

The historical version numbers and rollback assignments below describe the
original lab, not prerequisites already present in a new tenant. The current
deployment wrappers require an existing assignment matching the catalog's
approved rollback version. They are **not** a bootstrap installer for a machine
with no application assignment.

Before a fresh pilot:

1. Confirm the CLI and SRE browser tenant/subscription independently.
2. Review existing software and Arc application assignments; do not overwrite
   a newer or unmanaged installation.
3. Approve exact vendor artifacts, hashes/signers, Gallery version mapping,
   install/remove behavior, target machine, and costs. Publishing a product
   does not authorize assigning it to the pilot.
4. Publish immutable versions and verify replication is actually complete in
   the pilot's region before assigning an exact version.
5. If there is no previous assignment, review the supported direct
   single-machine application-resource API path separately. Do not fabricate
   a rollback assignment or bypass the wrapper's check by changing its catalog.
   Removal to an absent installation is not rollback to a prior working version.
6. Verify guest runtime/version, machine-wide registration, package-specific
   functionality and health, in addition to assignment instance view. Change
   Tracking can arrive later; mark inventory verification pending until it does.

The repository does not yet provide a reusable Python packaging helper or a
general clean-tenant gallery bootstrap. A separately approved Python pilot is
not authorization to reuse its private package or tenant bindings elsewhere.
For inventory onboarding, use the
[new-workspace guide](third-party-software-inventory.md#first-time-setup-in-a-new-workspace).

### Historical canary workflow

Use the 7-Zip example as a separate VM Application deployment proof, not as an automatic follow-on from the existing staging runbook.

1. The third-party lifecycle report identifies 7-Zip version drift.
2. The deployment catalog selects the exact approved Gallery version for the target ring; it does not select the latest 7-Zip release.
3. SRE Agent verifies that target version is available in the canary machine's region.
4. SRE Agent proposes a canary application assignment; a human approves it.
5. Assign the Gallery version using the reviewed wrapper, or use `az rest --method put` against the single machine's application resource. Do not assume the installed CLI exposes `az connectedmachine application add`.
6. Verify the Arc application resource instance view, Azure Activity Log, Change Tracking inventory, and post-install health.
7. Retain the prior Gallery application version before any broader rollout.

The original lab used assignment version `0.0.3` and retained `0.0.4` as a
rollback assignment. These historical values are not customer prerequisites or
current target versions. Configure the customer's chosen application and
approved versions in the catalog before using the reviewed action, which
resolves resource identifiers within the active Azure scope:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "CHG-7ZIP-2603-YYYYMMDD-NNN" `
  -WhatIf
```

It does not upload a package or create a Gallery version.

## Chrome template guidance

Chrome can use the same catalog-driven deployment scripts; do not add
Chrome-specific branching to them. Add a separate product record and bind a
separate SRE Agent action to:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "<approval-id>" `
  -ProductName "Google Chrome"
```

Expose only `approvalId` to the agent.

Chrome's vendor version has four numeric components, while an Azure Compute
Gallery application version uses three. Store both values and require an
explicit, unique mapping. Never silently truncate the fourth component or
derive a new version by incrementing another component. A tested mapping from
one environment is evidence for that deployment only, not a reusable policy.

Before publication, record:

- The exact approved Chrome enterprise vendor version.
- The unique three-part Gallery version.
- The immutable and legally permitted package source.
- SHA-256 and Authenticode signer evidence.
- The exact package file name as downloaded by VM Applications.
- Reviewed silent install, update, and remove commands.
- Target region, pilot machine, and retained rollback Gallery version.
- The exact storage prerequisite that was required, with its security impact.

Use a block blob for the installer by default. Current VM Application guidance
supports block blobs and page blobs, but page blobs are not required for a
Chrome installer. Diagnose version format, package URL, Gallery managed
identity, `Storage Blob Data Contributor`, storage networking, and command
quoting before changing blob type.

### Chrome Enterprise MSI: machine-wide deployment

The EXE pilot started processes but did not establish a verified installation.
Do not reuse `chrome_installer_uncompressed.exe /silent /install` as the
deployment recipe. Use Google's **Chrome Enterprise standalone x64 MSI** for
64-bit Windows, running as SYSTEM or an elevated administrator. Google documents
the MSI as a system-level installation in Program Files, available to users of
the machine. This does not configure every user's browser profile or prove that
existing per-user installations have been reconciled.

Obtain the MSI from the
[Chrome Enterprise download site](https://chromeenterprise.google/download/)
under the applicable license. The download can change over time: capture and
approve the exact artifact version, SHA-256, and valid Google Authenticode
signer, then retain that reviewed artifact in immutable package storage. Do not
invent a version-pinned URL or use a rolling download during installation.

Package these three files in one ZIP:

1. `GoogleChromeStandaloneEnterprise64.msi`: the approved MSI.
2. `Install-ChromeEnterpriseMsi.ps1`: the repository installer helper.
3. `Install-Chrome.ps1`: a reviewed copy of
   `scripts/Install-ChromeMsiPackage.example.ps1`, with its version, MSI hash,
   and exact signer placeholders replaced.

Record the MSI hash in `installerSha256` and the ZIP hash in `sha256` in the
staging catalog. These are different artifacts with different hashes. The
`packages` staging catalog is a planning manifest, not the `products` catalog
consumed by the legacy staging runbook.

For the new Gallery version, set the package download filename to
`chrome-enterprise-msi.zip`. Configure this install command (Windows `cmd.exe`):

```text
tar.exe -xf chrome-enterprise-msi.zip && powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Install-Chrome.ps1
```

This requires `tar.exe` on the target; validate that prerequisite during the
pilot. Use the same reviewed command for the Gallery update action if that
action is configured. `ExecutionPolicy Bypass` affects this process only and
is not a substitute for package review or signature/hash validation.

The helper runs:

```text
msiexec.exe /i "<approved-msi>" /qn /norestart ALLUSERS=1 REBOOT=ReallySuppress /L*v "<local-log>"
```

It waits for Windows Installer to exit, refuses a downgrade, and verifies the
expected full vendor version in both a Program Files `chrome.exe` and HKLM
uninstall registration. Merely finding a process, an EXE, or an assignment
marked `Succeeded` is not installation proof.

| Result | Handling |
| --- | --- |
| `0` plus matching machine-wide registration and executable | `InstalledVerified` |
| Expected version already verified | `AlreadyInstalledVerified`; no reinstall |
| `0` without matching installation evidence | Fail; retain the MSI log |
| `3010` | Fail pending separately approved reboot and revalidation; never report installation complete |
| Other nonzero code, including `1603`, `1618`, or `1641` | Fail; no automatic retry, uninstall, or reboot |

Verbose MSI logs are retained under
`%ProgramData%\SrePackageDeployment\Logs`. Treat them as operational evidence
and review them before sharing. Assignments set
`treatFailureAsDeploymentFailure = true` so installer failures surface as
deployment failures.

Create a **new three-part Gallery version** for the MSI package; do not mutate
the failed EXE version in place. Keep the four-part vendor version in the
catalog. Review the actual current assignment before using the deployment
wrapper: it still requires that assignment to match the approved rollback
version, and it does not automatically repair a failed assignment or create a
new one.

Do not invent a remove command or use an EXE uninstall string for this MSI.
Record and approve the MSI's actual ProductCode and uninstall/rollback behavior
separately before publishing. User-profile data must not be deleted.
The same helper supports guarded MSI removal:

```powershell
.\Install-ChromeEnterpriseMsi.ps1 -Uninstall `
    -ProductCode "<approved-msi-product-code-in-braces>" `
    -ExpectedVersion "<approved-four-part-chrome-version>"
```

For the Gallery remove action, extract the package first, then invoke this
command with `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass
-File .\Install-ChromeEnterpriseMsi.ps1` and the reviewed parameters.
Removal requires the exact ProductCode and version in HKLM; a different version
or unregistered executable blocks automatic removal. The helper waits for
`msiexec /x`, suppresses automatic reboot, logs the result, and verifies that
machine-wide Chrome files and registrations are absent. If already absent,
it returns `AlreadyAbsentVerified` without running MSI. It never deletes
browser profiles, per-user installs, registry entries, or inventory records.

Removing this MSI is recovery to an absent machine-wide installation, **not a
downgrade or a verified rollback to the failed EXE**. Validate the removal action
on the pilot before calling recovery tested. If a rolling vendor download now
returns a different version than the original pilot, record it as a candidate
and obtain target-version approval before assignment. Publish candidate Gallery
versions with `excludeFromLatest = true` and use explicit version references.

A remove command such as `cmd /c exit 0` performs no removal and must not be
counted as rollback evidence. A Gallery version in `Succeeded` state proves
publication, not that Chrome installed on an Arc machine.

For a version already staged and replicated, the
[direct CLI assignment example](../README.md#direct-cli-assignment-of-a-staged-msi-version)
shows the tested `az rest` PUT, a file-based JSON body for Windows quoting, and
explicit subscription authentication without changing the global CLI context.
That path creates or updates only the named application assignment, bypassing
the wrapper's catalog and rollback checks; review scope and recovery separately.
The MSI pilot verified Chrome `155.0.8059.40`, Gallery version `155.0.8059`,
the exact HKLM MSI registration, and successful installer return code `0`.
The operator confirmed the installation worked. This version mapping is
evidence, not a default target for other environments, and it does not prove
that multi-user launch or live removal recovery has been tested.

After the pilot, confirm Chrome launches under at least two representative
non-administrator user accounts, check `chrome://policy`, and wait for fresh
Change Tracking inventory. Existing browser/update policies or per-user copies
may need a separate reviewed migration. See
[Google's Windows MSI deployment guidance](https://support.google.com/chrome/a/answer/7650247).

## Monitor VM Applications

Use [queries/arc-vm-applications.arg](../queries/arc-vm-applications.arg) in Azure Resource Graph to show application assignments across the fleet.

For a single machine, query its VM Application assignment through the approved
read-only Azure connection without returning full resource identifiers.

Inspect deployment control-plane activity with:

```text
Microsoft.HybridCompute/machines/applications/write
```

## What to build next

1. Confirm the customer-selected Gallery application version's package source, install/uninstall commands, and retained rollback version.
2. Define a versioned 7-Zip Gallery application release process, including checksum/signature evidence.
3. Create an audit-only Azure Policy assignment that checks for the named VM Application on the selected lab scope.
4. Add the Azure Resource Graph inventory to the SRE Agent Live Report.
5. Add one approval-gated custom SRE Agent deployment tool after the canary workflow is proven manually.
