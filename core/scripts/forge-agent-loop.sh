#!/bin/bash
# forge-agent-loop.sh - Autonomous agent loop with Git workflow
# Usage: forge-agent-loop.sh <role> <project-dir>

ROLE="$1"
PROJECT_DIR="${2:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
FORGE_DIR="$PROJECT_DIR/.forge"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

case "$ROLE" in
    supervisor) MODEL="haiku"; COLOR="$MAGENTA" ;;
    developer) MODEL="sonnet"; COLOR="$GREEN" ;;
    code-reviewer) MODEL="haiku"; COLOR="$RED" ;;
    qa-tester) MODEL="haiku"; COLOR="$YELLOW" ;;
    *) echo "Usage: $0 <supervisor|developer|code-reviewer|qa-tester> [project-dir]"; exit 1 ;;
esac

INBOX="$FORGE_DIR/agent-state/$ROLE/inbox.json"
TICKETS="$FORGE_DIR/backlog/tickets.json"

log() { echo -e "${COLOR}[$ROLE]${NC} $(date '+%H:%M:%S') $1"; }

run_claude() {
    local prompt="$1"
    cd "$PROJECT_DIR"
    claude -p "$prompt" --model "$MODEL" --dangerously-skip-permissions 2>&1
}

# Main loop
log "Starting autonomous agent loop (with Git workflow)"
log "Model: $MODEL"
log "Project: $PROJECT_DIR"
echo ""

IDLE_COUNT=0

while true; do
    case "$ROLE" in
        supervisor)
            TODO_TICKET=$(jq -r '[.tickets[] | select(.status == "todo")][0].id // empty' "$TICKETS" 2>/dev/null)
            if [ -n "$TODO_TICKET" ]; then
                log "Found unassigned ticket: $TODO_TICKET"

                # Convert ticket ID to branch name (TICKET-001 -> ticket-001)
                BRANCH_NAME="feature/$(echo $TODO_TICKET | tr '[:upper:]' '[:lower:]')"

                log "${CYAN}Updating ticket status...${NC}"
                run_claude "Run: jq '.tickets[0].status = \"in_progress\"' \"$TICKETS\" > /tmp/t.json && mv /tmp/t.json \"$TICKETS\""

                log "${CYAN}Adding task to developer inbox (with branch info)...${NC}"
                run_claude "Run: jq '.pending_tasks += [{\"ticket_id\": \"$TODO_TICKET\", \"action\": \"implement\", \"branch\": \"$BRANCH_NAME\", \"assigned_by\": \"supervisor\"}]' \"$FORGE_DIR/agent-state/developer/inbox.json\" > /tmp/d.json && mv /tmp/d.json \"$FORGE_DIR/agent-state/developer/inbox.json\""

                log "Ticket $TODO_TICKET assigned to developer (branch: $BRANCH_NAME)"
                IDLE_COUNT=0
            else
                IDLE_COUNT=$((IDLE_COUNT + 1))
                [ $((IDLE_COUNT % 6)) -eq 0 ] && log "No todo tickets. Waiting..."
                sleep 10
                continue
            fi
            ;;

        developer)
            TASK=$(jq -r '.pending_tasks[0] // empty' "$INBOX" 2>/dev/null)
            if [ -n "$TASK" ] && [ "$TASK" != "null" ]; then
                TICKET_ID=$(echo "$TASK" | jq -r '.ticket_id // empty')
                BRANCH=$(echo "$TASK" | jq -r '.branch // empty')

                if [ -n "$TICKET_ID" ] && [ "$TICKET_ID" != "null" ]; then
                    log "Found task: $TICKET_ID"

                    # Default branch name if not provided
                    [ -z "$BRANCH" ] && BRANCH="feature/$(echo $TICKET_ID | tr '[:upper:]' '[:lower:]')"

                    # Get ticket details
                    TITLE=$(jq -r --arg id "$TICKET_ID" '.tickets[] | select(.id == $id) | .title' "$TICKETS" 2>/dev/null)
                    DESC=$(jq -r --arg id "$TICKET_ID" '.tickets[] | select(.id == $id) | .description' "$TICKETS" 2>/dev/null)

                    # 1. Create branch
                    log "${CYAN}Creating branch: $BRANCH${NC}"
                    run_claude "Run: cd \"$PROJECT_DIR\" && git checkout -b \"$BRANCH\" 2>/dev/null || git checkout \"$BRANCH\""

                    # 2. Implement feature
                    log "${CYAN}Implementing ticket...${NC}"
                    run_claude "You are the developer. Implement this ticket:
