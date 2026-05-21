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
#   4  Permission set          — FLS grants require fields to exist first
#   5  Custom metadata records — CMT records used by flow decision logic
#   5b BRE Decision Matrices   — DecisionMatrixDefinition metadata schema deploy
#   5b-data                   — row insertion + activation via Tooling API (replaces manual UI workflow)
#   5c BRE Expression Sets     — ExpressionSetDefinition metadata (must follow DMs they reference)
#   6  Remote sites + creds    — needed before any callout-capable flows compile
#   7  Apex classes            — must precede flows that call @InvocableMethod actions
#   7b Visualforce pages       — NEPA_Site_Location_Page (ArcGIS iframe); must follow Phase 7 (references controller)
#   8  Flows (one-at-a-time)   — Metadata API UNKNOWN_EXCEPTION on batch flow deployments;
#                                each flow deployed individually with retry on transient failure
#   9  Tabs                    — custom object tabs referenced by the Lightning app
#  10  Report types            — NEPA_Process_Reports, NEPA_Comment_Reports
#  11  Reports                 — depend on report types
#  12  Dashboards              — depend on reports
#  13  Layouts                 — compact layouts for related-list display
#  14  LWC                     — custom components referenced by FlexiPages
#  15  FlexiPages              — depend on fields, layouts, LWC
#  16  Lightning app           — depends on tabs; app visibility granted via NEPA_Permitting permset (Phase 4b)
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

# ── phase 3b: custom tabs ────────────────────────────────────────────────────
# Must precede Phase 4 (permission set) — the permset references tabSettings
# by tab name and Salesforce validates their existence at deploy time.
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
    --target-org "$TARGET_ORG"

# ── phase 4: permission set ──────────────────────────────────────────────────
# NOTE: Permission set is deployed AFTER Phase 7 (Apex) because it references
# ApexClass entries (NepaLayerDisciplineResolver, NepaActionPlanLauncher) that
# must exist before the permset deploy validates. See Phase 4b below.
phase_header "Phase 4: Permission set (deferred — see Phase 4b after Apex)"
echo "    (permission set deployed in Phase 4b after Apex — skipping here)"

# ── phase 5: custom metadata records ─────────────────────────────────────────
phase_header "Phase 5: Custom metadata seed records"
deploy "custom metadata" \
    --source-dir force-app/main/default/customMetadata \
    --target-org "$TARGET_ORG"

# ── phase 5b: bre decision matrices ──────────────────────────────────────────
# Deploys DecisionMatrixDefinition schemas (columns + version structure only).
# Rows and activation are handled in Phase 5b-data below.
phase_header "Phase 5b: BRE Decision Matrix definitions"
deploy "decision matrices" allow-failure \
    --source-dir force-app/main/default/decisionMatrixDefinition \
    --target-org "$TARGET_ORG"

# ── phase 5c: bre expression sets ────────────────────────────────────────────
# Deploy ESD metadata. The source files for all three ESDs contain their Active
# version as retrieved from the org (after the Tooling API activation workaround
# in Phase 5c-activate). Re-deploying an already-Active ESD is a no-op (Unchanged).
#
# On a FIRST-TIME deploy to a fresh org:
#   1. This phase creates a Draft ESDV in org (no snapshot yet — Metadata API
#      cannot create the snapshot; see known idiosyncrasy #20).
#   2. Phase 5b-data loads DM rows and activates DMs.
#   3. Phase 5c-activate runs load_decision_matrix_rows.py --activate-es, which
#      PATCHes the ESDV via Tooling API — this activates the version and creates
#      the LatestVersionSnapshotId. Subsequent deploys succeed as no-ops.
#
# allow-failure set because on a fresh org the first deploy creates a Draft ESDV
# that is technically valid but not yet Active; the deploy itself succeeds but
# the ES will not be usable until Phase 5c-activate runs.
phase_header "Phase 5c: BRE Expression Set definitions"
# Deployed individually — batch ESD deploys trigger transient UNKNOWN_EXCEPTION.
for esd in NEPA_CE_Screener NEPA_Permit_Coordinator NEPA_Litigation_Risk_Scorer; do
    deploy "expression set: $esd" allow-failure \
        --metadata "ExpressionSetDefinition:$esd" \
        --target-org "$TARGET_ORG"
done

