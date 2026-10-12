# Azure Arc SRE Demo Checklist

Last reviewed: 2026-08-31

Status legend: `[x]` completed and evidenced, `[-]` in progress or needs validation, `[ ]` not started.

## Foundation and governance

- [x] Azure Arc lab subscription selected: `<subscription-name>`.
- [x] Azure Arc estate inventoried: 22 machines; 20 were connected at the telemetry rollout.
- [x] `<log-analytics-workspace>` Log Analytics workspace identified as the core operational workspace.
- [x] Azure Update Manager and Windows/Linux patch maintenance configurations confirmed.
- [x] Change Tracking extensions and data collection rule confirmed.
- [x] Azure Monitor Agent confirmed on representative Windows and Linux Arc machines.
- [x] Read-only SRE telemetry DCRs deployed and associated to 20 connected machines.
- [x] Performance and Windows Event ingestion validated in `<log-analytics-workspace>`.
- [x] Azure SRE Agent prerequisites registered: `Microsoft.App` and `Microsoft.CloudHealth`.
- [x] `<sre-agent-name>` deployed in `<sre-agent-resource-group>`.
- [x] `<log-analytics-workspace>` connected to Azure SRE Agent.
- [x] Dedicated Arc lab subscription connected to Azure SRE Agent with read access.
- [x] Agent safety boundary established: Review mode; no privileged or remediation tools.
- [x] SRE configuration, rollout history, prompts, and demo plan committed to this repository.

## 01 - Platform Health

### Fleet health command center

- [x] Collect Arc connection state and Azure Monitor Agent heartbeat evidence.
- [x] Collect Windows/Linux performance evidence and high-severity operating-system logs.
- [x] Collect Update Manager and Change Tracking evidence.
- [x] Run and retain the initial read-only fleet-health investigation.
- [x] Create the `Arc Fleet Operations` SRE Agent Live Report: `<live-report-id>`, version 1.
- [ ] Verify that every report section refreshes against live <log-analytics-workspace>/subscription data.
- [ ] Add expected-offline machine handling for `<planned-offline-linux-machine>` and `<planned-offline-windows-machine>`.

### Disk, service, and recovery scenarios

- [x] Identify a real OS disk-pressure scenario: `<disk-pressure-machine>` C: at approximately 12% free.
- [x] Identify a real Windows Admin Center certificate crash-loop scenario: `<service-failure-machine>`.
- [x] Identify a real SQL extension crash-loop pattern: `<sql-extension-machine-1>`, `<sql-extension-machine-2>`, and `<aging-agent-machine-1>`.
- [x] Identify a real Linux inotify exhaustion scenario: `<linux-machine-1>`.
- [ ] Validate a repeatable host/guest recovery scenario using only noncritical lab systems.
- [ ] Document a safe recovery demo runbook, success criteria, and cleanup actions.

### Monitoring coverage

- [x] Identify and remediate the original telemetry coverage gap. Revalidated on 2026-09-02: 20 of 21 connected machines have an SRE telemetry DCR association and 19 have fresh `<log-analytics-workspace>` telemetry.
- [x] Diagnose the reported AMA gap on 2026-08-31. `<out-of-support-agent-machine>` has current heartbeat, performance, and event data; the earlier report was stale or used an inconsistent computer name.
- [x] Install Azure Monitor Agent on newly reconnected `<planned-offline-linux-machine>`; validate its SRE Linux telemetry association separately.
- [ ] Associate `SRE-Linux-Telemetry` with `<planned-offline-linux-machine>`. It has fresh AMA heartbeat but is the only connected host without the SRE telemetry DCR.
- [x] Install Azure Monitor Agent on `<canary-machine>`, `<windows-machine-1>`, and `<windows-machine-2>`; the Windows SRE telemetry DCR is already associated.
- [-] Diagnose why `<telemetry-gap-machine-2>`, `<windows-machine-3>`, and `<telemetry-gap-machine-1>` have a successful AMA extension and SRE DCR association but emit no recent `<log-analytics-workspace>` Heartbeat, Perf, or Event data. `<windows-machine-3>` was reconfirmed on 2026-09-01: AMA 1.44 is `Succeeded`, automatic upgrade is enabled, and `SRE-Windows-Telemetry` is associated; inspect host-side AMA/DCR processing and Log Analytics egress next.
- [-] Diagnose `<telemetry-gap-machine-1>` telemetry ingestion. On 2026-09-02 it has `SRE-Windows-Telemetry` associated but no fresh `<log-analytics-workspace>` telemetry; all other connected Windows DCR associations are emitting data.
- [-] Diagnose `<windows-machine-2>` telemetry ingestion. On 2026-09-01, AMA 1.44 is `Succeeded`, automatic upgrade is enabled, and `SRE-Windows-Telemetry` is associated, but no Heartbeat, Perf, or Event records were found in `<log-analytics-workspace>` over the preceding 24 hours.
- [x] Confirm AMA is installed and automatic extension upgrade is enabled on `<canary-machine>`, `<windows-machine-1>`, `<windows-machine-2>`, and `<planned-offline-linux-machine>`.
- [ ] Reconcile the remaining telemetry exceptions: associate `<planned-offline-linux-machine>` with the Linux SRE DCR and diagnose `<telemetry-gap-machine-1>` no-telemetry state.
- [ ] Validate Windows CPU counters across the Windows fleet; correct the DCR counter definition if required.

