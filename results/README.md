# Results

Benchmark results are stored here, organized by run.

## Directory Structure

```
results/
├── official/                              # Runs by refractionPOINT
│   └── YYYY-MM-DD-<model-name>/
│       ├── summary.json                   # Aggregate scores
│       └── <category>/
│           └── <scenario-id>/
│               ├── result.json            # Per-scenario metadata & scoring
│               ├── output.log             # Raw stdout from the model run
│               └── ticket-export/         # Exported ticket with full data
│                   ├── ticket.json        # Ticket metadata, notes, entities
│                   ├── detections/        # Full detection records (JSON)
│                   └── telemetry/         # Full telemetry events (JSON)
└── community/                             # Community-submitted runs
    └── YYYY-MM-DD-<model-name>-<submitter>/
        └── ...
```

## Result Format

Each `result.json` contains metadata and scoring for the run:

```json
{
  "scenario_id": "INV-001",
  "scenario_version": "1.0",
  "timestamp": "2026-03-01T14:30:22Z",

  "model": {
    "name": "claude-sonnet-4-20250514",
    "provider": "anthropic",
    "cli": "claude-code"
  },

  "parameters": {
    "OID": "org-id-here",
    "DETECT_ID": "detection-id-here"
  },

  "scoring": {
    "total_points": 100,
    "earned_points": 80,
    "score_pct": 0.80,
    "checkpoints": [
      {
        "id": "checkpoint-id",
        "passed": true,
        "points_earned": 15,
        "points_possible": 15,
        "detail": "Description of what happened"
      }
    ]
  },

  "artifacts": {
    "output_log": "output.log",
    "ticket_export": "ticket-export/"
  }
}
```

The ticket export is produced by `limacharlie ticket export --id <N> --with-data <DIR>` and contains the full ticket with all linked detections, telemetry, and artifacts.

## Summary Format

Each run directory's `summary.json` contains:

```json
{
  "run_date": "2026-03-01",
  "model": {
    "name": "claude-sonnet-4-20250514",
    "provider": "anthropic"
  },
  "overall_score_pct": 0.73,
  "total_scenarios": 12,
  "by_category": {
    "investigation": { "score_pct": 0.82, "count": 4 }
  },
  "by_difficulty": {
    "easy": { "score_pct": 0.95, "count": 3 },
    "medium": { "score_pct": 0.78, "count": 5 },
    "hard": { "score_pct": 0.55, "count": 3 }
  },
  "total_cost_usd": 1.23,
  "total_duration_seconds": 542
}
```

## Submitting Results

1. Run the benchmark using the harness (see [../README.md](../README.md))
2. Capture the output to a result.json following the format above
3. Place results in `results/community/YYYY-MM-DD-<model>-<your-name>/`
4. Submit a PR

Requirements:
- Include full model name and version
- Include the raw output log
- Export the ticket using `limacharlie ticket export --with-data`
- Results should be reproducible
