resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services=false
}


resource "google_workflows_workflow" "workflows" {
  name            = "${var.prefix}-${var.cluster_name}-scale-down-workflow"
  region          = var.region
  description     = "Fetch workflow"
  service_account = var.sa_email
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
  - terminate:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.terminate_function.https_trigger_url}
          body: $${ScaleResult.body}
      result: TerminateResult
  - transient:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.transient_function.https_trigger_url}
          body: $${TerminateResult.body}
      result: TransientResult
  - returnOutput:
      return: $${TransientResult}
EOF

  depends_on = [google_project_service.workflows, google_cloudfunctions_function.fetch_function , google_cloudfunctions_function.scale_down_function]
}