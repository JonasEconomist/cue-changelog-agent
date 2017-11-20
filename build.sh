#!/bin/bash -x

#set -exo pipefail

if [ -z ${AWS_CMD} ]; then
  AWS_CMD="aws"
fi 

set -exo pipefail

main() {
  cleanup
  setTags

  buildImage

  buildEbApplicationZip

  if [ ${DOCKER_HUB_ACCOUNT} != "local" ]; then
    uploadToDockerHub
  else
    docker kill `docker ps --format "{{.Names}}" --filter "ancestor=local/cue-changelog-agent:latest"` || true
    docker run -p 9494:9494 \
      -e AWS_S3_BUCKET=${AWS_S3_BUCKET} \
      -d $DOCKER_HUB_ACCOUNT/$SERVICE_NAME:$BUILD_TAG
    docker ps
    echo "Docker host: ${DOCKER_HOST}"
  fi

  if [ "$?" = "0" ]; then
    echo "Success!"
  else
    echo "Failure :-("
    exit 1
  fi
}

cleanup() {
  rm -f report.xml || true
}
buildImage() {
  sed "s/BUILD_TAG/${BUILD_TAG}/g; s/ECR/${DOCKER_HUB_ACCOUNT}/g; s/SERVICE_NAME/${SERVICE_NAME}/g;" < Dockerrun.aws.json.template > Dockerrun.aws.json
  docker build --pull=true --tag ${DOCKER_HUB_ACCOUNT}/${SERVICE_NAME}:${BUILD_TAG} .
}

setTags() {
  if [ -z "${SERVICE_NAME}" ]; then
    SERVICE_NAME="$(basename "$(pwd)")"
  fi
  if [ ! -z ${CODEBUILD_BUILD_ID} ]; then
     BUILD_TAG=${CODEBUILD_BUILD_ID#*:}
  fi
  DEV_LATEST_TAG="dev-latest"
  if [ -z ${BUILD_TAG} ]; then
    BUILD_TAG="latest"
    DOCKER_HUB_ACCOUNT="local"
    echo "${BUILD_TAG} development environment configuration..."
  else
    if [ -z ${DOCKER_HUB_ACCOUNT} ]; then
            loginECR
    fi
    DOCKER_HUB_ACCOUNT=${DOCKER_HUB_ACCOUNT:-economist}
    echo "${BUILD_TAG} environment configuration..."
  fi
}


loginECR(){
    LOGIN=$( $AWS_CMD ecr get-login --no-include-email )
    $LOGIN
    if [ $? -ne 0 ]; then 
          echo "Failed to login to AWS ECR";
          exit 1
    fi
    DOCKER_HUB_ACCOUNT=$( echo $LOGIN |  sed 's/.*https:\/\///' )
}


uploadToDockerHub ()
{
  if [ -z ${DOCKER_HUB_ACCOUNT} ]; then
    echo "Failed to push to docker hub. Docker hub account credentials not provided."
    exit 1
  else

    docker tag ${DOCKER_HUB_ACCOUNT}/${SERVICE_NAME}:${BUILD_TAG} ${DOCKER_HUB_ACCOUNT}/${SERVICE_NAME}:${DEV_LATEST_TAG}

    local DOCKER_TAGS="${BUILD_TAG} ${DEV_LATEST_TAG}"
    local DOCKER_PUSH_URL
    for DOCKER_TAG in ${DOCKER_TAGS}; do
      DOCKER_PUSH_URL="${DOCKER_HUB_ACCOUNT}/${SERVICE_NAME}:${DOCKER_TAG}"
      docker push "${DOCKER_PUSH_URL}" || docker push "${DOCKER_PUSH_URL}"
    done
  fi
}

buildEbApplicationZip(){
  if [ -f Dockerrun.aws.json ]; then
    mkdir -p target
    cp -a .ebextensions target/
    cp -a Dockerrun.aws.json target/ 
    pushd target
    zip -r ../eb-${SERVICE_NAME}-${BUILD_TAG}.zip .
    popd
  else
    echo "Build not complete Dockerrun.aws.json missing"
  fi
}


main
