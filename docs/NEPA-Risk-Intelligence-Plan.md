# NEPA Risk Intelligence Plan

**Version:** 0.1 (Draft)
**Date:** 2026-04-29
**Status:** Proposed

## Overview

This plan describes six intelligence features that extend the PSA-NEPA-Permitting-Data-Model beyond compliance into proactive risk assessment, timeline acceleration, and litigation prediction. The features are grounded in the PermitTEC v0.1 dataset (PNNL, 2025): 761 federal NEPA litigation cases, 223 linked to NEPATEC v2.0 project records, spanning 1970–2025 with classification by review type, agency, circuit, challenge ground, disposition, and adjacent statute involvement.

---

## Feature 1: Litigation Risk Scoring

**Goal:** Surface a composite litigation risk score on each `Program` (Project) and `IndividualApplication` (Process) so agencies and applicants can assess exposure before — not after — a decision is challenged.

### Signal Inputs (from PermitTEC analysis)

| Signal | Weight rationale |
|---|---|
| Review type (EIS) | 98.2% of PermitTEC-linked litigation involves EIS processes; EA/CE = lower baseline risk |
| Lead agency | Forest Service (37 cases), BLM (35), FERC (15) carry higher rates; agency-specific priors available |
| Circuit geography | 9th Circuit (369 cases, 48.5%), D.C. Circuit (175, 23%); same agency + circuit = multiplicative risk |
| Project sector | Energy Production and Transmission, Infrastructure, Mining have elevated rates |
| Adjacent statute exposure | ESA/CWA/NHPA co-involvement correlates with compound claims and vacatur outcomes |
| Challenge ground history | Agency's prior inadequacy findings increase recurrence probability |
| Missing supplemental process | Failure-to-supplement ground is detectable from document record before filing |

### Implementation

**New fields on `IndividualApplication`:**
- `nepa_risk_score__c` (Number 0–100) — composite score, updated by Flow or Apex trigger
- `nepa_risk_tier__c` (Picklist: Low / Moderate / High / Very High) — human-readable tier
- `nepa_risk_score_factors__c` (LongTextArea) — JSON or semicolon-delimited explanation of contributing factors
- `nepa_risk_score_updated__c` (DateTime) — staleness indicator

**New fields on `Program`:**
- `nepa_circuit__c` (Text 50) — federal circuit for the project geography (drives geographic risk weight)
- `nepa_adjacent_statutes__c` (LongTextArea) — ESA/CWA/NHPA/APA flags as semicolon list

**Scoring logic (Apex class `NEPA_LitigationRiskScorer`):**
1. Pull agency litigation rate from a custom metadata type `NEPA_Agency_Risk_Rate__mdt` (populated from PermitTEC aggregate stats).
2. Pull circuit risk weight from `NEPA_Circuit_Risk_Weight__mdt`.
3. Add sector weight from `NEPA_Sector_Risk_Weight__mdt`.
4. Bonus points for each adjacent statute flagged.
5. Penalty deduction if review type is CE (low base risk).
6. Normalize to 0–100; assign tier thresholds (0–24=Low, 25–49=Moderate, 50–74=High, 75–100=Very High).

**Trigger point:** Score recalculates on create/update of `IndividualApplication` when review type, lead agency, or related project changes.

---

## Feature 2: Challenge Type Prediction

**Goal:** Given a project's attributes, predict which of the five NEPA challenge grounds is most likely, so the agency can pre-emptively strengthen that aspect of the record.

### The Five Challenge Grounds (from PermitTEC classification)

1. **Failure to prepare** — agency skipped required EIS or EA; triggered by CE reliance on large-footprint projects
2. **EIS/EA inadequacy** — document prepared but found substantively deficient; correlates with complex multi-agency or contested projects
3. **Improper CE reliance** — extraordinary circumstances not evaluated; correlates with sector (mining, energy) + small-project classification
4. **Failure to supplement** — new information emerged post-ROD not addressed; correlates with long decision timelines
5. **Adjacent statute violation** — ESA Section 7, CWA Section 404, NHPA Section 106, APA arbitrary-and-capricious; detectable from adjacent statute flags

### Implementation

**New field on `IndividualApplication`:**
- `nepa_predicted_challenge_grounds__c` (LongTextArea) — semicolon list of predicted grounds, ordered by probability
- `nepa_challenge_prediction_notes__c` (LongTextArea) — plain-language explanation for each prediction

**Prediction logic:** A custom metadata-driven rule table (`NEPA_Challenge_Prediction_Rule__mdt`) maps input attributes to ground probabilities. Initial rule weights derived from PermitTEC distribution stats; can be refined with agency-specific history.

**AI enhancement (optional, Phase 2):** Pass project description + process attributes to an Einstein/Agentforce prompt to generate a natural-language "challenge vulnerability brief" for the assigned case team.

---

## Feature 3: Decision Timeline Acceleration

