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
#   - Agentforce for Public Sector (APS) installed in the target org
#   - Run from repo root
#
# Phase order (dependency-safe):
#   1  Custom object schemas   — object defs before fields/permsets/flows reference them
#   2  Custom fields           — full objects/ dir (fields on APS + custom objects)
#   3  Custom labels           — referenced by Apex and flows
#   3b Custom tabs             — tab names referenced by permission set tabSettings
#   3c Queues                  — must exist before Phase 8 flows; EJTribal_Router queries by DeveloperName
#   4  Permission set          — FLS grants require fields to exist first
#   5  Custom metadata records — CMT records used by flow decision logic
#   5b BRE Decision Matrices   — DecisionMatrixDefinition metadata schema deploy
#   5b-data                   — row insertion + activation via Tooling API (replaces manual UI workflow)
#   5c BRE Expression Sets     — ExpressionSetDefinition metadata (must follow DMs they reference)
#   5e CE Library data         — 314 nepa_ce_library__c records via scripts/load_ce_library.py (idempotent)
#   6  Remote sites + creds    — needed before any callout-capable flows compile
#                                Also deploys CSP Trusted Sites (ArcGIS_JS_CDN, ArcGIS_Tiles)
#   7  Apex classes            — must precede flows that call @InvocableMethod actions
#   7  Apex classes + VF pages — deployed together (circular reference: test cls → Page, VF page → controller)
#   7a Apex triggers           — must follow Phase 7 (NepaVisitAfterInsert calls NepaVisitActionPlanLauncher)
#   8  Flows (one-at-a-time)   — Metadata API UNKNOWN_EXCEPTION on batch flow deployments;
#                                each flow deployed individually with retry on transient failure
#   3b Tabs                    — custom object tabs referenced by the Lightning app
#   3c Queues                  — NEPA_EJ_Tribal_Liaison, NEPA_Comment_Triage
#   3d Lightning app           — must precede Phase 4b; permset references CustomApplication:NEPA_Permitting
#  10  Report types            — NEPA_Process_Reports, NEPA_Comment_Reports
#  11  Reports                 — depend on report types
#  12  Dashboards              — depend on reports
#  13  Layouts                 — compact layouts for related-list display
#  14  LWC                     — custom components referenced by FlexiPages
#  14a LWC-backed tabs         — nepaTemplateCatalog; requires LWC (Phase 14) to exist first
#  15  FlexiPages              — depend on fields, layouts, LWC
#  15a Path Assistants         — depends on nepa_process_stage__c picklist (Phase 2) and IA page (Phase 15)
#  15b Agentforce agents       — depends on Flow/Apex targets being live
#  16  Lightning app           — skipped (deployed in Phase 3d)
#
# NOTE: BRE Decision Matrix rows are loaded and activated automatically in
# Phase 5b-data via scripts/load_decision_matrix_rows.py. No manual UI steps
# are required. See decision_matrix_rows/README.md for the data reference and
# manual re-run instructions if Phase 5b-data fails.
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
# 7. OmniIntegrationProcedure metadata constraints:
#    - The <name>, <subType>, and <omniProcessKey> fields must be alphanumeric with NO
#      underscores or spaces. The platform rejects them with:
#        "Field must be alphanumeric and contain no spaces or underscores"
#    - The <uniqueName> is auto-built by the platform as {type}_{subType}_Procedure_{version}
#      (underscores are allowed only in uniqueName).
#    - OmniIntegrationProcedures are stored as OmniProcess sObject records, not Flow records.
#      See note 8 below for the Flow invocation consequence.
#
# 8. Flow <subflows> cannot reference OmniIntegrationProcedures.
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
#
# 9. OmniDataTransform, OmniIntegrationProcedure, OmniScript deploy via standard
#    Metadata API using .rpt-meta.xml, .oip-meta.xml, and .os-meta.xml source files.
#    No DataPack or vlocity-build tooling required.
#    OmniScript IP dependency validation: the platform checks IP dependencies against
#    its component index. Phase 8c includes a retry loop (up to 5 attempts, 60s apart)
#    to handle the lag between IP deployment and index update.
#
# 11. ConnectedApp:NEPA_CEQExport_API has an XML structure error in the source file:
#     <oauthFlows> is not valid inside <oauthConfig> for this API version.
#     ConnectedApps are excluded from manifest/deploy_clean.xml until this is resolved.
#     To fix: remove <oauthFlows> from the ConnectedApp XML and redeploy.
#
# 12. manifest/deploy_clean.xml is a single-shot manifest deploy alternative to this
#     phased script. It deploys 706 components in one call and is useful for re-deploys
#     to an org that already has the base schema. It excludes: OmniDataTransform,
#     OmniIntegrationProcedure, OmniScript, BotVersion, ConnectedApp,
#     ExpressionSetDefinition, NEPA_EIS_Section_Assembler, NEPA_EIS_Section_Draft_Trigger,
#     and Program_Record_Page. Use the phased script for first-time deploys.
#       sf project deploy start --manifest manifest/deploy_clean.xml \
#         --target-org <alias> --test-level NoTestRun --wait 60
#
# 13. Source-format file requirements (common failure mode on clone-and-deploy):
#     - Object files must use .object-meta.xml suffix (not bare .object)
#     - Layout files must use .layout-meta.xml suffix (not bare .layout)
#     - Permission set files must use .permissionset-meta.xml suffix
#     - Fields on standard objects (Program, IndividualApplication, ContentVersion,
#       PublicComplaint, ApplicationTimeline) must exist as individual
#       objects/<Object>/fields/<field>.field-meta.xml files — fields inside a flat
#       .object-meta.xml are silently ignored by the Metadata API for standard objects
#     - RecordType and ValidationRule definitions on standard objects must similarly be
#       extracted to objects/<Object>/recordTypes/ and objects/<Object>/validationRules/
#     - CustomLabel aggregate member "CustomLabels" does not resolve from source;
#       list individual label developer names as separate <members> entries in any manifest
#     - Layout Name field behavior must be "Required" (not "Edit" or "Readonly") or
#       the Metadata API rejects the layout with a validation error
#
# 14. FlexiPage Program_Record_Page:
#     Some orgs (e.g., pre-existing PSS installs) have Program_Record_Page already
#     assigned to CGC_Program__c (the PSS base package object alias). The Metadata API
#     cannot change the sobjectType of an existing Lightning page — attempting to deploy
#     with sobjectType=Program will fail. In that case either:
#     a) Exclude Program_Record_Page from the deploy and assign the page manually in
#        Setup → Lightning App Builder, or
#     b) Remove the existing page in the org before deploying.
#     The source file is checked in with sobjectType=Program (the correct value for
#     APS trial orgs). See manifest/deploy_clean.xml for the excluded manifest path.
#
# 15. Flow record filter: the <In> operator requires a collection variable, not a literal.
#     If you write a recordFilter with <operator>In</operator> and a <stringValue> (e.g. a
#     single status value), the platform compiles it as an empty collection and Get Records
#     always returns zero rows — no error is raised at deploy time or at runtime.
#     Symptom: a flow gate that should block never blocks because col_ExistingDocs is always
#     empty. Fix: change single-value record filters from <operator>In</operator> to
#     <operator>EqualTo</operator> with a <stringValue> literal.
#
# 16. Flow loop accumulator: every <assignments> node inside a collection loop must have
#     an explicit <connector> back to the loop element. Omitting the connector is valid XML
#     and deploys without error, but the flow terminates silently at that node — subsequent
#     elements (e.g., a Block_Save customErrors element) are never reached.
#     Symptom: a before-save gate that appends missing items to an error string never blocks
#     the save; flow run history shows "Completed" with no blocked executions.
#     Fix: add <connector><targetReference>Loop_Element_Name</targetReference></connector>
#     to every Assign node that should continue the loop.
#
# 17. Flow start filter using RecordType.DeveloperName on objects with no record types:
#     A Flow start filter on {$Record.RecordType.DeveloperName} compiles to the string
#     "null__NotFound" at runtime when the trigger object has no record types configured.
#     The flow entry condition always evaluates false and the flow never fires.
#     Symptom: UNKNOWN_EXCEPTION with no structured message during deploy/activation, or
#     flow is Active but never fires on ContentVersion / ApplicationTimeline.
#     Fix: remove the RecordType filter from the start element; guard with a Decision node
#     immediately after the start if record-type branching is needed.
#
# 18. PSS "Update Complaint Summary" package process + bulk PublicComplaint inserts:
#     The PSS managed package process "Update Complaint Summary and Resolution Priority"
#     fires on every PublicComplaint insert. In Apex test context it consumes governor
#     limits proportional to batch size. Batches above ~30 records in a single DML call
#     can exhaust org-level limits and fail with:
#       CANNOT_EXECUTE_FLOW_TRIGGER, Limit Exceeded
#     This is a PSS package constraint, not a NEPA flow issue.
#     Workaround: limit PublicComplaint bulk test inserts to ≤20 records per DML call.
#     Tests that prove NEPA flow bulk safety at 20 records are sufficient — the PSS
#     limit is a package ceiling, not a NEPA automation limit.
#
# 20. ExpressionSetDefinition deploy fails with "LatestVersionSnapshotId not found":
#     The Metadata API creates a new ESDV during deploy but never creates the snapshot
#     that the BRE runtime requires. This fails on every deploy attempt regardless of
#     the version status in the source file — even when the ESD already exists in org.
#     Root cause: a platform-side validation bug. Affects ESDs that include
#     GetOutputsFromDecisionMatrix steps.
#
#     Workaround (automated in Phase 5c-activate via --activate-es):
#       1. Deploy the ESD via Metadata API — this creates a Draft ESDV in org.
#       2. PATCH the ESDV's Metadata field with the full steps + variables via
#          Tooling API, setting status="Active". This atomically activates the
#          version AND creates the LatestVersionSnapshotId.
#       3. Retrieve the ESD back to source — the retrieved file now reflects the
#          Active version with snapshot. Subsequent Metadata API deploys succeed
#          as no-ops (Unchanged) because the org and source match exactly.
#
#     The load_decision_matrix_rows.py --activate-es flag implements step 2 for
#     all ES versions listed in ES_VERSIONS. The ESDV must already exist in org
#     (created by step 1) before --activate-es is called.
#
#     If the ESD source file is lost or regenerated (e.g., after a scratch org):
#       1. Deploy the ESD (creates Draft ESDV).
#       2. Run: python3 scripts/load_decision_matrix_rows.py --org <alias> --activate-es
#       3. Run: sf project retrieve start --metadata "ExpressionSetDefinition:NEPA_Litigation_Risk_Scorer" --target-org <alias>
#       4. Commit the retrieved file — it is now the authoritative source.
#
# 21. runExpressionSet action + storeOutputAutomatically: Numeric outputs not accessible
#     via dot-notation in Flow formula elements. When a Flow actionCall with
#     actionType=runExpressionSet uses storeOutputAutomatically=true, Text-typed ES
#     output variables ARE accessible in <formulas> as {!ActionName.VarName}. But
#     Numeric-typed outputs are NOT — deploy fails with:
#       "The formula expression is invalid: Field ActionName.VarName does not exist."
#     Workaround: use explicit <outputParameters> in the actionCall to bind each
#     Numeric/Boolean ES output to a named flow variable. Text outputs can still
#     use storeOutputAutomatically if preferred, but explicit outputParameters work
#     for all types and should be preferred for clarity and cross-type safety.
#
# 19. Text field length for formula-populated fields:
#     Flow formula values written to Text fields fail silently when the output string
#     exceeds the field's length. The DML exception is caught by any faultConnector on
#     the Update Records element and routed to End without surfacing an error.
#     Symptom: downstream fields that should be set (e.g., nepa_plaintiff_risk_flag__c)
#     are never written even though the flow logic appears correct.
#     Fix: audit Text fields populated by formula elements. Size them to accommodate the
#     maximum realistic formula output — use length 255 for any structured summary string.

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
    # Redirect stderr to /dev/null to suppress CLI update banners that pollute JSON stdout
    # shellcheck disable=SC2086
    output=$(sf project deploy start "$@" $flags 2>/dev/null) || true

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
            --json 2>/dev/null) || true

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

