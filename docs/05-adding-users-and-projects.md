# Adding Users & Projects

## Adding a New User

### Deployer users (auto-generated)

Deployer users are automatically created from the `projects` list in `manifest.yml`. No SQL files needed. Just add a project and push — the CI/CD pipeline generates and runs the SQL via `users/deployers/generate_deployer_sql.py`.

To disable a deployer, set `deployer_enabled: false` in `manifest.yml`:

```yaml
projects:
  FITNESS:
    environments:
      DEV:
        warehouse_size: XSMALL
        deployer_enabled: false    # disables FITNESS_DEV_DEPLOYER
```

### Developer users (one SQL file per user)

Create a `.sql` file in `users/developers/`. Use `users/developers/.example.sql` as a template.

Example — `users/developers/jsmith.sql`:

```sql
USE ROLE PLATFORM_DEPLOY_ROLE;

CREATE USER IF NOT EXISTS JSMITH
    DEFAULT_ROLE           = 'DEVELOPER_ROLE'
    TYPE                   = PERSON
    MUST_CHANGE_PASSWORD   = TRUE
    PASSWORD               = '__DEFAULT_USER_PASSWORD__'
    COMMENT                = 'Developer - John Smith';

GRANT ROLE DEVELOPER_ROLE TO USER JSMITH;

ALTER USER JSMITH SET DISABLED = FALSE;  -- set TRUE to disable
```

The `__DEFAULT_USER_PASSWORD__` placeholder is replaced at deploy time with the `DEFAULT_USER_PASSWORD` GitHub secret. The user must change this password on first login.

### Ops users (one SQL file per user)

Create a `.sql` file in `users/ops/`. Use `users/ops/.example.sql` as a template.

Example — `users/ops/monitoring_bot.sql`:

```sql
USE ROLE PLATFORM_DEPLOY_ROLE;

CREATE USER IF NOT EXISTS MONITORING_BOT
    DEFAULT_ROLE      = 'PLATFORM_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'PLATFORM_DEPLOY_WH'
    TYPE = SERVICE
    COMMENT = 'Ops - monitoring service account';

GRANT ROLE PLATFORM_DEPLOY_ROLE TO USER MONITORING_BOT;

ALTER USER MONITORING_BOT SET DISABLED = FALSE;  -- set TRUE to disable
```

### After pushing

Push to `main` — the CI/CD pipeline creates/updates the user automatically.

For service accounts, manually assign a key pair:

```sql
ALTER USER <username> SET RSA_PUBLIC_KEY='<public key content>';
```

### Disabling a user

- **Deployers:** set `deployer_enabled: false` in `manifest.yml`
- **Developers/Ops:** change `DISABLED = FALSE` to `DISABLED = TRUE` in their SQL file
- **Platform deployer:** must be done by ACCOUNTADMIN directly (owned by ACCOUNTADMIN)

## Onboarding a New Feature Project

### 1. Add project to manifest.yml

```yaml
templating:
  defaults:
    projects:
      FITNESS:
        environments:
          DEV: { warehouse_size: XSMALL }
          PROD: { warehouse_size: SMALL }
      ANALYTICS:                           # ← new project
        environments:
          DEV: { warehouse_size: XSMALL }
          PROD: { warehouse_size: MEDIUM }
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

### 3. Push to main

CI/CD automatically creates:
- Roles: `ANALYTICS_DEV_DEPLOY_ROLE`, `ANALYTICS_PROD_DEPLOY_ROLE`
- Warehouses: `ANALYTICS_DEV_DEPLOY_WH`, `ANALYTICS_PROD_DEPLOY_WH`
- Grants: role hierarchy, warehouse usage, DCM access, account privileges
- Deployer users: `ANALYTICS_DEV_DEPLOYER`, `ANALYTICS_PROD_DEPLOYER`

### 4. Transfer DCM project ownership

Add a block to `bootstrap/02_post_deploy.sql`:

```sql
GRANT OWNERSHIP ON DCM PROJECT ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_DEV
    TO ROLE ANALYTICS_DEV_DEPLOY_ROLE REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON DCM PROJECT ANALYTICS_DCM.PROJECTS.ANALYTICS_PROJECT_PROD
    TO ROLE ANALYTICS_PROD_DEPLOY_ROLE REVOKE CURRENT GRANTS;
```

Run it: `snow sql -f bootstrap/02_post_deploy.sql --connection platform-deployer`

### 5. Set up authentication

Generate key pairs, assign public keys, store private keys as GitHub Secrets in the feature repo.

## Adding a New Environment

### 1. Update manifest.yml

```yaml
projects:
  FITNESS:
    environments:
      DEV:
        warehouse_size: XSMALL
      STAGING:                    # ← new
        warehouse_size: XSMALL
      PROD:
        warehouse_size: SMALL
```

### 2. Push to main

All Jinja2 templates and the deployer script automatically pick up the new environment. Creates:

```
FITNESS_STAGING_DEPLOY_ROLE
FITNESS_STAGING_DEPLOY_WH (XSMALL)
FITNESS_STAGING_DEPLOYER
+ all grants
```

### 3. Manual follow-up

- Add DCM project: `FITNESS_DCM.PROJECTS.FITNESS_PROJECT_STAGING` to `bootstrap/01_pre_deploy.sql`
- Transfer DCM project ownership in `bootstrap/02_post_deploy.sql`
- Generate key pair + store as GitHub Secret
