#!/usr/bin/env bash
# load-demo-data.sh — Load Carrie Placer Mine demo data into a NEPA Permitting org
#
# Usage:
#   ./scripts/load-demo-data.sh <target-org-alias>
#
# Requirements:
#   - sf CLI v2 authenticated to <target-org-alias>
#   - Full metadata stack already deployed (run deploy.sh first)
#   - Run from repo root
#
# Load order (dependency-safe):
#   02  Account                 — no dependencies
#   03  Contact                 — depends on Account
#   05  WorkType                — no dependencies
#   06  ServiceResource         — no dependencies (RelatedRecordId wired via Apex)
#   08  Program                 — depends on Account
#   09  IndividualApplication   — depends on Program + Contact
#   10  ContentVersion          — created via Apex (VersionData requires Blob insert)
#   11  nepa_engagement__c      — created in step 27 Apex (nepa_process__c required, not in CSV)
#   12  ApplicationTimeline     — depends on IndividualApplication
#   16  PublicComplaint         — depends on Account
#   17  nepa_litigation__c      — no dependencies
#   18  Post-load Apex          — creates Visit(field surveys)/SR/CV/IA; wires all relationships
#   19  Task                    — created in step 27 Apex (Bulk API v2 hangs on small Task payloads;
#                                  WhatId wired in same transaction)
#   20  Entity 9/8/7 Apex       — RegulatoryCode, team members, GIS container + polygon
#   21  ServiceResource disc.   — nepa_discipline__c on ServiceResources
#   22  GIS team assembly       — proximity results, auto-assembled team, auto-generated Visits
#   23  Flow refresh Apex       — risk scorer + permit coordinator recalc
#   27  Post-load Apex          — nepa_engagement__c, PublicComplaint PC_003, decision_payload, ar_export,
#                                 Task (8 records with WhatId wired)

set -euo pipefail

TARGET_ORG="${1:-}"
if [[ -z "$TARGET_ORG" ]]; then
    echo "Usage: $0 <target-org-alias>" >&2
    exit 1
fi

DATA_DIR="demo/import_data"

# ── helpers ───────────────────────────────────────────────────────────────────

step_header() { echo ""; echo "==> $1"; }

# Upsert a CSV using an external ID field as the upsert key.
# Usage: upsert_csv <label> <object> <file> <external-id-field>
upsert_csv() {
    local label="$1" object="$2" file="$3" ext_id="$4"
    echo "    Upserting $label ($file) ..."
    local result
    result=$(sf data upsert bulk \
        --sobject "$object" \
        --file "$DATA_DIR/$file" \
        --external-id "$ext_id" \
        --target-org "$TARGET_ORG" \
        --wait 60 \
        --json 2>/dev/null) || true

    echo "$result" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('result', {})
    if 'successfulRecords' in r:
        ok  = r.get('successfulRecords', 0)
        bad = r.get('failedRecords', 0)
        print('    [JobComplete] success={} failed={}'.format(ok, bad))
    else:
        recs   = r.get('records', {})
        ok     = len(recs.get('successfulResults', []))
        bad    = len(recs.get('failedResults', []))
        state  = r.get('jobInfo', {}).get('state', d.get('status', '?'))
        job_id = r.get('jobInfo', {}).get('id', '')
        print('    [{}] success={} failed={}'.format(state, ok, bad))
        for e in recs.get('failedResults', []):
            print('    FAIL: {} -- {}'.format(e.get('sf__Id','?'), e.get('sf__Error','')))
        if bad > 0 and job_id:
            print('    Details: sf data bulk results --job-id {}'.format(job_id))
except Exception as ex:
    print('    (could not parse result):', ex)
" 2>&1
}

