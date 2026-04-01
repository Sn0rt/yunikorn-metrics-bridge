# Lifecycle Metric Design

This document defines the reviewer-facing lifecycle metric model for YuniKorn application state history.

It is a design and semantics document, not a list of currently emitted JSON-exporter metrics. It exists because YuniKorn `stateLog` is an append-only history of state-entry events, and a lifecycle can legitimately contain repeated states such as:

```text
submission -> accepted -> running -> completing -> running -> completing -> completed -> finished
```

That means lifecycle metrics must be defined by semantics, not by fixed `stateLog` positions.

## Designed Primary Metric Set

The current lifecycle design keeps these as the primary semantic metric set:

- `submission_to_finished_duration`
  - Meaning: full wall-clock job time
  - Definition: `finishedTime - submissionTime`
  - Use when the question is: "How long did the whole job take?"

- `accepted_to_completed_duration`
  - Meaning: scheduler-visible lifecycle duration
  - Definition: `completed_state_time - accepted_state_time`
  - Use when the question is: "How long did the app spend in the accepted-to-completed lifecycle?"
  - Note: this excludes the earlier `submission -> accepted` segment

- `running_transition_count`
  - Meaning: number of times the application entered `Running`
  - Definition: count of `stateLog` entries whose `applicationState` is `Running`
  - Use when the question is: "Did this app re-enter execution multiple times?"

## First Implemented Metric Set

The first implementation set currently exposes these lifecycle durations through Grafana/PromQL using the raw JSON-exporter timestamp metrics:

- `submission -> finished`
  - derived from `submissionTime -> finishedTime`

- `accepted -> completed`
  - derived from `accepted -> completed`

The first implementation set intentionally does **not** expose:

- `running_transition_count`
  - deferred until a richer transformation layer exists

## Candidate And Deferred Metrics

These metrics are intentionally not part of the primary set yet.

- `accepted_to_first_running_duration`
  - Candidate only
  - Intended meaning: first scheduling wait before the app first starts running
  - Reason not primary yet:
    - existing dashboards already have stable scheduling-wait views based on `startTime`
    - it is useful, but not yet clearly distinct enough to be required everywhere

- `total_running_wall_time`
  - Deferred
  - Intended meaning: sum of all `Running -> next state` intervals
  - Example:

    ```text
    accepted -> running -> completing -> running -> completing -> completed
                 └───────┘              └───────┘

    total_running_wall_time =
      (running #1 -> completing #1) +
      (running #2 -> completing #2)
    ```

  - Reason deferred:
    - semantically valid
    - but not a good fit for the current JSON-exporter configuration, which is field-extraction-oriented rather than interval-folding-oriented

- `completing_transition_count`
  - Excluded from the first implementation set
  - Reason:
    - likely correlated with `running_transition_count`
    - no strong reviewer-facing value has been established yet

## Source Mapping

Approved lifecycle metrics map to YuniKorn source data like this:

| Metric | Source fields / events | Notes |
|---|---|---|
| `submission_to_finished_duration` | `submissionTime`, `finishedTime` | Most stable total duration metric |
| `accepted_to_completed_duration` | `stateLog(applicationState=Accepted)`, `stateLog(applicationState=Completed)` | Lifecycle duration inside the scheduler-visible path |
| `running_transition_count` | `stateLog(applicationState=Running)` | Count metric, not a duration |

Important distinction:

- `finishedTime` is a dedicated field
- `Completed` is a lifecycle state entry in `stateLog`
- they are close in meaning, but not the same source

For repeated-state metrics:

- duration metrics must define whether they use:
  - first occurrence
  - last occurrence
  - sum of intervals
- count metrics must define the counted state explicitly

## Current Implementation Fit

Fit for the current `prometheus-json-exporter` layer:

- Good fit:
  - field-based durations using dedicated fields
  - single-state timestamp extraction when semantics are clear
  - state-entry counting, if a counting layer is added outside pure scalar extraction

- Poor fit:
  - interval folding across repeated states
  - metrics that require pairing one `Running` entry with the next non-`Running` entry
  - metrics that require multiple passes over the same `stateLog`

This means:

- `submission_to_finished_duration` is implementation-friendly
- `accepted_to_completed_duration` is feasible if the accepted and completed entries are extracted clearly
- `running_transition_count` is conceptually simple but may require a richer transformation layer than the current scalar JSON-exporter config
- `total_running_wall_time` should not be forced into the current exporter design

## Reviewer Guidance

Use these questions to choose the right lifecycle metric:

- "How long did the whole job take?"
  - `submission_to_finished_duration`

- "How long was the app in the accepted-to-completed lifecycle?"
  - `accepted_to_completed_duration`

- "Did the app bounce back into running multiple times?"
  - `running_transition_count`

Do not use:

- raw `stateLog` timestamps as a reviewer-facing metric by themselves
- sums of raw timestamps
- fixed index assumptions such as `stateLog[1] == Running`

## Validation Plan

Any future implementation of these metrics should validate at least these lifecycle shapes:

1. Linear lifecycle

```text
accepted -> running -> completing -> completed
```

2. Repeated running lifecycle

```text
accepted -> running -> completing -> running -> completing -> completed
```

3. Sparse lifecycle with missing optional states

```text
accepted -> completed
```

Validation should confirm:

- total wall-clock duration still renders
- accepted lifecycle duration remains attributable
- repeated `Running` entries increase `running_transition_count`
- repeated-state metrics do not fall back to fixed-index assumptions
