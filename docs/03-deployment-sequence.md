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
  │ Bootstrap │         │ Bootstrap │       │ DCM      │       │ SQL      │
  │ 00_*.sql  │────────▶│ 01_*.sql  │──────▶│ Deploy   │──────▶│ Users    │
  └──────────┘         └──────────┘       └──────────┘       └──────────┘
       │                     │                  │                  │
       ▼                     ▼                  ▼                  ▼
  PLATFORM_             DCM Project        Roles             Users
  DEPLOY_ROLE           objects            Warehouses        Role-to-user
  PLATFORM_                                Grants            grants
  DEPLOY_WH                                DB/Schemas

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
DCM DEFINE templates (Jinja2 rendered with project_name from manifest.yml)
│
├── dcm_projects.sql
│   ├── DEFINE DATABASE <PROJECT>_DCM
│   └── DEFINE SCHEMA <PROJECT>_DCM.PROJECTS
│
├── deploy_roles.sql
│   ├── DEFINE ROLE <PROJECT>_DEV_DEPLOY_ROLE
│   └── DEFINE ROLE <PROJECT>_PROD_DEPLOY_ROLE
│
├── deploy_warehouses.sql
│   ├── DEFINE WAREHOUSE <PROJECT>_DEV_DEPLOY_WH
│   └── DEFINE WAREHOUSE <PROJECT>_PROD_DEPLOY_WH
│
└── grants.sql (per environment)
    ├── ROLE → SYSADMIN hierarchy
    ├── USAGE ON WAREHOUSE → deploy role
    ├── USAGE ON DATABASE/SCHEMA <PROJECT>_DCM → deploy role
    └── CREATE DATABASE/WAREHOUSE/ROLE/USER ON ACCOUNT → deploy role
```

### Step 3: User Deploy (CI/CD)

**Run as:** PLATFORM_DEPLOY_ROLE (automated, every push, after DCM deploy)
**Command:** `snow sql -f sources/users/<category>/<user>.sql --connection myconnection`

Execution order:

```
sources/users/
│
├── 1. platform/                              ← first
│   └── platform_deployer.sql
│       ├── CREATE USER PLATFORM_DEPLOYER (SERVICE)
│       └── GRANT PLATFORM_DEPLOY_ROLE → PLATFORM_DEPLOYER
│
├── 2. deployers/                             ← second (depends on DCM roles)
│   ├── <project>_dev_deployer.sql
│   │   ├── CREATE USER <PROJECT>_DEV_DEPLOYER (SERVICE)
│   │   └── GRANT <PROJECT>_DEV_DEPLOY_ROLE → <PROJECT>_DEV_DEPLOYER
│   └── <project>_prod_deployer.sql
│       ├── CREATE USER <PROJECT>_PROD_DEPLOYER (SERVICE)
│       └── GRANT <PROJECT>_PROD_DEPLOY_ROLE → <PROJECT>_PROD_DEPLOYER
│
├── 3. developers/                            ← third (human accounts)
│   └── <username>.sql
│
└── 4. ops/                                   ← fourth (ops accounts)
    └── <username>.sql
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
    ├─▶ <PROJECT>_DCM ◀── DEFINE                               │
    │   └── PROJECTS                                            │
    │       ├── <PROJECT>_PROJECT_DEV  ──own──▶ <PROJECT>_DEV_DEPLOY_ROLE
    │       └── <PROJECT>_PROJECT_PROD ──own──▶ <PROJECT>_PROD_DEPLOY_ROLE
    │                                                           │
    ├─▶ <PROJECT>_DEV_DEPLOY_ROLE ◀── DEFINE                   │
    │   ├── <PROJECT>_DEV_DEPLOY_WH ◀── DEFINE                 │
    │   └── <PROJECT>_DEV_DEPLOYER (user)                       │
    │                                                           │
    ├─▶ <PROJECT>_PROD_DEPLOY_ROLE ◀── DEFINE                  │
    │   ├── <PROJECT>_PROD_DEPLOY_WH ◀── DEFINE                │
    │   └── <PROJECT>_PROD_DEPLOYER (user)                      │
    │                                                           │
    └─▶ PLATFORM_DEPLOYER (user) ──────────────────────────────┘
```

## What happens on each push to main

```
Push to main
│
├── 1. Checkout repo
├── 2. Install Snowflake CLI
├── 3. Verify connection
├── 4. snow dcm plan --target PLATFORM
├── 5. snow dcm deploy --target PLATFORM
│      └── Creates/updates roles, warehouses, grants, DB/schemas
├── 6. snow sql -f sources/users/platform/*.sql
├── 7. snow sql -f sources/users/deployers/*.sql
├── 8. snow sql -f sources/users/developers/*.sql
└── 9. snow sql -f sources/users/ops/*.sql
       └── Creates/updates users + role-to-user grants
```

## Onboarding a New Feature Project Checklist

1. Set `project_name` in `manifest.yml`
2. Add DCM project block to `bootstrap/01_pre_deploy.sql` and run it
3. Run `snow dcm plan/deploy`
4. Add deployer user files to `sources/users/deployers/`
5. Add ownership block to `bootstrap/02_post_deploy.sql` and run it
6. Generate key pairs, assign public keys, store private keys as GitHub Secrets
