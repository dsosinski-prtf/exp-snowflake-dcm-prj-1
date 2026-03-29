# Snowflake Platform Admin (DCM)

Platform administration repo that manages deployment infrastructure for all Snowflake feature projects using [DCM Projects](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview).

## What this repo manages

- **Deploy roles** per project/environment (e.g. `<PROJECT>_DEV_DEPLOY_ROLE`)
- **Deploy warehouses** per project/environment (e.g. `<PROJECT>_DEV_DEPLOY_WH`)
- **Developer roles** (e.g. `DEVELOPER_ROLE` under SYSADMIN)
- **Grants/permissions** wiring deployers to their projects + role hierarchy
- **Users** — platform, deployer (auto-generated), developer, and ops accounts
- **DCM project objects** — databases, schemas, projects

## Project structure

```
├── bootstrap/                       <- One-time manual setup scripts
├── sources/definitions/             <- DCM DEFINE directives (Jinja2)
├── users/                           <- User management (SQL + Python)
│   ├── platform/
│   ├── deployers/                   <- Auto-generated from manifest.yml
│   ├── developers/
│   └── ops/
├── manifest.yml                     <- DCM config + projects list
├── environment.yml                  <- Conda environment (Snowflake channel)
├── config.toml                      <- CI/CD connection template
└── .github/workflows/deploy.yml     <- CI/CD pipeline
```

## Local deployment

Prerequisites: [conda](https://docs.conda.io/en/latest/) and [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) installed, connection configured in `~/.snowflake/connections.toml`.

```bash
# Full deploy (plan + deploy + users)
./scripts/deploy_local.sh

# Preview changes only
./scripts/deploy_local.sh --plan-only

# Use a specific connection
./scripts/deploy_local.sh --connection platform-deployer
```

The script will prompt for `DEFAULT_USER_PASSWORD` if not set. To skip the prompt:

```bash
export DEFAULT_USER_PASSWORD='<<---->>!'
./scripts/deploy_local.sh
```

## Quick start (CI/CD)

1. Run bootstrap scripts (one-time, see [deployment sequence](docs/03-deployment-sequence.md))
2. Add projects to `manifest.yml`
3. Configure GitHub Secrets (see [authentication](docs/04-authentication.md))
4. Push to `main` — CI/CD handles the rest

## Documentation

| Doc | Description |
|-----|-------------|
| [Overview](docs/01-overview.md) | Architecture, role hierarchy, multi-project support |
| [Project Structure](docs/02-project-structure.md) | File tree, what lives where, key config files |
| [Deployment Sequence](docs/03-deployment-sequence.md) | Full setup from empty account, dependency graph |
| [Authentication](docs/04-authentication.md) | Key pairs, GitHub Secrets, connection config |
| [Adding Users & Projects](docs/05-adding-users-and-projects.md) | How-to guides, enable/disable users |
| [CI/CD Pipeline](docs/06-cicd-pipeline.md) | Pipeline flow, conda setup, troubleshooting |