Ticket: $TICKET_ID
Title: $TITLE
Description: $DESC

Create the necessary files and code. Be concise."

                    # 3. Commit changes
                    log "${CYAN}Committing changes...${NC}"
                    COMMIT_MSG="feat($TICKET_ID): $TITLE"
                    run_claude "Run: cd \"$PROJECT_DIR\" && git add -A && git commit -m \"$COMMIT_MSG\" --no-verify 2>/dev/null || echo 'Nothing to commit'"

                    # 4. Push branch
                    log "${CYAN}Pushing branch...${NC}"
                    run_claude "Run: cd \"$PROJECT_DIR\" && git push -u origin \"$BRANCH\" 2>/dev/null || echo 'Push failed or no remote'"

                    # 5. Create PR
                    log "${CYAN}Creating PR...${NC}"
                    PR_BODY="## $TICKET_ID: $TITLE

$DESC

---
Automated PR by La Forge Developer Agent"

                    PR_RESULT=$(run_claude "Run: cd \"$PROJECT_DIR\" && gh pr create --title \"$COMMIT_MSG\" --body \"$PR_BODY\" --head \"$BRANCH\" 2>/dev/null || echo 'PR_FAILED'")

                    # Extract PR number if created
                    PR_URL=$(echo "$PR_RESULT" | grep -o 'https://github.com/[^[:space:]]*' | head -1)
                    PR_NUM=$(echo "$PR_URL" | grep -o '[0-9]*$')

                    log "PR created: $PR_URL"

                    # 6. Update ticket to review
                    log "${CYAN}Updating ticket to review...${NC}"
                    run_claude "Run: jq '(.tickets[] | select(.id == \"$TICKET_ID\")).status = \"review\"' \"$TICKETS\" > /tmp/t.json && mv /tmp/t.json \"$TICKETS\""

                    # 7. Clear inbox
                    log "${CYAN}Clearing inbox...${NC}"
                    run_claude "Run: jq '.pending_tasks = []' \"$INBOX\" > /tmp/i.json && mv /tmp/i.json \"$INBOX\""

                    # 8. Add to reviewer inbox with PR info
                    log "${CYAN}Adding to reviewer inbox...${NC}"
                    run_claude "Run: jq '.pending_tasks += [{\"ticket_id\": \"$TICKET_ID\", \"action\": \"review\", \"branch\": \"$BRANCH\", \"pr_url\": \"$PR_URL\", \"pr_number\": \"$PR_NUM\"}]' \"$FORGE_DIR/agent-state/code-reviewer/inbox.json\" > /tmp/r.json && mv /tmp/r.json \"$FORGE_DIR/agent-state/code-reviewer/inbox.json\""

                    # 9. Checkout main
                    run_claude "Run: cd \"$PROJECT_DIR\" && git checkout main 2>/dev/null || git checkout master"

                    log "Ticket $TICKET_ID sent to code-reviewer (PR: $PR_NUM)"
                    IDLE_COUNT=0
                else
                    sleep 10
                    continue
                fi
            else
                IDLE_COUNT=$((IDLE_COUNT + 1))
                [ $((IDLE_COUNT % 6)) -eq 0 ] && log "No tasks. Waiting..."
                sleep 10
                continue
            fi
            ;;

        code-reviewer)
            TASK=$(jq -r '.pending_tasks[0] // empty' "$INBOX" 2>/dev/null)
            if [ -n "$TASK" ] && [ "$TASK" != "null" ]; then
                TICKET_ID=$(echo "$TASK" | jq -r '.ticket_id // empty')
                PR_NUM=$(echo "$TASK" | jq -r '.pr_number // empty')
                PR_URL=$(echo "$TASK" | jq -r '.pr_url // empty')
                BRANCH=$(echo "$TASK" | jq -r '.branch // empty')

                if [ -n "$TICKET_ID" ] && [ "$TICKET_ID" != "null" ]; then
                    log "Found review task: $TICKET_ID (PR #$PR_NUM)"

                    # 1. Review the PR
                    log "${CYAN}Reviewing PR #$PR_NUM...${NC}"
                    if [ -n "$PR_NUM" ] && [ "$PR_NUM" != "null" ]; then
                        run_claude "You are the code reviewer. Review PR #$PR_NUM for ticket $TICKET_ID.
