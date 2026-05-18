# PSA-NEPA Permitting Accelerator — Improvement Plan

**Version:** 1.0  
**Date:** 2026-05-17  
**Based on:** Stage 14–16 pipeline findings (CourtListener litigation duration, USFWS ECOS cross-reference, federal-state baseline comparison)  
**Scope:** Solution improvements to the PSA-NEPA-Permitting-Data-Model Salesforce package

---

## Executive Summary

Stages 14–16 of the calibration pipeline produced three findings that change what the accelerator should do — not just what it knows:

1. **Litigation duration is a cost dimension, not a risk dimension.** The v3 composite risk score now includes `Litigation_Duration_Cost__c`, but the UI and alert logic still treat the score as a pure win-probability signal. The display layer must distinguish the cost component from the probability core.

2. **Federal-specific friction is concentrated in multi-agency coordination overhead (1.45× overall; 1.65× Military), not in NEPA analytical depth.** The current accelerator focuses on record defensibility within a single agency. It does not help coordinators manage the multi-agency coordination stack that produces the majority of federal delay. One Federal Decision implementation is the primary gap.

3. **The ESA §7 1.48× multiplier cannot be decomposed because ECOS has no public API.** Until TAILS/PCTS access is established, the ESA risk signal is a flat premium with no actionable sub-component. The accelerator should flag this limitation at point-of-use rather than presenting the multiplier as fully calibrated.

Improvements are grouped into three tiers: **Implement Now** (low effort, high value, directly actionable from existing data), **Implement Next** (medium effort, new CMT or field additions required), and **Requires External Data** (blocked until TAILS/PCTS or CEQAnet access is established).

---

## Tier 1: Implement Now

These improvements require only configuration changes, UI copy updates, or small additions to existing flows — no new objects or external dependencies.

---

### IMP-001: Risk Score Display — Separate Cost from Probability

**Finding:** `Litigation_Duration_Cost__c` is statistically independent of case outcome (agency-won median: 15.1 months, challenger-won: 16.3 months). Displaying a single composite score blurs the distinction between "likely to lose" and "expensive if you lose."

**Current behavior:** The Risk Intelligence tab shows a single 0–100 score with no breakdown between the win-probability core and the duration cost component.

**Proposed change:** Split the `nepa_risk_score_factors__c` display into two sections:
- **Litigation Probability Score** (v2 components at 85% weight: Agency Loss Rate, Circuit Loss Rate, Plaintiff Org Strength, Sector Volatility, Procedural Posture Risk)
- **Litigation Cost Exposure** (duration term at 15% weight: agency median months, normalized, with note that this does not predict outcome)

**Implementation:** Update the Risk Intelligence FlexCard or LWC to read `nepa_risk_score_factors__c` and render the two categories with separate labels. Add a tooltip explaining the distinction. No formula field change required — the split is a UI presentation decision.

**Files to modify:** `nepaRiskIntelligenceCard` LWC or FlexCard; `nepa_risk_score_factors__c` formula field output format.

---

### IMP-002: Agency Duration Lookup in Risk Score Factors

**Finding:** Stage 14 produced a 15-agency median litigation duration table (BOEM: 6.5 months → FTA: 33.4 months) mapped to review pathway types (direct-circuit vs. APA district court). This is directly actionable for project sponsors.

**Current behavior:** The risk score factors string mentions agency loss rate but not expected litigation duration or pathway type.

**Proposed change:** Add agency litigation duration to the `nepa_risk_score_factors__c` disclosure string:
```
Agency: BLM (loss rate 39.3%) | Expected litigation duration if filed: ~17.5 months (APA district court, summary judgment track)
```

**Implementation:** Add `NEPA_Agency_Duration_Cost__mdt` CMT with `Median_Duration_Months__c`, `Normalized_Duration_Cost__c`, and `Pathway_Note__c` fields. Populate from the `litigation_duration_by_agency` table in `docs/decision-models/litigation-risk-weights.json`. Update `NEPA_Litigation_Risk_Scorer` flow to include the duration lookup in the factors string.

**New CMT records required:** 16 (one per agency in the duration table; default fallback = 15.4 months global median).

---

### IMP-003: ESA §7 Risk Flag — Add "Low Confidence" Disclosure

**Finding:** Stage 15 confirmed that the USFWS ECOS API does not exist. The 1.48× ESA §7 multiplier cannot be decomposed into consultation-duration or jeopardy-finding components. It is currently presented without confidence qualification.

**Current behavior:** `NEPA_Statute_Risk_Weight__mdt` ESA record carries `risk_points: 10` with the note "ESA Section 7 consultation failures are the top adjacent-statute challenge ground." No confidence flag exists.

