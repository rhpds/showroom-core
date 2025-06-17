# Examples

This directory contains complete deployment examples that demonstrate different Showroom configurations. Each example provides a ready-to-use configuration for specific use cases and can be customized with additional values files.

## Usage Pattern

```bash
# For Podman
helm template ./helm -f ./examples/EXAMPLE/podman.yaml [additional-values.yaml] | podman play kube --replace --publish-all -

# For OpenShift
helm template ./helm -f ./examples/EXAMPLE/openshift.yaml [additional-values.yaml] | oc apply -f -
```

Where:
- **EXAMPLE** - One of the available examples (content-only, content-terminal, content-2-terminals, all-services)
- **TARGET.yaml** - Platform-specific configuration (podman.yaml or openshift.yaml)
- **additional-values.yaml** - Your custom overrides (optional)

## Available Examples

### Content Only

Single page layout displaying only documentation content.

* **Example Directory**: [content-only/](content-only/)
* **Layout**: `content`
* **Use Case**: Documentation-only deployments, getting started guides, simple content presentation

#### Podman

```bash
helm template ./helm -f ./examples/content-only/podman.yaml | podman play kube --replace --publish-all -
```

Access at: `http://localhost:8000/showroom`

#### OpenShift

Replace `{{GUID}}` and `{{SANDBOX}}` with your OpenShift cluster values:

```bash
sed -i 's/{{GUID}}/your-guid/g' ./examples/content-only/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/content-only/openshift.yaml

helm template ./helm -f ./examples/content-only/openshift.yaml | oc apply -f -
```

### Content with Terminal

Two-column layout with documentation content on the left and terminal access on the right.

* **Example Directory**: [content-terminal/](content-terminal/)
* **Layout**: `1-host-1-terminal`
* **Use Case**: Hands-on labs requiring terminal access alongside documentation

#### Podman

The example includes an OpenSSH server container for testing terminal connectivity.

```bash
helm template ./helm -f ./examples/content-terminal/podman.yaml | podman play kube --replace --publish-all -
```

Access at: `http://localhost:8000/showroom`

#### OpenShift

Replace placeholders with your OpenShift cluster values. The terminal will connect to the bastion host with user `lab-user` and the specified password.

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/content-terminal/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/content-terminal/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/content-terminal/openshift.yaml

# Deploy
helm template ./helm -f ./examples/content-terminal/openshift.yaml | oc apply -f -
```

### Content with Two Terminals

Two-column layout with documentation content on the left and two stacked terminals on the right.

* **Example Directory**: [content-2-terminals/](content-2-terminals/)
* **Layout**: `1-host-2-terminals`
* **Use Case**: Advanced labs requiring multiple terminal sessions

#### Podman

The example includes an OpenSSH server container for testing terminal connectivity.

```bash
helm template ./helm -f ./examples/content-2-terminals/podman.yaml | podman play kube --replace --publish-all -
```

Access at: `http://localhost:8000/showroom`

#### OpenShift

Replace placeholders with your OpenShift cluster values. Both terminals will connect to the bastion host.

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/content-2-terminals/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/content-2-terminals/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/content-2-terminals/openshift.yaml

# Deploy
helm template ./helm -f ./examples/content-2-terminals/openshift.yaml | oc apply -f -
```

### All Services

Complex layout demonstrating all available services with columns, tabs, and stacks.

* **Example Directory**: [all-services/](all-services/)
* **Layout**: Custom layout configuration
* **Use Case**: Demonstration of full Showroom capabilities, advanced lab environments

This example showcases:
- Content service with documentation
- Hello world service
- Multiple terminal services (terminal, terminal2, terminal3)
- OpenSSH server for testing
- Complex layout with tabs and stacked components

#### Podman

```bash
helm template ./helm -f ./examples/all-services/podman.yaml | podman play kube --replace --publish-all -
```

Access at: `http://localhost:8000/showroom`

#### OpenShift

Replace placeholders with your OpenShift cluster values. Multiple services will connect to the bastion host.

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/all-services/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/all-services/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/all-services/openshift.yaml

# Deploy
helm template ./helm -f ./examples/all-services/openshift.yaml | oc apply -f -
```

## Example Configuration Details

### Content Only Example

```yaml
deployment:
  target: podman
  scheme: http
  hostname: localhost:8000

services:
  content:
    repoUrl: https://github.com/rhpds/showroom_template_default.git
    data:
      lab_name: All new dynamic showroom layouts!

layout_name: content
```

### Content Terminal Example

```yaml
deployment:
  target: podman
  scheme: http
  hostname: localhost:8000

services:
  content:
    repoUrl: https://github.com/rhpds/showroom_template_default.git
    data:
      lab_name: All new dynamic showroom layouts!!!!

  terminal:
    enable: true
    host: localhost
    port: 2222
    user: lab-user
    sshMethod: publickey

  openssh:
    enable: true
    user: lab-user
    sshKeyDir: files/ssh

layout_name: 1-host-1-terminal
```

### All Services Example

The all-services example demonstrates a complex custom layout:

```yaml
layout:
  columns:
    left:
      service: content
      width: 40
    right:
      width: 60
      tabs:
      - name: Terminals
        stack:
          top:
            service: terminal
            height: 30
          middle:
            service: terminal2
            height: 30
          bottom:
            service: terminal3
            height: 40
      - name: Documentation
        url: https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/about/welcome-index
      - name: Stack
        stack:
          top:
            service: helloworld
            height: 40
          bottom:
            url: https://en.wikipedia.org/wiki/Red_Hat
            height: 60
```

## Customization

### Adding Custom Values

You can override any configuration by providing additional values files:

```bash
# Create custom values
cat > my-custom.yaml << EOF
services:
  content:
    data:
      lab_name: My Custom Lab Name
      custom_var: Custom Value
EOF

# Deploy with custom values
helm template ./helm -f ./examples/content-only/podman.yaml -f my-custom.yaml | podman play kube --replace --publish-all -
```

### Available Layout Names

Instead of custom layout configuration, you can use predefined layout names:

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

## Getting Started

For new users, we recommend starting with the **Content Only** example to understand the basic deployment process, then progressing to **Content Terminal** for hands-on labs.

1. **Start Simple**: Begin with `content-only` to verify basic functionality
2. **Add Interactivity**: Move to `content-terminal` for labs requiring terminal access
3. **Scale Up**: Use `content-2-terminals` for more complex scenarios
4. **Explore Features**: Try `all-services` to see all capabilities

For detailed configuration options and troubleshooting, see the [main Helm chart documentation](../README.md).
