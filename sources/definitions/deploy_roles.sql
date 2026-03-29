-- Deployer roles for each project and environment
{% for project_name, project in projects.items() %}
{% for env in project.environments.keys() %}
DEFINE ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
{% endfor %}
{% endfor %}
