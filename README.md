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
                   pilot.project.com
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

## Quick Start

### 1. Clone and Configure

```bash
# On your Azure VM
git clone https://github.com/your-org/relational-proxy.git
cd relational-proxy

# Create environment file
cp .env.example .env
nano .env  # Edit with your domain and measurements
```

### 2. Generate Secrets

```bash
mkdir -p secrets

# Generate AVS signing key
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out secrets/avs-signing-key.pem

# Generate Gramine enclave key (if not exists)
mkdir -p ~/.config/gramine
gramine-sgx-gen-private-key ~/.config/gramine/enclave-key.pem
```

### 3. Get Enclave Measurements

Build the enclave and extract measurements:

```bash
cd ../../relational-sdk
make SGX=1 RA_TYPE=dcap
gramine-sgx-sigstruct-view relational-sdk.sig | grep -E "mr_signer|mr_enclave"

# Update .env with the measurements
cd ../deploy/caddy
nano .env
```

### 4. Start Services

```bash
# Pull latest images
docker compose pull

# Start all services
docker compose up -d

# Check logs
docker compose logs -f
```

### 5. Verify Deployment

```bash
# Check Caddy obtained certificates
curl https://pilot.project.com.com/health

# Check AVS
curl https://pilot.project.com/.well-known/jwks.json

# Test attestation
curl -X POST https://pilot.project.com.com/v1/attest \
  -H 'Content-Type: application/json' \
  -d '{"enclave_url":"https://localhost:8080","user_id":"test","role":"user"}'
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

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# If enclave code changed, update measurements in .env
```

## License

See repository root for license information.
