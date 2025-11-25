#!/usr/bin/env bash
set -euo pipefail

# Build directory and outputs
BUILD_DIR="$(pwd)/build"
LAYER_DIR="${BUILD_DIR}/python"
PKG_ZIP="${BUILD_DIR}/crypto_updater.zip"

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${LAYER_DIR}"

echo "Installing dependencies into ${LAYER_DIR} (using amazonlinux docker image)..."

# Use Docker to install packages compatible with Lambda's Amazon Linux environment.
docker run --rm -v "${LAYER_DIR}":/var/task -w /var/task python:3.12-slim bash -c "\
    pip install --target /var/task requests psycopg2-binary \
"

# Copy lambda handler files into build root
cp lambda_function.py "${BUILD_DIR}/"
pushd "${BUILD_DIR}" > /dev/null

# Create a zip with python packages and handler at root
zip -r9 "${PKG_ZIP}" . -x "*/__pycache__/*"

popd > /dev/null

echo "Created ${PKG_ZIP}"
