// State
let tickets = [];
let draggedTicket = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initializeTheme();
    setupDragAndDrop();
    loadTickets();
    startPolling();
});

// Theme management
function initializeTheme() {
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = savedTheme || (prefersDark ? 'dark' : 'light');

    if (theme === 'light') {
        document.body.classList.add('light-mode');
        updateThemeIcon('☀️');
    } else {
        updateThemeIcon('🌙');
    }
}

function toggleTheme() {
    const isLight = document.body.classList.toggle('light-mode');
    const theme = isLight ? 'light' : 'dark';

    localStorage.setItem('theme', theme);
    updateThemeIcon(isLight ? '☀️' : '🌙');
}

function updateThemeIcon(icon) {
    const themeToggle = document.getElementById('themeToggle');
    if (themeToggle) {
        themeToggle.textContent = icon;
    }
}

// Load tickets from backend
async function loadTickets() {
    try {
        const response = await fetch('/api/tickets');
        if (response.ok) {
            tickets = await response.json();
            console.log('Loaded tickets:', tickets);
            renderBoard();
            updateSystemStatus('active');
        } else {
            console.error('Failed to load tickets:', response.status);
            updateSystemStatus('error');
        }
    } catch (error) {
        console.error('Failed to load tickets:', error);
        updateSystemStatus('error');
    }
}

// Render the Kanban board
function renderBoard() {
    const statuses = ['backlog', 'todo', 'in_progress', 'review', 'testing', 'done'];

    console.log('Rendering board with', tickets.length, 'tickets');

    statuses.forEach(status => {
        const zone = document.getElementById(`zone-${status}`);
        const count = document.getElementById(`count-${status}`);

        const statusTickets = tickets.filter(t => t.status === status);
        console.log(`Status ${status}:`, statusTickets.length, 'tickets');
        count.textContent = statusTickets.length;

        zone.innerHTML = '';
        statusTickets.forEach(ticket => {
            zone.appendChild(createTicketElement(ticket));
        });
    });
}

// Create ticket DOM element
function createTicketElement(ticket) {
    const div = document.createElement('div');
    div.className = 'ticket';
    div.draggable = true;
    div.dataset.ticketId = ticket.id;

    const assigneeHtml = ticket.assignee
        ? `<div class="ticket-assignee">
             <div class="agent-avatar">${ticket.assignee.charAt(0).toUpperCase()}</div>
             <span>${ticket.assignee}</span>
           </div>`
        : '<span>Unassigned</span>';

    div.innerHTML = `
        <div class="ticket-id">${ticket.id}</div>
        <div class="ticket-title">${escapeHtml(ticket.title)}</div>
        <div class="ticket-description">${escapeHtml(ticket.description || '')}</div>
        <div class="ticket-meta">
            ${assigneeHtml}
            <span>${formatDate(ticket.updated_at || ticket.created_at)}</span>
        </div>
    `;

    div.addEventListener('click', () => openEditTicketModal(ticket));

    return div;
}

// Drag and drop setup
function setupDragAndDrop() {
    document.addEventListener('dragstart', (e) => {
        if (e.target.classList.contains('ticket')) {
            draggedTicket = e.target.dataset.ticketId;
            e.target.classList.add('dragging');
        }
    });

    document.addEventListener('dragend', (e) => {
        if (e.target.classList.contains('ticket')) {
            e.target.classList.remove('dragging');
            draggedTicket = null;
        }
    });

    document.querySelectorAll('.drop-zone').forEach(zone => {
        zone.addEventListener('dragover', (e) => {
            e.preventDefault();
            zone.classList.add('drag-over');
        });

        zone.addEventListener('dragleave', () => {
            zone.classList.remove('drag-over');
        });

        zone.addEventListener('drop', async (e) => {
            e.preventDefault();
            zone.classList.remove('drag-over');

            if (draggedTicket) {
                const newStatus = zone.id.replace('zone-', '');
                await updateTicketStatus(draggedTicket, newStatus);
            }
        });
    });
}

// Update ticket status
async function updateTicketStatus(ticketId, newStatus) {
    try {
        const response = await fetch(`/api/tickets/${ticketId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: newStatus })
        });

        if (response.ok) {
            const ticket = tickets.find(t => t.id === ticketId);
            if (ticket) {
                ticket.status = newStatus;
                ticket.updated_at = new Date().toISOString();
                renderBoard();
            }
        }
    } catch (error) {
        console.error('Failed to update ticket:', error);
    }
}

// Modal functions
function openCreateTicketModal() {
    document.getElementById('modalTitle').textContent = 'Create Ticket';
    document.getElementById('ticketForm').reset();
    document.getElementById('ticketId').value = '';
    document.getElementById('ticketModal').classList.add('active');
}

function openEditTicketModal(ticket) {
    document.getElementById('modalTitle').textContent = 'Edit Ticket';
    document.getElementById('ticketId').value = ticket.id;
    document.getElementById('ticketTitle').value = ticket.title;
    document.getElementById('ticketDescription').value = ticket.description;
    document.getElementById('ticketStatus').value = ticket.status;
    document.getElementById('ticketAssignee').value = ticket.assignee || '';
    document.getElementById('ticketModal').classList.add('active');
}

function closeTicketModal() {
    document.getElementById('ticketModal').classList.remove('active');
}

// Save ticket
async function saveTicket(event) {
    event.preventDefault();

    const ticketId = document.getElementById('ticketId').value;
    const ticketData = {
        title: document.getElementById('ticketTitle').value,
        description: document.getElementById('ticketDescription').value,
        status: document.getElementById('ticketStatus').value,
        assignee: document.getElementById('ticketAssignee').value || null
    };

    try {
        if (ticketId) {
            // Update existing
            const response = await fetch(`/api/tickets/${ticketId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(ticketData)
            });

            if (response.ok) {
                const updated = await response.json();
                const index = tickets.findIndex(t => t.id === ticketId);
                if (index !== -1) {
                    tickets[index] = updated;
                }
            }
        } else {
            // Create new
            const response = await fetch('/api/tickets', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(ticketData)
            });

            if (response.ok) {
                const newTicket = await response.json();
                tickets.push(newTicket);
            }
        }

        renderBoard();
        closeTicketModal();
    } catch (error) {
        console.error('Failed to save ticket:', error);
        alert('Failed to save ticket');
    }
}

// Refresh board
async function refreshBoard() {
    await loadTickets();
}

// Polling for updates
function startPolling() {
    setInterval(async () => {
        try {
            const response = await fetch('/api/status');
            if (response.ok) {
                const status = await response.json();
                updateSystemStatus(status.healthy ? 'active' : 'error');
            }
        } catch (error) {
            updateSystemStatus('error');
        }
    }, 5000);
}

// Update system status indicator
function updateSystemStatus(status) {
    const dot = document.getElementById('systemStatus');
    const text = document.getElementById('systemStatusText');

    if (status === 'active') {
        dot.classList.add('active');
        text.textContent = 'Online';
    } else {
        dot.classList.remove('active');
        text.textContent = 'Offline';
    }
}

// Utility functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(isoString) {
    if (!isoString) return 'N/A';
    const date = new Date(isoString);
    if (isNaN(date.getTime())) return 'N/A';

    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return date.toLocaleDateString();
}

// Close modal on escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeTicketModal();
    }
});
