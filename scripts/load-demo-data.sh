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
#   01  OperatingHours          — no dependencies
#   02  Account                 — no dependencies
#   03  Contact                 — depends on Account
#   04  ServiceTerritory        — depends on OperatingHours
#   05  WorkType                — no dependencies
#   06  ServiceResource         — no dependencies (RelatedRecordId wired via Apex)
#   07  ServiceTerritoryMember  — depends on ServiceTerritory + ServiceResource
#   08  Program                 — depends on Account
#   09  IndividualApplication   — depends on Program + Contact
#   10  ContentVersion          — created via Apex (VersionData requires Blob insert)
#   11  nepa_engagement__c      — depends on IndividualApplication
#   12  ApplicationTimeline     — depends on IndividualApplication
#   13  WorkOrder               — depends on Account + ServiceTerritory + WorkType
#   14  ServiceAppointment      — created via Apex (polymorphic ParentRecordId)
#   15  AssignedResource        — created via Apex (depends on ServiceAppointments)
#   16  PublicComplaint         — depends on Account
#   17  nepa_litigation__c      — no dependencies
#   18  Post-load Apex          — creates SA/AR/SR/CV/IA; wires all relationships
#   19  Task                    — depends on nothing; WhatId/WhoId wired by step 18

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

# ── step 01: OperatingHours ───────────────────────────────────────────────────
step_header "Step 01: OperatingHours"
upsert_csv "OperatingHours" "OperatingHours" "01_OperatingHours.csv" "External_ID__c"

# ── step 02: Account ──────────────────────────────────────────────────────────
step_header "Step 02: Account"
upsert_csv "Account" "Account" "02_Account.csv" "External_ID__c"

# ── step 03: Contact ──────────────────────────────────────────────────────────
step_header "Step 03: Contact"
upsert_csv "Contact" "Contact" "03_Contact.csv" "External_ID__c"

# ── step 04: ServiceTerritory ─────────────────────────────────────────────────
step_header "Step 04: ServiceTerritory"
upsert_csv "ServiceTerritory" "ServiceTerritory" "04_ServiceTerritory.csv" "External_ID__c"

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

# ── step 07: ServiceTerritoryMember ──────────────────────────────────────────
# ServiceTerritoryMember depends on ServiceResources created in step 18.
# The post-load Apex handles STM creation after ServiceResources exist.
step_header "Step 07: ServiceTerritoryMember (via post-load Apex)"
echo "    Skipping CSV — ServiceTerritoryMembers created in step 18 (depends on ServiceResources)"

# ── step 08: Program ──────────────────────────────────────────────────────────
step_header "Step 08: Program (Project)"
upsert_csv "Program" "Program" "08_Program.csv" "nepa_project_id__c"

# ── step 09: IndividualApplication ───────────────────────────────────────────
# LicenseTypeId is a required PSS field linking to RegulatoryAuthorizationType.
# Its ID is org-specific, so IndividualApplication is created in step 18 Apex
# which queries or creates the RegulatoryAuthorizationType at runtime.
step_header "Step 09: IndividualApplication (via post-load Apex)"
echo "    Skipping CSV — IndividualApplication created in step 18 (LicenseTypeId requires runtime ID)"

# ── step 10: ContentVersion ───────────────────────────────────────────────────
# ContentVersion requires VersionData (file content) on insert — Bulk API v2
# does not support base64 VersionData in CSV.  ContentVersions are created in
# the post-load Apex (step 18) using Blob.valueOf() for placeholder content.
step_header "Step 10: ContentVersion (via post-load Apex)"
echo "    Skipping CSV — ContentVersion created in step 18 (VersionData requires Apex Blob insert)"

# ── step 11: nepa_engagement__c ──────────────────────────────────────────────
step_header "Step 11: nepa_engagement__c (Public Engagement Events)"
insert_csv "nepa_engagement__c" "nepa_engagement__c" "11_nepa_engagement__c.csv"

# ── step 12: ApplicationTimeline ─────────────────────────────────────────────
step_header "Step 12: ApplicationTimeline (Case Events)"
insert_csv "ApplicationTimeline" "ApplicationTimeline" "12_ApplicationTimeline.csv"

