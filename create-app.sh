#!/bin/bash

set -eou pipefail

PROJECT_NAME=$1

if [ -e $PROJECT_NAME ]
then
echo "Проект $PROJECT_NAME уже существует"
exit 1
fi

mkdir $PROJECT_NAME

echo "Проект $PROJECT_NAME создан"

