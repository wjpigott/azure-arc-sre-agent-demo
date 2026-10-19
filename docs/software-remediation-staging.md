# Third-Party Software Remediation Staging

## Goal

Extend the read-only third-party software lifecycle report into a controlled remediation workflow:

```text
Assess version variance -> select approved Gallery version for the machine ring -> verify availability -> human approves -> deploy -> verify -> notify
```

Azure SRE Agent identifies and prioritizes the need. It must not download arbitrary executables or install software directly from a chat prompt.

## Architecture

| Phase | Component | Responsibility | Permission |
| --- | --- | --- | --- |
| Detect | Azure SRE Agent + `<log-analytics-workspace>` | Compare Change Tracking inventory and existing VM Application assignments against a human-reviewed deployment catalog. | Read-only |
| Plan | Azure SRE Agent skill | Select the approved Gallery application version for the machine's deployment ring and prepare an exact-version recommendation. | Read-only |
| Approve | Human change owner | Verify target version, ring, maintenance window, scope, and rollback version. | Explicit approval |
| Install | Azure Arc VM Applications | Assign/update a specific Gallery application version on approved Arc targets during maintenance. | Separate change approval |
| Notify | SRE Agent or Logic App | Create a delivery-ready notification only after deployment verification succeeds. | Preview exact content; explicit send approval |

Use only Gallery application versions already approved through the customer's
normal software-packaging controls. Do not embed infrastructure locations,
vendor credentials, or email credentials in an SRE Agent skill, script, or
repository.

## Required controls

- **Deployment catalog:** Every recommendation resolves to an exact, immutable Gallery application version, supported region, deployment ring, and rollback version.
- **No latest-by-default:** The agent selects the customer-approved stable version for that ring, not the vendor's latest release.
- **Availability validation:** Reject a recommendation if the selected version is not available in the target Arc machine's Azure region.
- **No silent downgrade:** If the installed version is newer than policy, require a human review rather than automatically reinstalling an older version.
- **Human approval:** Keep the agent in Review mode. Approval is required before staging and separately before installation.
- **Audit:** Record request ID, approver, source, checksum, output path, timestamp, and result.
- **No automatic email:** Preview recipient(s) and exact text after files are verified; send only after explicit confirmation.

## Recommended first demo

Use one noncritical package such as 7-Zip or Adobe Acrobat on one lab machine.

1. Live Report identifies an installed version that differs from its ring's policy target.
2. SRE Agent confirms the pre-approved Gallery application version is available in the machine's region.
3. SRE Agent creates an **exact-version deployment recommendation**; it does not download anything.
4. A human approves a single-machine canary assignment.
5. Azure Arc deploys the named Gallery application version.
6. SRE Agent produces a notification preview only after deployment verification.

## Azure SRE Agent skill

Create a skill in **Builder > Skills** named `third-party-software-staging` with:

- **Description:** Use when a verified third-party software update needs to be prepared for an approved maintenance change.
- **Tools initially:** `RunAzCliReadCommands` and the existing Log Analytics query tool only.
- **Knowledge files:** [third-party-software-inventory.md](third-party-software-inventory.md), the [Live Report deployment guide](../livereports/README.md), and this document.
- **No write tool at first:** The skill creates a recommendation/manifest only.

After the recommendation flow is trusted, attach one narrowly scoped staging workflow. The staging workflow must accept a pre-approved request ID, not free-form product names or URLs.

## Trigger and execution model

The `third-party-software-staging` skill is recommendation-only. A skill makes the procedure available to the agent; it is not itself a schedule, alert trigger, or package-transfer service.

| Trigger | How it starts | What the current skill can do |
| --- | --- | --- |
| Manual chat | An operator asks the SRE Agent to review products below approved versions or prepare staging recommendations. The agent loads the skill when its description matches. | Query inventory and create `PendingHumanApproval` recommendations. |
| Scheduled task | Create an SRE Agent task such as `Third-Party Software Lifecycle Review`, assign the agent/custom agent that can use the skill, and run it weekly or monthly. | Create a dated recommendation thread; no download, notification, or installation. |
| Alert/response plan | A future log alert can open an investigation when inventory is stale or an approved product is detected below its policy target. | Investigate and recommend; keep the response plan in Review mode. |
| Approved staging action | An operator approves a specific request, then invokes a separate staging-runner tool with the request ID. | Not available until a scoped runner/tool is implemented and attached. |

### Recommended initial schedule

Create the `Third-Party Software Lifecycle Review` scheduled task after the version baseline contains verified targets:

| Setting | Value |
| --- | --- |
| Frequency | Weekly, Tuesday at 8:00 AM local time |
| Run mode | Review |
| Scope | `<log-analytics-workspace>` and the existing read-only Azure subscription connection |
| Output | SRE Agent portal thread only |
| Skill | `third-party-software-staging` |
| Actions | None |

Use this task instruction:

```text
Run the third-party-software-staging recommendation procedure. Query <log-analytics-workspace> software
inventory, compare products only against vendor-verified approved versions, and prepare
PendingHumanApproval staging recommendations for affected connected machines. Do not download,
copy, install, update, remove, configure, schedule, or notify anyone about software.
```

Do not schedule the task until the supporting `approved-versions.json` has no unresolved or blocked product entries. A scheduled task should report "baseline incomplete" rather than manufacture a staging recommendation.

## SRE Agent prompt

```text
Review the third-party software lifecycle findings. For each product that is below a
vendor-verified approved version, create a staging recommendation only.

For every recommendation include product, installed and approved version, affected machines,
vendor release-note source, exact approved vendor download URL, published SHA-256,
maintenance-window recommendation, and rollback considerations.

Do not download, copy, install, update, remove, or configure any software. Do not send a
notification. Mark each recommendation PendingHumanApproval.
```

## Staging request lifecycle

| Status | Meaning |
| --- | --- |
| `PendingHumanApproval` | Agent created a recommendation; no package transfer is permitted. |
| `ApprovedForStaging` | Change owner verified source, checksum, scope, and destination. |
| `StagingInProgress` | Approved runner is downloading and validating the package. |
| `StagedVerified` | Package checksum and controlled local write are verified. |
| `StagingFailed` | Download, checksum, or local write failed; do not install. |
| `NotificationApproved` | Exact recipient list and message have been approved for send. |
| `InstallApproved` | A separate approved change authorizes deployment. |

## Notification preview template

Do not send this automatically. Replace all placeholders and show it for approval:

```text
Subject: Software package staged for approved maintenance

The verified <Product> <Version> package is ready for the approved maintenance change.

Staging status: Verified in the controlled runner location
SHA-256 verification: Passed
Affected machines: <MachineList>
Planned maintenance window: <Window>
Change/request ID: <RequestId>

No installation has been performed.
```

## Next implementation choice

Choose one staging execution surface:

1. **Azure Automation Hybrid Runbook Worker** on an on-prem management host - recommended for a customer-like hybrid demo.
2. **Azure DevOps/GitHub Actions self-hosted runner** - suitable when the organization already treats package staging as CI/CD.
3. **Logic App plus an internal API** - suitable for established ITSM and approval workflows.

Build the runner only after selecting a single noncritical package and an
approved vendor source/checksum process.

## Implemented staging-runner artifact

The `Stage-ApprovedPackage` PowerShell runbook is implemented in this repository. See [stage-approved-package-runbook.md](stage-approved-package-runbook.md) for publishing it to the `SRE-Package-Staging` Automation account and for the approval/catalog controls.

The preferred controlled deployment path is Azure Arc VM Applications. See [arc-vm-applications-deployment.md](arc-vm-applications-deployment.md).
