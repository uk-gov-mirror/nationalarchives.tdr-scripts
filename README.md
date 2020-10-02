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
* `cat /home/ssm-user/.pgpass` This will give you the connection information you need.
* `psql -h {host_name_from_file} -U {username_from_file} -d consignmentapi` There's no need to input the password.

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

* Run the ssh tunnel
`ssh ec2-user@instance_id -N -L 65432:db_host_name:5432`

* Connect locally through port 65432 or whichever port you choose.

[ec2-instances]: https://eu-west-2.console.aws.amazon.com/ec2/v2/home?region=eu-west-2#Instances
[ssh-key-pair]: https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
[bastion-jenkins-job]: https://jenkins.tdr-management.nationalarchives.gov.uk/job/TDR%20Bastion%20Deploy/
