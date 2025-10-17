#!/usr/bin/env bash
set -euo pipefail

# ---------- Path config (single source of truth) ----------
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"

# Terraform root (override via: TF_ROOT=/custom/path ...)
: "${TF_ROOT:="$REPO_ROOT/src"}"

# Config file location (override via: CONFIG_FILE=/custom/path/config.yaml)
: "${CONFIG_FILE:="$TF_ROOT/config.yaml"}"

# Rendered backend file path (override via: BACKEND_HCL=/custom/path/backend.hcl)
: "${BACKEND_HCL:="$TF_ROOT/backend.hcl"}"

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off
export AWS_SDK_LOAD_CONFIG=1
export PYTHONUTF8=1
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# ---------- Helpers ----------
render_backend_hcl() {
  # Read CONFIG_FILE, write BACKEND_HCL (CI omits profile to use OIDC)
  CONFIG_FILE="$CONFIG_FILE" BACKEND_HCL="$BACKEND_HCL" GITHUB_ACTIONS="${GITHUB_ACTIONS:-}" python3 - <<'PY'
import yaml, os, sys
cfg_path = os.environ["CONFIG_FILE"]
out_path = os.environ["BACKEND_HCL"]
in_ci    = os.environ.get("GITHUB_ACTIONS","") == "true"

with open(cfg_path, 'r', encoding='utf-8') as f:
    cfg = yaml.safe_load(f) or {}
b = (cfg.get('backend') or {})

def line(k, v):
    if isinstance(v, bool):
        return f'{k} = {"true" if v else "false"}'
    return f'{k} = "{v}"'

req = ['bucket','key','region','dynamodb_table','encrypt']
missing = [k for k in req if k not in b]
if missing:
    print(f"{cfg_path} backend is missing keys: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

keys = ['bucket','key','region','dynamodb_table','encrypt']
if not in_ci:
    keys += ['profile','shared_credentials_file']

lines = []
for k in keys:
    if k in b and b[k] is not None:
        lines.append(line(k, b[k]))

header = [
    "# -------------------------------------------------------------------",
    "# AUTO-GENERATED FILE: DO NOT EDIT",
    "# Rendered from src/config.yaml. CI omits profile/creds to use OIDC.",
    "# -------------------------------------------------------------------",
    ""
]

with open(out_path, 'w', encoding='utf-8') as fh:
    fh.write("\n".join(header + lines) + "\n")

print(f"backend.hcl rendered -> {out_path}")
PY
}

# Export AWS env for local runs; CI uses OIDC. Region is exported for both.
export_local_aws_env() {
  local region profile
  region="$(CONFIG_FILE="$CONFIG_FILE" python3 - <<'PY'
import yaml, os
cfg=yaml.safe_load(open(os.environ["CONFIG_FILE"], encoding='utf-8')) or {}
print((cfg.get('backend') or {}).get('region',''))
PY
)"
  profile="$(CONFIG_FILE="$CONFIG_FILE" python3 - <<'PY'
import yaml, os
cfg=yaml.safe_load(open(os.environ["CONFIG_FILE"], encoding='utf-8')) or {}
print((cfg.get('backend') or {}).get('profile',''))
PY
)"

  [[ -n "$region"  ]] && export AWS_DEFAULT_REGION="$region"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    return 0
  fi
  [[ -n "$profile" ]] && export AWS_PROFILE="$profile"
}

# Create S3 backend + DynamoDB lock table if absent (idempotent)
ensure_backend_prereqs() {
  CONFIG_FILE="$CONFIG_FILE" python3 - <<'PY'
import yaml, os, subprocess
cfg=yaml.safe_load(open(os.environ["CONFIG_FILE"], encoding='utf-8')) or {}
b = cfg['backend']
bucket=b['bucket']; region=b['region']; table=b['dynamodb_table']

def run(args, check=False):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)

hb = run(["aws","s3api","head-bucket","--bucket",bucket])
if hb.returncode == 0:
    print(f"S3 bucket '{bucket}' exists.")
else:
    print(f"Creating S3 bucket '{bucket}' in {region}...")
    if region == "us-east-1":
        run(["aws","s3api","create-bucket","--bucket",bucket,"--region",region], check=True)
    else:
        run(["aws","s3api","create-bucket","--bucket",bucket,"--region",region,
             "--create-bucket-configuration",f"LocationConstraint={region}"], check=True)
    run(["aws","s3api","put-public-access-block","--bucket",bucket,
         "--public-access-block-configuration",
         "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"], check=True)
    run(["aws","s3api","put-bucket-versioning","--bucket",bucket,
         "--versioning-configuration","Status=Enabled"], check=True)
    run(["aws","s3api","put-bucket-encryption","--bucket",bucket,
         "--server-side-encryption-configuration",
         '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'], check=True)

dt = run(["aws","dynamodb","describe-table","--table-name",table,"--region",region])
if dt.returncode == 0:
    print(f"DynamoDB table '{table}' exists.")
else:
    print(f"Creating DynamoDB table '{table}' in '{region}'...")
    run(["aws","dynamodb","create-table",
         "--table-name",table,
         "--attribute-definitions","AttributeName=LockID,AttributeType=S",
         "--key-schema","AttributeName=LockID,KeyType=HASH",
         "--billing-mode","PAY_PER_REQUEST",
         "--region",region], check=True)
    run(["aws","dynamodb","wait","table-exists","--table-name",table,"--region",region], check=True)

print("Backend prerequisites verified.")
PY
}

# Full init pipeline: env → backend.hcl → ensure infra → terraform init
tf_backend_init() {
  export_local_aws_env
  render_backend_hcl
  ensure_backend_prereqs
  cd "$TF_ROOT"
  terraform init -reconfigure -backend-config="$BACKEND_HCL"
}

tf_format_validate() {
  cd "$TF_ROOT"
  terraform fmt -recursive
  terraform validate
}

tf_env_varfile_arg() {
  local vf="$TF_ROOT/env.tfvars"
  if [[ -f "$vf" ]]; then
    printf -- '-var-file=%s ' "$vf"
  fi
}
