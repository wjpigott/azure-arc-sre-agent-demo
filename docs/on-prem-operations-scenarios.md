# On-Premises Operations Scenarios

Azure Arc gives Azure resource and telemetry context for on-premises machines, but safe operational decisions also require machine topology and workload context. This document defines scenarios to add after the foundational fleet-health demonstration.

## Cluster-aware maintenance

### Why it matters

Do not treat every Windows server as an independent patch target. A Windows Failover Cluster has node, role, quorum, storage, and failover dependencies. Patching/rebooting multiple nodes at once can create a service outage.

For Windows Failover Clusters, use **Cluster-Aware Updating (CAU)** for the update execution path. CAU places one node in maintenance mode, moves clustered roles, installs updates, restarts if required, validates recovery, and then proceeds to the next node.

### SRE Agent role

The initial role is read-only:

1. Discover whether a machine is a cluster node.
2. Identify cluster name, node state, quorum, clustered roles, owner node, maintenance state, and recent failovers.
3. Check that enough healthy nodes remain before any planned maintenance.
4. Recommend CAU or the documented cluster runbook rather than a direct multi-machine Update Manager deployment.
5. Require human approval before a maintenance action.

### Lab build

The current lab has no cluster. Add this only when a noncritical two-node test cluster is available.

| Item | Lab requirement |
| --- | --- |
| Nodes | Two noncritical Windows Server Arc-enabled VMs |
| Cluster capability | Failover Clustering feature and a validated failover cluster |
| Workload | A noncritical clustered file-server role or test workload |
| Telemetry | AMA/DCR coverage, cluster event log collection, and Change Tracking |
| Patching | Update Manager assessment; CAU is the cluster execution path |
| Evidence | Node state, role ownership, planned failover, one-node update/reboot, post-maintenance health |

### Read-only discovery evidence

Run locally or through a future approval-gated diagnostic tool:

```powershell
Get-WindowsFeature Failover-Clustering
Get-Cluster
Get-ClusterNode
Get-ClusterGroup
Get-ClusterResource
Get-ClusterQuorum
```

The agent must classify a server as **standalone**, **cluster member**, or **unknown**. Unknown means no evidence is available; it must not assume standalone safety.

## Other high-value on-premises scenarios

| Scenario | Signals to add | Safe agent question | Customer value |
| --- | --- | --- | --- |
| Hyper-V host and guest dependency | Host health, guest state, storage capacity, virtual-switch errors, guest Arc heartbeats | "Is this host safe for maintenance, and which guests are at risk?" | Shows blast-radius awareness beyond individual server alerts. |
| Active Directory and DNS dependency | AD DS/DNS service state, replication errors, SYSVOL health, domain-controller role tags | "Do I have enough healthy domain controllers before maintenance?" | Demonstrates foundational identity protection. |
| Backup and restore readiness | Backup-job status, last successful backup, job failures, retention, restore-test date | "Which protected workloads lack a recent successful backup?" | Converts backup reporting into recovery confidence. |
| Storage capacity and integrity | Volume free space/growth, RAID or iDRAC alerts, NTFS/ReFS errors, Storage Spaces health | "Which capacity or storage conditions threaten the next maintenance window?" | Finds risk before a guest, patch, or backup fails. |
| Network and DNS dependency | Gateway/DNS reachability, NIC errors, proxy health, Arc/AMA endpoint tests | "Is this a machine issue or a shared network/egress issue?" | Explains correlated Arc/AMA disconnects. |
| Certificate dependency | Service certificate expiry, chain/trust errors, WAC gateway certificate health | "Which certificate will break management or workload access in 30 days?" | Demonstrates lifecycle management beyond operating-system patches. |
| Time synchronization | Windows Time status, clock offset, NTP reachability, Kerberos-related events | "Could time drift be causing authentication or certificate failures?" | Addresses a common and subtle hybrid reliability condition. |
| Service dependency mapping | VM Insights dependency map, service tags, Change Tracking, process/service events | "What services and workloads depend on this machine before a restart?" | Supports safer change planning. |

## Recommended next build

Build a **read-only maintenance safety assessment** before creating a cluster:

1. Maintain an explicit machine role and maintenance criticality register in the repository.
2. Add a report that classifies each machine as standalone, cluster member, or unknown.
3. For standalone machines, report Arc/AMA health, patch state, uptime, disk headroom, recent critical events, and backup evidence before recommending maintenance.
4. For cluster members, stop at a CAU/runbook recommendation until cluster telemetry and a human-approved process are in place.

This provides a credible customer story now and creates the safe control plane for a future two-node cluster demonstration.