**Proposed change:**
1. Add `Low_Data_Confidence__c` checkbox to `NEPA_Statute_Risk_Weight__mdt` (parallel to the existing field on `NEPA_Circuit_Risk_Weight__mdt`).
2. Set `Low_Data_Confidence__c = true` on the ESA record with note: "ECOS API unavailable; multiplier is flat 1.48× pending TAILS/PCTS linkage. Cannot distinguish consultation duration vs. jeopardy-finding drivers."
3. Update the challenge prediction rule `Adjacent_Statute_ESA` explanation text to note the data limitation.
4. Add a yellow warning badge to the ESA risk factor row in the Risk Intelligence display when `Low_Data_Confidence__c = true`.

**Files to modify:** `NEPA_Statute_Risk_Weight__mdt` metadata; `NEPA_Challenge_Prediction_Rule__mdt` for `Adjacent_Statute_ESA`; `NEPA_Litigation_Risk_Scorer` flow.

---

### IMP-004: Circuit Duration Warnings

**Finding:** The 6th Circuit's 47.9-month median litigation duration is 4× the DC Circuit's 12.2-month median. This is operationally significant for project sponsors in Ohio, Tennessee, Kentucky, and Michigan.

**Current behavior:** Circuit risk weights reflect win-probability only. No duration guidance is surfaced by circuit.

**Proposed change:** Add circuit-level median duration to `NEPA_Circuit_Risk_Weight__mdt` as `Median_Litigation_Months__c`. Surface it in the circuit risk row of the factors display: "6th Circuit (risk: High, expected duration: ~47.9 months — likely due to docket congestion)."

**New field:** `Median_Litigation_Months__c` (Number) on `NEPA_Circuit_Risk_Weight__mdt`. Populate from Stage 14 circuit duration table.

---

### IMP-005: Federal Friction Context for Sector-Based Risk Cells

**Finding:** Stage 16 established that federal friction (1.45× over California EIR) is concentrated in multi-agency coordination (Military 1.65×, Water/Coastal 1.47×, Transportation 1.45×) rather than analytical depth. Wildlife sector shows only 1.17× because CESA mirrors ESA.

**Current behavior:** The sector × circuit risk matrix (Stage 13) reflects litigation outcomes but does not explain the process-level cause of sector-specific delay.

**Proposed change:** Add `federal_friction_multiplier` and `friction_drivers` to the sector entries in the sector-circuit risk CMT. Surface in the Challenge Prediction panel as a tooltip: "Transportation projects face 1.45× federal friction vs. California EIR — driven by Section 4(f), MPO conformity, and Title VI requirements absent at state level."

**Files to modify:** `NEPA_Sector_Circuit_Risk__mdt` (or equivalent); sector risk display FlexCard/LWC.

---

## Tier 2: Implement Next

These improvements require new CMT types, new fields, or targeted new flow logic.

---

### IMP-006: One Federal Decision Coordination Tracker

**Finding:** Stage 16's highest-friction sectors — Military (1.65×), Water/Coastal (1.47×), Transportation (1.45×) — are precisely those requiring 3+ federal agency sign-offs. The current accelerator tracks dependent permits as status records (`nepa_required_permit__c`) but does not track the coordination milestones between agencies that produce the delay.

**Proposed improvement:** Extend `ApplicationTimeline` with a `nepa_ofd_track__c` picklist (values: `NEPA_Lead` / `Agency_Consultation` / `Permit_Milestone` / `Joint_ROD`) and a `nepa_coordinating_agency__c` lookup to `Account`. Add a pre-built One Federal Decision Action Plan Template with:

| Task | Responsible Agency | Typical Duration |
|---|---|---|
| Initiate joint schedule (E.O. 13807) | Lead agency | Day 0 |
| Submit cooperating agency milestones | Each cooperating agency | Day 30 |
| First joint project management plan | Lead + all cooperating | Day 60 |
| ESA §7 initiation (if applicable) | USFWS/NOAA | Day 60 |
| §404/§401 pre-application meeting | USACE | Day 60 |
| Section 106 initiation | SHPO consultation | Day 90 |
| Scoping report circulated to cooperating agencies | Lead agency | DEIS − 90 days |
| Joint ROD target | All agencies | Day 730 |

**New CMT:** `NEPA_OFD_Milestone__mdt` (milestone template by sector + agency role). Replaces the manually maintained coordination list that agencies currently manage in email.

**Benefit:** Directly addresses the multi-agency overhead that explains 80% of the observed federal friction premium (Stage 16 finding: friction is coordination overhead, not analytical depth).

---

### IMP-007: Litigation Duration Cost Field on IndividualApplication

**Finding:** `Litigation_Duration_Cost__c` is defined in the v3 formula but has no corresponding Salesforce field. It is currently computed inline in the risk scorer without storage.

