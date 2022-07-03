resource "google_project_service" "firestore" {
  project = var.project
  service = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_firestore_document" "firestore_doc" {
  project     = var.project
  collection  = "${var.prefix}-${var.cluster_name}-collection"
  document_id = "${var.prefix}-${var.cluster_name}-document"
  fields      = "{\"instances\":{\"arrayValue\":{}}, \"initial_size\":{\"integerValue\":\"${var.cluster_size}\"}, \"desired_size\":{\"integerValue\":\"${var.cluster_size}\"}}"
  depends_on = [google_project_service.firestore]

  lifecycle {
    ignore_changes = [fields]
  }
}