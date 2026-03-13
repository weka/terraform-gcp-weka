# Cloud Functions Navigation

## Project Overview
GCP Cloud Functions module for deploying and managing Weka clusters on Google Cloud Platform via Terraform. Go 1.26 runtime. Part of `github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions`.

## Directory Structure

```
cloud-functions/
├── CLAUDE.md                 # This navigation file
├── main.go                   # HTTP router for all cloud functions (28KB)
├── cloud_functions_test.go   # Tests for cloud functions
├── go.mod / go.sum           # Go module definitions
├── common/                   # Shared utilities
├── functions/                # Individual cloud function implementations
│   ├── clusterize/          # Create and configure Weka cluster
│   ├── clusterize_finalization/
│   ├── deploy/              # Deploy Weka nodes
│   ├── fetch/               # Fetch cluster information
│   ├── gcp_functions_def/   # GCP function definitions
│   ├── join_finalization/   # Post-join operations
│   ├── report/              # Generate cluster reports
│   ├── resize/              # Resize cluster capacity
│   ├── scale_up/            # Add nodes to cluster
│   ├── scale_down/          # Remove nodes from cluster (via go-cloud-lib)
│   ├── status/              # Check cluster status
│   ├── terminate/           # Stop/terminate nodes
│   └── terminate_cluster/   # Full cluster teardown
```

## Key Files

### main.go (28KB)
- **Role**: HTTP entry point and router for all cloud functions
- **Structure**:
  - `respondWithErr()` - Error response formatting
  - `failedDecodingReqBody()` - Request parsing error handler
  - `Protocol` struct - Request protocol wrapper
  - Multiple HTTP handlers (one per function) - all registered in an HTTP router
- **Dependencies**: All functions packages + google.cloud-lib

### common/
- Shared utilities, constants, and helper functions used across functions
- Likely contains common data structures and validation logic

### functions/ (12 cloud functions)
Each function directory contains implementation for a specific operation:
- **clusterize**: Initialize Weka cluster from scratch
- **deploy**: Deploy Weka nodes/instances
- **scale_up**: Add nodes to running cluster
- **resize**: Modify cluster capacity parameters
- **fetch**: Query cluster information
- **status**: Report current cluster state
- **terminate**: Stop/terminate specific nodes
- **terminate_cluster**: Destroy entire cluster
- **report**: Generate cluster diagnostics/reports
- **join_finalization**: Post-join initialization steps
- **clusterize_finalization**: Post-clusterize setup steps
- **gcp_functions_def**: GCP function configuration definitions

## Dependencies
- **Google Cloud**: compute, secretmanager, storage, IAM APIs
- **Weka Libraries**: `github.com/weka/go-cloud-lib` (protocol, clusterize, scale_down)
- **Logging**: `github.com/rs/zerolog`
- **Utilities**: `github.com/lithammer/dedent`, Google API client libraries

## Runtime Info
- **Go Version**: 1.26.1
- **Target**: Google Cloud Functions (HTTP-triggered)
- **Branch**: update-runtime-to-go1.26

## Common Patterns
1. Each function receives HTTP request with JSON-encoded parameters
2. Functions decode request body, perform GCP operations, return JSON responses
3. Errors returned as JSON with descriptive messages and HTTP status codes
4. Logging via zerolog structured logging
5. Secrets accessed via Google Cloud Secret Manager
6. Storage via Google Cloud Storage buckets

## Tips for AI Assistance
- **Adding a function**: Create new directory in `functions/`, implement handler, import and register in `main.go`
- **Modifying routing**: Edit HTTP handler registrations in `main.go`
- **Cross-function logic**: Place in `common/` for reuse
- **Testing**: Use `cloud_functions_test.go` as reference
- **Dependencies**: Update `go.mod`, run `go mod tidy`

## Related Resources
- Parent module: `/Users/assafgiladi/projects/terraform-gcp-weka/`
- Go Cloud Library: `github.com/weka/go-cloud-lib` (clusterize, protocol, scale_down)
- GCP APIs: Google Cloud Compute, Secret Manager, Storage
