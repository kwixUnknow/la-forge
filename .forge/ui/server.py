#!/usr/bin/env python3
"""
Lightweight backend server for La Forge Kanban UI.
Handles ticket CRUD operations and file watching.
"""
import json
import os
from datetime import datetime
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import time

# Configuration
FORGE_DIR = Path(__file__).parent.parent
TICKETS_FILE = FORGE_DIR / "backlog" / "tickets.json"
AGENT_STATE_DIR = FORGE_DIR / "agent-state"
PORT = 8765

# Ensure directories exist
TICKETS_FILE.parent.mkdir(parents=True, exist_ok=True)
AGENT_STATE_DIR.mkdir(parents=True, exist_ok=True)


class TicketManager:
    """Manages ticket operations"""

    def __init__(self, tickets_file: Path):
        self.tickets_file = tickets_file
        self._ensure_file()

    def _ensure_file(self):
        """Ensure tickets file exists"""
        if not self.tickets_file.exists():
            self._write_tickets([])

    def _read_tickets(self) -> list:
        """Read tickets from file"""
        try:
            with open(self.tickets_file, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def _write_tickets(self, tickets: list):
        """Write tickets to file"""
        with open(self.tickets_file, 'w') as f:
            json.dump(tickets, f, indent=2)

    def get_all(self) -> list:
        """Get all tickets"""
        return self._read_tickets()

    def get_by_id(self, ticket_id: str) -> dict | None:
        """Get ticket by ID"""
        tickets = self._read_tickets()
        return next((t for t in tickets if t['id'] == ticket_id), None)

    def create(self, data: dict) -> dict:
        """Create new ticket"""
        tickets = self._read_tickets()

        # Generate ID
        max_num = 0
        for t in tickets:
            if t['id'].startswith('TICKET-'):
                try:
                    num = int(t['id'].split('-')[1])
                    max_num = max(max_num, num)
                except (IndexError, ValueError):
                    pass

        ticket = {
            'id': f'TICKET-{str(max_num + 1).zfill(3)}',
            'title': data['title'],
            'description': data['description'],
            'status': data.get('status', 'backlog'),
            'assignee': data.get('assignee'),
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
            'history': []
        }

        tickets.append(ticket)
        self._write_tickets(tickets)
        return ticket

    def update(self, ticket_id: str, data: dict) -> dict | None:
        """Update existing ticket"""
        tickets = self._read_tickets()
        ticket = next((t for t in tickets if t['id'] == ticket_id), None)

        if not ticket:
            return None

        # Track history
        if 'status' in data and data['status'] != ticket['status']:
            ticket['history'].append({
                'timestamp': datetime.now().isoformat(),
                'field': 'status',
                'old_value': ticket['status'],
                'new_value': data['status']
            })

        # Update fields
        ticket.update({
            'title': data.get('title', ticket['title']),
            'description': data.get('description', ticket['description']),
            'status': data.get('status', ticket['status']),
            'assignee': data.get('assignee', ticket.get('assignee')),
            'updated_at': datetime.now().isoformat()
        })

        self._write_tickets(tickets)
        return ticket

    def patch(self, ticket_id: str, data: dict) -> dict | None:
        """Partially update ticket (e.g., just status)"""
        tickets = self._read_tickets()
        ticket = next((t for t in tickets if t['id'] == ticket_id), None)

        if not ticket:
            return None

        # Track history for changed fields
        for field in ['status', 'assignee']:
            if field in data and data[field] != ticket.get(field):
                ticket.setdefault('history', []).append({
                    'timestamp': datetime.now().isoformat(),
                    'field': field,
                    'old_value': ticket.get(field),
                    'new_value': data[field]
                })

        # Update only provided fields
        ticket.update({k: v for k, v in data.items() if k in ['status', 'assignee', 'title', 'description']})
        ticket['updated_at'] = datetime.now().isoformat()

        self._write_tickets(tickets)
        return ticket


class KanbanRequestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler for Kanban UI"""

    def __init__(self, *args, **kwargs):
        self.ticket_manager = TicketManager(TICKETS_FILE)
        super().__init__(*args, directory=str(FORGE_DIR / "ui"), **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)

        if parsed.path == '/api/tickets':
            self._send_json(self.ticket_manager.get_all())
        elif parsed.path == '/api/status':
            self._send_json({'healthy': True, 'timestamp': datetime.now().isoformat()})
        else:
            super().do_GET()

    def do_POST(self):
        """Handle POST requests"""
        parsed = urlparse(self.path)

        if parsed.path == '/api/tickets':
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            data = json.loads(body)

            ticket = self.ticket_manager.create(data)
            self._send_json(ticket, status=201)
        else:
            self.send_error(404)

    def do_PUT(self):
        """Handle PUT requests"""
        parsed = urlparse(self.path)

        if parsed.path.startswith('/api/tickets/'):
            ticket_id = parsed.path.split('/')[-1]
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            data = json.loads(body)

            ticket = self.ticket_manager.update(ticket_id, data)
            if ticket:
                self._send_json(ticket)
            else:
                self.send_error(404)
        else:
            self.send_error(404)

    def do_PATCH(self):
        """Handle PATCH requests"""
        parsed = urlparse(self.path)

        if parsed.path.startswith('/api/tickets/'):
            ticket_id = parsed.path.split('/')[-1]
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            data = json.loads(body)

            ticket = self.ticket_manager.patch(ticket_id, data)
            if ticket:
                self._send_json(ticket)
            else:
                self.send_error(404)
        else:
            self.send_error(404)

    def _send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def log_message(self, format, *args):
        """Override to reduce noise"""
        if '/api/' in args[0]:
            print(f"[{self.log_date_time_string()}] {format % args}")


def watch_agent_state():
    """Watch agent state directory for changes"""
    last_check = {}

    while True:
        try:
            if AGENT_STATE_DIR.exists():
                for file in AGENT_STATE_DIR.glob("*.json"):
                    mtime = file.stat().st_mtime
                    if file.name not in last_check or last_check[file.name] != mtime:
                        last_check[file.name] = mtime
                        # In a real implementation, you could broadcast this via WebSocket
                        # For now, polling from frontend is sufficient
        except Exception as e:
            print(f"Error watching agent state: {e}")

        time.sleep(2)


def main():
    """Start the server"""
    # Start file watcher in background
    watcher_thread = threading.Thread(target=watch_agent_state, daemon=True)
    watcher_thread.start()

    # Start HTTP server
    server = HTTPServer(('localhost', PORT), KanbanRequestHandler)
    print(f"\n🔨 La Forge Kanban UI")
    print(f"Server running at: http://localhost:{PORT}")
    print(f"Tickets file: {TICKETS_FILE}")
    print(f"\nPress Ctrl+C to stop\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == '__main__':
    main()
