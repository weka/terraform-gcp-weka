output "output-resize-cloud-functions" {
  value = google_cloudfunctions_function.resize_function.https_trigger_url
}

output "output-lb-dns" {
  value = google_dns_record_set.record-a.name
}