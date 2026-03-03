# How ASW-Bench Works

## Overview

Each benchmark scenario tests a frontier AI model's ability to perform a specific security operations task using LimaCharlie tools. The execution follows two phases: environment setup, then model execution.

## Phase 1: Environment Setup

Before the model runs, the scenario's environment must be prepared in a LimaCharlie organization.

### 1.1 Apply Infrastructure

Each scenario includes an `infra.yaml` file in [LimaCharlie IaC v3 format](https://doc.limacharlie.io/docs/documentation/docs/infra-as-code.md). This defines the detection rules, sensors, lookups, and other resources needed for the scenario.

```bash
export LC_OID="your-org-id"
export LC_API_KEY="your-api-key"

limacharlie sync push --config-file scenarios/investigation/INV-001-xxx/infra.yaml --all
```

Use `--dry-run` first to preview changes:

```bash
limacharlie sync push --config-file scenarios/investigation/INV-001-xxx/infra.yaml --all --dry-run
```

### 1.2 Execute Adversary Activity

Each scenario includes adversary scripts in the `adversary/` directory that simulate the malicious activity the model will investigate. These scripts are documented and meant to be run manually (automation is planned for future versions).

Read the scenario's `adversary/README.md` for execution instructions and prerequisites.

```bash
cd scenarios/investigation/INV-001-xxx/adversary
# Review what the scripts do
cat README.md
# Execute
bash run.sh
```

## Phase 2: Model Execution

Once the environment is prepared, the model is given the scenario's prompt and access to LimaCharlie tools.

### 2.1 Build the Container

The benchmark container packages all supported frontier model CLIs alongside the LimaCharlie CLI:

```bash
docker build -t asw-bench .
```

The container includes:
- **Claude Code** (Anthropic)
- **OpenAI CLI** (OpenAI)
- **Gemini CLI** (Google)
- **LimaCharlie CLI** (`limacharlie`)

### 2.2 Run the Model

The container takes the CLI tool name and prompt file as arguments. Authentication is provided via environment variables or mounted credentials.

**With API key:**
```bash
docker run \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli claude --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md
```

**With Claude Code subscription (Pro/Max):**
```bash
docker run \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  -v ~/.claude.json:/root/.claude.json:ro \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli claude --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md
```

> **Note:** Subscription OAuth tokens may expire on long-running benchmarks (~15 min).
> The harness detects mounted credentials automatically and will warn about this limitation.
> If auth fails mid-run, switch to an API key.

Supported `--cli` values:
- `claude` — Uses Claude Code (API key or subscription)
- `openai` — Uses OpenAI Codex CLI
- `gemini` — Uses Gemini CLI

The model receives the prompt and has access to the LimaCharlie CLI/MCP tools to interact with the prepared environment. All output goes to stdout.

### 2.3 Using the Harness Script

For convenience, the harness run script orchestrates both phases:

```bash
./harness/run.sh \
  --scenario scenarios/investigation/INV-001-xxx \
  --cli claude \
  --oid "$LC_OID" \
  --api-key "$LC_API_KEY"
```

## Evaluation

### Current (v1): Manual Review

After the model run, compare the output against the scenario's `evaluation.yaml`. This file contains checkpoints — specific things the model should have done or identified — with point values.

Checkpoint types:
- **`trace`** — Did the model call a specific tool?
- **`output_contains`** — Does the output contain an expected value?
- **`rubric`** — Free-text rubric for human judgment (supports partial credit)

```bash
# Review the rubric
cat scenarios/investigation/INV-001-xxx/evaluation.yaml

# Run the evaluation passthrough (records the result)
./harness/evaluate.sh --result output.txt --scenario scenarios/investigation/INV-001-xxx
```

### Future: Automated Scoring

The evaluation harness is designed with a passthrough step that will support automated scoring in future versions, including LLM-as-judge for rubric-based checkpoints and API-based verification of trace checkpoints.

## Cleanup

After a benchmark run, clean up the LimaCharlie org:

```bash
limacharlie sync push --config-file scenarios/investigation/INV-001-xxx/infra.yaml --all --force
```

The `--force` flag removes resources in the cloud that are not in the local file, effectively resetting the org to a clean state. Be careful with this in shared orgs — it's best to use a dedicated org for benchmarking.
