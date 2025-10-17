#!/usr/bin/env bash
# Minimal sync of ./private <-> s3://<bucket>/<prefix>
# Actions: pull | push | dry-pull | dry-push
# Requirements: aws cli must be authenticated.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
LOCAL_DIR="$REPO_ROOT/private"

# Allow overrides via env:
#   CONFIG_FILE (defaults to src/config.yaml)
#   S3_URI      (takes precedence over config)

: "${TF_ROOT:="$REPO_ROOT/src"}"
: "${CONFIG_FILE:="$TF_ROOT/config.yaml"}"

# Resolve S3 URI from config.yaml unless S3_URI is explicitly set
if [[ -z "${S3_URI:-}" ]]; then
  S3_URI="$(CONFIG_FILE="$CONFIG_FILE" python3 - <<'PY'
import yaml, os, sys
cfg_path = os.environ["CONFIG_FILE"]
cfg = yaml.safe_load(open(cfg_path, encoding='utf-8')) or {}
ps = (cfg.get('private_sync') or {})
bucket = ps.get('bucket')
prefix = ps.get('remote_dir_name')
if not bucket or not prefix:
    print(f"[private_sync] config.yaml requires private_sync.bucket and private_sync.remote_dir_name", file=sys.stderr)
    sys.exit(1)
print(f"s3://{bucket}/{prefix}")
PY
  )"
fi

# Preflight: verify AWS creds are loaded
if ! acct="$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)"; then
  echo "[private] ERROR: No AWS credentials detected. Export AWS_PROFILE or run via CI/OIDC." >&2
  exit 1
fi

echo "[private] Using AWS account: $acct  profile=${AWS_PROFILE:-<unset>}  region=${AWS_DEFAULT_REGION:-<unset>}"
echo "[private] LOCAL_DIR=$LOCAL_DIR"
echo "[private] S3_URI=$S3_URI"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [pull|push|dry-pull|dry-push]

  pull       Download from \$S3_URI/ -> $LOCAL_DIR/
  push       Upload   from $LOCAL_DIR/ -> \$S3_URI/
  dry-pull   Show what would be downloaded (no changes)
  dry-push   Show what would be uploaded (no changes)

Env overrides:
  CONFIG_FILE=${CONFIG_FILE}
  S3_URI (takes precedence over config)
EOF
}

cmd="${1:-}"; [[ -z "$cmd" ]] && { usage; exit 1; }
mkdir -p "$LOCAL_DIR"

common_args=(--only-show-errors --no-progress --delete)

case "$cmd" in
  pull)
    echo "[private] PULL  $S3_URI/  ->  $LOCAL_DIR/"
    aws s3 sync "$S3_URI/" "$LOCAL_DIR/" "${common_args[@]}"
    ;;
  push)
    echo "[private] PUSH  $LOCAL_DIR/ ->  $S3_URI/"
    aws s3 sync "$LOCAL_DIR/" "$S3_URI/" "${common_args[@]}"
    ;;
  dry-pull)
    echo "[private] DRY-RUN PULL"
    aws s3 sync "$S3_URI/" "$LOCAL_DIR/" "${common_args[@]}" --dryrun
    ;;
  dry-push)
    echo "[private] DRY-RUN PUSH"
    aws s3 sync "$LOCAL_DIR/" "$S3_URI/" "${common_args[@]}" --dryrun
    ;;
  *)
    usage; exit 1 ;;
esac

echo "[private] Done."
