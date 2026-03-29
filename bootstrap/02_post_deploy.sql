-- ============================================================
-- POST-DEPLOY — Run as PLATFORM_DEPLOY_ROLE after first DCM deploy
-- Transfers DCM project ownership to deploy roles.
-- User creation is managed in sources/users/deployers/
--
-- Add a block for each new feature project.
-- ============================================================

USE ROLE PLATFORM_DEPLOY_ROLE;

-- ---- Feature projects ----
-- Copy this block for each new project, replacing <PROJECT> with the project name.
--
-- GRANT OWNERSHIP ON DCM PROJECT <PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_DEV
--     TO ROLE <PROJECT>_DEV_DEPLOY_ROLE REVOKE CURRENT GRANTS;
-- GRANT OWNERSHIP ON DCM PROJECT <PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_PROD
--     TO ROLE <PROJECT>_PROD_DEPLOY_ROLE REVOKE CURRENT GRANTS;
