#!/bin/bash

function checkEnv() {
    if [ -z $DEPLOY_BASEDIR ]
    then
        echo Please specify DEPLOY_BASEDIR to the directory of deployment file.
        exit 1
    fi

    if [ -z $CONFIG_ENV ]
    then
        echo Please specify git BRANCH of project config to deploy
        exit 1
    fi

    if [ -z $SERVER_ENV ]
    then
        echo Please specify git BRANCH of docker compose to deploy
        exit 1
    fi

    if [ -z $RELEASE_BRANCH ]
    then
        echo Please specify source code branch to deploy
        exit 1
    fi

    mkdir -p $DOCKER_DIR
    mkdir -p $SOURCE_DIR
    mkdir -p $CONFIG_DIR
    mkdir -p $BUILD_DIR
    mkdir -p $FINISH_DIR
}

function gitPull() {
    local DIR=$1
    sudo docker run -i --rm -v $DIR:/app $GIT_IMAGE pull
}

function gitClone() {
    local DIR=$1
    local REPO=$2
    sudo docker run -i --rm -v $DIR:/app $GIT_IMAGE clone $REPO .
}

function gitCheckout() {
    local DIR=$1
    local BRANCH=$2
    local TAG=$3

    sudo docker run -i --rm -v $DIR:/app $GIT_IMAGE clean -xdf
    if [ -z $TAG ]
    then
        sudo docker run -i --rm -v $DIR:/app $GIT_IMAGE checkout $BRANCH
    else
        sudo docker run -i --rm -v $DIR:/app $GIT_IMAGE checkout tags/$TAG
    fi
}

function gitUpdate() {
    local DIR=$1
    local REPO=$2
    local BRANCH=$3
    local TAG=$4

    if [ ! -d $DIR/.git ]
    then
        mkdir -p $DIR
        gitClone $DIR $REPO
    else
        gitPull $DIR
    fi

    if [ ! -z $BRANCH ]
    then
        gitCheckout $DIR $BRANCH $TAG
    fi
}

function rsyncSoft() {
    local FROM=$1
    local TO=$2

    if [ ! -d $FROM ]
    then
        return
    fi

    if [ -f $FROM/.deploy-ignore ]
    then
        rsync -rlczP --exclude-from=$FROM/.deploy-ignore $FROM/. $TO
    else
        rsync -rlczP $FROM/. $TO
    fi
}

function rsyncHard() {
    local FROM=$1
    local TO=$2

    if [ ! -d $FROM ]
    then
        return
    fi

    if [ -f $FROM/.deploy-ignore ]
    then
        rsync -rlczP --delete --exclude-from=$FROM/.deploy-ignore $FROM/. $TO
    else
        rsync -rlczP --delete $FROM/. $TO
    fi
}

function copyRemote() {
    PEM=$1
    FILE=$2
    DEST=$3

    scp -o StrictHostKeyChecking=no -i $PEM $FILE $DEST
}

function composerUpdate() {
    sudo docker run -i --rm -v $SOURCE_DIR/$SOURCE_SUBDIR:/app $COMPOSER_IMAGE install
}

function getDateNow {
	echo $(date +"%m-%d-%y")
}

function makeZip() {
    local ZIPFROM_DIR=$1
    local ZIPFILE=$2

    if [ -d $ZIPFROM_DIR ]
    then
        cd $ZIPFROM_DIR
        tar -czf $ZIPFILE .
        cd -
    fi
}

function uploadToMaster() {
    local DIR=$1
    local ZIPFILE=$2

    rm -f $ZIPFILE

    makeZip $DIR $ZIPFILE

    if [ -f $ZIPFILE ]
    then
        copyRemote $SRC_MASTER_PEM $ZIPFILE $SRC_MASTER_SERVER/$(basename $ZIPFILE)
    fi
}

function copyToMaster() {
    local DIR=$1
    local ZIPFILE=$2

    rm -f $ZIPFILE

    makeZip $DIR $ZIPFILE

    if [ -f $ZIPFILE ]
    then
        cp $ZIPFILE $SRC_MASTER_DIR/$(basename $ZIPFILE)
    fi
}

function redeploy() {
    SOURCE_ZIP=$1
    DOCKER_ZIP=$2
    for SERVER in $(echo $SERVERS | tr "," " "); do
        ssh -o StrictHostKeyChecking=no -i $SERVER_PEM $SERVER "bash -s" < $BASE/re-deploy.sh $SRC_MASTER_URL $SOURCE_ZIP $SERVER_SOURCE_PATH $DOCKER_ZIP $SERVER_DOCKER_PATH
    done
}

function runtest() {
    SOURCE_ZIP=$1
    DOCKER_ZIP=$2
    ssh -o StrictHostKeyChecking=no -i $SERVER_PEM $SERVERS "bash -s" < $BASE/runtest.sh $SRC_MASTER_URL $SOURCE_ZIP $SERVER_SOURCE_PATH $DOCKER_ZIP $SERVER_DOCKER_PATH
    exit $?
}

function run() {

    local CMD=$1

    checkEnv

    gitUpdate $SOURCE_DIR $SOURCE_REPO $RELEASE_BRANCH $RELEASE_VERSION
    gitUpdate $CONFIG_DIR $CONFIG_REPO $CONFIG_ENV
    gitUpdate $DOCKER_DIR $DOCKER_REPO $SERVER_ENV

    #sync file to build dir
    rsyncHard $SOURCE_DIR/$SOURCE_SUBDIR $BUILD_DIR
    #override config in build dir
    rsyncSoft $CONFIG_DIR/config $BUILD_DIR

    local SOURCE_ZIP="$FINISH_DIR/$PROJECT_NAME-code.tar.gz"
    copyToMaster $BUILD_DIR $SOURCE_ZIP

    local DOCKER_ZIP="$FINISH_DIR/$PROJECT_NAME-docker.tar.gz"
    copyToMaster $DOCKER_DIR/dockers $DOCKER_ZIP

    if [ $CMD = "test" ]
    then
        runtest $(basename $SOURCE_ZIP) $(basename $DOCKER_ZIP)
    else
        redeploy $(basename $SOURCE_ZIP) $(basename $DOCKER_ZIP)
    fi

}