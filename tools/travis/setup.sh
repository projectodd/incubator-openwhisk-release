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

echo "list images in setup after build"
docker images

# Build the binaries for CLI
cd $OPENWHISKDIR/incubator-openwhisk-cli
./gradlew buildBinaries -PcrossCompileCLI=true

# Build the binaries for wskdeploy
cd $OPENWHISKDIR/incubator-openwhisk-wskdeploy
./gradlew distDocker -PcrossCompileWSKDEPLOY=true

# Deploy to OpenShift and run smoke tests
cd $OPENWHISKDIR/incubator-openwhisk-deploy-kube
./tools/travis/openshift-build.sh
