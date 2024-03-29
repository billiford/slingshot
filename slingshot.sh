#!/bin/bash
#########################################################################################################
#                                                                                                       #
#                                                                                                       #
#  ******.                                                                                              #
# ,//#%%%#/                                                                                             #
# .%&&%##%%.                                                                                            #
#  (#/*****,.                                                                                           #
#  .,*******,                                                                                           #
#   .********.                                                                                          #
#    *********.                                               .,,,.                                     #
#    .*********                                             .(#((/**.                                   #
#     .********,                                           ,/##&&&%/,                                   #
#      *********,                                         .*****/%&*                                    #
#      .*********                                        *********,                                     #
#       .********,.                                    .*********                                       #
#        **********                                   .********,.                                       #
#        ,**********.                                ,*********                                         #
#         .********//,                             .,********,                                          #
#          **********//                           .********//                                           #
#          .,**********(*                        ,********/%&,                                          #
#            **********(%*.                    .,*********,%&/.                                         #
#            .*********/#&%.                  .**********  (&%*                                         #
#             .*********/%&%/                **********,   ,#                                           #
#              ,*********/(&&(.            ,**********,     *&&,                                        #
#               .**********/#&&.         .,**********.       %,                                         #
#                ,**********,#&&(       .***********.        *#&%                                       #
#                 ,**********,*&,    ************           .&&(,                                       #
#                  ************/#&&*.************.             *#&%.                                    #
#                  .,***************************.               .%&%*                                   #
#                    **************************                  .(&&,                                  #
#                    ,***********************.                     (&&(                                 #
#                     ,********************,                        ,&&(.                               #
#                      ******************/,                          *%&%.                              #
#                      *****************(&&.                          .%&%*                             #
#                      ,***************. #&%*                          .(&&,                            #
#                      .**************,  .(&&,                           #&%/                           #
#                      .*************,.    #&%*                          ./&&,                          #
#                       ,************,     .(&&.                           #&%*                         #
#                       ,************,      .%,                          .(&%.                          #
#                       ,************,       ,#&%                           ,&&/.                       #
#                       ,************,.       ,&&/.                          #&%*                       #
#                       ,************,.        (&&(                          *%                         #
#                       ,*************.        ./&&,                         ./&&,                      #
#                       ,*************.    #@@%*,%,                         .&&(.                       #
#                       ,*************.    #@@@@@@&%#*.                        %&&/                     #
#                       ,*************.      .,/#&@&%%%,                       /%&%                     #
#                       ,*************,          .(@@%%(,                      ,#&&,                    #
#                       ,*************,            /%&%%#*.                     *&&(.                   #
#                       ,*************,              .*%%%%*.                   .&&&(..                 #
#                       ,*************,                #%%%%%*.                  #&%%%%%*               #
#                       ,**************                ,#%%%%%%(*               .(%%%&&&&&/             #
#                       .**************                 *%%%%%%%%%%#(//**//((##%%%%%*                   #
#                       .**************                  #%%%%%%%%%%%%%%%%%%%%%%%%%%(                   #
#                       .**************                  *#%%%%%%%%%%%%%%%%%%%%%%%#.                    #
#                       .**************                   ,%%%%%%%%%%%%%%%%%%%%%%(,                     #
#                       .**************                    *#%%%%%%%%%%%%%%%%%%%%.                      #
#                       .**************.                     *#%%%%%%%%%%%%%%%%/.                       #
#                        .**************.                       .*#%%%%%%%%%%%/,                        #
#                        .**************.                            .,,*,,.                            #
#                        .**************,                                                               #
#                        .**************,                                                               #
#                         **************,                                                               #
#                         ***************.                                                              #
#                         ***************.                                                              #
#                         ***************.                                                              #
#                         ***************,                                                              #
#                         ***************,                                                              #
#                         ***************,                                                              #
#                         ****************                                                              #
#                         ,***************                                                              #
#                          .************,.                                                              #
#                                                                                                       #
#########################################################################################################

cleanup() {
  echo "killing docker server"
  curl -s $KILL_HOST/kill
}

SCRIPT_LOC=$(cd "$(dirname "$0")"; pwd -P)
. $SCRIPT_LOC/common_functions.sh

shopt -s extglob

need "iptables"

trap cleanup EXIT

start_server

# test "$STAGING" && DEST_REGION="us.gcr.io" || DEST_REGION="gcr.io"
DEST_REGION="gcr.io"
DEST_PROJECT=${DEST_PROJECT:-"np-platforms-gcr-thd"}
DEST_IMAGE="$DEST_REGION/$DEST_PROJECT"

#SRC_IMG from one of the parameters from the spinnaker pipeline
case "$SRC_IMG" in
  !(*gcr.io*) )
    die "No suitable registry found in source image: $SRC_IMG";;

  !(*:*) )
    die "No Tag found in source image: $SRC_IMG";;
esac

need_var "$SRC_IMG" "SRC_IMG"
need_var "$SOURCE_ACCOUNT_JSON_CREDS_PATH" "SOURCE_ACCOUNT_JSON_CREDS_PATH"
need_var "$DEST_ACCOUNT_JSON_CREDS_PATH" "DEST_ACCOUNT_JSON_CREDS_PATH"

#construct Destination_image for retagging
IFS='/'
read -a IMG_ARR <<< "${SRC_IMG}"
IFS=' '

for i in ${IMG_ARR[@]:1}
do
  DEST_IMAGE="$DEST_IMAGE/$i"
done

#activate gcloud service account
gcloud auth activate-service-account --key-file="$SOURCE_ACCOUNT_JSON_CREDS_PATH"
error_check "$?" "gcloud service-account auth"

#pull down image from source location
print_message "pulling $SRC_IMG"
docker pull $SRC_IMG || die "Could not pull image from docker repo"

#retag the image
print_message "retagging image: $SRC_IMG for destination registry as: $DEST_IMAGE"
docker tag "${SRC_IMG}" "${DEST_IMAGE}"


gcloud auth activate-service-account --key-file="$DEST_ACCOUNT_JSON_CREDS_PATH"
error_check "$?" "gcloud service-account auth"

#push to destination registry
print_message "pushing docker image to destination registry"
docker push "${DEST_IMAGE}" || die "Could not push image from docker repo"

#Vulnerability Scanning
gcloud beta container images describe "${DEST_IMAGE}" --show-package-vulnerability --format=json > "vulnerability_scan.json"
error_check "$?" "gcloud image describe"
"$SCRIPT_LOC"/bin/vulnerability_parser ./vulnerability_scan.json
error_check "$?" "Container Analysis"

#echo out properties to be caught by spinnaker
echo SPINNAKER_PROPERTY_GOLDEN_IMAGE="$DEST_IMAGE"
