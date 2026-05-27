# PSA-NEPA Permitting Accelerator — Feature Testing Guide

End-to-end test scenarios for the PSA-NEPA accelerator's live-integration and UI-dependent flows. Automated Apex tests cover logic correctness for all features; the steps in this guide verify production integration paths — async flow triggers, HTTP callouts, REST connectivity, BRE activation state, and UI-layer behavior that Apex cannot reach.

**Prerequisites:** Solution deployed, permission set assigned, BRE Decision Matrix rows loaded (automated by Phase 5b-data in `deploy.sh`), 36 core flows active (see QUICKSTART.md Step 4c for the activation list; 4 flows are deferred and not required for testing), sample data loaded. See QUICKSTART.md Steps 3–5 if any of these are incomplete.

**Note:** Section 16 (GIS Proximity Check) requires backlog OmniStudio components; the live integration test in that section cannot be completed. All other sections in this guide are for delivered features.

**Test suite size:** 64 test classes, 628+ test methods across all feature areas. Run `sf apex run test --test-level RunLocalTests` to execute the full automated suite (see [Section 20](#20-apex-test-suite)).

---

## Table of Contents

1. [Test Environment Setup](#1-test-environment-setup)
2. [Risk Intelligence — Litigation Risk Scoring](#2-risk-intelligence--litigation-risk-scoring)
5. [Tribal Plaintiff Intelligence](#5-tribal-plaintiff-intelligence)
11. [Tribal Consultation Hard Gate](#11-tribal-consultation-hard-gate)
12. [Public Comment Triage and EJ Detection](#12-public-comment-triage-and-ej-detection)
16. [GIS Proximity Check — Backlog](#16-gis-proximity-check)
17. [CEQ JSON Export API](#17-ceq-json-export-api)
20. [Apex Test Suite](#20-apex-test-suite)
21. [BRE Configuration Integrity](#21-bre-configuration-integrity)
23. [Test Results Summary Matrix](#23-test-results-summary-matrix)

---

## 1. Test Environment Setup

Create three clean test projects and processes. If you loaded sample data in QUICKSTART Step 5, you can use those records — the project and process IDs are printed to the debug log.

### 1a. Run the test data script

```bash
sf apex run --file scripts/create-test-data.apex --target-org <alias>
```

The script creates (or upserts if already present):

| Record | External ID | Scenario |
|---|---|---|
| Program | `TEST-BLM-EIS-001` | BLM / 10th Circuit / Energy / ESA+CWA — highest-risk EIS |
| Program | `TEST-FERC-EA-001` | FERC / DC Circuit — moderate-risk EA |
| Program | `TEST-BLM-CE-001` | BLM / 9th Circuit — CE scenario |
| IndividualApplication | `TEST-DOI-BLM-EIS-001` | EIS process, stage = Draft EIS Preparation |
| IndividualApplication | `TEST-FERC-EA-001` | EA process, stage = Comment Period |
| IndividualApplication | `TEST-DOI-BLM-CE-001` | CE process, stage = Scoping |

The script is idempotent — Programs are upserted by `nepa_project_id__c` and IndividualApplications are only inserted if one does not already exist for the linked project. Safe to re-run.

**Capture the IDs from the debug log output:**

```
=== Test data ready ===
EIS Program  (TEST-BLM-EIS-001):  <id>
EA  Program  (TEST-FERC-EA-001):   <id>
CE  Program  (TEST-BLM-CE-001):    <id>
EIS IndividualApplication:         <id>
EA  IndividualApplication:         <id>
CE  IndividualApplication:         <id>
```

These IDs are referenced throughout this guide.

---

## 2. Risk Intelligence — Litigation Risk Scoring

**Tests:** Score computation, BRE Expression Set invocation, and write-back to record via the live async flow. Tier thresholds (Very High / High / Moderate), expedited penalty, challenge prediction rules, agency performance tier, scoping overrun, and page count outliers are all fully covered by `NepaLitigationRiskScorerTest`, `NepaChallengePredictorTest`, `NepaAgencyTierSetterTest`, and `NepaTimelineRiskAssessorTest` — run Section 20 to verify those.

### 2a. High-Risk EIS Scenario

**Expected score:** BLM (39pts) + 10th Circuit (43pts) + ESA (10pts) + CWA (4pts) + EIS base = Very High tier

**Setup:** Use the TEST-EIS BLM 10th Circuit project created in Section 1. The parent Program already has `nepa_record_owner_agency__c='BLM'`, `nepa_circuit__c='10th'`, and `nepa_adjacent_statutes__c='ESA;CWA'`.

**Steps:**
1. Open the EIS `IndividualApplication` record in your org.
2. Set **NEPA Review Type** to `EIS`. The `create-test-data.apex` script leaves this field blank so this is always a genuine field change — required to fire the `IsChanged` trigger on the Risk Scorer flow.
3. Set **Record Completeness** (`nepa_record_completeness__c`) to `85`.
4. Click **Save**.
5. Wait 10–15 seconds (flow runs `AsyncAfterCommit`).
6. Refresh the record page.

> **Re-running after a previous test:** If **NEPA Review Type** is already `EIS` from a prior run, clear it first (set to blank), save, then set it back to `EIS` and save again. The flow entry condition is `IsChanged = true` — a no-op save will not fire it.

**Expected results:**
- `nepa_risk_score__c` ≥ 58 (Very High threshold)
- `nepa_risk_tier__c` = `Very High`
- `nepa_risk_score_factors__c` contains the text `AI-GENERATED — PermitTEC v0.1`
- `nepa_risk_score_updated__c` timestamp is within the last 60 seconds

**Pass criteria:** All four fields populated; tier = Very High; score factors string present.

**If score is 0:** Verify (a) BRE Decision Matrix rows are loaded — run the SOQL in Section 21a, and (b) the parent Program has `nepa_record_owner_agency__c` and `nepa_circuit__c` populated. The Risk Scorer reads both from the parent Program via `Get_RelatedProject`. Verify with: `sf data query --query "SELECT nepa_circuit__c, nepa_record_owner_agency__c FROM Program WHERE nepa_project_id__c='TEST-BLM-EIS-001'" --target-org $ALIAS`

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

> **Backlog — Integration Procedure path not verified.** The GIS proximity check architecture (Flow → Apex bridge → `NEPA_GISProximityIP` Integration Procedure) has not been verified end-to-end. The GIS layer catalog (`NEPA_GIS_Layer__mdt`), Apex bridge class, and flow trigger are deployed, but the Integration Procedure activation and end-to-end HTTP callout path are backlog. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). The Apex test class (`NepaGISProximityCheckTest`) covers the logic layer only, not live IP invocation.

**Tests:** GIS layer CMT integrity, proximity invocation logic, extraordinary circumstances flag, flow trigger conditions, detected layer record creation, and idempotent re-runs are fully covered by `NepaGISProximityCheckTest` (20 tests). The live integration test cannot be performed because the Integration Procedure path is backlog.

### 16a. Live Integration Test — Not Available (Backlog)

Since the Integration Procedure path is backlog, the live integration test cannot be performed. The `NepaGISProximityCheckTest` Apex tests (20 tests) verify the logic layer and will pass. Do not set coordinates to test live GIS callouts — the Integration Procedure activation has not been verified. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) for the resumption checklist.

---

## 17. CEQ JSON Export API

Two delivered Apex REST services expose the CEQ v1.2 payload:

| Service | Endpoint | Use case |
|---|---|---|
| `NepaCeqExportService` | `GET /services/apexrest/nepa/v1/processes/{id}` | Per-process export; used by cross-agency permit callouts |
| `NepaCeqFullExportService` | `POST /services/apexrest/nepa/v1/export/project` | Full project graph — Project → Processes → all 8 child arrays |

**Tests:** `NepaCeqExportServiceTest` (51 tests including 17 CEQ v1.2 compliance tests — see Section 20e) covers the per-process service. `NepaCeqFullExportServiceTest` (13 tests — see Section 20e2) covers the full-graph service including schema version, CEQ snake_case field names, nested comment structure, GIS at project and process level, permit DTOs, and 400/404 error guard rails. The steps below verify live endpoint routing and HTTP authentication.

### 17a. Call the Per-Process Export Endpoint

```bash
INSTANCE=$(sf org display --target-org $ALIAS --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org $ALIAS --json | jq -r '.result.accessToken')

# Replace TEST-BLM-EIS-001 with the nepa_project_id__c value of a deployed test project
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "$INSTANCE/services/apexrest/nepa/v1/processes/TEST-BLM-EIS-001" | jq .
```

**Pass criteria:**
- `success: true`
- `data` is an array of process objects
- Each process object contains CEQ v1.2 snake_case keys: `federal_id`, `type`, `status`, `agency_id`, `lead_agency`, `data_record_version`, and an `other` block with `salesforce_id`, `risk_score`, `required_permits`

### 17b. Call the Full Project Graph Export Endpoint

```bash
INSTANCE=$(sf org display --target-org $ALIAS --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org $ALIAS --json | jq -r '.result.accessToken')

# Replace <PROGRAM_ID> with the Salesforce record Id of a deployed Program
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"projectId": "<PROGRAM_ID>"}' \
  "$INSTANCE/services/apexrest/nepa/v1/export/project" | jq .
```

**Expected response shape:**

```json
{
  "success": true,
  "data": {
    "schema_version": "1.2",
    "standard": "CEQ NEPA and Permitting Data and Technology Standard",
    "exported_at": "2026-05-25T...",
    "project": {
      "id": "...",
      "project_id": "TEST-BLM-EIS-001",
      "project_title": "...",
      "lead_agency": "BLM",
      "gis_data": [ ... ],
      "processes": [
        {
          "id": "...",
          "federal_unique_id": "...",
          "nepa_review_type": "EIS",
          "process_description": "...",
          "agency_process_id": "...",
          "documents": [ { "id": "...", "comments": [ ... ] } ],
          "public_engagement_events": [ ... ],
          "case_events": [ ... ],
          "team_members": [ ... ],
          "legal_structure": [],
          "gis_data": [ ... ],
          "permits": [ ... ]
        }
      ]
    }
  }
}
```

**Pass criteria:**
- `success: true`
- `data.schema_version` = `"1.2"`
- `data.project.id` matches the Program record Id supplied
- `data.project.processes` is an array (may be empty for a project with no processes)
- Process objects use snake_case CEQ property names (`federal_unique_id`, `nepa_review_type`, `process_description`) — not camelCase
- `documents` array is present on each process (empty array when none exist)
- `permits` array is present on each process (empty array when none exist)

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
- **All tests pass**, 0 failures. The current baseline is 628+ test methods across 64 test classes; the exact count increases as tests are added. When using `--result-format json`, a passing run shows `"summary": { "outcome": "Passed", "failing": 0 }` and the `summary.passing` field shows the current count.
- Overall Apex coverage ≥ 75%
- Key test classes that must pass:
  - `NepaApiComplianceTest` (55 tests)
  - `NepaBREConfigTest` (46 tests)
  - `NepaCeqExportServiceTest` (51 tests — includes 17 CEQ v1.2 compliance tests + `@AuraEnabled` export tests + F-15 FPISC/YoY methods)
  - `NepaCeqFullExportServiceTest` (13 tests — full project graph export, schema version, CEQ field names)
  - `NepaEntity789Test` (25 tests)
  - `NepaStageGateTest` (17 tests)
  - `NepaTemplateCatalogControllerTest` (8 tests)
  - `NepaTemplateCatalogCmtTest` (13 tests)

### Test Class Inventory

| Test Class | Methods | Feature Area |
|---|---|---|
| `NepaApiComplianceTest` | 55 | CEQ v1.2 field coverage, all 9 entities |
| `NepaBREConfigTest` | 46 | BRE Expression Sets, CMT integrity |
| `NepaValidationRuleTest` | 27 | Field validation rules — all 7 VRs incl. Comment_Period_Closed, AIDocRequiresSMEReview, Phase2_Climate_Gate |
| `NepaEntity789Test` | 25 | GIS data, team members, legal structure |
| `NepaPlaintiffIntelligenceTest` | 25 | Plaintiff risk flag, tribal dual-flag, comment-level flags, ICL/Shoshone-Paiute CMT, 200-record bulk |
| `NepaCeqExportServiceTest` | 51 | REST export API, CEQ v1.2 snake_case compliance, `@AuraEnabled` export, provenance fields + IA-override fallback, lead_agency Account name, `other` nesting, permit DTO completeness + sort order, active-filter exclusion, null-field serialization, FPISC export (F-15), year-over-year trend |
| `NepaCeqFullExportServiceTest` | 13 | Full project graph export: schema version v1.2, CEQ snake_case field names, nested comments under documents, GIS at project+process level, permit DTOs, multi-process, 400/404 guard rails |
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
| `NepaVisitActionPlanLauncherTest` | 6 | Visit APT trigger handler |
| `NepaGISProximityCheckTest` | 20 | GIS proximity check (logic + CMT integrity) |
| `NepaGISProximityIPInvokerTest` | 4 | GIS proximity IP invoker |
| `NepaMapCreateCtrTest` | 5 | ArcGIS map VF controller — VF domain URL, community URL, address coordinates, constructor |
| `NepaRfpRequirementsTest` | 3 | RFP requirements coverage |
| `NepaErrorHandlingTest` | 4 | Error handling architecture |
| `NepaTemplateCatalogControllerTest` | 8 | F-11 template catalog: getCatalog filters, installTemplate error paths |
| `NepaTemplateCatalogCmtTest` | 13 | F-11 CMT seed integrity: 46 records, Review_Type coverage, APT name uniqueness |
| `NepaSlackFlowConfigTest` | 8 | F-12 Slack CMT seed integrity, placeholder guard, EJTribal Router regression |
| `NepaOFDVarianceAlertFlowTest` | 7 | F-15 OFD variance alert flow: overdue detection, task creation, bulk path |
| `NepaPreAppQualifySectorFlowTest` | 7 | F-03 pre-application sector qualification flow: sector match, no-input error, no-match guidance |
| `NepaPreAppScreeningControllerTest` | 6 | F-03 screening controller: pathway classification, permit matrix lookup, timeline range |

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

### 20e. Targeted Test — CEQ Export PIC/MFR Compliance (per-process service)

```bash
sf apex run test \
  --class-names NepaCeqExportServiceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 51 tests pass. The 17 CEQ v1.2 compliance tests verify:

| Test | Constraint verified |
|---|---|
| `compliance_federalUniqueId_nonNullOnExportedRecord` | `federal_id` non-null — required for all MFR submissions |
| `compliance_reviewType_isValidPicValue` | `type` ∈ `{EIS, EA, CE, Other Authorization}` |
| `compliance_processStatus_isValidPicValue` | `status` ∈ `{planned, pre-application, in progress, paused, completed, cancelled}` |
| `compliance_completedRecord_hasStartDate` | `start_date` key present and non-null when `nepa_start_date__c` was set |
| `compliance_envelopeShape_listResponseAlwaysArray` | List response `data` is always a JSON Array |
| `compliance_envelopeShape_singleResponseIsObject` | Single-record response `data` is a JSON Object, not Array |
| `compliance_errorEnvelope_hasRequiredFields` | Error responses carry `success: false`, `errorCode`, and `message` |
| `compliance_allDtoFields_matchCeqV12PropertyNames` | All 25 CEQ v1.2 top-level snake_case keys present; 9 NEPA-operational keys verified under `other` |
| `compliance_agencyId_nonNullWhenSet` | `agency_id` round-trips exactly — CEQ uses this as the join key to the agency registry |
| `compliance_provenanceFields_allPresent` | `data_record_version = "1.0"`, `last_updated`, `retrieved_timestamp`, `created_at` all non-null |
| `compliance_parentProjectId_populatedFromRelatedProject` | `parent_project_id` = `nepa_related_project__r.nepa_project_id__c` |
| `compliance_leadAgency_isAccountName` | `lead_agency` = Account Name traversed from `nepa_related_project__r.nepa_lead_agency__r.Name` |
| `compliance_nepaOperationalFields_nestedUnderOther` | `sla_due_date`, `risk_score`, `required_permits` in `other`; absent from top-level |
| `compliance_slaOverdue_isBoolean` | `other.sla_overdue` serializes as Boolean, not String |
| `generateCeqExport_singleProcess_returnsCompliantShape` | `@AuraEnabled` method returns CEQ v1.2 shape with `federal_id`, `data_record_version`, `other` block |
| `generateCeqExport_allActive_returnsArray` | Null `processId` returns JSON array; each element has required CEQ keys |
| `compliance_provenanceFields_iaLevelOverridesProject` | IA-level `record_owner_agency` / `data_source_agency` / `data_source_system` override Project-level fallback |

### 20e2. Targeted Test — CEQ Full Project Graph Export

```bash
sf apex run test \
  --class-names NepaCeqFullExportServiceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 13 tests pass. Tests verify:

| Test | Constraint verified |
|---|---|
| `export_missingProjectId_returns400` | Missing `projectId` in body → 400 + `MISSING_PARAM` |
| `export_unknownProjectId_returns404` | Valid ID format but no matching Program → 404 + `NOT_FOUND` |
| `export_invalidId_returns400` | Non-ID string in `projectId` → 400 + `INVALID_PARAM` |
| `export_schemaVersionIs12` | `data.schema_version` = `"1.2"`, `data.standard` present, `data.exported_at` non-null |
| `export_emptyProject_noProcesses_returnsEmptyArray` | Project with no processes → `processes` = `[]`, not null |
| `export_validProject_returnsFullPayload` | All 8 child arrays present on process node (documents, public_engagement_events, case_events, team_members, legal_structure, gis_data, permits); counts match inserted records |
| `export_processFields_mapToCeqNames` | `federal_unique_id`, `nepa_review_type`, `process_description`, `agency_process_id` present; camelCase keys (`federalUniqueId`, `reviewType`) absent |
| `export_projectFields_mapToCeqNames` | `project_id`, `project_title`, `name`, `status`, `lead_agency`, `last_updated` all present on project node |
| `export_multipleProcesses_allIncluded` | 3 processes on one project → `processes.size()` = 3 |
| `export_commentsNestedUnderDocument` | `PublicComplaint` linked via `nepa_parent_document__c` appears in `documents[0].comments`, not at process level |
| `export_processWithNoDocuments_documentsArrayEmpty` | All 4 arrays (documents, public_engagement_events, case_events, permits) are empty arrays, not null |
| `export_gisData_presentAtProjectAndProcessLevel` | GIS records appear in both `project.gis_data` and `process.gis_data` |
| `export_permitFields_mapToCeqNames` | Permit DTO contains `id`, `permit_type`, `permit_status`, `is_critical_path`, `lead_agency`, `regulatory_citation`, `process_id`, `last_updated`; `is_critical_path` = `true` round-trips correctly |

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

### 20m. Targeted Test — Agency Template Exchange (F-11)

```bash
sf apex run test \
  --tests NepaTemplateCatalogControllerTest,NepaTemplateCatalogCmtTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:**
- `NepaTemplateCatalogControllerTest` (8 tests): `getCatalog` no-filter, filter by reviewType, filter by sector, combined filter; `installTemplate` blank-name error, null-recordId error, missing-template error, getCatalog returns non-null list
- `NepaTemplateCatalogCmtTest` (13 tests): exactly 46 active CMT records, 13 CE / 13 EA / 13 EIS / 7 WO type distribution, all `APT_Unique_Name__c` values unique, all `Review_Type__c` values within `{CE, EA, EIS, WO, All}`, all records have non-blank `Agency__c`

### 20n. Targeted Test — Slack Config Integrity (F-12)

```bash
sf apex run test \
  --tests NepaSlackFlowConfigTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 8 tests pass: Default CMT record exists, `Default_Channel_Id__c` is the placeholder string, `Risk_Alert_Threshold__c` is 70, `Notify_Tribal_Channel__c` is the tribal placeholder string; EJTribal Router deploys without errors and routes EJ comments to the queue without Slack dependency; placeholder guard logic verified via CMT field assertions.

### 20o. Targeted Test — OFD Variance Alert (F-15)

```bash
sf apex run test \
  --tests NepaOFDVarianceAlertFlowTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All 7 tests pass: overdue IA (elapsed > target) generates a Task; within-target IA generates no Task; IA without `nepa_fast41_covered__c` is excluded; IA without `nepa_ofd_target_days__c` is excluded; bulk path with mixed overdue/current records creates correct count; Task has correct subject, priority, and WhatId.

### 20p. Targeted Test — Pre-Application Sector Qualification (F-03)

```bash
sf apex run test \
  --tests NepaPreAppQualifySectorFlowTest,NepaPreAppScreeningControllerTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:**
- `NepaPreAppQualifySectorFlowTest` (7 tests): sector match returns `out_ValidationPassed=true` and populated `out_SectorKey`/`out_LeadAgencyKey`; blank sector + blank NAICS returns validation error; unrecognized sector returns guidance message with sector list; NAICS-only input routes to CMT lookup; output variable types are correct
- `NepaPreAppScreeningControllerTest` (6 tests): pathway classification returns CE/EA/EIS; permit matrix lookup returns non-empty list for known sector; timeline range is non-null for matched sector; null sector returns error message; controller is guest-safe (no FLS exception)

---

## 20q. Targeted Test — Permit Issued Schedule Creator (F-05 foundation)

```bash
sf apex run test \
  --tests NepaPermitIssuedScheduleCreatorTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** Visit records are auto-created when `nepa_permit_status__c` changes to `Issued` on a `nepa_required_permit__c` record. `nepa_discipline__c` populated from `NEPA_Inspection_Schedule__mdt.Inspection_Type__c`; `nepa_trigger_layer__c` populated from `Statutory_Authority__c`; `nepa_auto_generated__c = true`. No Visits created when status is not `Issued`.

**Manual smoke test:**
1. Open a `nepa_required_permit__c` record where `nepa_permit_type__c` matches a seeded `NEPA_Inspection_Schedule__mdt` record (e.g., "CWA Section 402 NPDES Construction")
2. Change `nepa_permit_status__c` to `Issued` and save
3. Navigate to the related Visits list — confirm Visit records created with `nepa_auto_generated__c = true`, `nepa_discipline__c` populated, `nepa_trigger_layer__c` containing the CFR citation

---

### 20r. Targeted Test — BiOp Reinitiation Checker (F-05 / ESA §7)

**Manual smoke test** (no Apex test class yet — flow-only):
1. Open a Visit record linked to an `IndividualApplication` that has `nepa_has_active_biop__c = true`
2. Check `nepa_reinit_new_species_listing__c` and save
3. Confirm: a High-priority Task is created on the parent `IndividualApplication` with subject "ESA §7 Reinitiation Required — Review BiOp Compliance"; `nepa_challenge_risk_delta__c` on the IA increased by 12
4. Repeat with `nepa_reinit_rpa_not_implemented__c` — verify Task description lists both triggered fields

**Expected non-trigger:** Check a reinitiation box on a Visit whose parent IA has `nepa_has_active_biop__c = false` — no Task should be created.

---

### 20s. Targeted Test — Post-Decision Monitor Scheduler (F-09 foundation)

**Manual smoke test** (no Apex test class yet — flow-only):
1. Open an `IndividualApplication` with `nepa_review_type__c = EIS` where `nepa_ar_locked__c = false`
2. Set `nepa_ar_locked__c = true` and save (simulates ROD/FONSI issuance)
3. Navigate to the Tasks related list — confirm Tasks created for each active `NEPA_Required_Document__mdt` record where `Stage_Required_By__c = Post-Decision` and `Review_Type__c` matches `EIS` or `ALL`
4. Verify Task subjects contain the document type; Priority = High

**SOQL verification:**
```bash
sf data query \
  --query "SELECT Subject, Priority, Status FROM Task WHERE WhatId = '<IA_Id>' AND Subject LIKE 'Post-Decision%' ORDER BY Subject" \
  --target-org $ALIAS
```
Expected: 7–10 Tasks depending on review type (ALL records + EIS-specific records).

---

### 20t. CMT Seed Counts — Post-Permit Intelligence

```bash
sf data query \
  --query "SELECT COUNT(Id) cnt FROM NEPA_Inspection_Schedule__mdt WHERE Active__c = true" \
  --target-org $ALIAS
sf data query \
  --query "SELECT COUNT(Id) cnt FROM NEPA_State_Risk_Profile__mdt WHERE Active__c = true" \
  --target-org $ALIAS
sf data query \
  --query "SELECT COUNT(Id) cnt FROM NEPA_Required_Document__mdt WHERE Stage_Required_By__c = 'Post-Decision' AND Active__c = true" \
  --target-org $ALIAS
```

**Expected:** 30, 26, 10.

---

## 21. BRE Configuration Integrity

**Tests:** All Decision Matrix row counts correct; all Expression Sets are Active; CMT types have records. CMT record counts (agency risk rates, circuit weights, scoping baselines, challenge prediction rules, plaintiff profiles) are verified programmatically by `NepaBREConfigTest` — run Section 20b to verify those. The steps below verify BRE activation state that has no Apex API surface.

### 21a. Decision Matrix Row Counts

Run the following SOQL to verify row counts across all loaded Decision Matrix versions:

```bash
sf data query \
  --query "SELECT CalculationMatrixVersion.Name, COUNT(Id) cnt FROM CalculationMatrixRow GROUP BY CalculationMatrixVersion.Name ORDER BY CalculationMatrixVersion.Name" \
  --target-org <alias>
```

Expected counts:

| CalculationMatrixVersion.Name | Expected cnt |
|---|---|
| NEPA CE Screener - NAICS Routing V1 | 7 |
| NEPA CE Screener - Tier 1 Agency Sector Rules V1 | 17 |
| NEPA CE Screener - Tier 2 Agency Action Type Rules V1 | 16 |
| NEPA Risk Scorer - Review Type Points V1 | 4 |
| NEPA Risk Scorer - Agency Risk Points V1 | 7 |
| NEPA Risk Scorer - Circuit Risk Points V1 | 13 |
| NEPA Permit Matrix V1 | 9 |
| NEPA Risk Scorer - Sector Circuit Risk Points V1 | 17 (V3 only) |

If a version shows 0 rows, re-run the load script:

```bash
python3 scripts/load_decision_matrix_rows.py --org <alias> --dm <DM_dev_name> --no-skip
```

### 21b. Expression Set Activation Status

Run the following SOQL to verify activation state:

```bash
sf data query \
  --query "SELECT Name, IsEnabled FROM CalculationMatrixVersion WHERE Name LIKE 'NEPA%' ORDER BY Name" \
  --target-org <alias>
```

All V1 versions should show `IsEnabled: true`. To re-activate Expression Sets if needed:

```bash
python3 scripts/load_decision_matrix_rows.py --org <alias> --activate-es --no-skip
```

Expected active Expression Set versions:

| Expression Set | Active version |
|---|---|
| NEPA CE Screener | V3 Active |
| NEPA Litigation Risk Scorer | V1 Active |
| NEPA Permit Coordinator | V1 Active |

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
| 16a | GIS Proximity | **Backlog** — live IP test not available; `NepaGISProximityCheckTest` (20 tests) passes | | |
| 17a | CEQ Export | Per-process GET endpoint returns process payload (`success: true`, process fields present) | | |
| 17b | CEQ Export | Full project graph POST endpoint returns v1.2 payload (`schema_version: "1.2"`, snake_case keys, nested documents/comments/permits) | | |
| 20a | Test Suite | All tests pass (615+ methods, 0 failures), ≥ 75% coverage | | |
| 20b | Test Suite | NepaBREConfigTest (46 tests) passes | | |
| 20c | Test Suite | NepaApiComplianceTest (55 tests) passes | | |
| 20d | Test Suite | NepaEntity789Test (25 tests) passes | | |
| 20e | Test Suite | NepaCeqExportServiceTest (36 tests) passes | | |
| 20e2 | Test Suite | NepaCeqFullExportServiceTest (13 tests) passes | | |
| 20f | Test Suite | NepaSlaEscalationMonitorTest (12 tests) passes | | |
| 20g | Test Suite | NepaPlaintiffIntelligenceTest (23 tests) passes | | |
| 20h | Test Suite | NepaValidationRuleTest (27 tests) passes | | |
| 20i | Test Suite | NepaPermissionSetFlsTest (9 tests) passes | | |
| 20j | Test Suite | NepaStageGateTest (17 tests) passes | | |
| 20k | Test Suite | NepaAgencyPermitServiceTest (5 tests) passes | | |
| 20k | Cross-Agency | Permit Dependencies LWC renders on IA record page | | |
| 20l | Map Controller | NepaMapCreateCtrTest (5 tests) passes | | |
| 20m | F-11 Template Exchange | NepaTemplateCatalogControllerTest (8) + NepaTemplateCatalogCmtTest (13) pass | | |
| 20n | F-12 Slack Config | NepaSlackFlowConfigTest (8 tests) passes | | |
| 20o | F-15 OFD Variance | NepaOFDVarianceAlertFlowTest (7 tests) passes | | |
| 20p | F-03 PreApp Screener | NepaPreAppQualifySectorFlowTest (7) + NepaPreAppScreeningControllerTest (6) pass | | |
| 20q | F-05 Permit Schedule | NepaPermitIssuedScheduleCreatorTest passes; Visits created at permit issuance | | |
| 20r | F-05 BiOp Reinit | Reinitiation checkbox → ESA Task + +12 risk delta | | |
| 20s | F-09 Post-Decision | nepa_ar_locked__c → true creates monitoring Tasks | | |
| 20t | CMT Seed Counts | 30 Inspection Schedules, 26 State Profiles, 10 Post-Decision docs | | |
| 22a | NAICS Picker | NAICS code query returns 2,129 records across 5 levels | | |
| 22b | Site Picker | `nepaSiteLocationPickerOmni` map loads; polygon capture writes `siteLocation` to OmniScript JSON | **Backlog** | OmniScript path not verified — see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) |
| 21a | BRE Config | All DM row counts match expected | | |
| 21b | BRE Config | 3 Expression Sets Active | | |

---

## Common Failure Reference

| Symptom | Likely cause | Resolution |
|---|---|---|
| Risk score = 0 after save | BRE DM rows not loaded | Re-run `python3 scripts/load_decision_matrix_rows.py --org <alias> --no-skip` then verify row counts per Section 21a |
| Risk score = 0 after 30+ seconds | Parent Program missing `nepa_circuit__c` or `nepa_record_owner_agency__c` | Populate both fields on the Program |
| Tribal flag not set | `NEPA_Plaintiff_Profile__mdt` has no entry for the commenter org | Add org to CMT or check spelling exactly matches `nepa_organization__c` |
| Agency tier not updating | `NEPA_Agency_Tier_Setter` flow not active | Activate per QUICKSTART Step 4c item 25 |
| Stage gate not blocking | `NEPA_Stage_Gate` or `NEPA_Stage_Gate_Doc_Check` not active | Activate both; Doc Check must be active before Stage Gate |
| GIS proximity not firing | GIS Integration Procedure is backlog — not yet verified end-to-end | See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail); configuring Named Credentials will not resolve this. `NepaGISProximityCheckTest` (20 tests) validates the logic layer. |
| Per-process GET returning 404 | `nepa_project_id__c` value doesn't match | Use exact `nepa_project_id__c` value, not `Name` |
| Full-graph POST returning 404 | `projectId` in request body is a valid ID but no matching Program record exists | Use the Salesforce record Id (15 or 18 char) of an existing Program |
| Full-graph POST returning 400 `MISSING_PARAM` | `projectId` key absent from request body | Include `{"projectId": "<Id>"}` in the POST body |
| Full-graph POST returning 400 `INVALID_PARAM` | `projectId` value is not a valid Salesforce ID format | Pass an 18-character Salesforce record Id |
| Apex tests < 75% coverage | Flow-invoked Apex classes need flows active during test run | Activate the 33 core flows per QUICKSTART Step 4c, then rerun tests |
| Error record not created | Platform event delivery delay | Wait 30 seconds; if still missing, verify `NEPA_Error_Event_Handler` is active |
| `INVALID_FIELD` on SOQL | Permission set not assigned | Run `sf org assign permset --name NEPA_Permitting --target-org $ALIAS` |
| `Internal Salesforce Error: 723447963` in ContentVersion tests | Pre-existing sandbox platform bug in NEPADEMO on `ContentVersion` insert | Known issue — not fixable in code; tests include `try/catch` guards; open a Salesforce Support case if critical |
| SLA warning record incorrectly flagged overdue in mixed-batch run | `NEPA_SLA_Escalation_Monitor` flow loop variable state contamination | Ensure the deployed flow has reset assignments in both `Build_OverdueUpdate` (`nepa_sla_warning_sent__c = false`) and `Build_WarningUpdate` (`nepa_sla_overdue__c = false`) |
| No Visits created after permit status → Issued | `NEPA_Permit_Issued_Schedule_Creator` not active, or `nepa_permit_type__c` value doesn't match any `NEPA_Inspection_Schedule__mdt` record | Activate the flow; verify `Permit_Type__c` CMT field matches exactly (case-sensitive) |
| BiOp reinitiation Task not created | `NEPA_BiOp_Reinitiation_Checker` not active, or parent IA `nepa_has_active_biop__c = false` | Activate the flow; set `nepa_has_active_biop__c = true` on the parent IA before testing |
| No post-decision Tasks after AR lock | `NEPA_PostDecision_Monitor_Scheduler` not active, or no `NEPA_Required_Document__mdt` records with `Stage_Required_By__c = Post-Decision` and matching `Review_Type__c` | Activate the flow; verify CMT records deployed (run section 20t SOQL) |
