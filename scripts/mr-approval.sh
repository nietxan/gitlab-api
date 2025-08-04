#!/usr/bin/env bash

MR_APPROVALS=$(\
    curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/approvals" \
      --silent \
      --request GET \
      --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}" \
)

APPROVED=0

for id in $(echo "${MR_APPROVALS}" | jq -r '.approved_by[].user.id'); do
    USER=$(\
        curl "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/members/all/${id}" \
          --silent \
          --request GET \
          --header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}" \
    )

    ACCESS_LEVEL=$(echo $USER | jq -r '.access_level // 0')
    if [ "${ACCESS_LEVEL}" -ge 40 ]; then
        APPROVED=$((APPROVED + 1))
    fi
done

if [ "${APPROVED}" -ge 2 ]; then
    echo "Merge request has been approved!";
else
    echo "Please get approval from at least two members. Current: ${APPROVED}";
    exit 1;
fi
