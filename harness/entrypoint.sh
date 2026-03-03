#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: asw-bench --cli <claude|openai|gemini> --prompt-file <path> [--model <model>]"
    echo ""
    echo "Options:"
    echo "  --cli          CLI tool to use (claude, openai, gemini)"
    echo "  --prompt-file  Path to the prompt file inside the container"
    echo "  --model        Model to use (e.g. sonnet, opus, haiku, gpt-4o)"
    echo "  --help         Show this help message"
    exit 1
}

CLI=""
PROMPT_FILE=""
MODEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cli)
            CLI="$2"
            shift 2
            ;;
        --prompt-file)
            PROMPT_FILE="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
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

if [[ -z "$CLI" || -z "$PROMPT_FILE" ]]; then
    echo "Error: --cli and --prompt-file are required"
    usage
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: Prompt file not found: $PROMPT_FILE"
    exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")

# Substitute {{PARAM}} placeholders with ASW_PARAM_* env vars
while IFS='=' read -r envvar value; do
    param_name="${envvar#ASW_PARAM_}"
    PROMPT="${PROMPT//\{\{${param_name}\}\}/${value}}"
done < <(env | grep '^ASW_PARAM_' | sort)

# Error if any unresolved {{...}} placeholders remain
if [[ "$PROMPT" =~ \{\{[A-Za-z_][A-Za-z0-9_]*\}\} ]]; then
    echo "Error: Unresolved placeholder(s) in prompt:" >&2
    grep -oE '\{\{[A-Za-z_][A-Za-z0-9_]*\}\}' <<< "$PROMPT" | sort -u >&2
    exit 1
fi

# Append execution environment instructions
PROMPT+=$'\n\n---\n\nThe `limacharlie` CLI is installed and authenticated in your environment. Use it via shell commands to interact with the LimaCharlie platform. Do not use MCP tools.'

# Check if Claude Code subscription credentials are mounted
has_claude_credentials() {
    [[ -f "$HOME/.claude/.credentials.json" ]] && [[ -f "$HOME/.claude.json" ]]
}

# Print model selection
if [[ -n "$MODEL" ]]; then
    echo "Model: $MODEL"
else
    echo "Model: (default)"
fi

case "$CLI" in
    claude)
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
            if has_claude_credentials; then
                echo "Using mounted Claude Code subscription credentials"
                echo "Note: OAuth tokens may expire on long runs. If auth fails, use ANTHROPIC_API_KEY instead."
            else
                echo "Error: Claude auth required. Either:"
                echo "  - Set ANTHROPIC_API_KEY environment variable, or"
                echo "  - Mount subscription credentials:"
                echo "    -v ~/.claude/.credentials.json:\$HOME/.claude/.credentials.json:ro"
                echo "    -v ~/.claude.json:\$HOME/.claude.json:ro"
                exit 1
            fi
        fi
        # Run Claude Code: stream-json for real-time output, piped through jq
        # to produce readable text. --verbose is required by stream-json.
        CLAUDE_ARGS=(-p "$PROMPT" --output-format stream-json --verbose --dangerously-skip-permissions)
        if [[ -n "$MODEL" ]]; then
            CLAUDE_ARGS+=(--model "$MODEL")
        fi
        claude "${CLAUDE_ARGS[@]}" \
            | jq -r --unbuffered '
                if .type == "system" and .model then
                    "Model confirmed: \(.model)"
                elif .type == "assistant" then
                    [.message.content[]? |
                        if .type == "text" then .text
                        elif .type == "tool_use" then "\n>>> \(.name): \(.input | tostring | if length > 500 then .[0:500] + "..." else . end)\n"
                        else empty end
                    ] | join("")
                elif .type == "result" then
                    "\n--- Result ---\n\(.result // "")\nModel: \(.model // "unknown")"
                else empty end'
        ;;
    openai)
        if [[ -z "${OPENAI_API_KEY:-}" ]]; then
            if [[ -f "$HOME/.codex/auth.json" ]]; then
                echo "Using mounted Codex CLI subscription credentials"
                echo "Note: OAuth tokens may expire on long runs. If auth fails, use OPENAI_API_KEY instead."
            else
                echo "Error: OpenAI auth required. Either:"
                echo "  - Set OPENAI_API_KEY environment variable, or"
                echo "  - Mount subscription credentials:"
                echo "    -v ~/.codex/auth.json:\$HOME/.codex/auth.json:ro"
                exit 1
            fi
        fi
        # Run OpenAI Codex CLI in non-interactive mode with JSONL event streaming
        CODEX_ARGS=(exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --ephemeral --json)
        if [[ -n "$MODEL" ]]; then
            CODEX_ARGS+=(--model "$MODEL")
        fi
        CODEX_ARGS+=("$PROMPT")
        codex "${CODEX_ARGS[@]}" \
            | jq -r --unbuffered '
                if .type == "thread.started" then
                    "Thread: \(.thread_id)"
                elif .type == "turn.started" then
                    "\n--- Turn ---"
                elif .type == "turn.completed" then
                    empty
                elif .type == "turn.failed" then
                    "\n--- Turn FAILED: \(.error.message // "unknown error") ---"
                elif .type == "item.started" and .item.type == "command_execution" then
                    "\n>>> \(.item.command // "")\n"
                elif .type == "item.completed" and .item.type == "agent_message" then
                    "\(.item.text // "")"
                elif .type == "item.completed" and .item.type == "command_execution" then
                    (.item.output // .item.text // "" |
                        if length > 2000 then .[0:2000] + "\n... (truncated)"
                        else . end)
                elif .type == "item.completed" then
                    (.item | tostring |
                        if length > 500 then .[0:500] + "..."
                        else . end)
                elif .type == "error" then
                    "ERROR: \(.message // "")"
                else empty end'
        ;;
    gemini)
        if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
            if [[ -f "$HOME/.gemini/oauth_creds.json" ]]; then
                echo "Using mounted Gemini CLI subscription credentials"
                echo "Note: OAuth tokens may expire on long runs. If auth fails, use GOOGLE_API_KEY instead."
            else
                echo "Error: Gemini auth required. Either:"
                echo "  - Set GOOGLE_API_KEY environment variable, or"
                echo "  - Mount subscription credentials:"
                echo "    -v ~/.gemini:\$HOME/.gemini:ro"
                exit 1
            fi
        fi
        # Run Gemini CLI in non-interactive mode with auto-approval
        GEMINI_ARGS=(-p "$PROMPT" --yolo)
        if [[ -n "$MODEL" ]]; then
            GEMINI_ARGS+=(--model "$MODEL")
        fi
        gemini "${GEMINI_ARGS[@]}"
        ;;
    *)
        echo "Error: Unsupported CLI '$CLI'. Supported: claude, openai, gemini"
        exit 1
        ;;
esac
