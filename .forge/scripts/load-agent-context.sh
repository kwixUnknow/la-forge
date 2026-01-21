#!/bin/bash
# load-agent-context.sh - SessionStart hook to load agent-specific context
# This script runs when a Claude session starts to:
# 1. Set the agent role from environment
# 2. Display pending tasks in the inbox
# 3. Show relevant context for the agent

set -e

# Get environment variables
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FORGE_DIR="$PROJECT_DIR/.forge"
AGENT_ROLE="${FORGE_AGENT_ROLE:-developer}"

# Check if forge is initialized
if [ ! -d "$FORGE_DIR" ]; then
    exit 0
fi

# Output agent context as JSON for Claude to consume
echo "{"
echo "  \"agent_role\": \"$AGENT_ROLE\","

# Read inbox
INBOX_FILE="$FORGE_DIR/agent-state/$AGENT_ROLE/inbox.json"
if [ -f "$INBOX_FILE" ]; then
    PENDING_COUNT=$(jq '.pending_tasks | length' "$INBOX_FILE" 2>/dev/null || echo "0")
    MESSAGE_COUNT=$(jq '.messages | length' "$INBOX_FILE" 2>/dev/null || echo "0")

    echo "  \"pending_tasks\": $PENDING_COUNT,"
    echo "  \"unread_messages\": $MESSAGE_COUNT,"

    if [ "$PENDING_COUNT" -gt 0 ]; then
        FIRST_TASK=$(jq -c '.pending_tasks[0]' "$INBOX_FILE" 2>/dev/null || echo "{}")
        echo "  \"next_task\": $FIRST_TASK,"
    else
        echo "  \"next_task\": null,"
    fi
else
    echo "  \"pending_tasks\": 0,"
    echo "  \"unread_messages\": 0,"
    echo "  \"next_task\": null,"
fi

# Read progress summary
PROGRESS_FILE="$FORGE_DIR/progress.json"
if [ -f "$PROGRESS_FILE" ]; then
    TICKETS_SUMMARY=$(jq -c '.tickets_by_status' "$PROGRESS_FILE" 2>/dev/null || echo "{}")
    echo "  \"tickets_summary\": $TICKETS_SUMMARY,"

    AGENT_STATUS=$(jq -c ".agents_status.$AGENT_ROLE" "$PROGRESS_FILE" 2>/dev/null || echo "{}")
    echo "  \"my_status\": $AGENT_STATUS,"
else
    echo "  \"tickets_summary\": {},"
    echo "  \"my_status\": {},"
fi

# Add timestamp
echo "  \"loaded_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
echo "}"

# Human-readable output to stderr (visible in terminal)
echo "" >&2
echo "========================================" >&2
echo "  FORGE AGENT: $AGENT_ROLE" >&2
echo "  Project: $(basename $PROJECT_DIR)" >&2
echo "========================================" >&2

if [ -f "$INBOX_FILE" ]; then
    PENDING=$(jq '.pending_tasks | length' "$INBOX_FILE" 2>/dev/null || echo "0")
    MESSAGES=$(jq '.messages | length' "$INBOX_FILE" 2>/dev/null || echo "0")

    echo "" >&2
    echo "Inbox:" >&2
    echo "  Pending tasks: $PENDING" >&2
    echo "  Messages: $MESSAGES" >&2

    if [ "$PENDING" -gt 0 ]; then
        echo "" >&2
        echo "Next task:" >&2
        jq -r '.pending_tasks[0] | "  Ticket: \(.ticket_id)\n  Action: \(.action)"' "$INBOX_FILE" 2>/dev/null >&2
    fi
fi

if [ -f "$PROGRESS_FILE" ]; then
    echo "" >&2
    echo "Backlog overview:" >&2
    jq -r '.tickets_by_status | to_entries | .[] | "  \(.key): \(.value)"' "$PROGRESS_FILE" 2>/dev/null >&2
fi

echo "" >&2
echo "Commands:" >&2
echo "  Read inbox: jq . .forge/agent-state/$AGENT_ROLE/inbox.json" >&2
echo "  See tickets: jq '.tickets[] | {id,title,status}' .forge/backlog/tickets.json" >&2
echo "========================================" >&2
echo "" >&2

exit 0
