#!/bin/bash

CONFIG_ENV=$1
SERVER_ENV=$2
RELEASE_BRANCH=$3
RELEASE_VERSION=$4

PROJECT_NAME="laravel-quickstart-test"
SITE_NAME="laravel-quickstart-test.com"

BASE="/bitnami/jenkins/1001/deploy-scripts/base"
DEPLOY_BASEDIR="/bitnami/jenkins/1001/deploys"

#SOURCE MASTER
SRC_MASTER_DIR="/bitnami/jenkins/sourcemaster"
SRC_MASTER_URL="http://<your-jenkins-server-ip>:8080"

#SERVER
SERVERS="ubuntu@<your-app-server-ip>"
SERVER_DOCKER_PATH="/var/dockers/$SITE_NAME"
SERVER_SOURCE_PATH="/var/www/$SITE_NAME"

#GITS
GITREPO_URL="https://$GIT_USER:$GIT_PASS@github.com/pong3ds"
SOURCE_REPO="$GITREPO_URL/laravel-quickstart-source.git"
CONFIG_REPO="$GITREPO_URL/laravel-quickstart-config.git"
DOCKER_REPO="$GITREPO_URL/laravel-quickstart-dockers.git"
SOURCE_SUBDIR="web"

#BUILD DIR
DEPLOY_DIR="$DEPLOY_BASEDIR/$PROJECT_NAME"
DOCKER_DIR="$DEPLOY_DIR/dockers"
SOURCE_DIR="$DEPLOY_DIR/source"
CONFIG_DIR="$DEPLOY_DIR/config"
BUILD_DIR="$DEPLOY_DIR/build"
FINISH_DIR="$DEPLOY_DIR/finish"

#DOCKER IMAGES
GIT_IMAGE="3dsinteractive/git-client:1.0"
COMPOSER_IMAGE="3dsinteractive/composer:7.1"

source /bitnami/jenkins/1001/deploy-scripts/base/deploy-base.sh

run test