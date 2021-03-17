## TDR Scripts

This is a repository for scripts which are run infrequently and don't belong with other projects.
Terraform scripts are put into separate directories inside the terraform directories. Other non-terraform scripts can be organised as and when we need them.

### Bastion host creation script
This is a terraform script to create a bastion host which can be used to connect to the database.
Postgres client is installed when the instance is created and a .pgpass file is created to store the login credentials on the host. The host disk drive is encrypted.
The `terraform/bastion` directory contains a Jenkinsfile for creating the bastion instance through Jenkins.

To connect to the host
* Log into the required TDR AWS account (intg, staging, prod) and go to [EC2 instances][ec2-instances].
* Click the checkbox next to the instance called bastion-ec2-instance-{stage_name}
* Click Connect
* Choose the Session Manager radio button and click Connect

To connect to the database
* Connect to the host.
* Go to the /home/ssm-user directory
* Run the `connect.sh` script

To setup an ssh tunnel
* Create an [ssh key pair][ssh-key-pair]
* Create the bastion instance through [Jenkins][bastion-jenkins-job], adding your public key to the job.
* Add this to your ssh config. If you're not using aws cli v2 and sso then you don't need `--profile integration`
```
# SSH over Session Manager
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --profile integration --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```
* Get the instance id from the instances page in the console or by running
`aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=bastion-ec2-instance-intg`
  
* Get the database endpoint. There are three ways:
  
  You can get this from the AWS console by going to RDS, click DB Instances, choose the reader instance from the consignment api database and copy the endpoint.
  
  You can call `aws rds describe-db-instances` and look for a field called `Address` for the consignment api.

  You can open the `/home/ssm-user/connech.sh` script on the bastion host and the endpoint is in there assigned to the RDSHOST variable.
* Run the ssh tunnel

`ssh ec2-user@instance_id -N -L 65432:db_host_name:5432`
  
* Get the cluster endpoint. There are two ways:
  Select the cluster in the RDS Databases page in the console  
  Run `aws rds describe-db-cluster-endpoints --profile integration | jq '.DBClusterEndpoints[] | select(.EndpointType == "READER") | .Endpoint'
  ` and select the endpoint for the consginment API. 
* Update your hosts file. In *nix systems, this is in `/etc/hosts`, on Windows, it is in `C:\Windows\System32\drivers\etc\hosts` You will need to add an entry like
  
`127.0.0.1    cluster_endpoint `
* Get the password for the database 

`aws rds generate-db-auth-token --profile integration --hostname $RDSHOST --port 5432 --region eu-west-2 --username bastion_user`

* Download the rds certificate from https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem

* Connect using the password and cluster endpoint

`psql  "host=cluster_endpoint port=65432 sslmode=verify-full sslrootcert=/location/of/rds-combined-ca-bundle.pem dbname=consignmentapi user=bastion_user password=generated_password"`

[ec2-instances]: https://eu-west-2.console.aws.amazon.com/ec2/v2/home?region=eu-west-2#Instances
[ssh-key-pair]: https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
[bastion-jenkins-job]: https://jenkins.tdr-management.nationalarchives.gov.uk/job/TDR%20Bastion%20Deploy/

### Keycloak Sandbox

Terraform script for creating a temporary Keycloak instance in the Sandbox
environment. This instance does not have all of the security protections used
in the integration/staging/production version of Keycloak, so it should only be
used for testing new Keycloak configuration.

See the [Keycloak Sandbox Readme](keycloak-sandbox) for setup instructions.

[keycloak-sandbox]: terraform/keycloak-sandbox/README.md

### ECR Sandbox

Terraform script for creating a temporary Elastic Container Registry with image
scanning in the Sandbox account. This is useful for testing the image scanning
results of Docker image upgrades.

See the [ECR Sandbox Readme](ecr-sandbox) for setup instructions.

[ecr-sandbox]: terraform/ecr-sandbox/README.md
