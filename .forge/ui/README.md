# La Forge Kanban UI

A lightweight local web interface for managing La Forge tickets.

## Features

- **Kanban Board**: Visualize tickets across columns (Backlog, To Do, In Progress, Review, Testing, Done)
- **Drag & Drop**: Move tickets between columns by dragging
- **CRUD Operations**: Create, edit, and update tickets via modal form
- **Real-time Status**: Monitor system health with polling
- **File-based Storage**: Reads/writes to `.forge/backlog/tickets.json`
- **No External Dependencies**: Pure HTML/CSS/JS frontend with Python stdlib backend

## Quick Start

```bash
# From La Forge root directory
./.forge/ui/start.sh
```

Or manually:
```bash
cd .forge/ui
python3 server.py
```

Then open: http://localhost:8765

## Architecture

### Backend (server.py)
- Simple HTTP server using Python's `http.server`
- REST API for ticket operations:
  - `GET /api/tickets` - List all tickets
  - `POST /api/tickets` - Create ticket
  - `PUT /api/tickets/:id` - Update ticket
  - `PATCH /api/tickets/:id` - Partial update (e.g., drag & drop status change)
  - `GET /api/status` - Health check
- File watcher for `.forge/agent-state/` (monitoring agent activity)
- Serves static files (index.html, app.js)

### Frontend
- **index.html**: Single-page app with embedded CSS
- **app.js**: Vanilla JavaScript for:
  - Ticket CRUD operations
  - Drag & drop functionality
  - Modal dialogs
  - Polling for updates
  - Real-time status indicators

## File Structure

```
.forge/ui/
├── index.html       # Main HTML with embedded CSS
├── app.js           # Frontend logic
├── server.py        # Backend server
├── start.sh         # Startup script
└── README.md        # This file

.forge/backlog/
└── tickets.json     # Ticket storage

.forge/agent-state/
└── *.json           # Agent status files (watched)
```

## Ticket Schema

```json
{
  "id": "TICKET-001",
  "title": "Task title",
  "description": "Task description",
  "status": "backlog",
  "assignee": "developer",
  "created_at": "2026-01-21T10:00:00",
  "updated_at": "2026-01-21T10:30:00",
  "history": [
    {
      "timestamp": "2026-01-21T10:30:00",
      "field": "status",
      "old_value": "backlog",
      "new_value": "in_progress"
    }
  ]
}
```

## Development

The UI is intentionally minimal with no build step or external dependencies.

To modify:
1. Edit `index.html` for structure/styling
2. Edit `app.js` for frontend logic
3. Edit `server.py` for backend API
4. Refresh browser to see changes

## Port Configuration

Default port: **8765**

To change, edit `PORT` in `server.py`:
```python
PORT = 8765  # Change this value
```

## Integration with Agents

The server watches `.forge/agent-state/*.json` for agent activity updates. Agents should write their status to files like:

```json
{
  "agent": "developer",
  "status": "working",
  "current_ticket": "TICKET-001",
  "timestamp": "2026-01-21T10:30:00"
}
```

The UI polls `/api/status` every 5 seconds to update the system status indicator.

## Future Enhancements

Potential improvements:
- WebSocket support for real-time updates (vs polling)
- Ticket filtering and search
- Detailed ticket history view
- Agent assignment UI with live status
- Dark/light theme toggle
- Export to CSV/JSON