**Goal:** Detect stalled processes early by comparing actual milestone durations against historical agency/review-type baselines, and surface at-risk processes to managers before delays compound.

### Baseline Data Sources

- NEPATEC v2.0 process duration data (start_date + completion_date per process type and agency)
- PermitTEC ruling dates vs. process dates — cases filed within 60 days of ROD/FONSI tend to have stronger injunctive relief outcomes
- CEQ statutory/regulatory timelines (2-year EIS, 1-year EA guidance)

### Implementation

**New fields on `IndividualApplication`:**
- `nepa_estimated_completion_date__c` (Date) — agency/type baseline completion estimate from start date
- `nepa_days_in_current_stage__c` (Number) — formula: TODAY() - last stage transition date
- `nepa_milestone_variance_days__c` (Number) — actual days vs. baseline for current stage
- `nepa_timeline_status__c` (Picklist: On Track / At Risk / Stalled / Overdue) — driven by milestone variance
- `nepa_last_stage_transition__c` (DateTime) — set by Flow when `nepa_process_stage__c` changes

**New custom metadata type:** `NEPA_Stage_Baseline_Duration__mdt`
- Fields: `Review_Type__c`, `Process_Stage__c`, `Agency__c`, `Baseline_Days__c`, `P90_Days__c`
- Seeded with NEPATEC v2.0 aggregate data

**Automation:**
- Scheduled Apex job (nightly) computes `nepa_days_in_current_stage__c` and `nepa_milestone_variance__c` across all active processes
- Flow sends alert to assigned user when `nepa_timeline_status__c` transitions to "Stalled" or "Overdue"

---

## Feature 4: Analogous Case Retrieval

**Goal:** When reviewing a new project or process, surface PermitTEC cases that involved similar agencies, sectors, and circuits — so legal and NEPA staff can study how analogous decisions were defended or overturned.

### Matching Approach

PermitTEC's three-method matching framework (LLM query generation, fuzzy composite key, RAG+semantic search) informs a simplified Salesforce-native version:

| Method | Salesforce implementation |
|---|---|
| Agency match | Lookup filter on `nepa_litigation__c` via `nepa_lead_agency__c` on related Program |
| Circuit match | Text filter using `nepa_circuit__c` (to be added to Program, see Feature 1) |
| Keyword match | SOSL full-text search on `nepa_llm_keywords__c` against project description |
| Sector match | Picklist/text match on `nepa_project_sector__c` |

### Implementation

**New junction object: `nepa_project_analogous_case__c`**
- `nepa_project__c` (Lookup → Program)
- `nepa_litigation_case__c` (Lookup → nepa_litigation__c)
- `nepa_match_method__c` (Picklist: Agency+Circuit / Keyword / Manual)
- `nepa_match_score__c` (Number) — composite similarity score
- `nepa_match_notes__c` (Text) — human or AI-generated rationale

**Invocable Apex action `NEPA_FindAnalogusCases`:** Called from a Screen Flow or Agentforce action; queries `nepa_litigation__c` by agency, circuit, and keyword overlap; returns top-N ranked matches for staff review.

**Phase 2 (AI):** Agentforce agent action that passes project description to an LLM and retrieves semantically similar PermitTEC cases via Einstein Search grounding.

---

## Feature 5: Defensibility Gap Detection

**Goal:** Identify missing documents, low public engagement, or absent key milestones that correlate with court findings of EIS/EA inadequacy — before the record is closed.

### Gap Signals (from PermitTEC inadequacy case analysis)

| Gap | Detection method |
|---|---|
| No ROD/FONSI document | Query `ContentVersion` for `nepa_document_type__c IN ('ROD','FONSI')` linked to process |
| No public engagement events logged | COUNT of `nepa_engagement__c` for the process = 0 |
| Public comment period < 30 days | `nepa_public_comment_period_end_date__c - nepa_public_comment_period_start__c < 30` |
| Comment response document absent | No `ContentVersion` with `nepa_document_type__c = 'Comment Response'` |
| Alternatives analysis document absent | No document with type indicating alternatives analysis |
| No scoping notice for EIS | No `ApplicationTimeline` event with type = Scoping for EIS-class processes |
| Adjacent statute consultation record missing | `nepa_adjacent_statutes__c` populated but no corresponding `ApplicationTimeline` event |

### Implementation

**New fields on `IndividualApplication`:**
- `nepa_defensibility_score__c` (Number 0–100) — percentage of expected record elements present
- `nepa_defensibility_gaps__c` (LongTextArea) — semicolon list of detected gaps
- `nepa_defensibility_updated__c` (DateTime)

**Apex class `NEPA_DefensibilityChecker`:** Runs gap queries for a process and writes results to the above fields. Triggered on document upload (`ContentVersion`), engagement record creation, and timeline event creation.

**Dashboard component:** "Record Completeness" Lightning component on IndividualApplication record page — visual checklist of required elements with green/red status per gap rule.

---

