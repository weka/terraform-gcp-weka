resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services=false
}

data "google_project" "project" {
}

resource "google_project_iam_binding" "project" {
  count   = var.create_cloudscheduler_sa ? 1 : 0
  project = var.project
  role    = "roles/cloudscheduler.serviceAgent"

  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
  ]
}

resource "google_workflows_workflow" "scale_down" {
  name            = "${var.prefix}-${var.cluster_name}-scale-down-workflow"
  region          = var.region
  description     = "scale down workflow"
  service_account = var.sa_email
  source_contents = <<-EOF
  - fetch:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.fetch_function.https_trigger_url}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions_function.fetch_function.https_trigger_url}
      result: FetchResult
  - scale_down:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.scale_down_function.https_trigger_url}
          body: $${FetchResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions_function.scale_down_function.https_trigger_url}
      result: ScaleResult
  - terminate:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.terminate_function.https_trigger_url}
          body: $${ScaleResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions_function.terminate_function.https_trigger_url}
      result: TerminateResult
  - transient:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.transient_function.https_trigger_url}
          body: $${TerminateResult.body}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions_function.transient_function.https_trigger_url}
      result: TransientResult
  - returnOutput:
      return: $${TransientResult}
EOF

  depends_on = [google_project_service.workflows , google_cloudfunctions_function.scale_down_function]
}

#resource "google_cloud_scheduler_job" "scale_down_job" {
 # name        = "${var.prefix}-${var.cluster_name}-scale-down"
 # region      = var.region
  #description = "scale down job"
  #schedule    = "* * * * *"

  #http_target {
   # http_method = "POST"
    #uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.scale_down.id}/executions"
    #oauth_token {
     # service_account_email = var.sa_email
    #}
  #}
  #depends_on = [google_workflows_workflow.scale_down]
#}

resource "google_workflows_workflow" "scale_up" {
  name            = "${var.prefix}-${var.cluster_name}-scale-up-workflow"
  region          = var.region
  description     = "scale up workflow"
  service_account = var.sa_email
  source_contents = <<-EOF
  - scale_up:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.scale_up_function.https_trigger_url}
          auth:
            type: OIDC
            audience: ${google_cloudfunctions_function.scale_up_function.https_trigger_url}
      result: ScaleUpResult
  - returnOutput:
      return: $${ScaleUpResult}
EOF

  depends_on = [google_project_service.workflows, google_cloudfunctions_function.scale_up_function, google_cloudfunctions_function.deploy_function, google_cloudfunctions_function.clusterize_function, google_cloudfunctions_function.clusterize_finalization_function]
}

#resource "google_cloud_scheduler_job" "scale_up_job" {
 # name        = "${var.prefix}-${var.cluster_name}-scale-up"
  #region      = var.region
  #description = "scale up job"
  #schedule    = "* * * * *"

  #http_target {
   # http_method = "POST"
    #uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.scale_up.id}/executions"
    #oauth_token {
     # service_account_email = var.sa_email
    #}
  #}
  #depends_on = [google_workflows_workflow.scale_up]
#}
