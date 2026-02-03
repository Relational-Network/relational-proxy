# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Relational Network
#
# Relational Proxy - Caddy Reverse Proxy for SGX Enclave
# ========================================================
#
# This Dockerfile creates a minimal Caddy container with the
# production Caddyfile baked in. Environment variables are
# used for configuration at runtime.
#
# Build:
#   docker build -t relational-proxy .
#
# Run:
#   docker run -d --name caddy \
#     --network host \
#     -e PILOT_DOMAIN=staging.example.com \
#     -e DASHBOARD_ORIGIN=https://dashboard.example.com \
#     -v caddy_data:/data \
#     -v caddy_config:/config \
#     relational-proxy

FROM caddy:2-alpine

# Add labels for container registry
LABEL org.opencontainers.image.source="https://github.com/Relational-Network/relational-proxy"
LABEL org.opencontainers.image.description="Caddy reverse proxy for SGX enclave attestation platform"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"

# Copy Caddyfile into the container
COPY Caddyfile /etc/caddy/Caddyfile

# Caddy stores certificates in /data and config in /config
# These should be mounted as volumes for persistence
VOLUME ["/data", "/config"]

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Default command (can be overridden)
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
