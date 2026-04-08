#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# build-robot-image.sh -- Build a robot commissioning image locally.
#
# This script just wraps Docker Build arguments. The result is a LOCAL image only.
#
# The image is tagged with the full public registry path so that start.sh in
# the b_ctrldbox_commissioning repository will find it locally and skip
# pulling from the remote registry.
# ---------------------------------------------------------------------------

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./build-robot-image.sh <ROBOT_MANUFACTURER> <IMAGE_TAG>"
  echo "Example: ./build-robot-image.sh kuka 1.6.x"
  exit 1
fi

ROBOT_MANUFACTURER=$1
IMAGE_TAG=$2

if [ ! -d "$ROBOT_MANUFACTURER" ]; then
  echo "ERROR: Directory '${ROBOT_MANUFACTURER}' does not exist."
  echo "Available directories:"
  ls -d */ 2>/dev/null | grep -v common/ || echo "  (none)"
  exit 1
fi

CONTAINER_REGISTRY_URL="code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers"
IMAGE_NAME="${ROBOT_MANUFACTURER}-commission"
FULL_IMAGE_PATH="${CONTAINER_REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building commissioning image for '${ROBOT_MANUFACTURER}'..."
echo "  Image tag: ${FULL_IMAGE_PATH}"
echo ""

cd "$ROBOT_MANUFACTURER"

DOCKER_BUILDKIT=1 docker build \
  --no-cache \
  --ssh default \
  --network host \
  -f comissioning.Dockerfile \
  --build-arg ROBOT_MANUFACTURER=${ROBOT_MANUFACTURER} \
  -t ${FULL_IMAGE_PATH} .

echo ""
echo "Build complete!"
echo ""
echo "  Local image: ${FULL_IMAGE_PATH}"
echo ""
echo "To use this image, go to your b_ctrldbox_commissioning directory and run:"
echo "  ./start.sh"
echo ""
echo "Make sure your .env file has:"
echo "  ROBOT_TYPE=${ROBOT_MANUFACTURER}"
echo "  VERSION_TAG=${IMAGE_TAG}"