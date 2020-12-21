# Run an ECR repository in the Sandbox

This creates a container registry that can be used to test image scanning
without spamming the Slack channel and email address that receive image scan
alerts from containers in the Management account.

Get AWS credentials for the **Sandbox environment** and run:

```
terraform init
terraform apply
```

Visit the [ECR service] in the Sandbox, find the repository and click "View
push commands" to get the Docker commands for logging into ECR and pushing
images.

Once you have finished testing, tear down the repository and delete the images:

```
terraform destroy
```

[ECR service]: https://eu-west-2.console.aws.amazon.com/ecr/repositories?region=eu-west-2
