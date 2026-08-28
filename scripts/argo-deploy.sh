#!/usr/bin/env bash
#
# Pins an image tag in devops/argocd/argocd-app so Argo CD rolls it out.

set -eu

GITOPS_HOST="${GITOPS_HOST:-$CI_SERVER_HOST}"
ARGO_REPO="${ARGO_REPO:-devops/argocd/argocd-app}"
ARGO_BRANCH="${ARGO_BRANCH:-main}"
ARGO_CLUSTER="${ARGO_CLUSTER:-${ENVIRONMENT:-}}"
ARGO_SERVICE="${ARGO_SERVICE:-$CI_PROJECT_NAME}"
ARGO_PUSH_RETRIES="${ARGO_PUSH_RETRIES:-5}"
GITOPS_USER_NAME="${GITOPS_USER_NAME:-Argonaut}"
GITOPS_USER_EMAIL="${GITOPS_USER_EMAIL:-argonaut@example.com}"

if [[ -z "$ARGO_CLUSTER" ]]; then
  echo "[ERROR] neither ARGO_CLUSTER nor ENVIRONMENT is set"
  exit 1
fi

git clone --branch "$ARGO_BRANCH" "https://argonaut:${GITOPS_TOKEN}@${GITOPS_HOST}/${ARGO_REPO}.git"
cd "$(basename "$ARGO_REPO")"

IMAGE_FILE="clusters/${ARGO_CLUSTER}/apps/${ARGO_SERVICE}/image.yaml"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "[ERROR] $IMAGE_FILE not found in ${ARGO_REPO}"
  echo "[ERROR] the service must be onboarded to argocd-app before it can deploy this way"
  exit 1
fi

git config user.email "$GITOPS_USER_EMAIL"
git config user.name "$GITOPS_USER_NAME"

export DEPLOY_TAG="${IMAGE_TAG:-${CI_COMMIT_SHORT_SHA}}"

yq e '.image.tag = strenv(DEPLOY_TAG)' -i "$IMAGE_FILE"

if git diff --quiet -- "$IMAGE_FILE"; then
  echo "[INFO] tag already $DEPLOY_TAG, nothing to push"
  exit 0
fi

git add "$IMAGE_FILE"
git commit -m "deploy(${ARGO_CLUSTER}/${ARGO_SERVICE}): ${DEPLOY_TAG}"

attempt=1
while true; do
  if git push origin "HEAD:${ARGO_BRANCH}"; then
    echo "[INFO] ${IMAGE_FILE} pinned to ${DEPLOY_TAG}"
    exit 0
  fi

  if [ "$attempt" -ge "$ARGO_PUSH_RETRIES" ]; then
    echo "[ERROR] push rejected after ${ARGO_PUSH_RETRIES} attempts"
    exit 1
  fi

  echo "[WARN] push rejected, rebasing onto origin/${ARGO_BRANCH} (attempt ${attempt}/${ARGO_PUSH_RETRIES})"
  if ! git pull --rebase origin "$ARGO_BRANCH"; then
    git rebase --abort || true
    echo "[ERROR] could not rebase onto origin/${ARGO_BRANCH}"
    exit 1
  fi

  attempt=$((attempt + 1))
  sleep "$attempt"
done