**Proposed improvement:** Add `Litigation_Duration_Cost__c` as a stored Number (4,2) field on `IndividualApplication`, populated by `NEPA_Litigation_Risk_Scorer` alongside the existing `nepa_risk_score__c`. This enables:
- CRM Analytics dashboards that filter/group by cost exposure independently of win-probability
- Threshold-based alerts for high-cost-exposure projects even when win-probability is medium
- Administrative record snapshots that include cost exposure at decision time

**Field:** `IndividualApplication.nepa_litigation_duration_cost__c` (Number 4,2, range 0.00–1.00).

---

### IMP-008: Sector-Specific Friction Checklist in CE/EA/EIS Intake

**Finding:** Military (1.65×) and Water/Coastal (1.47×) friction stems from specific federal-only requirements: DoD NHPA §106 across installations, USACE §404 dual-track, CZMA federal consistency, EFH Magnuson-Stevens consultation. These are detectable at intake.

**Proposed improvement:** Add sector-specific federal overhead checklist items to the intake OmniScript step 3 (Resource Screening Questionnaire). When `nepa_project_sector__c` = "Military" or "Water/Coastal", additional questions fire:
- Military: "Will this project affect more than one DoD installation?" → triggers NHPA multi-installation coordination flag
- Water/Coastal: "Does the project cross jurisdictional waters?" → triggers USACE §404 and CZMA pre-consultation flag

New extraordinary circumstances triggers populate `nepa_extraordinary_circumstances__c` and feed the CE screening disqualifier logic.

**Files to modify:** `CEIntake` OmniScript (step 3 conditional section); `NEPA_CE_Screener` extraordinary circumstances Expression Set; CE Screener screening rules CMT.

---

### IMP-009: ESA §7 Consultation Status Integration (When TAILS/PCTS Becomes Available)

**Finding:** Stage 15 confirmed ECOS has no public API. The path to decomposing the 1.48× ESA multiplier requires either (a) TAILS (USFWS internal consultation tracking) or (b) NMFS PCTS (NOAA fisheries consultation) via data-sharing agreement.

**Proposed design (implement when data access is established):**

1. Add `nepa_esa_consultation_id__c` (Text 50, external ID) to `nepa_required_permit__c` for ESA §7 consultation tracking numbers.
2. Add `nepa_esa_consultation_type__c` (Picklist: Formal / Informal / Programmatic / No Effect Determination) and `nepa_esa_jeopardy_finding__c` (Picklist: Jeopardy / No Jeopardy / Not Yet Issued).
3. When TAILS API access is established, extend `NEPA_GISProximityIP` to query consultation status by action agency + project area + species.
4. Feed jeopardy finding into a sub-multiplier on the ESA statute risk weight: jeopardy finding → 1.65× (estimated uplift pending empirical data); no-jeopardy with RPA → 1.48× (current baseline); consultation > 24 months → 1.55× (estimated).

**Data access path:** Request data-sharing agreement with USFWS for TAILS read access, or with NOAA for PCTS. Contact route: USFWS Division of Environmental Review, NOAA Office of Protected Resources.

---

### IMP-010: Per-Agency Duration-Aware SLA Targets

**Finding:** Stage 14 shows a 5× spread in median litigation duration by agency (BOEM 6.5 months → FTA 33.4 months). Current SLA targets in `NEPA_Agency_Scoping_Baseline__mdt` cover only the permitting phase, not the downstream litigation phase.

**Proposed improvement:** Add `Median_Litigation_Months__c` and `Litigation_Pathway__c` to `NEPA_Agency_Scoping_Baseline__mdt`. Use in the Risk Intelligence display to tell coordinators: "If this project is challenged under BLM, expect approximately 17.5 months of litigation — factor this into project financing and sequencing decisions."

This is an informational addition; it does not change SLA enforcement logic. It strengthens the accelerator's "cost of delay" messaging for the CEQ Permitting Innovators submission.

---

## Tier 3: Requires External Data

These improvements are designed but blocked until specific data access is established.

---

### IMP-011: TAILS/PCTS Consultation Duration Sub-Multiplier

**Blocked on:** USFWS TAILS or NMFS PCTS API access  
**Action required:** Data-sharing agreement or FOIA request for bulk consultation records  
**See:** IMP-009 for full design

When unblocked, this enables the ESA §7 1.48× multiplier to be split into:
- Consultation duration > 24 months: estimated +0.17× uplift
- Jeopardy finding issued: estimated +0.17× uplift
- Informal consultation only: −0.10× reduction

---

### IMP-012: CEQAnet Project-Level EIR Timing Integration

**Blocked on:** California OPR bulk data export (no API currently available)  
**Action required:** Contact California OPR (`opr@opr.ca.gov`) for bulk EIR timing data export  
**Current state:** Stage 16 uses Holland & Knight 2022 published benchmarks (n=312)