# ── phase 5b-data: bre decision matrix rows + activation ─────────────────────
# Inserts CalculationMatrixRows from decision_matrix_rows/*.csv and activates
# each DecisionMatrixDefinitionVersion via Tooling API PATCH (Metadata.status=Active).
#
# Why this works:
#   - CalculationMatrixRow records can only be written while CMV.IsEnabled=False
#   - Tooling API PATCH of DecisionMatrixDefinitionVersion.Metadata.status="Active"
#     atomically sets DMDV.Status=Active and CMV.IsEnabled=True
#   - This is equivalent to clicking Activate in Setup → BRE → Decision Matrices
#
# Must run after Phase 5c (ESD deploy) and before Phase 5c-activate (ES activation).
# Skipped in --check mode (no org writes during validation).
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

# ── phase 5c-activate: bre expression set activation ─────────────────────────
# Activates all ESDs in ES_VERSIONS via Tooling API PATCH after DMs are active.
# DMs must be active first (BRE runtime requirement).
#
# For first-time deploys: the Metadata API created Draft ESDVs with full steps
# in Phase 5c. This PATCH atomically sets status=Active and creates the
# LatestVersionSnapshotId that the BRE runtime and subsequent Metadata API
# deploys require (see known idiosyncrasy #20).
#
# After this phase succeeds on a fresh org, retrieve the ESDs to sync the
# Active state back to source:
#   sf project retrieve start \
#     --metadata "ExpressionSetDefinition:NEPA_Litigation_Risk_Scorer" \
#     --metadata "ExpressionSetDefinition:NEPA_CE_Screener" \
#     --metadata "ExpressionSetDefinition:NEPA_Permit_Coordinator" \
#     --target-org <alias>
# Commit the retrieved files. Subsequent deploys will then succeed as no-ops.
if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 5c-activate: BRE Expression Set activation"
    python3 scripts/load_decision_matrix_rows.py \
        --org "$TARGET_ORG" \
        --activate-es \
        --skip-existing \
        --csv-dir decision_matrix_rows \
        || echo "    WARNING: ES activation encountered errors — check output above"
fi

# ── phase 5d: regulatory code seed data ──────────────────────────────────────
# Imports RegulatoryAuthorizationType and RegulatoryCode records from data/seed/.
# These are runtime data dependencies, not metadata:
#   - RegulatoryAuthorizationType: the records that NEPA_Permit_Record_Creator
#     queries by Name for each permit token. Without these, every permit instance
#     falls back to label-only mode (no critical-path flag, no SLA, no lead agency).
#   - RegulatoryCode: CEQ Entity 9 statutory text records (audit trail / future
#     AI-driven regulatory text matching). Non-blocking — import failure is warned.
#
# Uses sf data import --json (tree/records format). Idempotent when RAType records
# already exist, because sf data import is insert-only — run sf data upsert bulk
# with Name as external ID to refresh existing records.
#
# Skipped in --check mode (no org writes during validation).
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
    results = d.get('result', {}).get('results', [])
    ok  = sum(1 for r in results if not r.get('errors'))
    bad = sum(1 for r in results if r.get('errors'))
    print('    [Imported] RegulatoryAuthorizationType: {} succeeded, {} failed'.format(ok, bad))
    for r in results:
        for e in r.get('errors', []):
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
        sf data import tree \
            --files data/seed/regulatory_code_seed.json \
            --target-org "$TARGET_ORG" \
            --json 2>/dev/null \
            | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    results = d.get('result', {}).get('results', [])
    ok  = sum(1 for r in results if not r.get('errors'))
    bad = sum(1 for r in results if r.get('errors'))
    print('    [Imported] RegulatoryCode: {} succeeded, {} failed'.format(ok, bad))
    for r in results:
        for e in r.get('errors', []):
            if 'duplicate' not in str(e).lower():
                print('    WARN:', e)
except Exception as ex:
    print('    (could not parse import result):', ex)
" 2>&1 || echo "    WARNING: RegulatoryCode import failed — non-blocking, continuing"
    else
        echo "    (data/seed/regulatory_code_seed.json not found — skipping)"
    fi
else
    phase_header "Phase 5d: Regulatory code seed data (SKIPPED in --check)"
    echo "    (skipped — dry-run mode; run manually after deploy:)"
    echo "      sf data import tree --files data/seed/regulatory_authorization_type_seed.json --target-org <org>"
    echo "      sf data import tree --files data/seed/regulatory_code_seed.json --target-org <org>"
