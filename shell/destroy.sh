#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/common.sh"

read -r -p "Type 'destroy' to confirm: " CONFIRM
[[ "$CONFIRM" == "destroy" ]] || { echo "Aborted."; exit 1; }

tf_backend_init
tf_format_validate
cd "$TF_ROOT"
terraform destroy -parallelism=1 -input=false -auto-approve $(tf_env_varfile_arg)
