#!/usr/bin/env bash
# assign-record-pages.sh
# Usage: ./scripts/assign-record-pages.sh <target-org-alias>
#
# Sets 4 NEPA Lightning Record Pages as the org default for their sobjectType using the
# Tooling API. The Metadata API cannot set org-default activation for standard/APS objects
# (IndividualApplication, Program, PublicComplaint, Visit) — those objects already have a
# platform default page and the deploy API cannot override the assignment.
#
# The 5 custom-object pages (nepa_engagement__c, nepa_litigation__c, nepa_ce_library__c,
# nepa_decision_payload__c, nepa_decision_log__c) auto-assign as org default when deployed
# because they are the only RecordPage for their object — no script needed for those.
#
# Run after deploy.sh completes:
#   ./scripts/assign-record-pages.sh NEPADEV
#
# Safe to re-run: checks existing assignments before creating duplicates.

set -euo pipefail

TARGET_ORG="${1:-}"
if [[ -z "$TARGET_ORG" ]]; then
    echo "Usage: $0 <target-org-alias>" >&2
    exit 1
fi

# Pages that require scripted org-default assignment
# Format: "FlexiPage_DeveloperName:SobjectType"
declare -a PAGES=(
    "IndividualApplication_Record_Page:IndividualApplication"
    "Program_Record_Page:Program"
    "Public_Comment_Record_Page:PublicComplaint"
    "NEPA_Visit_Record_Page:Visit"
)

step() { echo ""; echo "==> $1"; }
pass() { echo "    ✓ $1"; }
fail() { echo "    ✗ $1"; }
skip() { echo "    – $1 (already set)"; }

step "Assigning NEPA Lightning Record Pages as org default"
echo "    Target org: $TARGET_ORG"

INSTANCE=$(sf org display --target-org "$TARGET_ORG" --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org "$TARGET_ORG" --json | jq -r '.result.accessToken')
TOOLING="$INSTANCE/services/data/v62.0/tooling"

for entry in "${PAGES[@]}"; do
    DEV_NAME="${entry%%:*}"
    SOBJECT_TYPE="${entry##*:}"

    echo ""
    echo "  FlexiPage: $DEV_NAME ($SOBJECT_TYPE)"

    # Look up the FlexiPage Id by DeveloperName
    FP_RESULT=$(curl -s \
        -H "Authorization: Bearer $TOKEN" \
        "$TOOLING/query?q=SELECT+Id,DeveloperName+FROM+FlexiPage+WHERE+DeveloperName='$DEV_NAME'")

    FP_ID=$(echo "$FP_RESULT" | jq -r '.records[0].Id // empty')

    if [[ -z "$FP_ID" ]]; then
        fail "FlexiPage '$DEV_NAME' not found — deploy it first"
        continue
    fi
    echo "    FlexiPage Id: $FP_ID"

    # Check whether an OrgDefault assignment already exists for this FlexiPage
    EXISTING=$(curl -s \
        -H "Authorization: Bearer $TOKEN" \
        "$TOOLING/query?q=SELECT+Id+FROM+FlexiPageRegion+WHERE+FlexiPageId='$FP_ID'+AND+PageContext='OrgDefault'")

    EXISTING_COUNT=$(echo "$EXISTING" | jq '.totalSize // 0')

    if [[ "$EXISTING_COUNT" -gt 0 ]]; then
        skip "$DEV_NAME already assigned as OrgDefault"
        continue
    fi

    # Create the OrgDefault assignment
    PAYLOAD="{\"FlexiPageId\":\"$FP_ID\",\"PageContext\":\"OrgDefault\",\"SobjectType\":\"$SOBJECT_TYPE\"}"
    CREATE_RESULT=$(curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "$TOOLING/sobjects/FlexiPageRegion/")

    NEW_ID=$(echo "$CREATE_RESULT" | jq -r '.id // empty')
    ERRORS=$(echo "$CREATE_RESULT" | jq -r '.message // empty')

    if [[ -n "$NEW_ID" ]]; then
        pass "Assigned $DEV_NAME as OrgDefault (FlexiPageRegion $NEW_ID)"
    else
        fail "Failed to assign $DEV_NAME: $ERRORS"
        echo "    Full response: $CREATE_RESULT"
    fi
done

echo ""
echo "==> Record page assignment complete."
echo "    Reload the org in your browser to see the updated pages."
