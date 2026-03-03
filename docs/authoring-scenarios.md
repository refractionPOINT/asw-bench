# Authoring Scenarios

This guide covers how to create a new benchmark scenario for ASW-Bench.

## Directory Structure

Create a new directory under the appropriate category:

```
scenarios/<category>/<PREFIX>-<NNN>-<short-name>/
├── scenario.yaml       # Required: Metadata
├── prompt.md           # Required: Model prompt
├── infra.yaml          # Required: LimaCharlie IaC template
├── adversary/          # Required: Adversary behavior
│   ├── README.md       # Required: Description and instructions
│   └── run.sh          # Required: Execution script
├── evaluation.yaml     # Required: Scoring rubric
└── data/               # Optional: Supplementary data
```

## File Schemas

### scenario.yaml

```yaml
# Unique identifier (must match directory name prefix)
id: "INV-001"

# Semantic version — increment when the scenario changes materially
version: "1.0"

# Human-readable name
name: "Detect Lateral Movement via SMB"

# Detailed description of what this scenario tests
description: >
  Given a detection alert for suspicious SMB connections, the model must
  investigate the source host, determine if lateral movement occurred,
  and identify all affected systems.

# Must match parent directory
category: investigation

# easy: straightforward single-tool tasks
# medium: multi-step investigation requiring 3-5 tool calls
# hard: complex scenarios requiring correlation across multiple data sources
# expert: ambiguous scenarios requiring deep reasoning and creative tool use
difficulty: medium

# Freeform tags for filtering and discovery
tags:
  - lateral-movement
  - smb
  - network-analysis

# Scenario parameters — substituted into prompt.md at runtime
# See "Prompt Parameters" section below for details.
parameters:
  - name: OID
    description: LimaCharlie organization ID
    required: true
    builtin: true    # auto-populated by harness from --oid
  - name: DETECT_ID
    description: Detection ID to investigate
    required: true

# LimaCharlie MCP tools the scenario is designed to exercise
# (informational — the model is not restricted to these)
tools_required:
  - get_detection
  - get_historic_events
  - run_lcql_query
  - get_network_connections

# Attribution
author: refractionPOINT
created: "2026-02-28"
```

### prompt.md

The exact text sent to the model. Write it as if briefing an analyst.

Guidelines:
- Be specific about what the model should investigate or accomplish
- Include any context it would need (alert details, host names, time windows)
- Use placeholders for values that are filled during setup (e.g., sensor IDs)
- Do not include hints about which tools to use — the model should decide
- End with clear deliverables (what the model should produce)

Example:

```markdown
You are a security analyst using LimaCharlie to investigate a detection.

The following detection was triggered:

**Detection: SMB Lateral Movement Detected**
- Sensor: `web-server-prod-03`
- Time: 2026-02-28T10:15:00Z
- Rule: `lateral-movement-smb-admin-share`

Your tasks:
1. Retrieve the full detection details and associated events
2. Identify the source IP and destination hosts involved
3. Determine the attack technique used
4. List all affected systems
5. Provide a verdict (true positive / false positive) with confidence level and evidence
```

### Prompt Parameters

Prompts use `{{PARAM_NAME}}` placeholders (mustache-style) for values that vary between runs. Parameters are declared in `scenario.yaml` and substituted at runtime by the harness.

#### How it works

1. **Declare** parameters in `scenario.yaml` under the `parameters:` key.
2. **Use** `{{PARAM_NAME}}` in `prompt.md` wherever the value should appear.
3. **Pass** values at runtime with `--param KEY=VALUE` on the `run.sh` command line.
4. The entrypoint substitutes all `{{...}}` placeholders before sending the prompt to the model. Any unresolved placeholders cause an error.

#### Parameter fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Parameter name — must match the placeholder in `prompt.md` (e.g. `DETECT_ID` for `{{DETECT_ID}}`) |
| `description` | Yes | Human-readable description |
| `required` | Yes | Whether the parameter must be provided |
| `builtin` | No | If `true`, the harness auto-populates this from existing flags (e.g. `OID` from `--oid`) |

#### Built-in parameters

| Name | Source |
|------|--------|
| `OID` | `--oid` flag or `LC_OID` env var |

Built-in parameters are always set automatically. You do not need to pass them with `--param`.

#### Example

`scenario.yaml`:
```yaml
parameters:
  - name: OID
    description: LimaCharlie organization ID
    required: true
    builtin: true
  - name: DETECT_ID
    description: Detection ID to investigate
    required: true
```

