locals {
  cloudrun_ingress_map = {
    ALLOW_ALL               = "INGRESS_TRAFFIC_ALL"
    ALLOW_INTERNAL_ONLY     = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    ALLOW_INTERNAL_AND_GCLB = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }
}
# ======================== deploy ============================
resource "google_cloud_run_v2_service" "cloud_internal" {
  count               = local.is_using_cloudfunctions ? 0 : 1
  name                = local.cloud_internal_function_name
  project             = var.project_id
  description         = "deploy, fetch, resize, clusterize, clusterize finalization, join, join_finalization, terminate, transient, terminate_cluster, scale_up functions"
  location            = lookup(var.cloud_functions_region_map, var.region, var.region)
  ingress             = local.cloudrun_ingress_map[local.function_ingress_settings]
  deletion_protection = false
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  template {
    timeout = "540s"
    scaling {
      max_instance_count = 20
      min_instance_count = 1
    }
    service_account = local.sa_email
    vpc_access {
      connector = local.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }
    containers {
      image = "${var.cloud_run_image_prefix}-cloudinternal"
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      dynamic "env" {
        for_each = local.cloud_internal_function_environment
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
  labels = {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, module.peering, google_project_service.run_api]
}

# IAM entry for all users to invoke the function
resource "google_cloud_run_v2_service_iam_member" "cloud_internal_invoker" {
  # can't use for_each here, as the elements of `cloud_function_invoker_allowed_members` are known after apply on first run
  count    = local.is_using_cloudfunctions ? 0 : length(local.cloud_function_invoker_allowed_members)
  project  = google_cloud_run_v2_service.cloud_internal[0].project
  location = google_cloud_run_v2_service.cloud_internal[0].location
  name     = google_cloud_run_v2_service.cloud_internal[0].name
  role     = "roles/run.invoker"
  member   = local.cloud_function_invoker_allowed_members[count.index]
}

# ======================== scale_down ============================
resource "google_cloud_run_v2_service" "scale_down" {
  count               = local.is_using_cloudfunctions ? 0 : 1
  name                = "${var.prefix}-${var.cluster_name}-scale-down"
  project             = var.project_id
  description         = "scale cluster down"
  location            = lookup(var.cloud_functions_region_map, var.region, var.region)
  ingress             = local.cloudrun_ingress_map[local.function_ingress_settings]
  deletion_protection = false
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  template {
    timeout = "540s"
    scaling {
      max_instance_count = 3
      min_instance_count = 1
    }
    service_account = local.sa_email
    vpc_access {
      connector = local.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }
    containers {
      image = "${var.cloud_run_image_prefix}-scaledown"
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }
  labels = {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.run_api]
}

# IAM entry for all users to invoke the function
resource "google_cloud_run_v2_service_iam_member" "weka_internal_invoker" {
  # can't use for_each here, as the elements of `cloud_function_invoker_allowed_members` are known after apply on first run
  count    = local.is_using_cloudfunctions ? 0 : length(local.cloud_function_invoker_allowed_members)
  project  = google_cloud_run_v2_service.scale_down[0].project
  location = google_cloud_run_v2_service.scale_down[0].location
  name     = google_cloud_run_v2_service.scale_down[0].name
  role     = "roles/run.invoker"
  member   = local.cloud_function_invoker_allowed_members[count.index]
}


# ======================== status ============================
resource "google_cloud_run_v2_service" "status" {
  count               = local.is_using_cloudfunctions ? 0 : 1
  name                = "${var.prefix}-${var.cluster_name}-status"
  project             = var.project_id
  description         = "get cluster status"
  location            = lookup(var.cloud_functions_region_map, var.region, var.region)
  ingress             = local.cloudrun_ingress_map[local.function_ingress_settings]
  deletion_protection = false
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  template {
    timeout = "540s"
    scaling {
      max_instance_count = 3
      min_instance_count = 1
    }
    service_account = local.sa_email
    vpc_access {
      connector = local.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }
    containers {
      image = "${var.cloud_run_image_prefix}-status"
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      dynamic "env" {
        for_each = local.status_function_environment
        content {
          name  = env.key
          value = env.value
        }

      }
    }
  }
  labels = {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.run_api]
}

# IAM entry for all users to invoke the function
resource "google_cloud_run_v2_service_iam_member" "status_invoker" {
  count    = local.is_using_cloudfunctions ? 0 : length(local.cloud_function_invoker_allowed_members)
  project  = google_cloud_run_v2_service.status[0].project
  location = google_cloud_run_v2_service.status[0].location
  name     = google_cloud_run_v2_service.status[0].name
  role     = "roles/run.invoker"
  member   = local.cloud_function_invoker_allowed_members[count.index]
}
