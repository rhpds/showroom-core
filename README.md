# showroom-core

showroom-core is a containerized multi-service application that provides an interactive learning environment with customizable layouts, terminal access, and documentation hosting. It combines a layout engine, web server, terminal interface, and Antora documentation building capabilities.

## Overview

The application consists of several integrated components:

- **Layout Engine**: A Python Flask application that renders customizable iframe layouts
- **Caddy Web Server**: Serves static content and proxies requests to other services
- **TTYD Terminal**: Provides web-based terminal access via SSH
- **Antora Documentation**: Automatically builds and serves documentation from Git repositories

## Features

- **Flexible Layout System**: Configure complex layouts with columns, tabs, and stacked content using YAML
- **Terminal Integration**: Web-based terminal access with SSH support (password or public key authentication)
- **Automatic Git Integration**: Clone repositories and build Antora documentation on container startup
- **Multi-Service Architecture**: All services managed by a single entrypoint script

## Quick Start

### Using Docker Compose

```bash
# Start the services
docker-compose up --build
```

The application will be available at:
- Main interface: http://localhost:8000
- Terminal: http://localhost:8000/ttyd/
- Static content: http://localhost:8000/content/

### Using Docker

```bash
# Build the image
docker build -t showroom-core .

# Run with default settings
docker run -p 8000:8000 showroom-core

# Run with custom configuration
docker run -p 8000:8000 \
  -e GIT_REPO_URL=https://github.com/your-org/your-repo.git \
  -e LAYOUT_CONFIG_NAME=content-terminal \
  showroom-core
```

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

#### Terminal Configuration

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