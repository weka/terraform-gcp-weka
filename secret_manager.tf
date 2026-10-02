resource "google_project_service" "secret_manager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "secret_weka_password" {
  secret_id = "${var.prefix}-${var.cluster_name}-password"
  project   = var.project_id
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "password_secret_key" {
  secret                 = google_secret_manager_secret.secret_weka_password.id
  secret_data_wo         = "<placeholder-for-weka-admin-password>"
  secret_data_wo_version = "1"
  lifecycle {
    # both are ForceNew: without this, a deployment still holding secret_data in state
    # recreates this version and the placeholder shadows the password clusterize wrote
    ignore_changes = [secret_data, secret_data_wo_version]
  }
}

resource "google_secret_manager_secret" "weka_deployment_password" {
  secret_id = "${var.prefix}-${var.cluster_name}-deployment-password"
  project   = var.project_id
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret" "secret_weka_username" {
  secret_id = "${var.prefix}-${var.cluster_name}-username"
  project   = var.project_id
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "user_secret_key" {
  secret                 = google_secret_manager_secret.secret_weka_username.id
  secret_data_wo         = "weka-deployment"
  secret_data_wo_version = "1"
  lifecycle {
    # clusterize runs "weka user add" for this name once, so publishing a new version here
    # would only point the functions at a cluster user that does not exist
    ignore_changes = [secret_data, secret_data_wo_version]
  }
}

resource "google_secret_manager_secret" "secret_token" {
  count     = var.get_weka_io_token != "" ? 1 : 0
  project   = var.project_id
  secret_id = "${var.prefix}-${var.cluster_name}-token"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "token_secret_key" {
  count                  = var.get_weka_io_token != "" ? 1 : 0
  secret                 = google_secret_manager_secret.secret_token[0].id
  secret_data_wo         = var.get_weka_io_token
  secret_data_wo_version = "1"
  lifecycle {
    ignore_changes = [secret_data, secret_data_wo_version]
  }
}
