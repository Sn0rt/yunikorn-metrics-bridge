# YARN Beans To YuniKorn Metrics Mapping

This document maps the YARN bean metrics used by legacy dashboards to the metrics available in a YuniKorn-based Kubernetes deployment.

It distinguishes between two YuniKorn data sources and one transformation layer:

- Native YuniKorn metrics endpoint
  - `yunikorn_queue_app`
  - `yunikorn_queue_resource`
  - scheduler and container metrics exposed by YuniKorn itself
- YuniKorn REST endpoints
  - `/ws/v1/partition/{partition}/queues`
  - `/ws/v1/partitions`
  - `/ws/v1/partition/{partition}/applications/active`
  - `/ws/v1/partition/{partition}/applications/completed`
- JSON-exporter transformation layer in this repo
  - `yunikorn_partition_capacity_*_value`
  - `yunikorn_partition_used_*_value`
  - `yunikorn_partition_applications_value`
  - `yunikorn_queue_*_value`
  - `yunikorn_app_used_*_value`
  - `yunikorn_completed_app_*_value`

Important:

- Most queue-level resource mappings can now be sourced from native YuniKorn queue metrics or from the `yunikorn_queues` JSON exporter module in this repo.
- The `yunikorn_queues` module is backed by the YuniKorn REST queue endpoint.
- Application lifecycle and partition capacity views rely on the JSON exporter modules in this repo.
- Some YARN metrics are not portable because they depend on YARN-specific concepts such as ApplicationMaster or reserved resources.
- The Prometheus JSON exporter used here appends `_value` to emitted scalar metric names. The examples below use the actual exported names for bridge metrics.
- `AppsPending` is the main exception to the queue-endpoint rule: it is available from native `yunikorn_queue_app` directly, or by aggregating `/ws/v1/partition/{partition}/applications/active`, but it is not currently emitted by the `yunikorn_queues` module itself.

## Coverage Summary

| Coverage | Meaning |
|---|---|
| Direct | Can be mapped 1:1 or close enough with only unit conversion |
| Derived | Can be calculated from YuniKorn metrics, but not as a native single metric |
| Unsupported | No reliable equivalent exists with the current YuniKorn data sources |

## Combined Gap Summary

This section evaluates the gap against the YARN bean list using the combined data sources that now exist in this repo:

- native YuniKorn metrics
- YuniKorn REST endpoints
- JSON-exporter bridge metrics from this repo

For the 21 YARN bean metrics in scope:

| Result | Count | Metrics |
|---|---:|---|
| Direct | 8 | `AllocatedMB`, `AllocatedVCores`, `AppsPending`, `AppsRunning`, `GuaranteedMB`, `GuaranteedVCores`, `PendingMB`, `PendingVCores` |
| Derived | 4 | `AbsoluteUsedCapacity`, `GuaranteedAbsoluteCapacity`, `MaxAbsoluteCapacity`, `PendingContainers` |
| Unsupported | 9 | `AMResourceLimitMB`, `AMResourceLimitVCores`, `AggregateContainersPreempted`, `AggregateMemoryMBPreempted`, `AggregateVcoresPreempted`, `ReservedMB`, `ReservedVCores`, `UsedAMResourceMB`, `UsedAMResourceVCores` |

Operationally, that means:

- queue capacity, allocation, pending, and running-app YARN panels are now largely reproducible
- queue absolute-capacity style panels are reproducible, but only as per-resource derived values rather than a single YARN scalar
- AM, reserved-resource, and cumulative preemption-history panels are still a real gap, not just a missing dashboard query

The important distinction is:

- `Direct` and `Derived` metrics can be implemented today with the existing native scrape plus this repo's bridge metrics
- `Unsupported` metrics are not currently blocked by dashboard work; they are blocked by missing source data or by YARN-specific semantics that do not exist in YuniKorn on Kubernetes

## Mapping Table

