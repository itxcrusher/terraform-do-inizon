# ===================================================================
#                                LOCALS.TF
#   Load config.yaml, derive arguments, and validate aggressively.
#   No defaults. No try(). Missing fields => fail via check{}.
# ===================================================================

locals {
  # ------- Load full config -------
  cfg = yamldecode(file("${path.module}/config.yaml"))

  # ------- Top-level toggles & blocks (must exist; validated below) -------
  enabled = local.cfg.enabled
  backend = local.cfg.backend
  github  = local.cfg.github
  oidc    = local.cfg.oidc

  do_cfg        = local.cfg.digitalocean
  do_region     = trimspace(local.do_cfg.region)
  do_repo       = trimspace(local.do_cfg.github_repo)
  do_output_dir = trimspace(local.do_cfg.output_dir)

  # Project id/name presence checked below
  do_project_id_raw = trimspace(local.do_cfg.project_id)
  do_project_name   = trimspace(local.do_cfg.project_name)

  # Apps list and shape validated below
  do_apps = [
    for a in local.do_cfg.apps : {
      name         = trimspace(a.name)
      environments = a.environments
    }
  ]

  # Resolve project ID if not provided (via data source in main graph)
  use_project_lookup = length(local.do_project_id_raw) == 0

  # Flatten envs for per-env maps (validated to exist before use)
  prod_env_by_app = {
    for a in local.do_apps :
    a.name => a.environments.prod
    if contains(keys(a.environments), "prod")
  }

  dev_env_by_app = {
    for a in local.do_apps :
    a.name => a.environments.dev
    if contains(keys(a.environments), "dev")
  }
}

# ----------------------------
#    DATA (project by name)
# ----------------------------
data "digitalocean_project" "by_name" {
  count = local.use_project_lookup ? 1 : 0
  name  = local.do_project_name
}

locals {
  do_project_id = local.use_project_lookup ? data.digitalocean_project.by_name[0].id : local.do_project_id_raw
}

# ===================================================================
#                            VALIDATIONS
# ===================================================================

check "config_present" {
  assert {
    condition     = can(local.cfg)
    error_message = "src/config.yaml is missing or unreadable."
  }
}

check "top_level_blocks" {
  assert {
    condition = alltrue([
      contains(keys(local.cfg), "enabled"),
      contains(keys(local.cfg), "backend"),
      contains(keys(local.cfg), "github"),
      contains(keys(local.cfg), "oidc"),
      contains(keys(local.cfg), "digitalocean")
    ])
    error_message = "config.yaml must contain: enabled, backend, github, oidc, digitalocean."
  }
}

check "backend_shape" {
  assert {
    condition = alltrue([
      contains(keys(local.backend), "account_id"),
      contains(keys(local.backend), "bucket"),
      contains(keys(local.backend), "key"),
      contains(keys(local.backend), "region"),
      contains(keys(local.backend), "profile"),
      contains(keys(local.backend), "encrypt"),
      contains(keys(local.backend), "use_lockfile"),
      (local.backend.use_lockfile ? contains(keys(local.backend), "dynamodb_table") : true)
    ])
    error_message = "backend{} requires: account_id, bucket, key, region, profile, encrypt, use_lockfile (+ dynamodb_table when use_lockfile=true)."
  }
}

check "github_shape" {
  assert {
    condition = alltrue([
      contains(keys(local.github), "owner"),
      contains(keys(local.github), "repo"),
      contains(keys(local.github), "main_branch"),
      contains(keys(local.github), "dev_branch")
    ])
    error_message = "github{} requires: owner, repo, main_branch, dev_branch."
  }
}

check "oidc_shape" {
  assert {
    condition = alltrue([
      contains(keys(local.oidc), "thumbprint_list")
    ])
    error_message = "oidc{} requires: thumbprint_list."
  }
}

check "do_shape" {
  assert {
    condition = alltrue([
      contains(keys(local.do_cfg), "region"),
      contains(keys(local.do_cfg), "github_repo"),
      contains(keys(local.do_cfg), "output_dir"),
      contains(keys(local.do_cfg), "apps"),
      (length(local.do_project_id_raw) > 0 || length(local.do_project_name) > 0),
      length(local.do_apps) > 0
    ])
    error_message = "digitalocean{} requires: region, github_repo, output_dir, apps[], and either project_id or project_name."
  }
}

check "apps_have_envs" {
  assert {
    condition = alltrue([
      for a in local.do_apps : contains(keys(a), "environments")
    ])
    error_message = "Each app must define an 'environments' block."
  }
}

check "env_fields_required" {
  assert {
    condition = alltrue(flatten([
      for a in local.do_apps : [
        for env in ["prod", "dev"] : (
          contains(keys(a.environments), env)
          ? alltrue([
            contains(keys(a.environments[env]), "domains"),
            contains(keys(a.environments[env]), "branch"),
            contains(keys(a.environments[env]), "build_command"),
            contains(keys(a.environments[env]), "node_version"),
            length(a.environments[env].domains) > 0
          ])
          : true
        )
      ]
    ]))
    error_message = "Each defined environment must include non-empty: domains[], branch, build_command, node_version."
  }
}
