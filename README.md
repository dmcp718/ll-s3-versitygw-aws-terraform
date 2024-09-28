## Packer and Terraform examples for deploying S3 API gateway in AWS
Example scripts to facilitate deploying an S3 API gateway for a LL Filespace. The end result is a public S3 API endpoint (e.g., https://s3.example.net) that presents the top-level folders of a LL Filespace as S3 buckets available for a full range of S3 API calls, LIST | GET | PUT | DELETE etc.

## Prerequisites

Dependencies for deployment:

1. AWS account with IAM credentials set as environmental variables on the system running the scripts.
2. Registered domain in [AWS Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#register_new_console)
3. Packer installed: [packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)
4. Terraform installed: [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
5. macOS or Linux system to download source files and run scripts and commands

<!-- OVERVIEW -->
### Overview
This template utilizes Packer to create a custom AMI with all software dependencies installed and a systemd service configured for the chosen LucidLink Filespace. After setting various input variables, Terraform is used to deploy the integrated services in an AWS VPC.

<!-- INSTALLATION -->
### Installation and execution steps

1. Clone the repo
   ```sh
   git clone https://github.com/dmcp718/ll-s3-gw-aws-terraform.git
   ```
2. The repo tree structure:
   ```sh
   ├── LICENSE
   ├── README.md
   ├── packer
   │   ├── images
   │   │   ├── ll-s3-gw.pkr.hcl
   │   │   └── variables.auto.pkrvars.hcl
   │   └── script
   │       ├── config_vars.txt
   │       └── ll-s3-gw_ami_build_args.sh
   └── terraform
      ├── asg.tf
      ├── main.tf
      ├── resources
      │   └── bootstrap.sh.tpl
      ├── route53.tf
      ├── variables.tf
      └── vpc.tf
   ```
3. Edit the packer/script/config_vars.text file:
   ```
   FILESPACE1="filespace.domain"
   FSUSER1="username"
   LLPASSWD1="password"
   ROOTPOINT1="/"
   VGWROOTACCESSKEY="vgw-root-user"
   VGWROOTSECRETKEY="vgw-root-secret"
   FQDOMAIN="example.net"
   ```
4. Run the ll-s3-gw_ami_build_args.sh script:
   ```sh
   cd ll-s3-gw-aws-terraform/packer/script
   sudo chmod +x ll-s3-gw_ami_build_args.sh
   ./ll-s3-gw_ami_build_args.sh
   ```
5. Edit packer variables:
   ```sh
   cd ../images
   nano variables.auto.pkrvars.hcl
   ```
   ```sh
   region = "us-east-2"

   instance_type = "c5.2xlarge"

   filespace = "filespace-name"
   ```
6. Run packer build:
   ```sh
   packer build ll-s3-gw.pkr.hcl
   ```
7. Copy the resulting ami_id value from the packer build, either from packer build terminal output or the post-processor script that generates the **ami_id.txt** file inside the /packer/images directory.
   ```sh
   cat ami_id.txt
   ami-099b66666eb33333d
   ```
8. Change to terraform directory and update the `ami_id` value in the **variable.tf** file along with the rest of the variable values for the desired deployment. Especially important are the `domain_name` that has been pre-registered in **Route 53** and the derivative `subdomain_name` value. The default value for `instance_type` of `c5.2xlarge` is a good starting point for a small to medium size Filespace and allocates 8 vCPUs and 16GB of memory and up to 10Gbps of network bandwidth. High volume and high throughput workflows may require larger instance types.
   ```sh
   cd ../../terraform
   nano variables.tf
   ```
   ```sh
   variable "instance_name" {
   description = "Value of the Name tag for the EC2 instance"
   type        = string
   default     = "ll-s3-gw"
   }

   variable "instance_type" {
   description = "Value of the EC2 instance type"
   type        = string
   default     = "c5.2xlarge"
   }

   variable "vpc_cidr" {
   type    = string
   default = "10.10.10.0/24"
   }

   variable "domain_name" {
   type    = string
   default = "example.net"
   }

   variable "subdomain_name" {
   type    = string
   default = "s3.example.net"
   }

   variable "ami_id" {
   type    = string
   default = "ami-099b66666eb33333d"
   }   
   ```
9. Run ``terraform apply``:
   ```sh
   terraform init && terraform apply
   ```
10. Run ``terraform destroy`` to stop and delete all services:
    ```sh
    terraform destroy
    ```
> [!NOTE]
> S3 clients can access the gateway at the FQDOMAIN set during Packer AMI creation  
> ``https://s3.<FQDOMAIN>``  
> over standard TLS/SSL port 443 with root access key and secret key credentials.  

## License
This project is licensed under the *MIT License* - see LICENSE.md file for details

## Acknowledgements
This project utilizes the versitygw software from Versity Software, Inc.
https://github.com/versity/versitygw

Minio Sidekick load balancer software is also deployed:  
docker.io/minio/minio/sidekick  
https://hub.docker.com/r/minio/sidekick