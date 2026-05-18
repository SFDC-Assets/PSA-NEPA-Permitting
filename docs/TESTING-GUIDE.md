# PSA-NEPA Permitting Accelerator — Feature Testing Guide

End-to-end test scenarios for the PSA-NEPA accelerator's live-integration and UI-dependent flows. Automated Apex tests cover logic correctness for all features; the steps in this guide verify production integration paths — async flow triggers, HTTP callouts, REST connectivity, BRE activation state, and UI-layer behavior that Apex cannot reach.

**Prerequisites:** Solution deployed, permission set assigned, BRE Decision Matrix rows imported, 33 core flows active (see QUICKSTART.md Step 4c for the activation list; 4 flows are deferred and not required for testing), sample data loaded. See QUICKSTART.md Steps 3–5 if any of these are incomplete.

**Test suite size:** 37 test classes, 514+ test methods across all feature areas. Run `sf apex run test --test-level RunLocalTests` to execute the full automated suite (see [Section 20](#20-apex-test-suite)).

---

## Table of Contents

1. [Test Environment Setup](#1-test-environment-setup)
2. [Risk Intelligence — Litigation Risk Scoring](#2-risk-intelligence--litigation-risk-scoring)
5. [Tribal Plaintiff Intelligence](#5-tribal-plaintiff-intelligence)
11. [Tribal Consultation Hard Gate](#11-tribal-consultation-hard-gate)
12. [Public Comment Triage and EJ Detection](#12-public-comment-triage-and-ej-detection)
16. [GIS Proximity Check](#16-gis-proximity-check)
17. [CEQ JSON Export API](#17-ceq-json-export-api)
20. [Apex Test Suite](#20-apex-test-suite)
21. [BRE Configuration Integrity](#21-bre-configuration-integrity)
23. [Test Results Summary Matrix](#23-test-results-summary-matrix)

---

## 1. Test Environment Setup

Create three clean test projects and processes. If you loaded sample data in QUICKSTART Step 5, you can use those records — the project and process IDs are printed to the debug log.

### 1a. Create Test Projects via CLI

```bash
ALIAS=NEPADEV   # substitute your org alias
```

Create a BLM EIS project (highest-risk scenario):

```bash
sf data create record \
  --sobject Program \
  --values "Name='TEST-EIS BLM 10th Circuit' nepa_project_id__c='TEST-BLM-EIS-001' nepa_record_owner_agency__c='BLM' nepa_circuit__c='10th' nepa_primary_sector__c='Energy Production and Management' nepa_adjacent_statutes__c='ESA;CWA'" \
  --target-org $ALIAS
```

Create a FERC EA project (moderate-risk scenario):

```bash
sf data create record \
  --sobject Program \
  --values "Name='TEST-EA FERC DC Circuit' nepa_project_id__c='TEST-FERC-EA-001' nepa_record_owner_agency__c='FERC' nepa_circuit__c='DC'" \
  --target-org $ALIAS
```

Create a BLM CE project:

```bash
sf data create record \
  --sobject Program \
  --values "Name='TEST-CE BLM 9th Circuit' nepa_project_id__c='TEST-BLM-CE-001' nepa_record_owner_agency__c='BLM' nepa_circuit__c='9th'" \
  --target-org $ALIAS
```

### 1b. Create Test Processes

`IndividualApplication` requires a `LicenseTypeId` (a `RegulatoryAuthorizationType` record). Create it once if it does not already exist, capture its ID, then create the three process records.

```bash
# Replace <EIS_PROGRAM_ID>, <EA_PROGRAM_ID>, <CE_PROGRAM_ID> with actual IDs

# Step 1 — ensure the RegulatoryAuthorizationType exists and capture its ID
LICENSE_TYPE_ID=$(sf data query \
  --query "SELECT Id FROM RegulatoryAuthorizationType WHERE Name='NEPA Environmental Review' LIMIT 1" \
  --target-org $ALIAS --json \
  | jq -r '.result.records[0].Id // empty')

if [ -z "$LICENSE_TYPE_ID" ]; then
  LICENSE_TYPE_ID=$(sf data create record \
    --sobject RegulatoryAuthorizationType \
    --values "Name='NEPA Environmental Review' RegulatoryAuthCategory='Permit'" \
    --target-org $ALIAS --json \
    | jq -r '.result.id')
fi
echo "LicenseTypeId: $LICENSE_TYPE_ID"

# Step 2 — create the three IndividualApplication records
sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' LicenseTypeId='$LICENSE_TYPE_ID' nepa_related_project__c='<EIS_PROGRAM_ID>' nepa_review_type__c='EIS' nepa_process_stage__c='Draft EIS Preparation' StatusCode='In Progress'" \
  --target-org $ALIAS

sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' LicenseTypeId='$LICENSE_TYPE_ID' nepa_related_project__c='<EA_PROGRAM_ID>' nepa_review_type__c='EA' nepa_process_stage__c='Comment Period' StatusCode='In Progress'" \
  --target-org $ALIAS

sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' LicenseTypeId='$LICENSE_TYPE_ID' nepa_related_project__c='<CE_PROGRAM_ID>' nepa_review_type__c='CE' nepa_process_stage__c='Scoping' StatusCode='In Progress'" \
  --target-org $ALIAS
```

Record all six IDs — they are referenced throughout this guide.

---

## 2. Risk Intelligence — Litigation Risk Scoring

**Tests:** Score computation, BRE Expression Set invocation, and write-back to record via the live async flow. Tier thresholds (Very High / High / Moderate), expedited penalty, challenge prediction rules, agency performance tier, scoping overrun, and page count outliers are all fully covered by `NepaLitigationRiskScorerTest`, `NepaChallengePredictorTest`, `NepaAgencyTierSetterTest`, and `NepaTimelineRiskAssessorTest` — run Section 20 to verify those.

### 2a. High-Risk EIS Scenario

**Expected score:** BLM (39pts) + 10th Circuit (43pts) + ESA (10pts) + CWA (4pts) + EIS base = Very High tier

**Setup:** Use the TEST-EIS BLM 10th Circuit project created in Section 1. The parent Program already has `nepa_record_owner_agency__c='BLM'`, `nepa_circuit__c='10th'`, and `nepa_adjacent_statutes__c='ESA;CWA'`.

**Steps:**
1. Open the EIS `IndividualApplication` record in your org.
2. Set **NEPA Review Type** to `EIS` (if not already set).
3. Set **Record Completeness** (`nepa_record_completeness__c`) to `85`.
4. Click **Save**.
5. Wait 10–15 seconds (flow runs `AsyncAfterCommit`).
6. Refresh the record page.

**Expected results:**
- `nepa_risk_score__c` ≥ 58 (Very High threshold)
- `nepa_risk_tier__c` = `Very High`
- `nepa_risk_score_factors__c` contains the text `AI-GENERATED — PermitTEC v0.1`
- `nepa_risk_score_updated__c` timestamp is within the last 60 seconds

**Pass criteria:** All four fields populated; tier = Very High; score factors string present.

**If score is 0:** Check that (a) BRE Decision Matrix rows are loaded — go to Setup → Business Rules Engine → Decision Matrices and verify row counts per QUICKSTART Step 7g, and (b) the parent Program has `nepa_record_owner_agency__c` and `nepa_circuit__c` populated. The Risk Scorer reads both from the parent Program via a `Get_RelatedProject` query.

---

## 5. Tribal Plaintiff Intelligence

**Tests:** Tribal dual-flag; risk delta; Tribal Liaison task creation; tribal consultation stage gate; comment-level plaintiff flags. Non-tribal plaintiff flag isolation, known plaintiff org matching, Idaho Conservation League and Shoshone-Paiute Tribes CMT integrity, and all CMT profile behavior are fully covered by `NepaPlaintiffIntelligenceTest` (23 tests) — run Section 20g to verify those.

### 5a. Create a Tribal Nation Comment

1. In the org UI, open the EIS `IndividualApplication` record.
2. Ensure the comment period is open: set `nepa_comment_start_date__c` to yesterday and `nepa_comment_end_date__c` to 30 days from now on the IA record.
3. Navigate to the related **Public Complaints** (Comments) related list and click **New**.
4. Set:
   - **Commenter Organization** (`nepa_organization__c`): `Navajo Nation`
   - **Comment Body**: `Tribal trust lands and water rights will be directly impacted. Government-to-government consultation under NHPA Section 106 is required.`
   - **Submission Method**: `Written`
5. Save the `PublicComplaint`.
6. Wait 10–15 seconds, refresh the parent `IndividualApplication` record.

**Expected on the `IndividualApplication`:**
- `nepa_plaintiff_risk_flag__c` = `true`
- `nepa_tribal_plaintiff_flag__c` = `true`
- `nepa_challenge_risk_delta__c` includes +20 (tribal rule)
- An open `Task` assigned to the Tribal Liaison role with subject referencing tribal consultation

**Expected on the `PublicComplaint`:**
- `nepa_plaintiff_risk_flag__c` = `true`
- `nepa_plaintiff_risk_tier__c` = `VERY_HIGH` (for Navajo Nation)
- `nepa_tribal_plaintiff_flag__c` = `true`

**Pass criteria:** Both flags true on IA and comment; comment-level flags populated; task created; delta updated.

### 5b. Verify Navajo Nation Is a Known Profile

```bash
sf data query \
  --query "SELECT Label, Risk_Tier__c, Success_Rate__c, Is_Tribal_Nation__c, Prior_Case_Count__c FROM NEPA_Plaintiff_Profile__mdt WHERE Is_Tribal_Nation__c = true" \
  --target-org $ALIAS
```

**Expected:** At least one record with `Is_Tribal_Nation__c = true` (Navajo Nation). Success_Rate__c = 0.75, Risk_Tier__c = VERY_HIGH.

---

## 11. Tribal Consultation Hard Gate

**Tests:** Stage gate blocks EA/EIS publication until tribal consultation is certified. No Apex test covers this gate — `NepaStageGateTest` covers VR-001 (tiering) and VR-004 (ESA consultation); the tribal gate requires live org verification.

### 11a. Gate Blocks Without Certified Consultation

1. Open an EA or EIS `IndividualApplication` that has `nepa_tribal_plaintiff_flag__c = true` (set in Test 5a).
2. Attempt to advance `nepa_process_stage__c` to `Final EIS` or `Decision Record`.
3. Click **Save**.

**Expected:** Save is blocked with a message referencing tribal consultation certification.

### 11b. Gate Releases After Certification

1. Open the related list of engagement events on the IA.
2. Create a `nepa_engagement__c` record with:
   - `nepa_event_type__c` = `Tribal Consultation`
   - `nepa_consultation_certified__c` = `true`
3. Retry the stage advance.

**Expected:** Stage gate passes the tribal consultation check (other gates may still block — this confirms the tribal gate specifically is cleared).

---

## 12. Public Comment Triage and EJ Detection

**Tests:** EJ keyword detection, comment triage parsing, supportive comment pass-through, tribal sovereignty keyword matching, and non-tribal plaintiff flag isolation are fully covered by `NepaCommentEJDetectorTest` (16 tests), `NepaCommentTriageParserTest` (16 tests), and `NepaPlaintiffIntelligenceTest` (23 tests). The step below verifies the AI AUP guardrail — the separation between the AI staging field and the human-editable classification field — which requires live org and field history verification.

### 12d. AI Classification vs. Human-Editable Field

Verify OMB M-24-10 guardrail:

1. After triage runs on any comment, check that:
   - `nepa_ai_classification__c` (read-only staging field) is populated
   - `nepa_comment_classification__c` (editable field) defaults to the AI suggestion but can be manually changed
2. Change `nepa_comment_classification__c` to a different value.
3. Verify field history tracking records the override with your user identity and timestamp.

---

## 16. GIS Proximity Check

**Tests:** GIS layer CMT integrity, proximity invocation logic, extraordinary circumstances flag, flow trigger conditions, detected layer record creation, and idempotent re-runs are fully covered by `NepaGISProximityCheckTest` (20 tests). The step below verifies live Named Credentials and actual ArcGIS connectivity.

### 16a. Set Project Coordinates

1. Open the TEST-EIS BLM 10th Circuit Program.
2. Set `nepa_location_lat__c` = `43.4917` and `nepa_location_lon__c` = `-111.8833` (Idaho — BLM land with ESA critical habitat nearby).
3. Save.
4. Wait 15–30 seconds (GIS check is async and involves HTTP callouts), refresh.

**Expected:**
- `nepa_proximity_result_summary__c` is populated (at minimum a "no hits" summary if the test coordinates don't intersect protected layers)
- `nepa_gis_run_timestamp__c` is recent
- One or more `nepa_detected_protection_layer__c` child records created

> **Note:** GIS callouts require the Named Credentials to be properly configured with valid authentication. In a fresh trial org without credentials configured, the GIS IP will fault and log to `NEPA_Flow_Error__c`. See Named Credentials setup in QUICKSTART Step 6 (remote site settings).

---

## 17. CEQ JSON Export API

**Tests:** Service logic, DTO field mapping, filter/pagination behavior, all 15 PIC v1.2 property names, provenance fields, envelope shapes, and error response structure are fully covered by `NepaCeqExportServiceTest` (22 tests including 9 PIC/MFR compliance tests — see Section 20e). The step below verifies live endpoint routing and HTTP authentication.

### 17a. Call the Export Endpoint

```bash
INSTANCE=$(sf org display --target-org $ALIAS --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org $ALIAS --json | jq -r '.result.accessToken')

curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$INSTANCE/services/apexrest/nepa/v1/processes/TEST-BLM-EIS-001" | jq .
```

**Expected response shape:**

```json
{
  "success": true,
  "data": {
    "ceq_standard_version": "1.2",
    "standard_name": "CEQ NEPA and Permitting Data and Technology Standard",
    "export_timestamp": "...",
    "project": { "federal_unique_project_id": "TEST-BLM-EIS-001", ... },
    "gis_data": [ ... ],
    "processes": [
      {
        "federal_unique_process_id": "...",
        "review_type": "EIS",
        "risk_score": ...,
        "documents": [ ... ],
        "comments": [ ... ],
        "engagements": [ ... ],
        "timeline": [ ... ],
        "team_members": [ ... ],
        "legal_structure": { ... }
      }
    ]
  }
}
```

**Pass criteria:**
- `success: true`
- `ceq_standard_version: "1.2"` present in root
- `project` node contains `federal_unique_project_id`
- `processes` array is non-empty
- At least one of `documents`, `comments`, `timeline` is non-empty

---

## 20. Apex Test Suite

**Tests:** All tests pass; code coverage ≥ 75%.

### 20a. Run Full Test Suite

```bash
sf apex run test \
  --target-org $ALIAS \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 15
```

**Expected:**
- **All tests pass**, 0 failures. The current baseline is 514+ test methods; the exact count increases as tests are added. When using `--result-format json`, a passing run shows `"summary": { "outcome": "Passed", "failing": 0 }` and the `summary.passing` field shows the current count.
- Overall Apex coverage ≥ 75%
- All five key test classes pass:
  - `NepaApiComplianceTest` (55 tests)
  - `NepaBREConfigTest` (46 tests)
  - `NepaEntity789Test` (25 tests)
  - `NepaCeqExportServiceTest` (22 tests — includes 9 PIC/MFR compliance tests)
  - `NepaStageGateTest` (17 tests)

### Test Class Inventory

| Test Class | Methods | Feature Area |
|---|---|---|
| `NepaApiComplianceTest` | 55 | CEQ v1.2 field coverage, all 9 entities |
| `NepaBREConfigTest` | 46 | BRE Expression Sets, CMT integrity |
| `NepaValidationRuleTest` | 27 | Field validation rules — all 7 VRs incl. Comment_Period_Closed, AIDocRequiresSMEReview, Phase2_Climate_Gate |
| `NepaEntity789Test` | 25 | GIS data, team members, legal structure |
| `NepaPlaintiffIntelligenceTest` | 25 | Plaintiff risk flag, tribal dual-flag, comment-level flags, ICL/Shoshone-Paiute CMT, 200-record bulk |
| `NepaCeqExportServiceTest` | 27 | REST export API, PIC/MFR compliance, null-field serialization, combined filters |
| `NepaCommentControllerTest` | 19 | Comment intake and LWC controller |
| `NepaLitigationRiskScorerTest` | 19 | BRE risk scoring, tier thresholds, 200-record bulk, null project link |
| `NepaChallengePredictorTest` | 13 | Challenge prediction rules, basis field, bulk 3-record safety |
| `NepaStageGateTest` | 17 | Before-save stage gate validation rules |
| `NepaCommentTriageParserTest` | 17 | Comment triage parser |
| `NepaCommentEJDetectorTest` | 17 | EJ keyword detection |
| `NepaTimelineRiskAssessorTest` | 15 | Timeline risk assessment |
| `NepaProjectControllerTest` | 15 | Project LWC controller |
| `NepaSlaEscalationMonitorTest` | 12 | SLA due dates, escalation monitor flow |
| `NepaDocumentControllerTest` | 10 | Document upload and query |
| `NepaPermissionSetFlsTest` | 9 | FLS enforcement — risk/plaintiff fields read-only via NEPA_Permitting PS |
| `NepaAIGovernanceTest` | 13 | AI governance and AUP guardrails |
| `NepaDefensibilityGapCheckerTest` | 9 | Defensibility gap detection |
| `NepaAdminRecordCheckerTest` | 8 | Administrative record completeness |
| `NepaTimelineControllerTest` | 7 | Timeline LWC controller |
| `NepaEngagementControllerTest` | 6 | Engagement event controller |
| `NepaCeScreenerTest` | 7 | CE screening and intake |
| `NepaAIGovernanceFlowTest` | 7 | AI governance flow integration |
| `NepaAgencyTierSetterTest` | 6 | Agency performance tier |
| `NepaCommentResponseTaskTest` | 7 | Comment response task creation |
| `NepaCommentDuplicateCheckTest` | 7 | Comment duplicate detection |
| `NepaCloseAdminRecordFlowTest` | 7 | Administrative record close flow |
| `NepaCommentAIRouterTest` | 6 | Comment AI router entry flow |
| `NepaEJTribalRouterTest` | 6 | EJ/tribal keyword gate routing |
| `NepaLayerDisciplineResolverTest` | 5 | GIS layer discipline resolver |
| `NepaActionPlanLauncherTest` | 5 | Action plan launcher flow |
| `NepaGISProximityCheckTest` | 20 | GIS proximity check (logic + CMT integrity) |
| `NepaGISProximityIPInvokerTest` | 4 | GIS proximity IP invoker |
| `NepaRfpRequirementsTest` | 3 | RFP requirements coverage |
| `NepaErrorHandlingTest` | 4 | Error handling architecture |

### 20b. Targeted Test — BRE Configuration

```bash
sf apex run test \
  --class-names NepaBREConfigTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 46 BRE config tests pass, including verification that all CMT types have at least one active record, statute weight point values match PermitTEC corpus calibration, required document registry entries exist for CE, EA, and EIS pathways, all 6 new Stage 10-13 sector-circuit cells are present, `NEPA_Doc_Count_Threshold__mdt` has entries for CE/EA/EIS, and `NEPA_Phase2_Climate_Gate` validation rule fires when climate assessment is required but incomplete.

### 20c. Targeted Test — CEQ API Compliance

```bash
sf apex run test \
  --class-names NepaApiComplianceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 55 compliance tests pass, verifying CEQ v1.2 field coverage across all 9 entities.

### 20d. Targeted Test — Entity 7/8/9 Coverage

```bash
sf apex run test \
  --class-names NepaEntity789Test \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** GIS data (`nepa_gis_data__c`), user roles (`nepa_process_team_member__c`), and legal structure (`RegulatoryCode`) all pass field coverage assertions.

### 20e. Targeted Test — CEQ Export PIC/MFR Compliance

```bash
sf apex run test \
  --class-names NepaCeqExportServiceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 27 tests pass (18 functional + 9 PIC compliance). The 9 compliance tests verify:

| Test | Constraint verified |
|---|---|
| `compliance_federalUniqueId_nonNullOnExportedRecord` | `federalUniqueId` non-null — required for all MFR submissions |
| `compliance_reviewType_isValidPicValue` | `reviewType` ∈ `{EIS, EA, CE, Other Authorization}` |
| `compliance_processStatus_isValidPicValue` | `processStatus` ∈ `{planned, pre-application, in progress, paused, completed, cancelled}` |
| `compliance_completedRecord_hasStartDate` | `startDate` key present and non-null when `nepa_start_date__c` was set |
| `compliance_envelopeShape_listResponseAlwaysArray` | List response `data` is always a JSON Array |
| `compliance_envelopeShape_singleResponseIsObject` | Single-record response `data` is a JSON Object, not Array |
| `compliance_errorEnvelope_hasRequiredFields` | Error responses carry `success: false`, `errorCode`, and `message` |
| `compliance_allDtoFields_matchPicPropertyNames` | All 15 PIC v1.2 DTO keys present: `id, federalUniqueId, reviewType, processStatus, processStage, agencyId, startDate, targetCompletionDate, slaDueDate, slaOverdue, riskScore, riskTier, recordCompleteness, lastStageTransition, lastModified` |
| `compliance_agencyId_nonNullWhenSet` | `agencyId` round-trips exactly — CEQ uses this as the join key to the agency registry |

### 20f. Targeted Test — SLA Escalation Monitor

```bash
sf apex run test \
  --class-names NepaSlaEscalationMonitorTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 12 tests pass, including mixed-batch overdue/warning records, EA SLA config matching, SLA due date setter for EIS and CE review types, and warning deduplication.

### 20g. Targeted Test — Plaintiff Intelligence

```bash
sf apex run test \
  --class-names NepaPlaintiffIntelligenceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 25 tests pass, covering VERY_HIGH org match, HIGH match, CONTAINS partial match, no-match isolation, blank org skip, tribal dual-flag, task subject content, 5-record and 200-record bulk safety, 200-mixed-org isolation (known flagged / unknown not flagged), comment-level flag writes (`nepa_plaintiff_risk_flag__c`, `nepa_plaintiff_risk_tier__c`, `nepa_tribal_plaintiff_flag__c` on `PublicComplaint`), Idaho Conservation League CMT assertions (HIGH, non-tribal), and Shoshone-Paiute Tribes CMT assertions (VERY_HIGH, tribal, 100% win rate).

### 20h. Targeted Test — Validation Rules

```bash
sf apex run test \
  --class-names NepaValidationRuleTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 27 tests pass, covering all 7 active validation rules: description minimum length, FONSI/ROD on CE, waiver legal sufficiency, tiering age check, `NEPA_Comment_Period_Closed` (after-deadline blocks, before-deadline saves, ISNEW guard on update, null end-date fail-open), `NEPA_AIDocumentRequiresSMEReview` (blocks AI+Approved with missing reviewer or date, passes when both set, non-AI doc exempt), and `NEPA_Phase2_Climate_Gate` bypass paths (not-applicable, not-required, assessment-complete, non-Decision stage).

### 20i. Targeted Test — Permission Set FLS

```bash
sf apex run test \
  --class-names NepaPermissionSetFlsTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 9 FLS tests pass. Tests use `System.runAs()` with a Standard User assigned the `NEPA_Permitting` permission set. Verified constraints: `nepa_plaintiff_risk_flag__c`, `nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_risk_score_factors__c` on IA are not updateable; `PublicComplaint` plaintiff flags are not updateable; all risk/plaintiff fields are readable; System Administrator context can update `nepa_risk_score__c`.

### 20j. Targeted Test — Stage Gate

```bash
sf apex run test \
  --class-names NepaStageGateTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 17 tests pass, including VR-001 (supplementation gate), VR-004 (ESA consultation gate), error message content assertions (`1502.9` and `ESA consultation`), stage transition timestamp stamping, and target completion date auto-population.

### 20k. Targeted Test — Cross-Agency Permit Service

```bash
sf apex run test \
  --class-names NepaAgencyPermitServiceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 5 tests pass:
- `getPermitStatuses_successCallout` — live callout success path: `calloutSuccess=true`, `liveStatus` populated from mock response
- `getPermitStatuses_calloutFailure` — HTTP exception degradation: `calloutSuccess=false`, `localStatus` preserved
- `getPermitStatuses_cmtNotFound` — missing CMT endpoint key: `calloutSuccess=false`, error message contains endpoint key name
- `getPermitStatuses_http404Response` — HTTP 404 response: `calloutSuccess=false`, `calloutError` populated
- `getPermitStatuses_emptyPermitList` — no permit records: returns empty list, no exception

**Manual smoke test (after deploying and updating Named Credential URLs):**

1. Create a `nepa_required_permit__c` record on any IndividualApplication with:
   - `nepa_agency_endpoint_key__c` = `USACE`
   - `nepa_external_federal_id__c` = any UUID
   - `nepa_permit_status__c` = `Under Review`
2. Open the IndividualApplication record page → **Permit Dependencies** tab
3. Confirm the component renders the permit row with spinner → status badge
4. Confirm "Live sync unavailable — showing cached data" appears if the USACE endpoint is not yet configured (expected)

---

## 21. BRE Configuration Integrity

**Tests:** All Decision Matrix row counts correct; all Expression Sets are Active; CMT types have records. CMT record counts (agency risk rates, circuit weights, scoping baselines, challenge prediction rules, plaintiff profiles) are verified programmatically by `NepaBREConfigTest` — run Section 20b to verify those. The steps below verify BRE activation state that has no Apex API surface.

### 21a. Decision Matrix Row Counts

In the org, go to **Setup → Business Rules Engine → Decision Matrices** and verify:

| Decision Matrix | Expected row count |
|---|---|
| NEPA CE Screener - NAICS Routing | 7 |
| NEPA CE Screener - Tier 1 Agency Sector Rules | 17 |
| NEPA CE Screener - Tier 2 Agency Action Type Rules | 16 |
| NEPA Risk Scorer - Review Type Points | 4 |
| NEPA Risk Scorer - Agency Risk Points | 7 |
| NEPA Risk Scorer - Circuit Risk Points | 13 |
| NEPA Permit Matrix | 9 |
| NEPA Risk Scorer - Sector Circuit Risk Points | 17 (V3 only) |

If a matrix shows 0 rows, re-import the corresponding CSV from `decision_matrix_rows/` per QUICKSTART Step 4b.

### 21b. Expression Set Activation Status

Go to **Setup → Business Rules Engine → Expression Sets** and verify:

| Expression Set | Active version |
|---|---|
| NEPA CE Screener | V2 Active |
| NEPA Litigation Risk Scorer | V2 Active (V3 Draft) |
| NEPA Permit Coordinator | V2 Active |

---

## 23. Test Results Summary Matrix

Use this matrix to track test execution. Mark each test ✅ Pass, ❌ Fail, or ⚠️ Blocked.

| # | Feature | Test | Status | Notes |
|---|---|---|---|---|
| 2a | Risk Scoring | High-risk EIS score ≥ 58, tier = Very High | | |
| 5a | Tribal Intel | Navajo Nation comment → dual flags + task | | |
| 5b | Tribal Intel | CMT has tribal profile records | | |
| 11a | Tribal Gate | Stage blocked without certified consultation | | |
| 11b | Tribal Gate | Stage passes after certification | | |
| 12d | AI AUP | AI classification read-only; human field editable | | |
| 16a | GIS Proximity | Coordinates trigger IP; layers written back | | |
| 17a | CEQ Export | REST API returns 9-entity payload | | |
| 20a | Test Suite | All tests pass (514+ methods, 0 failures), ≥ 75% coverage | | |
| 20b | Test Suite | NepaBREConfigTest (46 tests) passes | | |
| 20c | Test Suite | NepaApiComplianceTest (55 tests) passes | | |
| 20d | Test Suite | NepaEntity789Test (25 tests) passes | | |
| 20e | Test Suite | NepaCeqExportServiceTest (27 tests) passes | | |
| 20f | Test Suite | NepaSlaEscalationMonitorTest (12 tests) passes | | |
| 20g | Test Suite | NepaPlaintiffIntelligenceTest (23 tests) passes | | |
| 20h | Test Suite | NepaValidationRuleTest (27 tests) passes | | |
| 20i | Test Suite | NepaPermissionSetFlsTest (9 tests) passes | | |
| 20j | Test Suite | NepaStageGateTest (17 tests) passes | | |
| 20k | Test Suite | NepaAgencyPermitServiceTest (5 tests) passes | | |
| 20k | Cross-Agency | Permit Dependencies LWC renders on IA record page | | |
| 21a | BRE Config | All DM row counts match expected | | |
| 21b | BRE Config | 3 Expression Sets Active | | |

---

## Common Failure Reference

| Symptom | Likely cause | Resolution |
|---|---|---|
| Risk score = 0 after save | BRE DM rows not loaded | Import CSVs per QUICKSTART Step 4b |
| Risk score = 0 after 30+ seconds | Parent Program missing `nepa_circuit__c` or `nepa_record_owner_agency__c` | Populate both fields on the Program |
| Tribal flag not set | `NEPA_Plaintiff_Profile__mdt` has no entry for the commenter org | Add org to CMT or check spelling exactly matches `nepa_organization__c` |
| Agency tier not updating | `NEPA_Agency_Tier_Setter` flow not active | Activate per QUICKSTART Step 4c item 25 |
| Stage gate not blocking | `NEPA_Stage_Gate` or `NEPA_Stage_Gate_Doc_Check` not active | Activate both; Doc Check must be active before Stage Gate |
| GIS proximity not firing | Named Credentials not configured | Configure Named Credentials per QUICKSTART Step 6 |
| CEQ API returning 404 | `nepa_project_id__c` value doesn't match | Use exact `nepa_project_id__c` value, not `Name` |
| Apex tests < 75% coverage | Flow-invoked Apex classes need flows active during test run | Activate the 33 core flows per QUICKSTART Step 4c, then rerun tests |
| Error record not created | Platform event delivery delay | Wait 30 seconds; if still missing, verify `NEPA_Error_Event_Handler` is active |
| `INVALID_FIELD` on SOQL | Permission set not assigned | Run `sf org assign permset --name NEPA_Permitting --target-org $ALIAS` |
| `Internal Salesforce Error: 723447963` in ContentVersion tests | Pre-existing sandbox platform bug in NEPADEMO on `ContentVersion` insert | Known issue — not fixable in code; tests include `try/catch` guards; open a Salesforce Support case if critical |
| SLA warning record incorrectly flagged overdue in mixed-batch run | `NEPA_SLA_Escalation_Monitor` flow loop variable state contamination | Ensure the deployed flow has reset assignments in both `Build_OverdueUpdate` (`nepa_sla_warning_sent__c = false`) and `Build_WarningUpdate` (`nepa_sla_overdue__c = false`) |
