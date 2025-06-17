#!/bin/bash

# A simple readiness check script for the readinessProbe.
# It checks if the main services are responding to requests.

# Caddy acts as the reverse proxy, so we check its endpoints.
# The main endpoint at port 8000 proxies to all other services.
# A successful response from Caddy indicates the backend services it relies on are also ready.

# Configuration
TERMINAL_MAX_COUNT="${TERMINAL_MAX_COUNT:-5}"

# Get terminal configuration for a specific terminal number
get_terminal_config() {
    local terminal_num=$1
    local config_name=$2

    # Use eval to get the value of the dynamically named variable
    local var_name="TERMINAL_${terminal_num}_${config_name}"
    eval echo "\$$var_name"
}

# Discover enabled terminals by checking environment variables
get_enabled_terminals() {
    local terminals=""
    for i in $(seq 1 $TERMINAL_MAX_COUNT); do
        local enabled=$(get_terminal_config $i "ENABLE")
        if [ "$enabled" = "true" ]; then
            terminals="$terminals $i"
        fi
    done
    echo "$terminals"
}

# Check all enabled TTYD terminal endpoints
check_ttyd_terminals() {
    local enabled_terminals=$(get_enabled_terminals)

    if [ -z "$enabled_terminals" ]; then
        echo "No terminals enabled, skipping TTYD endpoint checks."
        return 0
    fi

    local failed_count=0
    local total_count=$(echo $enabled_terminals | wc -w)

    for i in $enabled_terminals; do
        # We expect a redirect for /ttydN/, so a 3xx response is success here.
        # TODO use --head here, there appears to be a bug in ttyd HEAD calls,
        # where it returns a body and golangs http.Client logs an error;
        # "Unsolicited response received on idle HTTP channel starting with \"
        if ! curl --fail --silent http://localhost:8000/ttyd$i/ > /dev/null; then
            echo "Readiness check failed: TTYD Terminal $i endpoint '/ttyd$i/' is not responding." >&2
            failed_count=$((failed_count + 1))
        else
            echo "TTYD Terminal $i on /ttyd$i/ is ready."
        fi
    done

    if [ $failed_count -gt 0 ]; then
        echo "Readiness check failed: $failed_count out of $total_count TTYD terminal endpoints are not responding." >&2
        return 1
    fi

    echo "All $total_count TTYD terminal endpoints are ready."
    return 0
}

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

# Check for enabled TTYD terminal endpoints
check_ttyd_terminals || exit 1

echo "Readiness check passed."
exit 0
