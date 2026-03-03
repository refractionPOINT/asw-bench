# ASW-Bench Development Guide

## Project Overview

ASW-Bench (Agentic SecOps Workspace Benchmark) is a set of open-source reference benchmarks for evaluating how frontier AI models operate modern security operations tools for investigation and response. It uses LimaCharlie as the standardized security operations platform.

## Architecture

Two-phase benchmark execution:

1. **Phase 1 - Environment Setup:** Apply LC IaC v3 template to a pre-created LimaCharlie org, then run adversary scripts to create the activity the model will investigate.
2. **Phase 2 - Model Execution:** Launch a Docker container (`Dockerfile` at repo root) containing frontier model CLIs (Claude Code, OpenAI Codex, Gemini) + LimaCharlie CLI. The container runs the model with the benchmark prompt and collects output via stdout.

## Key Directories

- `scenarios/` — Benchmark scenarios organized by category (investigation, response, etc.)
- `scenarios/investigation/INV-NNN-<name>/` — Individual benchmarks with scenario.yaml, prompt.md, infra.yaml, adversary/, evaluation.yaml
- `harness/` — Run scripts (run.sh, evaluate.sh, entrypoint.sh)
- `results/` — Benchmark results (official/ and community/)
- `docs/` — Architecture docs, authoring guide, scoring methodology

## Scenario Numbering

Benchmarks are numbered by category prefix: `INV-` (investigation), `RSP-` (response), `THT-` (threat-hunting), `DET-` (detection-engineering), `AUT-` (automation). Numbers are permanent and never reused.

## LimaCharlie IaC

Scenario `infra.yaml` files use LimaCharlie IaC v3 format. Push with: `limacharlie sync push --config-file infra.yaml --all`. Test with `--dry-run` first. The LC CLI is installed via `pip install limacharlie`.

## Key Technologies

- **LimaCharlie** — Security operations platform (EDR, detection rules, ticketing, LCQL queries)
- **Docker** — Benchmark execution container
- **Shell scripts** — Harness orchestration (bash)
- **PowerShell** — Windows adversary and user simulation scripts
- **YAML** — Scenario configs, IaC templates, evaluation rubrics

## Testing

No automated tests yet. Validate scenarios with:
- `limacharlie sync push --config-file <infra.yaml> --all --dry-run` for IaC templates
- `shellcheck harness/*.sh` for shell scripts
- `docker build -t asw-bench .` for the container

## Conventions

- Evaluation is ticket-based: the model creates a LimaCharlie Ticket documenting its investigation, and scoring is based on ticket quality (entities, notes, summary, classification).
- Adversary scripts document the malicious behavior but are run manually (not by the harness).
- User simulation scripts create realistic background noise.
- All model output goes to stdout for collection.
- Auth is provided via environment variables during Docker container creation.
