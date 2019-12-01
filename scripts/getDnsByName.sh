#!/bin/bash -e

region=$1
name=$2

getDNS() {
  aws ec2 describe-instances --region ${region} --filters Name=tag:Name,Values=${name} | grep -i PublicDnsName | head -1 | awk '{ print $2 }' | tr -d [\"] | tr -d [,]
}

echo Filtering by: ${name} >&2
dnsName=$(getDNS)
echo ${dnsName}
