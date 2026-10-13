# Customer Demo Catalog

This catalog maps the customer's four strategic themes to concrete, safe demonstrations in the Azure Arc lab. Each demonstration begins read-only and uses Azure SRE Agent to investigate and explain evidence. Remediation remains approval-gated.

## Live Report artifact

Use the saved `Arc Fleet Operations` Live Report as the live customer demo surface. Record its generated ID outside this public repository; downloaded HTML is a portable snapshot rather than its live data source.
For new deployments, use the selected software tracker and Arc priority/lifecycle
[blueprints](live-report-bootstrap.md). Existing demos can retain their current
report; the new templates do not rename it or create reports automatically.

## 01 - Platform Health

**Leadership outcome:** Reliable and scalable foundations through deep observability across Windows, Linux, hypervisor, storage, backup, identity, and data center services.

| Demo | Lab build | SRE Agent moment | Customer conversation |
| --- | --- | --- | --- |
| Fleet health command center | <log-analytics-workspace> telemetry DCRs, Arc machine inventory, Update Manager, Change Tracking, and the `Arc Fleet Operations` Live Report | Ask "What is unhealthy right now?" and receive a ranked, evidence-cited fleet view instead of disconnected dashboards. | Show how the agent separates a host-level outage, expected offline machines, telemetry gaps, and individual server faults. |
| Disk exhaustion prevention | Maintain the 15% disk threshold; use `<disk-pressure-machine>` as a real low-space example | Correlate sustained C: free-space pressure, available memory, and recent event activity; propose the safest cleanup investigation. | Demonstrate proactive prevention before an OS or application outage. |
| Windows service failure investigation | Use `<service-failure-machine>` WAC certificate crash loop and the SQL extension service crash loops as controlled evidence | Identify repeated event IDs, group correlated failures, form a likely root cause, and cite logs/timestamps. | Explain that the agent reduces triage time by grouping symptoms into one problem hypothesis. |
| Hypervisor and workload recovery | Restart a subset of noncritical lab guests or simulate an Arc agent service stop | Detect the blast radius, recognize whether the issue is host-level or isolated, and track recovery progress. | Show incident context: "what changed, what recovered, and what remains at risk?" |
| Monitoring coverage validation | Keep a small set of machines without a DCR association as a deliberate coverage test | Flag Arc-connected hosts that lack recent heartbeat, performance, or event telemetry. | Explain that reliable operations starts by proving observability coverage, not assuming it. |

## 02 - Proactive Lifecycle Management

**Leadership outcome:** Cost-effective planning ahead of hardware refresh, software renewal, capacity, and OS currency deadlines.

**Current scope note:** Lifecycle metadata tags and their Update Manager integration are deferred until Azure Update Manager Update Rules is available. The current demo uses live Arc inventory, Update Manager assessment data, and the Arc agent lifecycle baseline; it does not depend on future Update Rules functionality.

| Demo | Lab build | SRE Agent moment | Customer conversation |
| --- | --- | --- | --- |
| Arc agent lifecycle management | Use outdated Arc agent versions already present in the lab; maintain current, approved, and minimum-supported versions in the repository | Classify agents as current, approved one-version lag, aging, out of support, or time-bound exception. | Controlled lag is deliberate risk management, not a failure to patch. |
| OS lifecycle and ESU planning | Tag machines with `OsLifecycleDate`, `SupportTier`, `ServiceOwner`, and `RefreshTarget` | Produce a 30/60/90-day lifecycle action plan and identify systems that need ESU, upgrade, replacement, or an approved exception. | Turn end-of-support dates into an owned and prioritized program. |
| Patch readiness and maintenance planning | Use existing Windows/Linux Update Manager schedules and patch assessment data | Identify missing security updates, failed or stale assessments, reboot debt, and machines outside their assigned maintenance window. | Show readiness before patch night, not a post-failure spreadsheet. |
| Capacity forecast | Maintain disk and memory telemetry; tag Hyper-V host capacity | Flag hosts with a risk of crossing disk/memory thresholds and explain the trend and likely impact. | Make capacity a predictable lifecycle decision rather than an outage response. |
| Certificate and renewal hygiene | Monitor the WAC gateway certificate and add a few test certificates with known expiry dates | Identify certificates approaching expiry or failures caused by missing/expired certificates. | Extend lifecycle management beyond servers to operational dependencies. |
| Third-party software lifecycle | Use existing Change Tracking `ConfigurationData` inventory for Python, Acrobat, and selected software | Report installed versions, stale inventory, inconsistent deployment, and verified baseline drift. | Extend lifecycle governance beyond operating-system and Arc agent currency. |

