resource "google_project_service" "workflows" {
  service                    = "workflows.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

data "google_project" "project" {
}

resource "google_project_iam_binding" "cloudscheduler_binding" {
  count   = var.create_cloudscheduler_sa ? 1 : 0
  project = var.project_id
  role    = "roles/cloudscheduler.jobRunner"
  members = [
    "serviceAccount:service-${local.deployment_project_number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
  ]
}

resource "google_workflows_workflow" "scale_down" {
  name            = "${var.prefix}-${var.cluster_name}-scale-down-workflow"
  project         = var.project_id
  region          = lookup(var.workflow_map_region, var.region, var.region)
  description     = "scale down workflow"
  service_account = local.sa_email
  source_contents = <<-EOF
  - fetch:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri}
          query:
            action: fetch
          auth:
            type: OIDC
      result: FetchResult
  - scale_down:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.scale_down_function.service_config[0].uri}
          body: $${FetchResult.body}
          auth:
            type: OIDC
      result: ScaleResult
  - terminate:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri}
          query:
            action: terminate
          body: $${ScaleResult.body}
          auth:
            type: OIDC
      result: TerminateResult
  - transient:
      call: http.post
      args:
          url: ${google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri}
          query:
            action: transient
          body: $${TerminateResult.body}
          auth:
            type: OIDC
      result: TransientResult
  - returnOutput:
      return: $${TransientResult}
EOF

  depends_on = [google_project_service.workflows, google_cloudfunctions2_function.scale_down_function, google_cloudfunctions2_function.cloud_internal_function]
}

resource "google_pubsub_topic" "scale_down_trigger_topic" {
  name = "${var.prefix}-${var.cluster_name}-scale-down"
}

# needed for google_eventarc_trigger
resource "google_project_service" "eventarc_api" {
  service                    = "eventarc.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_eventarc_trigger" "scale_down_trigger" {
  name     = "${var.prefix}-${var.cluster_name}-scale-down"
  location = var.region
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    workflow = google_workflows_workflow.scale_down.name
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.scale_down_trigger_topic.name
    }
  }

  service_account = local.sa_email
  depends_on      = [google_workflows_workflow.scale_down, google_pubsub_topic.scale_down_trigger_topic]
}

resource "google_cloud_scheduler_job" "scale_down_job" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  description = "scale down job"
  schedule    = "* * * * *"
  region      = lookup(var.cloud_scheduler_region_map, var.region, var.region)

  pubsub_target {
    topic_name = google_pubsub_topic.scale_down_trigger_topic.id
    data       = base64encode("placeholder")
  }
  depends_on = [google_eventarc_trigger.scale_down_trigger]
}


resource "google_workflows_workflow" "scale_up" {
  name            = "${var.prefix}-${var.cluster_name}-scale-up-workflow"
  region          = lookup(var.workflow_map_region, var.region, var.region)
  description     = "scale up workflow"
  service_account = local.sa_email
  source_contents = <<-EOF
  - scale_up:
      call: http.get
      args:
          url: ${google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri}
          query:
            action: scale_up
          auth:
            type: OIDC
      result: ScaleUpResult
  - returnOutput:
      return: $${ScaleUpResult}
EOF

  depends_on = [google_project_service.workflows, google_cloudfunctions2_function.cloud_internal_function]
}

resource "google_pubsub_topic" "scale_up_trigger_topic" {
  name = "${var.prefix}-${var.cluster_name}-scale-up"
}

resource "google_eventarc_trigger" "scale_up_trigger" {
  name     = "${var.prefix}-${var.cluster_name}-scale-up"
  location = var.region
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    workflow = google_workflows_workflow.scale_up.name
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.scale_up_trigger_topic.name
    }
  }

  service_account = local.sa_email

  depends_on = [google_workflows_workflow.scale_up, google_pubsub_topic.scale_up_trigger_topic]
}

resource "google_cloud_scheduler_job" "scale_up_job" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up"
  description = "scale up job"
  schedule    = "* * * * *"
  region      = lookup(var.cloud_scheduler_region_map, var.region, var.region)

  pubsub_target {
    topic_name = google_pubsub_topic.scale_up_trigger_topic.id
    data       = base64encode("placeholder")
  }
  depends_on = [google_eventarc_trigger.scale_up_trigger]
}
