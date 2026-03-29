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
│  2. Set up Conda environment                            │
│     └── conda-incubator/setup-miniconda@v3              │
│         environment: environment.yml (Snowflake channel)│
│                                                         │
│  3. Install Snowflake CLI                               │
│     └── snowflakedb/snowflake-cli-action@v2.0           │
│         cli-version: 3.16.0                             │
│         config: config.toml → ~/.snowflake/config.toml  │
│                                                         │
│  4. Check versions                                      │
│     └── snow --version, python --version, conda list    │
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
│  8. snow sql -f users/platform/*.sql                    │
│     └── Platform service accounts                       │
│                                                         │
│  9. python users/deployers/generate_deployer_sql.py     │
│     └── Auto-generate + execute deployer SQL from       │
│         manifest.yml (with enable/disable support)      │
│                                                         │
│ 10. snow sql -f users/developers/*.sql                  │
│     └── Developer accounts (password from secret,       │
│         with enable/disable per user)                   │
│                                                         │
│ 11. snow sql -f users/ops/*.sql                         │
│     └── Ops accounts (with enable/disable per user)     │
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
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_PLATFORM_DEPLOYER_PRIVATE_KEY` | Full PEM content of `auth-key-pairs/platform-deployer/rsa_key.p8` |
| `DEFAULT_USER_PASSWORD` | Temporary password for new developer users (must change on first login) |

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection default is not configured` | Missing `config.toml` or wrong `default-config-file-path` | Ensure `config.toml` exists in repo root and action references it |
| `JWT token is invalid` | Private key doesn't match public key on user | Re-copy key to GitHub secret, verify public key on Snowflake user |
| `Unable to resolve action` | Wrong action name or version | Use `snowflakedb/snowflake-cli-action@v2.0` |
| `Insufficient privileges to operate on user` | Trying to ALTER a user owned by ACCOUNTADMIN | Platform deployer is owned by ACCOUNTADMIN — can only be altered by ACCOUNTADMIN |
| User SQL fails on role/warehouse | Role/warehouse doesn't exist yet | Ensure DCM deploy runs before user SQL scripts |
| `ModuleNotFoundError: yaml` | Conda environment not activated | Ensure step uses `shell: bash -l {0}` |
