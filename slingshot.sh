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

DEST_PROJECT=${DEST_PROJECT:-"np-platforms-gcr-thd"}

test "$STAGING" && DEST_REGION="us.gcr.io" || DEST_REGION="gcr.io"
DEST_REGISTRY="$DEST_REGION/$DEST_PROJECT"
DEST_IMAGE="$DEST_REGISTRY"

#SRC_IMG from one of the parameters from the spinnaker pipeline
case "$SRC_IMG" in
  !(*gcr.io*) )
    die "No suitable registry found in source image: $SRC_IMG";;

  !(*:*) )
    die "No Tag found in source image: $SRC_IMG";;
esac

need_var "$SRC_IMG" "SRC_IMG"
need_var "$DEST_IMAGE" "DEST_IMAGE"
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

#if we're staging the image, append '-staging' to the image, otherwise remove the suffix '-staging'
if [ "$STAGING" = "true" ]
then
  DEST_IMAGE="$DEST_IMAGE-staging"
else
  DEST_IMAGE="${DEST_IMAGE%-staging}"
fi

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

# print_message "SPINNAKER_PROPERTY_GOLDEN_IMAGE=${DEST_IMAGE}"
echo SPINNAKER_PROPERTY_GOLDEN_IMAGE="$DEST_IMAGE"
