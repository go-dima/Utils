#!/usr/bin/python3

import boto3
import argparse
import time
from os import system
from AwsRegionsDictionary.RegionsMapping import mapToRegionKey # https://github.com/go-dima/aws-regions-dictionary


class color:
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    DARKCYAN = '\033[36m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'


def status_to_srt(status):
    selectedColor = color.YELLOW
    if status == 'available':
        selectedColor = color.GREEN
    elif status == 'stopped':
        selectedColor = color.RED
    return selectedColor + status + color.END


def underline(text):
    return color.UNDERLINE + text + color.END


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-r', '--region',
        action='store',
        dest='region',
        help='Region to describe')
    parser.add_argument(
        '-w', '--watch',
        action='store_true',
        dest='watch',
        help='Enable watch loop')
    return parser.parse_args()


def clear(): return system('clear')


def describe_region(region_name):
    rdsClient = boto3.client('rds', region_name=region_name)
    response = rdsClient.describe_db_instances()
    instances = response['DBInstances']
    output = f"{region_name}: {len(instances)} rds instances"
    ready = True
    if len(instances) > 0:
        print(color.BOLD + output + color.END)
        for instance in instances:
            instanceDesc = f"{underline(instance['DBInstanceIdentifier'])} of type {underline(instance['DBInstanceClass'])} is {status_to_srt(instance['DBInstanceStatus'])}"
            print("\t{}".format(instanceDesc))
            if instance['DBInstanceStatus'] != "available":
                ready = False
    else:
        print(output)
    return ready


args = parse_args()

if args.region:
    while not describe_region(mapToRegionKey(args.region)) and args.watch:
        time.sleep(30)
        clear()
else:
    ec2Client = boto3.client('ec2')
    regionsResponse = ec2Client.describe_regions()
    for region in regionsResponse['Regions']:
        describe_region(region['RegionName'])