# ── step 13: WorkOrder ────────────────────────────────────────────────────────
step_header "Step 13: WorkOrder"
upsert_csv "WorkOrder" "WorkOrder" "13_WorkOrder.csv" "External_ID__c"

# ── step 14: ServiceAppointment ──────────────────────────────────────────────
# ServiceAppointment.ParentRecordId is a polymorphic field — Bulk API v2 cannot
# resolve it via external ID.  ServiceAppointments and AssignedResources are
# created in the post-load Apex (step 18) which queries WorkOrder IDs at runtime.
step_header "Step 14: ServiceAppointment (via post-load Apex)"
echo "    Skipping CSV — ServiceAppointment created in step 18 (polymorphic ParentRecordId)"

# ── step 15: AssignedResource ─────────────────────────────────────────────────
step_header "Step 15: AssignedResource (via post-load Apex)"
echo "    Skipping CSV — AssignedResource created in step 18 (depends on ServiceAppointments)"

# ── step 16: PublicComplaint ──────────────────────────────────────────────────
step_header "Step 16: PublicComplaint (Public Comments)"
insert_csv "PublicComplaint" "PublicComplaint" "16_PublicComplaint.csv"

# ── step 17: nepa_litigation__c ───────────────────────────────────────────────
step_header "Step 17: nepa_litigation__c (Litigation Cases)"
insert_csv "nepa_litigation__c" "nepa_litigation__c" "17_nepa_litigation__c.csv"

# ── step 18: post-load Apex (polymorphic wiring) ─────────────────────────────
step_header "Step 18: Post-load Apex (IA, ContentVersion, SR, STM, SA, AR + wire all relationships)"
run_apex "post-load polymorphic wiring" "demo/import_data/18_postload_polymorphic.apex"

# ── step 19: Task ─────────────────────────────────────────────────────────────
step_header "Step 19: Task"
upsert_csv "Task" "Task" "19_Task.csv" "External_ID__c"

# Wire Task WhatId/WhoId now that Tasks exist (step 18 Apex also handles this
# if Tasks were loaded before, but running it again is safe — it queries by
# External_ID__c and updates in-place).

# ── post-load summary ─────────────────────────────────────────────────────────
echo ""
echo "==> Demo data load complete."
echo ""
echo "    Verify records in $TARGET_ORG:"
echo ""
echo "    sf data query --query \"SELECT Id, Name FROM Program WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM ContentVersion WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND IsLatest = true\" --target-org $TARGET_ORG"
echo "    sf data query --query \"SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG"
echo ""
echo "    To clean up all demo records:"
echo "      sf data delete bulk --sobject Task --where \"External_ID__c LIKE 'DEMO_TASK_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject AssignedResource --where \"External_ID__c LIKE 'DEMO_AR_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ServiceAppointment --where \"External_ID__c LIKE 'DEMO_SA_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject WorkOrder --where \"External_ID__c LIKE 'DEMO_WO_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject PublicComplaint --where \"Subject LIKE 'DEMO_PC%' OR Subject LIKE 'ICL Comment%' OR Subject LIKE 'OSC Comment%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_litigation__c --where \"nepa_citation__c LIKE '%9th Cir%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ApplicationTimeline --where \"nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject nepa_engagement__c --where \"nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ContentVersion --where \"Title LIKE 'Carrie Placer Mine%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject IndividualApplication --where \"nepa_federal_unique_id__c = 'IDI-38709'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Program --where \"nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ServiceTerritoryMember --where \"External_ID__c LIKE 'DEMO_STM_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ServiceResource --where \"External_ID__c LIKE 'DEMO_SR_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject WorkType --where \"External_ID__c LIKE 'DEMO_WT_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject ServiceTerritory --where \"External_ID__c LIKE 'DEMO_TERR_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Contact --where \"External_ID__c LIKE 'DEMO_CON_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject Account --where \"External_ID__c LIKE 'DEMO_ACCT_%'\" --target-org $TARGET_ORG --async"
echo "      sf data delete bulk --sobject OperatingHours --where \"External_ID__c LIKE 'DEMO_OH_%'\" --target-org $TARGET_ORG --async"