# Insert a CSV (no upsert key — for objects without an external ID field).
# Usage: insert_csv <label> <object> <file>
insert_csv() {
    local label="$1" object="$2" file="$3"
    echo "    Inserting $label ($file) ..."
    local result
    result=$(sf data import bulk \
        --sobject "$object" \
        --file "$DATA_DIR/$file" \
        --target-org "$TARGET_ORG" \
        --wait 60 \
        --json 2>/dev/null) || true

    echo "$result" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('result', {})
    if 'successfulRecords' in r:
        ok  = r.get('successfulRecords', 0)
        bad = r.get('failedRecords', 0)
        print('    [JobComplete] success={} failed={}'.format(ok, bad))
    else:
        recs   = r.get('records', {})
        ok     = len(recs.get('successfulResults', []))
        bad    = len(recs.get('failedResults', []))
        state  = r.get('jobInfo', {}).get('state', d.get('status', '?'))
        job_id = r.get('jobInfo', {}).get('id', '')
        print('    [{}] success={} failed={}'.format(state, ok, bad))
        for e in recs.get('failedResults', []):
            print('    FAIL: {} -- {}'.format(e.get('sf__Id','?'), e.get('sf__Error','')))
        if bad > 0 and job_id:
            print('    Details: sf data bulk results --job-id {}'.format(job_id))
except Exception as ex:
    print('    (could not parse result):', ex)
" 2>&1
}

# Run an Apex file.
run_apex() {
    local label="$1" file="$2"
    local apex_tmp
    apex_tmp=$(mktemp /tmp/apex_out_XXXXXX.json)
    echo "    Running Apex: $label ..."
    sf apex run \
        --file "$file" \
        --target-org "$TARGET_ORG" \
        --json 2>/dev/null > "$apex_tmp" || true
    python3 - "$apex_tmp" <<'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    r = d.get('result', d.get('data', {}))
    if r.get('success'):
        print('    [Succeeded] Apex executed cleanly')
        logs = r.get('logs','')
        for line in logs.split('\n'):
            if 'DEBUG' in line:
                print('   ', line.split('DEBUG|')[-1].strip())
    else:
        prob = r.get('compileProblem') or r.get('exceptionMessage') or d.get('message','?')
        line_no = r.get('line','')
        print('    [FAILED] line={} {}'.format(line_no, prob))
        st = r.get('exceptionStackTrace','')
        if st:
            print('   ', st[:300])
except Exception as e:
    print('    (could not parse result):', e)
PYEOF
    rm -f "$apex_tmp"
}

# ── preflight ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Preflight"
sf org display --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c "
import sys, json
d = json.load(sys.stdin).get('result', {})
print('    Org: {} ({})'.format(d.get('alias', '?'), d.get('instanceUrl', '?')))
print('    User: {}'.format(d.get('username', '?')))
"

# ── step 02: Account ──────────────────────────────────────────────────────────
step_header "Step 02: Account"
upsert_csv "Account" "Account" "02_Account.csv" "External_ID__c"

# ── step 03: Contact ──────────────────────────────────────────────────────────
step_header "Step 03: Contact"
upsert_csv "Contact" "Contact" "03_Contact.csv" "External_ID__c"

# ── step 05: WorkType ─────────────────────────────────────────────────────────
step_header "Step 05: WorkType"
upsert_csv "WorkType" "WorkType" "05_WorkType.csv" "External_ID__c"

# ── step 06: ServiceResource ──────────────────────────────────────────────────
# ServiceResource.RelatedRecordId (required) accepts only User IDs — not Contacts.
# All 7 specialists are created in the post-load Apex (step 18) using the
# running user's ID as RelatedRecordId, which is the only available User in
# a fresh demo org. Skip CSV load for this object.
step_header "Step 06: ServiceResource (via post-load Apex)"
echo "    Skipping CSV — ServiceResource created in step 18 (requires User ID)"

# ── step 08: Program ──────────────────────────────────────────────────────────
step_header "Step 08: Program (Project)"
upsert_csv "Program" "Program" "08_Program.csv" "nepa_project_id__c"

# ── step 09: IndividualApplication ───────────────────────────────────────────
# LicenseTypeId is a required PSS field linking to RegulatoryAuthorizationType.
# Its ID is org-specific, so IndividualApplication is created in step 18 Apex
# which queries or creates the RegulatoryAuthorizationType at runtime.
#
# PREREQUISITE: Phase 5d of deploy.sh must have imported data/seed/regulatory_authorization_type_seed.json
# (49 RegulatoryAuthorizationType records). NEPA_Permit_Record_Creator queries these by Name to populate
# nepa_required_permit__c child records. If the seed was not imported, permit records will create with
# label text only — no critical-path flag, lead agency, or SLA due dates.
step_header "Step 09: IndividualApplication (via post-load Apex)"
echo "    Skipping CSV — IndividualApplication created in step 18 (LicenseTypeId requires runtime ID)"

