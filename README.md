# showroom-core

showroom-core is a containerized multi-service application that provides an interactive learning environment with customizable layouts, terminal access, and documentation hosting. It combines a layout engine, web server, terminal interface, and Antora documentation building capabilities.

## Overview

The application consists of several integrated components:

- **Layout Engine**: A Python Flask application that renders customizable iframe layouts
- **Caddy Web Server**: Serves static content and proxies requests to other services
- **TTYD Terminal**: Provides web-based terminal access via SSH (supports single and multiple terminals)
- **Antora Documentation**: Automatically builds and serves documentation from Git repositories

## Features

- **Flexible Layout System**: Configure complex layouts with columns, tabs, and stacked content using YAML
- **Terminal Integration**: Web-based terminal access with SSH support (password or public key authentication)
- **Multi-Terminal Support**: Run multiple terminal instances connecting to different hosts or commands
- **Automatic Git Integration**: Clone repositories and build Antora documentation on container startup
- **Multi-Service Architecture**: All services managed by a single entrypoint script

## Quick Start

### Using Podman

#### Just the content

```bash
podman run --rm \
--name showroom \
-p 8000:8000 \
-e LAYOUT_CONFIG_NAME=content \
-e GIT_REPO_URL=https://github.com/rhpds/showroom_template_default.git \
quay.io/andrew-jones/showroom-core:v0.0.16
```

#### Connect to an ssh server

Update the ssh details to be something you can connect to.  The example connects to a local ssh
server running on the same host as podman.


```bash
podman run --rm \
-p 8000:8000 \
-e LAYOUT_CONFIG_NAME=1-host-2-terminals \
-e GIT_REPO_URL=https://github.com/rhpds/showroom_template_default.git \
-e TERMINAL_1_ENABLE=true \
-e TERMINAL_1_SSH_HOST=host.docker.internal \
-e TERMINAL_1_SSH_METHOD=password \
-e TERMINAL_1_SSH_USER={{USERNAME}} \
-e TERMINAL_1_SSH_PASS={{PASSWORD}} \
quay.io/andrew-jones/showroom-core:v0.0.16
```

### Using Podman Compose

```bash
# Start the services
podman compose up --build
```

The application will be available at:
- Main interface: http://localhost:8000
- Terminal: http://localhost:8000/ttyd/
- Static content: http://localhost:8000/content/

## Configuration

### Environment Variables

#### Git Clone Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_CLONE` | `true` | Enable/disable git cloning functionality |
| `GIT_REPO_URL` | `https://github.com/rhpds/showroom_template_default.git` | Repository URL to clone |
| `GIT_BRANCH` | `main` | Git branch to clone |

#### Antora Build Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTORA_BUILD` | `true` | Enable/disable Antora documentation building |
| `ANTORA_PLAYBOOK` | `default-site.yml` | Antora playbook file name |

#### Layout Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LAYOUT_CONFIG_NAME` | `content` | Layout configuration name:<br>`content` - Basic content layout<br>`content-terminal` - Content with terminal<br>`content-2-terminals` - Content with two terminals<br>`content-tabs-terminal` - Tabbed content with terminal<br>`content-tabs-2-terminals` - Tabbed content with two terminals |
| `LAYOUT_CONFIG_DIR` | `/app/layouts` | Directory containing layout configurations |
| `LAYOUT_CONFIG_PATH` | - | Direct path to layout config (overrides name/dir) |

#### Terminal Configuration (Single Terminal)

| Variable | Default | Description |
|----------|---------|-------------|
| `TERMINAL_ENABLE` | `false` | Enable/disable terminal functionality |
| `TERMINAL_SSH_HOST` | - | SSH host to connect to |
| `TERMINAL_SSH_PORT` | `22` | SSH port |
| `TERMINAL_SSH_USER` | `lab-user` | SSH username |
| `TERMINAL_SSH_METHOD` | - | Authentication method: `password` or `publickey` |
| `TERMINAL_SSH_PASS` | - | SSH password (for password auth) |
| `TERMINAL_SSH_PRIVATE_KEY_FILE` | - | Path to private key file (for publickey auth) |
| `TERMINAL_COMMAND` | - | Command to run in terminal session |

## Multi-Terminal Support

The showroom-core container supports running multiple TTYD terminal instances, allowing you to connect to different hosts or run different commands simultaneously. Each terminal runs on its own port and can be configured independently.

### Multi-Terminal Configuration

The multi-terminal functionality is configured using indexed environment variables. Simply enable the terminals you want by setting `TERMINAL_N_ENABLE=true` for each terminal.

#### Per-Terminal Configuration
For each terminal `N` (where N is 1, 2, 3, etc.), you can set:

- `TERMINAL_N_ENABLE`: Enable this terminal (true/false)
- `TERMINAL_N_SSH_HOST`: SSH hostname to connect to
- `TERMINAL_N_SSH_PORT`: SSH port (default: 22)
- `TERMINAL_N_SSH_USER`: SSH username
- `TERMINAL_N_SSH_PASS`: SSH password (for password authentication)
- `TERMINAL_N_SSH_METHOD`: Authentication method ("password" or "publickey")
- `TERMINAL_N_SSH_PRIVATE_KEY_FILE`: Path to private key file (for publickey authentication)
- `TERMINAL_N_PORT`: TTYD port for this terminal (default: 7680 + N)
- `TERMINAL_N_COMMAND`: Custom command to run instead of SSH
- `TERMINAL_N_TERMINAL_COMMAND`: Command to run after SSH connection

