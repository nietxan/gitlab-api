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

APPROVED=0
MR_AUTHOR=$(echo "${MR}" | jq -r .author.id)

for id in $(echo "${MR_APPROVALS}" | jq -r '.approved_by[].user.id'); do
    USER=$(\
        curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/members/all/${id}" \
          --silent \
          --request GET \
          --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}" \
    )

    ACCESS_LEVEL=$(echo "${USER}" | jq -r '.access_level // 0')
    if [ "${ACCESS_LEVEL}" -ge 40 ] || [ "${id}" = "${MR_AUTHOR}" ]; then
        APPROVED=$((APPROVED + 1))
    fi
done

if [ "${APPROVED}" -ge 2 ]; then
    echo "Merge request has been approved!";
else
    echo "Please get approval from at least two members. Current: ${APPROVED}";
    exit 1;
fi
