#!/bin/bash

# A simple health check script for the livenessProbe.
# It checks if the main services are running by looking at their PID files.

PID_DIR="/tmp/pids"
CADDY_PID_FILE="$PID_DIR/caddy.pid"
PYTHON_PID_FILE="$PID_DIR/python.pid"

# Configuration
TERMINAL_MAX_COUNT="${TERMINAL_MAX_COUNT:-5}"

# Function to check a single process
check_process() {
    local service_name=$1
    local pid_file=$2

    # Check if the PID file exists
    if [ ! -f "$pid_file" ]; then
        echo "Liveness check failed: PID file for $service_name not found at $pid_file."
        return 1
    fi

    local pid
    pid=$(cat "$pid_file")

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

# Get terminal configuration for a specific terminal number
get_terminal_config() {
    local terminal_num=$1
    local config_name=$2
    local var_name="TERMINAL_${terminal_num}_${config_name}"
    echo "${!var_name}"
}

# Discover enabled terminals by checking environment variables
get_enabled_terminals() {
    local terminals=""
    for i in $(seq 1 "$TERMINAL_MAX_COUNT"); do
        local enabled
        enabled=$(get_terminal_config "$i" "ENABLE")
        if [ "$enabled" = "true" ]; then
            terminals="$terminals $i"
        fi
    done
    echo "$terminals"
}

# Check all enabled TTYD terminals
check_ttyd_terminals() {
    local enabled_terminals
    enabled_terminals=$(get_enabled_terminals)

    if [ -z "$enabled_terminals" ]; then
        echo "No terminals enabled, skipping TTYD checks."
        return 0
    fi

    local failed_count=0
    local total_count
    total_count=$(echo "$enabled_terminals" | wc -w)

    for i in $enabled_terminals; do
        local ttyd_pid_file="$PID_DIR/ttyd$i.pid"
        if ! check_process "TTYD Terminal $i" "$ttyd_pid_file"; then
            failed_count=$((failed_count + 1))
        fi
    done

    if [ $failed_count -gt 0 ]; then
        echo "Liveness check failed: $failed_count out of $total_count TTYD terminals are not running."
        return 1
    fi

    echo "All $total_count TTYD terminals are running."
    return 0
}

# --- Main Health Check Logic ---

# Always check for Caddy and the Python app
check_process "Caddy" "$CADDY_PID_FILE" || exit 1
check_process "Layout" "$PYTHON_PID_FILE" || exit 1

# Check for enabled TTYD terminals
check_ttyd_terminals || exit 1

# If we get here, all required services are running.
echo "Liveness check passed."
exit 0
