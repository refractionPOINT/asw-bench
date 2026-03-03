# ASW-Bench

**Agentic SecOps Workspace Benchmark**

A set of open-source reference benchmarks for evaluating how frontier AI models can operate modern security operations tools for investigation and response.

## Why This Exists

There are benchmarks for cybersecurity knowledge. There are companies building proprietary models and black boxes to do SOC work. But there are no public, general-purpose benchmarks that compare frontier models **as-is** — with minimal customization — on their ability to actually **operate** in complex security environments.

ASW-Bench fills that gap. These benchmarks test whether a model can use real security tooling to investigate alerts, hunt for threats, and respond to incidents — not whether it can answer trivia questions about CVEs.

## Design Principles

- **Real operations, not trivia.** Benchmarks test operational capability: using tools, querying data, making decisions under uncertainty.
- **Transparency.** [LimaCharlie](https://limacharlie.io) is used as the security operations platform. It provides a single streamlined environment with most capabilities built-in, without assembling 20 moving-target OSS products. There is no black box — all platform behavior is observable and documented.
- **Reproducibility.** Each scenario uses LimaCharlie Infrastructure-as-Code to define the environment, a Docker container to run the model, and documented adversary scripts. Anyone can reproduce any benchmark run.
- **Minimal customization.** Models are tested as-is with their standard tool-use capabilities. No fine-tuning, no custom scaffolding, no prompt chains. Just a model, a prompt, and access to security tools.

## How It Works

Each benchmark runs in two phases:

```
Phase 1: Environment Setup
┌─────────────────────────────────────────────────────┐
│  1. Apply LC IaC template to a LimaCharlie org      │
│  2. Execute adversary scripts (malicious activity)  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
Phase 2: Model Execution
┌─────────────────────────────────────────────────────┐
│  1. Launch Docker container with model CLI + LC CLI │
│  2. Pass benchmark prompt to the model              │
│  3. Model uses LC tools to investigate/respond      │
│  4. Collect output (stdout)                         │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
Evaluation
┌─────────────────────────────────────────────────────┐
│  Score output against scenario rubric               │
│  (manual review in v1, automated scoring planned)   │
└─────────────────────────────────────────────────────┘
```

See [docs/how-it-works.md](docs/how-it-works.md) for the full architecture.

## Scenario Categories

| Category | Prefix | Description | Status |
|----------|--------|-------------|--------|
| Investigation | `INV-` | Triage alerts, investigate incidents, determine scope | Active |
| Response | `RSP-` | Contain threats, isolate hosts, remediate | Planned |
| Threat Hunting | `THT-` | Proactively search for indicators and TTPs | Planned |
| Detection Engineering | `DET-` | Write and tune detection rules | Planned |
| Automation | `AUT-` | Build automated response workflows | Planned |

### Investigation Scenarios

| ID | Name | Difficulty | Status |
|----|------|-----------|--------|
| INV-001 | [Post-Exploitation Attack Investigation](scenarios/investigation/INV-001-post-exploitation-triage/) | Medium | Ready |

## Quick Start

### Prerequisites

- A [LimaCharlie](https://limacharlie.io) organization (free tier works)
- LimaCharlie CLI: `pip install limacharlie`
- Docker
- API key for the model you want to benchmark, or a Claude Code subscription (Pro/Max)

### Running a Benchmark

**Phase 1 — Set up the environment:**

```bash
# Configure LC CLI
export LC_OID="your-org-id"
export LC_API_KEY="your-api-key"

# Apply the scenario's infrastructure
limacharlie sync push --config-file scenarios/investigation/INV-001-xxx/infra.yaml --all

# Run the adversary scripts (see scenario's adversary/README.md for details)
```

**Phase 2 — Run the model:**

```bash
# Build the benchmark container
docker build -t asw-bench .

# Run with Claude (API key)
docker run \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli claude --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md

# Run with Claude (subscription — mount credentials from 'claude login')
docker run \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  -v ~/.claude.json:/root/.claude.json:ro \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli claude --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md

# Run with OpenAI (API key)
docker run \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli openai --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md

# Run with OpenAI (subscription — mount credentials from 'codex login')
docker run \
  -v ~/.codex/auth.json:/home/ubuntu/.codex/auth.json:ro \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli openai --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md

# Run with Gemini (API key)
docker run \
  -e GOOGLE_API_KEY="$GOOGLE_API_KEY" \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli gemini --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md

# Run with Gemini (subscription — mount credentials from 'gemini' login)
docker run \
  -v ~/.gemini:/home/ubuntu/.gemini \
  -e LC_OID="$LC_OID" \
  -e LC_API_KEY="$LC_API_KEY" \
  asw-bench --cli gemini --prompt-file /scenarios/investigation/INV-001-xxx/prompt.md
```

> **Note:** When using subscription credentials, OAuth tokens may expire on
> long-running benchmarks (~15 min). If you hit auth errors mid-run, switch to an API key.

**Evaluate:**

```bash
# Review output against the scenario's evaluation rubric
cat scenarios/investigation/INV-001-xxx/evaluation.yaml
```

See [docs/how-it-works.md](docs/how-it-works.md) for the full walkthrough.

## Results

### Latest Scores (INV-001: Post-Exploitation Attack Investigation)

| Model | Score | Beacon | C2 | Creds | Persistence | Lateral Mvmt | Exfil | Defense Evasion | Scope | Narrative | MITRE |
|-------|-------|--------|-----|-------|-------------|--------------|-------|-----------------|-------|-----------|-------|
| **Claude Opus 4.6** | **87/100** | 10/10 | 10/10 | 10/10 | 7/10 | 10/10 | 0/10 | 5/5 | 10/10 | 10/10 | 5/5 |
| **Claude Sonnet 4.6** | **84/100** | 10/10 | 10/10 | 10/10 | 4/10 | 10/10 | 0/10 | 5/5 | 10/10 | 10/10 | 5/5 |
| **OpenAI gpt-5.3-codex** | **61/100** | 10/10 | 10/10 | 0/10 | 4/10 | 5/10 | 0/10 | 0/5 | 10/10 | 10/10 | 2/5 |
| **Google gemini-3-flash-preview** | **63/100** | 10/10 | 10/10 | 0/10 | 6/10 | 0/10 | 0/10 | 5/5 | 10/10 | 10/10 | 2/5 |

All four models correctly identified the malicious beacon and C2 channel. Claude Opus and Sonnet investigated most deeply — both discovered credential theft (LSASS + SAM/SYSTEM dumps), lateral movement (ARP/ping sweep + SMB enumeration), and event log clearing, producing comprehensive attack narratives with full MITRE mappings. Google Gemini identified the beacon, C2, WMI and scheduled task persistence, event log clearing on a second host, and produced a coherent multi-phase attack narrative with remediation steps — but did not discover credential access or lateral movement. OpenAI Codex identified the beacon, C2, WMI persistence behavior (wmiprvse.exe re-execution), and SMB reconnaissance (net view against internal hosts), producing a multi-phase attack narrative with specific remediation steps — but did not discover credential access, event log clearing, or ARP/ping sweep activity. No model discovered the DNS exfiltration or data staging activity.

Full per-checkpoint breakdowns, raw output logs, exported tickets, and ticket reports are in the [results/](results/) directory.

## Contributing

We welcome contributions of new scenarios, results, and improvements to the harness. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Citation

If you use ASW-Bench in your research, please cite:

```bibtex
@software{asw-bench,
  title     = {ASW-Bench: Agentic SecOps Workspace Benchmark},
  author    = {refractionPOINT},
  year      = {2026},
  url       = {https://github.com/refractionPOINT/asw-bench},
  license   = {Apache-2.0}
}
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
