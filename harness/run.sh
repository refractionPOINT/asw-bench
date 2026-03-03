#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: ./harness/run.sh --scenario <path> --cli <claude|openai|gemini> [options]"
    echo ""
    echo "Options:"
    echo "  --scenario     Path to the scenario directory"
    echo "  --cli          CLI tool to use (claude, openai, gemini)"
    echo "  --oid          LimaCharlie organization ID (or set LC_OID)"
    echo "  --api-key      LimaCharlie API key (or set LC_API_KEY, or use ~/.limacharlie)"
    echo "  --model        Model to use (e.g. sonnet, opus, haiku, gpt-4o, etc.)"
    echo "  --param        Scenario parameter as KEY=VALUE (repeatable)"
    echo "  --skip-setup   Skip Phase 1 (IaC setup), useful for re-runs"
    echo "  --output       Output file for results (default: stdout)"
    echo "  --help         Show this help message"
    exit 1
}

SCENARIO=""
CLI=""
MODEL=""
OID="${LC_OID:-}"
API_KEY="${LC_API_KEY:-}"
SKIP_SETUP=false
OUTPUT=""
declare -A PARAMS

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scenario)
            SCENARIO="$2"
            shift 2
            ;;
        --cli)
            CLI="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --oid)
            OID="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --param)
            if [[ "$2" != *=* ]]; then
                echo "Error: --param value must be KEY=VALUE, got: $2"
                exit 1
            fi
            key="${2%%=*}"
            value="${2#*=}"
            PARAMS["$key"]="$value"
            shift 2
            ;;
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        --output)
            OUTPUT="$2"
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

if [[ -z "$SCENARIO" || -z "$CLI" ]]; then
    echo "Error: --scenario and --cli are required"
    usage
fi

# Resolve LimaCharlie credentials file (used by LC CLI for auth)
LC_CREDS_FILE="${LC_CREDS_FILE:-$HOME/.limacharlie}"

if [[ -z "$OID" ]]; then
    echo "Error: LimaCharlie OID is required (--oid or LC_OID)"
    exit 1
fi

if [[ -z "$API_KEY" ]] && [[ ! -f "$LC_CREDS_FILE" ]]; then
    echo "Error: LimaCharlie auth required. Either:"
    echo "  - Set --api-key or LC_API_KEY, or"
    echo "  - Log in with: limacharlie auth login"
    exit 1
fi

# Validate scenario directory
if [[ ! -d "$SCENARIO" ]]; then
    echo "Error: Scenario directory not found: $SCENARIO"
    exit 1
fi

if [[ ! -f "$SCENARIO/infra.yaml" ]]; then
    echo "Error: infra.yaml not found in $SCENARIO"
    exit 1
fi

if [[ ! -f "$SCENARIO/prompt.md" ]]; then
    echo "Error: prompt.md not found in $SCENARIO"
    exit 1
fi

SCENARIO_NAME=$(basename "$SCENARIO")
echo "=== ASW-Bench: $SCENARIO_NAME ==="
echo "CLI: $CLI"
if [[ -n "$MODEL" ]]; then
    echo "Model: $MODEL"
fi
echo "OID: $OID"
echo ""

# ─── Phase 1: Environment Setup ───

if [[ "$SKIP_SETUP" == false ]]; then
    echo "--- Phase 1: Applying IaC template ---"
    echo "Running: limacharlie sync push --config-file $SCENARIO/infra.yaml --all"

    export LC_OID="$OID"
    # Only export LC_API_KEY if set — empty value would override ~/.limacharlie config
    if [[ -n "$API_KEY" ]]; then
        export LC_API_KEY="$API_KEY"
    fi
    limacharlie sync push --config-file "$SCENARIO/infra.yaml" --all

    echo ""
    echo "--- IaC applied. ---"
    echo ""

    # Check if adversary scripts exist
    if [[ -d "$SCENARIO/adversary" ]]; then
        echo "This scenario has adversary scripts that must be run manually."
        echo "See: $SCENARIO/adversary/README.md"
        echo ""
        read -r -p "Press Enter once adversary activity is complete (or Ctrl+C to abort)..."
        echo ""
    fi
else
    echo "--- Phase 1: Skipped (--skip-setup) ---"
    echo ""
fi

# ─── Phase 2: Model Execution ───

echo "--- Phase 2: Running model ($CLI) ---"