Run: gh pr view $PR_NUM --json files,additions,deletions
Then provide a brief code review. Be concise."

                        # 2. Approve the PR
                        log "${CYAN}Approving PR...${NC}"
                        run_claude "Run: cd \"$PROJECT_DIR\" && gh pr review $PR_NUM --approve --body 'LGTM! Approved by Code Review Agent.' 2>/dev/null || echo 'Approval failed'"
                    else
                        log "No PR number, skipping gh review"
                        run_claude "You are the code reviewer. Briefly review the code changes for ticket $TICKET_ID on branch $BRANCH. Be concise."
                    fi

                    # 3. Update ticket to testing
                    log "${CYAN}Updating to testing...${NC}"
                    run_claude "Run: jq '(.tickets[] | select(.id == \"$TICKET_ID\")).status = \"testing\"' \"$TICKETS\" > /tmp/t.json && mv /tmp/t.json \"$TICKETS\""

                    # 4. Clear inbox
                    log "${CYAN}Clearing inbox...${NC}"
                    run_claude "Run: jq '.pending_tasks = []' \"$INBOX\" > /tmp/i.json && mv /tmp/i.json \"$INBOX\""

                    # 5. Add to QA inbox with PR info
                    log "${CYAN}Adding to QA inbox...${NC}"
                    run_claude "Run: jq '.pending_tasks += [{\"ticket_id\": \"$TICKET_ID\", \"action\": \"test\", \"branch\": \"$BRANCH\", \"pr_url\": \"$PR_URL\", \"pr_number\": \"$PR_NUM\"}]' \"$FORGE_DIR/agent-state/qa-tester/inbox.json\" > /tmp/q.json && mv /tmp/q.json \"$FORGE_DIR/agent-state/qa-tester/inbox.json\""

                    log "Ticket $TICKET_ID sent to qa-tester"
                    IDLE_COUNT=0
                else
                    sleep 10
                    continue
                fi
            else
                IDLE_COUNT=$((IDLE_COUNT + 1))
                [ $((IDLE_COUNT % 6)) -eq 0 ] && log "No reviews. Waiting..."
                sleep 10
                continue
            fi
            ;;

        qa-tester)
            TASK=$(jq -r '.pending_tasks[0] // empty' "$INBOX" 2>/dev/null)
            if [ -n "$TASK" ] && [ "$TASK" != "null" ]; then
                TICKET_ID=$(echo "$TASK" | jq -r '.ticket_id // empty')
                PR_NUM=$(echo "$TASK" | jq -r '.pr_number // empty')
                BRANCH=$(echo "$TASK" | jq -r '.branch // empty')

                if [ -n "$TICKET_ID" ] && [ "$TICKET_ID" != "null" ]; then
                    log "Found test task: $TICKET_ID (PR #$PR_NUM)"

                    # 1. Test the implementation
                    log "${CYAN}Testing implementation...${NC}"
                    run_claude "You are the QA tester. Verify ticket $TICKET_ID is implemented correctly. Check if files exist and code looks functional. Be concise."

                    # 2. Merge the PR
                    if [ -n "$PR_NUM" ] && [ "$PR_NUM" != "null" ]; then
                        log "${CYAN}Merging PR #$PR_NUM...${NC}"
                        run_claude "Run: cd \"$PROJECT_DIR\" && gh pr merge $PR_NUM --squash --delete-branch --body 'Merged by QA Agent after testing.' 2>/dev/null || echo 'Merge failed or already merged'"
                    fi

                    # 3. Mark ticket as done
                    log "${CYAN}Marking as done...${NC}"
                    run_claude "Run: jq '(.tickets[] | select(.id == \"$TICKET_ID\")).status = \"done\"' \"$TICKETS\" > /tmp/t.json && mv /tmp/t.json \"$TICKETS\""

                    # 4. Clear inbox
                    log "${CYAN}Clearing inbox...${NC}"
                    run_claude "Run: jq '.pending_tasks = []' \"$INBOX\" > /tmp/i.json && mv /tmp/i.json \"$INBOX\""

                    log "Ticket $TICKET_ID DONE! (PR merged)"
                    IDLE_COUNT=0
                else
                    sleep 10
                    continue
                fi
            else
                IDLE_COUNT=$((IDLE_COUNT + 1))
                [ $((IDLE_COUNT % 6)) -eq 0 ] && log "No tests. Waiting..."
                sleep 10
                continue
            fi
            ;;
    esac

    sleep 3
done
