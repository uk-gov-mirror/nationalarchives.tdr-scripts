import os
import sys
from datetime import datetime
import boto3

account_number = sys.argv[1]
stage = sys.argv[2]
instance_name = sys.argv[3]
age = sys.argv[4]


client = boto3.client("ec2")

resp = client.describe_instances(Filters=[{'Name': 'tag:Name', 'Values': [instance_name]}])

reservations = resp["Reservations"]
with open(os.environ['GITHUB_OUTPUT'], 'a') as fh:
    if len(reservations) > 0:
        instances = reservations[0]["Instances"][0]
        launch_time = reservations[0]["Instances"][0]["LaunchTime"]
        now = datetime.now(launch_time.tzinfo)
        print(f'bastion-age={(now - launch_time).days > int(age)}', file=fh)
    else:
        print("bastion-age=False", file=fh)