## Feature 6: Litigation Outcome Pattern Analysis (Reporting Layer)

**Goal:** Provide aggregate analytics over the `nepa_litigation__c` corpus to support agency program management — which sectors, agencies, circuits, and challenge grounds produce the worst outcomes, and how has performance changed over time.

### Reports and Dashboards

| Report | Key dimensions |
|---|---|
| Litigation by Agency | Agency × Challenge Ground × Prevailing Party |
| Litigation by Circuit | Circuit × Disposition Type × Review Type |
| Trend over Time | Year × Challenge Ground × Outcome |
| Sector Risk Heatmap | Project Sector × Review Type × Win Rate |
| Extraction Quality | `nepa_extraction_quality__c` distribution (Validated / Corrected / Unreviewed) |

### Implementation

- Standard Salesforce Reports and Dashboards on `nepa_litigation__c` — no custom development required
- A report folder `NEPA Litigation Analytics` with pre-built reports included in the package
- Optional: CRM Analytics (Tableau CRM) dataset for cross-object analysis joining `nepa_litigation__c` → `Program` → `IndividualApplication`

---

## Data Model Additions Summary

### New Fields

| Object | Field | Type | Feature |
|---|---|---|---|
| `IndividualApplication` | `nepa_risk_score__c` | Number | 1 |
| `IndividualApplication` | `nepa_risk_tier__c` | Picklist | 1 |
| `IndividualApplication` | `nepa_risk_score_factors__c` | LongTextArea | 1 |
| `IndividualApplication` | `nepa_risk_score_updated__c` | DateTime | 1 |
| `IndividualApplication` | `nepa_predicted_challenge_grounds__c` | LongTextArea | 2 |
| `IndividualApplication` | `nepa_challenge_prediction_notes__c` | LongTextArea | 2 |
| `IndividualApplication` | `nepa_estimated_completion_date__c` | Date | 3 |
| `IndividualApplication` | `nepa_days_in_current_stage__c` | Number | 3 |
| `IndividualApplication` | `nepa_milestone_variance_days__c` | Number | 3 |
| `IndividualApplication` | `nepa_timeline_status__c` | Picklist | 3 |
| `IndividualApplication` | `nepa_last_stage_transition__c` | DateTime | 3 |
| `IndividualApplication` | `nepa_defensibility_score__c` | Number | 5 |
| `IndividualApplication` | `nepa_defensibility_gaps__c` | LongTextArea | 5 |
| `IndividualApplication` | `nepa_defensibility_updated__c` | DateTime | 5 |
| `Program` | `nepa_circuit__c` | Text 50 | 1, 4 |
| `Program` | `nepa_adjacent_statutes__c` | LongTextArea | 1, 2, 5 |

### New Objects

| Object | Purpose | Feature |
|---|---|---|
| `nepa_project_analogous_case__c` | Junction: Project ↔ PermitTEC case | 4 |

### New Custom Metadata Types

| Type | Purpose | Feature |
|---|---|---|
| `NEPA_Agency_Risk_Rate__mdt` | Agency-level litigation rate priors | 1 |
| `NEPA_Circuit_Risk_Weight__mdt` | Circuit-level risk weights | 1 |
| `NEPA_Sector_Risk_Weight__mdt` | Sector-level risk weights | 1 |
| `NEPA_Challenge_Prediction_Rule__mdt` | Attribute → ground probability rules | 2 |
| `NEPA_Stage_Baseline_Duration__mdt` | Historical milestone durations by agency/type | 3 |

---

## Phasing

### Phase 1 — Data Foundation (no AI required)
- Feature 1: Risk scoring (rules-based, custom metadata-driven)
- Feature 3: Timeline tracking and stall detection
- Feature 5: Defensibility gap detection
- Feature 6: Litigation analytics reports

**Deliverables:** 16 new fields, 5 custom metadata types, 2 Apex classes, 1 scheduled job, pre-built report folder

### Phase 2 — Intelligence Layer (Agentforce / Einstein)
- Feature 2: Challenge type prediction with AI-generated explanations
- Feature 4: Analogous case retrieval with semantic search
- Feature 6 extension: CRM Analytics dataset

**Deliverables:** 1 new object, Agentforce agent actions, Einstein Search grounding config

### Phase 3 — Continuous Learning
- Feedback loop: when `nepa_extraction_quality__c` is set to Validated/Corrected on a litigation record, refresh risk weights
- Periodic refresh of custom metadata from updated PermitTEC corpus releases

---

## Source Data Reference

- **PermitTEC v0.1** (PNNL, 2025): 761 litigation cases, 223 linked to NEPATEC v2.0
- **NEPATEC v2.0**: Federal NEPA process registry with project and process-level data
- **CEQ NEPA and Permitting Data and Technology Standard v1.2** (May 30 / August 18, 2025): Compliance baseline for this data model
- **PSA-NEPA-Permitting-Data-Model**: This package — 6-entity Salesforce PSS implementation of the CEQ standard
