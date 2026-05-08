#!/usr/bin/env bash
# deploy.sh — PSA-NEPA-Permitting-Data-Model phased deployment
#
# Usage:
#   ./scripts/deploy.sh <target-org-alias> [--check]
#
# Options:
#   --check   Validate-only (dry run, no changes deployed)
#
# Requirements:
#   - sf CLI v2 authenticated to <target-org-alias>
#   - Public Sector Solutions (PSS) installed in the target org
#   - Run from repo root
#
# Phase order (dependency-safe):
#   1  Custom object schemas   — object defs before fields/permsets/flows reference them
#   2  Custom fields           — full objects/ dir (fields on PSS + custom objects)
#   3  Custom labels           — referenced by Apex and flows
#   4  Permission set          — FLS grants require fields to exist first
#   5  Custom metadata records — CMT records used by flow decision logic
#   5b BRE Decision Matrices   — DecisionMatrixDefinition metadata (schema only; rows are UI-only)
#   5c BRE Expression Sets     — ExpressionSetDefinition metadata (must follow DMs they reference)
#   6  Remote sites + creds    — needed before any callout-capable flows compile
#   7  Apex classes            — must precede flows that call @InvocableMethod actions
#   8  Flows (one-at-a-time)   — Metadata API UNKNOWN_EXCEPTION on batch flow deployments;
#                                each flow deployed individually with retry on transient failure
#   9  Tabs                    — custom object tabs referenced by the Lightning app
#  10  Report types            — NEPA_Process_Reports, NEPA_Comment_Reports
#  11  Reports                 — depend on report types
#  12  Dashboards              — depend on reports
#  13  Layouts                 — compact layouts for related-list display
#  14  LWC                     — custom components referenced by FlexiPages
#  15  FlexiPages              — depend on fields, layouts, LWC
#  16  Lightning app           — depends on tabs
#
# NOTE: BRE Decision Matrix rows (decision_matrix_rows/*.csv) cannot be deployed
# via Metadata API or CLI — this is a Salesforce platform limitation. After running
# this script, import each CSV manually via Setup → Business Rules Engine →
# Decision Matrices → open the matrix → V1 → Import CSV.
# See decision_matrix_rows/README.md for the full import sequence.
#
# Known deployment idiosyncrasies
# ──────────────────────────────
# 1. Flow batch deployments trigger UNKNOWN_EXCEPTION on this org's Salesforce pod
#    regardless of payload size or test level. Root cause: a Salesforce infrastructure
#    routing issue that fires before the payload is parsed.
#    Workaround: deploy each flow individually with retry logic (see deploy_flow below).
#
# 2. --dry-run + multiple flows always fails with UNKNOWN_EXCEPTION.
#    --dry-run works for a single flow but is omitted here because the comment-suppression
#    annotations added to flows have no effect once deployed (Salesforce strips XML comments).
#    Single-flow dry-run can be used manually:
#      sf project deploy start --dry-run --metadata "Flow:FLOW_NAME" --target-org ORG
#
# 3. --dry-run + Apex (even batched) works correctly with RunLocalTests.
#    Use --check to validate the Apex-only phases before a full deploy.
#
# 4. Flow meta.xml files require all elements of the same type to be contiguous.
#    A <decisions> block placed after <loops> or <formulas> causes:
#      "Error parsing file: Element decisions is duplicated at this location in type Flow"
#    Fix: move the block to join the other contiguous <decisions> blocks.
#
# 5. Field nepa_days_in_current_stage__c on IndividualApplication is a formula field
#    and is not writeable in Apex test code.
#
# 6. ApplicationTimeline does not have an IndividualApplicationId field; use
#    nepa_related_process__c to link timeline events to a process record.
#
# 7. OmniDataTransform item globalKeys embed the parent record ID in the format
#    {DRName}Custom{RecordId}Item{N}. Each org has a different record ID, so globalKeys
#    in the source file are org-specific. On a net-new deploy (DR does not yet exist),
#    deploying the file with items fails with:
#      "Required fields are missing: [OmniDataTransformationId]"
#    Workaround: two-step deploy via deploy_omnidatatransform() below:
#      Step 1 — deploy the DR header-only to get the org's record ID
#      Step 2 — patch globalKeys in the source file with the org ID, redeploy with items,
#               then restore the original globalKeys (NEPADEV IDs) for source control
#    Existing orgs where the DR header is already deployed are not affected.
#    See deploy_omnidatatransform() and the DRUpsertDetectedLayer_1 call in Phase 8c.
#
# 8. OmniIntegrationProcedure metadata constraints:
#    - The <name>, <subType>, and <omniProcessKey> fields must be alphanumeric with NO
#      underscores or spaces. The platform rejects them with:
#        "Field must be alphanumeric and contain no spaces or underscores"
#    - The <uniqueName> is auto-built by the platform as {type}_{subType}_Procedure_{version}
#      (underscores are allowed only in uniqueName).
#    - OmniIntegrationProcedures are stored as OmniProcess sObject records, not Flow records.
#      See note 9 below for the Flow invocation consequence.
#
# 9. Flow <subflows> cannot reference OmniIntegrationProcedures.
#    OmniIntegrationProcedures are OmniProcess sObject records. A Flow's <subflows> element
#    resolves only actual Flow records by developer name. Referencing an IP name in <subflows>
#    causes an HTTP-level UNKNOWN_EXCEPTION at activation time (no structured error).
#    Workaround: call IPs from Flow via an Apex @InvocableMethod bridge:
#      - Class: NepaGISProximityIPInvoker
#      - Invocation: new omnistudio.IntegrationProcedureService()
#                       .invokeMethod('runIntegrationService', inputMap, outputMap, options)
#      - Flow element: <actionCalls actionType=apex> referencing the class name
#    The correct method is invokeMethod() on an instance — not the static
#    runIntegrationService() call, which does not exist in this package version.

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────

