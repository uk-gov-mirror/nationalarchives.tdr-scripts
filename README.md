## TDR Scripts

This is a repository for scripts which are run infrequently and don't belong with other projects.
Terraform scripts are put into separate directories inside the terraform directories. Other non-terraform scripts are kept in their own directory at the root of the project.

### Bastion host creation script
This is a terraform script to create a bastion host.
There are three variables which can be set which control what the bastion can connect to.
* connect_to_database - Postgres client is installed and a file is created at /home/ssm-user/connect.sh. Running this script will connect you to the database in read only mode. 
* connect_to_export_efs - The export efs volume is mounted in read only mode in /home/ssm-user/efs/export

To connect to the host
* Log into the required TDR AWS account (intg, staging, prod)
* Click on EC2 (search for it, if it isn't in your 'Recently visited services' list)
* Click on [Instances (running)][ec2-instances-running].
* Click the checkbox next to the instance called bastion-ec2-instance-{stage_name}
* Click Connect
* Choose the Session Manager tab and click Connect

To connect to the database
* Connect to the host.
* Go to the /home/ssm-user directory (using `cd /home/ssm-user`)
* Run the `./connect.sh` script

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

[ec2-instances-running]: https://eu-west-2.console.aws.amazon.com/ec2/v2/home?region=eu-west-2#Instances:instanceState=running
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

### Generate Release Versions

This is a python script which is run on Jenkins. It generates an html file and a Slack message which show which repositories have out of date versions deployed to the staging and production environments. It does this by looking at the release tags on each of the `release-$environment` branches.

#### Running on Jenkins
The job to run the script is [here](https://jenkins.tdr-management.nationalarchives.gov.uk/job/Github%20release%20summary/) and when the job is run, it generates [an html file](https://jenkins.tdr-management.nationalarchives.gov.uk/job/Github%20release%20summary/Release_20Version_20Report/) like this one. 

#### Running locally
There is only one dependency outside the standard python library which will need to be installed to run this locally. You can install this system wide by running `pip install quik` but it's better to use a virtual environment.
You will need to use Python 3. 
For the Slack url environment variable, you can set it to a real Slack webhook url if you want to send messages to Slack or leave it unset and it will print the Slack message json to console.

```bash
cd release-versions
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export GITHUB_API_TOKEN=valid_api_token
python generate_release_file.py
```

This will print the slack json to the console and generate an output.html file which you can view in a browser. The css comes from Jenkins and gives a 403 error when you try to load it from a local file. If you want to view it with the css, you can replace the `href` in the `<link>` tag in `output.html` to the bootstrap css file `https://cdn.jsdelivr.net/npm/bootstrap@5.0.1/dist/css/bootstrap.min.css`

#### Cleaning up
```bash
deactivate
rm -r venv
```

### Judgment Report Generator
This will generate a csv report of all judgment consignments for the given environment.

#### Setting up the environment
```bash
cd judgment-report
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### Running the report
This report needs AWS credentials with SSM access to work.
These can be set with environment variables, in `~/.aws/credentials` or using sso profiles.

Once these are set you can run: 

`python report.py environment_name email_address_1 email_address_2`

It will create a file called `report.csv` in the same directory and will send a slack message with the file to all of the email addresses provided as arguments. You can provide zero or more email addresses.

#### Cleaning up
```bash
deactivate
rm -r venv
```
