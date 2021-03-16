{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${account_id}:role/BastionEC2Role${environment}"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}