## 02 - Proactive Lifecycle Management

### Arc Connected Machine agent lifecycle

- [x] Establish controlled-lag policy: current for canary, Current-1 allowed for standard, time-bound exceptions for legacy.
- [x] Identify live outdated-agent test cases, including `<out-of-support-agent-machine>` on 1.53.
- [x] Create `config/arc-agent-baseline.json` with current release, approved standard target, minimum supported version, source, and review date.
- [x] Create `config/arc-agent-exceptions.json` with machine, owner, rationale, and expiration fields.
- [x] Add a read-only lifecycle inventory script that reports agent versions and existing automatic-upgrade settings.
- [x] Validate the lifecycle inventory against the lab: 12 current, 4 approved-lag, 5 aging, and 1 out-of-support agents.
- [ ] Apply `ArcAgentRing` tags to canary, standard, and exception machines.
- [ ] Run the proactive lifecycle prompt and validate version classification against the baseline.
- [ ] Produce a canary-to-standard Arc agent upgrade recommendation; do not execute it.
- [ ] Select one noncritical canary and document a human-approved upgrade, reconnection, telemetry, and rollback validation procedure.

### Operating-system, patch, capacity, and certificate lifecycle

- [-] Apply lifecycle metadata tags: `OsLifecycleDate`, `SupportTier`, `ServiceOwner`, `RefreshTarget`, and `MaintenanceWindow`. Deferred until Azure Update Manager Update Rules is available; not required for the current demo.
- [x] Identify real patch compliance, failed assessment, and stale assessment examples.
- [ ] Create a 30/60/90-day lifecycle report with OS support, patch, Arc agent, capacity, and certificate actions.
- [ ] Record Hyper-V host and key guest capacity thresholds and growth-review cadence.
- [ ] Add certificate expiry monitoring for the WAC gateway and selected test certificates.
- [x] Validate third-party software inventory in `<log-analytics-workspace>` Change Tracking data: Python 3.13.12 observed on `<canary-machine>`.
- [x] Create the read-only third-party software lifecycle Live Report in Azure SRE Agent.
- [x] Capture the reusable inventory query, version-baseline template, and Live Report prompt in this repository.
- [x] Capture the SRE Agent Live Report connector/query pattern as a sanitized deployment template.
- [ ] Create an approved-version baseline for selected third-party software, beginning with Python and Acrobat.
- [x] Document the approval-gated third-party software remediation-staging architecture, request schema, notification template, and SRE Agent planning prompt.
- [ ] Select a noncritical product, approved vendor URL/SHA-256, and restricted staging-share path for the first package-staging demonstration.
- [ ] Create an SRE Agent `third-party-software-staging` skill with read-only recommendation tools and knowledge files.
- [ ] Upload a version-verified `approved-versions.json` with no unresolved/blocked entries to the skill before enabling a scheduled lifecycle-review task.
- [ ] Create the weekly `Third-Party Software Lifecycle Review` scheduled task in Review mode; it creates recommendations only.
- [ ] Deploy one restricted staging runner (recommended: Azure Automation Hybrid Runbook Worker) after the package and share controls are approved.
- [x] Validate the `SRE-Package-Staging` Hybrid Worker on `<package-staging-worker>`: Local System access to `<local-staging-root>` and HTTPS access to approved vendor sites.
- [x] Build the `Stage-ApprovedPackage` runbook artifact; publishing and the first approved-package test remain pending.
- [x] Define the dual-lane remediation architecture: Hybrid Worker package verification plus Azure Arc VM Applications deployment.
- [ ] Confirm the existing `<gallery-name>/7zipexe/0.0.4` Gallery application source, install/uninstall commands, and retained rollback version.
- [ ] Create a versioned 7-Zip 26.03 Gallery application from a verified artifact; replicate it to the canary machine region.
- [ ] Query Azure Resource Graph for Arc VM Application assignments and add that deployment state to the SRE Agent Live Report.
- [ ] Add an audit-only Azure Policy definition for the selected VM Application on the canary scope.
- [ ] Manually deploy one approved VM Application to a noncritical canary and verify instance view, Activity Log, inventory, and health.
- [x] Define a fixed 7-Zip canary target: `<canary-machine>` in West Central US, Gallery version `26.03.0`, with `0.0.4` retained for rollback.
- [x] Create a read-only SRE Agent skill template and an approval-gated, target-fixed PowerShell deployment script for the 7-Zip canary.
- [x] Create a paste-ready SRE Agent approval skill that asks before the one-machine 7-Zip `26.03.0` Canary deployment.
- [ ] Only after manual validation, add a narrowly scoped SRE Agent tool that proposes VM Application deployment in Review mode.
- [ ] Stage and verify one approved package, produce a notification preview, and obtain explicit approval before sending it.
- [ ] Keep Gallery publication and VM Application deployment as separately approved changes; do not automatically install staged third-party software.
- [x] Add read-only third-party software inventory and version-consistency reporting to the SRE Agent Live Report.
- [ ] Add Python virtual-environment/package inventory only if required, using an approved read-only custom-log collection design.
- [ ] Create a read-only maintenance safety assessment that classifies machines as standalone, cluster member, or unknown before recommending a patch or reboot.
- [ ] Create a machine role and maintenance-criticality register for the lab.
- [ ] If a noncritical test cluster is added later, collect cluster node/role/quorum evidence and use Cluster-Aware Updating for maintenance execution.

