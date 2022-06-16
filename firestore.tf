resource "google_project_service" "firestore" {
  project = var.project
  service = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_firestore_document" "firestore_doc" {
  project     = var.project
  collection  = "${var.prefix}-collection"
  document_id = "${var.prefix}-document"
  fields      = "{\"counter\":{\"integerValue\":\"${var.firestore_count}\"}}"

  depends_on = [google_project_service.firestore]
}