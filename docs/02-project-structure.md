# Project Structure

```
exp-snowflake-dcm-prj-1/
│
├── manifest.yml                          ← DCM config: targets, templating vars
│
├── bootstrap/                            ← One-time manual scripts (ACCOUNTADMIN)
│   ├── 00_platform_user.sql              │  Role + privileges + warehouse
│   ├── 01_pre_deploy.sql                 │  DCM databases, schemas, projects
│   └── 02_post_deploy.sql                │  DCM project ownership transfers
│
├── sources/
│   ├── definitions/                      ← DCM DEFINE directives (Jinja2 templated)
│   │   ├── dcm_projects.sql              │  <PROJECT>_DCM databases + schemas
│   │   ├── deploy_roles.sql              │  Per-environment deploy roles
│   │   ├── deploy_warehouses.sql         │  Per-environment warehouses
│   │   └── grants.sql                    │  All permissions + role hierarchy
│   │
│   ├── users/                            ← User SQL scripts (one file per user)
│   │   ├── platform/                     │  Platform service accounts
│   │   │   └── platform_deployer.sql     │
│   │   ├── deployers/                    │  Per-project deployer service accounts
│   │   │   └── .example.sql              │  Template for new deployers
│   │   ├── developers/                   │  Human developer accounts
│   │   │   └── .example.sql              │  Template for new developers
│   │   └── ops/                          │  Operations accounts
│   │       └── .example.sql              │  Template for new ops users
│   │
│   └── macros/                           ← Jinja2 macros (empty)
│
├── config.toml                           ← CI/CD connection template
├── auth-key-pairs/                       ← RSA key pairs (gitignored)
│
├── .github/workflows/
│   └── deploy.yml                        ← CI/CD pipeline
│
└── docs/                                 ← Documentation (this folder)
```

## What lives where

```
┌─────────────────────┬─────────────────────────────┬──────────────────┐
│     Directory        │  What it manages             │  How it runs     │
├─────────────────────┼─────────────────────────────┼──────────────────┤
│ bootstrap/           │  Account-level setup         │  Manual (once)   │
│                      │  DCM project objects          │  snow sql -f     │
│                      │  Ownership transfers          │                  │
├─────────────────────┼─────────────────────────────┼──────────────────┤
│ sources/definitions/ │  Roles, warehouses, grants   │  CI/CD (DCM)     │
│                      │  DCM databases/schemas        │  snow dcm deploy │
├─────────────────────┼─────────────────────────────┼──────────────────┤
│ sources/users/       │  All Snowflake users          │  CI/CD (SQL)     │
│                      │  Role-to-user grants          │  snow sql -f     │
├─────────────────────┼─────────────────────────────┼──────────────────┤
│ auth-key-pairs/      │  RSA keys (gitignored)       │  Manual setup    │
└─────────────────────┴─────────────────────────────┴──────────────────┘
```

## Key configuration files

### manifest.yml

Controls DCM targets and Jinja2 template variables. Set `project_name` to the feature project being onboarded:

```yaml
manifest_version: 2
type: DCM_PROJECT

targets:
  PLATFORM:
    account_identifier: "<account>"
    project_name: "PLATFORM_DCM.PROJECTS.PLATFORM_PROJECT"
    project_owner: "PLATFORM_DEPLOY_ROLE"

templating:
  defaults:
    project_name: <PROJECT>          # ← set per feature project
    environments:                    # ← loop target for Jinja2
      DEV:
        warehouse_size: XSMALL
      PROD:
        warehouse_size: SMALL
```

### config.toml

Minimal connection template for CI/CD. Actual credentials come from GitHub Secrets via `SNOWFLAKE_CONNECTIONS_MYCONNECTION_*` environment variables.

```toml
default_connection_name = "myconnection"

[connections.myconnection]
```