When project-level CEQAnet data is available:
1. Replace published benchmarks with direct sector medians computed from raw data
2. Narrow confidence intervals on the friction multiplier (currently directional due to small CEQA sub-sample sizes: n=8 Military, n=18 Wildlife)
3. Enable project-type-level matching (not just sector-level) between federal EIS and California EIR records

---

### IMP-013: RECAP Docket Entry Analysis for Preliminary Injunction Rate

**Blocked on:** Per-case CourtListener RECAP docket entry pulls  
**Action required:** Run Stage 14 enrichment pass for high-confidence matches (match_score ≥ 0.75, n ≈ 280–320) to fetch individual docket entries and classify "preliminary injunction", "TRO", "Rule 65" events  
**Current state:** Stage 14 returned null for PI analysis — payload lacked docket-entry granularity

When unblocked:
1. Add `nepa_pi_granted__c` (Checkbox) and `nepa_pi_duration_days__c` (Number) to `nepa_litigation__c`
2. Compute PI rate by agency and circuit (preliminary hypothesis: PI rate is higher in the 9th Circuit and for tribal plaintiffs)
3. Add PI history as a challenge prediction rule: if agency has > 20% historical PI rate for similar project type + circuit, add 5 risk points and create a legal review task

---

## Implementation Priority Matrix

| ID | Improvement | Effort | Impact | Blocked? | Recommended Phase |
|---|---|---|---|---|---|
| IMP-001 | Risk score display: separate cost from probability | Low | High | No | Now |
| IMP-002 | Agency duration lookup in risk score factors | Low | High | No | Now |
| IMP-003 | ESA §7 low-confidence disclosure | Low | Medium | No | Now |
| IMP-004 | Circuit duration warnings | Low | Medium | No | Now |
| IMP-005 | Federal friction context for sector cells | Low | Medium | No | Now |
| IMP-006 | One Federal Decision coordination tracker | High | Very High | No | Next (Phase 2) |
| IMP-007 | Litigation duration cost field on IndividualApplication | Low | Medium | No | Next (Phase 2) |
| IMP-008 | Sector-specific friction checklist at intake | Medium | High | No | Next (Phase 2) |
| IMP-009 | ESA §7 consultation status integration | Medium | High | Yes — TAILS/PCTS | When data available |
| IMP-010 | Per-agency duration-aware SLA targets | Low | Medium | No | Next (Phase 2) |
| IMP-011 | TAILS/PCTS consultation sub-multiplier | Medium | High | Yes — TAILS/PCTS | When data available |
| IMP-012 | CEQAnet project-level EIR integration | Medium | Medium | Yes — OPR export | When data available |
| IMP-013 | RECAP PI rate analysis | Medium | Medium | Yes — RECAP pull | When data available |

---

## Architectural Implications

**No new objects required for Tier 1.** IMP-001 through IMP-005 are CMT field additions and UI presentation changes. They deploy as metadata with no schema migration.

**IMP-006 (One Federal Decision tracker) is the highest-value Tier 2 addition** and directly addresses the Stage 16 finding that multi-agency coordination overhead explains most federal friction. It extends `ApplicationTimeline` — an existing standard object — with two new fields and a new Action Plan Template. No new custom objects required.

**IMP-007 introduces one new field** (`nepa_litigation_duration_cost__c`) that belongs in the risk score snapshot written to the administrative record at decision time.

**IMP-008 requires OmniScript step changes** — the conditional section in step 3 of the CE intake wizard. Per ADR 011, this is a supported pattern (IP-backed conditional navigation) and does not require changes to the scoring flows.

**None of the Tier 1 or Tier 2 improvements affect the Salesforce object model** for the 13 CEQ standard entities. They are all additive to existing objects.

---

## Submission Narrative Update

The following additions to `SUBMISSION-NARRATIVE.md` are warranted by these findings (not yet applied — for consideration before the June 2 CEQ submission deadline):

1. **Standard 4 (Minimizing Timeline Uncertainty):** Add the federal friction multiplier finding (1.45×) as evidence that the accelerator's multi-agency coordination hub (Priority 7) addresses the empirically-identified root cause of federal delay, not just a process preference.

2. **Impact section:** Add litigation duration as a quantified cost dimension: "A BLM NEPA challenge takes a median 17.5 months to resolve in court. A FHWA challenge takes 26.1 months. The accelerator's risk score now includes this cost exposure dimension, enabling project sponsors to make financing and sequencing decisions based on realistic timeline projections — not just win-probability estimates."

3. **Key Metrics table:** Update "Risk model calibration stages" from 13 to 16, and add "Court docket records analyzed: 71,243,855" as a headline number.
