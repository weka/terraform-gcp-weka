output "worker_pool_id" {
  value       = var.worker_pool_id == "" ? google_cloudbuild_worker_pool.worker_pool[0].id : var.worker_pool_id
  description = "Worker pool id"
}
