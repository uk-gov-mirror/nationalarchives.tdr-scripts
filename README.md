## TDR Scripts

This is a repository for scripts which are run infrequently and don't belong with other projects. 
Terraform scripts are put into separate directories inside the terraform directories. Other non-terraform scripts can be organised as and when we need them.

### Bastion host creation script
This is a terraform script to create a bastion host which can be used to connect to the database. 
Postgres client is installed when the instance is created and a .pgpass file is created to store the login credentials on the host. The host disk drive is encrypted.
The `terraform/bastion` directory contains a Jenkinsfile for creating the bastion instance through Jenkins. 