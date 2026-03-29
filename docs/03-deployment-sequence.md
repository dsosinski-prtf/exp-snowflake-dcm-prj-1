# Deployment Sequence

Starting from an empty Snowflake account with only ACCOUNTADMIN.

## Visual Overview

```
  MANUAL (one-time)                        CI/CD (every push to main)
  ─────────────────                        ────────────────────────────

  Step 0                Step 1             Step 2              Step 3
  ACCOUNTADMIN          PLATFORM_          PLATFORM_           PLATFORM_
                        DEPLOY_ROLE        DEPLOY_ROLE         DEPLOY_ROLE
  ┌──────────┐         ┌──────────┐       ┌──────────┐       ┌──────────┐
  │ Bootstrap │         │ Bootstrap │       │ DCM      │       │ Users    │
  │ 00_*.sql  │────────▶│ 01_*.sql  │──────▶│ Deploy   │──────▶│ (SQL +   │
  └──────────┘         └──────────┘       └──────────┘       │ Python)  │
       │                     │                  │             └──────────┘
       ▼                     ▼                  ▼                  │
  PLATFORM_             DCM Project        Roles                  ▼
  DEPLOY_ROLE           objects            Warehouses         Users
  PLATFORM_                                Grants            Enable/Disable
  DEPLOY_WH                                DB/Schemas        Role grants
                                           Dev roles
                                                             ┌──────────┐
                                           Step 4            │ Bootstrap │
                                           PLATFORM_    ◀────│ 02_*.sql  │
                                           DEPLOY_ROLE       └──────────┘
                                                                  │
                                                                  ▼
                                                             DCM project
                                                             ownership
                                                             transfers
```

## Detailed Steps

In examples below, `<PROJECT>` represents any feature project name (e.g. ANALYTICS, INGEST, FITNESS).

### Step 0: Platform Role & Warehouse

**Run as:** ACCOUNTADMIN (manual, one-time)
**Script:** `snow sql -f bootstrap/00_platform_user.sql --connection <accountadmin>`

```
ACCOUNTADMIN
│
├── Creates: PLATFORM_DEPLOY_ROLE
│   ├── GRANT CREATE DATABASE  (WITH GRANT OPTION)
│   ├── GRANT CREATE WAREHOUSE (WITH GRANT OPTION)
│   ├── GRANT CREATE ROLE      (WITH GRANT OPTION)
│   ├── GRANT CREATE USER      (WITH GRANT OPTION)
│   └── GRANT MANAGE GRANTS
│
├── Creates: PLATFORM_DEPLOY_WH (XSMALL)
│   └── GRANT USAGE → PLATFORM_DEPLOY_ROLE
│
└── Role hierarchy: PLATFORM_DEPLOY_ROLE → ACCOUNTADMIN
```

**After script:** Generate key pair, assign public key to PLATFORM_DEPLOYER user, configure CLI connection.

### Step 1: DCM Project Objects (per feature project)

**Run as:** PLATFORM_DEPLOY_ROLE (manual, once per new project)
**Script:** `snow sql -f bootstrap/01_pre_deploy.sql --connection platform-deployer`

```
PLATFORM_DEPLOY_ROLE
│
├── Creates: PLATFORM_DCM (database)
│   └── PROJECTS (schema)
│       └── PLATFORM_PROJECT (DCM project)
│
└── Creates: <PROJECT>_DCM (database)       ← one block per feature project
    └── PROJECTS (schema)
        ├── <PROJECT>_PROJECT_DEV  (DCM project)
        └── <PROJECT>_PROJECT_PROD (DCM project)
```

### Step 2: DCM Deploy (CI/CD)

**Run as:** PLATFORM_DEPLOY_ROLE (automated, every push)
**Command:** `snow dcm plan/deploy --target PLATFORM --connection myconnection`

```
DCM DEFINE templates (Jinja2 — loops over all projects in manifest.yml)
│
├── dcm_projects.sql (per project)
│   ├── DEFINE DATABASE <PROJECT>_DCM
│   └── DEFINE SCHEMA <PROJECT>_DCM.PROJECTS
│
├── deploy_roles.sql (per project × environment)
│   ├── DEFINE ROLE <PROJECT>_DEV_DEPLOY_ROLE
│   └── DEFINE ROLE <PROJECT>_PROD_DEPLOY_ROLE
│
├── deploy_warehouses.sql (per project × environment)
│   ├── DEFINE WAREHOUSE <PROJECT>_DEV_DEPLOY_WH
│   └── DEFINE WAREHOUSE <PROJECT>_PROD_DEPLOY_WH
│
├── developer_roles.sql
│   └── DEFINE ROLE DEVELOPER_ROLE → SYSADMIN
│
└── grants.sql (per project × environment)
    ├── ROLE → SYSADMIN hierarchy
    ├── USAGE ON WAREHOUSE → deploy role
    ├── USAGE ON DATABASE/SCHEMA <PROJECT>_DCM → deploy role
    └── CREATE DATABASE/WAREHOUSE/ROLE/USER ON ACCOUNT → deploy role
```

### Step 3: User Deploy (CI/CD)

**Run as:** PLATFORM_DEPLOY_ROLE (automated, every push, after DCM deploy)

