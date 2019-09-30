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

print_message() {
  echo ""
  echo "------------------------------------------"
  echo "$*"
  echo "------------------------------------------"
  echo ""
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

die() {
  print_message "$*" 1>&2
  exit 1
}

need_var() {
  test -n $1 || die "$1 does not exist, exiting script"
}

shopt -s extglob

trap cleanup EXIT

print_message "checking if docker server is online"
check_docker_server_health

#SRC_IMG from one of the parameters from the spinnaker pipeline
GOLDEN_REGISTRY=${GOLDEN_REGISTRY:-"np-platforms-gcr-thd"}
REGION=${REGION:-$(echo "${SRC_IMG}" | cut -d/ -f1)}
DEST_IMAGE="$REGION/$GOLDEN_REGISTRY"

print_message "REGISTRY: $REGION"

case "$REGION" in
  !(*gcr.io) )
    die "No suitable registry found in source image: $SRC_IMG";;
esac

need_var "$SRC_IMG"
need_var "$REGION"
need_var "$GOLDEN_REGISTRY"
need_var "$DEST_IMAGE"
need_var "$SOURCE_ACCOUNT_JSON_CREDS_PATH"
need_var "$DEST_ACCOUNT_JSON_CREDS_PATH"

print_message "pulling down docker image from source registry"

#activate gcloud service account
gcloud auth activate-service-account --key-file="$SOURCE_ACCOUNT_JSON_CREDS_PATH"

#pull down image from source location
#SRC_IMG from one of the parameters from the spinnaker pipeline
docker pull $SRC_IMG || die "Could not pull image from docker repo"

#construct Destination_image for retagging
IFS='/'
read -a IMG_ARR <<< "${SRC_IMG}"
IFS=' '

for i in ${IMG_ARR[@]:1}
do
  DEST_IMAGE="$DEST_IMAGE/$i"
done

#retag the image
print_message "retagging image: $SRC_IMG for destination registry as: $DEST_IMAGE"
docker tag "${SRC_IMG}" "${DEST_IMAGE}"

print_message "pushing docker image to destination registry"

gcloud auth activate-service-account --key-file="$DEST_ACCOUNT_JSON_CREDS_PATH"

#push to destination registry
docker push "${DEST_IMAGE}"
