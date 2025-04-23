#!/bin/bash

set -eu

BUILD_ID=${RANDOM}
RPI_BUILD_SVC="macmind_rpi_w_splash"
RPI_BUILD_USER="imagegen"
RPI_CUSTOMIZATIONS_DIR="macmind_rpi_customizations"
RPI_CONFIG=${RPI_BUILD_SVC}
RPI_OPTIONS=${RPI_BUILD_SVC}
RPI_IMAGE_NAME="macmind_rpi_w_splash"
SAVE_SBOM=1

ensure_cleanup() {
  echo "Cleanup containers..."

  RPI_BUILD_SVC_CONTAINER_ID=$(docker ps -a --filter "name=${RPI_BUILD_SVC}-${BUILD_ID}" --format "{{.ID}}" | head -n 1) \
    && docker kill ${RPI_BUILD_SVC_CONTAINER_ID} \
    && docker rm ${RPI_BUILD_SVC_CONTAINER_ID}

  echo "Cleanup complete."
}

# Set the trap to execute the ensure_cleanup function on EXIT
trap ensure_cleanup EXIT

# Build a customer raspberry pi image
# with the wifi setup service included
#
echo "🔨 Building Docker image with rpi-image-gen to create ${RPI_BUILD_SVC}..."
docker compose build ${RPI_BUILD_SVC}

echo "🚀 Running image generation in container..."
docker compose run --name ${RPI_BUILD_SVC}-${BUILD_ID} -d ${RPI_BUILD_SVC} \
  && docker compose exec ${RPI_BUILD_SVC} bash -c "/home/${RPI_BUILD_USER}/rpi-image-gen/build.sh -D /home/${RPI_BUILD_USER}/${RPI_CUSTOMIZATIONS_DIR} -c ${RPI_CONFIG} -o /home/${RPI_BUILD_USER}/${RPI_CUSTOMIZATIONS_DIR}/${RPI_OPTIONS}.options" \
  && CID=$(docker ps -a --filter "name=${RPI_BUILD_SVC}-${BUILD_ID}" --format "{{.ID}}" | head -n 1) \
  && docker cp ${CID}:/home/${RPI_BUILD_USER}/rpi-image-gen/work/${RPI_IMAGE_NAME}/deploy/${RPI_IMAGE_NAME}.img ./deploy/${RPI_IMAGE_NAME}-$(date +%m-%d-%Y-%H%M).img \

if [[ "${SAVE_SBOM}" == "1" ]]; then
  docker cp ${CID}:/home/${RPI_BUILD_USER}/rpi-image-gen/work/${RPI_IMAGE_NAME}/deploy/${RPI_IMAGE_NAME}.sbom ./deploy/${RPI_IMAGE_NAME}-$(date +%m-%d-%Y-%H%M).sbom
fi

echo "🚀 Completed -> ${RPI_CUSTOMIZATIONS_DIR}/deploy/${RPI_IMAGE_NAME}-$(date +%m-%d-%Y-%H%M).img"
