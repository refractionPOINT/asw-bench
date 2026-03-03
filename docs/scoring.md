# Scoring Methodology

## Overview

ASW-Bench uses checkpoint-based scoring. Each scenario defines a set of checkpoints — specific things the model should do or identify — each worth a defined number of points. The final score is earned points divided by total points.

## Checkpoint Types

### Trace Checks (`type: trace`)

Verify that the model called a specific LimaCharlie tool during its investigation.

```yaml
- id: "used_lcql"
  type: trace
  tool_called: run_lcql_query
  points: 15
```

This tests whether the model knows to use the right tools for the job. A model that reaches the right conclusion without using the expected tools still loses these points — the benchmark values operational competence, not just correct answers.

**v1:** Scored manually by reviewing the model's output for tool invocations.
**Future:** Automated by parsing the execution trace.

### Output Checks (`type: output_contains`)

Verify that the model's output contains a specific expected value.

```yaml
- id: "identified_source_ip"
  type: output_contains
  expected_value: "10.0.1.50"
  case_insensitive: false
  points: 20
```

**v1:** Scored manually by searching the output.
**Future:** Automated string matching.

### Rubric Checks (`type: rubric`)

Qualitative assessment against a free-text rubric. These capture the nuance that automated checks cannot.

```yaml
- id: "evidence_chain"
  type: rubric
  rubric: >
    The model should cite specific events, timestamps, and indicators
    that support its verdict. Reasoning should be logical and reference
    actual data.
  points: 20
  partial_credit: true
```

When `partial_credit: true`, the reviewer may award a fraction of the points based on the quality of the response.

**v1:** Scored by human reviewers.
**Future:** LLM-as-judge with the rubric as grading instructions.

## Scoring Formula

```
scenario_score = earned_points / total_points
```

For aggregate scoring across scenarios:

```
category_score = mean(scenario_scores in category)
overall_score  = mean(all scenario_scores)
```

Scores are reported as percentages (0-100%).

## What Gets Measured

Each benchmark run captures:

| Metric | Description |
|--------|-------------|
| **Score** | Points earned vs. total (percentage) |
| **Duration** | Wall-clock time for the model to complete |
| **Tool Calls** | Number of LimaCharlie tool invocations |
| **Token Usage** | Input and output tokens consumed |
| **Estimated Cost** | Approximate API cost in USD |

These metrics together paint a picture of both effectiveness (score) and efficiency (cost, time, tool usage).

## Interpreting Results

- **High score, low cost:** The model is effective and efficient.
- **High score, high cost:** The model gets results but is expensive (may be over-querying or verbose).
- **Low score, many tool calls:** The model is active but ineffective — it may be using the wrong tools or misinterpreting results.
- **Low score, few tool calls:** The model may not know how to use the tools or gave up early.

## Fairness Considerations

- All models receive the identical prompt with no model-specific tuning.
- All models have access to the same LimaCharlie tools and documentation.
- Temperature is set to 0 for reproducibility (unless the scenario specifies otherwise).
- Scenarios are designed to have clear expected outcomes, minimizing subjective judgment.
- Rubric checkpoints include detailed criteria to reduce reviewer bias.
