#!/bin/bash

# A simple health check script for the livenessProbe.
# It checks if the main services are running by looking at their PID files.

PID_DIR="/tmp/pids"
CADDY_PID_FILE="$PID_DIR/caddy.pid"
PYTHON_PID_FILE="$PID_DIR/python.pid"
TTYD_PID_FILE="$PID_DIR/ttyd.pid"

# Function to check a single process
check_process() {
    local service_name=$1
    local pid_file=$2

    # Check if the PID file exists
    if [ ! -f "$pid_file" ]; then
        echo "Liveness check failed: PID file for $service_name not found at $pid_file."
        return 1
    fi

    local pid=$(cat "$pid_file")

    # Check if PID is a number
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "Liveness check failed: Invalid PID '$pid' found in $pid_file."
        return 1
    fi

    # Check if a process with that PID is running
    # kill -0 <pid> sends a "null" signal, which doesn't harm the process
    # but fails if the process doesn't exist.
    if ! kill -0 "$pid" > /dev/null 2>&1; then
        echo "Liveness check failed: $service_name process (PID $pid) is not running."
        return 1
    fi

    echo "$service_name (PID $pid) is running."
    return 0
}

# --- Main Health Check Logic ---

# Always check for Caddy and the Python app
check_process "Caddy" "$CADDY_PID_FILE" || exit 1
check_process "Layout" "$PYTHON_PID_FILE" || exit 1

# Only check for TTYD if it's supposed to be enabled
if [ "$TERMINAL_ENABLE" = "true" ]; then
    check_process "TTYD" "$TTYD_PID_FILE" || exit 1
fi

# If we get here, all required services are running.
echo "Liveness check passed."
exit 0