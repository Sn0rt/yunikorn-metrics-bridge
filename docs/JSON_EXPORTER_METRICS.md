# JSON Exporter Metrics Reference

This document explains the secondary Prometheus metrics exported by this repo through the JSON exporter.

It is intended for reviewers who want to understand:

- which additional metrics are exported
- what each metric means
- which labels and units matter
- which limitations affect interpretation

It does not describe the internal exporter module structure.

It also does not cover native YuniKorn metrics such as:

- `yunikorn_queue_app`
- `yunikorn_queue_resource`
- `yunikorn_scheduler_*`
- `yunikorn_runtime_go_*`

Important conventions:

- The Prometheus JSON exporter appends `_value` to scalar metric names.
  Example:
  - configured metric: `yunikorn_queue_allocated_memory_bytes`
  - actual Prometheus metric: `yunikorn_queue_allocated_memory_bytes_value`
- Some metrics are conditional.
  - if the source field does not exist, no sample is emitted
  - this is normal for pending apps, incomplete lifecycle state, or sparse resource fields
- Time units are mixed because the YuniKorn REST API is mixed.
  - some timestamps are nanoseconds
  - some timestamps are milliseconds

## Application Inventory And Usage

`yunikorn_app_info_value`

- Meaning: the active application exists in the current active-application list
- Value: always `1`
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_used_memory_bytes_value`

- Meaning: current memory used by an active application
- Unit: bytes
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_used_cpu_millicores_value`

- Meaning: current CPU used by an active application
- Unit: millicores
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_used_pods_value`

- Meaning: current pod count used by an active application
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_max_used_memory_bytes_value`

- Meaning: max observed memory used by an active application
- Unit: bytes
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_max_used_cpu_millicores_value`

- Meaning: max observed CPU used by an active application
- Unit: millicores
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_max_used_pods_value`

- Meaning: max observed pod count used by an active application
- Labels:
  - `application_id`
  - `partition`
  - `queue`

## Application Lifecycle Timestamps

`yunikorn_app_submission_timestamp_nanoseconds_value`

- Meaning: active application submission time
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_start_timestamp_milliseconds_value`

- Meaning: active application start time
- Unit: milliseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_accepted_timestamp_nanoseconds_value`

- Meaning: first accepted timestamp of an active application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_app_running_timestamp_nanoseconds_value`

- Meaning: first running timestamp of an active application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`
- Limitation:
  - pending applications may not have a running timestamp yet

`yunikorn_completed_app_submission_timestamp_nanoseconds_value`

- Meaning: completed application submission time
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_accepted_timestamp_nanoseconds_value`

- Meaning: accepted timestamp of a completed application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_running_timestamp_nanoseconds_value`

- Meaning: running timestamp of a completed application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_completing_timestamp_nanoseconds_value`

- Meaning: completing timestamp of a completed application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_start_timestamp_milliseconds_value`

- Meaning: start timestamp of a completed application
- Unit: milliseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_finished_timestamp_nanoseconds_value`

- Meaning: finished timestamp of a completed application
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_completed_timestamp_nanoseconds_value`

