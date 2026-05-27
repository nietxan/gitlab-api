#!/usr/bin/env bash

set -eu

GITOPS_HOST="${GITOPS_HOST:-$CI_SERVER_HOST}"
GITOPS_REPO="${GITOPS_REPO:-devops/gitops}"
GITOPS_USER_NAME="${GITOPS_USER_NAME:-Argonaut}"
GITOPS_USER_EMAIL="${GITOPS_USER_EMAIL:-argonaut@example.com}"

git clone "https://argonaut:${GITOPS_TOKEN}@${GITOPS_HOST}/${GITOPS_REPO}.git"
cd "$(basename "$GITOPS_REPO")"

IMAGE_FILE="services/${CI_PROJECT_NAME}/image.yaml"
if [ ! -f "$IMAGE_FILE" ]; then
  echo "[ERROR] $IMAGE_FILE not found in gitops"
  exit 1
fi

git config user.email "$GITOPS_USER_EMAIL"
git config user.name "$GITOPS_USER_NAME"

yq e '.image.tag = strenv(CI_COMMIT_SHORT_SHA)' -i "$IMAGE_FILE"

if git diff --quiet -- "$IMAGE_FILE"; then
  echo "[INFO] tag already $CI_COMMIT_SHORT_SHA, nothing to push"
  exit 0
fi

git add "$IMAGE_FILE"
git commit -m "deploy(${CI_PROJECT_NAME}) - ${CI_COMMIT_SHORT_SHA}"
git push origin main
