resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services=false
}

data "google_project" "project" {
}

resource "google_project_iam_binding" "cloudscheduler-binding" {
  count   = var.create_cloudscheduler_sa ? 1 : 0
  project = var.project
  role    = "roles/cloudscheduler.serviceAgent"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
  ]

  lifecycle {
    ignore_changes = [members]
  }
}

resource "google_workflows_workflow" "scale_down" {
  name            = "${var.prefix}-${var.cluster_name}-scale-down-workflow"
  region          = lookup(var.workflow_map_region, var.region, var.region)
  description     = "scale down workflow"
  service_account = local.sa_email
  source_contents = <<-EOF
  - fetch:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.fetch_function.service_config[0].uri}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions2_function.fetch_function.service_config[0].uri}
      result: FetchResult
  - scale_down:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.scale_down_function.service_config[0].uri}
          body: $${FetchResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions2_function.scale_down_function.service_config[0].uri}
      result: ScaleResult
  - terminate:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.terminate_function.service_config[0].uri}
          body: $${ScaleResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions2_function.terminate_function.service_config[0].uri}
      result: TerminateResult
  - transient:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.transient_function.service_config[0].uri}
          body: $${TerminateResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions2_function.transient_function.service_config[0].uri}
      result: TransientResult
  - returnOutput:
      return: $${TransientResult}
EOF

  depends_on = [google_project_service.workflows , google_cloudfunctions2_function.scale_down_function]
}

resource "google_cloud_scheduler_job" "scale_down_job" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  region = lookup(var.cloud_scheduler_region_map, var.region, var.region)
  description = "scale down job"
  schedule    = "* * * * *"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.scale_down.id}/executions"
    oauth_token {
      service_account_email = local.sa_email
    }
  }
  depends_on = [google_workflows_workflow.scale_down]
}

resource "google_workflows_workflow" "scale_up" {
  name            = "${var.prefix}-${var.cluster_name}-scale-up-workflow"
  region          = lookup(var.workflow_map_region, var.region, var.region)
  description     = "scale up workflow"
  service_account = local.sa_email
  source_contents = <<-EOF
  - scale_up:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.scale_up_function.service_config[0].uri}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions2_function.scale_up_function.service_config[0].uri}
      result: ScaleUpResult
  - returnOutput:
      return: $${ScaleUpResult}
EOF

  depends_on = [google_project_service.workflows, google_cloudfunctions2_function.scale_up_function, google_cloudfunctions2_function.deploy_function, google_cloudfunctions2_function.clusterize_function, google_cloudfunctions2_function.clusterize_finalization_function]
}

resource "google_cloud_scheduler_job" "scale_up_job" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up"
  description = "scale up job"
  schedule    = "* * * * *"
  region = lookup(var.cloud_scheduler_region_map, var.region, var.region)

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.scale_up.id}/executions"
    oauth_token {
      service_account_email = local.sa_email
    }
  }
  depends_on = [google_workflows_workflow.scale_up]
}