- Meaning: completed timestamp from the completed application's lifecycle log
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`

## Allocation-Level Application View

These metrics are first-allocation views. They describe `allocations[0]`, not the full allocation set of the application.

`yunikorn_app_allocation_request_timestamp_nanoseconds_value`

- Meaning: request time of the first allocation object
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `namespace`
  - `pod_name`

`yunikorn_app_first_allocation_timestamp_nanoseconds_value`

- Meaning: allocation time of the first allocation object
- Unit: nanoseconds
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `namespace`
  - `pod_name`

`yunikorn_app_primary_allocation_memory_bytes_value`

- Meaning: memory requested/allocated by the first allocation object
- Unit: bytes
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `namespace`
  - `pod_name`

`yunikorn_app_primary_allocation_cpu_millicores_value`

- Meaning: CPU requested/allocated by the first allocation object
- Unit: millicores
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `namespace`
  - `pod_name`

`yunikorn_app_primary_allocation_pods_value`

- Meaning: pod count of the first allocation object
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `namespace`
  - `pod_name`

Important limitation:

- `namespace` and `pod_name` come from the first allocation only
- for multi-pod applications, these metrics are first-allocation views, not full-application summaries

## Completed Application Peak Usage

`yunikorn_completed_app_info_value`

- Meaning: the completed application exists in the completed-application list
- Value: always `1`
- Labels:
  - `application_id`
  - `partition`
  - `queue`
  - `application_state`

`yunikorn_completed_app_max_used_memory_bytes_value`

- Meaning: max observed memory used by a completed application
- Unit: bytes
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_max_used_cpu_millicores_value`

- Meaning: max observed CPU used by a completed application
- Unit: millicores
- Labels:
  - `application_id`
  - `partition`
  - `queue`

`yunikorn_completed_app_max_used_pods_value`

- Meaning: max observed pod count used by a completed application
- Labels:
  - `application_id`
  - `partition`
  - `queue`

## Partition Inventory And Capacity

`yunikorn_partition_info_value`

- Meaning: the partition exists
- Value: always `1`
- Labels:
  - `partition`
  - `cluster_id`
  - `state`
  - `node_sorting_policy`

`yunikorn_partition_preemption_enabled_value`

- Meaning: partition preemption enabled flag
- Labels:
  - `partition`

`yunikorn_partition_quota_preemption_enabled_value`

- Meaning: partition quota preemption enabled flag
- Labels:
  - `partition`

`yunikorn_partition_total_nodes_value`

- Meaning: total nodes in the partition
- Labels:
  - `partition`

`yunikorn_partition_total_containers_value`

- Meaning: total containers in the partition
- Labels:
  - `partition`

`yunikorn_partition_applications_value`

- Meaning: partition application count by state
- Labels:
  - `partition`
  - `application_state`
- Current exported states:
  - `total`
  - `Running`

`yunikorn_partition_capacity_memory_bytes_value`

- Meaning: total memory capacity of the partition
- Unit: bytes
- Labels:
  - `partition`

`yunikorn_partition_capacity_cpu_millicores_value`

- Meaning: total CPU capacity of the partition
- Unit: millicores
- Labels:
  - `partition`

`yunikorn_partition_capacity_pods_value`

- Meaning: total pod capacity of the partition
- Labels:
  - `partition`

`yunikorn_partition_capacity_ephemeral_storage_bytes_value`

- Meaning: total ephemeral-storage capacity of the partition
- Unit: bytes
- Labels:
  - `partition`

`yunikorn_partition_used_memory_bytes_value`

- Meaning: currently used memory in the partition
- Unit: bytes
- Labels:
  - `partition`

`yunikorn_partition_used_cpu_millicores_value`

- Meaning: currently used CPU in the partition
- Unit: millicores
- Labels:
  - `partition`

`yunikorn_partition_used_pods_value`

- Meaning: currently used pods in the partition
- Labels:
  - `partition`

`yunikorn_partition_utilization_memory_percent_value`

- Meaning: partition memory utilization percent reported by YuniKorn
- Labels:
  - `partition`

`yunikorn_partition_utilization_cpu_percent_value`

- Meaning: partition CPU utilization percent reported by YuniKorn
- Labels:
  - `partition`

`yunikorn_partition_utilization_pods_percent_value`

- Meaning: partition pod utilization percent reported by YuniKorn
- Labels:
  - `partition`

`yunikorn_partition_last_state_transition_timestamp_nanoseconds_value`

- Meaning: last partition state transition time
- Unit: nanoseconds
- Labels:
  - `partition`

## Queue Resource And Capacity Metrics

`yunikorn_queue_running_apps_value`

