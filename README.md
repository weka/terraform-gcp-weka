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
Similar command   

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

### Notes
- You have 2 ways to know that your weka cluster is ready:
  * all vms where added to the instance group 
  * run resize curl command with target size equal to initial size.  Until cluster is fully formed, it will return error indication that cluster is not ready yet
  * future versions will include status api with more information
- In case you deployed a public cluster you can't change it to private and vise versa
- You can't change vpc or number of nics after deployment
- In order to see the input and output of each step in the scale down workflow, you can go to `EDIT`, then you can edit
the scheduler, go to `Configure the execution` and choose for log level `All calls` . (We can't set this option via TF)
- In order to run `terraform destroy`, you have to kill all the vms that were created by `scale_up` workflow. We added
a script on the instance group destroy that will delete all vms. This script will kill all the instances that are attached to
the instance group. In case something bad happened and there are instances that are not attached to the instance group,
you will need to remove them manually.
- When destroying cluster using `terraform destroy` we will remove only instances that belong to instance group.   
In case destroy runs during scale up, some instances might not yet be added to instance group and deletion of VPC and other shared resources will be rejected by GCP.
Please ensure to run destroy in a stable state of cluster  
Example of such case:
```
│ Error: Error when reading or editing Subnetwork: googleapi: Error 400: The subnetwork resource 'projects/wekaio-rnd/regions/europe-west1/subnetworks/weka-subnet-1' is already being used by 'projects/wekaio-rnd/zones/europe-west1-b/instances/weka-poc-vm-98b6bab9-6fc4-4e5f-8902-1c5971521099', resourceInUseByAnotherResource
```
In this case, ensure that you have no instances in VPC and re-run `terrafor destroy` again
- Right now only two configurations are supported:
  - nics_number == 4 with instance type c2-standard-8
  - nics_number == 7 with instance type c2-standard-16
