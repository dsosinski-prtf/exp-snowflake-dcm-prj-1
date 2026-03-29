-- Grants for each project's deployer per environment
{% for project_name, project in projects.items() %}
{% for env in project.environments.keys() %}
{# --- Role hierarchy: deployer -> SYSADMIN to prevent orphan roles --- #}
GRANT ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE TO ROLE SYSADMIN;

{# --- Warehouse usage --- #}
GRANT USAGE ON WAREHOUSE {{ project_name }}_{{ env }}_DEPLOY_WH TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;

{# --- DCM database/schema access --- #}
GRANT USAGE ON DATABASE {{ project_name }}_DCM TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
GRANT USAGE ON SCHEMA {{ project_name }}_DCM.PROJECTS TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;

{# --- Account-level privileges for creating app objects --- #}
GRANT CREATE DATABASE ON ACCOUNT TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
GRANT CREATE ROLE ON ACCOUNT TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
GRANT CREATE USER ON ACCOUNT TO ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
{% endfor %}
{% endfor %}