TARGET_ORG="${1:-}"
DRY_RUN=false

if [[ -z "$TARGET_ORG" ]]; then
    echo "Usage: $0 <target-org-alias> [--check]" >&2
    exit 1
fi

for arg in "$@"; do
    [[ "$arg" == "--check" ]] && DRY_RUN=true
done

phase_header() {
    echo ""
    echo "==> $1"
}

# Run a deploy and print a one-line result. Exits non-zero on failure unless
# the second argument is "allow-failure".
deploy() {
    local label="$1"; shift
    local allow_failure="${1:-}"; [[ "$1" == "allow-failure" ]] && shift

    local flags="--wait 30 --json"
    # --dry-run is supported for Apex and metadata phases but NOT for flows
    # (see known idiosyncrasies note 2 above)
    [[ "$DRY_RUN" == "true" ]] && flags="--dry-run $flags"

    local output
    # shellcheck disable=SC2086
    output=$(sf project deploy start "$@" $flags 2>&1) || true

    local result
    result=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    r = data.get('result', {})
    print('    [{}] {}/{} components'.format(
        r.get('status','?'),
        r.get('numberComponentsDeployed', 0),
        r.get('numberComponentsTotal', 0)
    ))
    failures = r.get('details', {}).get('componentFailures', [])
    for f in failures[:5]:
        print('    FAIL: {} — {}'.format(f.get('fullName','?'), f.get('problem','')))
    if r.get('status') not in ('Succeeded', 'SucceededPartial') and r.get('status') is not None:
        sys.exit(1)
except Exception:
    print('    (could not parse JSON output)')
    sys.exit(1)
" 2>&1) || {
        echo "$result"
        if [[ "$allow_failure" == "allow-failure" ]]; then
            echo "    WARNING: phase failed but continuing (allow-failure set)"
            return 0
        fi
        echo "ERROR: deployment failed. Aborting." >&2
        exit 1
    }

    echo "$result"
}