`prompt.md`:
```markdown
Investigate detection `{{DETECT_ID}}` in organization `{{OID}}`.
```

Run command:
```bash
./harness/run.sh \
  --scenario scenarios/investigation/INV-001-post-exploitation-triage \
  --cli claude \
  --oid "$LC_OID" \
  --api-key "$LC_API_KEY" \
  --param DETECT_ID="det:abc123"
```

### infra.yaml

LimaCharlie Infrastructure-as-Code v3 format. This is applied to the org before the benchmark runs.

```yaml
version: 3

hives:
  dr-general:
    lateral-movement-smb-admin-share:
      detect:
        op: ends with
        event: NEW_PROCESS
        path: event/FILE_PATH
        value: evil.exe
      respond:
        - action: report
          name: lateral-movement-detected

  cloud_sensor:
    web-server-prod-03:
      # Cloud sensor configuration

  lookup:
    known-bad-ips:
      # Lookup table data

installation_keys:
  - desc: benchmark-sensor
    tags:
      - benchmark
```

Test your IaC before submitting:

```bash
limacharlie sync push --config-file infra.yaml --all --dry-run
```

### adversary/

The `adversary/` directory contains scripts that demonstrate the malicious behavior the model will investigate. These are not run automatically by the harness in v1 — they document and enable the manual setup.

**adversary/README.md** should describe:
- What the scripts simulate
- Prerequisites (running sensor, network access, etc.)
- Execution order
- Expected observable artifacts (events, detections, etc.)

**adversary/run.sh** should be a standalone executable script. Include comments explaining each step.

### evaluation.yaml

Defines how the model's output is scored.

```yaml
# Total points available
total_points: 100

checkpoints:
  # Trace check: did the model call a specific tool?
  - id: "retrieved_detection"
    description: "Model retrieved the full detection details"
    type: trace
    tool_called: get_detection
    points: 15

  # Output check: does the output contain an expected value?
  - id: "identified_source_ip"
    description: "Model correctly identified the source IP"
    type: output_contains
    expected_value: "10.0.1.50"
    case_insensitive: false
    points: 20

  # Rubric check: human judgment with optional partial credit
  - id: "listed_affected_systems"
    description: "Model identified all affected systems"
    type: rubric
    rubric: >
      The model should identify web-server-prod-03, db-server-prod-01,
      and file-server-prod-02 as affected. Award partial credit for
      identifying 2 of 3 systems.
    points: 25
    partial_credit: true

  # Rubric check: reasoning quality
  - id: "evidence_chain"
    description: "Model provided coherent evidence chain for verdict"
    type: rubric
    rubric: >
      The model should cite specific events, timestamps, and indicators
      that support its verdict. The reasoning should be logical and
      reference actual data from the investigation.
    points: 20
```

### Checkpoint Types

| Type | Automated | Description |
|------|-----------|-------------|
| `trace` | Yes (future) | Checks if a specific LimaCharlie tool was called during execution |
| `output_contains` | Yes (future) | Checks if the model's output contains an expected string |
| `rubric` | No (human review) | Free-text rubric for qualitative assessment |

In v1, all scoring is manual. The `trace` and `output_contains` types document the intent for future automation.

## Difficulty Guidelines

| Level | Tool Calls | Description |
|-------|-----------|-------------|
| Easy | 1-2 | Single-step lookup or retrieval |
| Medium | 3-5 | Multi-step investigation with correlation |
| Hard | 5-10 | Complex scenario requiring multiple data sources and reasoning |
| Expert | 10+ | Ambiguous scenario with incomplete data requiring creative approaches |

## Submission Checklist

- [ ] `scenario.yaml` has all required fields and valid values
- [ ] `prompt.md` is self-contained and does not hint at tools
- [ ] `prompt.md` uses `{{PARAM}}` syntax for all variable values (no ad-hoc placeholders)
- [ ] `scenario.yaml` declares all parameters used in `prompt.md`
- [ ] `infra.yaml` is valid LC IaC v3 (passes `--dry-run`)
- [ ] `adversary/README.md` clearly describes the simulated behavior
- [ ] `adversary/run.sh` is executable and commented
- [ ] `evaluation.yaml` has clear, unambiguous checkpoints
- [ ] Total points add up correctly
- [ ] Tested against at least one model to validate difficulty rating
