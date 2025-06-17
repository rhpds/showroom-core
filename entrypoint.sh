#!/bin/bash

# Multi-service entrypoint script for OpenShift
# Manages Caddy, Layout python web app, and TTYD

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[entrypoint]\t[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[entrypoint]\t[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[entrypoint]\t[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

success() {
    echo -e "${GREEN}[entrypoint]\t[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Configuration - adjust these paths as needed
PYTHON_APP_DIR="/app/layout-engine"
CADDY_CONFIG="/app/caddy/Caddyfile"
STATIC_SITE_DIR="/app/caddy/static"
REPOSITORY_DIR="/app/repository"
PID_DIR="/tmp/pids"


# Environment variables

# Git configuration
GIT_CLONE="${GIT_CLONE:-true}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/rhpds/showroom_template_default.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Antora configuration
ANTORA_BUILD="${ANTORA_BUILD:-true}"
ANTORA_PLAYBOOK="${ANTORA_PLAYBOOK:-default-site.yml}"

# Layout configuration
LAYOUT_CONFIG_NAME="${LAYOUT_CONFIG_NAME:-content}"
LAYOUT_CONFIG_DIR="${LAYOUT_CONFIG_DIR:-/app/layouts}"

# TTYD configuration
TERMINAL_MAX_COUNT="${TERMINAL_MAX_COUNT:-5}"

# Cleanup function
cleanup() {
    log "Shutting down services..."

    if [ ! -d "$PID_DIR" ]; then
        warn "PID directory not found, cannot perform cleanup."
        exit 0
    fi

    # Gracefully terminate all processes found in the PID directory
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid
            local service_name
            pid=$(cat "$pid_file")
            service_name=$(basename "$pid_file" .pid)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log "Stopping $service_name (PID: $pid)..."
                # Kill the entire process group by prefixing the PID with a '-'
                kill -TERM -- "-$pid" 2>/dev/null || true
            fi
        fi
    done

    # Wait for a few seconds for graceful shutdown
    sleep 5

    # Force kill any processes that are still running
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid
            local service_name
            pid=$(cat "$pid_file")
            service_name=$(basename "$pid_file" .pid)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                warn "Force killing $service_name (PID: $pid)..."
                kill -KILL -- "-$pid" 2>/dev/null || true
            fi
        fi
    done

    success "All services stopped."
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Get terminal configuration for a specific terminal number
get_terminal_config() {
    local terminal_num=$1
    local config_name=$2

    # Use eval to get the value of the dynamically named variable
    local var_name="TERMINAL_${terminal_num}_${config_name}"
    eval echo "\$$var_name"
}

# Validate SSH configuration for a specific terminal
validate_terminal_ssh_config() {
    local terminal_num=$1
    local enabled
    enabled=$(get_terminal_config "$terminal_num" "ENABLE")

    if [ "$enabled" != "true" ]; then
        return 0  # Skip validation if terminal is not enabled
    fi

    local command
    local ssh_host
    local ssh_method
    local ssh_user
    local ssh_pass
    local ssh_key_file
    command=$(get_terminal_config "$terminal_num" "COMMAND")
    ssh_host=$(get_terminal_config "$terminal_num" "SSH_HOST")
    ssh_method=$(get_terminal_config "$terminal_num" "SSH_METHOD")
    ssh_user=$(get_terminal_config "$terminal_num" "SSH_USER")
    ssh_pass=$(get_terminal_config "$terminal_num" "SSH_PASS")
    ssh_key_file=$(get_terminal_config "$terminal_num" "SSH_PRIVATE_KEY_FILE")

    # If COMMAND is set, skip SSH validation
    if [ -n "$command" ]; then
        log "Terminal $terminal_num: Custom command is set, skipping SSH validation"
        return 0
    fi

    if [ -z "$ssh_host" ]; then
        error "Terminal $terminal_num: SSH_HOST must be set"
        return 1
    fi

    # Check if SSH_METHOD is set
    if [ -z "$ssh_method" ]; then
        error "Terminal $terminal_num: SSH_METHOD must be set when enabled and COMMAND is empty"
        return 1
    fi

    # Validate SSH_METHOD value
    if [ "$ssh_method" != "password" ] && [ "$ssh_method" != "publickey" ]; then
        error "Terminal $terminal_num: SSH_METHOD must be 'password' or 'publickey', got: $ssh_method"
        return 1
    fi

    # Validate required variables for password method
    if [ "$ssh_method" = "password" ]; then
        if [ -z "$ssh_user" ] || [ -z "$ssh_pass" ]; then
            error "Terminal $terminal_num: SSH_USER and SSH_PASS must be set when SSH_METHOD=password"
            return 1
        fi
    fi

    # Validate required variables for publickey method
    if [ "$ssh_method" = "publickey" ]; then
        if [ -z "$ssh_key_file" ]; then
            error "Terminal $terminal_num: SSH_PRIVATE_KEY_FILE must be set when SSH_METHOD=publickey"
            return 1
        fi
        if [ ! -f "$ssh_key_file" ]; then
            error "Terminal $terminal_num: Private key file not found: $ssh_key_file"
            return 1
        fi
    fi

    log "Terminal $terminal_num: SSH configuration validated successfully"
    return 0
}

# Clone git repository
clone_repository() {
    if [ "$GIT_CLONE" != "true" ]; then
        log "GIT_CLONE is not set to 'true', skipping repository clone"
        return 0
    fi

    log "Cloning git repository..."

    # Create repository directory if it doesn't exist
    mkdir -p "$REPOSITORY_DIR"

    # Check if repository already exists
    if [ -d "$REPOSITORY_DIR/.git" ]; then
        log "Repository already exists, skipping..."
    else
        log "Cloning repository from $GIT_REPO_URL (branch: $GIT_BRANCH)..."

        # Clone the repository with the specified branch
        if git clone --branch "$GIT_BRANCH" --single-branch "$GIT_REPO_URL" "$REPOSITORY_DIR" 2>&1 | sed -u 's/^/[git]\t\t/'; then
            success "Repository cloned successfully"
        else
            error "Failed to clone repository"
            return 1
        fi
    fi

    # Display repository information
    cd "$REPOSITORY_DIR"
    local current_commit
    local current_branch
    current_commit=$(git rev-parse HEAD)
    current_branch=$(git branch --show-current)
    log "Repository info:"
    log "  Branch: $current_branch"
    log "  Commit: $current_commit"
    log "  Location: $REPOSITORY_DIR"

    return 0
}

# Build Antora documentation
build_antora() {
    if [ "$ANTORA_BUILD" != "true" ]; then
        log "ANTORA_BUILD is not set to 'true', skipping Antora build"
        return 0
    fi

    log "Building Antora documentation..."

    # Check if repository directory exists
    if [ ! -d "$REPOSITORY_DIR" ]; then
        warn "Repository directory not found: $REPOSITORY_DIR, skipping Antora build"
        return 0
    fi

    # Check if playbook file exists
    if [ ! -f "$REPOSITORY_DIR/$ANTORA_PLAYBOOK" ]; then
        warn "Antora playbook not found: $REPOSITORY_DIR/$ANTORA_PLAYBOOK, skipping Antora build"
        return 0
    fi

    # Change to repository directory
    cd "$REPOSITORY_DIR"

    # Create output directory if it doesn't exist
    mkdir -p "$STATIC_SITE_DIR"

    log "Running Antora build with playbook: $ANTORA_PLAYBOOK"
    log "Output directory: $STATIC_SITE_DIR"

    # Run Antora build with output to static directory
    if antora --stacktrace --to-dir="$STATIC_SITE_DIR" "$ANTORA_PLAYBOOK" 2>&1 | sed -u 's/^/[antora]\t/'; then
        success "Antora build completed successfully"
    else
        error "Antora build failed"
        return 1
    fi

    # Display build information
    if [ -d "$STATIC_SITE_DIR" ]; then
        local file_count
        file_count=$(find "$STATIC_SITE_DIR" -type f | wc -l)
        log "Antora build info:"
        log "  Output directory: $STATIC_SITE_DIR"
        log "  Files generated: $file_count"
    fi

    return 0
}

# Start Python web app
start_python_app() {
    log "Starting Python web app..."

    if [ ! -d "$PYTHON_APP_DIR" ]; then
        error "Python app directory not found: $PYTHON_APP_DIR"
        return 1
    fi

    # Set layout config path - use direct path if set, otherwise construct from dir and name
    if [ -z "$LAYOUT_CONFIG_PATH" ]; then
        export LAYOUT_CONFIG_PATH="${LAYOUT_CONFIG_DIR}/${LAYOUT_CONFIG_NAME}.yaml"
        log "Constructed LAYOUT_CONFIG_PATH from dir and name: $LAYOUT_CONFIG_PATH"
    else
        log "Using provided LAYOUT_CONFIG_PATH: $LAYOUT_CONFIG_PATH"
    fi

    cd "$PYTHON_APP_DIR"

    # Force unbuffered output and add diagnostic
    log "Starting Flask with prefix logging..."
    (exec waitress-serve --host=0.0.0.0 --port=5000 app:app 2>&1 | sed -u 's/^/[layout]\t/' ) &

    local pid=$!
    echo $pid > "$PID_DIR/python.pid"

    log "Python app started with PID: $pid"
    return 0
}

# Start a specific TTYD terminal
start_ttyd_terminal() {
    local terminal_num=$1
    local enabled
    enabled=$(get_terminal_config "$terminal_num" "ENABLE")

    if [ "$enabled" != "true" ]; then
        log "Terminal $terminal_num: not enabled, skipping"
        return 0
    fi

    # Validate SSH configuration
    validate_terminal_ssh_config "$terminal_num" || {
        error "Terminal $terminal_num: SSH configuration validation failed";
        return 1;
    }

    log "Starting TTYD Terminal $terminal_num..."

    local port
    local command
    local ssh_host
    local ssh_port
    local ssh_user
    local ssh_pass
    local ssh_method
    local ssh_key_file
    local terminal_command
    port=$(get_terminal_config "$terminal_num" "PORT")
    command=$(get_terminal_config "$terminal_num" "COMMAND")
    ssh_host=$(get_terminal_config "$terminal_num" "SSH_HOST")
    ssh_port=$(get_terminal_config "$terminal_num" "SSH_PORT")
    ssh_user=$(get_terminal_config "$terminal_num" "SSH_USER")
    ssh_pass=$(get_terminal_config "$terminal_num" "SSH_PASS")
    ssh_method=$(get_terminal_config "$terminal_num" "SSH_METHOD")
    ssh_key_file=$(get_terminal_config "$terminal_num" "SSH_PRIVATE_KEY_FILE")
    terminal_command=$(get_terminal_config "$terminal_num" "TERMINAL_COMMAND")

    # Set default port if not specified
    if [ -z "$port" ]; then
        port=$((7680 + terminal_num))
        log "Terminal $terminal_num: No port specified, using default: $port"
    fi

    # Set default SSH port if not specified
    if [ -z "$ssh_port" ]; then
        ssh_port=22
    fi

    TTYD_THEME='{ "foreground": "#bbbbbb", "background": "#121212", "cursor": "#bbbbbb", "black": "#121212", "brightBlack": "#555555", "red": "#fa2573", "brightRed": "#f6669d", "green": "#98e123", "brightGreen": "#b1e05f", "yellow": "#dfd460", "brightYellow": "#fff26d", "blue": "#1080d0", "brightBlue": "#00afff", "magenta": "#8700ff", "brightMagenta": "#af87ff", "cyan": "#43a8d0", "brightCyan": "#51ceff", "white": "#bbbbbb", "brightWhite": "#ffffff" }'

    # Determine the command to run
    local command_to_run

    if [ -n "$command" ]; then
        # Use custom COMMAND if set
        command_to_run="$command"
        log "Terminal $terminal_num: Using custom command: $command_to_run"
    else
        # Build SSH command based on method
        if [ "$ssh_method" = "publickey" ]; then
            command_to_run="ssh -o StrictHostKeyChecking=no -i ${ssh_key_file} ${ssh_user}@${ssh_host} -p ${ssh_port}"
            log "Terminal $terminal_num: Using SSH with public key authentication"
        elif [ "$ssh_method" = "password" ]; then
            command_to_run="sshpass -p ${ssh_pass} ssh -o StrictHostKeyChecking=no ${ssh_user}@${ssh_host} -p ${ssh_port}"
            log "Terminal $terminal_num: Using SSH with password authentication"
        else
            error "Terminal $terminal_num: Invalid SSH_METHOD: $ssh_method"
            return 1
        fi

        # Append terminal command if set
        if [ -n "$terminal_command" ]; then
            command_to_run="$command_to_run -t ${terminal_command}"
            log "Terminal $terminal_num: Appending terminal command: ${terminal_command}"
        fi
    fi

    # Start TTYD with the determined command
    log "Terminal $terminal_num: Starting TTYD on port $port with command: $command_to_run"
    # shellcheck disable=SC2086
    (exec ttyd --base-path=/ -W -p "$port" -O -t fontSize=14 -t "theme=${TTYD_THEME}" $command_to_run 2>&1 | sed -u "s/^/[ttyd$terminal_num]\t/" ) &

    local pid=$!
    echo $pid > "$PID_DIR/ttyd$terminal_num.pid"

    log "Terminal $terminal_num: TTYD started with PID: $pid on port: $port"
    return 0
}

# Discover enabled terminals by checking environment variables
get_enabled_terminals() {
    local terminals=""
    for i in $(seq 1 "$TERMINAL_MAX_COUNT"); do  # Check up to TERMINAL_MAX_COUNT terminals
        local enabled
        enabled=$(get_terminal_config "$i" "ENABLE")
        if [ "$enabled" = "true" ]; then
            terminals="$terminals $i"
        fi
    done
    echo "$terminals"
}

# Start all TTYD terminals
start_ttyd_terminals() {
    local enabled_terminals
    enabled_terminals=$(get_enabled_terminals)

    if [ -z "$enabled_terminals" ]; then
        log "No terminals enabled, skipping TTYD startup"
        return 0
    fi

    local terminal_count
    terminal_count=$(echo "$enabled_terminals" | wc -w)
    log "Starting $terminal_count TTYD terminals: $enabled_terminals"

    local failed_count=0
    for i in $enabled_terminals; do
        if ! start_ttyd_terminal "$i"; then
            warn "Failed to start terminal $i"
            failed_count=$((failed_count + 1))
        fi
        sleep 1  # Small delay between terminal starts
    done

    if [ $failed_count -gt 0 ]; then
        warn "$failed_count out of $terminal_count terminals failed to start"
    else
        success "All $terminal_count terminals started successfully"
    fi

    return 0
}

# Generate Caddy configuration for terminals
generate_caddy_terminal_config() {
    local config_file="/app/caddy/includes/entrypoint/00_terminals.caddy"
    local enabled_terminals
    enabled_terminals=$(get_enabled_terminals)

    log "Generating Caddy configuration for terminals..."

    # Create the includes.d directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"

    # Start with header
    cat > "$config_file" << 'EOF'
# Auto-generated terminal routing configuration
# This file is generated by entrypoint.sh based on enabled terminals

EOF

    # Generate routes for each enabled terminal
    for i in $enabled_terminals; do
        local port
        port=$(get_terminal_config "$i" "PORT")
        if [ -z "$port" ]; then
            port=$((7680 + i))
        fi

        cat >> "$config_file" << EOF
# Terminal $i configuration
handle_path /ttyd$i/* {
    reverse_proxy localhost:$port
}

EOF
    done

    log "Generated Caddy terminal configuration: $config_file"
}

# Start Caddy
start_caddy() {
    log "Starting Caddy web server..."

    # Generate terminal configuration before starting Caddy
    generate_caddy_terminal_config

    # Start Caddy with unbuffered sed
    log "Starting Caddy with prefix logging..."
    (exec caddy run --config "$CADDY_CONFIG" --adapter caddyfile 2>&1 | sed -u 's/^/[caddy]\t\t/' ) &

    local pid=$!
    echo $pid > "$PID_DIR/caddy.pid"

    log "Caddy started with PID: $pid"
    return 0
}

wait_for_services() {
    log "Waiting for services to be ready..."

    local max_attempts=30
    local attempt=0
    local enabled_terminals
    enabled_terminals=$(get_enabled_terminals)

    while [ $attempt -lt $max_attempts ]; do
        local all_ready=true

        # Check if Python app is ready (assuming port 5000)
        if ! curl -f -s http://localhost:5000 > /dev/null 2>&1; then
            all_ready=false
        fi

        # Check if terminals are ready
        for i in $enabled_terminals; do
            local port
            port=$(get_terminal_config "$i" "PORT")
            if [ -z "$port" ]; then
                port=$((7680 + i))
            fi
            if ! curl -f -s http://localhost:"$port" > /dev/null 2>&1; then
                all_ready=false
            fi
        done

        # Check if Caddy is serving the static site
        if ! curl -f -s http://localhost:8000 > /dev/null 2>&1; then
            all_ready=false
        fi

        if [ "$all_ready" = true ]; then
            success "All services are ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        log "Waiting for services... ($attempt/$max_attempts)"
        sleep 2
    done

    warn "Services may not be fully ready, but continuing..."
    return 0
}

# Main execution
main() {
    log "Starting multi-service container..."
    log "Container running as user: $(id)"

    local enabled_terminals
    local terminal_count
    enabled_terminals=$(get_enabled_terminals)
    terminal_count=$(echo "$enabled_terminals" | wc -w)
    log "Terminal configuration: $terminal_count terminals enabled ($enabled_terminals)"

    # Create a directory for PID files
    mkdir -p "$PID_DIR"

    # Init container, git clone repo and build antora content

    # Clone repository first
    clone_repository || { error "Failed to clone repository"; exit 1; }

    # Build Antora content
    build_antora || { error "Failed to build Antora documentation"; exit 1; }

    # Start background services
    start_python_app || { error "Failed to start Python app"; exit 1; }
    sleep 2

    start_ttyd_terminals # Don't exit if terminals fail to start, they're optional
    sleep 2

    start_caddy || { error "Failed to start Caddy"; exit 1; }
    sleep 2

    # Wait for services to be ready
    wait_for_services

    success "All services started successfully!"
    log "Container is ready to serve traffic on port 8000"
    log "Routes:"
    log "  / -> Showroom layout"
    for i in $enabled_terminals; do
        log "  /ttyd$i/* -> Terminal $i"
    done
    log "  /content/* -> Static content"

    # Wait for any child process to exit. The livenessProbe is the primary failure detector.
    # The 'trap' will handle cleanup on SIGTERM/SIGINT.
    # If a process dies unexpectedly, 'wait' will exit, and the script will end,
    # causing the container to stop.
    wait -n

    # If we reach here, a service has exited
    error "A service has exited unexpectedly, shutting down."
    cleanup
}

# Run main function
main "$@"