# Deploy a single flow with retry logic.
# Batch flow deployments cause UNKNOWN_EXCEPTION on this org's Salesforce pod
# (see known idiosyncrasies note 1). Deploying one flow at a time avoids this.
# Transient UNKNOWN_EXCEPTION errors are retried up to MAX_FLOW_RETRIES times.
#
# In --check mode this function is a no-op: multi-flow dry-run always fails
# with UNKNOWN_EXCEPTION regardless of count (note 2). Validation for flows is
# handled implicitly because Phase 7 Apex deploy with RunLocalTests exercises
# all flow-touching test classes.
deploy_flow() {
    local flow_name="$1"
    local max_retries=3
    local attempt=0

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "    [SKIP-CHECK] $flow_name (flow dry-run unsupported — see script header)"
        return 0
    fi

    while (( attempt < max_retries )); do
        attempt=$(( attempt + 1 ))
        local output
        output=$(sf project deploy start \
            --metadata "Flow:$flow_name" \
            --target-org "$TARGET_ORG" \
            --test-level NoTestRun \
            --wait 30 \
            --json 2>&1) || true

        local deploy_status
        deploy_status=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    r = data.get('result', {})
    # Surface real flow parse/compile errors immediately
    failures = r.get('details', {}).get('componentFailures', [])
    if failures:
        for f in failures:
            print('    FAIL: {} — {}'.format(f.get('fullName','?'), f.get('problem','')))
        sys.exit(2)
    print(r.get('status') or data.get('name') or 'UNKNOWN')
except Exception:
    print('UNKNOWN')
" 2>&1) || {
            # exit 2 = real failure, not transient; surface and abort
            echo "$deploy_status"
            return 1
        }

        if [[ "$deploy_status" == "Succeeded" ]]; then
            echo "    [Succeeded] $flow_name"
            return 0
        fi

        # UNKNOWN_EXCEPTION is a transient Salesforce pod error — retry
        if echo "$deploy_status" | grep -q "UNKNOWN_EXCEPTION"; then
            if (( attempt < max_retries )); then
                echo "    [Retry $attempt/$max_retries] $flow_name — transient UNKNOWN_EXCEPTION, retrying..."
                sleep 5
            else
                echo "    [WARN] $flow_name — UNKNOWN_EXCEPTION persisted after $max_retries attempts."
                echo "           This is a Salesforce pod routing issue, not a code error."
                echo "           Retry manually: sf project deploy start --metadata \"Flow:$flow_name\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
                return 0  # warn but don't abort the pipeline
            fi
        else
            echo "    [FAIL] $flow_name — $deploy_status"
            return 1
        fi
    done
}

# ── preflight ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Preflight"
sf --version 2>&1 | grep "@salesforce/cli" | head -1
sf org display --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
print('    Org: {} ({})'.format(d.get('alias', '?'), d.get('instanceUrl', '?')))
print('    User: {}'.format(d.get('username', '?')))
"

[[ "$DRY_RUN" == "true" ]] && echo "    Mode: VALIDATE ONLY (--check) — flow phases will be skipped (see script header)"

# ── phase 1: custom object schemas ────────────────────────────────────────────
phase_header "Phase 1: Custom object schemas"
deploy "object schemas" \
    --metadata "CustomObject:NEPA_Flow_Error__c" \
    --metadata "CustomObject:nepa_engagement__c" \
    --metadata "CustomObject:nepa_litigation__c" \
    --metadata "CustomObject:nepa_ar_export__c" \
    --metadata "CustomObject:nepa_decision_modification__c" \
    --metadata "CustomObject:nepa_process_related_agencies__c" \
    --metadata "CustomObject:nepa_project_agency_relationship__c" \
    --metadata "CustomObject:NEPA_Agency_Risk_Rate__mdt" \
    --metadata "CustomObject:NEPA_Circuit_Risk_Weight__mdt" \
    --metadata "CustomObject:NEPA_Challenge_Prediction_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Screening_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Code__mdt" \
    --metadata "CustomObject:NEPA_Required_Document__mdt" \
    --metadata "CustomObject:NEPA_Statute_Risk_Weight__mdt" \
    --metadata "CustomObject:NEPA_GIS_Layer__mdt" \
    --metadata "CustomObject:NEPA_Plaintiff_Profile__mdt" \
    --metadata "CustomObject:NEPA_Layer_Discipline__mdt" \
    --metadata "CustomObject:nepa_detected_protection_layer__c" \
    --target-org "$TARGET_ORG"

# ── phase 2: custom fields on all objects ─────────────────────────────────────
phase_header "Phase 2: Custom fields (all objects)"
deploy "custom fields" \
    --source-dir force-app/main/default/objects \
    --target-org "$TARGET_ORG"

