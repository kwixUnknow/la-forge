#!/bin/bash
# forge-test-full.sh - Full integration test for Forge
# Simulates the complete multi-agent workflow without actually running Claude

set -e

PROJECT_DIR="${1:-$HOME/la-forge}"
FORGE_DIR="$PROJECT_DIR/.forge"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

PASS=0
FAIL=0

test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  FORGE FULL INTEGRATION TEST${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""

# Test 1: Settings validation
echo -e "${YELLOW}[1/8] Testing Claude settings...${NC}"
if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
    if jq empty "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
        test_pass "settings.json is valid JSON"
    else
        test_fail "settings.json is invalid JSON"
    fi
else
    test_fail "settings.json not found"
fi

# Test 2: Ticket exists and is valid
echo ""
echo -e "${YELLOW}[2/8] Testing ticket data...${NC}"
TICKETS_FILE="$FORGE_DIR/backlog/tickets.json"
if [ -f "$TICKETS_FILE" ]; then
    TICKET_COUNT=$(jq '.tickets | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
    if [ "$TICKET_COUNT" -gt 0 ]; then
        test_pass "Found $TICKET_COUNT ticket(s)"

        # Show ticket details
        TICKET_ID=$(jq -r '.tickets[0].id' "$TICKETS_FILE")
        TICKET_STATUS=$(jq -r '.tickets[0].status' "$TICKETS_FILE")
        TICKET_TITLE=$(jq -r '.tickets[0].title' "$TICKETS_FILE" | cut -c1-40)
        echo -e "     Ticket: ${BLUE}$TICKET_ID${NC} [$TICKET_STATUS] $TICKET_TITLE..."
    else
        test_fail "No tickets found"
    fi
else
    test_fail "tickets.json not found"
fi

# Test 3: Tmux session creation
echo ""
echo -e "${YELLOW}[3/8] Testing tmux session creation...${NC}"
SESSION="forge-integration-test"
tmux kill-session -t "$SESSION" 2>/dev/null || true

if tmux new-session -d -s "$SESSION" -n "supervisor" 2>/dev/null; then
    test_pass "Created tmux session"

    # Create all 4 windows
    tmux new-window -t "$SESSION" -n "developer" 2>/dev/null
    tmux new-window -t "$SESSION" -n "code-reviewer" 2>/dev/null
    tmux new-window -t "$SESSION" -n "qa-tester" 2>/dev/null

    WINDOW_COUNT=$(tmux list-windows -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$WINDOW_COUNT" -eq 4 ]; then
        test_pass "Created 4 windows"
    else
        test_fail "Expected 4 windows, got $WINDOW_COUNT"
    fi

    tmux kill-session -t "$SESSION" 2>/dev/null
else
    test_fail "Failed to create tmux session"
fi

# Test 4: Simulate ticket assignment
echo ""
echo -e "${YELLOW}[4/8] Testing ticket assignment flow...${NC}"
DEVELOPER_INBOX="$FORGE_DIR/agent-state/developer/inbox.json"

# Backup original
cp "$DEVELOPER_INBOX" "$DEVELOPER_INBOX.bak" 2>/dev/null || true

# Simulate supervisor assigning ticket to developer
TASK_JSON=$(cat <<EOF
{
  "pending_tasks": [
    {
      "task_id": "task-001",
      "ticket_id": "TICKET-001",
      "action": "implement",
      "assigned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "assigned_by": "supervisor"
    }
  ],
  "messages": []
}
EOF
)

echo "$TASK_JSON" > "$DEVELOPER_INBOX"
if jq empty "$DEVELOPER_INBOX" 2>/dev/null; then
    test_pass "Wrote task to developer inbox"

    # Verify task can be read
    TASK_COUNT=$(jq '.pending_tasks | length' "$DEVELOPER_INBOX")
    if [ "$TASK_COUNT" -eq 1 ]; then
        test_pass "Developer inbox has 1 pending task"
    else
        test_fail "Expected 1 task, got $TASK_COUNT"
    fi
else
    test_fail "Failed to write to developer inbox"
fi

# Test 5: Simulate ticket status change
echo ""
echo -e "${YELLOW}[5/8] Testing ticket status transition...${NC}"

# Backup tickets
cp "$TICKETS_FILE" "$TICKETS_FILE.bak" 2>/dev/null || true

# Change ticket status to in_progress
jq '.tickets[0].status = "in_progress" | .tickets[0].started_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' "$TICKETS_FILE" > "$TICKETS_FILE.tmp" && mv "$TICKETS_FILE.tmp" "$TICKETS_FILE"

NEW_STATUS=$(jq -r '.tickets[0].status' "$TICKETS_FILE")
if [ "$NEW_STATUS" = "in_progress" ]; then
    test_pass "Ticket status changed to in_progress"
else
    test_fail "Failed to change ticket status (got: $NEW_STATUS)"
fi

# Test 6: Dashboard reads updated status
echo ""
echo -e "${YELLOW}[6/8] Testing dashboard reads changes...${NC}"
IN_PROGRESS_COUNT=$(jq '[.tickets[] | select(.status == "in_progress")] | length' "$TICKETS_FILE")
if [ "$IN_PROGRESS_COUNT" -eq 1 ]; then
    test_pass "Dashboard would show: In Progress = 1"
else
    test_fail "Dashboard count incorrect: $IN_PROGRESS_COUNT"
fi

# Test 7: Simulate review handoff
echo ""
echo -e "${YELLOW}[7/8] Testing review handoff...${NC}"
REVIEWER_INBOX="$FORGE_DIR/agent-state/code-reviewer/inbox.json"

REVIEW_JSON=$(cat <<EOF
{
  "pending_tasks": [
    {
      "task_id": "review-001",
      "ticket_id": "TICKET-001",
      "action": "review",
      "assigned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "assigned_by": "developer"
    }
  ],
  "messages": []
}
EOF
)

echo "$REVIEW_JSON" > "$REVIEWER_INBOX"
if jq '.pending_tasks[0].action' "$REVIEWER_INBOX" | grep -q "review"; then
    test_pass "Handoff to code-reviewer works"
else
    test_fail "Handoff failed"
fi

# Test 8: Restore and cleanup
echo ""
echo -e "${YELLOW}[8/8] Restoring original state...${NC}"

# Restore backups
if [ -f "$DEVELOPER_INBOX.bak" ]; then
    mv "$DEVELOPER_INBOX.bak" "$DEVELOPER_INBOX"
    test_pass "Restored developer inbox"
fi

if [ -f "$TICKETS_FILE.bak" ]; then
    mv "$TICKETS_FILE.bak" "$TICKETS_FILE"
    test_pass "Restored tickets.json"
fi

# Reset reviewer inbox
echo '{"pending_tasks": [], "messages": []}' > "$REVIEWER_INBOX"
test_pass "Reset code-reviewer inbox"

# Summary
echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  TEST SUMMARY${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All integration tests passed!${NC}"
    echo ""
    echo "The workflow simulation verified:"
    echo "  1. Settings are valid"
    echo "  2. Tickets exist and are readable"
    echo "  3. Tmux creates 4 windows correctly"
    echo "  4. Supervisor can assign tickets to developer"
    echo "  5. Ticket status transitions work"
    echo "  6. Dashboard reads changes correctly"
    echo "  7. Handoff between agents works"
    echo ""
    echo -e "${GREEN}Ready to launch:${NC}"
    echo "  ~/la-forge/core/scripts/forge-team.sh $PROJECT_DIR"
    exit 0
else
    echo -e "${RED}Some tests failed. Please fix the issues.${NC}"
    exit 1
fi
