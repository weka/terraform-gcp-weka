### Prerequisites:
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)

### General info
This Terraform is made for weka deployment on GCP including auto-scaling.
This Terraform can use existing network (vpcs/subnets etc.) or create new network.<br>

We supply 5 modules:
1. [**setup_network**](modules/setup_network): includes vpcs, subnets, peering, firewall and health check.
2. [**service_account**](modules/service_account): includes the service account that will be used for deployment with all necessary permissions.
3. [**deploy_weka**](modules/deploy_weka): includes the actual weka deployment, instance template, cloud functions, workflows, job schedulers, secret manger, buckets, health check.
4. [**shared_vpcs**(*optional*)](modules/shared_vpcs): includes vpc sharing between the weka deployment network and another notwork.
5. [**local_centos_repo**(*optional*)](modules/local_centos_repo): includes setup of private yum repo.

We support deploying weka on public and private network.
* public network deployment:
  * requires passing `get.weka.io` token to terraform.
* private network deployment:
  - requires weka installation tar file in some GCP bucket.
  - yum repo server connectivity.

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
- **State**: for our state we use a bucket named `weka-infra-backend` ( - see `backend/`) you can apply it (using your relevant variables). 
In case you want different bucket name, you will need to change it in `backend.tf` as well.
- **Deployment**:<br>
  Update the variables in `tf-deploy-all.tfvars` according to your env.<br>
  You can see the full variables' description in the modules links above.
  * **Public deployment**:
    * 
      ```
      TF_VAR_get_weka_io_token=$TOKEN TF_VAR_weka_username=$USERNAME terraform apply -auto-approve -var-file tf-deploy-all.tfvars
      ```
  * **Private deployment**:
    * Update in `tf-deploy-all.tfvars` the following values:
      * `private_network = true`
      * `install_url = YOUR_TAR_OBJECT_URL`
      * `yum_repo_server = YOUR_YUM_REPO_URL`
      * *Optional in case you wish to use our option for private yum repo server:* `create_local_repo = true`
    *
    ```
    TF_VAR_weka_username=$USERNAME terraform apply -auto-approve -var-file tf-deploy-all.tfvars
    ```

