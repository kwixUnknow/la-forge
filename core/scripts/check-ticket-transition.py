#!/usr/bin/env python3
"""
PostToolUse hook: Detect ticket state changes and signal agent handoffs.
Runs after every Write operation to check if tickets.json was modified.

Exit codes:
- 0: Success (approve the operation)
- 2: Block the operation (with reason in stdout)
"""
import json
import sys
import os
from pathlib import Path
from datetime import datetime

# Get project directory from environment or current dir
PROJECT_DIR = Path(os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd()))
FORGE_DIR = PROJECT_DIR / '.forge'
TICKETS_FILE = FORGE_DIR / 'backlog' / 'tickets.json'
PROGRESS_FILE = FORGE_DIR / 'progress.json'
SIGNAL_FILE = FORGE_DIR / 'agent-state' / 'handoff-signal.json'

# Agent transitions based on ticket status
AGENT_TRANSITIONS = {
    'todo': 'developer',
    'in_progress': 'developer',
    'review': 'code-reviewer',
    'testing': 'qa-tester',
}


def main():
    try:
        # Read hook input from stdin
        input_data = sys.stdin.read()
        if not input_data:
            sys.exit(0)

        data = json.loads(input_data)
        tool_input = data.get('tool_input', {})
        file_path = tool_input.get('file_path', '')

        # Only care about ticket-related writes
        if 'tickets.json' not in file_path and 'outbox.json' not in file_path:
            sys.exit(0)

        # Check if forge is initialized
        if not FORGE_DIR.exists():
            sys.exit(0)

        # Process based on file type
        if 'tickets.json' in file_path:
            process_ticket_change()
        elif 'outbox.json' in file_path:
            process_agent_completion()

        sys.exit(0)

    except json.JSONDecodeError:
        # Not JSON input, ignore
        sys.exit(0)
    except Exception as e:
        # Log error but don't block
        print(f"Hook warning: {e}", file=sys.stderr)
        sys.exit(0)


def process_ticket_change():
    """Check for tickets needing assignment after a ticket file change."""
    if not TICKETS_FILE.exists():
        return

    with open(TICKETS_FILE) as f:
        data = json.load(f)

    for ticket in data.get('tickets', []):
        status = ticket.get('status')
        assignee = ticket.get('assignee')
        ticket_id = ticket.get('id')

        # If ticket has status that needs an agent but no assignee, signal handoff
        if status in AGENT_TRANSITIONS and not assignee:
            next_agent = AGENT_TRANSITIONS[status]
            signal_handoff(ticket_id, next_agent, status)
            update_progress(ticket_id, next_agent, status)


def process_agent_completion():
    """Process when an agent writes to their outbox."""
    # Get the agent role from environment
    agent_role = os.environ.get('FORGE_AGENT_ROLE')
    if not agent_role:
        return

    outbox_file = FORGE_DIR / 'agent-state' / agent_role / 'outbox.json'
    if not outbox_file.exists():
        return

    with open(outbox_file) as f:
        outbox = json.load(f)

    # Check for completed tasks that need status transition
    completed = outbox.get('completed_tasks', [])
    for task in completed:
        ticket_id = task.get('ticket_id')
        next_status = task.get('next_status')

        if ticket_id and next_status:
            # Update ticket status
            update_ticket_status(ticket_id, next_status, agent_role)


def signal_handoff(ticket_id: str, agent: str, status: str):
    """Write handoff signal for the watcher to pick up."""
    SIGNAL_FILE.parent.mkdir(parents=True, exist_ok=True)

    signal = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'ticket_id': ticket_id,
        'agent': agent,
        'status': status,
        'action': 'assign'
    }

    with open(SIGNAL_FILE, 'w') as f:
        json.dump(signal, f, indent=2)

    # Also write to agent's inbox
    write_to_inbox(agent, ticket_id, status)


def write_to_inbox(agent: str, ticket_id: str, status: str):
    """Add task to agent's inbox."""
    inbox_file = FORGE_DIR / 'agent-state' / agent / 'inbox.json'
    inbox_file.parent.mkdir(parents=True, exist_ok=True)

    inbox = {'pending_tasks': [], 'messages': []}
    if inbox_file.exists():
        with open(inbox_file) as f:
            inbox = json.load(f)

    # Check if task already exists
    existing_ids = [t.get('ticket_id') for t in inbox['pending_tasks']]
    if ticket_id in existing_ids:
        return

    # Add new task
    task = {
        'task_id': f"task-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
        'ticket_id': ticket_id,
        'action': get_action_for_status(status),
        'assigned_at': datetime.utcnow().isoformat() + 'Z',
        'assigned_by': 'hook-system'
    }

    inbox['pending_tasks'].append(task)

    with open(inbox_file, 'w') as f:
        json.dump(inbox, f, indent=2)


def get_action_for_status(status: str) -> str:
    """Map status to action verb."""
    actions = {
        'todo': 'implement',
        'in_progress': 'implement',
        'review': 'review',
        'testing': 'test'
    }
    return actions.get(status, 'process')


def update_ticket_status(ticket_id: str, new_status: str, agent: str):
    """Update ticket status in tickets.json."""
    if not TICKETS_FILE.exists():
        return

    with open(TICKETS_FILE) as f:
        data = json.load(f)

    for ticket in data.get('tickets', []):
        if ticket['id'] == ticket_id:
            old_status = ticket.get('status')
            if old_status == new_status:
                return  # No change needed

            ticket['status'] = new_status
            ticket['assignee'] = None  # Clear for next agent
            ticket['updated_at'] = datetime.utcnow().isoformat() + 'Z'

            # Update timestamps
            if new_status == 'in_progress' and not ticket.get('started_at'):
                ticket['started_at'] = datetime.utcnow().isoformat() + 'Z'
            elif new_status == 'done':
                ticket['completed_at'] = datetime.utcnow().isoformat() + 'Z'

            # Add history entry
            if 'history' not in ticket:
                ticket['history'] = []
            ticket['history'].append({
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'from_status': old_status,
                'to_status': new_status,
                'agent': agent,
                'comment': f'Automatic transition by {agent}'
            })
            break

    with open(TICKETS_FILE, 'w') as f:
        json.dump(data, f, indent=2)

    # Signal for next agent
    if new_status in AGENT_TRANSITIONS:
        signal_handoff(ticket_id, AGENT_TRANSITIONS[new_status], new_status)


def update_progress(ticket_id: str, agent: str, status: str):
    """Update progress.json with recent activity."""
    if not PROGRESS_FILE.exists():
        return

    with open(PROGRESS_FILE) as f:
        progress = json.load(f)

    progress['last_updated'] = datetime.utcnow().isoformat() + 'Z'

    # Update agent status
    if agent in progress.get('agents_status', {}):
        progress['agents_status'][agent]['status'] = 'pending'
        progress['agents_status'][agent]['current_ticket'] = ticket_id

    # Add to recent activity
    activity = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'agent': 'hook-system',
        'action': 'signaled',
        'ticket': ticket_id,
        'to': agent
    }

    if 'recent_activity' not in progress:
        progress['recent_activity'] = []
    progress['recent_activity'].insert(0, activity)
    progress['recent_activity'] = progress['recent_activity'][:20]  # Keep last 20

    # Update ticket counts
    if TICKETS_FILE.exists():
        with open(TICKETS_FILE) as f:
            tickets = json.load(f)

        counts = {}
        for ticket in tickets.get('tickets', []):
            s = ticket.get('status', 'backlog')
            counts[s] = counts.get(s, 0) + 1
        progress['tickets_by_status'] = counts

    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)


if __name__ == '__main__':
    main()
