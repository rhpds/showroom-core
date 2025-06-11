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
TERMINAL_ENABLE="${TERMINAL_ENABLE:-false}"
TERMINAL_SSH_HOST="${TERMINAL_SSH_HOST:-}"
TERMINAL_SSH_PORT="${TERMINAL_SSH_PORT:-22}"
TERMINAL_SSH_USER="${TERMINAL_SSH_USER:-lab-user}"
TERMINAL_SSH_PASS="${TERMINAL_SSH_PASS:-}"
TERMINAL_SSH_METHOD="${TERMINAL_SSH_METHOD:-}"
TERMINAL_SSH_PRIVATE_KEY_FILE="${TERMINAL_SSH_PRIVATE_KEY_FILE:-}"
TERMINAL_COMMAND="${TERMINAL_COMMAND:-}"

# Process tracking - Replaced with PID files
# PIDS=()
# SERVICES=()

# Cleanup function
cleanup() {
    log "Shutting down services..."
    
    if [ ! -d "$PID_DIR" ]; then
        warn "PID directory not found, cannot perform cleanup."
        exit 0
    fi

    # Gracefully terminate all processes found in the PID directory
    for pid_file in $PID_DIR/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local service_name=$(basename "$pid_file" .pid)
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
    for pid_file in $PID_DIR/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local service_name=$(basename "$pid_file" .pid)
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

# Validate SSH configuration for TTYD
validate_ssh_config() {    
    # If TTYD_COMMAND is set, skip SSH validation
    if [ -n "$TTYD_COMMAND" ]; then
        log "TTYD_COMMAND is set, skipping SSH validation"
        return 0
    fi

    if [ -z "$TERMINAL_SSH_HOST" ]; then
        error "TERMINAL_SSH_HOST must be set"
        return 1
    fi
    
    # Check if TERMINAL_SSH_METHOD is set
    if [ -z "$TERMINAL_SSH_METHOD" ]; then
        error "TERMINAL_SSH_METHOD must be set when TERMINAL_ENABLE=true and TTYD_COMMAND is empty"
        return 1
    fi
    
    # Validate TERMINAL_SSH_METHOD value
    if [ "$TERMINAL_SSH_METHOD" != "password" ] && [ "$TERMINAL_SSH_METHOD" != "publickey" ]; then
        error "TERMINAL_SSH_METHOD must be set to 'password' or 'publickey', got: $TERMINAL_SSH_METHOD"
        return 1
    fi
    
    # Validate required variables for password method
    if [ "$TERMINAL_SSH_METHOD" = "password" ]; then
        if [ -z "$TERMINAL_SSH_USER" ] || [ -z "$TERMINAL_SSH_PASS" ]; then
            error "TERMINAL_SSH_USER and TERMINAL_SSH_PASS must be set when TERMINAL_SSH_METHOD=password"
            return 1
        fi
    fi
    
    # Validate required variables for publickey method
    if [ "$TERMINAL_SSH_METHOD" = "publickey" ]; then
        if [ -z "$TERMINAL_SSH_PRIVATE_KEY_FILE" ]; then
            error "TERMINAL_SSH_PRIVATE_KEY_FILE must be set when TERMINAL_SSH_METHOD=publickey"
            return 1
        fi
        if [ ! -f "$TERMINAL_SSH_PRIVATE_KEY_FILE" ]; then
            error "Private key file not found: $TERMINAL_SSH_PRIVATE_KEY_FILE"
            return 1
        fi
    fi
    
    log "SSH configuration validated successfully"
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
    local current_commit=$(git rev-parse HEAD)
    local current_branch=$(git branch --show-current)
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
        local file_count=$(find "$STATIC_SITE_DIR" -type f | wc -l)
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

# Start TTYD
start_ttyd() {
    if [ "$TERMINAL_ENABLE" != "true" ]; then
        log "TERMINAL_ENABLE is not set to 'true', skipping starting TTYD"
        return 0
    fi

    # Validate SSH configuration
    validate_ssh_config || { error "SSH configuration validation failed"; return 1; }

    log "Starting TTYD..."
    TTYD_THEME='{ "foreground": "#bbbbbb", "background": "#121212", "cursor": "#bbbbbb", "black": "#121212", "brightBlack": "#555555", "red": "#fa2573", "brightRed": "#f6669d", "green": "#98e123", "brightGreen": "#b1e05f", "yellow": "#dfd460", "brightYellow": "#fff26d", "blue": "#1080d0", "brightBlue": "#00afff", "magenta": "#8700ff", "brightMagenta": "#af87ff", "cyan": "#43a8d0", "brightCyan": "#51ceff", "white": "#bbbbbb", "brightWhite": "#ffffff" }'
    
    # Determine the command to run
    local command_to_run
    
    if [ -n "$TTYD_COMMAND" ]; then
        # Use custom TTYD_COMMAND if set
        command_to_run="$TTYD_COMMAND"
        log "Using custom TTYD_COMMAND: $command_to_run"
    else
        # Build SSH command based on method
        if [ "$TERMINAL_SSH_METHOD" = "publickey" ]; then
            command_to_run="ssh -o StrictHostKeyChecking=no -i ${TERMINAL_SSH_PRIVATE_KEY_FILE} ${TERMINAL_SSH_USER}@${TERMINAL_SSH_HOST} -p ${TERMINAL_SSH_PORT}"
            log "Using SSH with public key authentication"
        elif [ "$TERMINAL_SSH_METHOD" = "password" ]; then
            command_to_run="sshpass -p ${TERMINAL_SSH_PASS} ssh -o StrictHostKeyChecking=no ${TERMINAL_SSH_USER}@${TERMINAL_SSH_HOST} -p ${TERMINAL_SSH_PORT}"
            log "Using SSH with password authentication"
        else
            error "Invalid TERMINAL_SSH_METHOD: $TERMINAL_SSH_METHOD"
            return 1
        fi
        
        # Append terminal command if set
        if [ -n "$TERMINAL_COMMAND" ]; then
            command_to_run="$command_to_run -t ${TERMINAL_COMMAND}"
            log "Appending terminal command: ${TERMINAL_COMMAND}"
        fi
    fi
    
    # Start TTYD with the determined command
    log "Starting TTYD with command: $command_to_run"
    (exec ttyd --base-path=/ -W -p 7681 -O -t fontSize=14 -t "theme=${TTYD_THEME}" $command_to_run 2>&1 | sed -u 's/^/[ttyd]\t\t/' ) &
    
    local pid=$!
    echo $pid > "$PID_DIR/ttyd.pid"
    
    log "TTYD started with PID: $pid"
    return 0
}

# Start Caddy
start_caddy() {
    log "Starting Caddy web server..."
    
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
    
    while [ $attempt -lt $max_attempts ]; do
        local all_ready=true
        
        # Check if Python app is ready (assuming port 5000)
        if ! curl -f -s http://localhost:5000 > /dev/null 2>&1; then
            all_ready=false
        fi
        
        # Check if TTYD is running
        if ! curl -f -s http://localhost:7681 > /dev/null 2>&1; then
            all_ready=false
        fi
        
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
    
    start_ttyd # Don't exit if TTYD fails to start, it's optional
    sleep 2
    
    start_caddy || { error "Failed to start Caddy"; exit 1; }
    sleep 2
    
    # Wait for services to be ready
    wait_for_services
    
    success "All services started successfully!"
    log "Container is ready to serve traffic on port 8000"
    log "Routes:"
    log "  / -> Showroom layout"
    log "  /ttyd/* -> Terminal"
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
