# PSA-NEPA Permitting Accelerator — Feature Testing Guide

End-to-end test scenarios for every major capability of the PSA-NEPA accelerator. Use this guide after completing deployment (see [QUICKSTART.md](QUICKSTART.md)). Each test is self-contained with setup steps, exact actions, expected results, and pass criteria.

**Prerequisites:** Solution deployed, permission set assigned, BRE Decision Matrix rows imported, all 31 flows active, sample data loaded. See QUICKSTART.md Steps 3–5 if any of these are incomplete.

---

## Table of Contents

1. [Test Environment Setup](#1-test-environment-setup)
2. [Risk Intelligence — Litigation Risk Scoring](#2-risk-intelligence--litigation-risk-scoring)
3. [Risk Intelligence — Tier Thresholds and Score Composition](#3-risk-intelligence--tier-thresholds-and-score-composition)
4. [Risk Intelligence — Challenge Prediction Rules](#4-risk-intelligence--challenge-prediction-rules)
5. [Tribal Plaintiff Intelligence](#5-tribal-plaintiff-intelligence)
6. [Agency Performance Tier](#6-agency-performance-tier)
7. [Scoping Overrun Detection](#7-scoping-overrun-detection)
8. [Page Count Outlier Detection](#8-page-count-outlier-detection)
9. [CE Screening and Intake](#9-ce-screening-and-intake)
10. [Stage Gate Enforcement](#10-stage-gate-enforcement)
11. [Tribal Consultation Hard Gate](#11-tribal-consultation-hard-gate)
12. [Public Comment Triage and EJ Detection](#12-public-comment-triage-and-ej-detection)
13. [Plaintiff Risk Flag (Non-Tribal)](#13-plaintiff-risk-flag-non-tribal)
14. [Defensibility Gap Checker](#14-defensibility-gap-checker)
15. [SLA Due Date and Escalation Monitor](#15-sla-due-date-and-escalation-monitor)
16. [GIS Proximity Check](#16-gis-proximity-check)
17. [CEQ JSON Export API](#17-ceq-json-export-api)
18. [Administrative Record Completeness Checker](#18-administrative-record-completeness-checker)
19. [Error Handling Architecture](#19-error-handling-architecture)
20. [Apex Test Suite](#20-apex-test-suite)
21. [BRE Configuration Integrity](#21-bre-configuration-integrity)
22. [CEQ Standard Compliance — Field Coverage](#22-ceq-standard-compliance--field-coverage)
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

Note the three Program IDs from the output above, then create corresponding `IndividualApplication` records:

```bash
# Replace <EIS_PROGRAM_ID>, <EA_PROGRAM_ID>, <CE_PROGRAM_ID> with actual IDs

sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' nepa_related_project__c='<EIS_PROGRAM_ID>' nepa_review_type__c='EIS' nepa_process_stage__c='Draft EIS Preparation' StatusCode='In Progress'" \
  --target-org $ALIAS

sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' nepa_related_project__c='<EA_PROGRAM_ID>' nepa_review_type__c='EA' nepa_process_stage__c='Comment Period' StatusCode='In Progress'" \
  --target-org $ALIAS

sf data create record \
  --sobject IndividualApplication \
  --values "Category='Permit' nepa_related_project__c='<CE_PROGRAM_ID>' nepa_review_type__c='CE' nepa_process_stage__c='Scoping' StatusCode='In Progress'" \
  --target-org $ALIAS
```

Record all six IDs — they are referenced throughout this guide.

---

## 2. Risk Intelligence — Litigation Risk Scoring

**Tests:** Score computation, BRE Expression Set invocation, write-back to record.

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

### 2b. Verify Score via SOQL

```bash
sf data query \
  --query "SELECT nepa_risk_score__c, nepa_risk_tier__c, nepa_risk_score_updated__c FROM IndividualApplication WHERE nepa_related_project__r.nepa_project_id__c = 'TEST-BLM-EIS-001'" \
  --target-org $ALIAS
```

Expected: one row with `nepa_risk_score__c` ≥ 58 and `nepa_risk_tier__c = Very High`.

---

## 3. Risk Intelligence — Tier Thresholds and Score Composition

**Tests:** All four tier thresholds; expedited penalty; statute point pre-computation.

### 3a. Very High Threshold (≥ 58)

Already verified in Test 2a. Confirm tier = `Very High` for BLM + 10th + ESA + CWA.

### 3b. High Threshold (45–57)

**Setup:** FERC (24pts) + DC Circuit (28pts) = 52pts → High

1. Open the TEST-EA FERC DC Circuit `IndividualApplication`.
2. Set **NEPA Review Type** to `EIS`.
3. Save, wait 10 seconds, refresh.

**Expected:** `nepa_risk_tier__c = High`, score in range 45–57.

### 3c. Moderate Threshold (35–44)

**Setup:** FHWA (18pts) + 8th Circuit (17pts) = 35pts → Moderate/boundary

1. Create a new Program: `nepa_record_owner_agency__c='FHWA'`, `nepa_circuit__c='8th'`.
2. Create a linked `IndividualApplication` with `nepa_review_type__c='EIS'`.
3. Save, wait 10 seconds, refresh.

**Expected:** `nepa_risk_tier__c = Moderate` (score ~35 — at the boundary; tier formula uses `>= 35`).

### 3d. Expedited/Emergency APA Penalty

**Setup:** Set an EIS process's review timeline type to `Expedited/Emergency` with incomplete record.

1. Open any EIS `IndividualApplication`.
2. Set `nepa_review_timeline_type__c` = `Expedited/Emergency`.
3. Set `nepa_record_completeness__c` = `70` (< 100).
4. Save, wait 10 seconds, refresh.

**Expected:**
- `nepa_expedited_risk_penalty_applied__c` = `true`
- `nepa_risk_score_factors__c` contains `APA PENALTY: 1.5x multiplier applied`
- Score is higher than the non-expedited equivalent

### 3e. Statute Point Accumulation

**Setup:** Verify that `nepa_adjacent_statutes__c` on the Program drives statute points.

```bash
# Check that the ESA record in NEPA_Statute_Risk_Weight__mdt has Risk_Points__c = 10
sf data query \
  --query "SELECT Label, Statute_Key__c, Risk_Points__c FROM NEPA_Statute_Risk_Weight__mdt ORDER BY Statute_Key__c" \
  --target-org $ALIAS
```

**Expected rows:**

| Statute_Key__c | Risk_Points__c |
|---|---|
| CWA | 4 |
| ESA | 10 |
| NFMA | 5 |
| NGA | 1 |
| NHPA | 2 |

If points differ, the CMT records were not updated from Phase 1 defaults. Update them in Setup → Custom Metadata Types → NEPA Statute Risk Weight.

---

## 4. Risk Intelligence — Challenge Prediction Rules

**Tests:** Accumulable delta system; Energy × 4th Circuit rule; output written to IA.

### 4a. Energy Sector × 4th Circuit Rule (+12 pts)

1. Create a Program with `nepa_primary_sector__c='Energy Production and Management'` and `nepa_circuit__c='4th'`.
2. Create a linked `IndividualApplication` with `nepa_review_type__c='EIS'`.
3. Save, wait 10 seconds, refresh.

**Expected:**
- `nepa_challenge_risk_delta__c` ≥ 12
- `nepa_challenge_prediction_basis__c` contains `Energy` and `4th`

### 4b. Verify Challenge Prediction Rules in CMT

```bash
sf data query \
  --query "SELECT Label, Risk_Delta__c, Trigger_Sector__c, Trigger_Plaintiff_Flag__c FROM NEPA_Challenge_Prediction_Rule__mdt WHERE Active__c = true ORDER BY Risk_Delta__c DESC" \
  --target-org $ALIAS
```

**Expected:** 7 active rules; the Tribal Plaintiff Override rule shows `Risk_Delta__c = 20` and `Trigger_Plaintiff_Flag__c = true`; the Energy 4th Circuit rule shows `Risk_Delta__c = 12`.

### 4c. Accumulated Delta Feeds Risk Score

Verify that a process with `nepa_challenge_risk_delta__c = 12` shows a higher risk score than an identical process with delta = 0.

1. Compare the TEST-EIS BLM 10th Circuit process (delta from prior tests) against a fresh process with the same agency/circuit but no sector match.
2. The delta-carrying process should score ≥ 12 points higher.

---

## 5. Tribal Plaintiff Intelligence

**Tests:** Tribal dual-flag; risk delta; Tribal Liaison task creation; tribal consultation stage gate.

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
- No direct flag on the comment record — flags are written to the parent IA

**Pass criteria:** Both flags true; task created; delta updated.

### 5b. Verify Navajo Nation Is a Known Profile

```bash
sf data query \
  --query "SELECT Label, Risk_Tier__c, Success_Rate__c, Is_Tribal_Nation__c, Prior_Case_Count__c FROM NEPA_Plaintiff_Profile__mdt WHERE Is_Tribal_Nation__c = true" \
  --target-org $ALIAS
```

**Expected:** At least one record with `Is_Tribal_Nation__c = true` (Navajo Nation). Success_Rate__c = 0.75, Risk_Tier__c = VERY_HIGH.

### 5c. Non-Tribal Plaintiff — Flag Isolation

Repeat 5a but use commenter organization `WildEarth Guardians` instead of `Navajo Nation`.

**Expected:**
- `nepa_plaintiff_risk_flag__c` = `true`
- `nepa_tribal_plaintiff_flag__c` = `false` (WildEarth Guardians is not a tribal profile)
- Tribal Liaison task is **not** created

---

## 6. Agency Performance Tier

**Tests:** `NEPA_Agency_Tier_Setter` flow; per-agency scoping baselines; tier written to Program.

### 6a. Slow Scoping Bottleneck — FAA

1. Open any `Program` record.
2. Set `nepa_record_owner_agency__c` = `FAA`.
3. Save.
4. Wait 10–15 seconds (flow runs `AsyncAfterCommit`), refresh.

**Expected:**
- `nepa_agency_performance_tier__c` = `Slow_Scoping_Bottleneck`

### 6b. Fast and Defensible — FERC

1. On the same Program, change `nepa_record_owner_agency__c` to `FERC`.
2. Save, wait, refresh.

**Expected:**
- `nepa_agency_performance_tier__c` = `Fast_and_Defensible`

### 6c. Legally Vulnerable — BLM

1. Change `nepa_record_owner_agency__c` to `BLM`.
2. Save, wait, refresh.

**Expected:**
- `nepa_agency_performance_tier__c` = `Legally_Vulnerable`

### 6d. Verify All Agency Baselines in CMT

```bash
sf data query \
  --query "SELECT Label, Agency_Key__c, Median_NOI_to_DEIS_Months__c, Agency_Performance_Tier__c FROM NEPA_Agency_Scoping_Baseline__mdt ORDER BY Median_NOI_to_DEIS_Months__c DESC" \
  --target-org $ALIAS
```

**Expected:** 11 records. Longest scoping: FAA (47 months), USACE (42 months). Fastest: TVA (9 months), FERC (10 months).

---

## 7. Scoping Overrun Detection

**Tests:** Overrun flag; overrun magnitude; write-back to IA; feed into risk score.

### 7a. Simulate a Scoping Overrun

The `NEPA_Timeline_Risk_Assessor` fires when `nepa_process_stage__c` or `nepa_days_in_current_stage__c` changes on an EIS-type IA linked to a Program with a known agency.

1. Open an EIS `IndividualApplication` linked to the BLM Program (scoping cap: 28 months → ~840 days).
2. Set `nepa_process_stage__c` = `Scoping`.
3. Set `nepa_days_in_current_stage__c` = `900` (30 months — exceeds BLM's 28-month cap).
4. Save, wait 10 seconds, refresh.

**Expected:**
- `nepa_scoping_overrun_flag__c` = `true`
- `nepa_projected_scoping_overrun_months__c` ≈ `2` (900 days / 30 days − 28 months cap)
- `nepa_agency_scoping_baseline_months__c` = `41` (BLM's NOI-to-FEIS total: 28 + 13)

### 7b. No Overrun — FERC Project

1. Open an EIS `IndividualApplication` linked to the FERC Program.
2. Set `nepa_process_stage__c` = `Scoping`.
3. Set `nepa_days_in_current_stage__c` = `200` (under 10-month FERC NOI→DEIS cap = ~300 days).
4. Save, wait, refresh.

**Expected:** `nepa_scoping_overrun_flag__c` = `false`.

---

## 8. Page Count Outlier Detection

**Tests:** CE > 17 pages (p95 threshold); EA > 200 pages; risk flag written to IA.

### 8a. CE Page Count Outlier

1. Open the CE `IndividualApplication`.
2. Upload any document (create a `ContentVersion`) with `nepa_document_type__c = 'CE Determination'` and `nepa_page_count__c = 20`.
3. Save the ContentVersion linked to the CE process.
4. Wait 10 seconds, refresh the `IndividualApplication`.

**Expected:**
- `nepa_classification_basis__c` contains `CE page count outlier` or `>17 pages`
- `nepa_timeline_risk_tier__c` = `At Risk`

### 8b. EA Page Count Outlier

1. Upload a document to the EA `IndividualApplication` with `nepa_document_type__c = 'EA'` and `nepa_page_count__c = 250`.
2. Wait 10 seconds, refresh.

**Expected:** Risk tier elevated; `nepa_classification_basis__c` notes outlier.

### 8c. Normal Page Count — No Flag

1. Upload a CE document with `nepa_page_count__c = 10` (under threshold).

**Expected:** No page count flag set; prior risk tier unchanged.

---

## 9. CE Screening and Intake

**Tests:** CE Screener BRE fires on action type change; recommendation written; review type NOT auto-changed (AI AUP guardrail).

### 9a. CE Recommendation — Auto-Advance Eligible

1. Open the CE `IndividualApplication`.
2. Ensure the parent Program has `nepa_primary_sector__c` set (e.g., `Agriculture and Natural`).
3. Set `nepa_action_type__c` = `Routine Maintenance` (or any value that maps to a CE in the NAICS routing DM).
4. Set `nepa_disturbance_acres__c` = `0.5`.
5. Save.
6. Wait 10–15 seconds, refresh.

**Expected:**
- `nepa_ce_pathway_recommendation__c` = `CE-Recommended` (or similar value)
- `nepa_classification_basis__c` is populated with rule match detail
- **`nepa_review_type__c` is NOT changed by the screener** — it remains what a human set it to

> The AI AUP guardrail is specifically that the screener writes a *recommendation* field, not the official Review Type field. A human coordinator must confirm the CE determination.

### 9b. CE Screener — Extraordinary Circumstances Override

If the parent Program has `nepa_extraordinary_circumstances_flag__c = true` (set by GIS proximity check), the screener should recommend EA or higher — not CE.

1. Manually set `nepa_extraordinary_circumstances_flag__c = true` on the parent Program.
2. Trigger a screener re-run by changing `nepa_action_type__c`.
3. Save, wait, refresh.

**Expected:** `nepa_ce_pathway_recommendation__c` changes to `EA-Required` or `EIS-Required`.

### 9c. Verify CE Screener BRE DM Row Counts

```bash
# Check NAICS routing DM rows
sf data query \
  --query "SELECT Label, Sector_Key__c, CE_Code__c FROM NEPA_CE_Screening_Rule__mdt ORDER BY Priority__c LIMIT 10" \
  --target-org $ALIAS
```

Expected: rows present for BLM, DOE, USACE, USFS agencies. If no rows, load CE Library data per QUICKSTART Step 4e.

---

## 10. Stage Gate Enforcement

**Tests:** Before-save gate blocks advancement without required documents; gate error message names the missing condition.

### 10a. Gate Blocks Missing Document

1. Open the EIS `IndividualApplication`.
2. Ensure the current stage is `Draft EIS Preparation`.
3. Attempt to change `nepa_process_stage__c` to `Final EIS` (skipping required steps).
4. Click **Save**.

**Expected:** Save is blocked. A field-level or page-level error message appears naming the unmet condition (e.g., `Draft EIS document required before advancing to Final EIS`).

### 10b. Gate Allows Advance After Requirements Met

1. Upload a document to the EIS process with `nepa_document_type__c = 'DEIS'` and `nepa_document_status__c = 'Approved'`.
2. Retry the stage advance from 10a.

**Expected:** Save succeeds (or gate advances to the next unmet condition).

### 10c. Required Document Registry

```bash
sf data query \
  --query "SELECT Label, Review_Type__c, Stage__c, Required_Document_Type__c FROM NEPA_Required_Document__mdt ORDER BY Review_Type__c, Stage__c" \
  --target-org $ALIAS
```

Verify the registry contains records for CE, EA, and EIS pathways.

---

## 11. Tribal Consultation Hard Gate

**Tests:** Stage gate blocks EA/EIS publication until tribal consultation is certified.

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

**Tests:** EJ keyword detection; low-confidence flag; human review task creation; AI classification vs. human-editable field.

### 12a. Environmental Justice Comment — EJ Flag

1. Create a `PublicComplaint` linked to the EIS process with body text:
   > `The proposed project will disproportionately impact low-income communities of color already facing environmental burdens. A cumulative impact analysis including all existing pollution sources in the 3-mile radius is required under Executive Order 12898.`
2. Save.
3. Wait 10 seconds, refresh.

**Expected:**
- `nepa_requires_human_review__c` = `true`
- `nepa_detected_triggers__c` contains `Environmental Justice` or `Cumulative Impact`
- A Task is created for human review

### 12b. EJ Detector — Tribal Sovereignty Keywords

Run via Anonymous Apex for a direct test:

```bash
sf apex run --target-org $ALIAS <<'EOF'
NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
req.commentBody = 'Treaty rights under the 1868 Fort Bridger Treaty must be honored. Sacred site protection required.';
req.commentId = 'manual-test-tribal';
List<NepaCommentEJDetector.Result> results =
    NepaCommentEJDetector.detect(new List<NepaCommentEJDetector.Request>{ req });
System.debug('Requires Review: ' + results[0].requiresHumanReview);
System.debug('Triggers: ' + results[0].detectedTriggers);
EOF
```

**Expected:** `Requires Review: true`; triggers include `Tribal Sovereignty` and/or `Sacred Sites`.

### 12c. Supportive Comment — No EJ Flag

Create a `PublicComplaint` with body: `I fully support this project. The economic benefits for the region are clear.`

**Expected:** `nepa_requires_human_review__c` = `false`; no EJ task created.

### 12d. AI Classification vs. Human-Editable Field

Verify OMB M-24-10 guardrail:

1. After triage runs on any comment, check that:
   - `nepa_ai_classification__c` (read-only staging field) is populated
   - `nepa_comment_classification__c` (editable field) defaults to the AI suggestion but can be manually changed
2. Change `nepa_comment_classification__c` to a different value.
3. Verify field history tracking records the override with your user identity and timestamp.

---

## 13. Plaintiff Risk Flag (Non-Tribal)

**Tests:** WildEarth Guardians profile; Earthjustice; ONRC; litigation history reference written.

### 13a. Known Plaintiff Organization Match

1. Create a `PublicComplaint` with `nepa_organization__c` = `Earthjustice`.
2. Save, wait 10 seconds, refresh the parent `IndividualApplication`.

**Expected:**
- `nepa_plaintiff_risk_flag__c` = `true`
- `nepa_tribal_plaintiff_flag__c` = `false`
- Legal review Task created

### 13b. Unknown Organization — No Flag

1. Create a `PublicComplaint` with `nepa_organization__c` = `Local Hiking Club`.
2. Save, wait, refresh.

**Expected:** Both flags remain `false`. No legal review task.

### 13c. Verify Plaintiff Profiles in CMT

```bash
sf data query \
  --query "SELECT Label, Risk_Tier__c, Success_Rate__c, Prior_Case_Count__c, Is_Tribal_Nation__c FROM NEPA_Plaintiff_Profile__mdt ORDER BY Success_Rate__c DESC" \
  --target-org $ALIAS
```

**Expected:** 6 records. Navajo Nation and WildEarth Guardians at 75% success rate; Earthjustice at 40%; ONRC at 38%.

---

## 14. Defensibility Gap Checker

**Tests:** Score computation; gap detection; score updates when documents added.

### 14a. Baseline Score — Sparse Record

1. Open the EIS `IndividualApplication` with minimal documents attached.
2. Check `nepa_defensibility_score__c` and `nepa_defensibility_gaps__c`.

**Expected:** Score < 50 if required documents are missing; `nepa_defensibility_gaps__c` lists specific gap categories (e.g., `No Scoping Summary`, `No Public Comment Response`).

### 14b. Score Increases on Document Upload

1. Upload a document to the EIS process with `nepa_document_type__c = 'Scoping Summary'` and `nepa_document_status__c = 'Approved'`.
2. Wait 10 seconds (the `NEPA_Defensibility_Trigger_ContentVersion` flow fires after-save), refresh.

**Expected:**
- `nepa_defensibility_score__c` increased
- `nepa_defensibility_updated__c` timestamp is current

### 14c. Score Increases on Engagement Event Added

1. Create a `nepa_engagement__c` record linked to the EIS process.
2. Wait 10 seconds, refresh.

**Expected:** Score increases further as engagement coverage gaps are resolved.

---

## 15. SLA Due Date and Escalation Monitor

**Tests:** Due date set on timeline event creation; escalation task generated when overdue.

### 15a. SLA Due Date Setter

1. Create an `ApplicationTimeline` record linked to the EIS process with:
   - `Type` = `Comment Period`
   - `Status` = `Planned`
   - `StartDate` = today
2. Save.

**Expected:** `nepa_sla_due_date__c` is automatically populated (based on `NEPA_SLA_Config__mdt` rules for the event type). If blank, verify `NEPA_SLA_Due_Date_Setter` flow is active.

### 15b. Escalation Monitor — Manual Trigger

To test without waiting for the daily schedule:

```bash
sf apex run --target-org $ALIAS <<'EOF'
Flow.Interview f = Flow.Interview.createInterview(
    'NEPA_SLA_Escalation_Monitor', new Map<String, Object>());
f.start();
System.debug('Escalation monitor executed');
EOF
```

Then check the EIS process for new Tasks with subjects referencing SLA escalation, and check the `nepa_sla_warning_sent__c` flag on overdue `ApplicationTimeline` records.

---

## 16. GIS Proximity Check

**Tests:** Coordinates on Program trigger IP invocation; detected layers written back; EC flag set.

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

### 16b. Verify GIS Layer Registry

```bash
sf data query \
  --query "SELECT Label, nepa_layer_url__c, nepa_proximity_buffer_m__c, nepa_triggers_ec__c FROM NEPA_GIS_Layer__mdt WHERE nepa_active__c = true ORDER BY Label" \
  --target-org $ALIAS
```

**Expected:** 7 active layers including BLM Surface Management, USFWS Critical Habitat, NWI Wetlands, EPA EJSCREEN.

---

## 17. CEQ JSON Export API

**Tests:** REST endpoint returns valid 9-entity payload; all CEQ standard fields present; schema version correct.

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

### 17b. Verify All Five Provenance Fields on Export

Check that the project node contains:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$INSTANCE/services/apexrest/nepa/v1/processes/TEST-BLM-EIS-001" | \
  jq '.data.project | {data_record_version, data_source_agency, data_source_system, record_owner_agency, retrieved_timestamp}'
```

**Expected:** All five provenance keys present with non-null values.

### 17c. Verify CEQ Export via Apex

```bash
sf apex run --target-org $ALIAS <<'EOF'
String projectId = [SELECT Id FROM Program WHERE nepa_project_id__c = 'TEST-BLM-EIS-001' LIMIT 1].Id;
NepaCeqExportService svc = new NepaCeqExportService();
Map<String, Object> payload = svc.exportProject(projectId);
System.debug('CEQ version: ' + payload.get('ceq_standard_version'));
System.debug('Process count: ' + ((List<Object>) payload.get('processes')).size());
EOF
```

**Expected:** `CEQ version: 1.2`; process count ≥ 1.

---

## 18. Administrative Record Completeness Checker

**Tests:** Completeness score computed; gaps identified; completeness updates on document addition.

### 18a. Run AR Checker

```bash
sf apex run --target-org $ALIAS <<'EOF'
Id processId = [SELECT Id FROM IndividualApplication WHERE nepa_related_project__r.nepa_project_id__c = 'TEST-BLM-EIS-001' LIMIT 1].Id;
// Invoke via Flow
Map<String, Object> inputs = new Map<String, Object>{ 'inp_ProcessId' => processId };
Flow.Interview f = Flow.Interview.createInterview('NEPA_Administrative_Record_Checker', inputs);
f.start();
System.debug('AR check complete for: ' + processId);
EOF
```

Then query the updated IA:

```bash
sf data query \
  --query "SELECT nepa_record_completeness__c, nepa_defensibility_score__c FROM IndividualApplication WHERE nepa_related_project__r.nepa_project_id__c = 'TEST-BLM-EIS-001'" \
  --target-org $ALIAS
```

**Expected:** `nepa_record_completeness__c` is a number 0–100 reflecting document coverage.

---

## 19. Error Handling Architecture

**Tests:** Platform event error log survives failed transaction; `NEPA_Flow_Error__c` record created; error count incremented on IA.

### 19a. Trigger a Controlled Fault

```bash
sf apex run --target-org $ALIAS <<'EOF'
// Invoke the error logger directly with a simulated fault
Map<String, Object> inputs = new Map<String, Object>{
    'inp_FlowName'    => 'ManualTest',
    'inp_ErrorMessage'=> 'Test fault — verifying error architecture',
    'inp_FailedStep'  => 'Test_Step',
    'inp_RecordId'    => [SELECT Id FROM IndividualApplication LIMIT 1].Id,
    'inp_RunningUserId' => UserInfo.getUserId(),
    'inp_ErrorContext' => 'Manual:true|Test:true'
};
Flow.Interview f = Flow.Interview.createInterview('NEPA_Error_Logger', inputs);
f.start();
System.debug('Error logger invoked');
EOF
```

### 19b. Verify Error Record Created

Wait 15–30 seconds (platform event delivery is async), then:

```bash
sf data query \
  --query "SELECT nepa_flow_name__c, nepa_error_message__c, nepa_failed_step__c, CreatedDate FROM NEPA_Flow_Error__c ORDER BY CreatedDate DESC LIMIT 5" \
  --target-org $ALIAS
```

**Expected:** A `NEPA_Flow_Error__c` record exists for `ManualTest` with `nepa_error_message__c = 'Test fault — verifying error architecture'`.

---

## 20. Apex Test Suite

**Tests:** All 125 tests pass; code coverage ≥ 75%.

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
- **125 tests pass**, 0 failures
- Overall Apex coverage ≥ 75%
- All four key test classes pass:
  - `NepaApiComplianceTest`
  - `NepaCeqExportServiceTest`
  - `NepaEntity789Test`
  - `NepaBREConfigTest`

### 20b. Targeted Test — BRE Configuration

```bash
sf apex run test \
  --class-names NepaBREConfigTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All BRE config tests pass, including verification that all 15 CMT types have at least one active record.

### 20c. Targeted Test — CEQ API Compliance

```bash
sf apex run test \
  --class-names NepaApiComplianceTest \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** All compliance tests pass, verifying CEQ v1.2 field coverage across all 9 entities.

### 20d. Targeted Test — Entity 7/8/9 Coverage

```bash
sf apex run test \
  --class-names NepaEntity789Test \
  --target-org $ALIAS \
  --result-format human \
  --wait 10
```

**Expected:** GIS data (`nepa_gis_data__c`), user roles (`nepa_process_team_member__c`), and legal structure (`RegulatoryCode`) all pass field coverage assertions.

---

## 21. BRE Configuration Integrity

**Tests:** All Decision Matrix row counts correct; all Expression Sets are Active; CMT types have records.

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

### 21c. CMT Record Counts via SOQL

```bash
sf data query \
  --query "SELECT COUNT() FROM NEPA_Agency_Risk_Rate__mdt WHERE Active__c = true" \
  --target-org $ALIAS
# Expected: 7

sf data query \
  --query "SELECT COUNT() FROM NEPA_Circuit_Risk_Weight__mdt WHERE Active__c = true" \
  --target-org $ALIAS
# Expected: 14 (13 circuits + Default)

sf data query \
  --query "SELECT COUNT() FROM NEPA_Agency_Scoping_Baseline__mdt WHERE Active__c = true" \
  --target-org $ALIAS
# Expected: 11

sf data query \
  --query "SELECT COUNT() FROM NEPA_Challenge_Prediction_Rule__mdt WHERE Active__c = true" \
  --target-org $ALIAS
# Expected: 7

sf data query \
  --query "SELECT COUNT() FROM NEPA_Plaintiff_Profile__mdt WHERE Active__c = true" \
  --target-org $ALIAS
# Expected: 6
```

---

## 22. CEQ Standard Compliance — Field Coverage

**Tests:** All 13 CEQ entities have required fields; provenance fields present on all objects.

### 22a. Five Provenance Fields on All 9 Entity Objects

```bash
# Check Program (Entity 1)
sf data query \
  --query "SELECT nepa_data_record_version__c, nepa_data_source_agency__c, nepa_data_source_system__c, nepa_record_owner_agency__c, nepa_retrieved_timestamp__c FROM Program LIMIT 1" \
  --target-org $ALIAS

# Check IndividualApplication (Entity 2)
sf data query \
  --query "SELECT nepa_data_record_version__c, nepa_data_source_agency__c, nepa_data_source_system__c, nepa_record_owner_agency__c, nepa_retrieved_timestamp__c FROM IndividualApplication LIMIT 1" \
  --target-org $ALIAS
```

Repeat for `ContentVersion`, `PublicComplaint`, `nepa_engagement__c`, `ApplicationTimeline`, `nepa_gis_data__c`, `nepa_process_team_member__c`. All should return without `INVALID_FIELD` errors — if they do, a field is missing from the object definition.

### 22b. Entity 7 GIS Data — CEQ Field Coverage

```bash
sf sobject describe --sobject nepa_gis_data__c --target-org $ALIAS --json | \
  jq '.result.fields[] | select(.name | startswith("nepa_")) | .name'
```

Expected fields include: `nepa_format__c`, `nepa_access_method__c`, `nepa_coordinate_system__c`, `nepa_bounding_box__c`, `nepa_purpose__c`, `nepa_access_information__c`.

### 22c. Object Availability Check

Verify all 9 CEQ entity objects exist in the org:

```bash
for obj in Program IndividualApplication ContentVersion PublicComplaint nepa_engagement__c ApplicationTimeline nepa_gis_data__c nepa_process_team_member__c RegulatoryCode; do
  sf data query --query "SELECT COUNT() FROM $obj" --target-org $ALIAS 2>/dev/null && echo "OK: $obj" || echo "MISSING: $obj"
done
```

**Expected:** All 9 return "OK".

---

## 23. Test Results Summary Matrix

Use this matrix to track test execution. Mark each test ✅ Pass, ❌ Fail, or ⚠️ Blocked.

| # | Feature | Test | Status | Notes |
|---|---|---|---|---|
| 2a | Risk Scoring | High-risk EIS score ≥ 58, tier = Very High | | |
| 2b | Risk Scoring | SOQL confirms score on record | | |
| 3a | Tier Thresholds | Very High (≥ 58) | | |
| 3b | Tier Thresholds | High (45–57) — FERC + DC | | |
| 3c | Tier Thresholds | Moderate (35–44) — FHWA + 8th | | |
| 3d | APA Penalty | Expedited + incomplete → 1.5x multiplier | | |
| 3e | Statute Points | CMT has 5 statutes with correct points | | |
| 4a | Challenge Rules | Energy × 4th → +12 delta | | |
| 4b | Challenge Rules | 7 active rules in CMT | | |
| 4c | Challenge Rules | Delta feeds risk score | | |
| 5a | Tribal Intel | Navajo Nation comment → dual flags + task | | |
| 5b | Tribal Intel | CMT has tribal profile records | | |
| 5c | Tribal Intel | WildEarth → general flag only | | |
| 6a | Agency Tier | FAA → Slow_Scoping_Bottleneck | | |
| 6b | Agency Tier | FERC → Fast_and_Defensible | | |
| 6c | Agency Tier | BLM → Legally_Vulnerable | | |
| 6d | Agency Tier | 11 baseline records in CMT | | |
| 7a | Scoping Overrun | BLM, 30mo > 28mo cap → flag + magnitude | | |
| 7b | Scoping Overrun | FERC, 200d < cap → no flag | | |
| 8a | Page Count | CE 20pp > 17pp → At Risk | | |
| 8b | Page Count | EA 250pp > 200pp → At Risk | | |
| 8c | Page Count | CE 10pp → no flag | | |
| 9a | CE Screening | Recommendation written; Review Type unchanged | | |
| 9b | CE Screening | EC flag overrides to EA | | |
| 10a | Stage Gate | Advance blocked without document | | |
| 10b | Stage Gate | Advance allowed after document approved | | |
| 11a | Tribal Gate | Stage blocked without certified consultation | | |
| 11b | Tribal Gate | Stage passes after certification | | |
| 12a | EJ Detection | EJ comment → requires_human_review = true | | |
| 12b | EJ Detection | Tribal sovereignty keywords trigger flag | | |
| 12c | EJ Detection | Supportive comment → no flag | | |
| 12d | AI AUP | AI classification read-only; human field editable | | |
| 13a | Plaintiff Flag | Earthjustice → plaintiff flag, no tribal flag | | |
| 13b | Plaintiff Flag | Unknown org → no flags | | |
| 14a | Defensibility | Sparse record scores < 50; gaps listed | | |
| 14b | Defensibility | Score increases on document upload | | |
| 14c | Defensibility | Score increases on engagement event | | |
| 15a | SLA | Due date auto-set on timeline event creation | | |
| 15b | SLA | Escalation monitor creates overdue tasks | | |
| 16a | GIS Proximity | Coordinates trigger IP; layers written back | | |
| 16b | GIS Proximity | 7 active layers in CMT | | |
| 17a | CEQ Export | REST API returns 9-entity payload | | |
| 17b | CEQ Export | All 5 provenance fields in payload | | |
| 17c | CEQ Export | Apex export service returns version 1.2 | | |
| 18a | AR Completeness | Completeness score computed on demand | | |
| 19a | Error Handling | Error Logger invocation succeeds | | |
| 19b | Error Handling | NEPA_Flow_Error__c record created via platform event | | |
| 20a | Test Suite | 125 tests pass, ≥ 75% coverage | | |
| 20b | Test Suite | NepaBREConfigTest passes | | |
| 20c | Test Suite | NepaApiComplianceTest passes | | |
| 20d | Test Suite | NepaEntity789Test passes | | |
| 21a | BRE Config | All DM row counts match expected | | |
| 21b | BRE Config | 3 Expression Sets Active | | |
| 21c | BRE Config | CMT record counts correct | | |
| 22a | CEQ Compliance | 5 provenance fields on all 9 entity objects | | |
| 22b | CEQ Compliance | Entity 7 GIS fields present | | |
| 22c | CEQ Compliance | All 9 entity objects accessible | | |

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
| Apex tests < 75% coverage | Flow-invoked Apex classes need flows active during test run | Activate all 31 flows, then rerun tests |
| Error record not created | Platform event delivery delay | Wait 30 seconds; if still missing, verify `NEPA_Error_Event_Handler` is active |
| `INVALID_FIELD` on SOQL | Permission set not assigned | Run `sf org assign permset --name NEPA_Permitting --target-org $ALIAS` |
