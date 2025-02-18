#!/usr/bin/python3

"""Jenkins Job Runner
This script allows to run pre-configured jenkins jobs with cli.

Assumptions:
    - VPN is on
    - Environment has `JENKINS_USER` and `JENKINS_TOKEN` variables defined
    - Some functionality assumes that the script is invoked from a git folder
    - Tested on mac only, sorry Yoni.

Usage:
    how to create access token: https://stackoverflow.com/questions/45466090/how-to-get-the-api-token-for-jenkins
    python3 jenkins_run.py --help provieds a description of flags
"""

import argparse
import json
import logging
import os
import subprocess
import time
import requests


class CustomHTTPError(Exception):
    pass


logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

try:
    creds = (os.environ["JENKINS_USER"], os.environ["JENKINS_TOKEN"])
except KeyError as ke:
    logger.error(f"{ke} is not defined in env!")
    exit(1)

JENKINS_URL = os.environ.get("JENKINS_URL")
LAST_BUILD_URL = "/lastBuild/api/json"
FLIP_ACTION = {
    "/build": "/buildWithParameters",
    "/buildWithParameters": "/build"
}

urls = {
    "start-jobname1": f"{JENKINS_URL}/job/folder1/job/jobname1/job/main/build",
    "deploy-jobname2": f"{JENKINS_URL}/job/folder2/job/jobname2/job/main/buildWithParameters",
    "build-repo": f"{JENKINS_URL}/job/folder1/job/REPO/job/BRANCH/buildWithParameters",
}


class Job:
    base_url: str
    action: str

    def __init__(self, _base_url, _action) -> None:
        self.base_url = _base_url
        self.action = _action

    def format_url(self, repo, branch):
        self.base_url = self.base_url.replace("REPO", repo).replace("BRANCH", branch)

    def build(self, data=None):
        logger.info(f"Building {self.base_url + self.action}")
        try:
            return send_with_retry(self.base_url + self.action, data)
        except requests.HTTPError as err:
            if err.response.status_code == 404:
                logger.error("URL Not found - Is is a new branch? Try running `scan-repo` first.")
                exit(1)
        except CustomHTTPError:
            logger.info(f"Failed to build with {self.action}, flipping")
            self.action = FLIP_ACTION[self.action]
            self.build()
        except requests.exceptions.ProxyError:
            logger.error("Blocked by proxy!")
            exit(1)
        except Exception as ex:
            logger.error(f"Caught something: {type(ex).__name__}, {type(ex)}")
            logger.error(f"Details: {ex}")
            exit(1)

    def get_latest_build(self):
        return send_with_retry(self.base_url + LAST_BUILD_URL, None)


def send_with_retry(jenkins_job_url, data) -> requests.Response:
    """Sends post with 3 retries"""
    logger.debug(jenkins_job_url)
    retries = 0
    while retries < 3:
        try:
            reply = requests.post(jenkins_job_url, data=data, auth=creds)
            reply.raise_for_status()
            return reply
        except requests.exceptions.ProxyError as proxy_err:
            raise proxy_err
        except requests.exceptions.HTTPError:
            raise CustomHTTPError(f"HttpError {reply.status_code}")
        except requests.exceptions.ConnectionError as err:
            logger.debug(f"Caught {err}\nRetrying")
            retries += 1


for key in urls.keys():
    full_url = urls[key]
    split_index = full_url.rfind("/")
    urls[key] = Job(full_url[0:split_index], full_url[split_index:])


def validate_job(value):
    if value not in urls.keys():
        raise argparse.ArgumentTypeError(f"{value} is not valid.\nPossible values: {list(urls.keys())}")
    return value


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-j', '--job', dest='job',
        action='store', type=validate_job,
        required=True, help=f"Job to run: {list(urls.keys())}")
    parser.add_argument(
        '--dir', dest='current_dir',
        action='store_true',
        required=False, help="Invoke build for current repo directory")
    parser.add_argument(
        '--repo', dest='repo',
        action='store',
        required=False, help="Invoke build for given repo name")
    parser.add_argument(
        '-b', '--branch', dest='branch',
        action='store', type=str,
        required=False, help="Branch name to build (default: current branch, **must be in git folder**)")
    parser.add_argument(
        '--wait', dest='wait',
        action='store_true',
        required=False, help="Wait for job to finish")
    parser.add_argument(
        '--data', dest='data',
        action='store', type=parse_data,
        required=False, help="Job params")
    return parser.parse_args()


def get_local_git_branch():
    """Finds current branch name when invoked in get repo"""
    git_rev_parse = subprocess.run(
                ["git rev-parse --abbrev-ref HEAD"],
                shell=True,
                stdout=subprocess.PIPE,
                universal_newlines=True)
    return git_rev_parse.stdout.strip()


if __name__ == '__main__':
    args = parse_args()
    jenkins_job: Job = urls[args.job]

    if args.current_dir or args.repo:
        repo = args.repo or os.getcwd().split("/")[-1]
        branch = args.branch or get_local_git_branch()
        branch = branch.replace("/", "%252F")  # Fix slash for correct url format
        jenkins_job.format_url(repo, branch)

    if args.data:
        args.data = json.loads(args.data)

    jenkins_job.build(args.data)

    if "scan" not in args.job:
        time.sleep(10)  # Let the job start
        response = jenkins_job.get_latest_build()
        logger.info(f"Latest build:\n\t{response.json()['url']}")

    if args.wait:
        pass

    logger.info("Done")
