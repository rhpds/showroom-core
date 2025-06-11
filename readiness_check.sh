#!/bin/bash

# A simple readiness check script for the readinessProbe.
# It checks if the main services are responding to requests.

# Caddy acts as the reverse proxy, so we check its endpoints.
# The main endpoint at port 8000 proxies to all other services.
# A successful response from Caddy indicates the backend services it relies on are also ready.

# Check Caddy main page (proxies to layout python app)
if ! curl --fail --silent --head http://localhost:8000/ > /dev/null; then
    echo "Readiness check failed: Showroom on port 8000 is not responding." >&2
    exit 1
fi
echo "Showroom on port 8000 is ready."

if ! curl --fail --silent --head http://localhost:8000/content/ > /dev/null; then
    echo "Readiness check failed: Content endpoint '/content/' is not responding." >&2
    exit 1
fi
echo "Content on /content/ is ready."

# If TTYD is enabled, check its endpoint through Caddy
if [ "$TERMINAL_ENABLE" = "true" ]; then
    # We expect a redirect for /ttyd/, so a 3xx response is success here.
    # The --location-trusted flag follows the redirect.
    # TODO use --head here, there appears to be a bug in ttyd HEAD calls,
    # where it returns a body and golangs http.Client logs an error;
    # "Unsolicited response received on idle HTTP channel starting with \"
    if ! curl --fail --silent http://localhost:8000/ttyd/ > /dev/null; then
         echo "Readiness check failed: TTYD endpoint '/ttyd/' is not responding." >&2
         exit 1
    fi
    echo "TTYD on /ttyd/ is ready."
fi

echo "Readiness check passed."
exit 0