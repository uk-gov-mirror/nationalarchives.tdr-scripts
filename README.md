## TDR Scripts

This is a repository for scripts which are run infrequently and don't belong with other projects. 
Terraform scripts are put into separate directories inside the terraform directories. Other non-terraform scripts can be organised as and when we need them.

### Bastion host creation script
This is a terraform script to create a bastion host which can be used to connect to the database. 
Postgres client is installed when the instance is created and a .pgpass file is created to store the login credentials on the host. The host disk drive is encrypted.
The `terraform/bastion` directory contains a Jenkinsfile for creating the bastion instance through Jenkins.

To connect to the host
* Log into AWS and go to EC2 instances.
* Click the checkbox next to the instance called bastion-ec2-instance-{stage_name}
* Click Connect
* Choose the Session Manager radio button and click Connect

To connect to the database
* `cat /home/ssm-user/.pgpass` This will give you the connection information you need.
* `psql -h {host_name_from_file} -U {username_from_file} -d consignmentapi` There's no need to input the password. 