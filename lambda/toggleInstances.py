#!/usr/bin/python3

import boto3
import os
from collections import ChainMap

states = {'on': 'stopped', 'off': 'running'}
exec_data = {
    'on': {
        'filter': lambda i, t, v: marked(t, i['tags'], v),
        # 'action': lambda ec2client, instances: print('start', len(instances)),
        'action': lambda ec2client, instances: getInstanceIds(ec2client, instances).start(),
        'event_tags': 'applyTags',
        'filter_value': 'true'
    },
    'off': {
        'filter': lambda i, t, v: not marked(t, i['tags'], v),
        # 'action': lambda ec2client, instances: print('stop', len(instances)),
        'action': lambda ec2client, instances: getInstanceIds(ec2client, instances).stop(),
        'event_tags': 'ignoredTags',
        'filter_value': 'false'
    },
}


def lambda_handler(event, context):
    print(event)
    regionsResponse = boto3.client('ec2').describe_regions()
    for region in regionsResponse['Regions']:
        ec2client = boto3.resource('ec2', region_name=region['RegionName'])
        # filter instances to retrieve all relevant EC2 instances.
        instancesToToggle = filterInstances(ec2client, event['action'])

        print(f"Region {region}: ", end='')
        perform_action(ec2client, instancesToToggle, event)


def getInstanceIds(ec2client, instances):
    return ec2client.instances.filter(InstanceIds=[instance['id'] for instance in instances])


def filterInstances(ec2client, action):
    filters = [{'Name': 'instance-state-name', 'Values': [states[action]]}]  # running/stopped
    return [extract_instance_data(instance) for instance in ec2client.instances.filter(Filters=filters)]


def perform_action(ec2client, instances, event):
    action = event['action']
    action_data = exec_data[action]
    filtered = filter_by_tags(instances, event[action_data['event_tags']],
                              action_data['filter_value'], action_data['filter'])
    if len(filtered) == 0:
        print(f"Nothing to power {action}.")
    else:
        print(f"Powering", action, f"{len(filtered)} instances: {[instance['name'] for instance in filtered]}")
        action_data['action'](ec2client, filtered)


def extract_instance_data(instance):
    return {
        'id': instance.id,
        'name': extract_name_tag(instance.tags),
        'tags': flatten(instance.tags)
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


def filter_by_tags(instances, tags, value, filterFunc):
    filtered = []
    for inst in instances:
        if filterFunc(inst, tags, value):
            filtered.append(inst)
    return filtered


def marked(ignoredTags, instTags, value):
    for tag in ignoredTags:
        if tag in instTags and instTags[tag] == value:
            return True
    return False
