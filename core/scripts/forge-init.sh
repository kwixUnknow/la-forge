#!/bin/bash
# forge-init.sh - Initialize .forge/ directory structure for multi-agent development
# Usage: forge-init.sh [project-dir]

set -e

PROJECT_DIR="${1:-.}"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
FORGE_DIR="$PROJECT_DIR/.forge"
LA_FORGE_DIR="$HOME/la-forge"

echo "=========================================="
echo "  Initializing Forge for: $(basename $PROJECT_DIR)"
echo "=========================================="

# Check if already initialized
if [ -d "$FORGE_DIR" ]; then
    echo "Warning: .forge/ already exists. Skipping initialization."
    echo "To reinitialize, remove .forge/ first."
    exit 0
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$FORGE_DIR"/{backlog/archive,agent-state/{supervisor,developer,code-reviewer,qa-tester,planner,devops,documenter},reviews,decisions,scripts,metrics}

# Copy schema
echo "Setting up backlog..."
cp "$LA_FORGE_DIR/core/backlog/schema.json" "$FORGE_DIR/backlog/"
cp "$LA_FORGE_DIR/core/backlog/tickets.template.json" "$FORGE_DIR/backlog/tickets.json"

# Initialize empty inboxes for each agent
echo "Initializing agent state..."
AGENTS=("supervisor" "developer" "code-reviewer" "qa-tester" "planner" "devops" "documenter")

for agent in "${AGENTS[@]}"; do
    cat > "$FORGE_DIR/agent-state/$agent/inbox.json" << 'EOF'
{
  "pending_tasks": [],
  "messages": []
}
EOF
    cat > "$FORGE_DIR/agent-state/$agent/outbox.json" << 'EOF'
{
  "completed_tasks": [],
  "blocked_tasks": [],
  "metrics": {}
}
EOF
done

# Initialize progress file
echo "Setting up progress tracking..."
cat > "$FORGE_DIR/progress.json" << EOF
{
  "last_updated": null,
  "project": "$(basename $PROJECT_DIR)",
  "sprint": null,
  "tickets_by_status": {
    "backlog": 0,
    "todo": 0,
    "in_progress": 0,
    "review": 0,
    "testing": 0,
    "done": 0
  },
  "agents_status": {
    "supervisor": { "status": "idle", "current_ticket": null, "last_active": null },
    "developer": { "status": "idle", "current_ticket": null, "last_active": null },
    "code-reviewer": { "status": "idle", "current_ticket": null, "last_active": null },
    "qa-tester": { "status": "idle", "current_ticket": null, "last_active": null }
  },
  "recent_activity": [],
  "blockers": []
}
EOF

# Initialize metrics file
cat > "$FORGE_DIR/metrics.json" << 'EOF'
{
  "period_start": null,
  "cycle_times": {
    "average_hours": 0,
    "by_type": {},
    "by_complexity": {}
  },
  "throughput": {
    "tickets_per_day": 0,
    "by_week": []
  },
  "agent_utilization": {},
  "quality_metrics": {
    "review_rejection_rate": 0,
    "test_failure_rate": 0,
    "bugs_per_feature": 0
  }
}
EOF

# Copy hook scripts
echo "Installing hook scripts..."
cp "$LA_FORGE_DIR/core/scripts/check-ticket-transition.py" "$FORGE_DIR/scripts/" 2>/dev/null || echo "  - check-ticket-transition.py not found, will create later"
cp "$LA_FORGE_DIR/core/scripts/agent-handoff.py" "$FORGE_DIR/scripts/" 2>/dev/null || echo "  - agent-handoff.py not found, will create later"
cp "$LA_FORGE_DIR/core/scripts/load-agent-context.sh" "$FORGE_DIR/scripts/" 2>/dev/null || echo "  - load-agent-context.sh not found, will create later"

# Make scripts executable
chmod +x "$FORGE_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$FORGE_DIR/scripts/"*.py 2>/dev/null || true

# Copy agents to project
echo "Installing agent definitions..."
mkdir -p "$PROJECT_DIR/.claude/agents"
if [ -d "$LA_FORGE_DIR/core/agents" ]; then
    cp "$LA_FORGE_DIR/core/agents/"*.md "$PROJECT_DIR/.claude/agents/" 2>/dev/null || echo "  - No agents found yet"
fi

# Update .gitignore
echo "Updating .gitignore..."
if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q ".forge/agent-state" "$PROJECT_DIR/.gitignore"; then
        cat >> "$PROJECT_DIR/.gitignore" << 'EOF'

# Forge agent state (transient)
.forge/agent-state/
.forge/kanban-db/
.forge/metrics.json
EOF
    fi
else
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# Forge agent state (transient)
.forge/agent-state/
.forge/kanban-db/
.forge/metrics.json
EOF
fi

# Create or update .claude/settings.json with hooks
echo "Configuring Claude Code hooks..."
mkdir -p "$PROJECT_DIR/.claude"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Merge hooks into existing settings
    tmp_file=$(mktemp)
    jq '. + {
      "hooks": {
        "PostToolUse": [
          {
            "matcher": "Write",
            "hooks": [
              {
                "type": "command",
                "command": "python3 ${CLAUDE_PROJECT_DIR}/.forge/scripts/check-ticket-transition.py",
                "timeout": 5
              }
            ]
          }
        ],
        "SessionStart": [
          {
            "matcher": "*",
            "hooks": [
              {
                "type": "command",
                "command": "bash ${CLAUDE_PROJECT_DIR}/.forge/scripts/load-agent-context.sh",
                "timeout": 5
              }
            ]
          }
        ]
      }
    }' "$SETTINGS_FILE" > "$tmp_file"
    mv "$tmp_file" "$SETTINGS_FILE"
else
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "extraKnownMarketplaces": {
    "la-forge": {
      "source": {
        "source": "path",
        "path": "~/la-forge"
      }
    }
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PROJECT_DIR}/.forge/scripts/check-ticket-transition.py",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.forge/scripts/load-agent-context.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF
fi

echo ""
echo "=========================================="
echo "  Forge initialized successfully!"
echo "=========================================="
echo ""
echo "Structure created:"
echo "  $FORGE_DIR/"
echo "  ├── backlog/tickets.json    # Your tickets"
echo "  ├── agent-state/            # Agent communication"
echo "  ├── progress.json           # Dashboard data"
echo "  └── scripts/                # Hook scripts"
echo ""
echo "Next steps:"
echo "  1. Add tickets to .forge/backlog/tickets.json"
echo "  2. Run: forge-team.sh $PROJECT_DIR"
echo "  3. Or single agent: FORGE_AGENT_ROLE=developer claude"
echo ""
