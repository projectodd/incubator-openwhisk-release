#!/usr/bin/env bash

set -e
set -x

sudo apt-get install jq

HOMEDIR="$(dirname "$TRAVIS_BUILD_DIR")"
OPENWHISKDIR="$HOMEDIR/openwhisk"
source "$TRAVIS_BUILD_DIR/tools/travis/util.sh"

function git_clone_repo() {
    ORG_NAME=$1
    PROJECT_NAME=$2
    HASH=$3
    git clone https://github.com/$ORG_NAME/$PROJECT_NAME.git $OPENWHISKDIR/$PROJECT_NAME
    cd $OPENWHISKDIR/$PROJECT_NAME
    git reset --hard $HASH
    rm -rf .git
}

rm -rf $OPENWHISKDIR/*

CONFIG=$(read_file $TRAVIS_BUILD_DIR/tools/travis/config.json)
repos=$(echo $(json_by_key "$CONFIG" "RepoList") | sed 's/[][]//g')

for repo in $(echo $repos | sed "s/,/ /g")
do
    org_and_repo=$(echo "$repo" | sed -e 's/^"//' -e 's/"$//')
    org_name=$(echo "$org_and_repo" | awk -F '/' {'print $1'})
    repo_name=$(echo "$org_and_repo" | awk -F '/' {'print $2'})
    HASH_KEY=${repo_name//-/_}.hash
    HASH=$(json_by_key "$CONFIG" $HASH_KEY)
    if [ "$HASH" != "null" ]; then
        echo "The hash for $repo_name is $HASH"
        git_clone_repo $org_name $repo_name $HASH
    fi
done