## 03 - New Capability and Increased Maturity

### Standardized onboarding and drift

- [x] Store SRE telemetry DCR definitions and idempotent deployment script in Git.
- [x] Confirm Policy/Guest Configuration assignments are present.
- [ ] Document the intended minimum server baseline: Arc agent, AMA, Change Tracking, Defender, DCR association, tags, and approved extensions.
- [ ] Create an onboarding compliance check that identifies a new or drifted Arc machine.
- [ ] Create an approved-extension inventory and identify unnecessary extensions, starting with SQL extension crash-loop candidates.
- [x] Create a read-only Arc extension inventory and automatic-upgrade policy baseline.
- [x] Validate extension lifecycle inventory: 130 instances; all 19 Azure Monitor Agent instances are `Succeeded` with automatic upgrade enabled.

### Controlled rollout rings

- [ ] Apply `PatchRing` tags: Canary, Standard, and Legacy.
- [ ] Map Update Manager maintenance configurations to the patch rings.
- [ ] Select a noncritical canary machine for patch/agent lifecycle testing.
- [ ] Define promotion criteria: stable Arc connectivity, telemetry, disk/memory health, and no elevated critical events.
- [ ] Demonstrate an evidence-based recommendation to promote or hold a rollout; do not auto-promote.

### On-premises dependency scenarios

- [ ] Add Hyper-V host-to-guest dependency and maintenance-safety assessment.
- [ ] Add Active Directory/DNS health and domain-controller maintenance-safety assessment if these roles exist in the lab.
- [ ] Add backup/restore readiness evidence for selected noncritical workload(s).
- [ ] Add storage, network/egress, certificate, and time-synchronization checks as the next operational data sources.

## 04 - Platform Management Evolution

### SRE Agent operating model

- [x] Deploy Azure SRE Agent with Azure resource and Log Analytics context.
- [x] Execute the initial read-only fleet-health prompt.
- [ ] Create the `Arc Fleet Daily Health` scheduled task in Review mode.
- [ ] Keep task results in the SRE Agent portal for an initial two-to-four-week learning period.
- [ ] Create a daily triage procedure with severity definitions, owner, and expected follow-up.
- [ ] Review task history for recurring SQL extension, certificate, patch, or telemetry patterns.

### Health model and governed change

- [ ] Design an Azure Monitor health model for `Arc lab`.
- [ ] Add health signals for connectivity, disk capacity, patch assessment freshness, and critical event volume.
- [ ] Configure a read-only alert-to-investigation flow.
- [ ] Define one narrow approval-gated action, such as an Update Manager assessment or Arc agent upgrade.
- [ ] Validate the approval, action audit, and post-action health-check experience on a noncritical machine.

## Customer-ready acceptance criteria

- [ ] Live Report presents current, evidence-cited fleet health without manually rebuilding a dashboard.
- [ ] Agent distinguishes planned offline, telemetry gap, warning, and urgent conditions.
- [ ] Agent shows approved Arc agent lag separately from unsupported/risky drift.
- [ ] Agent produces a credible 30/60/90-day lifecycle plan.
- [ ] A policy or configuration-drift condition is visible and explained.
- [ ] A controlled rollout recommendation is grounded in canary health evidence.
- [ ] A proposed infrastructure change requires explicit human approval.
- [ ] Demo uses real but non-destructive lab conditions, with a documented reset path.
