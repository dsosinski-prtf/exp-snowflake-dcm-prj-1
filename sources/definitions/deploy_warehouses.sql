-- Dedicated warehouses for running deployments
{% for project_name, project in projects.items() %}
{% for env, config in project.environments.items() %}
DEFINE WAREHOUSE {{ project_name }}_{{ env }}_DEPLOY_WH
    WAREHOUSE_SIZE = '{{ config.warehouse_size }}'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;
{% endfor %}
{% endfor %}
