-- ============================================================
-- POST-DEPLOY — Run as ACCOUNTADMIN after first DCM deploy
-- Creates users and grants that reference DCM-managed objects
-- (roles, warehouses must exist before this runs)
-- ============================================================

-- Deployer service accounts (USER is not a DCM-supported object type)
-- Replace RSA_PUBLIC_KEY with actual keys for GitHub Actions auth
CREATE USER IF NOT EXISTS FITNESS_DEV_DEPLOYER
    DEFAULT_ROLE = 'FITNESS_DEV_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'FITNESS_DEV_DEPLOY_WH'
    TYPE = SERVICE;
--  RSA_PUBLIC_KEY = '<your_dev_public_key>';

CREATE USER IF NOT EXISTS FITNESS_PROD_DEPLOYER
    DEFAULT_ROLE = 'FITNESS_PROD_DEPLOY_ROLE'
    DEFAULT_WAREHOUSE = 'FITNESS_PROD_DEPLOY_WH'
    TYPE = SERVICE;
--  RSA_PUBLIC_KEY = '<your_prod_public_key>';

-- Assign deploy roles to deployer users
GRANT ROLE FITNESS_DEV_DEPLOY_ROLE TO USER FITNESS_DEV_DEPLOYER;
GRANT ROLE FITNESS_PROD_DEPLOY_ROLE TO USER FITNESS_PROD_DEPLOYER;

-- Grant DCM project ownership to deployer roles
GRANT OWNERSHIP ON DCM PROJECT FITNESS_DCM.PROJECTS.FITNESS_PROJECT_DEV
    TO ROLE FITNESS_DEV_DEPLOY_ROLE REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON DCM PROJECT FITNESS_DCM.PROJECTS.FITNESS_PROJECT_PROD
    TO ROLE FITNESS_PROD_DEPLOY_ROLE REVOKE CURRENT GRANTS;
