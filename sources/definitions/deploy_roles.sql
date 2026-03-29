-- Deployer roles for each environment
{% for env in environments.keys() %}
DEFINE ROLE {{ project_name }}_{{ env }}_DEPLOY_ROLE;
{% endfor %}
