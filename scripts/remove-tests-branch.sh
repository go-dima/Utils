#!/bin/bash

GIT_FOLDER=~/git/pegasus
BRANCH_NAME=$1

clean_branch() {
  git fetch --all
  if $(git branch -r | grep -q ${BRANCH_NAME}); then
    echo Branch found, deleting.
    git push origin --delete ${BRANCH_NAME}
  else
    echo Branch not found, skipping.
  fi
}

if [[ -z ${BRANCH_NAME} ]]; then
  echo Error, branch not specified
  exit 1
fi

echo Deleting branch ${1}

for repo in automationtoolbox pegasus-tests pegasus-app; do
  echo Repository $repo
  cd ${GIT_FOLDER}/${repo}
  clean_branch
  sleep 2s
done

if [[ -n $2 && "$2" == "--no-dev" ]]; then
  exit 0
fi

for repo in pegasus-wf-pcloud pegasus-wf-customer pegasus-system-jobs; do
  echo Repository $repo
  cd ${GIT_FOLDER}/${repo}
  clean_branch
  sleep 1s
done

