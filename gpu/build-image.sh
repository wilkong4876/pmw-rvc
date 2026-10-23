#!/usr/bin/env bash
set -euo pipefail
image_ref="${1:?Usage: bash gpu/build-image.sh docker.io/YOUR_ACCOUNT/pmw-rvc:cu128-v1}"
cd "$(dirname "$0")/.."
# Authenticate separately with docker login. Never pass credentials as build args.
docker buildx build --platform linux/amd64 --file gpu/Dockerfile --tag "$image_ref" --push .
printf '\nPublished %s\nSet Sites runtime PMW_GPU_IMAGE to the published digest after a GPU smoke test.\n' "$image_ref"
