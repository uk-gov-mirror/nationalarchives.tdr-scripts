{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": [
        "arn:aws:ssm:eu-west-2:${account_id}:document/deleteuser"
      ]
    }
  ]
}