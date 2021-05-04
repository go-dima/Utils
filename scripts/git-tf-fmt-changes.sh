#!/bin/bash

CHANGES=$(git status | grep modified | tr -d ' ' | cut -d':' -f2 | awk '{print $1}')

for change in ${CHANGES}; do
  echo $change
  pushd $(dirname $change) > /dev/null
  terraform fmt
  popd > /dev/null
done