Execution order:

```
users/
│
├── 1. platform/*.sql                         ← SQL files
│   └── platform_deployer.sql
│       ├── CREATE USER PLATFORM_DEPLOYER (SERVICE)
│       └── GRANT PLATFORM_DEPLOY_ROLE → PLATFORM_DEPLOYER
│       (no ALTER — owned by ACCOUNTADMIN)
│
├── 2. deployers/generate_deployer_sql.py     ← Python script
│   Reads manifest.yml, generates SQL for ALL deployer users:
│   ├── CREATE USER <PROJECT>_<ENV>_DEPLOYER (SERVICE)
│   ├── GRANT <PROJECT>_<ENV>_DEPLOY_ROLE → <PROJECT>_<ENV>_DEPLOYER
│   └── ALTER USER <PROJECT>_<ENV>_DEPLOYER SET DISABLED = TRUE/FALSE
│       (controlled by deployer_enabled in manifest.yml)
│
├── 3. developers/*.sql                       ← SQL files (one per user)
│   └── <username>.sql
│       ├── CREATE USER (PERSON, MUST_CHANGE_PASSWORD)
│       ├── PASSWORD from GitHub secret DEFAULT_USER_PASSWORD
│       ├── GRANT role → user
│       └── ALTER USER SET DISABLED = TRUE/FALSE
│
└── 4. ops/*.sql                              ← SQL files (one per user)
    └── <username>.sql
        ├── CREATE USER
        ├── GRANT role → user
        └── ALTER USER SET DISABLED = TRUE/FALSE
```

### Step 4: DCM Project Ownership (per feature project)

**Run as:** PLATFORM_DEPLOY_ROLE (manual, once per new project)
**Script:** `snow sql -f bootstrap/02_post_deploy.sql --connection platform-deployer`

```
PLATFORM_DEPLOY_ROLE
│
├── GRANT OWNERSHIP ON DCM PROJECT <PROJECT>_PROJECT_DEV
│   └── → <PROJECT>_DEV_DEPLOY_ROLE
│
└── GRANT OWNERSHIP ON DCM PROJECT <PROJECT>_PROJECT_PROD
    └── → <PROJECT>_PROD_DEPLOY_ROLE
```

**After script:** Generate key pairs for deployer users, assign public keys, store private keys as GitHub Secrets in the feature repo.

## Object Dependency Graph

```
ACCOUNTADMIN (exists)
│
└─▶ PLATFORM_DEPLOY_ROLE ──────────────────────────────────────┐
    │                                                           │
    ├─▶ PLATFORM_DEPLOY_WH                                     │
    │                                                           │
    ├─▶ PLATFORM_DCM.PROJECTS.PLATFORM_PROJECT                 │
    │                                                           │
    ├─▶ DEVELOPER_ROLE ◀── DEFINE ──▶ SYSADMIN                 │
    │                                                           │
    ├─▶ <PROJECT>_DCM ◀── DEFINE                               │
    │   └── PROJECTS                                            │
    │       ├── <PROJECT>_PROJECT_DEV  ──own──▶ <PROJECT>_DEV_DEPLOY_ROLE
    │       └── <PROJECT>_PROJECT_PROD ──own──▶ <PROJECT>_PROD_DEPLOY_ROLE
    │                                                           │
    ├─▶ <PROJECT>_DEV_DEPLOY_ROLE ◀── DEFINE                   │
    │   ├── <PROJECT>_DEV_DEPLOY_WH ◀── DEFINE                 │
    │   └── <PROJECT>_DEV_DEPLOYER (user, can be disabled)      │
    │                                                           │
    ├─▶ <PROJECT>_PROD_DEPLOY_ROLE ◀── DEFINE                  │
    │   ├── <PROJECT>_PROD_DEPLOY_WH ◀── DEFINE                │
    │   └── <PROJECT>_PROD_DEPLOYER (user, can be disabled)     │
    │                                                           │
    └─▶ PLATFORM_DEPLOYER (user, owned by ACCOUNTADMIN) ───────┘
```

## What happens on each push to main

```
Push to main
│
├──  1. Checkout repo
├──  2. Set up Conda environment (environment.yml)
├──  3. Install Snowflake CLI
├──  4. Verify connection
├──  5. snow dcm plan --target PLATFORM
├──  6. snow dcm deploy --target PLATFORM
│       └── Creates/updates roles, warehouses, grants, DB/schemas
├──  7. snow sql -f users/platform/*.sql
├──  8. python users/deployers/generate_deployer_sql.py
│       └── Auto-generates + runs deployer SQL from manifest.yml
├──  9. snow sql -f users/developers/*.sql (with password substitution)
└── 10. snow sql -f users/ops/*.sql
        └── Creates/updates users, grants roles, sets enabled/disabled
```

## Onboarding a New Feature Project Checklist

1. Add project to `projects` in `manifest.yml`
2. Add DCM project block to `bootstrap/01_pre_deploy.sql` and run it
3. Push to `main` (DCM deploy + deployer users auto-created)
4. Add ownership block to `bootstrap/02_post_deploy.sql` and run it
5. Generate key pairs, assign public keys, store private keys as GitHub Secrets