### Multi-Terminal Examples

#### Podman Compose Example

```yaml
environment:
  # Terminal 1 - Production server
  - TERMINAL_1_ENABLE=true
  - TERMINAL_1_SSH_HOST=prod-server
  - TERMINAL_1_SSH_PORT=22
  - TERMINAL_1_SSH_USER=admin
  - TERMINAL_1_SSH_METHOD=password
  - TERMINAL_1_SSH_PASS=secret123
  - TERMINAL_1_PORT=7681

  # Terminal 2 - Development server
  - TERMINAL_2_ENABLE=true
  - TERMINAL_2_SSH_HOST=dev-server
  - TERMINAL_2_SSH_PORT=2222
  - TERMINAL_2_SSH_USER=developer
  - TERMINAL_2_SSH_METHOD=publickey
  - TERMINAL_2_SSH_PRIVATE_KEY_FILE=/opt/dev-key
  - TERMINAL_2_PORT=7682

  # Terminal 3 - Local commands
  - TERMINAL_3_ENABLE=true
  - TERMINAL_3_COMMAND=bash
  - TERMINAL_3_PORT=7683
```

#### Kubernetes/OpenShift Example

```yaml
env:
- name: TERMINAL_1_ENABLE
  value: "true"
- name: TERMINAL_1_SSH_HOST
  value: "bastion.example.com"
- name: TERMINAL_1_SSH_USER
  value: "lab-user"
- name: TERMINAL_1_SSH_METHOD
  value: "password"
- name: TERMINAL_1_SSH_PASS
  value: "password123"
- name: TERMINAL_2_ENABLE
  value: "true"
- name: TERMINAL_2_SSH_HOST
  value: "worker.example.com"
- name: TERMINAL_2_SSH_USER
  value: "lab-user"
- name: TERMINAL_2_SSH_METHOD
  value: "password"
- name: TERMINAL_2_SSH_PASS
  value: "password123"
```

### Multi-Terminal URL Routing

Each terminal is accessible via its own URL path:

- Terminal 1: `/ttyd1/`
- Terminal 2: `/ttyd2/`
- Terminal 3: `/ttyd3/`
- etc.

The routing configuration is automatically generated by the entrypoint script and added to Caddy.

### Multi-Terminal Layout Configuration

To use multiple terminals in your layout, reference them by their URL paths:

```yaml
# Example: 3 terminals stacked vertically
layout:
  columns:
    left:
      url: /content/
    right:
      tabs:
      - name: Terminals
        stack:
          top:
            url: /ttyd1/
          middle:
            url: /ttyd2/
          bottom:
            url: /ttyd3/
```

### Multi-Terminal Port Allocation

By default, terminals use ports starting from 7681:
- Terminal 1: 7681
- Terminal 2: 7682
- Terminal 3: 7683
- etc.

You can override the port for any terminal using the `TERMINAL_N_PORT` variable.

### Multi-Terminal Authentication Methods

#### Password Authentication
```bash
TERMINAL_1_SSH_METHOD=password
TERMINAL_1_SSH_USER=username
TERMINAL_1_SSH_PASS=password123
```

#### Public Key Authentication
```bash
TERMINAL_1_SSH_METHOD=publickey
TERMINAL_1_SSH_USER=username
TERMINAL_1_SSH_PRIVATE_KEY_FILE=/path/to/private/key
```

#### Custom Commands
Instead of SSH, you can run any command:
```bash
TERMINAL_1_COMMAND=bash
# or
TERMINAL_1_COMMAND="python3 -i"
# or
TERMINAL_1_COMMAND="kubectl get pods -w"
```

### Multi-Terminal Troubleshooting

#### Check Terminal Status
The entrypoint script logs the status of each terminal during startup. Look for messages like:
```
[entrypoint] Terminal 1: TTYD started with PID: 123 on port: 7681
[entrypoint] Terminal 2: SSH configuration validation failed
```

#### Common Issues

1. **Terminal not starting**: Check that `TERMINAL_N_ENABLE=true` is set
2. **SSH connection fails**: Verify SSH credentials and host accessibility
3. **Port conflicts**: Ensure each terminal uses a unique port
4. **Layout not showing terminal**: Check that the layout YAML references the correct `/ttydN/` path

#### Logs
Each terminal's output is prefixed with `[ttydN]` in the container logs, making it easy to identify which terminal is generating which output.

### Migration from Single Terminal

If you're currently using the single terminal configuration (`TERMINAL_ENABLE=true`), the system will continue to work without any changes needed. However, for new deployments, it's recommended to use the new indexed variable format for clarity.

### Multi-Terminal Limits and Recommendations

