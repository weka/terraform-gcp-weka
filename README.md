### Prerequisites:
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)

### General info
This Terraform is made for weka deployment on GCP including auto-scaling.
This Terraform can use existing network (vpcs/subnets etc.) or create new network.<br>

We supply 4 modules:
1. [**setup_network**](modules/setup_network): includes vpcs, subnets, peering, firewall and health check.
2. [**service_account**](modules/service_account): includes the service account that will be used for deployment with all necessary permissions.
3. [**deploy_weka**](modules/deploy_weka): includes the actual weka deployment, instance template, cloud functions, workflows, job schedulers, secret manger, buckets, health check.
4. [**shared_vpcs**(*optional*)](modules/shared_vpcs): includes vpc sharing between the weka deployment network and another notwork.

We support deploying weka on public and private network.
* public network deployment:
  * requires passing `get.weka.io` token to terraform.
* private network deployment:
  - requires weka installation tar file in some GCP bucket
  - utils folder contains helper script [`utils/sync_weka_tar.sh`](utils/sync_weka_tar.sh)

You can find several usage examples under [**examples**](examples) in this repo.

After applying this Terraform, you will get 2 workflows that run every minute and will be used for scale up and down.
Automatically a new cluster will be created in a few minutes according to the cluster size you set.
When an instance is added to the instance group the Terraform created, it indicates this instance is now a part
of the cluster.

In order to change the cluster size (up or down) you can use a special cloud function we made called `resize`.
Example: 
```
curl -m 70 -X POST RESIZE_CLOUD_FUNCTION_URL -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json" -d '{"value":6}'
```

### Weka cluster deployment:
- **Authentication**: `gcloud auth application-default login`
- **Deployment**:<br>
  This repository provides TF modules and examples,
  actual usage assumes use of modules in new or existing project,
  similar way as shown in examples. Examples include examples for public and private networks  
  **Important to note:**
  - Public deployment requires to pass `get_weka_io_token` in order to download release from public get.weka.io service
  - Private deployment requires to upload weka software tarfile into GSC bucket, so instances will be able to download software from it
  - Private network deployment/examples must come with:
    - `private_network = true` on `setup_network` and `deploy_weka` modules level, this adapts various configuration for private networks
  - In addition, following params are optional for private networking, depending on how network topology looks like:
    - `install_url` on `deploy_weka` module level, this allows to download weka from local bucket and not public get.weka.io service
    - `yum_repo_server` - Centos7 only, instructions to auto-configure yum to use alternative repository. Distributive repository required in order to download kernel headers and additional build software
    - `weka_image_id` - custom image to use
