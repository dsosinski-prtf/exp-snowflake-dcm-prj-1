# CI/CD Pipeline

## Trigger

The pipeline runs on every push to `main`.

## Pipeline Flow

```
Push to main
│
▼
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions Runner (ubuntu-latest)                  │
│                                                         │
│  1. Checkout repository                                 │
│     └── actions/checkout@v4                             │
│                                                         │
│  2. Install Snowflake CLI                               │
│     └── snowflakedb/snowflake-cli-action@v1.5           │
│         cli-version: 3.9.0                              │
│         config: config.toml → ~/.snowflake/config.toml  │
│                                                         │
│  3. snow --version                                      │
│     └── Verify CLI installed correctly                  │
│                                                         │
│  4. cat ~/.snowflake/config.toml                        │
│     └── Debug: print resolved config                    │
│                                                         │
│  5. snow connection test                                │
│     └── Verify auth to Snowflake works                  │
│                                                         │
│  6. snow dcm plan --target PLATFORM                     │
│     └── Preview what DCM will create/change             │
│                                                         │
│  7. snow dcm deploy --target PLATFORM                   │
│     └── Apply DCM changes (roles, warehouses, grants)   │
│                                                         │
│  8. snow sql -f sources/users/platform/*.sql            │
│  9. snow sql -f sources/users/deployers/*.sql           │
│ 10. snow sql -f sources/users/developers/*.sql          │
│ 11. snow sql -f sources/users/ops/*.sql                 │
│     └── Create/update users + role-to-user grants       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Connection Mechanism

```
┌──────────────────┐         ┌──────────────────────────────────┐
│  config.toml     │         │  GitHub Secrets (env vars)       │
│  (in repo)       │         │                                  │
│                  │         │  SNOWFLAKE_CONNECTIONS_           │
│  [connections.   │────────▶│  MYCONNECTION_ACCOUNT            │
│   myconnection]  │ merged  │  MYCONNECTION_USER               │
│                  │         │  MYCONNECTION_AUTHENTICATOR       │
│                  │         │  MYCONNECTION_PRIVATE_KEY_RAW     │
└──────────────────┘         └──────────────────────────────────┘
                                          │
                                          ▼
                               snow connection test
                               snow dcm deploy
                               snow sql -f ...
```

The `config.toml` defines the connection name (`myconnection`). Environment variables with the `SNOWFLAKE_CONNECTIONS_MYCONNECTION_*` prefix inject the actual credentials at runtime.

## Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier (e.g. `WCCVLVP-OZC26701`) |
| `SNOWFLAKE_PLATFORM_DEPLOYER_PRIVATE_KEY` | Full PEM content of `auth-key-pairs/platform-deployer/rsa_key.p8` |

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection default is not configured` | Missing `config.toml` or wrong `default-config-file-path` | Ensure `config.toml` exists in repo root and action references it |
| `JWT token is invalid` | Private key doesn't match public key on user | Re-copy key to GitHub secret, verify public key on Snowflake user |
| `Unable to resolve action` | Wrong action name or version | Use `snowflakedb/snowflake-cli-action@v1.5` |
| User SQL fails | Role/warehouse doesn't exist yet | Ensure DCM deploy runs before user SQL scripts |
