#!/usr/bin/env bash

if [[ "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}" != "dev" ]]; then
    echo "Skipping non DEV branch..."
    exit 0
fi

IFS=','

for label in ${CI_MERGE_REQUEST_LABELS}; do
    case $label in
        "new-api-test"|"update-api-test"|"no-api-test")
            echo "Found required label: $label. Proceeding."
            exit 0
            ;;
    esac
done

echo -e "Missing one of the required labels:\n- new-api-test\n- update-api-test\n- no-api-test"
exit 1
