output "service_account_email" {
  value = google_service_account.sa.email
  description = "Service account email"
}