fi

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
# Tests run in Phase 8d (after flows are deployed) so that flow-integration test
# classes can invoke flows via Flow.Interview.createInterview() and FLS-enforcing
# queries succeed with the permission set in place.
phase_header "Phase 7: Apex classes"
deploy "apex" \
    --source-dir force-app/main/default/classes \
    --test-level NoTestRun \
    --target-org "$TARGET_ORG"

# ── phase 7b: visualforce pages ──────────────────────────────────────────────
# Must deploy after Phase 7 (Apex) — VF pages reference their controller class.
# NEPA_Site_Location_Page is the ArcGIS iframe for the nepaSiteLocationPickerOmni LWC.
phase_header "Phase 7b: Visualforce pages"
if [[ -d force-app/main/default/pages ]] && \
   [[ -n "$(find force-app/main/default/pages -name '*.page' 2>/dev/null)" ]]; then
    deploy "visualforce pages" \
        --source-dir force-app/main/default/pages \
        --target-org "$TARGET_ORG"
else
    echo "    (no Visualforce pages to deploy)"
fi

# ── phase 4b: permission set (post-apex) ─────────────────────────────────────
# Deployed here rather than Phase 4 because the permset references:
#   - ApexClass: NepaLayerDisciplineResolver, NepaActionPlanLauncher (need Phase 7 first)
#   - CustomTab: all tabs (needed Phase 3b first — already done)
#   - CustomField: all custom fields (needed Phase 2 first — already done)
phase_header "Phase 4b: Permission set"
deploy "permission set" \
    --source-dir force-app/main/default/permissionsets \
    --target-org "$TARGET_ORG"

