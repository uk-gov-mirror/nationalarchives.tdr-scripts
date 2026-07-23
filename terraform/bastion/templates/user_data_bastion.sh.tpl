#!/bin/bash
%{ if connect_to_database == "true" }
mkdir -p /home/ssm-user
amazon-linux-extras install -y postgresql14
yum install -y jq
cat <<\EOF >> /home/ssm-user/connect.sh
FILE=/home/ssm-user/eu-west-2-bundle.pem
if [ ! -f "$FILE" ]; then
wget https://truststore.pki.rds.amazonaws.com/eu-west-2/eu-west-2-bundle.pem
fi
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
aws sts assume-role --role-arn arn:aws:iam::${account_number}:role/TDRBastionAccessDbRole${environment} --role-session-name bastionrolesession > creds
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' creds)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' creds)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' creds)
export RDSHOST="${db_host}"
export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port 5432 --region eu-west-2 --username bastion_user )"
psql "host=$RDSHOST port=5432 sslmode=verify-full sslrootcert=eu-west-2-bundle.pem dbname=consignmentapi user=bastion_user password=$PGPASSWORD"
EOF
chmod +x /home/ssm-user/connect.sh
chown -R 1001:1001 /home/ssm-user
history -c
%{ endif }

%{ if connect_to_export_efs == "true" }
yum install -y amazon-efs-utils
mkdir -p /home/ssm-user/export
chown -R 1001:1001 /home/ssm-user/export
mount -t efs -o iam,tls ${export_file_system_id} /home/ssm-user/export/
%{ endif }
