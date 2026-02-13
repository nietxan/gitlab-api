#!/usr/bin/env bash

PROJECT=$(
    curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}" \
      --silent \
      --request GET \
      --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}"
)

if [[ $(echo "${PROJECT}" | jq -r '.only_allow_merge_if_pipeline_succeeds') = "false" ]] || 
        [[ $(echo "${PROJECT}" | jq -r '.allow_merge_on_skipped_pipeline') = "true" ]]; then
    echo "Enable: Settings -> Merge requests -> Pipelines must succeed"
    echo "Disable: Settings -> Merge requests -> Skipped pipelines are considered successful"
    exit 1
fi

MR_APPROVALS=$(\
    curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/approvals" \
      --silent \
      --request GET \
      --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}"
)

MR=$(
    curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}" \
      --silent \
      --request GET \
      --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}"
)

MR_AUTHOR_ID=$(echo "${MR}" | jq -r .author.id)
MAINTAINER_APPROVALS=0

for id in $(echo "${MR_APPROVALS}" | jq -r '.approved_by[].user.id'); do
    if [ "${id}" = "${MR_AUTHOR_ID}" ]; then
        echo "Author approval found; skipping."
        continue
    fi

    USER_INFO=$(
        curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/members/all/${id}" \
          --silent \
          --request GET \
          --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}"
    )
    
    ACCESS_LEVEL=$(echo "${USER_INFO}" | jq -r '.access_level // 0')

    if [ "${ACCESS_LEVEL}" -ge 40 ]; then
        MAINTAINER_APPROVALS=$((MAINTAINER_APPROVALS + 1))
        APPROVER_NAME=$(echo "${USER_INFO}" | jq -r '.username')
        echo "Valid approval from Maintainer: ${APPROVER_NAME}"
    fi
done

if [ "${MAINTAINER_APPROVALS}" -ge 1 ]; then
    echo "Success: MR has been approved by at least one Maintainer (excluding author).";
else
    echo "Error: This MR requires approval from at least one Maintainer other than the author.";
    exit 1;
fi
