# Snowflake Platform Admin (DCM)

Platform administration repo that manages deployment infrastructure for all Snowflake feature projects using [DCM Projects](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview).

## What this repo manages

### Via DCM (automated)
- **Deploy roles** per project/environment (e.g. `FITNESS_DEV_DEPLOY_ROLE`)
- **Deploy warehouses** per project/environment (e.g. `FITNESS_DEV_DEPLOY_WH`)
- **DCM management databases and schemas** (e.g. `FITNESS_DCM.PROJECTS`)
- **Grants** wiring deployers to their projects + role hierarchy to SYSADMIN

### Via bootstrap scripts (manual, one-time)
- **DCM project objects** — not a supported DEFINE type
- **Deployer users** — USER is not a supported DEFINE type
- **Role-to-user grants and DCM project ownership**

## Project structure

```
├── bootstrap/
│   ├── 01_pre_deploy.sql                <- run once before first DCM deploy
│   └── 02_post_deploy.sql               <- run once after first DCM deploy
├── manifest.yml                         <- platform DCM config
├── sources/definitions/
│   ├── dcm_projects.sql                 <- feature repo DCM databases/schemas
│   ├── deploy_roles.sql                 <- deployer roles
│   ├── deploy_warehouses.sql            <- deploy warehouses
│   └── grants.sql                       <- all permissions
└── .github/workflows/deploy.yml         <- CI/CD (future)
```

## Setup (one-time)

### Prerequisites
- Snowflake CLI installed (`snow --version`)
- Connection configured in `~/.snowflake/connections.toml` with ACCOUNTADMIN role

### Step 1: Run pre-deploy bootstrap

Creates DCM project objects that cannot be managed by DCM itself.

```bash
snow sql -f bootstrap/01_pre_deploy.sql --connection <your-connection>
```

This creates:
- `PLATFORM_DCM.PROJECTS.PLATFORM_PROJECT` (this repo's state)
- `FITNESS_DCM.PROJECTS.FITNESS_PROJECT_DEV` (feature repo DEV target)
- `FITNESS_DCM.PROJECTS.FITNESS_PROJECT_PROD` (feature repo PROD target)

### Step 2: Plan and deploy platform infrastructure

```bash
snow dcm plan --target PLATFORM --connection <your-connection>
snow dcm deploy --target PLATFORM --connection <your-connection>
```

This creates:
- `FITNESS_DEV_DEPLOY_ROLE` / `FITNESS_PROD_DEPLOY_ROLE`
- `FITNESS_DEV_DEPLOY_WH` (XSMALL) / `FITNESS_PROD_DEPLOY_WH` (SMALL)
- Grants: role hierarchy to SYSADMIN, warehouse usage, DCM access, account-level CREATE privileges

### Step 3: Run post-deploy bootstrap

Creates deployer users and assigns ownership. These reference roles and warehouses created in step 2.

```bash
snow sql -f bootstrap/02_post_deploy.sql --connection <your-connection>
```

This creates:
- `FITNESS_DEV_DEPLOYER` / `FITNESS_PROD_DEPLOYER` service accounts
- Role-to-user grants
- DCM project ownership transferred to deploy roles

### Step 4: Configure deployer authentication

Generate key pairs for each deployer user and store private keys as GitHub Secrets in the feature repo.

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out dev_deployer_key.p8 -nocrypt
openssl rsa -in dev_deployer_key.p8 -pubout -out dev_deployer_key.pub

openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out prod_deployer_key.p8 -nocrypt
openssl rsa -in prod_deployer_key.p8 -pubout -out prod_deployer_key.pub
```

Then assign public keys to users:

```sql
ALTER USER FITNESS_DEV_DEPLOYER SET RSA_PUBLIC_KEY='<contents of dev_deployer_key.pub>';
ALTER USER FITNESS_PROD_DEPLOYER SET RSA_PUBLIC_KEY='<contents of prod_deployer_key.pub>';
```

Add private keys as GitHub Secrets (`SNOWFLAKE_DEV_PRIVATE_KEY`, `SNOWFLAKE_PROD_PRIVATE_KEY`) in the feature repo.

## Ongoing changes

After initial setup, all infrastructure changes go through the standard DCM workflow:

```bash
# Preview changes
snow dcm plan --target PLATFORM --connection <your-connection>

# Apply changes
snow dcm deploy --target PLATFORM --connection <your-connection>
```

## Adding a new feature project

1. Add new environment entries to `manifest.yml` under `templating.defaults`
2. Add new definition files or extend existing loops
3. Run `snow dcm plan` / `snow dcm deploy`
4. Run a new post-deploy script for users and DCM project ownership

## Adding a new environment

Add the environment to the `environments` dictionary in `manifest.yml`:

```yaml
templating:
  defaults:
    project_name: FITNESS
    environments:
      DEV:
        warehouse_size: XSMALL
      STAGING:                    # <- new
        warehouse_size: XSMALL
      PROD:
        warehouse_size: SMALL
```

Then plan and deploy — all definition files automatically pick up the new environment via Jinja2 loops.
