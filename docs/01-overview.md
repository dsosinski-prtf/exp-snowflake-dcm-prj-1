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
│  │  - Grants/permissions  (DCM)                              │  │
│  │  - Users               (SQL scripts)                      │  │
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

## Two Deployment Mechanisms

```
┌──────────────────────────────┐    ┌──────────────────────────────┐
│         DCM (Automated)      │    │     SQL Scripts (Automated)  │
│                              │    │                              │
│  Roles, Warehouses, Grants   │    │  Users + Role-to-User Grants │
│                              │    │                              │
│  Managed via DEFINE          │    │  One .sql file per user      │
│  directives + Jinja2         │    │  in sources/users/           │
│  templates                   │    │                              │
│                              │    │                              │
│  snow dcm plan/deploy        │    │  snow sql -f <file>          │
└──────────────────────────────┘    └──────────────────────────────┘
         │                                    │
         └────────────┬───────────────────────┘
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
├── <PROJECT>_DEV_DEPLOY_ROLE             ← feature deployer (dev)
├── <PROJECT>_STAGING_DEPLOY_ROLE         ← feature deployer (staging, if configured)
└── <PROJECT>_PROD_DEPLOY_ROLE            ← feature deployer (prod)
```

## Per-Project Resources

Each feature project gets a full set of resources per environment, driven by `manifest.yml`:

| Resource | Naming Convention | Example (PROJECT=ANALYTICS, ENV=DEV) |
|----------|-------------------|--------------------------------------|
| Deploy role | `<PROJECT>_<ENV>_DEPLOY_ROLE` | `ANALYTICS_DEV_DEPLOY_ROLE` |
| Deploy warehouse | `<PROJECT>_<ENV>_DEPLOY_WH` | `ANALYTICS_DEV_DEPLOY_WH` |
| Deployer user | `<PROJECT>_<ENV>_DEPLOYER` | `ANALYTICS_DEV_DEPLOYER` |
| DCM database | `<PROJECT>_DCM` | `ANALYTICS_DCM` |
| DCM project | `<PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_<ENV>` | `ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_DEV` |

Environments are defined in `manifest.yml` and automatically picked up by all Jinja2 templates.
