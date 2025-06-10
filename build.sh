#!/usr/bin/env bash

VERSION=${1:-latest}

podman build -t=localhost/showroom-core:$VERSION .
podman tag localhost/showroom-core:$VERSION quay.io/andrew-jones/showroom-core:$VERSION