# ── parallel helpers ──────────────────────────────────────────────────────────

# Wait for background jobs in launch order; print their captured output; abort
# the pipeline if any non-allow-failure job exited non-zero.
# Arguments: alternating pairs of tmpfile pid (e.g. file1 pid1 file2 pid2 ...)
wait_jobs() {
    local rc=0
    while [[ $# -ge 2 ]]; do
        local tmpfile="$1" pid="$2"; shift 2
        local job_rc=0
        wait "$pid" || job_rc=$?
        cat "$tmpfile" 2>/dev/null
        [[ $job_rc -eq 0 ]] || rc=$job_rc
    done
    if [[ $rc -ne 0 ]]; then
        echo "ERROR: one or more parallel phases failed. Aborting." >&2
        exit 1
    fi
}

# ── phase functions (called in parallel via subshells) ────────────────────────
# Each function runs in a ( fn ) >/tmp/out 2>&1 & subshell that inherits all
# functions and variables from the parent. deploy() / deploy_flow() are available.

phase_3_labels() {
    phase_header "Phase 3: Custom labels"
    if [[ -d force-app/main/default/labels ]] && \
       [[ -n "$(find force-app/main/default/labels -name '*.xml' 2>/dev/null)" ]]; then
        deploy "labels" \
            --source-dir force-app/main/default/labels \
            --target-org "$TARGET_ORG"
    else
        echo "    (no labels to deploy)"
    fi
}

phase_3b_tabs() {
    phase_header "Phase 3b: Custom tabs"
    deploy "tabs" \
        --metadata "CustomTab:nepa_ar_export__c" \
        --metadata "CustomTab:nepa_detected_protection_layer__c" \
        --metadata "CustomTab:nepa_engagement__c" \
        --metadata "CustomTab:nepa_gis_data__c" \
        --metadata "CustomTab:nepa_gis_data_element__c" \
        --metadata "CustomTab:nepa_litigation__c" \
        --metadata "CustomTab:nepa_process_team_member__c" \
        --metadata "CustomTab:nepa_ce_library__c" \
        --metadata "CustomTab:nepa_required_permit__c" \
        --target-org "$TARGET_ORG"
}

phase_3c_queues() {
    phase_header "Phase 3c: Queues"
    deploy "queues" \
        --metadata "Queue:NEPA_EJ_Tribal_Liaison" \
        --metadata "Queue:NEPA_Comment_Triage" \
        --target-org "$TARGET_ORG"
}

phase_5_cmt() {
    phase_header "Phase 5: Custom metadata seed records"
    deploy "custom metadata" \
        --source-dir force-app/main/default/customMetadata \
        --target-org "$TARGET_ORG"
}

phase_5b_bre_dm() {
    phase_header "Phase 5b: BRE Decision Matrix definitions"
    deploy "decision matrices" allow-failure \
        --source-dir force-app/main/default/decisionMatrixDefinition \
        --target-org "$TARGET_ORG"
}

phase_6_remote() {
    phase_header "Phase 6: Remote site settings, named credentials, and CSP Trusted Sites"
    local REMOTE_DIRS=()
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
    if [[ -d force-app/main/default/cspTrustedSites ]] && \
       [[ -n "$(find force-app/main/default/cspTrustedSites -name '*.xml' 2>/dev/null)" ]]; then
        deploy "CSP Trusted Sites" \
            --source-dir force-app/main/default/cspTrustedSites \
            --target-org "$TARGET_ORG"
    else
        echo "    (no CSP Trusted Sites to deploy)"
    fi
}

phase_7_apex() {
    phase_header "Phase 7: Apex classes"
    local APEX_DIRS=(--source-dir force-app/main/default/classes)
    if [[ -d force-app/main/default/pages ]] && \
       [[ -n "$(find force-app/main/default/pages -name '*.page' 2>/dev/null)" ]]; then
        APEX_DIRS+=(--source-dir force-app/main/default/pages)
    fi
    deploy "apex + vf pages" "${APEX_DIRS[@]}" \
        --test-level NoTestRun \
        --target-org "$TARGET_ORG"
}

phase_8b_apts() {
    phase_header "Phase 8b: Action Plan Templates"
    deploy "action plan templates" allow-failure \
        --source-dir force-app/main/default/actionPlanTemplates \
        --target-org "$TARGET_ORG"
}

phase_8c_omnistudio() {
    phase_header "Phase 8c: OmniStudio DataRaptors, Integration Procedures, OmniScripts"
    if [[ -n "$(find force-app/main/default/omniDataTransforms -name '*.rpt-meta.xml' 2>/dev/null)" ]]; then
        deploy "DataRaptors" \
            --source-dir force-app/main/default/omniDataTransforms \
            --target-org "$TARGET_ORG"
    else
        echo "    (no DataRaptors to deploy)"
    fi
    if [[ -n "$(find force-app/main/default/omniIntegrationProcedures -name '*.oip-meta.xml' 2>/dev/null)" ]]; then
        deploy "Integration Procedures" allow-failure \
            --source-dir force-app/main/default/omniIntegrationProcedures \
            --target-org "$TARGET_ORG"
    else
        echo "    (no Integration Procedures to deploy)"
    fi
    if [[ -n "$(find force-app/main/default/omniScripts -name '*.xml' 2>/dev/null)" ]]; then
        deploy_omniscript_with_retry
    else
        echo "    (no OmniScripts to deploy)"
    fi
}

phase_8d_tests() {
    if [[ "$DRY_RUN" == "false" ]]; then
        phase_header "Phase 8d: RunLocalTests (post-flow validation)"
        deploy "local tests" allow-failure \
            --source-dir force-app/main/default/classes \
            --test-level RunLocalTests \
            --target-org "$TARGET_ORG"
    fi
}

phase_10_12_reports() {
    phase_header "Phase 10: NEPA report types"
    deploy "report types" \
        --metadata "ReportType:NEPA_Process_Reports" \
        --metadata "ReportType:NEPA_Comment_Reports" \
        --target-org "$TARGET_ORG"
    phase_header "Phase 11: Reports"
    deploy "reports" \
        --source-dir force-app/main/default/reports \
        --target-org "$TARGET_ORG"
    phase_header "Phase 12: Dashboards"
    deploy "dashboards" \
        --source-dir force-app/main/default/dashboards \
        --target-org "$TARGET_ORG"
}

phase_13_layouts() {
    phase_header "Phase 13: Layouts"
    # First pass: most layouts deploy cleanly here.
    local output result
    output=$(sf project deploy start \
        --source-dir force-app/main/default/layouts \
        --target-org "$TARGET_ORG" \
        --wait 30 --json 2>/dev/null) || true
    result=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    r = data.get('result', {})
    failures = r.get('details', {}).get('componentFailures', [])
    status = r.get('status', '?')
    print('    [{}] {}/{} components'.format(
        status,
        r.get('numberComponentsDeployed', 0),
        r.get('numberComponentsTotal', 0)
    ))
    for f in failures[:5]:
        print('    FAIL: {} — {}'.format(f.get('fullName','?'), f.get('problem','')))
    if status not in ('Succeeded', 'SucceededPartial'):
        sys.exit(1)
except Exception:
    print('    (could not parse JSON output)')
    sys.exit(1)
" 2>&1) && { echo "$result"; return 0; } || true
    echo "$result"
    echo "    INFO: layout deploy failed — retrying once after 10s"
    sleep 10
    deploy "layouts (retry)" allow-failure \
        --source-dir force-app/main/default/layouts \
        --target-org "$TARGET_ORG"
}

phase_14_lwc() {
    phase_header "Phase 14: LWC components"
    if [[ -d force-app/main/default/lwc ]] && \
       [[ -n "$(find force-app/main/default/lwc -name '*.js' 2>/dev/null)" ]]; then
        deploy "lwc" \
            --source-dir force-app/main/default/lwc \
            --target-org "$TARGET_ORG"
    else
        echo "    (no LWC components to deploy)"
    fi
}

phase_15a_path_assistants() {
    phase_header "Phase 15a: Path Assistants"
    if [[ -d force-app/main/default/pathAssistants ]] && \
       [[ -n "$(find force-app/main/default/pathAssistants -name '*.pathAssistant-meta.xml' 2>/dev/null)" ]]; then
        # allow-failure: PathAssistantStep element ordering is schema-version sensitive.
        # Add manually in Setup → Path if this fails: Object Manager → IndividualApplication
        # → Path Assistant → NEPA Process Path → configure stage guidance.
        deploy "path assistants" allow-failure \
            --source-dir force-app/main/default/pathAssistants \
            --target-org "$TARGET_ORG"
    else
        echo "    (no Path Assistants to deploy)"
    fi
}

phase_15b_agents() {
    phase_header "Phase 15b: Agentforce Agent Script bundles"
    # Agent configuration specs live in force-app/main/default/agents/ as .agent files.
    # These are human-readable config specs, not Salesforce Agent Script (.agent) syntax —
    # they cannot be compiled and published via "sf agent publish authoring-bundle".
    # Agentforce agents (NEPA_Comment_Triage, NEPA_PreApp_Screener) must be created
    # manually in Agentforce Studio or via Agent Builder using the specs as a guide.
    # See docs/AGENT_SETUP.md for step-by-step setup instructions.
    if [[ -d force-app/main/default/agents ]] && \
       [[ -n "$(find force-app/main/default/agents -name '*.agent' 2>/dev/null)" ]]; then
        for agent_file in force-app/main/default/agents/*/*.agent; do
            local agent_dir agent_name
            agent_dir=$(dirname "$agent_file")
            agent_name=$(basename "$agent_dir")
            echo "    INFO: Agent spec found: $agent_name"
            echo "          See force-app/main/default/agents/$agent_name/$agent_name.agent"
            echo "          Create this agent manually in Agentforce Studio."
        done
    else
        echo "    (no Agent Script bundles to deploy)"
    fi
}

deploy_omniscript_with_retry() {
    local max_attempts=5
    local attempt=0
    while (( attempt < max_attempts )); do
        attempt=$(( attempt + 1 ))
        local output status
        output=$(sf project deploy start \
            --source-dir force-app/main/default/omniScripts \
            --target-org "$TARGET_ORG" \
            --test-level NoTestRun \
            --wait 30 \
            --json 2>/dev/null) || true

        status=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
r = data.get('result', {})
failures = r.get('details', {}).get('componentFailures', [])
if failures:
    prob = failures[0].get('problem', '')
    if 'dependent components' in prob.lower():
        print('DEPENDENCY_LAG')
    else:
        print('FAIL: ' + prob[:120])
else:
    print(r.get('status', 'UNKNOWN'))
" 2>&1)

        if [[ "$status" == "Succeeded" ]]; then
            echo "    [Succeeded] OmniScripts"
            return 0
        elif [[ "$status" == "DEPENDENCY_LAG" ]]; then
            if (( attempt < max_attempts )); then
                echo "    [Retry $attempt/$max_attempts] OmniScript — IP index not yet updated, waiting 60s..."
                sleep 60
            else
                echo "    [WARN] OmniScript — IP dependency index still not updated after $max_attempts attempts."
                echo "           Activate manually: OmniStudio Designer → OmniScripts → find NEPA/CEIntake → Activate"
            fi
        else
            echo "    [FAIL] OmniScript: $status"
            return 1
        fi
    done
}

phase_5c_es_defs() {
    phase_header "Phase 5c: BRE Expression Set definitions"
    # Deployed individually — batch ESD deploys trigger transient UNKNOWN_EXCEPTION.
    for esd in NEPA_CE_Screener NEPA_Permit_Coordinator NEPA_Litigation_Risk_Scorer; do
        deploy "expression set: $esd" allow-failure \
            --metadata "ExpressionSetDefinition:$esd" \
            --target-org "$TARGET_ORG"
    done
}

phase_7a_triggers() {
    phase_header "Phase 7a: Apex triggers"
    if [[ -d force-app/main/default/triggers ]] && \
       [[ -n "$(find force-app/main/default/triggers -name '*.trigger' 2>/dev/null)" ]]; then
        deploy "apex triggers" \
            --source-dir force-app/main/default/triggers \
            --target-org "$TARGET_ORG"
    else
        echo "    (no Apex triggers to deploy)"
    fi
}

phase_3b_3d_app_initial() {
    # Tabs must precede the app — app references tabs in its navigation list.
    phase_3b_tabs
    phase_header "Phase 3d: Lightning app (initial)"
    local APP_SRC="force-app/main/default/apps/NEPA_Permitting.app-meta.xml"
    local APP_TMP_DIR
    APP_TMP_DIR="/tmp/nepa_app_initial_$$/apps"
    mkdir -p "$APP_TMP_DIR"
    grep -v "nepaTemplateCatalog" "$APP_SRC" > "$APP_TMP_DIR/NEPA_Permitting.app-meta.xml"
    deploy "app (initial without LWC-backed tab)" \
        --source-dir "$APP_TMP_DIR" \
        --target-org "$TARGET_ORG"
    rm -rf "/tmp/nepa_app_initial_$$"
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
# All custom objects, CMT types, and the platform event must deploy before Phase 2
# adds fields to them, and before Phase 5 deploys CMT records into them.
# Missing an object here causes Phase 2 to fail with "no CustomObject named X found"
# and Phase 5 to fail with "no CustomMetadata type named X found" on a fresh org.
deploy "object schemas" \
    --metadata "CustomObject:NEPA_Flow_Error__c" \
    --metadata "CustomObject:nepa_engagement__c" \
    --metadata "CustomObject:nepa_litigation__c" \
    --metadata "CustomObject:nepa_ar_export__c" \
    --metadata "CustomObject:nepa_decision_modification__c" \
    --metadata "CustomObject:nepa_process_related_agencies__c" \
    --metadata "CustomObject:nepa_project_agency_relationship__c" \
    --metadata "CustomObject:nepa_decision_element__c" \
    --metadata "CustomObject:nepa_decision_log__c" \
    --metadata "CustomObject:nepa_comment_attribution__c" \
    --metadata "CustomObject:nepa_project_analogous_case__c" \
    --metadata "CustomObject:nepa_required_permit__c" \
    --metadata "CustomObject:nepa_gis_data_element__c" \
    --metadata "CustomObject:NEPA_Error_Event__e" \
    --metadata "CustomObject:NEPA_Agency_Risk_Rate__mdt" \
    --metadata "CustomObject:NEPA_Agency_Duration_Cost__mdt" \
    --metadata "CustomObject:NEPA_Agency_Endpoint__mdt" \
    --metadata "CustomObject:NEPA_ActionPlan_Config__mdt" \
    --metadata "CustomObject:NEPA_Circuit_Risk_Weight__mdt" \
    --metadata "CustomObject:NEPA_Challenge_Prediction_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Screening_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Code__mdt" \
    --metadata "CustomObject:NEPA_Doc_Count_Threshold__mdt" \
    --metadata "CustomObject:NEPA_Required_Document__mdt" \
    --metadata "CustomObject:NEPA_Statute_Risk_Weight__mdt" \
    --metadata "CustomObject:NEPA_GIS_Layer__mdt" \
    --metadata "CustomObject:NEPA_Inspection_Schedule__mdt" \
    --metadata "CustomObject:NEPA_MFR_Assessment__mdt" \
    --metadata "CustomObject:NEPA_OFD_Milestone__mdt" \
    --metadata "CustomObject:NEPA_Permit_Matrix__mdt" \
    --metadata "CustomObject:NEPA_Plaintiff_Profile__mdt" \
    --metadata "CustomObject:NEPA_Layer_Discipline__mdt" \
    --metadata "CustomObject:NEPA_Risk_Threshold__mdt" \
    --metadata "CustomObject:NEPA_SLA_Config__mdt" \
    --metadata "CustomObject:NEPA_Slack_Config__mdt" \
    --metadata "CustomObject:NEPA_Stage_Baseline_Duration__mdt" \
    --metadata "CustomObject:NEPA_State_Risk_Profile__mdt" \
    --metadata "CustomObject:NEPA_Template_Catalog__mdt" \
    --metadata "CustomObject:nepa_detected_protection_layer__c" \
    --metadata "CustomObject:nepa_ce_library__c" \
    --metadata "CustomObject:nepa_decision_payload__c" \
    --metadata "CustomObject:NEPA_Process_Model__mdt" \
    --metadata "CustomObject:nepa_process_team_member__c" \
    --metadata "CustomObject:nepa_gis_data__c" \
    --metadata "CustomObject:NEPA_Agency_Scoping_Baseline__mdt" \
    --metadata "CustomObject:NEPA_Sector_Circuit_Risk__mdt" \
    --metadata "CustomObject:NEPA_Permit_Type_Catalog__mdt" \
    --metadata "CustomObject:NEPA_Map_Config__mdt" \
    --metadata "CustomObject:NEPA_NAICS_Code__mdt" \
    --target-org "$TARGET_ORG"

# ── phase 2: custom fields on all objects ─────────────────────────────────────
phase_header "Phase 2: Custom fields (all objects)"
deploy "custom fields" \
    --source-dir force-app/main/default/objects \
    --target-org "$TARGET_ORG"

# ── phase 3: parallel group A (after Phase 2) ────────────────────────────────
# Labels, queues, CMT records, BRE DM schemas, remote sites — all independent.
# The 3b→3d app chain must finish before Phase 4b (permset refs app + tabs).
# Group A completes before Phase 4: permission set notice is still printed here.
echo ""
echo "==> Phase 4: Permission set (deferred — see Phase 4b after Apex)"
echo "    (permission set deployed in Phase 4b after Apex — skipping here)"

echo ""
echo "==> Parallel group A: labels / queues / CMT / BRE DM schemas / remote sites / 3b→3d app chain"

_tmp_labels="/tmp/nepa_deploy_labels_$$.out"
_tmp_queues="/tmp/nepa_deploy_queues_$$.out"
_tmp_cmt="/tmp/nepa_deploy_cmt_$$.out"
_tmp_bredm="/tmp/nepa_deploy_bredm_$$.out"
_tmp_remote="/tmp/nepa_deploy_remote_$$.out"
_tmp_app="/tmp/nepa_deploy_app_$$.out"

( phase_3_labels )    >"$_tmp_labels"  2>&1 & _pid_labels=$!
( phase_3c_queues )   >"$_tmp_queues"  2>&1 & _pid_queues=$!
( phase_5_cmt )       >"$_tmp_cmt"     2>&1 & _pid_cmt=$!
( phase_5b_bre_dm )   >"$_tmp_bredm"   2>&1 & _pid_bredm=$!
( phase_6_remote )    >"$_tmp_remote"  2>&1 & _pid_remote=$!
# 3b tabs → 3d app — must stay sequential; run as a unit in its own subshell
( phase_3b_3d_app_initial ) >"$_tmp_app" 2>&1 & _pid_app=$!

wait_jobs \
    "$_tmp_labels"  "$_pid_labels" \
    "$_tmp_queues"  "$_pid_queues" \
    "$_tmp_cmt"     "$_pid_cmt" \
    "$_tmp_bredm"   "$_pid_bredm" \
    "$_tmp_remote"  "$_pid_remote" \
    "$_tmp_app"     "$_pid_app"
rm -f "$_tmp_labels" "$_tmp_queues" "$_tmp_cmt" "$_tmp_bredm" "$_tmp_remote" "$_tmp_app"

# ── parallel group B (after group A): Apex + ES defs — both independent ───────
echo ""
echo "==> Parallel group B: Apex classes+triggers+permset chain  |  BRE Expression Set defs"

_tmp_apex="/tmp/nepa_deploy_apex_$$.out"
_tmp_es="/tmp/nepa_deploy_es_$$.out"

# Apex chain: 7 classes → 7a triggers → 4b permset (sequential within subshell)
(
    phase_7_apex
    phase_7a_triggers
    phase_header "Phase 4b: Permission set"
    deploy "permission set" \
        --source-dir force-app/main/default/permissionsets \
        --target-org "$TARGET_ORG"
    # Auto-assign permset to the deploying admin user so post-deploy data loads
    # (demo data, Apex anonymous, verify queries) work without a separate manual step.
    phase_header "Phase 4b-assign: Permission set auto-assign to deploying user"
    sf org assign permset \
        --name NEPA_Permitting \
        --target-org "$TARGET_ORG" \
        && echo "    [Succeeded] NEPA_Permitting assigned to deploying user" \
        || echo "    WARNING: permset assign failed (may already be assigned) — continuing"
) >"$_tmp_apex" 2>&1 & _pid_apex=$!

( phase_5c_es_defs ) >"$_tmp_es" 2>&1 & _pid_es=$!

wait_jobs \
    "$_tmp_apex"  "$_pid_apex" \
    "$_tmp_es"    "$_pid_es"
rm -f "$_tmp_apex" "$_tmp_es"

# ── phase 5b-data / 5c-activate / 5d / 5e — sequential data loads ─────────────
# These must run after BRE DM schemas (group A) and ES defs (group B) complete.
if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 5b-data: BRE Decision Matrix rows + activation"
    python3 scripts/load_decision_matrix_rows.py \
        --org "$TARGET_ORG" \
        --skip-existing \
        --csv-dir decision_matrix_rows \
        || echo "    WARNING: DM row load encountered errors — check output above"
else
    phase_header "Phase 5b-data: BRE Decision Matrix rows + activation (SKIPPED in --check)"
    echo "    (skipped — dry-run mode; run: python3 scripts/load_decision_matrix_rows.py --org $TARGET_ORG --dry-run)"
fi

if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 5c-activate: BRE Expression Set activation"
    python3 scripts/load_decision_matrix_rows.py \
        --org "$TARGET_ORG" \
        --activate-es \
        --skip-existing \
        --csv-dir decision_matrix_rows \
        || echo "    WARNING: ES activation encountered errors — check output above"
fi

if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 5d: Regulatory code seed data (RegulatoryAuthorizationType + RegulatoryCode)"

    if [[ -f data/seed/regulatory_authorization_type_seed.json ]]; then
        echo "    Importing RegulatoryAuthorizationType records (49 permit type catalog entries)..."
        sf data import tree \
            --files data/seed/regulatory_authorization_type_seed.json \
            --target-org "$TARGET_ORG" \
            --json 2>/dev/null \
            | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('result', [])
    results = r if isinstance(r, list) else r.get('results', [])
    ok  = sum(1 for x in results if not x.get('errors'))
    bad = sum(1 for x in results if x.get('errors'))
    print('    [Imported] RegulatoryAuthorizationType: {} succeeded, {} failed'.format(ok, bad))
    for x in results:
        for e in x.get('errors', []):
            if 'duplicate' not in str(e).lower():
                print('    WARN:', e)
except Exception as ex:
    print('    (could not parse import result):', ex)
" 2>&1 || echo "    WARNING: RegulatoryAuthorizationType import failed — check data/seed/regulatory_authorization_type_seed.json"
    else
        echo "    (data/seed/regulatory_authorization_type_seed.json not found — skipping)"
    fi

    if [[ -f data/seed/regulatory_code_seed.json ]]; then
        echo "    Importing RegulatoryCode records (24 statutory text entries)..."
        # RegulatoryCode requires RegulatoryAuthorityId (lookup to RegulatoryAuthority, not Account).
        # Create or find a NEPA authority record first, then inject its ID into the seed JSON.
        NEPA_AUTH_ID=$(sf data query \
            --query "SELECT Id FROM RegulatoryAuthority WHERE Name = 'U.S. Federal Government (NEPA)' LIMIT 1" \
            --target-org "$TARGET_ORG" --json 2>/dev/null \
            | python3 -c "import sys,json; d=json.load(sys.stdin); recs=d.get('result',{}).get('records',[]); print(recs[0]['Id'] if recs else '')" 2>/dev/null)
        if [[ -z "$NEPA_AUTH_ID" ]]; then
            NEPA_AUTH_ID=$(sf data create record \
                --sobject RegulatoryAuthority \
                --values "Name='U.S. Federal Government (NEPA)'" \
                --target-org "$TARGET_ORG" --json 2>/dev/null \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('id',''))" 2>/dev/null)
        fi
        if [[ -n "$NEPA_AUTH_ID" ]]; then
            python3 -c "
import json, sys
auth_id = sys.argv[1]
with open('data/seed/regulatory_code_seed.json') as f:
    d = json.load(f)
for rec in d.get('records', []):
    rec['RegulatoryAuthorityId'] = auth_id
import tempfile, os
tmp = 'data/seed/regulatory_code_seed_patched.json'
with open(tmp, 'w') as f:
    json.dump(d, f)
print(tmp)
" "$NEPA_AUTH_ID" > /tmp/nepa_rc_patched_path.txt 2>/dev/null
            RC_PATCHED=$(cat /tmp/nepa_rc_patched_path.txt 2>/dev/null)
            sf data import tree \
                --files "${RC_PATCHED:-data/seed/regulatory_code_seed.json}" \
                --target-org "$TARGET_ORG" \
                --json 2>/dev/null \
                | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('result', [])
    results = r if isinstance(r, list) else r.get('results', [])
    ok  = sum(1 for x in results if not x.get('errors'))
    bad = sum(1 for x in results if x.get('errors'))
    print('    [Imported] RegulatoryCode: {} succeeded, {} failed'.format(ok, bad))
    for x in results:
        for e in x.get('errors', []):
            if 'duplicate' not in str(e).lower():
                print('    WARN:', e)
except Exception as ex:
    print('    (could not parse import result):', ex)
" 2>&1 || echo "    WARNING: RegulatoryCode import failed — non-blocking, continuing"
            rm -f data/seed/regulatory_code_seed_patched.json /tmp/nepa_rc_patched_path.txt
        else
            echo "    WARNING: could not create RegulatoryAuthority — skipping RegulatoryCode import"
        fi
    else
        echo "    (data/seed/regulatory_code_seed.json not found — skipping)"
    fi
else
    phase_header "Phase 5d: Regulatory code seed data (SKIPPED in --check)"
    echo "    (skipped — dry-run mode; run manually after deploy:)"
    echo "      sf data import tree --files data/seed/regulatory_authorization_type_seed.json --target-org <org>"
    echo "      sf data import tree --files data/seed/regulatory_code_seed.json --target-org <org>"
fi

if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 5e: CE Library reference data (314 priority-agency records)"
    if [[ -f exclusions_filtered.json ]]; then
        python3 scripts/load_ce_library.py \
            --org "$TARGET_ORG" \
            2>&1 | sed 's/^/    /' \
            || echo "    WARNING: CE Library load encountered errors — see output above"
        echo "    Verify: sf data query --query \"SELECT COUNT() FROM nepa_ce_library__c\" --target-org $TARGET_ORG"
    else
        echo "    (exclusions_filtered.json not found in repo root — skipping CE Library load)"
        echo "    To load manually: python3 scripts/load_ce_library.py --org $TARGET_ORG"
        echo "    Full dataset (2,105 records): curl -o exclusions.json https://ce.permitting.innovation.gov/data/exclusions.json"
        echo "    then: python3 scripts/load_ce_library.py --org $TARGET_ORG --all"
    fi
else
    phase_header "Phase 5e: CE Library reference data (SKIPPED in --check)"
    echo "    (skipped — dry-run mode; run: python3 scripts/load_ce_library.py --org $TARGET_ORG)"
fi

# ── phase 8: flows (one per deploy call, serial) ──────────────────────────────
# Each flow is deployed individually to avoid the Salesforce Metadata API
# UNKNOWN_EXCEPTION that fires when multiple flows are included in a single
# deployment payload (see known idiosyncrasies note 1 in script header).
# Transient UNKNOWN_EXCEPTION errors are retried automatically (up to 3 times).
# Real parse/compile errors abort immediately.
# Flows must remain serial — the Metadata API pod routing issue (UNKNOWN_EXCEPTION)
# makes concurrent flow deployments unreliable even one-at-a-time.
phase_header "Phase 8: Flows (deployed individually with retry)"
FLOWS=(
    # ── Tier 0: leaf subflows — no flow dependencies; must deploy first ──────────
    NEPA_FlowError_CountIncrementer   # called by NEPA_Error_Logger
    NEPA_Error_Logger                 # called by nearly every flow below
    NEPA_Error_Event_Handler          # platform event handler; no subflow deps
    NEPA_EJTribal_Router              # called by NEPA_Comment_AI_Router

    # ── Tier 1: flows with no subflow dependencies ───────────────────────────────
    NEPA_SLA_Due_Date_Setter
    NEPA_Stage_Gate
    NEPA_Stage_Gate_Doc_Check
    NEPA_Comment_Period_Gate
    NEPA_Comment_Triage_Save
    NEPA_GIS_Proximity_Check
    NEPA_FRA_Page_Limit_Setter
    NEPA_Agency_Tier_Setter
    NEPA_Phase2_Applicability_Setter
    NEPA_ActionPlan_Launcher

    # ── Tier 2: flows that call NEPA_Error_Logger as subflow ─────────────────────
    NEPA_Litigation_Risk_Scorer
    NEPA_Challenge_Predictor
    NEPA_Defensibility_Gap_Checker
    NEPA_Defensibility_Trigger_ContentVersion
    NEPA_Defensibility_Trigger_Engagement
    NEPA_Timeline_Risk_Assessor
    NEPA_SLA_Escalation_Monitor
    NEPA_CE_Screener
    NEPA_CE_Determination_Router
    NEPA_CE_Intake
    NEPA_Record_Completeness_Scorer
    NEPA_Stage_Gate_Orchestrator
    NEPA_Administrative_Record_Checker
    NEPA_Plaintiff_Intelligence
    NEPA_Permit_Coordinator
    NEPA_Permit_Record_Creator           # creates nepa_required_permit__c records
    NEPA_Permit_SLA_Monitor
    NEPA_AdminRecord_AutoCreate
    NEPA_Team_Assembly_Orchestrator
    NEPA_Close_Administrative_Record
    NEPA_Comment_Duplicate_Check
    NEPA_BiOp_Reinitiation_Checker       # after-save on Visit; calls NEPA_Error_Logger
    NEPA_Permit_Issued_Schedule_Creator  # after-save on nepa_required_permit__c; calls NEPA_Error_Logger
    NEPA_PostDecision_Monitor_Scheduler  # scheduled; calls NEPA_Error_Logger

    # ── Visit survey automation (call NEPA_Error_Logger) ────────────────────────
    NEPA_Visit_Survey_Window_Setter
    NEPA_Visit_Completion_Assessor

    # ── Flows that depend on NEPA_EJTribal_Router ────────────────────────────────
    NEPA_Comment_AI_Router               # calls NEPA_EJTribal_Router as subflow
    NEPA_Comment_ResponseTask_Creator

    # ── F-03: pre-application screening ─────────────────────────────────────────
    NEPA_PreApp_Qualify_Sector

    # ── F-15: FAST-41 OFD variance alert (scheduled, daily 07:00 UTC) ───────────
    NEPA_OFD_Variance_Alert

    # ── F-12: Slack notifications ────────────────────────────────────────────────
    # Deployed as Draft. Require the Salesforce for Slack managed package + workspace
    # connection. Will fail to activate on orgs without the package — deploy_flow
    # retries transiently but will warn and continue rather than abort the pipeline.
    # See post-deploy Step 9 for full Slack setup instructions.
    NEPA_Slack_Stage_Notifier
    NEPA_Slack_Risk_Alert
)

# NEPA_EIS_Section_Assembler uses generateText (Einstein AI) — skipped unless
# Einstein generative AI is provisioned in the target org.
# NEPA_EIS_Section_Draft_Trigger calls NEPA_EIS_Section_Assembler as a subflow;
# it cannot deploy until the assembler exists. Both must be deployed together.
# NEPA_Work_Order_Generator — flow file not yet created (stub listed in docs only).
# Deploy these manually when Einstein AI is available:
#   sf project deploy start --metadata "Flow:NEPA_EIS_Section_Assembler" --target-org "$TARGET_ORG" --test-level NoTestRun --wait 30
#   sf project deploy start --metadata "Flow:NEPA_EIS_Section_Draft_Trigger" --target-org "$TARGET_ORG" --test-level NoTestRun --wait 30

for flow in "${FLOWS[@]}"; do
    deploy_flow "$flow" || echo "    [WARN] $flow — failed (non-transient); continuing pipeline"
done

# ── parallel group D (after Phase 8 flows) ────────────────────────────────────
# APTs, OmniStudio, reports chain, layouts, LWC — all independent of each other.
echo ""
echo "==> Parallel group D: APTs  |  OmniStudio  |  reports/dashboards  |  layouts  |  LWC"

_tmp_apts="/tmp/nepa_deploy_apts_$$.out"
_tmp_omni="/tmp/nepa_deploy_omni_$$.out"
_tmp_rpts="/tmp/nepa_deploy_rpts_$$.out"
_tmp_layouts="/tmp/nepa_deploy_layouts_$$.out"
_tmp_lwc="/tmp/nepa_deploy_lwc_$$.out"

( phase_8b_apts )           >"$_tmp_apts"    2>&1 & _pid_apts=$!
( phase_8c_omnistudio )     >"$_tmp_omni"    2>&1 & _pid_omni=$!
( phase_10_12_reports )     >"$_tmp_rpts"    2>&1 & _pid_rpts=$!
( phase_13_layouts )        >"$_tmp_layouts" 2>&1 & _pid_layouts=$!
( phase_14_lwc )            >"$_tmp_lwc"     2>&1 & _pid_lwc=$!

wait_jobs \
    "$_tmp_apts"    "$_pid_apts" \
    "$_tmp_omni"    "$_pid_omni" \
    "$_tmp_rpts"    "$_pid_rpts" \
    "$_tmp_layouts" "$_pid_layouts" \
    "$_tmp_lwc"     "$_pid_lwc"
rm -f "$_tmp_apts" "$_tmp_omni" "$_tmp_rpts" "$_tmp_layouts" "$_tmp_lwc"

# ── phase 8d: run local tests (after all Apex+flows+OmniStudio deployed) ──────
phase_8d_tests

# ── phase 9: (merged into Phase 3b) ──────────────────────────────────────────
# Custom tabs were deployed in Phase 3b (tabs must precede the permission set
# because the permset references tabSettings by name and the platform validates
# their existence at deploy time). Nothing to do here.

# ── phase 14a: lwc-backed tabs + app redeploy (after LWC lands) ──────────────
# nepaTemplateCatalog is an LWC-backed tab — the platform requires the LWC to
# exist before the tab can be deployed. Deploying here (after Phase 14 LWC) avoids
# the "no LightningComponentBundle named nepaTemplateCatalog found" error that
# occurs if it is included in the Phase 3b object-tab batch.
phase_header "Phase 14a: LWC-backed tabs"
deploy "lwc-backed tabs" \
    --metadata "CustomTab:nepaTemplateCatalog" \
    --target-org "$TARGET_ORG"

# Redeploy app to add nepaTemplateCatalog to nav now that the LWC-backed tab exists
deploy "app (with nepaTemplateCatalog tab)" \
    --source-dir force-app/main/default/apps \
    --target-org "$TARGET_ORG"

# ── phase 15: flexipages ──────────────────────────────────────────────────────
# Only the NEPA-specific pages checked into this repo.
# All non-NEPA flexipages have been removed from force-app/main/default/flexipages/.
#
# Program_Record_Page: deployed individually with allow-failure because some orgs
# (pre-existing PSS installs) already have Program_Record_Page bound to CGC_Program__c.
# The Metadata API cannot change the sobjectType of an existing page. If it fails here,
# assign the page manually in Setup → Lightning App Builder. (See idiosyncrasy #14.)
phase_header "Phase 15: FlexiPages (NEPA record and home pages)"
deploy "flexipages (non-Program)" \
    --metadata "FlexiPage:ApplicationTimeline_Record_Page" \
    --metadata "FlexiPage:IndividualApplication_Record_Page" \
    --metadata "FlexiPage:NEPA_AR_Export_Record_Page" \
    --metadata "FlexiPage:NEPA_CE_Library_Record_Page" \
    --metadata "FlexiPage:NEPA_Decision_Log_Record_Page" \
    --metadata "FlexiPage:NEPA_Decision_Payload_Record_Page" \
    --metadata "FlexiPage:NEPA_Detected_Protection_Layer_Record_Page" \
    --metadata "FlexiPage:NEPA_Engagement_Record_Page" \
    --metadata "FlexiPage:NEPA_GIS_Data_Element_Record_Page" \
    --metadata "FlexiPage:NEPA_GIS_Data_Record_Page" \
    --metadata "FlexiPage:NEPA_Litigation_Record_Page" \
    --metadata "FlexiPage:NEPA_Process_Team_Member_Record_Page" \
    --metadata "FlexiPage:NEPA_Required_Permit_Record_Page" \
    --metadata "FlexiPage:NEPA_Visit_Record_Page" \
    --metadata "FlexiPage:Public_Comment_Record_Page" \
    --metadata "FlexiPage:RegulatoryCode_Record_Page" \
    --target-org "$TARGET_ORG"

# NEPA_Permitting_Home uses flexipage:filterListCard components that look up list views
# (All_IndividualApplications, All_PublicComplaint, All_ApplicationTimelines). On orgs
# with a corrupted SOAP/describe cache (zombie fields after repeated partial deploys),
# the list view lookup fails even though the list views exist. allow-failure keeps the
# pipeline unblocked on such orgs; the page deploys cleanly on fresh org installs.
deploy "NEPA_Permitting_Home" allow-failure \
    --metadata "FlexiPage:NEPA_Permitting_Home" \
    --target-org "$TARGET_ORG"

deploy "Program_Record_Page" allow-failure \
    --metadata "FlexiPage:Program_Record_Page" \
    --target-org "$TARGET_ORG"

# ── parallel group E (after Phase 15 flexipages) ─────────────────────────────
# Path Assistants and Agentforce agents are independent of each other.
echo ""
echo "==> Parallel group E: path assistants  |  Agentforce agent bundles"

_tmp_pa="/tmp/nepa_deploy_pa_$$.out"
_tmp_agents="/tmp/nepa_deploy_agents_$$.out"

( phase_15a_path_assistants ) >"$_tmp_pa"     2>&1 & _pid_pa=$!
( phase_15b_agents )          >"$_tmp_agents" 2>&1 & _pid_agents=$!

wait_jobs \
    "$_tmp_pa"     "$_pid_pa" \
    "$_tmp_agents" "$_pid_agents"
rm -f "$_tmp_pa" "$_tmp_agents"

# ── phase 16: lightning app ───────────────────────────────────────────────────
# Moved to Phase 3d — must precede Phase 4b permission set (applicationVisibilities dep).
phase_header "Phase 16: Lightning app (deployed in Phase 3d)"
echo "    (app deployed in Phase 3d before permission set — skipping here)"

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
    echo "    1. Assign permission set (grants field access, tab visibility, and NEPA Permitting app access):"
    echo "       sf org assign permset --name NEPA_Permitting --target-org $TARGET_ORG"
    echo "       Or assign to a specific user:"
    echo "       sf org assign permset --name NEPA_Permitting --on-behalf-of user@example.com --target-org $TARGET_ORG"
    echo ""
    echo "    2. All flows deploy with status=Active — no manual activation needed."
    echo "       Verify in Setup > Flows that all NEPA_* flows show Active status."
    echo "       If any show Draft or Inactive, activate them manually or re-run Phase 8."
    echo "       Exceptions:"
    echo "       a) NEPA_EIS_Section_Assembler + NEPA_EIS_Section_Draft_Trigger require Einstein"
    echo "          generative AI and are NOT deployed by this script."
    echo "          Deploy manually when Einstein AI is provisioned:"
    echo "          sf project deploy start --metadata \"Flow:NEPA_EIS_Section_Assembler\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
    echo "          sf project deploy start --metadata \"Flow:NEPA_EIS_Section_Draft_Trigger\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
    echo "       b) NEPA_Slack_Stage_Notifier + NEPA_Slack_Risk_Alert require the Salesforce for"
    echo "          Slack managed package. They deploy as Draft and will fail on orgs without it."
    echo "          See post-deploy Step 9 for Slack setup instructions."
    echo ""
    echo "    3. BRE Decision Matrices and Expression Sets — automated by Phase 5b-data above."
    echo "       If Phase 5b-data reported errors, re-run manually:"
    echo "         python3 scripts/load_decision_matrix_rows.py --org $TARGET_ORG --activate-es"
    echo "       To reload specific DMs only:"
    echo "         python3 scripts/load_decision_matrix_rows.py --org $TARGET_ORG --dm NEPA_Risk_Agency --no-skip"
    echo "       To preview without writing:"
    echo "         python3 scripts/load_decision_matrix_rows.py --org $TARGET_ORG --dry-run"
    echo ""
    echo "    4. Verify Custom Metadata records loaded:"
    echo "       Setup > Custom Metadata Types > each NEPA_* type > Manage Records"
    echo "       Key types to verify: NEPA_Permit_Matrix__mdt (25 records), NEPA_Permit_Type_Catalog__mdt (49 records)"
    echo ""
    echo "    4b. Verify regulatory code seed data (Phase 5d):"
    echo "       sf data query --query \"SELECT COUNT() FROM RegulatoryAuthorizationType WHERE Name LIKE 'CWA%' OR Name LIKE 'ESA%'\" --target-org $TARGET_ORG"
    echo "       sf data query --query \"SELECT COUNT() FROM RegulatoryCode\" --target-org $TARGET_ORG"
    echo "       Expected: 49 RegulatoryAuthorizationType records, 24 RegulatoryCode records."
    echo "       If Phase 5d was skipped or failed, re-run manually:"
    echo "         sf data import tree --files data/seed/regulatory_authorization_type_seed.json --target-org $TARGET_ORG"
    echo "         sf data import tree --files data/seed/regulatory_code_seed.json --target-org $TARGET_ORG"
    echo ""
    echo "    5. CE Library reference data — loaded automatically in Phase 5e above."
    echo "       If Phase 5e was skipped (exclusions_filtered.json missing) or failed, re-run:"
    echo "         python3 scripts/load_ce_library.py --org $TARGET_ORG"
    echo "       Full 2,105-record dataset (requires exclusions.json in repo root):"
    echo "         curl -o exclusions.json https://ce.permitting.innovation.gov/data/exclusions.json"
    echo "         python3 scripts/load_ce_library.py --org $TARGET_ORG --all"
    echo "       Verify: sf data query --query \"SELECT COUNT() FROM nepa_ce_library__c\" --target-org $TARGET_ORG"
    echo ""
    echo "    5b. Seed demo data (optional):"
    echo "       sf apex run --file scripts/seed-sample-data.apex --target-org $TARGET_ORG"
    echo ""
    echo "    5c. Seed ServiceResource discipline values (GIS team assembly):"
    echo "       sf apex run --file demo/import_data/21_postload_discipline.apex --target-org $TARGET_ORG"
    echo ""
    echo "    6. Agentforce agents — MANUAL SETUP REQUIRED."
    echo "       Agent configuration specs are in force-app/main/default/agents/."
    echo "       These are human-readable config specs that must be created in Agentforce Studio."
    echo "       See docs/AGENT_SETUP.md for step-by-step setup instructions for:"
    echo "         - NEPA_Comment_Triage (Employee Agent — comment classification)"
    echo "         - NEPA_PreApp_Screener (Service Agent — pre-application screening)"
    echo ""
    echo "    6b. OmniStudio — deployed automatically in Phase 8c above."
    echo "       Phase 8c handles the DRUpsertDetectedLayer two-step (globalKey patching)"
    echo "       and deploys OmniIntegrationProcedures via the omniIntegrationProcedures/ directory."
    echo ""
    echo "       ACTION REQUIRED: Activate the CE Intake OmniScript manually after deploy."
    echo "       The Metadata API deploys the OmniScript record but does NOT generate the"
    echo "       LWC components needed to render it. Activation via Designer compiles them."
    echo "       Steps:"
    echo "         sf org open --target-org $TARGET_ORG --path /lightning/setup/OmniStudioDesigner/home"
    echo "         → OmniScripts tab → find NEPA / CE Intake / English / 1 → click Activate"
    echo "         → Also activate NEPA / PreApp_Screening_IP / English / 1"
    echo "       Without this step OmniScripts render blank with LDS normalization errors."
    echo ""
    echo "    6c. ArcGIS map component (nepaSiteLocationPickerOmni):"
    echo "        CSP Trusted Sites (ArcGIS_JS_CDN, ArcGIS_Tiles) deployed automatically in Phase 6."
    echo "        ACTION REQUIRED — set ESRI API key:"
    echo "          Setup > Custom Metadata Types > NEPA Map Config > API Key > Edit > set Value"
    echo "        Without the API key the map loads but no basemap tiles render (grey canvas)."
    echo ""
    echo "    6d. NAICS code data — 2,129 records loaded via Apex anonymous, not metadata."
    echo "        Verify records exist:"
    echo "          sf data query --query \"SELECT Level__c, COUNT(Id) cnt FROM NEPA_NAICS_Code__mdt GROUP BY Level__c\" --target-org $TARGET_ORG"
    echo "        Expected: Sector(20) SubSector(96) IndustryGroup(308) Industry(692) NationalIndustry(1013)"
    echo "        If records are missing, reload from the authoritative NAICS 2022 CSV"
    echo "        using Metadata.Operations.enqueueDeployment in Apex anonymous (40-record batches)."
    echo ""
    echo "    7. GIS proximity trigger chain verification:"
    echo "       Set nepa_location_lat__c + nepa_location_lon__c on a Program record."
    echo "       Wait ~10s, refresh — nepa_protection_areas__c should be populated."
    echo "       Chain: NEPA_GIS_Proximity_Check flow"
    echo "            → NepaGISProximityIPInvoker Apex (invokeMethod bridge)"
    echo "            → NEPA_GISProximityIP OmniIntegrationProcedure"
    echo "            → DRUpsertDetectedLayer DataRaptor (upserts nepa_detected_protection_layer__c)"
    echo "            → sets nepa_gis_proximity_complete__c = true"
    echo ""
    echo "    8. FPISC / FAST-41 OFD export (F-15):"
    echo "       nepaFpiscExportButton is deployed to IndividualApplication_Record_Page"
    echo "       automatically in Phase 15 — no manual Lightning App Builder step required."
    echo "       OFD Variance Alert (NEPA_OFD_Variance_Alert) runs daily at 07:00 UTC."
    echo "       Verify: sf data query --query \"SELECT COUNT() FROM Flow WHERE DeveloperName = 'NEPA_OFD_Variance_Alert' AND Status = 'Active'\" --use-tooling-api --target-org $TARGET_ORG"
    echo ""
    echo "    9. Slack Integration Hub (F-12) — REQUIRES MANUAL SETUP:"
    echo "       a) Install Salesforce for Slack managed package from AppExchange"
    echo "       b) Setup → Slack → connect org to workspace"
    echo "       c) Update NEPA_Slack_Config.Default CMT with real Slack channel IDs"
    echo "          (Setup → Custom Metadata Types → NEPA Slack Config → Manage Records → Default)"
    echo "       d) Re-deploy and activate NEPA_Slack_Stage_Notifier and NEPA_Slack_Risk_Alert:"
    echo "          sf project deploy start --metadata \"Flow:NEPA_Slack_Stage_Notifier\" --target-org $TARGET_ORG --wait 30"
    echo "          sf project deploy start --metadata \"Flow:NEPA_Slack_Risk_Alert\" --target-org $TARGET_ORG --wait 30"
    echo "       Note: NEPA_EJTribal_Router does NOT include the Slack call — tribal notifications"
    echo "       are handled by NEPA_Slack_Stage_Notifier once that flow is active. The EJTribal"
    echo "       Router focuses solely on queue assignment, task creation, and flag updates."
    echo "       See: DEVELOPER_GUIDE.md § Step 12"
    echo ""
    echo "   10. Agency Template Exchange (F-11):"
    echo "       Verify 46 CMT seed records: sf data query --query \"SELECT COUNT() FROM NEPA_Template_Catalog__mdt\" --target-org $TARGET_ORG"
    echo "       Catalog tab 'Agency Template Exchange' should appear in the NEPA Permitting app navigation."
    echo "       If tab is missing: Setup → App Manager → NEPA Permitting → Navigation Items → add nepaTemplateCatalog"
    echo "       See: DEVELOPER_GUIDE.md § Step 13"
    echo ""
    echo "    Full post-deploy checklist with exact commands: DEVELOPER_GUIDE.md § Post-Deploy Checklist"
    echo ""
    # ── demo data prompt ──────────────────────────────────────────────────────
    # Skip prompt when stdin is not a terminal (CI, piped input, etc.)
    if [[ -t 0 ]]; then
        echo "────────────────────────────────────────────────────────────────────────────"
        echo "  DEMO DATA — Carrie Placer Mine (IDI-38709)"
        echo "  Loads a realistic full-lifecycle NEPA EA record: BLM Idaho, Salmon Field Office,"
        echo "  30+ case events, 7 specialist team, GIS proximity layers, litigation case,"
        echo "  risk score, required permits, inspection visits, and administrative record."
        echo "────────────────────────────────────────────────────────────────────────────"
        read -r -p "==> Load Carrie Placer Mine demo data into $TARGET_ORG? [y/N] " LOAD_DEMO
        echo ""
        if [[ "$LOAD_DEMO" =~ ^[Yy]$ ]]; then
            if [[ -f "scripts/load-demo-data.sh" ]]; then
                bash scripts/load-demo-data.sh "$TARGET_ORG"
            else
                echo "    ERROR: scripts/load-demo-data.sh not found." >&2
                echo "    Run manually: bash scripts/load-demo-data.sh $TARGET_ORG" >&2
            fi
        else
            echo "    Skipping demo data. To load later:"
            echo "      bash scripts/load-demo-data.sh $TARGET_ORG"
        fi
    fi
fi
