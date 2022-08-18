remote_state {
  backend  = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "tf-vars-infra-backend"
    prefix = "state"
  }
}