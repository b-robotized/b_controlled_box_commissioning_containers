#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# build.sh -- Build the rtw-tools base image locally.
#
# This builds the base image layer that all robot commissioning images
# inherit from. The image is tagged with the full
# public registry path so that downstream Dockerfiles resolve to this local
# build instead of pulling from the remote registry.
#
# Most users do NOT need to run this script. The pre-built base image is
# pulled automatically when you build a robot image. Only run this if you
# need to modify the base layer itself.
# ---------------------------------------------------------------------------

CONTAINER_REGISTRY_URL="code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers"
IMAGE_NAME="rtw-tools"
IMAGE_TAG="jazzy"
FULL_IMAGE_PATH="${CONTAINER_REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building base tooling image..."
echo "  Image tag: ${FULL_IMAGE_PATH}"
echo ""

docker build --network host -f ${IMAGE_NAME}.${IMAGE_TAG}.Dockerfile -t ${FULL_IMAGE_PATH} .

echo ""
echo "Build complete!"
echo ""
echo "  Local image: ${FULL_IMAGE_PATH}"
echo ""
echo "Robot commissioning Dockerfiles reference this image in their FROM line."
echo "Any subsequent robot image builds will now use this local base image."