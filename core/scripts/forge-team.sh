#!/bin/bash
# forge-team.sh - Launch AUTONOMOUS multi-agent team in tmux (split-screen view)
# Usage: forge-team.sh [project-dir]

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
FORGE_DIR="$PROJECT_DIR/.forge"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

AGENT_LOOP="$SCRIPTS_DIR/forge-agent-loop.sh"
if [ ! -f "$AGENT_LOOP" ]; then
    echo -e "${RED}Error: forge-agent-loop.sh not found${NC}"
    exit 1
fi
chmod +x "$AGENT_LOOP"

SESSION="forge-$PROJECT_NAME"
tmux kill-session -t "$SESSION" 2>/dev/null

echo -e "${GREEN}Creating split-screen session: $SESSION${NC}"
echo ""

# Create session with first pane (supervisor)
tmux new-session -d -s "$SESSION" -n "agents" -c "$PROJECT_DIR"

# Split into 2x2 grid:
# +-------------+-------------+
# | SUPERVISOR  |  DEVELOPER  |
# +-------------+-------------+
# |  REVIEWER   |   TESTER    |
# +-------------+-------------+

# Split horizontally (creates top-right pane for developer)
tmux split-window -h -t "$SESSION:agents" -c "$PROJECT_DIR"

# Split top-left vertically (creates bottom-left for reviewer)
tmux split-window -v -t "$SESSION:agents.0" -c "$PROJECT_DIR"

# Split top-right vertically (creates bottom-right for tester)
tmux split-window -v -t "$SESSION:agents.1" -c "$PROJECT_DIR"

# Now panes are: 0=supervisor, 1=reviewer, 2=developer, 3=tester
# Let's label them with a header and start the agents

# Pane 0 - Supervisor (top-left)
tmux send-keys -t "$SESSION:agents.0" "echo -e '${MAGENTA}=== SUPERVISOR ===${NC}'; bash '$AGENT_LOOP' supervisor '$PROJECT_DIR'" C-m

# Pane 1 - Reviewer (bottom-left)
tmux send-keys -t "$SESSION:agents.1" "echo -e '${RED}=== CODE-REVIEWER ===${NC}'; bash '$AGENT_LOOP' code-reviewer '$PROJECT_DIR'" C-m

# Pane 2 - Developer (top-right)
tmux send-keys -t "$SESSION:agents.2" "echo -e '${GREEN}=== DEVELOPER ===${NC}'; bash '$AGENT_LOOP' developer '$PROJECT_DIR'" C-m

# Pane 3 - Tester (bottom-right)
tmux send-keys -t "$SESSION:agents.3" "echo -e '${YELLOW}=== QA-TESTER ===${NC}'; bash '$AGENT_LOOP' qa-tester '$PROJECT_DIR'" C-m

# Keep panes open if agent exits
tmux set -t "$SESSION" remain-on-exit on

# Create a second window for dashboard (optional, Ctrl+b n to switch)
tmux new-window -t "$SESSION" -n "dashboard" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:dashboard" "while true; do clear; echo '=== FORGE DASHBOARD ==='; echo ''; echo 'TICKETS:'; jq -r '.tickets[] | \"  \\(.id): \\(.status)\"' .forge/backlog/tickets.json 2>/dev/null; echo ''; echo 'INBOXES:'; echo \"  Developer: \$(jq '.pending_tasks | length' .forge/agent-state/developer/inbox.json 2>/dev/null) tasks\"; echo \"  Reviewer: \$(jq '.pending_tasks | length' .forge/agent-state/code-reviewer/inbox.json 2>/dev/null) tasks\"; echo \"  QA: \$(jq '.pending_tasks | length' .forge/agent-state/qa-tester/inbox.json 2>/dev/null) tasks\"; echo ''; echo 'Updated:' \$(date '+%H:%M:%S'); sleep 2; done" C-m

# Go back to agents window
tmux select-window -t "$SESSION:agents"

echo -e "Layout (${CYAN}2x2 split-screen${NC}):"
echo ""
echo "  +---------------+---------------+"
echo -e "  | ${MAGENTA}SUPERVISOR${NC}    | ${GREEN}DEVELOPER${NC}     |"
echo "  +---------------+---------------+"
echo -e "  | ${RED}REVIEWER${NC}      | ${YELLOW}TESTER${NC}        |"
echo "  +---------------+---------------+"
echo ""
echo "Navigation:"
echo "  Ctrl+b arrow  - Move between panes"
echo "  Ctrl+b n      - Switch to dashboard"
echo "  Ctrl+b z      - Zoom current pane (toggle)"
echo ""
echo -e "Workflow: ${CYAN}todo → in_progress → review → testing → done${NC}"
echo ""

read -p "Attach now? [Y/n] " response
if [[ ! "$response" =~ ^[Nn]$ ]]; then
    tmux attach -t "$SESSION"
fi
