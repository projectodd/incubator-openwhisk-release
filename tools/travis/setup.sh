#!/usr/bin/env bash

set -e
set -x

echo "hello openwhisk release"

# Define the parent directory of TRAVIS_BUILD_DIR(the directory of the current repository) as HOMEDIR
HOMEDIR="$(dirname "$TRAVIS_BUILD_DIR")"
OPENWHISKDIR="$HOMEDIR/openwhisk"
SUFFIX="$TRAVIS_BUILD_NUMBER"
PR_NUM="$TRAVIS_PULL_REQUEST"
IMAGE_PREFIX="projectodd"
IMAGE_TAG="openshift-latest"

export OPENWHISK_HOME="$OPENWHISKDIR/incubator-openwhisk";

mkdir -p $OPENWHISKDIR
cd $OPENWHISKDIR

echo "list images in setup before build"
docker images

cd $TRAVIS_BUILD_DIR
./tools/travis/download_source_code.sh

# Setup OpenShift
cd $OPENWHISKDIR/incubator-openwhisk-deploy-kube
./tools/travis/openshift-setup.sh

# Build the controller and invoker
cd $OPENWHISKDIR/incubator-openwhisk
# ./tools/travis/setup.sh
# instead of setup.sh, we copy only a few relevant bits of it here
pip install --user couchdb
pip install --user ansible==2.3.0.0
#
TERM=dumb ./gradlew core:controller:distDocker core:invoker:distDocker -PdockerImagePrefix=$IMAGE_PREFIX -PdockerImageTag=$IMAGE_TAG

# Build the Node runtime images
cd $OPENWHISKDIR/incubator-openwhisk-runtime-nodejs
TERM=dumb ./gradlew core:nodejs6Action:distDocker core:nodejs8Action:distDocker -PdockerImagePrefix=$IMAGE_PREFIX -PdockerImageTag=$IMAGE_TAG

# Build the Python runtime images
cd $OPENWHISKDIR/incubator-openwhisk-runtime-python
TERM=dumb ./gradlew core:pythonAction:distDocker core:python2Action:distDocker -PdockerImagePrefix=$IMAGE_PREFIX -PdockerImageTag=$IMAGE_TAG

# Build the Java runtime image
cd $OPENWHISKDIR/incubator-openwhisk-runtime-java
TERM=dumb ./gradlew core:javaAction:distDocker -PdockerImagePrefix=$IMAGE_PREFIX -PdockerImageTag=$IMAGE_TAG

echo "list images in setup after build"
docker images

# Build the binaries for CLI
cd $OPENWHISKDIR/incubator-openwhisk-cli
./gradlew buildBinaries -PcrossCompileCLI=true

# Build the binaries for wskdeploy
cd $OPENWHISKDIR/incubator-openwhisk-wskdeploy
./gradlew distDocker -PcrossCompileWSKDEPLOY=true

# Figure out which url and hash to use for Docker builds that need
# OpenWhisk cloned
cd $OPENWHISKDIR/incubator-openwhisk
OPENWHISK_REPO_URL=$(git remote get-url origin)
OPENWHISK_REPO_HASH=$(git rev-parse $HEAD)

# Build the deployment Docker images for OpenShift
cd $OPENWHISKDIR/incubator-openwhisk-deploy-kube
docker build --build-arg OPENWHISK_REPO_URL=${OPENWHISK_REPO_URL} --build-arg OPENWHISK_REPO_HASH=${OPENWHISK_REPO_HASH} --tag ${IMAGE_PREFIX}/whisk_couchdb:${IMAGE_TAG} docker/couchdb
docker build --tag ${IMAGE_PREFIX}/whisk_zookeeper:${IMAGE_TAG} docker/zookeeper
docker build --tag ${IMAGE_PREFIX}/whisk_kafka:${IMAGE_TAG} docker/kafka
docker build --tag ${IMAGE_PREFIX}/whisk_nginx:${IMAGE_TAG} docker/nginx
docker build --tag ${IMAGE_PREFIX}/whisk_catalog:${IMAGE_TAG} docker/openwhisk-catalog
docker build --tag ${IMAGE_PREFIX}/whisk_alarms:${IMAGE_TAG} docker/alarms

# Deploy to OpenShift and run smoke tests
cd $OPENWHISKDIR/incubator-openwhisk-deploy-kube
./tools/travis/openshift-build.sh
