#!/bin/bash
# forge-watcher.sh - Watch for agent handoffs and send notifications
# Usage: forge-watcher.sh [project-dir]

set -e

PROJECT_DIR="${1:-.}"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")
FORGE_DIR="$PROJECT_DIR/.forge"
SIGNAL_FILE="$FORGE_DIR/agent-state/handoff-signal.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  FORGE WATCHER${NC}"
echo -e "${MAGENTA}  Project: $PROJECT_NAME${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""

# Check if forge is initialized
if [ ! -d "$FORGE_DIR" ]; then
    echo -e "${RED}Error: .forge/ not found in $PROJECT_DIR${NC}"
    exit 1
fi

# Track last signal to avoid duplicates
LAST_SIGNAL=""

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"

    # macOS notification
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"Submarine\""
    fi

    # Linux notification (if available)
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message"
    fi

    # Terminal bell
    echo -e "\a"
}

# Function to get agent color
get_agent_color() {
    case "$1" in
        supervisor) echo "${MAGENTA}" ;;
        developer) echo "${GREEN}" ;;
        code-reviewer) echo "${RED}" ;;
        qa-tester) echo "${YELLOW}" ;;
        *) echo "${CYAN}" ;;
    esac
}

# Function to process signal
process_signal() {
    if [ ! -f "$SIGNAL_FILE" ]; then
        return
    fi

    local signal_content=$(cat "$SIGNAL_FILE" 2>/dev/null)
    if [ -z "$signal_content" ]; then
        return
    fi

    # Check if this is a new signal
    if [ "$signal_content" = "$LAST_SIGNAL" ]; then
        return
    fi

    LAST_SIGNAL="$signal_content"

    # Parse signal
    local timestamp=$(echo "$signal_content" | jq -r '.timestamp // ""')
    local ticket_id=$(echo "$signal_content" | jq -r '.ticket_id // ""')
    local agent=$(echo "$signal_content" | jq -r '.agent // ""')
    local status=$(echo "$signal_content" | jq -r '.status // ""')
    local action=$(echo "$signal_content" | jq -r '.action // ""')

    if [ -z "$ticket_id" ] || [ -z "$agent" ]; then
        return
    fi

    # Get time
    local time=$(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1 | cut -d'Z' -f1)
    local color=$(get_agent_color "$agent")

    # Log to console
    echo -e "[${time}] ${color}${agent}${NC} <- ${CYAN}${ticket_id}${NC} (${status})"

    # Send notification
    send_notification "Forge: $PROJECT_NAME" "$ticket_id ready for $agent"

    # Optional: Send tmux notification to specific pane
    local session="forge-$PROJECT_NAME"
    if tmux has-session -t "$session" 2>/dev/null; then
        # Map agent to pane index
        local pane_index
        case "$agent" in
            supervisor) pane_index=0 ;;
            code-reviewer) pane_index=1 ;;
            developer) pane_index=2 ;;
            qa-tester) pane_index=3 ;;
            *) pane_index="" ;;
        esac

        if [ -n "$pane_index" ]; then
            # Flash the pane border
            tmux select-pane -t "$session:0.$pane_index" 2>/dev/null || true
        fi
    fi
}

# Check for file watcher
if command -v fswatch &> /dev/null; then
    echo -e "${GREEN}Using fswatch for file monitoring${NC}"
    echo ""
    echo "Watching for handoffs..."
    echo "Press Ctrl+C to stop"
    echo ""

    fswatch -0 "$FORGE_DIR/agent-state/" 2>/dev/null | while IFS= read -r -d '' event; do
        if [[ "$event" == *"handoff-signal.json"* ]] || [[ "$event" == *"inbox.json"* ]]; then
            process_signal
        fi
    done

elif command -v inotifywait &> /dev/null; then
    echo -e "${GREEN}Using inotifywait for file monitoring${NC}"
    echo ""
    echo "Watching for handoffs..."
    echo "Press Ctrl+C to stop"
    echo ""

    inotifywait -m -e modify,create "$FORGE_DIR/agent-state/" 2>/dev/null | while read -r directory events filename; do
        if [[ "$filename" == "handoff-signal.json" ]] || [[ "$filename" == "inbox.json" ]]; then
            process_signal
        fi
    done

else
    echo -e "${YELLOW}Warning: No file watcher found${NC}"
    echo ""
    echo "For real-time monitoring, install fswatch:"
    echo "  macOS: brew install fswatch"
    echo "  Linux: sudo apt install inotify-tools"
    echo ""
    echo "Falling back to polling mode (checking every 2 seconds)..."
    echo "Press Ctrl+C to stop"
    echo ""

    while true; do
        process_signal
        sleep 2
    done
fi