## 03 - New Capability and Increased Maturity

**Leadership outcome:** Standardized builds, images, patching, security, certificates, and data center practices that make delivery faster and safer.

| Demo | Lab build | SRE Agent moment | Customer conversation |
| --- | --- | --- | --- |
| Baseline-as-code | Keep the DCR JSON, deployment script, tags, and policy intent in this repository | Show that a newly connected server can be assessed for required telemetry and baseline configuration immediately. | Replace manual onboarding with an auditable, repeatable platform standard. |
| Compliance and drift detection | Azure Policy/Guest Configuration for AMA, Change Tracking, Defender, required tags, and approved extensions | Explain which machine drifted, what baseline it violates, and whether the drift coincides with a service issue. | Standardization enables faster investigation and safer change. |
| Patch-ring promotion | Tag hosts `Canary`, `Standard`, and `Legacy`; configure matching Update Manager maintenance schedules | Compare canary health and event evidence before recommending promotion to the next ring. | The platform learns from a small blast radius before changing the broader estate. |
| Arc agent release-ring promotion | Maintain `ArcAgentRing` and version baselines; nominate a canary host | Recommend a phased Arc agent upgrade plan, validate post-upgrade reconnectivity/telemetry, and only then recommend broader rollout. | Directly addresses bad-rollout concerns with a governed, observable process. |
| Security and certificate posture | Use Defender extensions and Policy evidence; track test certificate expiry | Correlate a missing agent, configuration drift, or certificate issue with potential service risk. | Security controls become measurable platform capabilities, not point-in-time projects. |

## 04 - Platform Management Evolution

**Leadership outcome:** Modern and secure AI-enabled incident, problem, and change management.

| Demo | Lab build | SRE Agent moment | Customer conversation |
| --- | --- | --- | --- |
| AI-assisted incident investigation | Azure SRE Agent with `<log-analytics-workspace>` and subscription read access | Run the fleet-health prompt; have the agent gather facts, state confidence, and produce a ranked incident summary. | The agent compresses context gathering, but does not replace human accountability. |
| Recurring problem detection | Retain scheduled task history and use recurring SQL/WAC/telemetry findings | Ask the agent to identify repeat patterns, affected machines, likely common cause, and recommended permanent remediation. | Move from recurring incident handling to problem management. |
| Governed change recommendation | Keep the agent in Review mode and attach a specific runbook later | The agent proposes a patch assessment, Arc agent upgrade, or restart sequence; a human must approve the action. | AI makes recommendations and prepares change evidence without bypassing change control. |
| Daily operating rhythm | Create the `Arc Fleet Daily Health` scheduled task and Live Report | Open a consistent daily report that refreshes telemetry, highlights change since yesterday, and retains investigation threads. | Replace manually rebuilt morning checks with consistent proactive operations. |
| Action audit and learning | Preserve agent investigation threads, Live Report revisions, and repository changes | Review what the agent observed, proposed, approved, executed, and validated. | Governance and institutional knowledge improve together. |

## Key enablers

| Enabler | How to demonstrate it |
| --- | --- |
| App context for hosting | Start with infrastructure context: tags, owner, service role, criticality, dependencies, maintenance window, and expected-offline status. Add application telemetry only when a workload is available. |
| Operating model evolution | Use a daily health task, a triage procedure, defined severity criteria, documented exceptions, and human approval for changes. |
| Talent strategy | Position the agent as an SRE force multiplier: it handles evidence gathering and repeatable analysis so engineers spend time on engineering judgment and permanent fixes. |
| AI | Use Azure SRE Agent with managed identity, Log Analytics, subscription read scope, tool governance, and Review mode. Explain its sources and evidence rather than presenting it as an opaque chatbot. |

## Recommended customer-facing demo sequence

1. Open `Arc Fleet Operations` and establish the live fleet baseline.
2. Investigate a real condition, such as low disk, a WAC certificate crash loop, or an Arc agent version outside support.
3. Pivot to the 90-day lifecycle plan and show controlled Arc agent and patch rings.
4. Show the baseline-as-code repository and Policy/Change Tracking evidence.
5. Close with the approved-change model: the agent can propose a safe phased action, but a person decides whether it runs.

## Do not demo initially

- Autonomous reboots, patch deployments, or Arc agent upgrades.
- Broad privileged agent roles.
- Sending findings externally without an approved notification destination and message review.
- Artificially destructive failures on the lab host or critical lab infrastructure.
