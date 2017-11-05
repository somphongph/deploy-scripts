#!/bin/bash

SOURCE_MASTER_URL=$1
SOURCE_FILE=$2
SOURCE_PATH=$3
DOCKER_FILE=$4
DOCKER_PATH=$5

rm -f $DOCKER_FILE
wget $SOURCE_MASTER_URL/$DOCKER_FILE
sudo rm -Rf $DOCKER_PATH
sudo mkdir -p $DOCKER_PATH
sudo tar -xzf $DOCKER_FILE -C $DOCKER_PATH
sudo chown ubuntu:ubuntu $DOCKER_PATH
sudo mkdir -p $DOCKER_PATH/logs
sudo chown -R 1001:1001 $DOCKER_PATH/logs
sudo chown -R 1001:1001 $DOCKER_PATH/nginx
sudo chown -R 1001:1001 $DOCKER_PATH/php-fpm

sudo docker-compose -f $DOCKER_PATH/docker-compose.yml pull

rm -f $SOURCE_FILE
wget $SOURCE_MASTER_URL/$SOURCE_FILE
sudo rm -Rf $SOURCE_PATH
sudo mkdir -p $SOURCE_PATH
sudo tar -xzf $SOURCE_FILE -C $SOURCE_PATH
sudo chown -R 1001 $SOURCE_PATH

sudo docker-compose -f $DOCKER_PATH/docker-compose.yml down
sleep 5
sudo docker-compose -f $DOCKER_PATH/docker-compose.yml up -d
sleep 20

PHPFPM_NAME=$(docker-compose -f $DOCKER_PATH/docker-compose.yml ps -q phpfpm)
sudo docker exec -i $PHPFPM_NAME php artisan migrate:refresh --database=mysqltest
sudo docker exec -i $PHPFPM_NAME vendor/bin/phpunit

exit $?