#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/common.sh"

tf_backend_init
tf_format_validate
cd "$TF_ROOT"
terraform plan -parallelism=1 -input=false $(tf_env_varfile_arg)