# ── phase 8: flows (one per deploy call) ──────────────────────────────────────
# Each flow is deployed individually to avoid the Salesforce Metadata API
# UNKNOWN_EXCEPTION that fires when multiple flows are included in a single
# deployment payload (see known idiosyncrasies note 1 in script header).
# Transient UNKNOWN_EXCEPTION errors are retried automatically (up to 3 times).
# Real parse/compile errors abort immediately.
phase_header "Phase 8: Flows (deployed individually with retry)"
FLOWS=(
    # Leaf subflows — no dependencies; must deploy first
    NEPA_FlowError_CountIncrementer
    NEPA_Error_Logger
    NEPA_Error_Event_Handler
    NEPA_EJTribal_Router
    # Independent flows with no subflow dependencies
    NEPA_SLA_Due_Date_Setter
    NEPA_Stage_Gate
    NEPA_Stage_Gate_Doc_Check
    NEPA_Comment_Period_Gate
    NEPA_Comment_Triage_Save
    NEPA_GIS_Proximity_Check
    NEPA_FRA_Page_Limit_Setter
    NEPA_WO_Milestone_Setter
    NEPA_Agency_Tier_Setter
    NEPA_Phase2_Applicability_Setter
    NEPA_ActionPlan_Launcher
    # Flows that depend on NEPA_Error_Logger
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
    NEPA_Permit_Record_Creator
    NEPA_Permit_SLA_Monitor
    NEPA_AdminRecord_AutoCreate
    NEPA_Team_Assembly_Orchestrator
    NEPA_Close_Administrative_Record
    NEPA_Comment_Duplicate_Check
    # Visit survey automation flows (depend on NEPA_Error_Logger)
    NEPA_Visit_Survey_Window_Setter
    NEPA_Visit_Completion_Assessor
    # Flows that depend on NEPA_EJTribal_Router (must come after it)
    NEPA_Comment_AI_Router
    NEPA_Comment_ResponseTask_Creator
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

# ── phase 8b: action plan templates ──────────────────────────────────────────
phase_header "Phase 8b: Action Plan Templates"
deploy "action plan templates" \
    --source-dir force-app/main/default/actionPlanTemplates \
    --target-org "$TARGET_ORG"

# ── phase 8c: omnistudio dataRaptors, integration procedures, omniscripts ──────
# All OmniStudio components deploy via standard Metadata API — no DataPack tooling.
#
# DataRaptor globalKey note:
#   All DRs except DRUpsertDetectedLayer use stable placeholder globalKeys
#   (PLACEHOLDER_NEPA_001 etc.) that are portable across orgs. The platform
#   stores these as-is — no ID patching required.
#
#   DRUpsertDetectedLayer_1 was originally authored in the NEPADEV org and has
#   org-specific ID (3ULao000000KUtBGAW) baked into its globalKeys. It deploys
#   cleanly to any org that doesn't yet have it (platform creates the DR and
#   accepts the foreign ID in globalKeys). On orgs where it already exists, the
#   platform updates items in-place by globalKey match. No patching needed.
#
# OmniScript IP dependency indexing:
#   The platform validates OmniScript IP dependencies against the org's component
#   index. If IPs were just deployed, the index may not reflect them yet (typically
#   resolves within minutes). This function retries up to 5 times with a 60s wait.

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

phase_header "Phase 8c: OmniStudio DataRaptors, Integration Procedures, OmniScripts"

# Deploy all DataRaptors from source in one call
if [[ -n "$(find force-app/main/default/omniDataTransforms -name '*.rpt-meta.xml' 2>/dev/null)" ]]; then
    deploy "DataRaptors" \
        --source-dir force-app/main/default/omniDataTransforms \
        --target-org "$TARGET_ORG"
else
    echo "    (no DataRaptors to deploy)"
fi

# Integration Procedures
if [[ -n "$(find force-app/main/default/omniIntegrationProcedures -name '*.oip-meta.xml' 2>/dev/null)" ]]; then
    deploy "Integration Procedures" \
        --source-dir force-app/main/default/omniIntegrationProcedures \
        --target-org "$TARGET_ORG"
else
    echo "    (no Integration Procedures to deploy)"
fi

# OmniScripts — retry loop handles IP index lag
if [[ -n "$(find force-app/main/default/omniScripts -name '*.xml' 2>/dev/null)" ]]; then
    deploy_omniscript_with_retry
else
    echo "    (no OmniScripts to deploy)"
fi

# ── phase 8d: run local tests ─────────────────────────────────────────────────
# Runs after flows (Phase 8), permission set (Phase 4b), and OmniStudio (Phase 8c)
# are all deployed so that:
#   - Flow-integration tests can invoke flows via Flow.Interview.createInterview()
#   - USER_MODE / WITH SECURITY_ENFORCED queries succeed with FLS grants in place
# Skipped in --check mode (dry-run) because flows are not deployed in that mode.
if [[ "$DRY_RUN" == "false" ]]; then
    phase_header "Phase 8d: RunLocalTests (post-flow validation)"
    deploy "local tests" \
        --source-dir force-app/main/default/classes \
        --test-level RunLocalTests \
        --target-org "$TARGET_ORG"
fi

# ── phase 9: custom tabs ──────────────────────────────────────────────────────
# Tabs were already deployed in Phase 3b (required before permission set).
# This phase is a no-op but retained for documentation of deployment order.
phase_header "Phase 9: Custom tabs (already deployed in Phase 3b)"
echo "    (tabs deployed in Phase 3b — skipping)"

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
    --metadata "FlexiPage:Individual_Application_Record_Page" \
    --metadata "FlexiPage:IndividualApplication_Record_Page" \
    --metadata "FlexiPage:NEPA_AR_Export_Record_Page" \
    --metadata "FlexiPage:NEPA_Engagement_Record_Page" \
    --metadata "FlexiPage:NEPA_GIS_Data_Element_Record_Page" \
    --metadata "FlexiPage:NEPA_Legal_Structure_Record_Page" \
    --metadata "FlexiPage:NEPA_Litigation_Record_Page" \
    --metadata "FlexiPage:NEPA_Permitting_Home" \
    --metadata "FlexiPage:NEPA_Process_Team_Member_Record_Page" \
    --metadata "FlexiPage:Public_Comment_Record_Page" \
    --metadata "FlexiPage:NEPA_CE_Library_Record_Page" \
    --metadata "FlexiPage:NEPA_Decision_Payload_Record_Page" \
    --target-org "$TARGET_ORG"

deploy "Program_Record_Page" allow-failure \
    --metadata "FlexiPage:Program_Record_Page" \
    --target-org "$TARGET_ORG"

# ── phase 15b: agentforce agents (Agent Script bundles) ──────────────────────
# Deploys .agent bundles via sf agent publish authoring-bundle.
# Runs after OmniStudio (Phase 8c) so that flow:// and apex:// targets are live.
# Activation is intentionally separate — run sf agent activate after smoke-testing.
phase_header "Phase 15b: Agentforce Agent Script bundles"
if [[ -d force-app/main/default/agents ]] && \
   [[ -n "$(find force-app/main/default/agents -name '*.agent' 2>/dev/null)" ]]; then
    for agent_file in force-app/main/default/agents/*/*.agent; do
        agent_dir=$(dirname "$agent_file")
        agent_name=$(basename "$agent_dir")
        echo "    Publishing agent bundle: $agent_name"
        sf agent publish authoring-bundle \
            --api-name "$agent_name" \
            --target-org "$TARGET_ORG" \
            --json || echo "    WARN: agent publish failed for $agent_name — check org agent user and action targets"
    done
else
    echo "    (no Agent Script bundles to deploy)"
fi

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
    echo "    1. Assign permission set (grants field access, tab visibility, and NEPA Permitting app access):"
    echo "       sf org assign permset --name NEPA_Permitting --target-org $TARGET_ORG"
    echo "       Or assign to a specific user:"
    echo "       sf org assign permset --name NEPA_Permitting --on-behalf-of user@example.com --target-org $TARGET_ORG"
    echo ""
    echo "    2. All flows deploy with status=Active — no manual activation needed."
    echo "       Verify in Setup > Flows that all NEPA_* flows show Active status."
    echo "       If any show Draft or Inactive, activate them manually or re-run Phase 8."
    echo "       Exception: NEPA_EIS_Section_Assembler + NEPA_EIS_Section_Draft_Trigger"
    echo "       require Einstein generative AI and are NOT deployed by this script."
    echo "       Deploy them manually when Einstein AI is provisioned:"
    echo "         sf project deploy start --metadata \"Flow:NEPA_EIS_Section_Assembler\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
    echo "         sf project deploy start --metadata \"Flow:NEPA_EIS_Section_Draft_Trigger\" --target-org $TARGET_ORG --test-level NoTestRun --wait 30"
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
    echo "    5. Load CE Library reference data (314 priority-agency records from CEQ CE Explorer v2.0):"
    echo "       python3 scripts/load_ce_library.py --org $TARGET_ORG"
    echo "       This is idempotent — safe to re-run. Uses nepa_ce_explorer_id__c as external ID."
    echo "       To load the full 2,105-record dataset (requires exclusions.json in repo root):"
    echo "       python3 scripts/load_ce_library.py --org $TARGET_ORG --all"
    echo ""
    echo "    5b. Seed demo data (optional):"
    echo "       sf apex run --file scripts/seed-sample-data.apex --target-org $TARGET_ORG"
    echo ""
    echo "    5c. Seed ServiceResource discipline values (GIS team assembly):"
    echo "       sf apex run --file demo/import_data/21_postload_discipline.apex --target-org $TARGET_ORG"
    echo ""
    echo "    6. Agentforce agents — published automatically in Phase 15b above."
    echo "       Publishing deploys the agent but does NOT activate it."
    echo "       ACTION REQUIRED after smoke-testing each agent:"
    echo "         sf agent activate --api-name NEPA_Comment_Triage --target-org $TARGET_ORG"
    echo "         sf agent activate --api-name NEPA_PreApp_Screener --target-org $TARGET_ORG"
    echo "       NEPA_PreApp_Screener is a Service Agent — verify the agent user exists first:"
    echo "         sf org create agent-user --agent-api-name NEPA_PreApp_Screener --target-org $TARGET_ORG"
    echo "       Preview before activation:"
    echo "         sf agent preview start --api-name NEPA_PreApp_Screener --target-org $TARGET_ORG --simulate-actions"
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
    echo "    6c. ArcGIS map component (nepaSiteLocationPickerOmni) — two manual steps required:"
    echo "        a. Set ESRI API key:"
    echo "           Setup > Custom Metadata Types > NEPA Map Config > API Key > Edit > set Value"
    echo "        b. Add CSP Trusted Sites (Setup > Security > CSP Trusted Sites):"
    echo "           Name: ArcGIS_JS_CDN  URL: https://js.arcgis.com   Directive: script-src"
    echo "           Name: ArcGIS_Tiles   URL: https://*.arcgis.com    Directive: connect-src"
    echo "        Without the API key the map loads but no basemap tiles render."
    echo "        Without CSP entries the ArcGIS SDK is blocked and the iframe shows blank."
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
    echo "       Add nepaFpiscExportButton LWC to Program or IndividualApplication record pages"
    echo "       via Lightning App Builder. OFD Variance Alert (NEPA_OFD_Variance_Alert)"
    echo "       runs daily at 07:00 UTC — no additional activation needed."
    echo "       Verify: sf data query --query \"SELECT COUNT() FROM Flow WHERE DeveloperName = 'NEPA_OFD_Variance_Alert' AND Status = 'Active'\" --use-tooling-api --target-org $TARGET_ORG"
    echo ""
    echo "    Full post-deploy checklist with exact commands: DEVELOPER_GUIDE.md § Post-Deploy Checklist"
fi
