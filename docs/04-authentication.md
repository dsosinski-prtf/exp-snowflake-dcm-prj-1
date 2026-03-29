# Authentication

All service accounts use RSA key-pair authentication (no passwords). Human accounts (developers, ops) may use key pairs or other authenticators.

## Authentication Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  Private Key  │     │  Snowflake   │     │  Public Key      │
│  (secret)     │────▶│  JWT Auth    │◀────│  (on user)       │
│               │     │              │     │                  │
│  Stored in:   │     │  Validates   │     │  Stored in:      │
│  - Local file │     │  token       │     │  - ALTER USER    │
│  - GH Secret  │     │  signature   │     │    SET RSA_      │
└──────────────┘     └──────────────┘     │    PUBLIC_KEY    │
                                           └──────────────────┘
```

## Users & Keys

| User | Type | Private Key Location | Public Key Set Via |
|------|------|---------------------|--------------------|
| `DSOSINSKI` (ACCOUNTADMIN) | PERSON | `auth-key-pairs/accountadmin/rsa_key.p8` | ALTER USER (manual) |
| `PLATFORM_DEPLOYER` | SERVICE | `auth-key-pairs/platform-deployer/rsa_key.p8` + GitHub Secret (this repo) | ALTER USER (manual) |
| `<PROJECT>_<ENV>_DEPLOYER` | SERVICE | `auth-key-pairs/<env>-deployer/rsa_key.p8` + GitHub Secret (feature repo) | ALTER USER (manual) |

## Key Pair Generation

```bash
# Generate private key (unencrypted PKCS8)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Extract public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

## Assigning Public Key to User

```sql
-- Strip the -----BEGIN PUBLIC KEY----- and -----END PUBLIC KEY----- lines
-- Paste only the base64 content
ALTER USER <username> SET RSA_PUBLIC_KEY='MIIBIjANBgkq...';
```

## GitHub Secrets for CI/CD

### This repo (platform admin)

| Secret | Purpose |
|--------|---------|
| `SNOWFLAKE_ACCOUNT` | Account identifier |
| `SNOWFLAKE_PLATFORM_DEPLOYER_PRIVATE_KEY` | Full PEM content of platform-deployer/rsa_key.p8 |

### Feature repos

| Secret | Purpose |
|--------|---------|
| `SNOWFLAKE_ACCOUNT` | Account identifier |
| `SNOWFLAKE_<ENV>_PRIVATE_KEY` | Full PEM content of deployer private key per environment |

## Local Connection Config

Connections are configured in `~/.snowflake/connections.toml`:

```toml
[platform-deployer]
account = "<account>"
user = "PLATFORM_DEPLOYER"
role = "PLATFORM_DEPLOY_ROLE"
warehouse = "PLATFORM_DEPLOY_WH"
authenticator = "SNOWFLAKE_JWT"
private_key_file = "/path/to/auth-key-pairs/platform-deployer/rsa_key.p8"
```

## CI/CD Connection Config

In CI/CD, credentials are injected via environment variables that override the `config.toml` template:

```
SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT          ← from secret
SNOWFLAKE_CONNECTIONS_MYCONNECTION_USER              ← hardcoded
SNOWFLAKE_CONNECTIONS_MYCONNECTION_AUTHENTICATOR     ← SNOWFLAKE_JWT
SNOWFLAKE_CONNECTIONS_MYCONNECTION_PRIVATE_KEY_RAW   ← from secret (full PEM)
```
