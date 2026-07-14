#!/usr/bin/env bash

# Validates that a merge request has at least one Maintainer approval
# (excluding the author) and reports the result to the MR as a note.
#
# The note is upserted: a single hidden marker identifies the bot's note so
# repeated pipeline runs edit it in place instead of adding new comments.

API="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}"
MR_API="${API}/merge_requests/${CI_MERGE_REQUEST_IID}"
AUTH=(--header "PRIVATE-TOKEN: ${GITLAB_ACCESS_TOKEN}")
MARKER="<!-- mr-approval -->"

REASONS=""

# Append a line to the reason detail shown in the MR note and CI log.
note() {
    REASONS="${REASONS}- ${1}"$'\n'
    echo "${1}"
}

# Upsert the pass/fail result as a single MR note, then exit.
#   $1 = passed|failed   $2 = short summary
report() {
    local status="${1}" summary="${2}"

    local icon="✅"
    [ "${status}" = "failed" ] && icon="❌"
    local body="${MARKER}"$'\n'"${icon} **Maintainer approval check: ${summary}**"$'\n\n'"${REASONS}"

    # Find an existing bot note by its hidden marker.
    local note_id
    note_id=$(
        curl "${MR_API}/notes?per_page=100" --silent --request GET "${AUTH[@]}" |
            jq -r --arg m "${MARKER}" \
                'first(.[] | select(.body | startswith($m)) | .id) // empty'
    )

    if [ -n "${note_id}" ]; then
        curl "${MR_API}/notes/${note_id}" \
            --silent --output /dev/null \
            --request PUT "${AUTH[@]}" \
            --data-urlencode "body=${body}"
        echo "Updated MR note ${note_id} (${status})."
    else
        curl "${MR_API}/notes" \
            --silent --output /dev/null \
            --request POST "${AUTH[@]}" \
            --data-urlencode "body=${body}"
        echo "Posted MR note (${status})."
    fi

    [ "${status}" = "passed" ] && exit 0 || exit 1
}

PROJECT=$(curl "${API}" --silent --request GET "${AUTH[@]}")

# The MR must be gated on a green pipeline for this check to be meaningful.
if [[ $(echo "${PROJECT}" | jq -r '.only_allow_merge_if_pipeline_succeeds') = "false" ]] ||
    [[ $(echo "${PROJECT}" | jq -r '.allow_merge_on_skipped_pipeline') = "true" ]]; then
    note "Enable: Settings -> Merge requests -> Pipelines must succeed"
    note "Disable: Settings -> Merge requests -> Skipped pipelines are considered successful"
    report failed "misconfigured project settings"
fi

MR_APPROVALS=$(curl "${MR_API}/approvals" --silent --request GET "${AUTH[@]}")
MR=$(curl "${MR_API}" --silent --request GET "${AUTH[@]}")

MR_AUTHOR_ID=$(echo "${MR}" | jq -r .author.id)
MAINTAINER_APPROVALS=0

for id in $(echo "${MR_APPROVALS}" | jq -r '.approved_by[].user.id'); do
    if [ "${id}" = "${MR_AUTHOR_ID}" ]; then
        echo "Author approval found; skipping."
        continue
    fi

    USER_INFO=$(curl "${API}/members/all/${id}" --silent --request GET "${AUTH[@]}")
    ACCESS_LEVEL=$(echo "${USER_INFO}" | jq -r '.access_level // 0')

    if [ "${ACCESS_LEVEL}" -ge 40 ]; then
        MAINTAINER_APPROVALS=$((MAINTAINER_APPROVALS + 1))
        APPROVER_NAME=$(echo "${USER_INFO}" | jq -r '.username')
        note "Valid approval from Maintainer: ${APPROVER_NAME}"
    fi
done

if [ "${MAINTAINER_APPROVALS}" -ge 1 ]; then
    report passed "approved by ${MAINTAINER_APPROVALS} Maintainer(s)"
else
    note "Requires approval from at least one Maintainer other than the author."
    report failed "no Maintainer approval"
fi
