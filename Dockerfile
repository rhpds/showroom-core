FROM registry.access.redhat.com/ubi10:10.0

USER root

ARG ANTORA_VERSION=3.1
ARG CADDY_VERSION=2.10.0
ARG TTYD_VERSION=1.7.7
ARG SSHPASS_VERSION=1.09-9
ARG TINI_VERSION=v0.19.0

# Install necessary tools
RUN dnf -y update && dnf -y upgrade && \
    dnf -y install 'dnf-command(copr)' && \
    dnf -y copr enable @caddy/caddy && \
    dnf -y --quiet install \
    wget python3 python3-pip caddy-${CADDY_VERSION} git nodejs procps \
    openssh-clients && \
    dnf install -y https://mirror.stream.centos.org/10-stream/AppStream/x86_64/os/Packages/sshpass-${SSHPASS_VERSION}.el10.x86_64.rpm && \
    dnf -y clean all --enablerepo='*' && \
    rm -rf /var/cache/yum /root/.cache

# Install tini
RUN wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64" && \
    chmod +x /usr/local/bin/tini

###################################################
# Git
RUN mkdir -p /app/repository

###################################################
# Antora
RUN npm i -g @antora/cli@${ANTORA_VERSION} @antora/site-generator@${ANTORA_VERSION} && \
    npm cache clean --force

###################################################
# ttyd
# TODO check sha256 sum
RUN wget -q https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64 \
    -O /usr/bin/ttyd && chmod +x /usr/bin/ttyd
###################################################

###################################################
# Caddy
COPY ./caddy/Caddyfile /app/caddy/Caddyfile
COPY ./caddy/includes/core /app/caddy/includes/core
# Make directory for entrypoint script to write caddy configs
RUN mkdir -p /app/caddy/includes/entrypoint
# Make directory for extra configs, entrypoint.sh will create configs here
# and users can mount files to include
RUN mkdir -p /app/caddy/includes.d

RUN mkdir -p /app/caddy/static
COPY ./caddy/static/index.html /app/caddy/static/index.html

###################################################
# Layout
# Copy requirements file and install dependencies
RUN mkdir -p /app/layout-engine
COPY ./layout-engine /app/layout-engine
RUN pip install --no-cache-dir -r /app/layout-engine/requirements.txt && \
    pip install --no-cache-dir waitress
# Copy the layout configurations
RUN mkdir -p /app/layouts
COPY ./layouts /app/layouts

COPY entrypoint.sh /app/entrypoint.sh
COPY health_check.sh /app/health_check.sh
COPY readiness_check.sh /app/readiness_check.sh

RUN chmod +x /app/entrypoint.sh && \
    chmod +x /app/health_check.sh && \
    chmod +x /app/readiness_check.sh

# Setting the 'HOME' env var, caddy will create files in .config and .local
# and ttyd in .ssh. OCP will set HOME to / by default otherwise.
ENV HOME=/app
WORKDIR /app
ENTRYPOINT ["/usr/local/bin/tini", "-v", "-g", "--", "/app/entrypoint.sh"]
