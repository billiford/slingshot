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

function cleanup {
  echo "killing docker server"
  curl -s $KILL_HOST/kill
}

function print_message {
  echo "----------------------------------------------------------"
  echo "$* |"
  echo "----------------------------------------------------------"
  echo ""
}

function check_docker_server_health {
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

trap cleanup EXIT

#SRC_IMG from one of the parameters from the spinnaker pipeline
GOLDEN_REGISTRY=${GOLDEN_REGISTRY:-"np-platforms-gcr-thd"}
REGION=${REGION:-$(echo "${SRC_IMG}" | cut -d/ -f1)}
DEST_IMAGE="$REGION/$GOLDEN_REGISTRY"

print_message checking if docker server is online

check_docker_server_health

print_message pulling down docker image from source registry

#activate gcloud service account
#below syntax - for stdin, <<< to redirect echo to temp file
# echo "$SA_CREDS_SRC" > /tmp/src_creds_file.json
gcloud auth activate-service-account --key-file=-<<<$(echo $SA_CREDS_SRC)

#pull down image from source location
#SRC_IMG from one of the parameters from the spinnaker pipeline
docker pull $SRC_IMG


print_message retagging image for destination registry

#construct Destination_image for retagging
IFS='/'
read -a IMG_ARR <<< "${SRC_IMG}"
IFS=' '

for i in ${IMG_ARR[@]:1}
do
  DEST_IMAGE="$DEST_IMAGE/$i"
done

#retag the image
docker tag "${SRC_IMG}" "${DEST_IMAGE}"

print_message pushing docker image to destination registry

# echo "$SA_CREDS_DEST" > /tmp/dest_creds_file.json
gcloud auth activate-service-account --key-file=-<<<$(echo $SA_CREDS_DEST)

#push to destination registry
docker push "${DEST_IMAGE}"
