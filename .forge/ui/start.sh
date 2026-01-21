#!/bin/bash
# Start La Forge Kanban UI

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🔨 Starting La Forge Kanban UI..."
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not found"
    exit 1
fi

# Start the server
cd "$SCRIPT_DIR"
python3 server.py
