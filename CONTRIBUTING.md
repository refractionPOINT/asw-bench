# Contributing to ASW-Bench

We welcome contributions of new scenarios, benchmark results, and improvements to the harness.

## Adding a New Scenario

Each scenario lives in its own numbered directory under the appropriate category:

```
scenarios/<category>/<PREFIX>-<NNN>-<short-name>/
```

### Numbering

- Use the next available number in the category sequence
- Prefixes by category: `INV-` (investigation), `RSP-` (response), `THT-` (threat-hunting), `DET-` (detection-engineering), `AUT-` (automation)
- Numbers are permanent — retired scenarios keep their number

### Required Files

Every scenario must include:

| File | Purpose |
|------|---------|
| `scenario.yaml` | Metadata: id, name, description, difficulty, tags, tools required |
| `prompt.md` | The exact prompt given to the model |
| `infra.yaml` | LimaCharlie IaC v3 template for environment setup |
| `evaluation.yaml` | Scoring rubric with checkpoints |
| `adversary/README.md` | Description of the adversary behavior |
| `adversary/run.sh` | Script demonstrating the malicious activity |

Optional:
- `adversary/run.ps1` — Windows variant of the adversary script
- `data/` — Supplementary data files referenced by the scenario

See [docs/authoring-scenarios.md](docs/authoring-scenarios.md) for the full authoring guide with schemas and examples.

### Quality Checklist

Before submitting a scenario PR:

- [ ] `scenario.yaml` has all required fields
- [ ] `infra.yaml` is valid LC IaC v3 (test with `limacharlie sync push --dry-run`)
- [ ] `prompt.md` is self-contained — the model should not need external context
- [ ] `evaluation.yaml` has clear checkpoints with unambiguous rubrics
- [ ] Adversary scripts are documented and reproducible
- [ ] Difficulty rating is reasonable (test with at least one model)

## Submitting Results

Results from benchmark runs can be submitted via PR to the `results/` directory. See [results/README.md](results/README.md) for the expected format.

### Requirements

- Include the full model name and version
- Include execution metrics (duration, tool calls, cost estimate)
- Include the raw output (stdout capture)
- Results must be reproducible — anyone should be able to re-run and get comparable outcomes

## Development

### Repository Structure

```
docs/           — Documentation
scenarios/      — Benchmark scenarios
harness/        — Run and evaluation scripts
results/        — Benchmark results
```

### Running Locally

See [README.md](README.md) for quick start instructions.

## Code of Conduct

Be respectful. Focus on improving the benchmarks. Security research should be conducted responsibly.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