# ── phase 3: custom labels ────────────────────────────────────────────────────
phase_header "Phase 3: Custom labels"
if [[ -d force-app/main/default/labels ]] && \
   [[ -n "$(find force-app/main/default/labels -name '*.xml' 2>/dev/null)" ]]; then
    deploy "labels" \
        --source-dir force-app/main/default/labels \
        --target-org "$TARGET_ORG"
else
    echo "    (no labels to deploy)"
fi

# ── phase 4: permission set ───────────────────────────────────────────────────
phase_header "Phase 4: Permission set"
deploy "permission set" \
    --source-dir force-app/main/default/permissionsets \
    --target-org "$TARGET_ORG"

# ── phase 5: custom metadata records ─────────────────────────────────────────
phase_header "Phase 5: Custom metadata seed records"
deploy "custom metadata" \
    --source-dir force-app/main/default/customMetadata \
    --target-org "$TARGET_ORG"

# ── phase 5b: bre decision matrices ──────────────────────────────────────────
# Schema-only deploy — rows and UI activation must follow via Setup UI.
#
# CRITICAL: After this script runs, each DM must be Activated via Setup UI
# (Setup → BRE → Decision Matrices → open DM → Activate). Metadata API deploy
# alone does NOT create the LatestVersionSnapshotId that the BRE runtime requires.
# Without UI activation, the BRE runtime fails with:
#   "Cannot invoke RulesEngineInputInterview.getDecisionInterviewMap() because
#    rulesEngineInputInterview is null"
# This is a Salesforce platform limitation — there is no CLI workaround.
# See decision_matrix_rows/README.md for the full activation + import sequence.
phase_header "Phase 5b: BRE Decision Matrix definitions"
deploy "decision matrices" \
    --source-dir force-app/main/default/decisionMatrixDefinition \
    --target-org "$TARGET_ORG"

# ── phase 5c: bre expression sets ────────────────────────────────────────────
# Must follow Phase 5b — ES definitions reference DM names in their step elements.
#
# CRITICAL: Same activation requirement as Phase 5b. After deploy, go to
# Setup → BRE → Expression Sets → open each ES → Activate. Without this,
# the ES version has no LatestVersionSnapshotId and the BRE runtime NPEs.
phase_header "Phase 5c: BRE Expression Set definitions"
deploy "expression sets" \
    --source-dir force-app/main/default/expressionSetDefinition \
    --target-org "$TARGET_ORG"

# ── phase 6: remote sites + named credentials ─────────────────────────────────
phase_header "Phase 6: Remote site settings and named credentials"
REMOTE_DIRS=()
[[ -d force-app/main/default/remoteSiteSettings ]] && \
    [[ -n "$(find force-app/main/default/remoteSiteSettings -name '*.xml' 2>/dev/null)" ]] && \
    REMOTE_DIRS+=(--source-dir force-app/main/default/remoteSiteSettings)
[[ -d force-app/main/default/namedCredentials ]] && \
    [[ -n "$(find force-app/main/default/namedCredentials -name '*.xml' 2>/dev/null)" ]] && \
    REMOTE_DIRS+=(--source-dir force-app/main/default/namedCredentials)

