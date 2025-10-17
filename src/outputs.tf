# ==========================================
# outputs.tf — Human-friendly verification
# ==========================================

output "do_project_id" {
  value     = local.do_project_id
  sensitive = false
}

output "region" {
  value     = local.do_region
  sensitive = false
}

output "repo" {
  value     = local.do_repo
  sensitive = false
}

output "prod_apps" {
  value = {
    for name, app in digitalocean_app.prod :
    name => {
      id       = app.id
      urn      = app.urn
      live_url = try(app.live_url, null)
      name     = app.spec[0].name
      domains  = local.prod_env_by_app[name].domains
      branch   = local.prod_env_by_app[name].branch
    }
  }
  sensitive = false
}

output "dev_apps" {
  value = {
    for name, app in digitalocean_app.dev :
    name => {
      id       = app.id
      urn      = app.urn
      live_url = try(app.live_url, null)
      name     = app.spec[0].name
      domains  = local.dev_env_by_app[name].domains
      branch   = local.dev_env_by_app[name].branch
    }
  }
  sensitive = false
}
