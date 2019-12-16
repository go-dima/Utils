#!/usr/bin/python3

import boto3
import json
import argparse
import multiprocessing
from joblib import Parallel, delayed
from AwsRegionsDictionary.RegionsMapping import mapToRegionKey # https://github.com/go-dima/aws-regions-dictionary


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-l', '--list',
        action='store_true',
        default=False,
        dest='list',
        help='List available RDS without performing any action')
    parser.add_argument(
        '-r', '--region',
        action='store',
        dest='region',
        help='Region to run on')
    return parser.parse_args()


def handleStart(rdsClient, clusterIdentifier):
    print(f"\tStarting {clusterIdentifier}")
    rdsClient.start_db_cluster(DBClusterIdentifier=clusterIdentifier)


def handleStop(rdsClient, clusterIdentifier):
    print(f"\tStopping {clusterIdentifier}")
    rdsClient.stop_db_cluster(DBClusterIdentifier=clusterIdentifier)


def handleRegion(region_name, action):
    rdsClient = boto3.client('rds', region_name)
    regionalDBClusters = rdsClient.describe_db_clusters()
    dbClusters = regionalDBClusters['DBClusters']
    print(f"{region_name}: {len(dbClusters)} rds clusters")
    for cluster in dbClusters:
        clusterStatus = cluster['Status']
        clusterIdentifier = cluster['DBClusterIdentifier']
        print(f"\t{clusterIdentifier} is {clusterStatus}")
        if not args.list:
           if (action == 'start' and clusterStatus == 'stopped'):
               handleStart(rdsClient, clusterIdentifier)
           if (action == 'stop' and clusterStatus == 'available'):
               handleStop(rdsClient, clusterIdentifier)


def lambda_handler(event, context):
    regionsToHandle = []
    if args.region:
        regionsToHandle.append(mapToRegionKey(args.region))
    else:
        regionsResponse = boto3.client('ec2').describe_regions()
        regionsToHandle.extend([region['RegionName'] for region in regionsResponse['Regions']])
    num_cores = multiprocessing.cpu_count()
    Parallel(n_jobs=num_cores)(delayed(handleRegion)(region, event['action']) for region in regionsToHandle)


args = parse_args()
lambda_handler({'action': 'start'}, '')
