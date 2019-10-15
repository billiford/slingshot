#!/bin/bash
SCRIPT_LOC=$(cd "$(dirname "$0")"; pwd -P)
. $SCRIPT_LOC/common_functions.sh

REGION="us.gcr.io"
STAGING_PROJECT=${STAGING_PROJECT:-"np-platforms-gcr-thd"}
STAGING_REGISTRY="$REGION/$STAGING_PROJECT"
STAGING_IMAGE="$STAGING_REGISTRY"

need_var "$SRC_IMG" "SRC_IMG"
need_var "$REGION" "REGION"
need_var "$STAGING_REGISTRY" "STAGING_REGISTRY"
need_var "$STAGING_IMAGE" "STAGING_IMAGE"
need_var "$STAGING_ACCOUNT_JSON_CREDS_PATH" "STAGING_ACCOUNT_JSON_CREDS_PATH"

#construct STAGING_image for retagging
IFS='/'
read -a IMG_ARR <<< "${SRC_IMG}"
IFS=' '

for i in ${IMG_ARR[@]:1}
do
  STAGING_IMAGE="$STAGING_IMAGE/$i"
done

STAGING_IMAGE="$STAGING_IMAGE-staging"

gcloud auth activate-service-account --key-file="$STAGING_ACCOUNT_JSON_CREDS_PATH"

error_check "$?" "gcloud service-account auth"

gcloud beta container images describe "$STAGING_IMAGE" --show-package-vulnerability --format=json > "vulnerability_scan.json"

error_check "$?" "gcloud image describe"

"$SCRIPT_LOC"/bin/vulnerability_parser ./vulnerability_scan.json
