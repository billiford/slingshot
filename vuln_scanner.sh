#!/bin/bash
SCRIPT_LOC=$(cd "$(dirname "$0")"; pwd -P)
. $SCRIPT_LOC/common_functions.sh

REGION="us.gcr.io"
QUARANTINE_PROJECT=${QUARANTINE_PROJECT:-"np-platforms-gcr-thd"}
QUARANTINE_REGISTRY="$REGION/$QUARANTINE_PROJECT"
QUARANTINE_IMAGE="$QUARANTINE_REGISTRY"

need_var "$SRC_IMG" "SRC_IMG"
need_var "$REGION" "REGION"
need_var "$QUARANTINE_REGISTRY" "QUARANTINE_REGISTRY"
need_var "$QUARANTINE_IMAGE" "QUARANTINE_IMAGE"
need_var "$QUARANTINE_ACCOUNT_JSON_CREDS_PATH" "QUARANTINE_ACCOUNT_JSON_CREDS_PATH"

#construct QUARANTINE_image for retagging
IFS='/'
read -a IMG_ARR <<< "${SRC_IMG}"
IFS=' '

for i in ${IMG_ARR[@]:1}
do
  QUARANTINE_IMAGE="$QUARANTINE_IMAGE/$i"
done

QUARANTINE_IMAGE="$QUARANTINE_IMAGE-quarantine"

gcloud auth activate-service-account --key-file="$QUARANTINE_ACCOUNT_JSON_CREDS_PATH"

error_check "$?" "gcloud service-account auth"

gcloud beta container images describe "$QUARANTINE_IMAGE" --show-package-vulnerability --format=json > "vulnerability_scan.json"

error_check "$?" "gcloud image describe"

vulnerability_parser ./vulnerability_scan.json
