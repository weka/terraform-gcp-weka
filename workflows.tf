resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "workflows_api" {
  service = "workflowexecutions.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services=false
}


data "google_compute_default_service_account" "default" {
}

resource "google_workflows_workflow" "workflows" {
  name            = "${var.prefix}-workflow-fetch"
  region          = var.region
  description     = "Fetch workflow"
  service_account = data.google_compute_default_service_account.default.id
  source_contents = <<-EOF
  - fetch:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.fetch_function.https_trigger_url}
      result: FetchResult
  - scale_down:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.scale_down_function.https_trigger_url}
          body: $${FetchResult.body}
      result: ScaleResult
  - returnOutput:
      return: $${ScaleResult}
EOF

  depends_on = [google_project_service.workflows]
}