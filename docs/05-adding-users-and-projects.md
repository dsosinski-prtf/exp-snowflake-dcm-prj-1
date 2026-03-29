# Adding Users & Projects

## Adding a New User

Create a single `.sql` file in the appropriate category under `sources/users/`. Each category has a `.example.sql` template to copy from.

```
sources/users/
├── platform/        ← platform service accounts
├── deployers/       ← feature project deployer service accounts
├── developers/      ← human developer accounts
└── ops/             ← operations/admin accounts
```

### Example: Add a deployer

Copy `sources/users/deployers/.example.sql` to `sources/users/deployers/<project>_<env>_deployer.sql`:

```sql
USE ROLE PLATFORM_DEPLOY_ROLE;

CREATE USER IF NOT EXISTS ANALYTICS_DEV_DEPLOYER
    DEFAULT_ROLE      = 'ANALYTICS_DEV_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'ANALYTICS_DEV_DEPLOY_WH'
    TYPE = SERVICE
    COMMENT = 'Service account for ANALYTICS DEV deployments';

GRANT ROLE ANALYTICS_DEV_DEPLOY_ROLE TO USER ANALYTICS_DEV_DEPLOYER;
```

### Example: Add a developer

Copy `sources/users/developers/.example.sql` to `sources/users/developers/<username>.sql`:

```sql
USE ROLE PLATFORM_DEPLOY_ROLE;

CREATE USER IF NOT EXISTS JSMITH
    DEFAULT_ROLE      = 'ANALYTICS_DEV_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'ANALYTICS_DEV_DEPLOY_WH'
    TYPE = PERSON
    COMMENT = 'Developer - John Smith';

GRANT ROLE ANALYTICS_DEV_DEPLOY_ROLE TO USER JSMITH;
```

### Example: Add an ops user

Copy `sources/users/ops/.example.sql` to `sources/users/ops/<username>.sql`:

```sql
USE ROLE PLATFORM_DEPLOY_ROLE;

CREATE USER IF NOT EXISTS MONITORING_BOT
    DEFAULT_ROLE      = 'PLATFORM_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'PLATFORM_DEPLOY_WH'
    TYPE = SERVICE
    COMMENT = 'Ops - monitoring service account';

GRANT ROLE PLATFORM_DEPLOY_ROLE TO USER MONITORING_BOT;
```

### After pushing

Push to `main` — the CI/CD pipeline creates the user automatically.

For service accounts, manually assign a key pair:

```sql
ALTER USER <username> SET RSA_PUBLIC_KEY='<public key content>';
```

## Onboarding a New Feature Project

### 1. Set project name in manifest.yml

```yaml
templating:
  defaults:
    project_name: ANALYTICS          # ← your project name
    environments:
      DEV:
        warehouse_size: XSMALL
      PROD:
        warehouse_size: SMALL
```

### 2. Add DCM project objects to bootstrap

Add a block to `bootstrap/01_pre_deploy.sql`:

```sql
CREATE DATABASE IF NOT EXISTS ANALYTICS_DCM;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DCM.PROJECTS;
CREATE DCM PROJECT IF NOT EXISTS ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_DEV;
CREATE DCM PROJECT IF NOT EXISTS ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_PROD;
```

Run it: `snow sql -f bootstrap/01_pre_deploy.sql --connection platform-deployer`

### 3. Run DCM deploy

```bash
snow dcm plan --target PLATFORM --connection platform-deployer
snow dcm deploy --target PLATFORM --connection platform-deployer
```

This creates: roles, warehouses, grants, DCM database/schema for all environments.

### 4. Add deployer users

Create files in `sources/users/deployers/`:

- `analytics_dev_deployer.sql`
- `analytics_prod_deployer.sql`

Use `.example.sql` as a template.

### 5. Transfer DCM project ownership

Add a block to `bootstrap/02_post_deploy.sql`:

```sql
GRANT OWNERSHIP ON DCM PROJECT ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_DEV
    TO ROLE ANALYTICS_DEV_DEPLOY_ROLE REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON DCM PROJECT ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_PROD
    TO ROLE ANALYTICS_PROD_DEPLOY_ROLE REVOKE CURRENT GRANTS;
```

Run it: `snow sql -f bootstrap/02_post_deploy.sql --connection platform-deployer`

### 6. Set up authentication

Generate key pairs, assign public keys, store private keys as GitHub Secrets in the feature repo.

## Adding a New Environment

### 1. Update manifest.yml

```yaml
templating:
  defaults:
    project_name: <PROJECT>
    environments:
      DEV:
        warehouse_size: XSMALL
      STAGING:                    # ← new
        warehouse_size: XSMALL
      PROD:
        warehouse_size: SMALL
```

### 2. Push to main

All Jinja2 templates automatically pick up the new environment. DCM deploy creates:

```
<PROJECT>_STAGING_DEPLOY_ROLE
<PROJECT>_STAGING_DEPLOY_WH (XSMALL)
+ all grants
```

### 3. Manual follow-up

- Add DCM project: `<PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_STAGING` to `bootstrap/01_pre_deploy.sql`
- Add deployer user: `sources/users/deployers/<project>_staging_deployer.sql`
- Transfer DCM project ownership in `bootstrap/02_post_deploy.sql`
- Generate key pair + store as GitHub Secret