| YARN Metric | YuniKorn Metric / Formula | Coverage | Notes |
|---|---|---:|---|
| `beans.AMResourceLimitMB` | None | Unsupported | Re-checked against native metrics and REST endpoints: no AM-like resource pool is exposed. |
| `beans.AMResourceLimitVCores` | None | Unsupported | Same reason as above. |
| `beans.AbsoluteUsedCapacity` | `queues.absUsedCapacity.{memory,vcore}` or `100 * queue_allocated / partition_capacity` | Derived | The queue endpoint exposes per-resource absolute used capacity directly, but not a single YARN-style scalar across resources. |
| `beans.AggregateContainersPreempted` | None | Unsupported | Re-checked against the queue endpoint: only preemption settings are exposed, not cumulative preempted-container history. |
| `beans.AggregateMemoryMBPreempted` | None | Unsupported | No cumulative preempted-memory field was found in metrics or REST data. |
| `beans.AggregateVcoresPreempted` | None | Unsupported | No cumulative preempted-CPU field was found in metrics or REST data. |
| `beans.AllocatedMB` | `yunikorn_queue_resource{resource="memory",state="allocated"}` or `queues.allocatedResource.memory` | Direct | Convert bytes to MB. |
| `beans.AllocatedVCores` | `yunikorn_queue_resource{resource="vcore",state="allocated"}` or `queues.allocatedResource.vcore` | Direct | Convert millicores to vcores with `/ 1000`. |
| `beans.AppsPending` | `yunikorn_queue_app{state=~"accepted|new"}` or count of `applications/active` by `queueName` and `applicationState` | Direct | Native queue metrics support it; the queue REST endpoint does not expose a pending-app counter, but the active-app endpoint can be aggregated by queue. |
| `beans.AppsRunning` | `yunikorn_queue_app{state="running"}` or `queues.runningApps` or count of `applications/active` by `queueName` and `applicationState="Running"` | Direct | Semantics are close enough for queue-level dashboards. |
| `beans.GuaranteedAbsoluteCapacity` | `100 * queues.guaranteedResource / partition.maxResource` | Derived | No dedicated absolute guaranteed capacity field was found, but it can be derived per resource from the queue endpoint. |
| `beans.GuaranteedMB` | `yunikorn_queue_resource{resource="memory",state="guaranteed"}` or `queues.guaranteedResource.memory` | Direct | Convert bytes to MB. |
| `beans.GuaranteedVCores` | `yunikorn_queue_resource{resource="vcore",state="guaranteed"}` or `queues.guaranteedResource.vcore` | Direct | Convert millicores to vcores with `/ 1000`. |
| `beans.MaxAbsoluteCapacity` | `100 * queues.maxResource / partition.maxResource` | Derived | No dedicated absolute max capacity field was found, but it can be derived per resource from the queue endpoint. |
| `beans.PendingContainers` | `yunikorn_queue_resource{resource="pods",state="pending"}` or `queues.pendingResource.pods` | Derived | This is a Kubernetes pod approximation of YARN containers, not a strict 1:1 mapping. Good enough for queue backlog trend panels, not for exact YARN parity. |
| `beans.PendingMB` | `yunikorn_queue_resource{resource="memory",state="pending"}` or `queues.pendingResource.memory` | Direct | Convert bytes to MB. |
| `beans.PendingVCores` | `yunikorn_queue_resource{resource="vcore",state="pending"}` or `queues.pendingResource.vcore` | Direct | Convert millicores to vcores with `/ 1000`. |
| `beans.ReservedMB` | None | Unsupported | Re-checked against native metrics plus queue, partition, active-app, and completed-app endpoints: no reserved-resource field was found. |
| `beans.ReservedVCores` | None | Unsupported | Same reason as above. |
| `beans.UsedAMResourceMB` | None | Unsupported | Re-checked against native metrics and endpoints: no AM-style resource accounting is exposed because YuniKorn on Kubernetes does not expose a YARN ApplicationMaster resource model. |
| `beans.UsedAMResourceVCores` | None | Unsupported | Same reason as above. |

## JSON Exporter Metrics In This Repo

The JSON exporter modules in this repo now cover partition, queue, and application-level views.

Current JSON exporter coverage:

- Partition capacity and usage
  - `yunikorn_partition_capacity_*_value`
  - `yunikorn_partition_used_*_value`
  - `yunikorn_partition_applications_value`
- Queue resources and queue state
  - `yunikorn_queue_*_value`
- Active application usage and lifecycle
  - `yunikorn_app_used_*_value`
  - `yunikorn_app_max_used_*_value`
  - `yunikorn_app_*_timestamp_*_value`