# Always rebuild — Docker layer caching makes this fast when nothing changed,
# and ensures the image reflects the latest harness and scenario files.
echo "Building asw-bench Docker image..."
docker build -q -t asw-bench .

# Determine the prompt file path inside the container
# Scenarios are copied to /scenarios/ in the Dockerfile
# Normalize: strip leading ./, trailing /, and the "scenarios/" prefix
SCENARIO_REL="${SCENARIO#./}"
SCENARIO_REL="${SCENARIO_REL%/}"
SCENARIO_REL="${SCENARIO_REL#scenarios/}"
CONTAINER_PROMPT="/scenarios/${SCENARIO_REL}/prompt.md"

# Build docker run command
DOCKER_ARGS=(
    -e "LC_OID=$OID"
)

# Pass LC_API_KEY only if explicitly set — otherwise the container uses ~/.limacharlie
if [[ -n "$API_KEY" ]]; then
    DOCKER_ARGS+=(-e "LC_API_KEY=$API_KEY")
fi

# Mount LC CLI credentials file if it exists
if [[ -f "$LC_CREDS_FILE" ]]; then
    DOCKER_ARGS+=(-v "$LC_CREDS_FILE:/home/ubuntu/.limacharlie:ro")
fi

# Pass through active LC environment if set
if [[ -n "${LC_CURRENT_ENV:-}" ]]; then
    DOCKER_ARGS+=(-e "LC_CURRENT_ENV=$LC_CURRENT_ENV")
fi

# Auto-populate built-in param: OID
PARAMS["OID"]="$OID"

# Pass all scenario parameters as ASW_PARAM_* env vars
for key in "${!PARAMS[@]}"; do
    DOCKER_ARGS+=(-e "ASW_PARAM_${key}=${PARAMS[$key]}")
done

case "$CLI" in
    claude)
        if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
            DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
        elif [[ -f "$HOME/.claude/.credentials.json" ]] && [[ -f "$HOME/.claude.json" ]]; then
            echo "No ANTHROPIC_API_KEY set — mounting Claude Code subscription credentials"
            DOCKER_ARGS+=(
                -v "$HOME/.claude:/home/ubuntu/.claude"
                -v "$HOME/.claude.json:/home/ubuntu/.claude.json:ro"
            )
        else
            echo "Error: Claude auth required. Set ANTHROPIC_API_KEY or run 'claude login' first."
            exit 1
        fi
        ;;
    openai)
        if [[ -n "${OPENAI_API_KEY:-}" ]]; then
            DOCKER_ARGS+=(-e "OPENAI_API_KEY=${OPENAI_API_KEY}")
        elif [[ -f "$HOME/.codex/auth.json" ]]; then
            echo "No OPENAI_API_KEY set — mounting Codex CLI subscription credentials"
            DOCKER_ARGS+=(-v "$HOME/.codex/auth.json:/home/ubuntu/.codex/auth.json:ro")
        else
            echo "Error: OpenAI auth required. Either:"
            echo "  - Set OPENAI_API_KEY environment variable, or"
            echo "  - Log in with: codex login"
            exit 1
        fi
        ;;
    gemini)
        if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
            DOCKER_ARGS+=(-e "GOOGLE_API_KEY=${GOOGLE_API_KEY}")
        elif [[ -f "$HOME/.gemini/oauth_creds.json" ]]; then
            echo "No GOOGLE_API_KEY set — mounting Gemini CLI subscription credentials"
            DOCKER_ARGS+=(-v "$HOME/.gemini:/home/ubuntu/.gemini")
        else
            echo "Error: Gemini auth required. Either:"
            echo "  - Set GOOGLE_API_KEY environment variable, or"
            echo "  - Log in with: gemini"
            exit 1
        fi
        ;;
esac

ENTRYPOINT_ARGS=(--cli "$CLI" --prompt-file "$CONTAINER_PROMPT")
if [[ -n "$MODEL" ]]; then
    ENTRYPOINT_ARGS+=(--model "$MODEL")
fi

if [[ -n "$OUTPUT" ]]; then
    docker run "${DOCKER_ARGS[@]}" asw-bench "${ENTRYPOINT_ARGS[@]}" | tee "$OUTPUT"
else
    docker run "${DOCKER_ARGS[@]}" asw-bench "${ENTRYPOINT_ARGS[@]}"
fi

echo ""
echo "--- Benchmark complete ---"
echo "Review output against: $SCENARIO/evaluation.yaml"
