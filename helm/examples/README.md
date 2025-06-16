# Examples

This directory contains complete deployment examples that demonstrate how to use profiles with target-specific overrides. Each example follows the pattern:

```bash
helm template ./helm -f ./profiles/PROFILE.yaml -f ./examples/EXAMPLE/TARGET.yaml | DEPLOY_COMMAND
```

Where:
- **PROFILE.yaml** - Base configuration from [profiles/](../profiles/)
- **TARGET.yaml** - Platform-specific overrides (podman.yaml or openshift.yaml)
- **DEPLOY_COMMAND** - `podman play kube` or `oc apply -f -`

## Content Only

Single page layout displaying only documentation content.

* **Example Directory**: [content-only/](content-only/)
* **Profile**: [../profiles/content-only.yaml](../profiles/content-only.yaml)
* **Use Case**: Documentation-only deployments, getting started guides

### Podman

```
helm template ./helm -f ./profiles/content-only.yaml -f ./examples/content-only/podman.yaml | podman play kube --replace --publish-all -
```

```
~ curl -I -k https://showroom-example.com:8443/showroom

HTTP/2 200
content-type: text/html; charset=utf-8
date: Fri, 06 Jun 2025 04:21:41 GMT
server: waitress
content-length: 3529
```

### Openshift

Replace `{{GUID}}` and `{{SANDBOX}}` with your openshift cluster values.

```
sed -i 's/{{GUID}}/6grh2/g' ./examples/content-only/openshift.yaml
sed -i 's/{{SANDBOX}}/sandbox1425/g' ./examples/content-only/openshift.yaml
```

Apply the chart to your openshift cluster
```
helm template ./helm -f ./profiles/content-only.yaml -f ./examples/content-only/openshift.yaml | oc apply -f -
```
Check showroom returns a 200

```
~ curl -I -k https://showroom.apps.cluster-6grh2.6grh2.sandbox1425.opentlc.com/showroom

HTTP/2 200
content-type: text/html; charset=utf-8
date: Fri, 06 Jun 2025 04:29:52 GMT
server: waitress
content-length: 3561
```

## Split Content and Terminal

Two-column layout with documentation content on the left and terminal access on the right.

### Single Terminal

* **Example Directory**: [split-content-terminal/](split-content-terminal/)
* **Profile**: [../profiles/split-content-terminal.yaml](../profiles/split-content-terminal.yaml)
* **Use Case**: Hands-on labs requiring terminal access alongside documentation

#### Podman

The profile connects to an SSH server. For local testing, the example includes an OpenSSH server container.

```bash
helm template ./helm -f ./profiles/split-content-terminal.yaml -f ./examples/split-content-terminal/podman.yaml | podman play kube --replace --publish-all -
```

### Two Stacked Terminals

* **Example Directory**: [split-content-2-terminals/](split-content-2-terminals/)
* **Profile**: [../profiles/split-content-2-terminals.yaml](../profiles/split-content-2-terminals.yaml)
* **Use Case**: Advanced labs requiring multiple terminal sessions

#### Podman

```bash
helm template ./helm -f ./profiles/split-content-2-terminals.yaml -f ./examples/split-content-2-terminals/podman.yaml | podman play kube --replace --publish-all -
```

#### OpenShift

Replace placeholders with your OpenShift cluster values. The terminal will connect to the bastion host with user `lab-user` and the specified password.

**Single Terminal:**

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/split-content-terminal/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/split-content-terminal/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/split-content-terminal/openshift.yaml

# Deploy
helm template ./helm -f ./profiles/split-content-terminal.yaml -f ./examples/split-content-terminal/openshift.yaml | oc apply -f -
```

**Two Stacked Terminals:**

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/split-content-2-terminals/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/split-content-2-terminals/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/split-content-2-terminals/openshift.yaml

# Deploy
helm template ./helm -f ./profiles/split-content-2-terminals.yaml -f ./examples/split-content-2-terminals/openshift.yaml | oc apply -f -
```

## Split Content and TTYD

Two-column layout with documentation content on the left and TTYD terminal on the right.

* **Example Directory**: [split-content-ttyd/](split-content-ttyd/)
* **Profile**: [../profiles/split-content-ttyd.yaml](../profiles/split-content-ttyd.yaml)
* **Use Case**: Labs requiring terminal access with TTYD's enhanced features

### Podman

The profile connects to an SSH server on the local machine. For testing, the example includes an OpenSSH server container.

```bash
helm template ./helm -f ./profiles/split-content-ttyd.yaml -f ./examples/split-content-ttyd/podman.yaml | podman play kube --replace --publish-all -
```

### OpenShift

Replace placeholders with your OpenShift cluster values. TTYD will connect to the bastion host with user `lab-user` and the specified password.

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/split-content-ttyd/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/split-content-ttyd/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/split-content-ttyd/openshift.yaml

# Deploy
helm template ./helm -f ./profiles/split-content-ttyd.yaml -f ./examples/split-content-ttyd/openshift.yaml | oc apply -f -
```

## All Services

Complex layout demonstrating all available services with columns, tabs, and stacks.

* **Example Directory**: [all-services/](all-services/)
* **Profile**: None (uses complete custom configuration)
* **Use Case**: Demonstration of full showroom capabilities, advanced lab environments

### Podman

```bash
helm template ./helm -f ./examples/all-services/podman.yaml | podman play kube --replace --publish-all -
```

### OpenShift

Replace placeholders with your OpenShift cluster values. Multiple services will connect to the bastion host.

```bash
# Replace placeholders
sed -i 's/{{GUID}}/your-guid/g' ./examples/all-services/openshift.yaml
sed -i 's/{{SANDBOX}}/your-sandbox/g' ./examples/all-services/openshift.yaml
sed -i 's/{{PASSWORD}}/your-password/g' ./examples/all-services/openshift.yaml

# Deploy
helm template ./helm -f ./examples/all-services/openshift.yaml | oc apply -f -
```

## Getting Started

For new users, we recommend starting with the **Content Only** example to understand the basic deployment process, then progressing to **Split Content and Terminal** for hands-on labs.

For detailed information about profiles and customization options, see:
- [Profiles Documentation](../profiles/README.md)
- [Helm Chart Documentation](../helm/README.md)
