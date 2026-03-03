# Scenarios

Benchmark scenarios are organized by category and numbered for stable identification.

## Categories

| Category | Prefix | Directory | Description |
|----------|--------|-----------|-------------|
| Investigation | `INV-` | `investigation/` | Triage alerts, investigate incidents, determine blast radius |
| Response | `RSP-` | `response/` | Contain threats, isolate hosts, apply remediations |
| Threat Hunting | `THT-` | `threat-hunting/` | Proactively search for indicators and TTPs |
| Detection Engineering | `DET-` | `detection-engineering/` | Write, test, and tune detection rules |
| Automation | `AUT-` | `automation/` | Build automated response and enrichment workflows |

Only **Investigation** is active in v1. Other categories are planned.

## Numbering Convention

Each scenario gets a permanent identifier: `<PREFIX>-<NNN>-<short-name>`

Examples:
- `INV-001-lateral-movement-smb`
- `INV-002-phishing-triage`
- `RSP-001-isolate-compromised-host`

Numbers are never reused. If a scenario is retired, its number is kept and the scenario is marked as deprecated in `scenario.yaml`.

## Scenario Structure

Each scenario directory contains:

```
INV-001-example/
├── scenario.yaml       # Metadata
├── prompt.md           # Prompt sent to the model
├── infra.yaml          # LimaCharlie IaC v3 template
├── adversary/          # Scripts for malicious activity
│   ├── README.md       # What the scripts do
│   └── run.sh          # Execution script
├── evaluation.yaml     # Scoring rubric
└── data/               # Supplementary data (optional)
```

See [../docs/authoring-scenarios.md](../docs/authoring-scenarios.md) for the full schema reference.

## Scenario Index

### Investigation

| ID | Name | Difficulty |
|----|------|-----------|
| INV-001 | Post-Exploitation Attack Investigation | Hard |
