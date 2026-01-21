#!/usr/bin/env python3
"""
Stop hook: Handle agent completion and trigger next agent in the workflow.
Runs when an agent session ends.

This hook:
1. Reads the agent's outbox for completed tasks
2. Updates ticket statuses accordingly
3. Signals the next agent in the workflow
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

# Agent transitions based on status
AGENT_TRANSITIONS = {
    'todo': 'developer',
    'in_progress': 'developer',
    'review': 'code-reviewer',
    'testing': 'qa-tester',
}


def main():
    try:
        # Get agent role from environment
        agent_role = os.environ.get('FORGE_AGENT_ROLE', 'unknown')

        # Check if forge is initialized
        if not FORGE_DIR.exists():
            approve_stop("No .forge directory")
            return

        outbox_file = FORGE_DIR / 'agent-state' / agent_role / 'outbox.json'

        if not outbox_file.exists():
            approve_stop(f"No outbox for {agent_role}")
            return

        with open(outbox_file) as f:
            outbox = json.load(f)

        # Process completed tasks
        completed = outbox.get('completed_tasks', [])
        if not completed:
            approve_stop("No completed tasks")
            return

        # Process the most recent completed task
        for task in completed:
            ticket_id = task.get('ticket_id')
            next_status = task.get('next_status')
            result = task.get('result', 'unknown')

            if ticket_id and next_status:
                # Update ticket status
                update_ticket_status(ticket_id, next_status, agent_role)

                # Update progress
                update_progress_on_complete(ticket_id, agent_role, next_status, result)

                # Signal next agent
                if next_status in AGENT_TRANSITIONS:
                    signal_handoff(ticket_id, AGENT_TRANSITIONS[next_status], next_status)

        # Process blocked tasks
        blocked = outbox.get('blocked_tasks', [])
        for task in blocked:
            ticket_id = task.get('ticket_id')
            reason = task.get('reason', 'Unknown blocker')
            if ticket_id:
                mark_ticket_blocked(ticket_id, reason, agent_role)

        # Clear processed tasks from outbox
        clear_outbox(outbox_file, outbox)

        # Approve the stop
        tasks_processed = len(completed) + len(blocked)
        approve_stop(f"Processed {tasks_processed} tasks from {agent_role}")

    except json.JSONDecodeError as e:
        approve_stop(f"JSON error: {e}")
    except Exception as e:
        print(f"Handoff error: {e}", file=sys.stderr)
        approve_stop(f"Error: {e}")


def approve_stop(reason: str):
    """Output approval for the stop hook."""
    result = {
        'decision': 'approve',
        'reason': reason
    }
    print(json.dumps(result))
    sys.exit(0)


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
                return

            ticket['status'] = new_status
            ticket['assignee'] = None
            ticket['updated_at'] = datetime.utcnow().isoformat() + 'Z'

            if new_status == 'done':
                ticket['completed_at'] = datetime.utcnow().isoformat() + 'Z'

            if 'history' not in ticket:
                ticket['history'] = []
            ticket['history'].append({
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'from_status': old_status,
                'to_status': new_status,
                'agent': agent,
                'comment': f'Completed by {agent}'
            })
            break

    with open(TICKETS_FILE, 'w') as f:
        json.dump(data, f, indent=2)


def mark_ticket_blocked(ticket_id: str, reason: str, agent: str):
    """Mark a ticket as blocked."""
    if not TICKETS_FILE.exists():
        return

    with open(TICKETS_FILE) as f:
        data = json.load(f)

    for ticket in data.get('tickets', []):
        if ticket['id'] == ticket_id:
            ticket['status'] = 'blocked'
            ticket['updated_at'] = datetime.utcnow().isoformat() + 'Z'

            if 'history' not in ticket:
                ticket['history'] = []
            ticket['history'].append({
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'from_status': ticket.get('status'),
                'to_status': 'blocked',
                'agent': agent,
                'comment': f'Blocked: {reason}'
            })
            break

    with open(TICKETS_FILE, 'w') as f:
        json.dump(data, f, indent=2)

    # Add to blockers in progress
    add_blocker(ticket_id, reason)


def add_blocker(ticket_id: str, reason: str):
    """Add blocker to progress.json."""
    if not PROGRESS_FILE.exists():
        return

    with open(PROGRESS_FILE) as f:
        progress = json.load(f)

    if 'blockers' not in progress:
        progress['blockers'] = []

    progress['blockers'].append({
        'ticket': ticket_id,
        'reason': reason,
        'since': datetime.utcnow().isoformat() + 'Z'
    })

    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)


def signal_handoff(ticket_id: str, agent: str, status: str):
    """Signal handoff to next agent."""
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

    # Write to agent's inbox
    inbox_file = FORGE_DIR / 'agent-state' / agent / 'inbox.json'
    inbox_file.parent.mkdir(parents=True, exist_ok=True)

    inbox = {'pending_tasks': [], 'messages': []}
    if inbox_file.exists():
        with open(inbox_file) as f:
            inbox = json.load(f)

    # Check if already in inbox
    existing_ids = [t.get('ticket_id') for t in inbox['pending_tasks']]
    if ticket_id not in existing_ids:
        inbox['pending_tasks'].append({
            'task_id': f"task-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
            'ticket_id': ticket_id,
            'action': 'process',
            'assigned_at': datetime.utcnow().isoformat() + 'Z',
            'assigned_by': 'handoff-hook'
        })

        with open(inbox_file, 'w') as f:
            json.dump(inbox, f, indent=2)


def update_progress_on_complete(ticket_id: str, agent: str, new_status: str, result: str):
    """Update progress when agent completes work."""
    if not PROGRESS_FILE.exists():
        return

    with open(PROGRESS_FILE) as f:
        progress = json.load(f)

    progress['last_updated'] = datetime.utcnow().isoformat() + 'Z'

    # Update agent status
    if agent in progress.get('agents_status', {}):
        progress['agents_status'][agent]['status'] = 'idle'
        progress['agents_status'][agent]['current_ticket'] = None
        progress['agents_status'][agent]['last_active'] = datetime.utcnow().isoformat() + 'Z'

    # Add activity
    activity = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'agent': agent,
        'action': 'completed',
        'ticket': ticket_id,
        'result': result,
        'next_status': new_status
    }

    if 'recent_activity' not in progress:
        progress['recent_activity'] = []
    progress['recent_activity'].insert(0, activity)
    progress['recent_activity'] = progress['recent_activity'][:20]

    # Update counts
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


def clear_outbox(outbox_file: Path, outbox: dict):
    """Clear processed tasks from outbox."""
    outbox['completed_tasks'] = []
    outbox['blocked_tasks'] = []

    with open(outbox_file, 'w') as f:
        json.dump(outbox, f, indent=2)


if __name__ == '__main__':
    main()