# ── step 10: ContentVersion ───────────────────────────────────────────────────
# ContentVersion requires VersionData (file content) on insert — Bulk API v2
# does not support base64 VersionData in CSV.  ContentVersions are created in
# the post-load Apex (step 18) using Blob.valueOf() for placeholder content.
step_header "Step 10: ContentVersion (via post-load Apex)"
echo "    Skipping CSV — ContentVersion created in step 18 (VersionData requires Apex Blob insert)"

# step 11: nepa_engagement__c — handled in step 27 Apex (nepa_process__c required, not in CSV)

# ── step 12: ApplicationTimeline ─────────────────────────────────────────────
step_header "Step 12: ApplicationTimeline (Case Events)"
upsert_csv "ApplicationTimeline" "ApplicationTimeline" "12_ApplicationTimeline.csv" "External_ID__c"

# ── step 16: PublicComplaint ──────────────────────────────────────────────────
step_header "Step 16: PublicComplaint (Public Comments)"
upsert_csv "PublicComplaint" "PublicComplaint" "16_PublicComplaint.csv" "External_ID__c"

# ── step 17: nepa_litigation__c ───────────────────────────────────────────────
step_header "Step 17: nepa_litigation__c (Litigation Cases)"
upsert_csv "nepa_litigation__c" "nepa_litigation__c" "17_nepa_litigation__c.csv" "External_ID__c"

# ── step 18: post-load Apex (polymorphic wiring) ─────────────────────────────
step_header "Step 18: Post-load Apex (IA, ContentVersion, SR, Visits + wire all relationships)"
run_apex "post-load polymorphic wiring" "demo/import_data/18_postload_polymorphic.apex"

# step 19: Task — handled in step 27 Apex (Bulk API v2 hangs on small Task payloads)

# ── step 20: Entity 9/8/7 Apex (RegulatoryCode, team members, GIS container + polygon) ──
step_header "Step 20: Entity 9/8/7 (RegulatoryCode, Team Members, nepa_gis_data__c + GIS polygon + lat/lon)"
run_apex "entity 9/8/7 demo data" "demo/import_data/20_entities789_demo_data.apex"

# ── step 21: ServiceResource discipline ───────────────────────────────────────
step_header "Step 21: ServiceResource nepa_discipline__c"
run_apex "ServiceResource discipline" "demo/import_data/21_postload_discipline.apex"

# ── step 22: GIS proximity results + auto-assembled team + auto-generated Visits ─
step_header "Step 22: GIS proximity results, auto-assembled team, and auto-generated Visits"
run_apex "GIS team assembly" "demo/import_data/22_postload_gis_team_assembly.apex"

# ── step 23: Flow refresh (risk scorer + permit coordinator recalc) ───────────
step_header "Step 23: Flow refresh (risk scorer + permit coordinator recalc)"
run_apex "flow refresh" "demo/import_data/23_postload_flow_refresh.apex"

# ── step 27: records requiring Apex insert (nepa_engagement__c, PC_003, decision_payload, ar_export, Task) ─
# nepa_decision_payload__c and nepa_ar_export__c are inserted here via Apex rather than CSV upsert.
# Bulk API v2 does not support relationship-path external ID keys (nepa_process__r.nepa_federal_unique_id__c)
# as the upsert key on these objects, so CSV upsert always returns 0 records without error.
step_header "Step 27: Apex insert (engagement, PublicComplaint PC_003, decision_payload, ar_export, Task)"
run_apex "missing records insert" "demo/import_data/27_postload_missing_records.apex"

# ── step 28 (label): OFD coordination milestones ─────────────────────────────
step_header "Step 28a: OFD Coordination Milestones (ApplicationTimeline OFD tracks for IDI-38709)"
run_apex "OFD milestones" "demo/import_data/27_ofd_milestones.apex"

# ── step 28: nepa_required_permit__c (NPDES + CWA 404 permits for Scene 7) ───
step_header "Step 28: nepa_required_permit__c (DEMO_RP_001 NPDES + DEMO_RP_002 CWA 404)"
run_apex "required permits" "demo/import_data/28_required_permits.apex"

