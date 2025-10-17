# Terraform — DigitalOcean App Platform (Insizon)

## Why this repo exists

Deploy and manage **Insizon Angular** on **DigitalOcean App Platform** for **prod** and **dev**, with:

* **Single source of truth**: `src/config.yaml`
* **Deterministic Terraform**: `locals.tf` loads & validates, `main.tf` applies, no silent defaults
* **State in S3 + DynamoDB locks** using AWS OIDC (CI) or profile (local)
* **Local + CI workflow** via `shell/` scripts and GitHub Actions

---

## Repo layout

```bash
.
├── README.md
├── docs/
├── index.sh                     # entrypoint: runs the interactive prompt
├── private/                     # synced to s3://.../do via shell/private_sync.sh
├── shell/
│   ├── apply.sh                 # init→fmt→validate→apply
│   ├── backend_init.sh          # renders backend.hcl from config.yaml + ensures S3/DDB
│   ├── common.sh                # helpers for init/env/config rendering
│   ├── destroy.sh               # safe destroy with prompt
│   ├── fmt.sh
│   ├── output.sh
│   ├── plan.sh
│   ├── private_sync.sh          # pulls/pushes ./private with S3 (reads config.yaml)
│   └── prompt.sh                # interactive menu (sync + terraform)
└── src/
    ├── backend.hcl              # auto-generated (do not edit)
    ├── config.yaml              # THE config (apps, backend, private sync, etc.)
    ├── env.tfvars               # optional var-file (local secrets, if you want)
    ├── locals.tf                # loads+validates config, computes inputs (no try/defaults)
    ├── main.tf                  # DO apps + project attachment (dumb, explicit inputs)
    ├── oidc.tf                  # AWS IAM role+policy for CI OIDC (names are DO-scoped)
    ├── outputs.tf               # verification outputs (no secrets)
    ├── providers.tf             # providers only (no inline config)
    └── variables.tf             # variables (all values come from config/TF_VARs)
```

---

## One source of truth: `src/config.yaml`

**Everything** must be defined here (no hidden defaults in TF).

**Validation:** `locals.tf` uses `check {}` blocks to **fail hard** if anything required is missing or malformed.

---

## Providers & auth

* **DigitalOcean**: set `TF_VAR_do_token` (CI uses repo secret `DO_TOKEN`).
* **AWS (backend)**:

  * **CI**: GitHub OIDC → role `Do-GitHubOIDC-TerraformRole`
  * **Local**: AWS profile from `backend.profile` (exported by `shell/common.sh`)

---

## How to run (local)

### Option A — interactive menu (recommended)

```bash
./index.sh
# 1) sync ./private with S3 (dry-run or real)
# 2) fmt / plan / apply / output / destroy
```

### Option B — direct scripts

```bash
# Render backend.hcl + ensure S3 bucket & DynamoDB table exist + terraform init
bash ./shell/backend_init.sh

# Plan / Apply
bash ./shell/plan.sh
bash ./shell/apply.sh

# Outputs
bash ./shell/output.sh

# Destroy (with confirmation)
bash ./shell/destroy.sh
```

#### Env you’ll need locally

```bash
export TF_VAR_do_token=<your_do_token>
# Optional if you want to override:
export TF_ROOT=./src
export CONFIG_FILE=./src/config.yaml
```

---

## CI (GitHub Actions)

* Workflow name: `terraform`
* OIDC assumes `arn:aws:iam::252925426330:role/Do-GitHubOIDC-TerraformRole`
* Steps:

  1. Checkout
  2. Configure AWS creds (OIDC)
  3. `hashicorp/setup-terraform`
  4. `shell/backend_init.sh` (renders backend + ensures state infra)
  5. Plan on PR, Apply on push to `main`

**Required secret:** `DO_TOKEN` (used as `TF_VAR_do_token`)

---

## DigitalOcean apps (what gets created)

For every app in `digitalocean.apps[]`:

* `digitalocean_app.prod[app]`
* `digitalocean_app.dev[app]` (if `dev` exists)
* Attachments: `digitalocean_project_resources.prod_attach[app]` / `dev_attach[app]`

**Domains order matters**: **first domain is PRIMARY**.
We explicitly emit the first domain, then any aliases, to keep it stable and avoid Terraform flip-flopping.

---

## Outputs (human-friendly)

* `prod_apps` / `dev_apps`: id, urn, branch, domains, live_url, name
* `do_project_id`, `region`, `repo`

Example:

```text
prod_apps = {
  insizon-angular = {
    branch   = "main"
    domains  = ["www.insizon.com","insizon.com"]
    id       = "<uuid>"
    live_url = "https://www.insizon.com"
    name     = "insizon-angular-prod"
    urn      = "do:app:<uuid>"
  }
}
```

---

## Private artifacts sync

`./shell/private_sync.sh` reads S3 details from `config.yaml` → `private_sync.bucket` + `remote_dir_name`.

```bash
# Dry-run pull/push
bash ./shell/private_sync.sh dry-pull
bash ./shell/private_sync.sh dry-push

# Real pull/push
bash ./shell/private_sync.sh pull
bash ./shell/private_sync.sh push
```

Override manually if you ever need:

```bash
S3_URI="s3://custom-bucket/custom-prefix" bash ./shell/private_sync.sh pull
```

---

## Gotchas & tips

* **State refactors**: if resource addresses change (e.g., moved to `for_each`), use `moved {}` blocks or `terraform state mv` to **migrate state**, not resources.
* **DO primary domain**: keep your intended primary domain as index `0` in YAML.
* **Lock table name**: keep `backend.dynamodb_table` consistent across repos to avoid spawning siblings.
* **No defaults**: if it isn’t in `config.yaml`, plan should fail. That’s by design.

---

## Troubleshooting

| Symptom                         | Likely cause                       | Fix                                                                                                              |
| ------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Terraform wants to swap domains | You sorted domains                 | We emit first domain as explicit primary + unsorted rest. Keep desired primary at index 0.                       |
| `EntityAlreadyExists` on IAM    | Role/Policy names already exist    | `terraform import` them into `aws_iam_role.gha_terraform` / `aws_iam_policy.tf_state_access`, or rename in code. |
| `No AWS credentials` locally    | Missing profile vars               | Ensure `backend.profile` is set and you have that profile. `aws sts get-caller-identity` should work.            |
| CI can’t assume role            | Wrong role ARN or OIDC not present | Confirm workflow uses the new role ARN; verify OIDC provider exists in the account.                              |
| DO deploys stale build          | DO cache or no code change         | Trigger a redeploy from DO dashboard or push a no-op commit; clear CDN if needed.                                |

---

## Credits

**Owner:** Muhammad Hassaan Javed | Senior Infrastructure Engineer | [Linktree](https://linktr.ee/itxcrusher)
**Platform:** DigitalOcean App Platform
**Infra:** Terraform + GitHub OIDC + S3/DynamoDB backend
**Domains:**

* Prod → [https://www.insizon.com](https://www.insizon.com)
* Dev → [https://dev.insizon.com](https://dev.insizon.com)

> build like a poet: few words, strong guarantees.
