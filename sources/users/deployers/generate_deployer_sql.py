"""Generate deployer user SQL statements from manifest.yml projects list."""

import sys
import yaml


def generate_deployer_sql(manifest_path: str) -> str:
    with open(manifest_path) as f:
        manifest = yaml.safe_load(f)

    projects = manifest["templating"]["defaults"]["projects"]
    statements = []

    for project_name, project in projects.items():
        for env in project["environments"]:
            user = f"{project_name}_{env}_DEPLOYER"
            role = f"{project_name}_{env}_DEPLOY_ROLE"
            wh = f"{project_name}_{env}_DEPLOY_WH"

            statements.append(f"""
CREATE USER IF NOT EXISTS {user}
    DEFAULT_ROLE      = '{role}'
    DEFAULT_WAREHOUSE = '{wh}'
    TYPE = SERVICE
    COMMENT = 'Service account for {project_name} {env} deployments';

GRANT ROLE {role} TO USER {user};""")

    return "USE ROLE PLATFORM_DEPLOY_ROLE;\n" + "\n".join(statements)


if __name__ == "__main__":
    manifest_path = sys.argv[1] if len(sys.argv) > 1 else "manifest.yml"
    print(generate_deployer_sql(manifest_path))
