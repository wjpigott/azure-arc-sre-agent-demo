# Azure Arc VM Applications Deployment

## Decision

Use Azure Arc VM Applications as the deployment path. Keep the Hybrid Worker/share as optional lab-only package onboarding:

```text
Customer packaging process publishes immutable Azure Compute Gallery application versions
  -> SRE Agent assesses installed and assigned versions against an approved deployment ring
  -> SRE Agent confirms the selected Gallery version is available in the target region
  -> SRE Agent proposes an exact-version deployment
  -> human approves Arc VM Application assignment or update
  -> Azure Arc runs the application install command on the target machine
  -> SRE Agent verifies inventory, telemetry, and deployment state
```

Azure Compute Gallery VM Applications is the deployment, versioning, targeting, and Azure Activity Log audit lane. The Hybrid Worker/share is not a customer software-distribution service; it is optional for a lab demonstration of controlled package onboarding.

## Version-selection policy

The SRE Agent must not equate "latest vendor release" with "approved target." The customer owns an explicit deployment catalog with one version per product and ring:

| Ring | Target behavior |
| --- | --- |
| Canary | A newly approved version, deployed first to selected noncritical machines. |
| Standard | The proven stable version; this can intentionally be one or more releases behind the vendor's newest release. |
| Legacy | A retained earlier version with a documented exception, compensating controls, review date, and owner. |

Each catalog record identifies the exact Azure Compute Gallery application version and supported regions. For example, a Standard ring can remain on `7zipexe/0.0.4` while a newer vendor release or Canary Gallery version exists. The agent only recommends the catalog target for the machine's ring.

## Assessment and deployment workflow

1. **Assess:** Query Change Tracking inventory for installed software, Azure Resource Graph for Arc machines and existing VM Application assignments, and the approved deployment catalog.
2. **Select policy target:** Determine the machine's deployment ring and select the product's approved Gallery application version; never select the vendor's latest version automatically.
3. **Confirm availability:** Ensure the selected Gallery version is replicated to the Arc machine's Azure region and that the machine meets connectivity and Arc-agent prerequisites.
4. **Classify:** Mark each machine as `Compliant`, `UpgradeRecommended`, `NewInstallRecommended`, `AheadOfPolicyReview`, `ArtifactUnavailable`, or `ManualReview`.
5. **Propose:** For a valid recommendation, present product, installed version, assigned Gallery version, approved target version, machine/ring, maintenance window, and rollback Gallery version.
6. **Approve:** A human approves the exact machine and exact Gallery application version.
7. **Deploy:** Create or update only the Arc VM Application assignment for that approved target.
8. **Verify:** Check application instance view, Azure Activity Log, Change Tracking inventory, and machine health before promoting the target version to the next ring.

If a machine already has a version newer than its ring target, do not downgrade it automatically. Mark it `AheadOfPolicyReview` and require an explicit compatibility or rollback decision.

## Why VM Applications is the preferred deployment path

| Capability | Hybrid Worker plus SMB share | Arc VM Applications |
| --- | --- | --- |
| Verify external vendor artifact | Yes | Artifact must be prepared first |
| Immutable version record | Receipt only | Gallery application version |
| Deploy to Arc machines | Requires a separate installer/remoting mechanism | Native `Microsoft.HybridCompute/machines/applications` resource |
| Upgrade control | Custom logic | Update assignment to a specific gallery application version |
| Azure control-plane audit | Runbook job log | Activity Log create/update operations |
| Fleet inventory | Custom share/receipt scan | Azure Resource Graph query |
| Rollback | Custom logic | Assign a retained prior gallery application version |

## Important boundaries

- VM Applications on Arc is currently a preview feature. Use it only on noncritical lab machines until feature, support, and customer tenancy requirements are confirmed.
- Arc machine agent version must be 1.61 or newer.
- Each target must be connected, not expired, and able to reach the Azure Storage Blob endpoint that hosts the gallery package.
- The gallery application version must be replicated to the Arc machine's Azure region.
- The package and install/uninstall commands belong to the Gallery application version. `application add` or `application update` assigns that prebuilt version to a machine.
- Do not use Run Command as the standard installer. Use it only for approved diagnostics, such as retrieving VM Application stdout/stderr after a failed deployment.
- Keep SRE Agent in Review mode and do not grant broad contributor access. The first write permission should be a custom role limited to VM Application assignment/update on selected Arc machines.

## Lab prerequisites

| Requirement | Current state or action |
| --- | --- |
| Feature enrollment | Confirm this subscription remains allowlisted for Arc VM Applications preview. |
| Arc agent | Verify target machine is at least 1.61. `<canary-machine>` is already newer. |
| Gallery | Existing `<gallery-name>` gallery has `7zipexe` assigned to `<canary-machine>` at version `0.0.4` with `Succeeded` provisioning state. |
| Network | Allow target Arc machines outbound HTTPS to `*.blob.core.windows.net`. |
| Package source | Use an application version already published through the customer's approved packaging process. |
| Gallery replication | Publish/replicate the application version to each target Arc machine region, such as West Central US or Central US. |
| Target | Start with one noncritical, connected x64 Windows Arc machine. |

## First demo: 7-Zip 26.03

Use the 7-Zip example as a separate VM Application deployment proof, not as an automatic follow-on from the existing staging runbook.

1. The third-party lifecycle report identifies 7-Zip version drift.
2. The deployment catalog selects the exact approved Gallery version for the target ring; it does not select the latest 7-Zip release.
3. SRE Agent verifies that target version is available in the canary machine's region.
4. SRE Agent proposes a canary application assignment; a human approves it.
5. Assign the Gallery version using `az connectedmachine application add`; use `update` only for an existing application assignment.
6. Verify the Arc application resource instance view, Azure Activity Log, Change Tracking inventory, and post-install health.
7. Retain the prior Gallery application version before any broader rollout.

The original application-assignment command used version `0.0.3`. The current lab assignment is version `0.0.4`:

```powershell
az connectedmachine application add `
  --name "7zipexe" `
  --machine-name "<canary-machine>" `
  --resource-group "<arc-resource-group>" `
  --location "westcentralus" `
  --package-reference-id "/subscriptions/<subscription-id>/resourceGroups/<arc-resource-group>/providers/Microsoft.Compute/galleries/<gallery-name>/applications/7zipexe/versions/0.0.4"
```

It does not upload a package or create a Gallery version.

## Monitor VM Applications

Use [queries/arc-vm-applications.arg](../queries/arc-vm-applications.arg) in Azure Resource Graph to show application assignments across the fleet.

For a single machine's result:

```powershell
az connectedmachine application show `
  --name "<application-name>" `
  --machine-name "<arc-machine-name>" `
  --resource-group "<resource-group>" `
  --instance-view
```

Inspect deployment control-plane activity with:

```text
Microsoft.HybridCompute/machines/applications/write
```

## What to build next

1. Confirm the `7zipexe` Gallery application version's package source, install/uninstall commands, and retained rollback version.
2. Define a versioned 7-Zip Gallery application release process, including checksum/signature evidence.
3. Create an audit-only Azure Policy assignment that checks for the named VM Application on the selected lab scope.
4. Add the Azure Resource Graph inventory to the SRE Agent Live Report.
5. Add one approval-gated custom SRE Agent deployment tool after the canary workflow is proven manually.
