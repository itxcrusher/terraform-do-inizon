# ===================================================================
#                               MAIN.TF
# DigitalOcean App Platform apps — config-driven, modules dumb.
# No defaults; everything comes from locals (which load config.yaml).
# ===================================================================

# PROD apps (for each app with a prod env)
resource "digitalocean_app" "prod" {
  for_each = local.prod_env_by_app

  spec {
    name   = "${each.key}-prod"
    region = local.do_region

    # --- Primary domain first (index 0) ---
    domain {
      name = each.value.domains[0]
    }

    # --- Remaining domains as aliases, stable order (no sorting) ---
    dynamic "domain" {
      for_each = { for d in slice(each.value.domains, 1, length(each.value.domains)) : d => d }
      content {
        name = domain.key
      }
    }

    static_site {
      name              = "web"
      build_command     = each.value.build_command
      output_dir        = local.do_output_dir
      index_document    = "index.html"
      catchall_document = "index.html"

      env {
        key   = "NODE_VERSION"
        value = tostring(each.value.node_version)
        scope = "BUILD_TIME"
      }

      github {
        repo           = local.do_repo
        branch         = each.value.branch
        deploy_on_push = true
      }
    }

    alert { rule = "DEPLOYMENT_FAILED" }
  }
}

resource "digitalocean_project_resources" "prod_attach" {
  for_each = digitalocean_app.prod
  project  = local.do_project_id
  resources = [
    digitalocean_app.prod[each.key].urn
  ]
}

# DEV apps (for each app with a dev env)
resource "digitalocean_app" "dev" {
  for_each = local.dev_env_by_app

  spec {
    name   = "${each.key}-dev"
    region = local.do_region

    # Primary domain first
    domain {
      name = each.value.domains[0]
    }

    # Any additional dev aliases (usually none)
    dynamic "domain" {
      for_each = { for d in slice(each.value.domains, 1, length(each.value.domains)) : d => d }
      content {
        name = domain.key
      }
    }

    static_site {
      name              = "web"
      build_command     = each.value.build_command
      output_dir        = local.do_output_dir
      index_document    = "index.html"
      catchall_document = "index.html"

      env {
        key   = "NODE_VERSION"
        value = tostring(each.value.node_version)
        scope = "BUILD_TIME"
      }

      github {
        repo           = local.do_repo
        branch         = each.value.branch
        deploy_on_push = true
      }
    }

    alert { rule = "DEPLOYMENT_FAILED" }
  }
}

resource "digitalocean_project_resources" "dev_attach" {
  for_each = digitalocean_app.dev
  project  = local.do_project_id
  resources = [
    digitalocean_app.dev[each.key].urn
  ]
}