- Meaning: currently running applications in the queue
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_allocated_memory_bytes_value`

- Meaning: currently allocated memory in the queue
- Unit: bytes
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_allocated_cpu_millicores_value`

- Meaning: currently allocated CPU in the queue
- Unit: millicores
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_allocated_pods_value`

- Meaning: currently allocated pods in the queue
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_pending_memory_bytes_value`

- Meaning: currently pending memory in the queue
- Unit: bytes
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_pending_cpu_millicores_value`

- Meaning: currently pending CPU in the queue
- Unit: millicores
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_pending_pods_value`

- Meaning: currently pending pods in the queue
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_guaranteed_memory_bytes_value`

- Meaning: guaranteed memory configured for the queue
- Unit: bytes
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_guaranteed_cpu_millicores_value`

- Meaning: guaranteed CPU configured for the queue
- Unit: millicores
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_max_memory_bytes_value`

- Meaning: maximum memory configured for the queue
- Unit: bytes
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_max_cpu_millicores_value`

- Meaning: maximum CPU configured for the queue
- Unit: millicores
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_abs_used_capacity_memory_percent_value`

- Meaning: absolute used memory capacity percent reported by YuniKorn
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_abs_used_capacity_cpu_percent_value`

- Meaning: absolute used CPU capacity percent reported by YuniKorn
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_headroom_memory_bytes_value`

- Meaning: current memory headroom available to the queue
- Unit: bytes
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_headroom_cpu_millicores_value`

- Meaning: current CPU headroom available to the queue
- Unit: millicores
- Labels:
  - `queue`
  - `parent`
  - `partition`

## Queue Metadata And Policy

`yunikorn_queue_info_value`

- Meaning: queue metadata record
- Value: always `1`
- Labels:
  - `queue`
  - `parent`
  - `partition`
  - `status`
  - `sorting_policy`
  - `preemption_delay`
  - `quota_preemption_delay`
  - `is_leaf`
  - `is_managed`
  - `priority_sorting`
  - `is_preemption_fence`
  - `is_priority_fence`

`yunikorn_queue_preemption_enabled_value`

- Meaning: queue preemption enabled flag
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_current_priority_value`

- Meaning: raw current priority value reported by YuniKorn
- Labels:
  - `queue`
  - `parent`
  - `partition`
- Limitation:
  - some queues expose sentinel values such as `-2147483648`
  - this should be interpreted as a raw scheduler value, not as a cleaned business priority

`yunikorn_queue_priority_sorting_enabled_value`

- Meaning: priority sorting enabled flag
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_is_leaf_value`

- Meaning: whether the queue is a leaf queue
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_is_managed_value`

- Meaning: whether the queue is a managed queue
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_is_preemption_fence_value`

- Meaning: whether the queue is a preemption fence
- Labels:
  - `queue`
  - `parent`
  - `partition`

`yunikorn_queue_is_priority_fence_value`

- Meaning: whether the queue is a priority fence
- Labels:
  - `queue`
  - `parent`
  - `partition`

## Important Non-Metrics

These values are relevant to YARN comparison, but are not directly emitted by the JSON-exporter bridge as standalone queue metrics today:

- queue-level pending application count
  - use native `yunikorn_queue_app{state=~"accepted|new"}`
  - or aggregate `/applications/active` by `queueName`

## Known Limitations

### Mixed time units

The YuniKorn REST API mixes milliseconds and nanoseconds.

Current bridge behavior preserves source units:

- `*_timestamp_nanoseconds_value`
- `*_timestamp_milliseconds_value`

### Sparse fields are normal

The exporter only emits a sample if the source field exists.

This is expected for:

- pending apps with no `Running` state yet
- apps with no allocation yet
- completed apps whose `maxUsedResource` does not include every resource dimension

### Queue metrics are partition-fixed

The queue metrics in this repo currently emit:

- `partition="default"`

This matches the current single-partition deployment model.
