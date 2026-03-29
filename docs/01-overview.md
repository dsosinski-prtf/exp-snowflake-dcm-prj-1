# Platform Overview

## What This Repo Does

This is the **platform administration repository** for Snowflake. It manages the foundational infrastructure that all feature projects depend on: roles, warehouses, users, and permissions.

```
┌─────────────────────────────────────────────────────────────────┐
│                      SNOWFLAKE ACCOUNT                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              THIS REPO (Platform Admin)                   │  │
│  │                                                           │  │
│  │  Manages:                                                 │  │
│  │  - Deploy roles        (DCM)                              │  │
│  │  - Deploy warehouses   (DCM)                              │  │
│  │  - Developer roles     (DCM)                              │  │
│  │  - Grants/permissions  (DCM)                              │  │
│  │  - Users               (SQL + Python scripts)             │  │
│  │  - DCM projects        (Bootstrap)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│          │                          │                            │
│          ▼                          ▼                            │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  Feature Repo A   │    │  Feature Repo B   │                  │
│  │                   │    │                   │                   │
│  │  Uses:            │    │  Uses:            │                   │
│  │  - Deploy roles   │    │  - Deploy roles   │                   │
│  │  - Warehouses     │    │  - Warehouses     │                   │
│  │  - Service users  │    │  - Service users  │                   │
│  └──────────────────┘    └──────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

## Three Deployment Mechanisms

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│   DCM (Automated)   │  │  Python (Automated)  │  │  SQL (Automated)    │
│                     │  │                      │  │                     │
│  Roles, Warehouses  │  │  Deployer users      │  │  Platform, dev,     │
│  Grants, DB/Schemas │  │  (auto-generated     │  │  ops users          │
│  Developer roles    │  │  from manifest.yml)  │  │  (one .sql per user │
│                     │  │                      │  │  in users/)         │
│  snow dcm deploy    │  │  generate_deployer   │  │  snow sql -f        │
│                     │  │  _sql.py             │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  ▼
                        GitHub Actions CI/CD
                        (push to main)
```

## Role Hierarchy

```
ACCOUNTADMIN
├── PLATFORM_DEPLOY_ROLE                  ← platform admin (this repo)
│
SYSADMIN
├── DEVELOPER_ROLE                        ← human developers
├── <PROJECT>_DEV_DEPLOY_ROLE             ← feature deployer (dev)
├── <PROJECT>_STAGING_DEPLOY_ROLE         ← feature deployer (staging, if configured)
└── <PROJECT>_PROD_DEPLOY_ROLE            ← feature deployer (prod)
```

## Multi-Project Support

All projects are defined in a single `manifest.yml`:

```yaml
projects:
  FITNESS:
    environments:
      DEV: { warehouse_size: XSMALL }
      PROD: { warehouse_size: SMALL }
  ANALYTICS:
    environments:
      DEV: { warehouse_size: XSMALL }
      PROD: { warehouse_size: MEDIUM }
```

Each project gets a full set of resources per environment:

| Resource | Naming Convention | Example (PROJECT=ANALYTICS, ENV=DEV) |
|----------|-------------------|--------------------------------------|
| Deploy role | `<PROJECT>_<ENV>_DEPLOY_ROLE` | `ANALYTICS_DEV_DEPLOY_ROLE` |
| Deploy warehouse | `<PROJECT>_<ENV>_DEPLOY_WH` | `ANALYTICS_DEV_DEPLOY_WH` |
| Deployer user | `<PROJECT>_<ENV>_DEPLOYER` | `ANALYTICS_DEV_DEPLOYER` |
| DCM database | `<PROJECT>_DCM` | `ANALYTICS_DCM` |
| DCM project | `<PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_<ENV>` | `ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_DEV` |

## User Management

| Category | Location | How created | Enable/Disable |
|----------|----------|-------------|----------------|
| Platform | `users/platform/*.sql` | SQL files | Managed by ACCOUNTADMIN |
| Deployers | Auto-generated | Python script from `manifest.yml` | `deployer_enabled` in manifest |
| Developers | `users/developers/*.sql` | SQL files (one per user) | `ALTER USER SET DISABLED` in file |
| Ops | `users/ops/*.sql` | SQL files (one per user) | `ALTER USER SET DISABLED` in file |