- **Recommended maximum**: 5 terminals per container
- **Resource usage**: Each terminal uses approximately 40-64MB of memory
- **Port range**: Use ports 7681-7685 for terminals 1-5
- **Performance**: More terminals = more SSH connections = higher resource usage

## Health and Readiness Checks

The container includes built-in health and readiness check scripts for use with container orchestration platforms like OpenShift and Kubernetes.

### Health Check Script (`/app/health_check.sh`)

The health check script is designed for **liveness probes** and verifies that the core application processes are running:

- **Caddy Web Server**: Checks if the Caddy process is running via PID file
- **Layout Engine**: Verifies the Python Flask application process is active
- **TTYD Terminal**: Only checked if `TERMINAL_ENABLE=true` is set

The script examines PID files in `/tmp/pids/` and uses `kill -0` to verify processes are alive without affecting them.

### Readiness Check Script (`/app/readiness_check.sh`)

The readiness check script is designed for **readiness probes** and verifies that services are responding to HTTP requests:

- **Main Application**: Tests HTTP response from `http://localhost:8000/`
- **Content Endpoint**: Verifies `/content/` endpoint is accessible
- **Terminal Endpoint**: Only checked if `TERMINAL_ENABLE=true`, tests `/ttyd/` endpoint

The script uses `curl` to perform HTTP health checks and ensures the application is ready to serve traffic.

### OpenShift/Kubernetes Deployment Example

Here's how to configure these health checks in an OpenShift DeploymentConfig or Kubernetes Deployment:

```yaml
apiVersion: apps.openshift.io/v1 # Or apps/v1 for Kubernetes
kind: DeploymentConfig # Or Deployment for Kubernetes
metadata:
  name: showroom-core
spec:
  # ... other deployment specs like replicas, selector, etc.
  template:
    # ... pod metadata
    spec:
      containers:
        - name: showroom-core-container
          image: "your-image-registry/showroom-core:latest"
          # ... ports, env vars, volumes, etc.

          # --- Liveness Probe ---
          # "Is the application still alive? If not, restart it."
          livenessProbe:
            exec:
              command:
                - /app/health_check.sh
            # Wait 60 seconds before the first check to allow services to start.
            initialDelaySeconds: 60
            # Check every 30 seconds.
            periodSeconds: 30
            # Give the script 5 seconds to complete.
            timeoutSeconds: 5
            # Restart the container after 3 consecutive failures.
            failureThreshold: 3
            # Consider the check successful after 1 success.
            successThreshold: 1

          # --- Readiness Probe ---
          # "Is the application ready to accept traffic? If not, remove from service."
          readinessProbe:
            exec:
              command:
                - /app/readiness_check.sh
            # Wait 15 seconds before the first check.
            initialDelaySeconds: 15
            # Check every 10 seconds.
            periodSeconds: 10
            # Give the script 5 seconds to complete.
            timeoutSeconds: 5
            # Mark as not ready after 2 consecutive failures.
            failureThreshold: 2
            # Mark as ready after 1 success.
            successThreshold: 1
```

### Manual Health Check Testing

You can manually test the health checks by running the scripts directly in a running container:

```bash
# Test liveness probe
podman exec <container-id> /app/health_check.sh

# Test readiness probe
podman exec <container-id> /app/readiness_check.sh
```

Both scripts return exit code 0 on success and non-zero on failure, with descriptive error messages sent to stderr.

## Git Clone and Antora Integration

The container automatically handles git repository cloning and Antora documentation building on startup.

### Git Clone Process

1. **Disabled**: If `GIT_CLONE` is not "true", skips cloning
2. **First Run**: Clones the specified repository and branch to `/app/repository`
3. **Subsequent Runs**: Skips cloning if repository already exists

### Antora Build Process

1. **Disabled**: If `ANTORA_BUILD` is not "true", skips building
2. **Validation**: Checks for repository and playbook file existence
3. **Build**: Runs Antora with the specified playbook
4. **Output**: Generated site is placed in `/app/caddy/static`

## Examples

The repository includes several example files to help you get started:

- `docker-compose.yml`: Basic Podman Compose setup
- `docker-compose-multi-terminal.yml`: Complete Podman Compose setup with 3 terminals
- `layouts/content-tabs-3-terminals.yaml`: Layout configuration for 3 terminals
- Various layout configurations in the `layouts/` directory
- Helm chart examples in `helm/examples/`

## Architecture

The application uses a multi-service architecture with the following components:

1. **Entrypoint Script**: Manages all services and handles configuration
2. **Caddy Web Server**: Reverse proxy and static file server
3. **Layout Engine**: Python Flask app for rendering layouts
4. **TTYD Terminals**: One or more terminal instances
5. **Git/Antora Integration**: Automatic documentation building

All services are coordinated through the main entrypoint script which handles:
- Environment variable processing
- Service startup and monitoring
- Configuration file generation
- Health monitoring

## Contributing

When contributing to this project, please ensure:

1. All new features are documented in this README
2. Configuration examples are provided
3. Health checks work with new features
4. Multi-terminal functionality is preserved
5. Backward compatibility is maintained

## License

This project is part of the Red Hat Partner Demo System (RHPDS) and follows the associated licensing terms.
