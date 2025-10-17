#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

global_menu() {
  export_local_aws_env
  while true; do
    {
      echo
      echo "Private bucket sync"
      echo "AWS_PROFILE=${AWS_PROFILE:-<unset>}  AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-<unset>}"
      echo "──────────────────────────────────────────────────────────"
      echo "1) DRY-RUN pull (S3 -> ./private)"
      echo "2) Pull         (S3 -> ./private)"
      echo "3) DRY-RUN push (./private -> S3)"
      echo "4) Push         (./private -> S3)"
      echo "5) Continue to Terraform menu"
      echo "6) Quit"
    } >&2
    read -r -p "Choose: " g
    case "$g" in
      1) bash "$SCRIPT_DIR/private_sync.sh" dry-pull ;;
      2) bash "$SCRIPT_DIR/private_sync.sh" pull     ;;
      3) bash "$SCRIPT_DIR/private_sync.sh" dry-push ;;
      4) bash "$SCRIPT_DIR/private_sync.sh" push     ;;
      5) return 0 ;;
      6) exit 0 ;;
      *) echo "Invalid option." >&2 ;;
    esac
  done
}

terraform_menu() {
  while true; do
    export_local_aws_env
    echo
    echo "Terraform (Digital Ocean)"
    echo "--------------------------------------------------------------------------------"
    echo "CONFIG_FILE=${CONFIG_FILE}"
    echo "TF_ROOT=${TF_ROOT}"
    echo "AWS_PROFILE=${AWS_PROFILE:-<unset>}  |  AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-<unset>}"
    echo "--------------------------------------------------------------------------------"
    echo "1) fmt"
    echo "2) plan"
    echo "3) apply"
    echo "4) output (all)"
    echo "5) destroy"
    echo "6) back to sync menu"
    echo "7) quit"
    read -r -p "Choose: " choice
    case "$choice" in
      1) bash "$SCRIPT_DIR/fmt.sh" ;;
      2) bash "$SCRIPT_DIR/plan.sh" ;;
      3) bash "$SCRIPT_DIR/apply.sh" ;;
      4) bash "$SCRIPT_DIR/output.sh" ;;
      5) bash "$SCRIPT_DIR/destroy.sh" ;;
      6) return 0 ;;
      7) exit 0 ;;
      *) echo "Invalid option." >&2 ;;
    esac
  done
}

# Flow: sync menu first, then TF menu (loop)
while true; do
  global_menu
  terraform_menu
done
