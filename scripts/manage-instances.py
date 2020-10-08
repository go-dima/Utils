#!/usr/bin/python3

import boto3
import os
from collections import ChainMap
import argparse
from AwsRegionsDictionary.RegionsMapping import mapToRegionKey # https://github.com/go-dima/aws-regions-dictionary


def get_instance_ids(instances):
    return ec2client.instances.filter(InstanceIds=[instance['id'] for instance in instances])


def power_on(instances):
    if len(instances) == 0:
        print(f"Nothing to power on.")
    else:
        print(f"Powering on {len(instances)} instances: {[instance['name'] for instance in instances]}")
        if args.dry_run:
            dry_power_on(instances)
        else:
            run_power_on(instances)


def extract_instance_data(instance):
    return {
        'id': instance.id,
        'name': extract_name_tag(instance.tags),
        'tags': flatten(instance.tags),
        'ip': instance.public_ip_address,
        'state': instance.state['Name']
    }


def extract_name_tag(tags):
    if tags is None:
        return "UNKNOWN NAME"
    return [item['Value'] for item in tags if item['Key'] == 'Name'][0]


def flatten(tags):
    flat = {}
    if tags is not None:
        for item in tags:
            flat[item['Key']] = item['Value']
    return flat


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--region', action='store', default='frankfurt', dest='region', help='Region to describe')
    parser.add_argument('-n', '--name', action='store', dest='machineName', help='Machine Tag:Name')
    parser.add_argument('-a', '--async', action='store_true', dest='run_async', default=False, help='Async mode')
    parser.add_argument('-l', '--list', action='store_true', default=False, help='List matching machines')
    parser.add_argument('-d', '--dry-run', action='store_true', dest='dry_run', default=False, help='Perform dry run')
    parser.add_argument('-p', '--profile', action='store', default='default', help='Profile name to use')
    return parser.parse_args()


def add_suffix(instances):
    return "s" if len(instances) > 1 else ""


def run_power_on(instances):
    return get_instance_ids(instances).start()


def dry_power_on(instances):
    print(f"Dry run: Start {len(instances)} instance{add_suffix(instances)}")


def get_instances_data():
    return [extract_instance_data(instance) for instance in ec2client.instances.filter(Filters=filters)]


ec2client = None
filters = None
args = None

if __name__ == '__main__':
    args = parse_args()
    session = boto3.session.Session(profile_name=args.profile)
    ec2client = session.resource('ec2', region_name=mapToRegionKey(args.region))
    filters = [dict(Name='tag:Name', Values=[f"*{args.machineName}*"])]
    instancesData = get_instances_data()
    for instanceData in instancesData:
        print(f"{instanceData['name']}: {instanceData['ip']} - {instanceData['state']}")

    if len(instancesData) == 0:
        print("No instances found.")
        exit(0)

    if args.list:
        exit(0)

    power_on(instancesData)

    if args.run_async or len(instancesData) != 1:
        exit(0)

    while get_instances_data()[0]['state'] != 'running':
        pass
    print(get_instances_data()[0]['ip'])
