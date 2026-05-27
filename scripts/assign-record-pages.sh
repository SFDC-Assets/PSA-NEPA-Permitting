#!/usr/bin/env bash
# assign-record-pages.sh
# Usage: ./scripts/assign-record-pages.sh <target-org-alias>
#
# Sets 4 NEPA Lightning Record Pages as the app default for the NEPA_Permitting
# Lightning app using the Tooling API (PageContext='AppDefault').
#
# App-default scopes the page to only the NEPA Permitting app, leaving the
# org-wide default for IndividualApplication, Program, PublicComplaint, and Visit
# untouched for other apps in the same org.
#
# The Metadata API cannot set app-default or org-default activation for standard/APS
# objects (those objects already have a platform default page that the deploy API
# cannot override).
#
# The 5 custom-object pages (nepa_engagement__c, nepa_litigation__c, nepa_ce_library__c,
# nepa_decision_payload__c, nepa_decision_log__c) auto-assign as org default on deploy
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

APP_DEV_NAME="NEPA_Permitting"

# Pages that require scripted app-default assignment
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

step "Assigning NEPA Lightning Record Pages as app default for $APP_DEV_NAME"
echo "    Target org: $TARGET_ORG"

_org_raw=$(sf org display --target-org "$TARGET_ORG" --json 2>/dev/null)
INSTANCE=$(echo "$_org_raw" | python3 -c "import sys,re; d=sys.stdin.read(); print(re.search(r'\"instanceUrl\"\s*:\s*\"([^\"]+)\"',d).group(1))")
TOKEN=$(echo "$_org_raw" | python3 -c "import sys,re; d=sys.stdin.read(); print(re.search(r'\"accessToken\"\s*:\s*\"([^\"]+)\"',d).group(1))")
TOOLING="$INSTANCE/services/data/v62.0/tooling"

# Look up the AppDefinition Id for NEPA_Permitting
echo ""
echo "  Looking up AppDefinition: $APP_DEV_NAME"
APP_RESULT=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$TOOLING/query?q=SELECT+Id,DeveloperName+FROM+AppDefinition+WHERE+DeveloperName='$APP_DEV_NAME'")

APP_ID=$(echo "$APP_RESULT" | jq -r '.records[0].Id // empty')

if [[ -z "$APP_ID" ]]; then
    echo "  ERROR: AppDefinition '$APP_DEV_NAME' not found. Deploy the NEPA_Permitting app first." >&2
    echo "  Full response: $APP_RESULT" >&2
    exit 1
fi
echo "    AppDefinition Id: $APP_ID"

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

    # Check whether an AppDefault assignment already exists for this FlexiPage + app
    EXISTING_Q="SELECT+Id+FROM+FlexiPageRegion+WHERE+FlexiPageId='$FP_ID'+AND+PageContext='AppDefault'+AND+PageContextIdentifier='$APP_ID'"
    EXISTING=$(curl -s \
        -H "Authorization: Bearer $TOKEN" \
        "$TOOLING/query?q=$EXISTING_Q")

    EXISTING_COUNT=$(echo "$EXISTING" | jq '.totalSize // 0')

    if [[ "$EXISTING_COUNT" -gt 0 ]]; then
        skip "$DEV_NAME already assigned as AppDefault for $APP_DEV_NAME"
        continue
    fi

    # Create the AppDefault assignment scoped to NEPA_Permitting
    PAYLOAD=$(printf '{"FlexiPageId":"%s","PageContext":"AppDefault","PageContextIdentifier":"%s","SobjectType":"%s"}' \
        "$FP_ID" "$APP_ID" "$SOBJECT_TYPE")

    CREATE_RESULT=$(curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "$TOOLING/sobjects/FlexiPageRegion/")

    NEW_ID=$(echo "$CREATE_RESULT" | jq -r '.id // empty')
    ERRORS=$(echo "$CREATE_RESULT" | jq -r '.message // empty')

    if [[ -n "$NEW_ID" ]]; then
        pass "Assigned $DEV_NAME as AppDefault for $APP_DEV_NAME (FlexiPageRegion $NEW_ID)"
    else
        fail "Failed to assign $DEV_NAME: $ERRORS"
        echo "    Full response: $CREATE_RESULT"
    fi
done

echo ""
echo "==> Record page assignment complete."
echo "    Pages are now the default when opening records from within the NEPA Permitting app."
echo "    Other apps in the org retain their existing default pages for these objects."
