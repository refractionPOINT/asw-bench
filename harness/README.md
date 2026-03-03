# Harness

The benchmark harness orchestrates scenario execution and evaluation.

## Components

| File | Purpose |
|------|---------|
| `run.sh` | Orchestrates Phase 1 (IaC setup) and Phase 2 (model execution via Docker) |
| `evaluate.sh` | Evaluation passthrough — records results for manual review |
| `entrypoint.sh` | Docker container entrypoint — dispatches to the correct CLI tool |

## Usage

### Running a Scenario

```bash
# Using host LC CLI credentials (~/.limacharlie):
./harness/run.sh \
  --scenario scenarios/investigation/INV-001-post-exploitation-triage \
  --cli claude \
  --oid "$LC_OID" \
  --param DETECT_ID="det:abc123"

# Or with an explicit API key:
./harness/run.sh \
  --scenario scenarios/investigation/INV-001-post-exploitation-triage \
  --cli claude \
  --oid "$LC_OID" \
  --api-key "$LC_API_KEY" \
  --param DETECT_ID="det:abc123"
```

This will:
1. Apply the scenario's `infra.yaml` to the LimaCharlie org
2. Build and run the Docker container with the specified CLI
3. Substitute `{{PARAM}}` placeholders in the prompt with provided values
4. Capture stdout output

Note: Adversary scripts must be run manually between Phase 1 and Phase 2. The run script will pause and prompt you.

### LimaCharlie Authentication

The harness supports two ways to authenticate with LimaCharlie:

1. **Host credentials (recommended):** If you're logged in via `limacharlie auth login`, the `~/.limacharlie` config file is mounted read-only into the container. No `--api-key` needed.
2. **Explicit API key:** Pass `--api-key` or set `LC_API_KEY`. This takes priority over the config file.

If you use named LC environments (`limacharlie auth use-env`), set `LC_CURRENT_ENV` to pass the active environment into the container.

### Scenario Parameters

Scenarios declare parameters in `scenario.yaml` that get substituted into `prompt.md` at runtime. Use the `--param KEY=VALUE` flag (repeatable) to pass scenario-specific values:

```bash
--param DETECT_ID="det:abc123" --param SENSOR_ID="sid:xyz"
```

The `OID` parameter is built-in and auto-populated from the `--oid` flag. See `docs/authoring-scenarios.md` for the full parameter specification.

### Evaluating Results

```bash
./harness/evaluate.sh \
  --output result-output.txt \
  --scenario scenarios/investigation/INV-001-xxx
```

In v1, this is a passthrough that formats the output alongside the evaluation rubric for manual review. Future versions will support automated scoring.

## Roadmap

- [ ] Automated trace parsing for `trace` checkpoints
- [ ] Automated string matching for `output_contains` checkpoints
- [ ] LLM-as-judge for `rubric` checkpoints
- [ ] Result aggregation and summary generation
- [ ] Adversary script automation
