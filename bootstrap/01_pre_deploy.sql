-- ============================================================
-- PRE-DEPLOY — Run as PLATFORM_DEPLOY_ROLE before first DCM deploy
-- Creates objects that DCM cannot manage itself.
--
-- Add a block for each new feature project.
-- ============================================================

USE ROLE PLATFORM_DEPLOY_ROLE;

-- Platform DCM project home
CREATE DATABASE IF NOT EXISTS PLATFORM_DCM;
CREATE SCHEMA IF NOT EXISTS PLATFORM_DCM.PROJECTS;
CREATE DCM PROJECT IF NOT EXISTS PLATFORM_DCM.PROJECTS.PLATFORM_PROJECT;

-- ---- Feature projects ----
-- Copy this block for each new project, replacing <PROJECT> with the project name.
--
-- CREATE DATABASE IF NOT EXISTS <PROJECT>_DCM;
-- CREATE SCHEMA IF NOT EXISTS <PROJECT>_DCM.PROJECTS;
-- CREATE DCM PROJECT IF NOT EXISTS <PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_DEV;
-- CREATE DCM PROJECT IF NOT EXISTS <PROJECT>_DCM.PROJECTS.<PROJECT>_PROJECT_PROD;
