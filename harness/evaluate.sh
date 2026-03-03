#!/usr/bin/env bash
set -euo pipefail

# Evaluation harness (v1: passthrough for manual review)
#
# In v1, this script formats the model output alongside the evaluation rubric
# for manual scoring. Future versions will support automated scoring.

usage() {
    echo "Usage: ./harness/evaluate.sh --output <output-file> --scenario <path>"
    echo ""
    echo "Options:"
    echo "  --output       Path to the captured model output"
    echo "  --scenario     Path to the scenario directory"
    echo "  --help         Show this help message"
    exit 1
}

OUTPUT_FILE=""
SCENARIO=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --scenario)
            SCENARIO="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

if [[ -z "$OUTPUT_FILE" || -z "$SCENARIO" ]]; then
    echo "Error: --output and --scenario are required"
    usage
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "Error: Output file not found: $OUTPUT_FILE"
    exit 1
fi

if [[ ! -f "$SCENARIO/evaluation.yaml" ]]; then
    echo "Error: evaluation.yaml not found in $SCENARIO"
    exit 1
fi

SCENARIO_NAME=$(basename "$SCENARIO")

echo "=========================================="
echo " ASW-Bench Evaluation: $SCENARIO_NAME"
echo "=========================================="
echo ""
echo "--- Evaluation Rubric ---"
echo ""
cat "$SCENARIO/evaluation.yaml"
echo ""
echo "--- Model Output ---"
echo ""
cat "$OUTPUT_FILE"
echo ""
echo "=========================================="
echo ""
echo "Score each checkpoint in the rubric above against the model output."
echo "Record results in: results/<run-id>/$SCENARIO_NAME/result.json"
echo ""
echo "See results/README.md for the expected result format."
