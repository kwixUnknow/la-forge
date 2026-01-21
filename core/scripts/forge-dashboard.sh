#!/bin/bash
# forge-dashboard.sh - Real-time CLI dashboard for Forge progress
# Usage: forge-dashboard.sh [project-dir] [--watch]

set -e

PROJECT_DIR="${1:-.}"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")
FORGE_DIR="$PROJECT_DIR/.forge"
WATCH_MODE="${2:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check if forge is initialized
if [ ! -d "$FORGE_DIR" ]; then
    echo -e "${RED}Error: .forge/ not found in $PROJECT_DIR${NC}"
    exit 1
fi

render_dashboard() {
    clear

    # Header
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  ${WHITE}FORGE DASHBOARD${NC} - $PROJECT_NAME"
    echo -e "${MAGENTA}║${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Ticket Status
    echo -e "${CYAN}┌─ TICKET STATUS ────────────────────────────────────────────────┐${NC}"

    TICKETS_FILE="$FORGE_DIR/backlog/tickets.json"
    if [ -f "$TICKETS_FILE" ]; then
        # Read counts directly from tickets.json
        BACKLOG=$(jq '[.tickets[] | select(.status == "backlog")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        TODO=$(jq '[.tickets[] | select(.status == "todo")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        IN_PROGRESS=$(jq '[.tickets[] | select(.status == "in_progress")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        REVIEW=$(jq '[.tickets[] | select(.status == "review")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        TESTING=$(jq '[.tickets[] | select(.status == "testing")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        DONE=$(jq '[.tickets[] | select(.status == "done")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")
        BLOCKED=$(jq '[.tickets[] | select(.status == "blocked")] | length' "$TICKETS_FILE" 2>/dev/null || echo "0")

        TOTAL=$((BACKLOG + TODO + IN_PROGRESS + REVIEW + TESTING + DONE + BLOCKED))

        # Progress bar function
        progress_bar() {
            local count=$1
            local max=$2
            local width=30
            local filled=0
            if [ "$max" -gt 0 ]; then
                filled=$((count * width / max))
            fi
            local empty=$((width - filled))
            printf "%${filled}s" | tr ' ' '█'
            printf "%${empty}s" | tr ' ' '░'
        }

        echo -e "│                                                                  │"
        printf "│  ${GRAY}Backlog${NC}     %3d  " "$BACKLOG"
        progress_bar $BACKLOG $TOTAL
        echo "                │"

        printf "│  ${BLUE}Todo${NC}        %3d  " "$TODO"
        progress_bar $TODO $TOTAL
        echo "                │"

        printf "│  ${YELLOW}In Progress${NC} %3d  " "$IN_PROGRESS"
        progress_bar $IN_PROGRESS $TOTAL
        echo "                │"

        printf "│  ${MAGENTA}Review${NC}      %3d  " "$REVIEW"
        progress_bar $REVIEW $TOTAL
        echo "                │"

        printf "│  ${CYAN}Testing${NC}     %3d  " "$TESTING"
        progress_bar $TESTING $TOTAL
        echo "                │"

        printf "│  ${GREEN}Done${NC}        %3d  " "$DONE"
        progress_bar $DONE $TOTAL
        echo "                │"

        if [ "$BLOCKED" -gt 0 ]; then
            printf "│  ${RED}Blocked${NC}     %3d  " "$BLOCKED"
            progress_bar $BLOCKED $TOTAL
            echo "                │"
        fi

        echo -e "│                                                                  │"
        echo -e "│  Total: $TOTAL tickets                                            │"
    else
        echo -e "│  No tickets file found                                           │"
    fi

    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Agent Status
    echo -e "${GREEN}┌─ AGENT STATUS ─────────────────────────────────────────────────┐${NC}"

    if [ -f "$FORGE_DIR/progress.json" ]; then
        echo -e "│                                                                  │"

        for agent in supervisor developer code-reviewer qa-tester; do
            STATUS=$(jq -r ".agents_status.$agent.status // \"unknown\"" "$FORGE_DIR/progress.json" 2>/dev/null || echo "unknown")
            TICKET=$(jq -r ".agents_status.$agent.current_ticket // \"\"" "$FORGE_DIR/progress.json" 2>/dev/null || echo "")
            LAST_ACTIVE=$(jq -r ".agents_status.$agent.last_active // \"never\"" "$FORGE_DIR/progress.json" 2>/dev/null || echo "never")

            # Format status with color
            case "$STATUS" in
                "working"|"busy")
                    STATUS_COLOR="${YELLOW}●${NC}"
                    ;;
                "idle")
                    STATUS_COLOR="${GREEN}○${NC}"
                    ;;
                "blocked")
                    STATUS_COLOR="${RED}■${NC}"
                    ;;
                *)
                    STATUS_COLOR="${GRAY}?${NC}"
                    ;;
            esac

            printf "│  $STATUS_COLOR %-14s " "$agent"

            if [ -n "$TICKET" ] && [ "$TICKET" != "null" ]; then
                printf "%-12s" "[$TICKET]"
            else
                printf "%-12s" ""
            fi

            # Show last active time
            if [ "$LAST_ACTIVE" != "never" ] && [ "$LAST_ACTIVE" != "null" ]; then
                LAST_TIME=$(echo "$LAST_ACTIVE" | cut -d'T' -f2 | cut -d'.' -f1 | cut -d'Z' -f1)
                printf "${GRAY}last: %s${NC}" "$LAST_TIME"
            fi

            echo "                    │"
        done

        echo -e "│                                                                  │"
        echo -e "│  ${GREEN}○${NC} Idle  ${YELLOW}●${NC} Working  ${RED}■${NC} Blocked                               │"
    else
        echo -e "│  No agent status data found                                      │"
    fi

    echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Recent Activity
    echo -e "${YELLOW}┌─ RECENT ACTIVITY ──────────────────────────────────────────────┐${NC}"

    if [ -f "$FORGE_DIR/progress.json" ]; then
        ACTIVITY_COUNT=$(jq '.recent_activity | length' "$FORGE_DIR/progress.json" 2>/dev/null || echo "0")

        if [ "$ACTIVITY_COUNT" -gt 0 ]; then
            echo -e "│                                                                  │"
            jq -r '.recent_activity[:5] | .[] | "│  [\(.timestamp | split("T")[1] | split(".")[0] | split("Z")[0])] \(.agent): \(.action) \(.ticket // "")"' "$FORGE_DIR/progress.json" 2>/dev/null | while read line; do
                printf "%-68s│\n" "$line"
            done
            echo -e "│                                                                  │"
        else
            echo -e "│  No recent activity                                              │"
        fi
    else
        echo -e "│  No activity data found                                          │"
    fi

    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Blockers
    if [ -f "$FORGE_DIR/progress.json" ]; then
        BLOCKER_COUNT=$(jq '.blockers | length' "$FORGE_DIR/progress.json" 2>/dev/null || echo "0")

        if [ "$BLOCKER_COUNT" -gt 0 ]; then
            echo -e "${RED}┌─ BLOCKERS ($BLOCKER_COUNT) ────────────────────────────────────────────────┐${NC}"
            echo -e "│                                                                  │"
            jq -r '.blockers[] | "│  ⚠ \(.ticket): \(.reason)"' "$FORGE_DIR/progress.json" 2>/dev/null | while read line; do
                printf "%-68s│\n" "$line"
            done
            echo -e "│                                                                  │"
            echo -e "${RED}└──────────────────────────────────────────────────────────────────┘${NC}"
            echo ""
        fi
    fi

    # Active Tickets
    echo -e "${BLUE}┌─ ACTIVE TICKETS ───────────────────────────────────────────────┐${NC}"

    if [ -f "$FORGE_DIR/backlog/tickets.json" ]; then
        ACTIVE_COUNT=$(jq '[.tickets[] | select(.status == "in_progress" or .status == "review" or .status == "testing")] | length' "$FORGE_DIR/backlog/tickets.json" 2>/dev/null || echo "0")

        if [ "$ACTIVE_COUNT" -gt 0 ]; then
            echo -e "│                                                                  │"
            jq -r '.tickets[] | select(.status == "in_progress" or .status == "review" or .status == "testing") | "│  \(.id) [\(.status | .[0:10])] \(.title | .[0:35])"' "$FORGE_DIR/backlog/tickets.json" 2>/dev/null | while read line; do
                printf "%-68s│\n" "$line"
            done
            echo -e "│                                                                  │"
        else
            echo -e "│  No active tickets                                               │"
        fi
    else
        echo -e "│  No tickets file found                                           │"
    fi

    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Footer
    echo -e "${GRAY}Press Ctrl+C to exit${NC}"
    if [ "$WATCH_MODE" = "--watch" ]; then
        echo -e "${GRAY}Auto-refreshing every 2 seconds...${NC}"
    else
        echo -e "${GRAY}Run with --watch for auto-refresh${NC}"
    fi
}

# Main
if [ "$WATCH_MODE" = "--watch" ]; then
    while true; do
        render_dashboard
        sleep 2
    done
else
    render_dashboard
fi