# ── step 29: Scene 7-B inspection Visits (safety net for async flow) ──────────
step_header "Step 29: Scene 7-B Inspection Visits (NPDES compliance schedule)"
run_apex "inspection visits" "demo/import_data/29_scene7_inspection_visits.apex"

# ── step 30: Scene 7-C BiOp reinitiation trigger ──────────────────────────────
step_header "Step 30: Scene 7-C BiOp reinitiation (nepa_reinit_new_species_listing__c + ESA Task)"
run_apex "BiOp reinitiation" "demo/import_data/30_scene7_biop_reinit.apex"

# ── step 31: NEPA Visit Action Plan Templates (AssessmentTaskDefinition + APT + ItemValues) ──
step_header "Step 31a: AssessmentTaskDefinition records for NEPA Visit APTs"
run_apex "AssessmentTaskDefinition seed" "demo/import_data/31a_postload_atd.apex"

step_header "Step 31b: ActionPlanTemplate + Version + Items"
run_apex "ActionPlanTemplate seed" "demo/import_data/31b_postload_apt.apex"

step_header "Step 31c: ActionPlanTemplateItemValue + publish"
run_apex "ActionPlanTemplateItemValue + publish" "demo/import_data/31c_postload_apt_values.apex"

# ── step 32: CEQ v1.2 provenance backfill ─────────────────────────────────────
# Sets data_record_version, data_source_agency, data_source_system, and
# record_owner_agency on Carrie Placer Mine records that pre-date the v1.2
# provenance field additions.
step_header "Step 32: CEQ v1.2 Provenance Backfill (IDI-38709)"
run_apex "provenance backfill" "demo/import_data/32_provenance_backfill.apex"

# ── post-load summary ─────────────────────────────────────────────────────────
echo ""
echo "==> Demo data load complete."
echo ""
echo "    Verify records in $TARGET_ORG:"
echo ""
echo "    sf data query --query \"SELECT Id, Name FROM Program WHERE nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM ContentVersion WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND IsLatest = true\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM nepa_required_permit__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo ""
echo "    Expected: 6+ nepa_required_permit__c records for the Carrie Placer Mine demo."
echo "    Permit types should include: BLM Application for Permit to Drill, ESA Section 7 Consultation,"
echo "    NHPA Section 106 Consultation, CWA Section 404 Permit (GIS-triggered by NHD proximity flag)."
echo "    If count is 0: NEPA_Permit_Record_Creator flow did not fire OR RegulatoryAuthorizationType seed"
echo "    is missing. Re-run seed: sf data import tree --files data/seed/regulatory_authorization_type_seed.json --target-org $TARGET_ORG"
echo ""
echo "    To clean up all demo records:"
echo "      sf data delete bulk --sobject Task --where \"Subject LIKE 'Initiate IDWR%' OR Subject LIKE 'File EPA%' OR Subject LIKE 'Day-30%' OR Subject LIKE 'Add Dust%' OR Subject LIKE 'Generate ARMPA%' OR Subject LIKE 'Confirm Tribal%' OR Subject LIKE 'Verify Required%' OR Subject LIKE 'Applicant Portal Update%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Visit --where \"nepa_auto_generated__c = true AND nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_process_team_member__c --where \"nepa_assembly_source__c = 'GIS_Auto_Assembly' AND nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_detected_protection_layer__c --where \"nepa_program__r.nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject PublicComplaint --where \"Subject LIKE 'DEMO_PC%' OR Subject LIKE 'ICL Comment%' OR Subject LIKE 'OSC Comment%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_litigation__c --where \"nepa_citation__c LIKE '%9th Cir%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ApplicationTimeline --where \"nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_engagement__c --where \"nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ContentVersion --where \"Title LIKE 'Carrie Placer Mine%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject IndividualApplication --where \"nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Program --where \"nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ServiceResource --where \"External_ID__c LIKE 'DEMO_SR_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject WorkType --where \"External_ID__c LIKE 'DEMO_WT_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Contact --where \"External_ID__c LIKE 'DEMO_CON_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Account --where \"External_ID__c LIKE 'DEMO_ACCT_%'\" --target-org $TARGET_ORG --async"