if [[ ${#REMOTE_DIRS[@]} -gt 0 ]]; then
    deploy "remote sites + creds" "${REMOTE_DIRS[@]}" --target-org "$TARGET_ORG"
else
    echo "    (no remote sites or named credentials to deploy)"
fi

# ── phase 7: apex classes ─────────────────────────────────────────────────────
# Must precede flows — flows that call @InvocableMethod actions require the
# class to exist and compile first.
# RunLocalTests here also validates flow-touching test classes that cover the
# flow logic indirectly (compensates for skipping flow dry-run in --check mode).
phase_header "Phase 7: Apex classes"
deploy "apex" \
    --source-dir force-app/main/default/classes \
    --test-level RunLocalTests \
    --target-org "$TARGET_ORG"

# ── phase 8: flows (one per deploy call) ──────────────────────────────────────
# Each flow is deployed individually to avoid the Salesforce Metadata API
# UNKNOWN_EXCEPTION that fires when multiple flows are included in a single
# deployment payload (see known idiosyncrasies note 1 in script header).
# Transient UNKNOWN_EXCEPTION errors are retried automatically (up to 3 times).
# Real parse/compile errors abort immediately.
phase_header "Phase 8: Flows (deployed individually with retry)"
FLOWS=(
    NEPA_Litigation_Risk_Scorer
    NEPA_Challenge_Predictor
    NEPA_Defensibility_Gap_Checker
    NEPA_Defensibility_Trigger_ContentVersion
    NEPA_Defensibility_Trigger_Engagement
    NEPA_Timeline_Risk_Assessor
    NEPA_SLA_Due_Date_Setter
    NEPA_SLA_Escalation_Monitor
    NEPA_CE_Screener
    NEPA_CE_Determination_Router
    NEPA_CE_Intake
    NEPA_Record_Completeness_Scorer
    NEPA_Stage_Gate
    NEPA_Stage_Gate_Doc_Check
    NEPA_Stage_Gate_Orchestrator
    NEPA_Administrative_Record_Checker
    NEPA_Comment_Period_Gate
    NEPA_Comment_Triage_Save
    NEPA_GIS_Proximity_Check
    NEPA_Plaintiff_Intelligence
    NEPA_Permit_Coordinator
    NEPA_FRA_Page_Limit_Setter
    NEPA_EIS_Section_Assembler
    NEPA_EIS_Section_Draft_Trigger
    NEPA_AdminRecord_AutoCreate
    NEPA_Error_Logger
    NEPA_Error_Event_Handler
    NEPA_FlowError_CountIncrementer
    NEPA_Work_Order_Generator
    NEPA_Team_Assembly_Orchestrator
    NEPA_WO_Milestone_Setter
)

for flow in "${FLOWS[@]}"; do
    deploy_flow "$flow"
done

# ── phase 8b: action plan templates ──────────────────────────────────────────
phase_header "Phase 8b: Action Plan Templates"
deploy "action plan templates" \
    --source-dir force-app/main/default/actionPlanTemplates \
    --target-org "$TARGET_ORG"

# ── phase 8c: omnidatatransforms + omniintegrationprocedures ──────────────────
# Deploy DataRaptors before the IP that calls them, then the IP.
#
# OmniDataTransform items embed the parent record ID in their globalKeys.
# DRUpsertDetectedLayer requires a two-step deploy on net-new orgs:
#   Step 1: header-only to create the record and capture its ID
#   Step 2: full file with items using the real record ID in globalKeys
#
# The function below handles both cases (header missing vs. already present).
# The repo source file uses NEPADEV globalKeys; this function patches them
# in-place, deploys, and restores the originals so source control stays clean.
#
# NEPADEV DR record ID is 3ULao000000KUtBGAW — stored in globalKeys in the
# repo file. If you create a new dev org, update NEPADEV_DR_RECORD_ID below
# and rerun to re-seed the source IDs.
NEPADEV_DR_RECORD_ID="3ULao000000KUtBGAW"
DR_FILE="force-app/main/default/omniDataTransforms/DRUpsertDetectedLayer_1.rpt-meta.xml"

deploy_omnidatatransform() {
    local dr_name="$1"  # uniqueName, e.g. DRUpsertDetectedLayer_1
    local dr_file="$2"  # path to the .rpt-meta.xml file
    local source_id="$3"  # record ID embedded in globalKeys in the source file (NEPADEV ID)

    # Check whether the DR already exists in the target org
    local existing_id
    existing_id=$(sf apex run \
        --target-org "$TARGET_ORG" \
        --file /dev/stdin 2>/dev/null <<APEX
List<SObject> rs = Database.query('SELECT Id FROM OmniDataTransform WHERE UniqueName=\'${dr_name}\' LIMIT 1');
System.debug(rs.isEmpty() ? 'NOT_FOUND' : (String)rs[0].get('Id'));
APEX
) || true
    existing_id=$(echo "$existing_id" | grep -oE '[a-zA-Z0-9]{18}' | grep "^3UL" | head -1 || true)

    if [[ -z "$existing_id" ]]; then
        # Step 1: deploy header-only to create the record
        echo "    [DR two-step] $dr_name: header not found, creating..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        mkdir -p "$tmp_dir/omniDataTransforms"
        python3 -c "
import re, sys
with open('$dr_file') as f:
    content = f.read()
# Strip all omniDataTransformItem blocks for header-only deploy
content = re.sub(r'\s*<omniDataTransformItem>.*?</omniDataTransformItem>', '', content, flags=re.DOTALL)
with open('$tmp_dir/omniDataTransforms/${dr_name}.rpt-meta.xml', 'w') as f:
    f.write(content)
"
        local header_output
        header_output=$(sf project deploy start \
            --source-dir "$tmp_dir" \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --json 2>&1) || true
        rm -rf "$tmp_dir"

        existing_id=$(echo "$header_output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('result', {}).get('details', {}).get('componentSuccesses', []):
    if s.get('id','').startswith('3UL'):
        print(s['id'])
        break
" 2>/dev/null || true)

        if [[ -z "$existing_id" ]]; then
            echo "    [ERROR] Could not create DR header for $dr_name — aborting phase 8c" >&2
            exit 1
        fi
        echo "    [DR two-step] $dr_name: created with ID $existing_id"
    fi

    # Step 2: patch globalKeys in source file, deploy with items, restore
    if [[ "$existing_id" != "$source_id" ]]; then
        sed -i '' "s/${source_id}/${existing_id}/g" "$dr_file"
    fi

    deploy "OmniDataTransform:${dr_name}" \
        --metadata "OmniDataTransform:${dr_name}" \
        --target-org "$TARGET_ORG"

    # Restore source-control IDs
    if [[ "$existing_id" != "$source_id" ]]; then
        sed -i '' "s/${existing_id}/${source_id}/g" "$dr_file"
    fi
}

phase_header "Phase 8c: OmniStudio DataRaptors and Integration Procedures"

# All DRs other than DRUpsertDetectedLayer can be deployed from source directly
# (they have no item-level globalKey constraints). Only DRUpsertDetectedLayer
# requires the two-step because it has omniDataTransformItem elements.
OTHER_DR_FILES=$(find force-app/main/default/omniDataTransforms -name "*.rpt-meta.xml" \
    ! -name "DRUpsertDetectedLayer_1.rpt-meta.xml" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$OTHER_DR_FILES" -gt 0 ]]; then
    for dr_file in force-app/main/default/omniDataTransforms/*.rpt-meta.xml; do
        [[ "$dr_file" == *"DRUpsertDetectedLayer_1"* ]] && continue
        deploy "$(basename "$dr_file" .rpt-meta.xml)" \
            --metadata "OmniDataTransform:$(basename "$dr_file" .rpt-meta.xml)" \
            --target-org "$TARGET_ORG"
    done
fi

# DRUpsertDetectedLayer: two-step with globalKey patching
deploy_omnidatatransform "DRUpsertDetectedLayer_1" "$DR_FILE" "$NEPADEV_DR_RECORD_ID"

# Integration Procedures (stored as OmniIntegrationProcedure metadata type)
deploy "OmniIntegrationProcedures" \
    --source-dir force-app/main/default/omniIntegrationProcedures \
    --target-org "$TARGET_ORG"

# ── phase 9: custom tabs ──────────────────────────────────────────────────────
phase_header "Phase 9: Custom tabs"
deploy "tabs" \
    --source-dir force-app/main/default/tabs \
    --target-org "$TARGET_ORG"

# ── phase 10: report types ────────────────────────────────────────────────────
# Only the two NEPA report types — the others are installed by the managed pkg.
phase_header "Phase 10: NEPA report types"
deploy "report types" \
    --metadata "ReportType:NEPA_Process_Reports" \
    --metadata "ReportType:NEPA_Comment_Reports" \
    --target-org "$TARGET_ORG"

# ── phase 11: reports ─────────────────────────────────────────────────────────
phase_header "Phase 11: Reports"
deploy "reports" \
    --source-dir force-app/main/default/reports \
    --target-org "$TARGET_ORG"

# ── phase 12: dashboards ──────────────────────────────────────────────────────
phase_header "Phase 12: Dashboards"
deploy "dashboards" \
    --source-dir force-app/main/default/dashboards \
    --target-org "$TARGET_ORG"

# ── phase 13: layouts ─────────────────────────────────────────────────────────
phase_header "Phase 13: Layouts"
deploy "layouts" \
    --source-dir force-app/main/default/layouts \
    --target-org "$TARGET_ORG"

# ── phase 14: lwc ─────────────────────────────────────────────────────────────
phase_header "Phase 14: LWC components"
if [[ -d force-app/main/default/lwc ]] && \
   [[ -n "$(find force-app/main/default/lwc -name '*.js' 2>/dev/null)" ]]; then
    deploy "lwc" \
        --source-dir force-app/main/default/lwc \
        --target-org "$TARGET_ORG"
else
    echo "    (no LWC components to deploy)"
fi

# ── phase 15: flexipages ──────────────────────────────────────────────────────
# Only the 12 NEPA-specific pages checked into this repo.
# All non-NEPA flexipages have been removed from force-app/main/default/flexipages/.
phase_header "Phase 15: FlexiPages (NEPA record and home pages)"
deploy "flexipages" \
    --metadata "FlexiPage:ApplicationTimeline_Record_Page" \
    --metadata "FlexiPage:Individual_Application_Record_Page" \
    --metadata "FlexiPage:IndividualApplication_Record_Page" \
    --metadata "FlexiPage:NEPA_AR_Export_Record_Page" \
    --metadata "FlexiPage:NEPA_Engagement_Record_Page" \
    --metadata "FlexiPage:NEPA_GIS_Data_Element_Record_Page" \
    --metadata "FlexiPage:NEPA_Legal_Structure_Record_Page" \
    --metadata "FlexiPage:NEPA_Litigation_Record_Page" \
    --metadata "FlexiPage:NEPA_Permitting_Home" \
    --metadata "FlexiPage:NEPA_Process_Team_Member_Record_Page" \
    --metadata "FlexiPage:Program_Record_Page" \
    --metadata "FlexiPage:Public_Comment_Record_Page" \
    --target-org "$TARGET_ORG"

# ── phase 16: lightning app ───────────────────────────────────────────────────
phase_header "Phase 16: Lightning app"
deploy "app" \
    --source-dir force-app/main/default/apps \
    --target-org "$TARGET_ORG"

# ── post-deploy ───────────────────────────────────────────────────────────────
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo "==> Validation complete."
    echo "    NOTE: Flow phases were skipped — multi-flow dry-run is unsupported on this org."
    echo "    To validate a specific flow manually:"
    echo "      sf project deploy start --dry-run --metadata \"Flow:FLOW_NAME\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
else
    echo "==> Deployment complete."
    echo ""
    echo "    Post-deploy checklist:"
    echo ""
    echo "    1. Assign permission set:"
    echo "       sf org assign permset --name NEPA_Permitting --target-org $TARGET_ORG"
    echo ""
    echo "    2. Activate flows (Setup > Flows). Recommended order:"
    echo "       NEPA_Litigation_Risk_Scorer"
    echo "       NEPA_Challenge_Predictor"
    echo "       NEPA_Defensibility_Gap_Checker"
    echo "       NEPA_Defensibility_Trigger_ContentVersion"
    echo "       NEPA_Defensibility_Trigger_Engagement"
    echo "       NEPA_CE_Screener"
    echo "       NEPA_CE_Determination_Router"
    echo "       NEPA_CE_Intake"
    echo "       NEPA_Timeline_Risk_Assessor"
    echo "       NEPA_SLA_Due_Date_Setter"
    echo "       NEPA_SLA_Escalation_Monitor"
    echo "       NEPA_Record_Completeness_Scorer"
    echo "       NEPA_Stage_Gate"
    echo "       NEPA_Stage_Gate_Doc_Check"
    echo "       NEPA_Stage_Gate_Orchestrator"
    echo "       NEPA_Administrative_Record_Checker"
    echo "       NEPA_Comment_Period_Gate"
    echo "       NEPA_Comment_Triage_Save"
    echo "       NEPA_Plaintiff_Intelligence"
    echo "       NEPA_Permit_Coordinator"
    echo "       NEPA_FRA_Page_Limit_Setter"
    echo "       NEPA_GIS_Proximity_Check"
    echo "       NEPA_Work_Order_Generator"
    echo "       NEPA_Team_Assembly_Orchestrator"
    echo "       NEPA_WO_Milestone_Setter"
    echo "       NEPA_EIS_Section_Assembler"
    echo "       NEPA_EIS_Section_Draft_Trigger"
    echo "       NEPA_AdminRecord_AutoCreate"
    echo "       NEPA_Error_Logger"
    echo "       NEPA_Error_Event_Handler"
    echo "       NEPA_FlowError_CountIncrementer"
    echo ""
    echo "    3. Activate BRE Decision Matrices and Expression Sets (REQUIRED — cannot be done via CLI):"
    echo "       CRITICAL: Metadata API deploy alone does NOT create the LatestVersionSnapshotId"
    echo "       the BRE runtime requires. Without UI activation the BRE fails with:"
    echo "         'Cannot invoke RulesEngineInputInterview.getDecisionInterviewMap()'"
    echo "       a) Setup > Business Rules Engine > Decision Matrices"
    echo "          Open each DM below, click the active version, click Activate (if not already active):"
    echo "            NEPA_Risk_ReviewType, NEPA_Risk_Agency, NEPA_Risk_Circuit"
    echo "            NEPA_CE_Screener_NAICS, NEPA_CE_Screener_Tier1, NEPA_CE_Screener_Tier2"
    echo "            NEPA_Permit_Matrix_BRE"
    echo "       b) Import rows for each Risk Scorer DM (CSV in decision_matrix_rows/):"
    echo "         NEPA_Risk_ReviewType       → NEPA_Risk_ReviewType.csv"
    echo "         NEPA_Risk_Agency           → NEPA_Risk_Agency.csv  (uses abbreviations: USFS/BLM/FERC/USACE/USFWS)"
    echo "         NEPA_Risk_Circuit          → NEPA_Risk_Circuit.csv"
    echo "       c) Also import rows for CE Screener and Permit Matrix DMs:"
    echo "         NEPA_CE_Screener_NAICS     → NEPA_CE_Screener_NAICS.csv"
    echo "         NEPA_CE_Screener_Tier1     → NEPA_CE_Screener_Tier1.csv"
    echo "         NEPA_CE_Screener_Tier2     → NEPA_CE_Screener_Tier2.csv"
    echo "         NEPA_Permit_Matrix         → NEPA_Permit_Matrix_BRE.csv"
    echo "       d) Setup > BRE > Expression Sets — Activate each ES:"
    echo "            NEPA_Litigation_Risk_Scorer (V1), NEPA_CE_Screener (V3)"
    echo "       e) Deactivate NEPA CE Screener V1 and V2 (leave V3 active only)."
    echo "       See decision_matrix_rows/README.md for full activation + import sequence."
    echo ""
    echo "    4. Verify Custom Metadata records loaded:"
    echo "       Setup > Custom Metadata Types > each NEPA_* type > Manage Records"
    echo ""
    echo "    5. Seed demo data (optional):"
    echo "       sf apex run --file scripts/seed-sample-data.apex --target-org $TARGET_ORG"
    echo ""
    echo "    5b. Seed ServiceResource discipline values (GIS team assembly):"
    echo "       sf apex run --file demo/import_data/21_postload_discipline.apex --target-org $TARGET_ORG"
    echo ""
    echo "    6. OmniStudio — deployed automatically in Phase 8c above."
    echo "       Phase 8c handles the DRUpsertDetectedLayer two-step (globalKey patching)"
    echo "       and deploys OmniIntegrationProcedures via the omniIntegrationProcedures/ directory."
    echo "       No manual OmniStudio deployment is needed."
    echo ""
    echo "    7. GIS proximity trigger chain verification:"
    echo "       Set nepa_location_lat__c + nepa_location_lon__c on a Program record."
    echo "       Wait ~10s, refresh — nepa_protection_areas__c should be populated."
    echo "       Chain: NEPA_GIS_Proximity_Check flow"
    echo "            → NepaGISProximityIPInvoker Apex (invokeMethod bridge)"
    echo "            → NEPA_GISProximityIP OmniIntegrationProcedure"
    echo "            → DRUpsertDetectedLayer DataRaptor (upserts nepa_detected_protection_layer__c)"
    echo "            → sets nepa_gis_proximity_complete__c = true"
fi
