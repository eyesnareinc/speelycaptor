#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: polycosm-publish.sh [environment]

Packages and publishes the lambda code to S3 for redistribution into new polycosm deployments.
"
  exit 1
fi

if [[ -z "$HUBS_OPS_PATH" ]]; then
  echo -e "To use this deploy script, you need to clone out the hubs-ops repo

git clone git@github.com:mozilla/hubs-ops.git

Then set HUBS_OPS_PATH to point to the cloned repo."
  exit 1
fi

ENVIRONMENT=$1
[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

VERSION=$(cat package.json | jq -r ".version")
NAME=$(cat package.json | jq -r ".name")

DIR=$(pwd)
pushd $HUBS_OPS_PATH/terraform
BUCKET=$(./grunt_local.sh output base $ENVIRONMENT -json | jq 'with_entries(.value |= .value)' | jq -r ".polycosm_assets_bucket_id")
BUCKET_REGION=$(./grunt_local.sh output base $ENVIRONMENT -json | jq 'with_entries(.value |= .value)' | jq -r ".polycosm_assets_bucket_region")
popd

mv node_modules node_modules_tmp
env npm_config_arch=x64 npm_config_platform=linux npm_config_target=10.16.1 npm ci
zip -9 -y -r ${NAME}-${VERSION}.zip *.js node_modules
curl https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz | tar xJ
mv ffmpeg*/ffmpeg .
mv ffmpeg*/ffprobe .
zip -m -u ${NAME}-${VERSION}.zip ffmpeg ffprobe
aws s3 cp --region $BUCKET_REGION --acl public-read ${NAME}-${VERSION}.zip s3://$BUCKET/lambdas/$NAME/${NAME}-${VERSION}.zip
rm -rf node_modules
mv node_modules_tmp node_modules
rm ${NAME}-${VERSION}.zip
rm -rf ffmpeg*