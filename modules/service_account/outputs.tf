output "outputs-service-account-email" {
  value = google_service_account.sa.email
}

output "output-sa-key" {
  value = base64decode(google_service_account_key.sa-key.private_key)
}