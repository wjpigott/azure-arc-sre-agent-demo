# 7-Zip Azure Arc VM Application Canary

## Current target

| Field | Value |
| --- | --- |
| Canary machine | `<canary-machine>` |
| Machine region | West Central US |
| Application assignment | `7zipexe` |
| Current assigned Gallery version | `0.0.4` |
| Approved Canary Gallery version | `26.03.0` |
| Rollback Gallery version | `0.0.4` |

Do not provide an external package location to SRE Agent chat or use one as an
ad hoc installer source. Azure Arc receives the approved package through the
Gallery application assignment.

## Package command preflight

Before deploying, inspect version `26.03.0` in the Gallery. Its package source is
named `7z2603-x64.zip`, while the configured install action includes
`ren 7z2603 7z2603.zip`. Confirm that this command is correct for the file name
presented to the Arc VM Applications runtime. If it is not, create a new Gallery
version with the corrected command; do not alter an existing version in place.

## Create the read-only SRE Agent skill

In Azure SRE Agent **Builder > Skills**, create a skill named
`arc-vm-application-7zip-canary`.

1. Use the assessment and approval policy in this document as the skill instruction.
2. Attach `config/arc-vm-application-deployment-catalog.json` as knowledge after replacing its placeholders.
3. Enable the Log Analytics query and Azure read/Resource Graph tools.
4. Add a custom action named `DeployApproved7ZipCanary`. Expose only `approvalId`
   to the agent. It must run `Start-ArcVmApplicationCanaryDeployment.ps1`, which
   reads the reviewed catalog, discovers the Azure and package-storage scope,
   validates it, and invokes the lower-level assignment implementation.
5. Scope that action to the exact `<canary-machine>` VM Application assignment; do
   not enable a general Azure CLI write tool, Run Command, Automation job
   action, or notification action.
6. Save the skill.

Use this chat request:

```text
Assess 7-Zip on <canary-machine> using the approved Canary policy.
If it is eligible, ask for explicit deployment approval. Do not make a change
unless I provide the full approval sentence requested by the skill.
```

## Controlled canary deployment

Only proceed when the assessment is `ReadyForHumanApproval`. Run a what-if first
from an Azure-authenticated administrative shell:

```powershell
.\scripts\Start-ArcVmApplicationCanaryDeployment.ps1 `
  -ApprovalId "CHG-7ZIP-2603-CANARY-001" `
  -WhatIf
```

After review, run the same command without `-WhatIf`. The script resolves the
required resources from the reviewed catalog within the active Azure scope and
fails if a logical target is missing or ambiguous. The agent cannot select an
arbitrary machine, Gallery, application, package source, or version.

## Verify after deployment

Wait for the application assignment to reach `Succeeded`, then validate:

1. Arc VM Application instance view and Azure Activity Log.
2. Change Tracking inventory shows the expected 7-Zip version.
3. A basic archive create/extract check succeeds on `<canary-machine>`.
4. No new health, connectivity, or application errors occur.

If verification fails, assign the retained rollback Gallery version `0.0.4` through
the same reviewed process; do not invoke an unreviewed uninstall command.
