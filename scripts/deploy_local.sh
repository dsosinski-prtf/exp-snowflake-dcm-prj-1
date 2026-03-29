#!/usr/bin/env bash
set -euo pipefail

# Local deployment script — mirrors the CI/CD pipeline
# Usage: ./scripts/deploy_local.sh [--connection <name>] [--plan-only]
#
# Defaults to --connection platform-deployer (from ~/.snowflake/connections.toml)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONNECTION="platform-deployer"
PLAN_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --connection) CONNECTION="$2"; shift 2 ;;
        --plan-only) PLAN_ONLY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_DIR"

# ── 1. Conda environment ──────────────────────────────────────────
echo "=== Setting up conda environment ==="
if ! conda info --envs | grep -q "snowflake"; then
    echo "Creating conda environment..."
    conda env create -f environment.yml
else
    echo "Updating conda environment..."
    conda env update -f environment.yml --prune
fi

eval "$(conda shell.bash hook)"
conda activate snowflake

# ── 2. Version check ──────────────────────────────────────────────
echo ""
echo "=== Versions ==="
snow --version
python --version

# ── 3. Connection test ────────────────────────────────────────────
echo ""
echo "=== Testing connection ($CONNECTION) ==="
snow connection test --connection "$CONNECTION"

# ── 4. DCM plan ───────────────────────────────────────────────────
echo ""
echo "=== DCM Plan ==="
snow dcm plan --target PLATFORM --connection "$CONNECTION"

if [ "$PLAN_ONLY" = true ]; then
    echo ""
    echo "Plan only mode — skipping deploy."
    exit 0
fi

# ── 5. DCM deploy ─────────────────────────────────────────────────
echo ""
echo "=== DCM Deploy ==="
snow dcm deploy --target PLATFORM --connection "$CONNECTION"

# ── 6. Platform users ─────────────────────────────────────────────
echo ""
echo "=== Deploy platform users ==="
for f in users/platform/*.sql; do
    [ -f "$f" ] || continue
    echo "Running $f"
    snow sql -f "$f" --connection "$CONNECTION"
done

# ── 7. Deployer users (auto-generated) ────────────────────────────
echo ""
echo "=== Deploy deployer users ==="
python users/deployers/generate_deployer_sql.py manifest.yml > /tmp/deployers.sql
echo "--- Generated SQL ---"
cat /tmp/deployers.sql
echo "--- Executing ---"
snow sql -f /tmp/deployers.sql --connection "$CONNECTION"

# ── 8. Developer users ────────────────────────────────────────────
echo ""
echo "=== Deploy developer users ==="
if [ -z "${DEFAULT_USER_PASSWORD:-}" ]; then
    read -sp "Enter DEFAULT_USER_PASSWORD: " DEFAULT_USER_PASSWORD
    echo ""
fi

for f in users/developers/*.sql; do
    [ -f "$f" ] || continue
    echo "Running $f"
    sed "s/__DEFAULT_USER_PASSWORD__/$DEFAULT_USER_PASSWORD/g" "$f" > /tmp/user.sql
    snow sql -f /tmp/user.sql --connection "$CONNECTION"
done

# ── 9. Ops users ──────────────────────────────────────────────────
echo ""
echo "=== Deploy ops users ==="
for f in users/ops/*.sql; do
    [ -f "$f" ] || continue
    echo "Running $f"
    snow sql -f "$f" --connection "$CONNECTION"
done

echo ""
echo "=== Deploy complete ==="
