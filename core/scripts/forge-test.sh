#!/bin/bash
# forge-test.sh - Test the Forge multi-agent system
# Usage: forge-test.sh [project-dir]
# This script validates that all components work correctly

set -e

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
FORGE_DIR="$PROJECT_DIR/.forge"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

test_result() {
    local name="$1"
    local result="$2"
    if [ "$result" = "pass" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $name"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  FORGE SYSTEM TEST${NC}"
echo -e "${BLUE}  Project: $(basename $PROJECT_DIR)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: .forge directory exists
echo -e "${YELLOW}[1/7] Testing .forge/ structure...${NC}"
if [ -d "$FORGE_DIR" ]; then
    test_result ".forge/ directory exists" "pass"
else
    test_result ".forge/ directory exists" "fail"
fi

if [ -d "$FORGE_DIR/backlog" ]; then
    test_result ".forge/backlog/ exists" "pass"
else
    test_result ".forge/backlog/ exists" "fail"
fi

if [ -d "$FORGE_DIR/agent-state" ]; then
    test_result ".forge/agent-state/ exists" "pass"
else
    test_result ".forge/agent-state/ exists" "fail"
fi

# Test 2: Tickets file
echo ""
echo -e "${YELLOW}[2/7] Testing tickets.json...${NC}"
TICKETS_FILE="$FORGE_DIR/backlog/tickets.json"
if [ -f "$TICKETS_FILE" ]; then
    test_result "tickets.json exists" "pass"

    # Validate JSON
    if jq empty "$TICKETS_FILE" 2>/dev/null; then
        test_result "tickets.json is valid JSON" "pass"
    else
        test_result "tickets.json is valid JSON" "fail"
    fi

    # Check for tickets array
    TICKET_COUNT=$(jq '.tickets | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
    if [ "$TICKET_COUNT" -gt 0 ]; then
        test_result "Has $TICKET_COUNT ticket(s)" "pass"
    else
        test_result "Has tickets (found: 0)" "fail"
    fi

    # Count by status
    TODO=$(jq '[.tickets[] | select(.status == "todo")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
    IN_PROGRESS=$(jq '[.tickets[] | select(.status == "in_progress")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
    DONE=$(jq '[.tickets[] | select(.status == "done")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
    echo -e "     Status: todo=$TODO, in_progress=$IN_PROGRESS, done=$DONE"
else
    test_result "tickets.json exists" "fail"
fi

# Test 3: Agent state directories
echo ""
echo -e "${YELLOW}[3/7] Testing agent-state directories...${NC}"
for agent in supervisor developer code-reviewer qa-tester; do
    AGENT_DIR="$FORGE_DIR/agent-state/$agent"
    if [ -d "$AGENT_DIR" ]; then
        test_result "$agent/ directory exists" "pass"
    else
        test_result "$agent/ directory exists" "fail"
    fi

    if [ -f "$AGENT_DIR/inbox.json" ]; then
        if jq empty "$AGENT_DIR/inbox.json" 2>/dev/null; then
            test_result "$agent/inbox.json valid" "pass"
        else
            test_result "$agent/inbox.json valid" "fail"
        fi
    else
        test_result "$agent/inbox.json exists" "fail"
    fi
done

# Test 4: progress.json
echo ""
echo -e "${YELLOW}[4/7] Testing progress.json...${NC}"
if [ -f "$FORGE_DIR/progress.json" ]; then
    test_result "progress.json exists" "pass"
    if jq empty "$FORGE_DIR/progress.json" 2>/dev/null; then
        test_result "progress.json is valid JSON" "pass"
    else
        test_result "progress.json is valid JSON" "fail"
    fi
else
    test_result "progress.json exists" "fail"
fi

# Test 5: Dashboard script
echo ""
echo -e "${YELLOW}[5/7] Testing dashboard script...${NC}"
DASHBOARD_SCRIPT="$HOME/la-forge/core/scripts/forge-dashboard.sh"
if [ -f "$DASHBOARD_SCRIPT" ]; then
    test_result "forge-dashboard.sh exists" "pass"
    if [ -x "$DASHBOARD_SCRIPT" ]; then
        test_result "forge-dashboard.sh is executable" "pass"
    else
        test_result "forge-dashboard.sh is executable" "fail"
    fi
else
    test_result "forge-dashboard.sh exists" "fail"
fi

# Test 6: Team script
echo ""
echo -e "${YELLOW}[6/7] Testing team script...${NC}"
TEAM_SCRIPT="$HOME/la-forge/core/scripts/forge-team.sh"
if [ -f "$TEAM_SCRIPT" ]; then
    test_result "forge-team.sh exists" "pass"
    if [ -x "$TEAM_SCRIPT" ]; then
        test_result "forge-team.sh is executable" "pass"
    else
        test_result "forge-team.sh is executable" "fail"
    fi
else
    test_result "forge-team.sh exists" "fail"
fi

# Test 7: tmux availability
echo ""
echo -e "${YELLOW}[7/7] Testing tmux...${NC}"
if command -v tmux &> /dev/null; then
    test_result "tmux is installed" "pass"
    TMUX_VERSION=$(tmux -V)
    echo -e "     Version: $TMUX_VERSION"
else
    test_result "tmux is installed" "fail"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All tests passed! System is ready.${NC}"
    echo ""
    echo "To launch the team:"
    echo "  ~/la-forge/core/scripts/forge-team.sh $PROJECT_DIR"
    echo ""
    echo "To view the dashboard:"
    echo "  ~/la-forge/core/scripts/forge-dashboard.sh $PROJECT_DIR --watch"
    exit 0
else
    echo -e "${RED}Some tests failed. Please fix the issues above.${NC}"
    exit 1
fi
