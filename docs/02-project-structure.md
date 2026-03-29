# Project Structure

```
exp-snowflake-dcm-prj-1/
│
├── manifest.yml                          ← DCM config: targets, projects list
│
├── bootstrap/                            ← One-time manual scripts (ACCOUNTADMIN)
│   ├── 00_platform_user.sql              │  Role + privileges + warehouse
│   ├── 01_pre_deploy.sql                 │  DCM databases, schemas, projects
│   └── 02_post_deploy.sql                │  DCM project ownership transfers
│
├── sources/
│   ├── definitions/                      ← DCM DEFINE directives (Jinja2 templated)
│   │   ├── dcm_projects.sql              │  <PROJECT>_DCM databases + schemas
│   │   ├── deploy_roles.sql              │  Per-project/env deploy roles
│   │   ├── deploy_warehouses.sql         │  Per-project/env warehouses
│   │   ├── developer_roles.sql           │  DEVELOPER_ROLE under SYSADMIN
│   │   └── grants.sql                    │  All permissions + role hierarchy
│   └── macros/                           ← Jinja2 macros
│
├── users/                                ← User management (outside sources/)
│   ├── platform/                         │  Platform service accounts
│   │   └── platform_deployer.sql         │
│   ├── deployers/                        │  Auto-generated from manifest.yml
│   │   ├── generate_deployer_sql.py      │  Script to generate deployer SQL
│   │   └── .example.sql                  │  Template reference
│   ├── developers/                       │  Human developer accounts
│   │   ├── dsosinski_developer.sql       │
│   │   └── .example.sql                  │  Template reference
│   └── ops/                              │  Operations accounts
│       └── .example.sql                  │  Template reference
│
├── environment.yml                       ← Conda environment (Snowflake channel)
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
┌─────────────────────┬──────────────────────────────┬──────────────────┐
│     Directory        │  What it manages              │  How it runs     │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ bootstrap/           │  Account-level setup          │  Manual (once)   │
│                      │  DCM project objects           │  snow sql -f     │
│                      │  Ownership transfers           │                  │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ sources/definitions/ │  Roles, warehouses, grants    │  CI/CD (DCM)     │
│                      │  DCM databases/schemas         │  snow dcm deploy │
│                      │  Developer roles               │                  │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ users/platform/      │  Platform service accounts    │  CI/CD (SQL)     │
│                      │                                │  snow sql -f     │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ users/deployers/     │  Deployer service accounts    │  CI/CD (Python)  │
│                      │  (auto-generated from          │  generate_       │
│                      │   manifest.yml)                │  deployer_sql.py │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ users/developers/    │  Human developer accounts     │  CI/CD (SQL)     │
│ users/ops/           │  Operations accounts           │  snow sql -f     │
├─────────────────────┼──────────────────────────────┼──────────────────┤
│ auth-key-pairs/      │  RSA keys (gitignored)        │  Manual setup    │
└─────────────────────┴──────────────────────────────┴──────────────────┘
```

Note: `users/` lives outside `sources/` so DCM does not upload user scripts during `snow dcm deploy`.

## Key configuration files

### manifest.yml

Controls DCM targets and the list of feature projects. All `sources/definitions/` templates and `users/deployers/generate_deployer_sql.py` read from this file:

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
    projects:
      FITNESS:
        environments:
          DEV:
            warehouse_size: XSMALL
          PROD:
            warehouse_size: SMALL
            deployer_enabled: true     # set false to disable deployer
```

### environment.yml

Conda environment using the Snowflake channel:

```yaml
name: snowflake
channels:
  - https://repo.anaconda.com/pkgs/snowflake
  - nodefaults
dependencies:
  - python=3.11
  - pyyaml
```

### config.toml

Minimal connection template for CI/CD. Actual credentials come from GitHub Secrets via `SNOWFLAKE_CONNECTIONS_MYCONNECTION_*` environment variables.

```toml
default_connection_name = "myconnection"

[connections.myconnection]
```
