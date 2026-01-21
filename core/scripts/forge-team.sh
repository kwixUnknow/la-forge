#!/bin/bash
# forge-team.sh - Launch AUTONOMOUS multi-agent team in tmux
# Usage: forge-team.sh [project-dir]

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
FORGE_DIR="$PROJECT_DIR/.forge"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  FORGE AUTONOMOUS MULTI-AGENT TEAM${NC}"
echo -e "${MAGENTA}  Project: $PROJECT_NAME${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""

if [ ! -d "$FORGE_DIR" ]; then
    echo -e "${RED}Error: .forge/ not found. Run forge-init.sh first.${NC}"
    exit 1
fi

if ! command -v tmux &> /dev/null; then
    echo -e "${RED}Error: tmux not installed${NC}"
    exit 1
fi

# Ensure agent loop script exists
AGENT_LOOP="$SCRIPTS_DIR/forge-agent-loop.sh"
if [ ! -f "$AGENT_LOOP" ]; then
    echo -e "${RED}Error: forge-agent-loop.sh not found${NC}"
    exit 1
fi
chmod +x "$AGENT_LOOP"

SESSION="forge-$PROJECT_NAME"
tmux kill-session -t "$SESSION" 2>/dev/null

echo -e "${GREEN}Creating session: $SESSION${NC}"
echo ""

# Create session with dashboard as first window
tmux new-session -d -s "$SESSION" -n "dashboard" -c "$PROJECT_DIR"
tmux set -t "$SESSION" remain-on-exit on

# Create agent windows
tmux new-window -t "$SESSION" -n "supervisor" -c "$PROJECT_DIR"
tmux new-window -t "$SESSION" -n "developer" -c "$PROJECT_DIR"
tmux new-window -t "$SESSION" -n "reviewer" -c "$PROJECT_DIR"
tmux new-window -t "$SESSION" -n "tester" -c "$PROJECT_DIR"

# Start dashboard (using bash loop instead of watch for macOS compatibility)
tmux send-keys -t "$SESSION:dashboard" "while true; do clear; echo '=== FORGE DASHBOARD ==='; echo ''; echo 'TICKETS:'; jq -r '.tickets[] | \"  \\(.id): \\(.status)\"' .forge/backlog/tickets.json 2>/dev/null; echo ''; echo 'INBOXES:'; echo \"  Developer: \$(jq '.pending_tasks | length' .forge/agent-state/developer/inbox.json 2>/dev/null) tasks\"; echo \"  Reviewer: \$(jq '.pending_tasks | length' .forge/agent-state/code-reviewer/inbox.json 2>/dev/null) tasks\"; echo \"  QA: \$(jq '.pending_tasks | length' .forge/agent-state/qa-tester/inbox.json 2>/dev/null) tasks\"; echo ''; echo 'Updated:' \$(date '+%H:%M:%S'); sleep 2; done" C-m

echo -e "Agents (${CYAN}AUTONOMOUS${NC}):"
echo -e "  ${MAGENTA}supervisor${NC} - Haiku - Assigns tickets"
echo -e "  ${GREEN}developer${NC}  - Sonnet - Implements code"
echo -e "  ${RED}reviewer${NC}   - Haiku - Reviews code"
echo -e "  ${YELLOW}tester${NC}     - Haiku - Tests code"
echo ""

# Start AUTONOMOUS agent loops in each window
echo "Starting autonomous agent loops..."
tmux send-keys -t "$SESSION:supervisor" "bash '$AGENT_LOOP' supervisor '$PROJECT_DIR'" C-m
sleep 0.5
tmux send-keys -t "$SESSION:developer" "bash '$AGENT_LOOP' developer '$PROJECT_DIR'" C-m
sleep 0.5
tmux send-keys -t "$SESSION:reviewer" "bash '$AGENT_LOOP' code-reviewer '$PROJECT_DIR'" C-m
sleep 0.5
tmux send-keys -t "$SESSION:tester" "bash '$AGENT_LOOP' qa-tester '$PROJECT_DIR'" C-m

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Autonomous Team Running!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Windows:"
echo "  0: dashboard  - Real-time status"
echo "  1: supervisor - Automatically assigns todo tickets"
echo "  2: developer  - Automatically implements tickets"
echo "  3: reviewer   - Automatically reviews code"
echo "  4: tester     - Automatically tests and marks done"
echo ""
echo -e "The agents run in a loop: ${CYAN}todo → in_progress → review → testing → done${NC}"
echo ""
echo "Attach: tmux attach -t $SESSION"
echo ""

read -p "Attach now? [Y/n] " response
if [[ ! "$response" =~ ^[Nn]$ ]]; then
    tmux select-window -t "$SESSION:dashboard"
    tmux attach -t "$SESSION"
fi
