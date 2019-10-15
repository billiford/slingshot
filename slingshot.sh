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

check_docker_server_health() {
  EXIT_CODE=1
  i=0
  while [ "${EXIT_CODE}" -ne 0 ]
  do
    sleep 2
    echo "Attempt $i to connect to docker daemon"
    nc localhost 2375 -v
    EXIT_CODE=$?
    i=$((i + 1))
  done
}

SCRIPT_LOC=$(cd "$(dirname "$0")"; pwd -P)
. $SCRIPT_LOC/common_functions.sh

shopt -s extglob

trap cleanup EXIT

print_message "checking if docker server is online"
check_docker_server_health

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

test "$STAGING" && DEST_IMAGE="$DEST_IMAGE-staging"

#construct the staging source image if we are pulling from staging registry
if ! [ $STAGING ]
then
  STAGING_PROJECT=${STAGING_PROJECT:-"np-platforms-gcr-thd"}
  STAGING_IMAGE="us.gcr.io/$STAGING_PROJECT"

  #construct STAGING_image for retagging
  IFS='/'
  read -a IMG_ARR <<< "${SRC_IMG}"
  IFS=' '

  for i in ${IMG_ARR[@]:1}
  do
    STAGING_IMAGE="$STAGING_IMAGE/$i"
  done

  STAGING_IMAGE="$STAGING_IMAGE-staging"
  SRC_IMG="$STAGING_IMAGE"
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
echo "SPINNAKER_PROPERTY_golden_image=${DEST_IMAGE}"
