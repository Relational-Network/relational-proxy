# Relational Proxy

<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Copyright (C) 2026 Relational Network
-->

Caddy reverse proxy configuration for Relational Network.

**License:** AGPL-3.0-or-later

## Related Repositories

| Repository | License | Description |
|------------|---------|-------------|
| `relational-sdk` | AGPL-3.0-or-later | SGX enclave server |
| `attestation-verification-service` | AGPL-3.0-or-later | AVS - verifies RA-TLS, issues JWTs |
| `relational-proxy` | AGPL-3.0-or-later | **This repo** - Caddy reverse proxy config |
| `XXX-dashboard` | Proprietary | Next.js browser client (private) |

## Architecture

```
                         Internet
                             │
                      [Your Domain]
              iob-staging.duckdns.org (staging)
                             │
                     ┌───────┴───────┐
                     │    Caddy      │
                     │  (TLS + Proxy)│  ← Let's Encrypt certificates
                     └───────┬───────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    /v1/attest          /v1/data/*          /.well-known/*
    /avs/*              /v1/attestation/*        
         │              /health                  │
         │              /docs                    │
         │                   │                   │
    ┌────┴────┐        ┌─────┴─────┐       ┌────┴────┐
    │   AVS   │        │  Enclave  │       │   AVS   │
    │ :9100   │        │  :8080    │       │ :9100   │
    └─────────┘        └───────────┘       └─────────┘
```

## Prerequisites

1. **Azure DCsv3 VM** with SGX support
2. **Domain name** pointing to VM's public IP
3. **Docker** and **Docker Compose** installed
4. **Gramine enclave signing key** at `~/.config/gramine/enclave-key.pem`

## Staging Deployment

**Live URL:** https://iob-staging.duckdns.org

**Docker Image:** `ghcr.io/relational-network/relational-proxy:staging-latest`

The staging deployment runs as a Docker container on the Azure DCsv3 VM (`iob-staging`).

### Verify Deployment

```bash
# Check health via Caddy
curl https://iob-staging.duckdns.org/health

# Check AVS JWKS
curl https://iob-staging.duckdns.org/.well-known/jwks.json

# Test attestation
curl -X POST https://iob-staging.duckdns.org/v1/attest \
  -H 'Content-Type: application/json' \
  -d '{"enclave_url":"https://127.0.0.1:8080","user_id":"test","role":"user"}'
```

## CI/CD

This repo uses GitHub Actions for CI/CD:

- **CI** (`.github/workflows/ci.yml`): Runs on push/PR
  - Validates Caddyfile syntax (`caddy validate`)
  - Checks formatting (`caddy fmt --diff`)
  - Lints Dockerfile with hadolint

- **CD** (`.github/workflows/cd-staging.yml`): Runs on push to `main`
  - Builds Docker image
  - Pushes to GHCR (`ghcr.io/relational-network/relational-proxy:staging-latest`)
  - Deploys to staging VM via SSH

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `STAGING_HOST` | Staging VM IP (e.g., `20.86.174.127`) |
| `STAGING_USER` | SSH user (e.g., `azureuser`) |
| `STAGING_SSH_KEY` | SSH private key for deployment |
| `GITHUB_TOKEN` | Automatic, for GHCR push |

## Docker

The Dockerfile is based on `caddy:2-alpine` with the production Caddyfile baked in.

### Build Locally

```bash
docker build -t relational-proxy .
```

### Run Locally

```bash
docker run -d --name caddy \
  --network host \
  -e PILOT_DOMAIN=localhost \
  -e DASHBOARD_ORIGIN=http://localhost:3000 \
  -v caddy_data:/data \
  -v caddy_config:/config \
  relational-proxy
```

## Quick Start (Local Development)

### 1. Clone and Configure

```bash
git clone https://github.com/Relational-Network/relational-proxy.git
cd relational-proxy

# Create environment file
cp .env.example .env
nano .env  # Edit with your domain and measurements
```

### 2. Run with Local Caddyfile

```bash
# Using native Caddy (self-signed TLS on :8443)
caddy run --config Caddyfile.local

# Or using Docker Compose
docker compose -f docker-compose.local.yml up -d
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PILOT_DOMAIN` | Domain for Let's Encrypt | Yes |
| `AVS_EXPECTED_MRSIGNER` | Enclave signer measurement | Yes |
| `AVS_EXPECTED_MRENCLAVE` | Enclave code measurement | No* |
| `AVS_ALLOW_DEBUG_ENCLAVE` | Allow debug enclaves (0/1) | No |
| `SECRETS_DIR` | Path to secrets directory | No |
| `ENCLAVE_KEY_PATH` | Path to Gramine signing key | No |

*MRENCLAVE changes with every code change. For pilot, MRSIGNER alone may suffice.

### Caddy Configuration

The `Caddyfile` routes requests:

| Path | Backend | Description |
|------|---------|-------------|
| `/v1/attest*` | AVS :9100 | Attestation requests |
| `/.well-known/*` | AVS :9100 | JWKS for token verification |
| `/v1/data/*` | Enclave :8080 | Data upload/query |
| `/v1/attestation/*` | Enclave :8080 | Public key endpoint |
| `/health` | Enclave :8080 | Health check |
| `/docs*` | Enclave :8080 | Swagger UI |

## Vercel Dashboard Configuration

Set these environment variables in your Vercel project:

```
BACKEND_URL=https://...
AVS_URL=https://...
NODE_ENV=production
```

## Local Development

For local testing without a domain:

```bash
# Start services with local Caddyfile
docker compose -f docker-compose.local.yml up -d

# Or run Caddy directly
caddy run --config Caddyfile.local
```

## Troubleshooting

### Certificate Issues

```bash
# Check Caddy logs
docker compose logs caddy

# Force certificate renewal
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Enclave Not Starting

```bash
# Check SGX devices
ls -la /dev/sgx/

# Check enclave logs
docker compose logs enclave

# Verify measurements match
docker compose exec enclave gramine-sgx-sigstruct-view /app/relational-sdk.sig
```

### AVS Connection Issues

```bash
# Check AVS is running
docker compose exec avs curl http://localhost:9100/health

# Check network connectivity
docker compose exec caddy wget -O- http://avs:9100/health
```

## Security Checklist

Before going live:

- [ ] Set `AVS_ALLOW_DEBUG_ENCLAVE=0`
- [ ] Set `AVS_ALLOW_OUTDATED_TCB=0`
- [ ] Configure both `MRSIGNER` and `MRENCLAVE`
- [ ] Restrict secrets directory permissions: `chmod 700 secrets`
- [ ] Enable firewall (only ports 80, 443)
- [ ] Set up log rotation for `/var/log/caddy`

## Updating

Updates are automatic via CI/CD on push to `main`. For manual updates:

```bash
# SSH to staging VM
ssh azureuser@20.86.174.127

# Pull latest image and restart
docker pull ghcr.io/relational-network/relational-proxy:staging-latest
sudo systemctl restart caddy-docker
```

## Related Documentation

- [STAGING-DEPLOYMENT.md](../STAGING-DEPLOYMENT.md) - Full staging deployment guide
- [AGENTS.md](../AGENTS.md) - Architecture and development context

## License

AGPL-3.0-or-later. See [LICENSE](LICENSE) for details.
