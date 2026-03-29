-- ============================================================
-- PLATFORM ROLE & PRIVILEGES — Run ONCE as ACCOUNTADMIN
-- Creates the role, privileges, and warehouse for platform admin.
-- User creation is managed in sources/users/platform/
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ---- Role ----
CREATE ROLE IF NOT EXISTS PLATFORM_DEPLOY_ROLE
    COMMENT = 'Manages all platform-admin DCM objects (databases, warehouses, roles, users, grants)';

-- Role hierarchy: PLATFORM_DEPLOY_ROLE -> ACCOUNTADMIN
GRANT ROLE PLATFORM_DEPLOY_ROLE TO ROLE ACCOUNTADMIN;

-- ---- Account-level privileges ----
-- WITH GRANT OPTION so DCM can delegate these to deploy roles
GRANT CREATE DATABASE  ON ACCOUNT TO ROLE PLATFORM_DEPLOY_ROLE WITH GRANT OPTION;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE PLATFORM_DEPLOY_ROLE WITH GRANT OPTION;
GRANT CREATE ROLE      ON ACCOUNT TO ROLE PLATFORM_DEPLOY_ROLE WITH GRANT OPTION;
GRANT CREATE USER      ON ACCOUNT TO ROLE PLATFORM_DEPLOY_ROLE WITH GRANT OPTION;
GRANT MANAGE GRANTS    ON ACCOUNT TO ROLE PLATFORM_DEPLOY_ROLE;

-- ---- Warehouse for platform deploys ----
CREATE WAREHOUSE IF NOT EXISTS PLATFORM_DEPLOY_WH
    WAREHOUSE_SIZE    = 'XSMALL'
    AUTO_SUSPEND      = 60
    AUTO_RESUME       = TRUE
    INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE PLATFORM_DEPLOY_WH TO ROLE PLATFORM_DEPLOY_ROLE;
