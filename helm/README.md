# Helm Chart

## Overview

The Showroom Helm chart provides a flexible way to deploy interactive documentation environments with optional terminal access. The chart uses examples-based configuration instead of profiles, making it easier to customize deployments for different platforms and use cases.

## Quick Start

### Using Examples (Recommended)

The easiest way to deploy Showroom is using the provided examples. Examples contain complete configurations that you can customize with additional values files.

```bash
# For Podman
helm template ./helm -f ./examples/EXAMPLE/podman.yaml [additional-values.yaml] | podman play kube --replace --publish-all -

# For OpenShift
helm template ./helm -f ./examples/EXAMPLE/openshift.yaml [additional-values.yaml] | oc apply -f -
```

Where:
- **EXAMPLE** - One of the available examples (content-only, content-terminal, content-2-terminals, all-services)
- **TARGET.yaml** - Platform-specific settings (podman.yaml or openshift.yaml)
- **additional-values.yaml** - Your custom overrides (optional)

## Available Examples

| Example | Description | Layout | Use Case |
|---------|-------------|---------|----------|
| [content-only](examples/content-only/) | Single page with documentation only | `content` | Documentation-only deployments, getting started guides |
| [content-terminal](examples/content-terminal/) | Two-column layout with content and terminal | `1-host-1-terminal` | Hands-on labs requiring terminal access |
| [content-2-terminals](examples/content-2-terminals/) | Two-column layout with content and two terminals | `1-host-2-terminals` | Advanced labs requiring multiple terminal sessions |
| [all-services](examples/all-services/) | Complex layout with all services | Custom layout | Demonstration of full capabilities, advanced environments |

For detailed information about each example, see the [examples documentation](examples/README.md).

## Deploying to Podman

### Prerequisites

1. Ensure Podman is installed and running
2. Choose an example that fits your use case

### Deployment

```bash
# Content only
helm template ./helm -f ./examples/content-only/podman.yaml | podman play kube --replace --publish-all -

# Content with terminal
helm template ./helm -f ./examples/content-terminal/podman.yaml | podman play kube --replace --publish-all -

# Content with two terminals
helm template ./helm -f ./examples/content-2-terminals/podman.yaml | podman play kube --replace --publish-all -

# All services (complex example)
helm template ./helm -f ./examples/all-services/podman.yaml | podman play kube --replace --publish-all -
```

### Verification

1. Check the deployment:
    ```bash
    kubectl get all
    ```

2. Add hostname to your hosts file:
    ```bash
    # /etc/hosts
    127.0.0.1  localhost
    ```

3. Access the UI at `http://localhost:8000/showroom`

## Deploying to OpenShift

### Prerequisites

1. Access to an OpenShift cluster
2. `oc` CLI tool configured

### Deployment

1. Choose an example and customize the OpenShift configuration:

    ```bash
    # Replace placeholders with your cluster values
    sed -i 's/{{GUID}}/your-guid/g' ./examples/content-only/openshift.yaml
    sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/content-only/openshift.yaml

    # For examples with terminals, also set the password
    sed -i 's/{{PASSWORD}}/your-password/g' ./examples/content-terminal/openshift.yaml
    ```

2. Deploy the chart:

    ```bash
    # Content only
    helm template ./helm -f ./examples/content-only/openshift.yaml | oc apply -f -

    # Content with terminal
    helm template ./helm -f ./examples/content-terminal/openshift.yaml | oc apply -f -

    # Content with two terminals
    helm template ./helm -f ./examples/content-2-terminals/openshift.yaml | oc apply -f -

    # All services
    helm template ./helm -f ./examples/all-services/openshift.yaml | oc apply -f -
    ```

### Access the Application

Access the UI at the hostname provided `/showroom`, e.g., `https://showroom.apps.cluster-tlthz.tlthz.sandbox1218.opentlc.com/showroom`.

The application uses a self-signed certificate which will require adding a browser exception.

## Custom Configuration

If the provided examples don't meet your needs, you can create custom configuration files. See the [Configuration Reference](#configuration-reference) below.

### Manual Configuration Example

```yaml
# my-values.yaml
---
deployment:
  target: podman
  hostname: localhost:8000
  scheme: http

services:
  content:
    repoUrl: https://github.com/rhpds/showroom_template_default.git
    data:
      lab_name: My Custom Lab

layout_name: content
```

