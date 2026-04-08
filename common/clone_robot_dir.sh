#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: pull_robot.sh <REPO_URL> <ROBOT_NAME> <TARGET_DIR> [BRANCH]"
  exit 1
fi

REPO_URL=$1
ROBOT_NAME=$2
TARGET_DIR=$3
BRANCH=${4:-master} # master is default

# resolve target dir absolute path w.r.t. call site
mkdir -p "$TARGET_DIR"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo "Pulling workspaces/${ROBOT_NAME} from ${REPO_URL} (Branch: ${BRANCH})..."
echo "Target location: ${TARGET_DIR}"

TMP_DIR=$(mktemp -d)

git clone --filter=blob:none --depth 1 --sparse -b "$BRANCH" "$REPO_URL" "$TMP_DIR"
cd "$TMP_DIR"
git sparse-checkout set "workspaces/${ROBOT_NAME}"

# copy the *contents* of the robot directory into our target directory
cp -a "workspaces/${ROBOT_NAME}/." "$TARGET_DIR/"

cd "$TARGET_DIR"
rm -rf "$TMP_DIR"

echo "✅ Successfully pulled robot workspace."