#!/bin/sh

endpoint='http://169.254.169.254/latest/meta-data/iam/security-credentials/'

instance_profile=`curl $endpoint`

aws_access_key_id=`curl 
${endpoint}${instance_profile} | grep AccessKeyId | cut -d':' -f2 | sed 's/[^0-9A-Z]*//g'`

aws_secret_access_key=`curl 
${endpoint}${instance_profile} | grep SecretAccessKey | cut -d':' -f2 | sed 's/[^0-9A-Za-z/+=]*//g'`

#token=`curl -s 
#${endpoint}${instance_profile} | sed -n '/Token/{p;}' | cut -f4 -d'"'`

export AWS_ACCESS_KEY=aws_access_key_id
export AWS_SECRET_KEY=aws_secret_access_key

#bucket="suse1-ecom-mt-economist-storage"
#file="economist/pub/nodes/21700419.json"
#date="`date +'%a, %d %b %Y %H:%M:%S %z'`"
#resource="/${bucket}/${file}"
#signature_string="GET\n\n\n${date}\nx-amz-security-token:${token}\n/${resource}"
#signature=`/bin/echo -en "${signature_string}" | openssl sha1 -hmac ${aws_secret_access_key} -binary | base64`
#authorization="AWS ${aws_access_key_id}:${signature}"

#curl -s -H "Date: ${date}" -H "X-AMZ-Security-Token: ${token}" -H "Authorization: ${authorization}" "https://s3.amazonaws.com/${resource}" -o "output.txt"