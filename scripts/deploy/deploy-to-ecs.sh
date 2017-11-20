#!/bin/sh

set -e

check_service_status () {
  echo "Waiting for deployment"
  aws ecs wait services-stable --cluster $ECS_CLUSTER_NAME --services $ECS_SERVICE_NAME --region ${ECS_AWS_REGION}

  echo "Checking Task deployment version"
  serviceStatus=$(aws ecs describe-services --cluster $ECS_CLUSTER_NAME --services $ECS_SERVICE_NAME --region ${ECS_AWS_REGION} | jq '.services | .[] ' )

  if [ -z "$serviceStatus" ]; then
    exit 1
  fi

  primaryDeploymentTaskDefn=$(echo $serviceStatus | jq '.deployments | .[0]'| jq '.taskDefinition')

  if [[ $(echo $primaryDeploymentTaskDefn | grep ${ECS_FAMILY_NAME}:${deployRevision}) ]]; then
      echo "{$primaryDeploymentTaskDefn} has been deployed."
  else
    echo "\nTask definition on service does not match the current deployment. \nExpected TaskDefinition: ${ECS_FAMILY_NAME}:${deployRevision} \nDeployment TaskDefinition: ${primaryDeploymentTaskDefn}"
    exit 1
  fi
}

if [ -n "${CI_BUILD_ID}" ]; then
  TAG="${ECS_SERVICE_NAME}.${CI_BRANCH}.${CI_BUILD_ID}" #CodeShip
  BUILD_NO="${CI_BUILD_ID}"
elif [ -n "${GO_PIPELINE_LABEL}" ]; then
  TAG=${ECS_DOCKER_IMAGE_NAME}-${GO_PIPELINE_LABEL} #GoCD
  BUILD_NO=${GO_PIPELINE_LABEL}
else
  echo "This is a local build. Skipping deployment"
  exit 0
fi

# Write out json for register-task-definition call
cat >task-definition.json <<EOF
{
  "family": "${ECS_FAMILY_NAME}",
  "containerDefinitions": [
    {
      "name": "${ECS_DOCKER_IMAGE_NAME}",
      "image": "economist/${ECS_DOCKER_IMAGE_NAME}:${TAG}",
      "cpu": 5,
      "memory": 200,
      "portMappings": [
        {
          "containerPort": 9494,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "syslog",
        "options": {
          "syslog-address": "udp://localhost:5514",
          "syslog-tag": "{{.ImageName}} {{.ID}}"
        }
      },
      "environment": [
          {
              "name": "ENV",
              "value": "${ENV}"
          },
          {
              "name": "DRUPAL_ENDPOINT",
              "value": "${DRUPAL_ENDPOINT}"
          },
          {
              "name": "AWS_S3_BUCKET",
              "value": "${AWS_S3_BUCKET}"
          },
          {
              "name": "AWS_REGION",
              "value": "${ECS_AWS_REGION}"
          },
          {
              "name": "BUILD_NO",
              "value": "${BUILD_NO}"
          }
      ],
      "essential": true
    }
  ]
}
EOF

cat task-definition.json

# Register new task revision, record output revision number
deployRevision=$(aws ecs register-task-definition --cli-input-json file://task-definition.json --region ${ECS_AWS_REGION} | jq '.taskDefinition | .revision')

# Bump the service to use the new revision
aws ecs update-service --cluster ${ECS_CLUSTER_NAME} --service ${ECS_SERVICE_NAME} --task-definition ${ECS_FAMILY_NAME}:${deployRevision} --region ${ECS_AWS_REGION}

check_service_status
