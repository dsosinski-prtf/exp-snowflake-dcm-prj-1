-- DCM management database and schema for feature repo
-- Note: DCM PROJECT objects are not a supported DEFINE type,
-- they are created via bootstrap/setup.sql
DEFINE DATABASE {{ project_name }}_DCM;

DEFINE SCHEMA {{ project_name }}_DCM.PROJECTS;