- Completed application lifecycle and peak resource usage
  - `yunikorn_completed_app_*_value`

These are best used for:

- application scheduling wait analysis
- application runtime and completion analysis
- partition-level capacity tracking
- active and completed application drill-downs
- queue resource parity for YARN migration dashboards when combined with native `yunikorn_queue_*` metrics

They are still not sufficient for:

- reserved-resource analysis
- cumulative preemption analysis
- AM-style resource accounting

In other words, the bridge closes the lifecycle and queue-capacity gaps that native metrics alone do not cover, but it does not create missing concepts such as reserved resources, cumulative preemption history, or AM accounting.

## REST Endpoint Re-check

The queue endpoint we inspected, `/ws/v1/partition/default/queues`, exposes these fields that are useful for YARN metric migration:

- `runningApps`
- `allocatedResource`
- `pendingResource`
- `guaranteedResource`
- `maxResource`
- `absUsedCapacity`
- `headroom`
- `preemptionEnabled`, `preemptionDelay`, `quotaPreemptionDelay`

That means these YARN-style values can be backed by REST data, and the repo now exports most queue-resource values through the `yunikorn_queues` module:

- `AllocatedMB`
- `AllocatedVCores`
- `AppsPending` from `/applications/active`, grouped by `queueName`
- `AppsRunning`
- `GuaranteedMB`
- `GuaranteedVCores`
- `PendingMB`
- `PendingVCores`
- `PendingContainers`
- `AbsoluteUsedCapacity` as per-resource value
- `GuaranteedAbsoluteCapacity` as per-resource derived value
- `MaxAbsoluteCapacity` as per-resource derived value

These fields were not found in the queue REST data we inspected:

- reserved resources
- cumulative preempted counters
- AM-style resource accounting

The queue endpoint does not expose queue-level pending app counts, but `AppsPending` can still be derived from `/ws/v1/partition/{partition}/applications/active` by grouping `Accepted` and `New` states by `queueName`.

## Unsupported Metrics And Root Cause

### YARN-specific AM concepts

These metrics do not have a stable YuniKorn/Kubernetes equivalent, and no matching REST fields were found:

- `beans.AMResourceLimitMB`
- `beans.AMResourceLimitVCores`
- `beans.UsedAMResourceMB`
- `beans.UsedAMResourceVCores`

### Reserved resources

These metrics are not covered by the current native YuniKorn queue metrics, the JSON exporter modules in this repo, or the REST endpoints we inspected:

- `beans.ReservedMB`
- `beans.ReservedVCores`

### Cumulative preemption history

These metrics need historical counters that are not currently exposed in the metric set or REST endpoints we inspected:

- `beans.AggregateContainersPreempted`
- `beans.AggregateMemoryMBPreempted`
- `beans.AggregateVcoresPreempted`

## Practical Migration Guidance

If the goal is to reproduce an existing YARN queue dashboard:

1. Scrape native YuniKorn queue metrics into Prometheus, or use this repo's `yunikorn_queues` module as the queue source.
2. Keep this repo's partition and application lifecycle modules for drill-down analysis.
3. Replace direct YARN queue beans with the queue-level mappings in this document and the corresponding Grafana queries in this repo.
4. Mark AM, reserved, and cumulative preemption panels as unsupported unless a new data source is added.

If the goal is to measure the remaining gap explicitly:

1. Treat `Direct` as production-ready replacements.
2. Treat `Derived` as migration-compatible but not 1:1 semantic equivalents.
3. Treat `Unsupported` as source-data gaps, not dashboard gaps.
4. Do not promise YARN-equivalent semantics for:
   - ApplicationMaster accounting
   - reserved resources
   - cumulative preemption history

## One-line Conclusion

Directly portable:

- `Allocated*`
- `AppsPending`
- `AppsRunning`
- `Guaranteed*`
- `Pending*`

Derived but not 1:1:

- `AbsoluteUsedCapacity`
- `GuaranteedAbsoluteCapacity`
- `MaxAbsoluteCapacity`
- `PendingContainers`

Unsupported with the current data sources:

- `AM*`
- `UsedAM*`
- `Reserved*`
- `Aggregate*Preempted`
