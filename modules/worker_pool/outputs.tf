output "worker_pool_id" {
  value       = var.worker_pool_id == "" ? google_cloudbuild_worker_pool.pool.id : var.worker_pool_id
  description = "Worker pool id"
}