Deploy with custom configuration:
```bash
helm template ./helm -f my-values.yaml | podman play kube --replace --publish-all -
```

## Configuration Reference

### Deployment Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `deployment.target` | string | `podman` | Deployment target (`podman` or `openshift`) |
| `deployment.guid` | string | `xxxxx` | Unique GUID from deploying system |
| `deployment.hostname` | string | `showroom-example.com:8443` | Hostname to access Showroom |
| `deployment.scheme` | string | `https` | URL scheme (`http` or `https`) |
| `deployment.appName` | string | `showroom` | Kubernetes application name |
| `deployment.namespace` | string | `showroom` | Namespace to deploy into |
| `deployment.serviceAccountName` | string | `showroom-service-account` | Service account name |
| `deployment.clusterHTTPSPort` | integer | `8443` | External HTTPS port for redirects |

### Service Configuration

#### Content Service

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `services.content.repoUrl` | string | `https://github.com/rhpds/showroom_template_default.git` | Git repository URL for documentation |
| `services.content.repoRef` | string | `main` | Git branch/tag/commit to use |
| `services.content.antoraPlaybook` | string | `default-site.yml` | Antora playbook file |
| `services.content.data` | object | `null` | Template variables for documentation |

#### Terminal Services

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `services.terminal.enable` | boolean | `false` | Enable terminal service |
| `services.terminal.host` | string | `host.docker.internal` | SSH host to connect to |
| `services.terminal.port` | integer | `22` | SSH port |
| `services.terminal.user` | string | `lab-user` | SSH username |
| `services.terminal.pass` | string | `""` | SSH password (for password auth) |
| `services.terminal.sshMethod` | string | `publickey` | SSH method (`publickey` or `password`) |
| `services.terminal.sshPrivateKeyFile` | string | `files/ssh/id` | SSH private key file path |

Similar configuration is available for `services.terminal2` and `services.terminal3`.

#### OpenSSH Service (for testing)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `services.openssh.enable` | boolean | `false` | Enable OpenSSH server |
| `services.openssh.user` | string | `lab-user` | SSH server username |
| `services.openssh.pass` | string | `""` | SSH server password |
| `services.openssh.sshKeyDir` | string | `files/ssh` | SSH key directory |

#### Hello World Service

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `services.helloworld.enable` | boolean | `false` | Enable hello world service |

### Layout Configuration

You can configure layouts in two ways:

#### 1. Using Layout Names (Recommended)

```yaml
layout_name: content  # or 1-host-1-terminal, 1-host-2-terminals, etc.
```

Available layout names:
- `content` - Single page content only
- `1-host-1-terminal` - Content with one terminal
- `1-host-1-terminal-no-tabs` - Content with one terminal (no tabs)
- `1-host-2-terminals` - Content with two terminals
- `1-host-2-terminals-no-tabs` - Content with two terminals (no tabs)
- `1-host-3-terminals` - Content with three terminals
- `1-host-3-terminals-no-tabs` - Content with three terminals (no tabs)
- `2-hosts-2-terminals` - Content with two terminals for different hosts
- `2-hosts-2-terminals-no-tabs` - Content with two terminals for different hosts (no tabs)
- `3-hosts-3-terminals` - Content with three terminals for different hosts
- `3-hosts-3-terminals-no-tabs` - Content with three terminals for different hosts (no tabs)

#### 2. Using Custom Layout Configuration

```yaml
layout:
  columns:
    left:
      service: content
      width: 40
    right:
      width: 60
      tabs:
      - name: Terminal
        service: terminal
      - name: Documentation
        url: https://docs.example.com
```

For more layout examples, see the [all-services example](examples/all-services/).

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure the specified ports are available
2. **SSH connectivity**: Verify SSH host and credentials for terminal services
3. **Git repository access**: Ensure the content repository URL is accessible
4. **OpenShift routes**: Check that the hostname matches your cluster's route pattern

### Debugging

```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs deployment/showroom-{guid}

# Check services
kubectl get services

# For OpenShift, check routes
oc get routes
```

## Examples

For complete deployment examples and detailed usage instructions, see the [examples documentation](examples/README.md).
