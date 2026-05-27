#!/usr/bin/env bash
# assign-record-pages.sh
# Usage: ./scripts/assign-record-pages.sh <target-org-alias>
#
# Prints the steps required to assign 4 NEPA Lightning Record Pages as the
# app default for the NEPA_Permitting Lightning app.
#
# NOTE: Salesforce does not expose a public API for setting app-default page
# assignments on standard/APS objects (IndividualApplication, Program,
# PublicComplaint, Visit). The FlexiPageRegion Tooling API object referenced
# in older documentation does not exist in API v62.0. These assignments must
# be made manually in Lightning App Builder.
#
# The 5 custom-object pages (nepa_engagement__c, nepa_litigation__c,
# nepa_ce_library__c, nepa_decision_payload__c, nepa_decision_log__c)
# auto-assign as org default on deploy because they are the only RecordPage
# for their object — no manual step needed for those.
#
# Run after deploy.sh completes:
#   ./scripts/assign-record-pages.sh NEPADEV

set -euo pipefail

TARGET_ORG="${1:-}"
if [[ -z "$TARGET_ORG" ]]; then
    echo "Usage: $0 <target-org-alias>" >&2
    exit 1
fi

APP_DEV_NAME="NEPA_Permitting"

_org_raw=$(sf org display --target-org "$TARGET_ORG" --json 2>/dev/null)
INSTANCE=$(echo "$_org_raw" | python3 -c "import sys,re; d=sys.stdin.read(); print(re.search(r'\"instanceUrl\"\s*:\s*\"([^\"]+)\"',d).group(1))")

echo ""
echo "==> Lightning Record Page app-default assignment"
echo "    Org: $INSTANCE"
echo ""
echo "    Salesforce does not provide a public API for setting app-default"
echo "    page assignments. Complete these steps in Lightning App Builder:"
echo ""

declare -A PAGE_LABELS=(
    ["IndividualApplication_Record_Page"]="NEPA Process Record Page"
    ["Program_Record_Page"]="NEPA Project Record Page"
    ["Public_Comment_Record_Page"]="NEPA Public Comment Record Page"
    ["NEPA_Visit_Record_Page"]="NEPA Visit Record Page"
)

i=1
for DEV_NAME in IndividualApplication_Record_Page Program_Record_Page Public_Comment_Record_Page NEPA_Visit_Record_Page; do
    LABEL="${PAGE_LABELS[$DEV_NAME]}"
    echo "    $i. Setup > Lightning App Builder > open '$LABEL'"
    echo "       Activation > Assign as App Default > select '$APP_DEV_NAME'"
    echo ""
    (( i++ ))
done

echo "    Quick link to Lightning App Builder:"
echo "    $INSTANCE/lightning/setup/AppBuilder/home"
echo ""
echo "==> Custom-object pages (no action needed — auto-assigned on deploy):"
for obj in nepa_engagement__c nepa_litigation__c nepa_ce_library__c nepa_decision_payload__c nepa_decision_log__c; do
    echo "    ✓ $obj"
done
echo ""
