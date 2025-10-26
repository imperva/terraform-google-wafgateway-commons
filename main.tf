locals {
  constants = {
    gcp = {
      image_url_prefix = "https://www.googleapis.com/compute/v1/projects/imperva-cloud-images-public/global/images/"
      healthcheck_source_ranges = [
        "130.211.0.0/22",
        "35.191.0.0/16"
      ]
      gw_healthcheck_port = 541
      autoscaling = {
        cpu_threshold = 0.7
        throughput_threshold = 0.7
        cooldown_period = 360
        health_check = {
          interval_sec = 5
          timeout_sec = 5
          healthy_threshold = 2
          unhealthy_threshold = 3
          port = 541
        }
      }
      lb = {
        health_check = {
          interval_sec = 3
          timeout_sec = 3
          healthy_threshold = 2
          unhealthy_threshold = 2
          port = 541
        }
      }
      model_throughput_capping = {
        GV1000 = 100 / 8 * 1000 * 1000 # 100 Mbps to bytes conversion
        GV2500 = 500 / 8 * 1000 * 1000 # 500 Mbps to bytes conversion
      }
    }
    global = module.commons.constants.global
  }
  raw_builds = {
    for build_data in module.commons.available_builds.builds: 
    "${build_data.build}${build_data.location == "us" ? "" : "-${build_data.location}"}" => replace(build_data.link, local.constants.gcp.image_url_prefix, "")
    if contains(local.options.waf.supported_versions, build_data.build)
  }
  selectable_builds = local.raw_builds
  options = {
    gcp = {
      mx_instance_types = [
        "n2-standard-4",
        "n2-standard-8"
      ]
      gw_instance_types = [
        "c2-standard-4", 
        "c2-standard-8", 
        "c2-standard-16", 
        "n2-standard-4", 
        "n2-standard-8", 
        "n2-standard-16"
      ]
      ip_network_tiers = [
        "PREMIUM",
        "FIXED_STANDARD",
        "STANDARD"
      ]
      gw_models = [
        "GV1000",
        "GV2500"
      ]
      lb = {
        frontend_protocols = [
          "HTTP",
          "HTTPS"
        ]
        backend_protocols = [
          "HTTP",
          "HTTPS",
          "HTTP/2"
        ],
        schemes = [
          "EXTERNAL_MANAGED"
        ]
        types = [
          "GLOBAL",
          "REGIONAL"
        ]
      }
    }
    waf = {
      supported_versions = [
        "14.7.0.140",
        "14.7.0.150",
        "14.7.0.160",
        "15.3.0.10",
        "15.3.0.20",
        "15.4.0.10"
      ]
    }
    global = module.commons.options.global
  }

  validation_rules = {
    gcp = {
      mx_instance_type = {
        allowed_values = local.options.gcp.mx_instance_types
        error_message = "Valid values are: ${join(", ", local.options.gcp.mx_instance_types)}"
      }
      gw_instance_type = {
        allowed_values = local.options.gcp.gw_instance_types
        error_message = "Valid values are: ${join(", ", local.options.gcp.gw_instance_types)}"
      }
      ip_network_tier = {
        allowed_values = flatten([
          "",
          local.options.gcp.ip_network_tiers
        ])
        error_message = "Valid values are ${join(", ", local.options.gcp.ip_network_tiers)}."
      }
      standard_name = {
        regex = "^[a-z][-a-z0-9]*[a-z0-9]$"
        error_message = "Must consist of lowercase letters (a-z), numbers, and hyphens."
      }
      gw_model = {
        allowed_values = local.options.gcp.gw_models
        error_message = "Valid values are: ${join(", ", local.options.gcp.gw_models)}"
      }
      lb = {
        frontend_protocol = {
          allowed_values = local.options.gcp.lb.frontend_protocols
          error_message = "Supported frontend protocols are: ${join(", ", local.options.gcp.lb.frontend_protocols)}"
        }
        backend_protocol = {
          allowed_values = local.options.gcp.lb.backend_protocols
          error_message = "Supported backend protocols are: ${join(", ", local.options.gcp.lb.backend_protocols)}"
        }
        scheme = {
          default = local.options.gcp.lb.schemes[0]
          allowed_values = local.options.gcp.lb.schemes
          error_message = "Supported schemes are: ${join(", ", local.options.gcp.lb.schemes)}"
        }
        type = {
          default = local.options.gcp.lb.types[0]
          allowed_values = local.options.gcp.lb.types
          error_message = "Supported types are: ${join(", ", local.options.gcp.lb.types)}"
        }
      }
      gw_count = {
        minimum = 0
        maximum = 20
      }
      waf_version = {
        allowed_values = keys(local.selectable_builds)
        error_message = "Invalid version. Valid values are: ${join(", ", keys(local.selectable_builds))}"
      }
      subnet = {
        private_google_access = {
          error_message = "Private Google Access must be enabled for all supplied subnets"
        }
      }
    }   
    global = module.commons.validation.global
  }    
}

module "commons" {
  source = "imperva/commons/wafgateway"
  platform = "gcp"
}