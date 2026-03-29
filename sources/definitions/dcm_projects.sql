-- DCM management databases and schemas for feature projects
{% for project_name, project in projects.items() %}
DEFINE DATABASE {{ project_name }}_DCM;
DEFINE SCHEMA {{ project_name }}_DCM.PROJECTS;
{% endfor %}
