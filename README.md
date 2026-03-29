# Snowflake Platform Admin (DCM)

Platform administration repo that manages deployment infrastructure for all Snowflake feature projects using [DCM Projects](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview).

## What this repo manages

- **Deploy roles** per project/environment (e.g. `<PROJECT>_DEV_DEPLOY_ROLE`)
- **Deploy warehouses** per project/environment (e.g. `<PROJECT>_DEV_DEPLOY_WH`)
- **Grants/permissions** wiring deployers to their projects + role hierarchy
- **Users** — platform, deployer, developer, and ops accounts
- **DCM project objects** — databases, schemas, projects

## Project structure

```
├── bootstrap/                       <- One-time manual setup scripts
├── sources/
│   ├── definitions/                 <- DCM DEFINE directives (Jinja2)
│   └── users/                       <- One .sql file per user
│       ├── platform/
│       ├── deployers/
│       ├── developers/
│       └── ops/
├── manifest.yml                     <- DCM config (targets, templating)
├── config.toml                      <- CI/CD connection template
└── .github/workflows/deploy.yml     <- CI/CD pipeline
```

## Quick start

1. Run bootstrap scripts (one-time, see [deployment sequence](docs/03-deployment-sequence.md))
2. Set `project_name` in `manifest.yml` for the feature project to onboard
3. Configure GitHub Secrets (see [authentication](docs/04-authentication.md))
4. Push to `main` — CI/CD handles the rest

## Documentation

| Doc | Description |
|-----|-------------|
| [Overview](docs/01-overview.md) | Architecture, role hierarchy, environments |
| [Project Structure](docs/02-project-structure.md) | File tree, what lives where, key config files |
| [Deployment Sequence](docs/03-deployment-sequence.md) | Full setup from empty account, dependency graph |
| [Authentication](docs/04-authentication.md) | Key pairs, GitHub Secrets, connection config |
| [Adding Users & Projects](docs/05-adding-users-and-projects.md) | How-to guides for common operations |
| [CI/CD Pipeline](docs/06-cicd-pipeline.md) | Pipeline flow, troubleshooting |
