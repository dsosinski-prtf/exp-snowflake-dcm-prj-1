# Snowflake Platform Admin (DCM)

Platform administration repo that manages deployment infrastructure for all Snowflake feature projects using [DCM Projects](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview).

## What this repo manages

### Via DCM (automated)
- **Deploy roles** per project/environment (e.g. `FITNESS_DEV_DEPLOY_ROLE`)
- **Deploy warehouses** per project/environment (e.g. `FITNESS_DEV_DEPLOY_WH`)
- **DCM management databases and schemas** (e.g. `FITNESS_DCM.PROJECTS`)
- **Grants** wiring deployers to their projects + role hierarchy to SYSADMIN

### Via bootstrap scripts (manual, one-time)
- **Platform admin user + role** (`PLATFORM_DEPLOYER` / `PLATFORM_DEPLOY_ROLE`) — runs all DCM operations instead of ACCOUNTADMIN
- **DCM project objects** — not a supported DEFINE type
- **Deployer users** — USER is not a supported DEFINE type
- **Role-to-user grants and DCM project ownership**

## Project structure

```
├── auth-key-pairs/                      <- RSA key pairs per user (gitignored)
│   ├── accountadmin/
│   ├── platform-deployer/
│   ├── dev-deployer/
│   └── prod-deployer/
├── bootstrap/
│   ├── 00_platform_user.sql             <- run once as ACCOUNTADMIN to create platform user
│   ├── 01_pre_deploy.sql                <- run once before first DCM deploy (as PLATFORM_DEPLOYER)
│   └── 02_post_deploy.sql               <- run once after first DCM deploy (as PLATFORM_DEPLOYER)
├── manifest.yml                         <- platform DCM config (owner: PLATFORM_DEPLOY_ROLE)
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
- Connection configured in `~/.snowflake/connections.toml` with ACCOUNTADMIN role (only needed for Step 0)

### Step 0: Create platform user (run as ACCOUNTADMIN)

Creates a dedicated `PLATFORM_DEPLOYER` user and `PLATFORM_DEPLOY_ROLE` so that ACCOUNTADMIN is not used for day-to-day operations. This is the only step that requires ACCOUNTADMIN.

```bash
snow sql -f bootstrap/00_platform_user.sql --connection <accountadmin-connection>
```

This creates:
- `PLATFORM_DEPLOY_ROLE` with account-level privileges (CREATE DATABASE/WAREHOUSE/ROLE/USER, MANAGE GRANTS — all WITH GRANT OPTION)
- `PLATFORM_DEPLOYER` service account (key-pair auth only, no password)
- `PLATFORM_DEPLOY_WH` (XSMALL) warehouse for platform deployments
- Role hierarchy: `PLATFORM_DEPLOY_ROLE` -> `ACCOUNTADMIN`

Then generate a key pair and assign it:

```bash
cd auth-key-pairs/platform-deployer
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

```sql
-- Run as ACCOUNTADMIN
ALTER USER PLATFORM_DEPLOYER SET RSA_PUBLIC_KEY='<contents of rsa_key.pub>';
```

Configure a Snowflake CLI connection for the platform user in `~/.snowflake/connections.toml`:

```toml
[platform]
account = "<<account>>"
user = "PLATFORM_DEPLOYER"
role = "PLATFORM_DEPLOY_ROLE"
warehouse = "PLATFORM_DEPLOY_WH"
authenticator = "SNOWFLAKE_JWT"
private_key_file = "<<path to private key filep 8"
``` 

All subsequent steps use `--connection platform` instead of ACCOUNTADMIN.

### Step 1: Run pre-deploy bootstrap

Creates DCM project objects that cannot be managed by DCM itself.

```bash
snow sql -f bootstrap/01_pre_deploy.sql --connection platform
```

This creates:
- `PLATFORM_DCM.PROJECTS.PLATFORM_PROJECT` (this repo's state)
- `FITNESS_DCM.PROJECTS.FITNESS_PROJECT_DEV` (feature repo DEV target)
- `FITNESS_DCM.PROJECTS.FITNESS_PROJECT_PROD` (feature repo PROD target)

### Step 2: Plan and deploy platform infrastructure

```bash
snow dcm plan --target PLATFORM --connection platform
snow dcm deploy --target PLATFORM --connection platform
```

This creates:
- `FITNESS_DEV_DEPLOY_ROLE` / `FITNESS_PROD_DEPLOY_ROLE`
- `FITNESS_DEV_DEPLOY_WH` (XSMALL) / `FITNESS_PROD_DEPLOY_WH` (SMALL)
- Grants: role hierarchy to SYSADMIN, warehouse usage, DCM access, account-level CREATE privileges

### Step 3: Run post-deploy bootstrap

Creates deployer users and assigns ownership. These reference roles and warehouses created in step 2.

```bash
snow sql -f bootstrap/02_post_deploy.sql --connection platform
```

This creates:
- `FITNESS_DEV_DEPLOYER` / `FITNESS_PROD_DEPLOYER` service accounts
- Role-to-user grants
- DCM project ownership transferred to deploy roles

### Step 4: Configure deployer authentication

Generate key pairs for each deployer user and store private keys as GitHub Secrets in the feature repo.

```bash
cd auth-key-pairs/dev-deployer
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

cd auth-key-pairs/prod-deployer
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

Then assign public keys to users:

```sql
ALTER USER FITNESS_DEV_DEPLOYER SET RSA_PUBLIC_KEY='<contents of dev-deployer/rsa_key.pub>';
ALTER USER FITNESS_PROD_DEPLOYER SET RSA_PUBLIC_KEY='<contents of prod-deployer/rsa_key.pub>';
```

Add private keys as GitHub Secrets (`SNOWFLAKE_DEV_PRIVATE_KEY`, `SNOWFLAKE_PROD_PRIVATE_KEY`) in the feature repo.

## Authentication

All users authenticate via RSA key pairs (no passwords). Key pairs are stored in `auth-key-pairs/` (gitignored).

| User | Role | Type | Auth |
|------|------|------|------|
| `DSOSINSKI` | `ACCOUNTADMIN` | PERSON | Key pair |
| `PLATFORM_DEPLOYER` | `PLATFORM_DEPLOY_ROLE` | SERVICE | Key pair |
| `FITNESS_DEV_DEPLOYER` | `FITNESS_DEV_DEPLOY_ROLE` | SERVICE | Key pair |
| `FITNESS_PROD_DEPLOYER` | `FITNESS_PROD_DEPLOY_ROLE` | SERVICE | Key pair |

Service accounts (`TYPE = SERVICE`) cannot use password authentication by design.

## Ongoing changes

After initial setup, all infrastructure changes go through the standard DCM workflow using the platform deployer:

```bash
# Preview changes
snow dcm plan --target PLATFORM --connection platform

# Apply changes
snow dcm deploy --target PLATFORM --connection platform
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
