resource "google_project_service" "workflows" {
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
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
          body:
              project: ${var.project}
              zone: ${var.zone}
              instance_group: weka-igm
              cluster_name: ${var.cluster_name}
      result: FetchResult
  - scale:
      call: http.post
      args:
          url: ${google_cloudfunctions_function.scale_function.https_trigger_url}
          body: $${FetchResult.body}
      result: ScaleResult
  - returnOutput:
      return: $${ScaleResult}
EOF

  depends_on = [google_project_service.workflows]
}