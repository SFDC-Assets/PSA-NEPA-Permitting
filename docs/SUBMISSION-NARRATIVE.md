# CEQ Permitting Innovators Submission Narrative

**Program:** CEQ Permitting Innovators
**Submission Deadline:** June 2, 2026
**Solution Name:** PSA-NEPA Permitting Accelerator
**Submitting Organization:** GPS Accelerators (Salesforce Public Sector Partner)
**License:** MIT (open source)
**Repository:** PSA-NEPA-Permitting-Data-Model

---

## Executive Summary

The PSA-NEPA Permitting Accelerator is an open-source, production-ready implementation of the CEQ NEPA and Permitting Data and Technology Standard v1.2, built entirely on Salesforce Public Sector Solutions (PSS) — a FedRAMP-authorized platform. It maps all six CEQ-defined entities to Salesforce-native objects, delivers 30 declarative automation flows covering the full NEPA process lifecycle, and embeds a risk intelligence layer pre-seeded from 761 federal litigation cases (PermitTEC v0.1, PNNL 2025) and a CE Library of 2,105 categorical exclusions across 79 federal agencies.

The solution is deployable from the command line in approximately 15 minutes, requires no custom infrastructure, and is extensible to additional agencies through custom metadata configuration alone — no code changes required.

---

## Criterion 1: Impact

### Quantified Time-to-Permit Reductions

The CEQ EIS Timeline Report (January 2025) documented a median EIS completion time of 2.8 years (2019–2024), with the distribution heavily right-skewed — some processes exceeding 13 years. Environmental Assessments typically run 6–18 months. Categorical Exclusions, when correctly applied, resolve in days to weeks. The gap between an incorrect EA escalation and a proper CE determination is measured in months to years, not days.

This accelerator addresses three categories of delay directly:

**Category 1: CE Misclassification (6 months to 2+ years per incorrectly escalated project)**

The CE Library contains 2,105 categorical exclusions across 79 federal agencies, searchable via Einstein Search and indexed with SOSL full-text search. The CE Screener BRE covers 6 agencies using 3-tier Business Rules Engine logic: NAICS routing narrows the CE namespace, agency/sector rules apply high-confidence Tier 1 mappings, and agency/action-type rules resolve ambiguous Tier 2 cases. NEPATEC v2.0 analysis identified that 23% of CE records lacked a ce_category — concentrated in BLM oil/gas and Agriculture/Rangeland projects, precisely the categories where ambiguity causes unnecessary EA escalation. The screener eliminates that ambiguity at intake.

**Category 2: Comment Analysis Bottleneck (4–8 weeks per EA/EIS on the critical path)**

Public comment compilation and individual response is directly on the critical path for every EA and EIS. The NAEP 2025 Workshop documented an AI-assisted comment analysis case where 2,600 comments required by 4 staff over 4 weeks were processed in approximately 4 hours. The accelerator's Comment Triage infrastructure — Agentforce-ready field design, EJ/tribal gate architecture, and sentiment/substantive classification — establishes the data foundation for this compression.

**Category 3: Late-Stage Litigation Surprises (months to years of delays from vacated decisions)**

Analysis of the PermitTEC v0.1 corpus (761 federal NEPA litigation cases, PNNL 2025) shows that incomplete administrative records are among the most common bases for successful NEPA challenges. The accelerator's Defensibility Gap Checker scores completeness of the administrative record in real time — flagging missing required documents, absent public engagement records, and unaddressed adjacent statute consultations before the record is closed, not after a court filing identifies the gap. Very High risk scores (75–100) automatically trigger a legal review task, routing human attention to the cases most likely to be challenged.

### Measurable Administrative Burden Reduction

- **30 declarative flows** automate milestone routing, SLA due-date setting, stage gate enforcement, document completeness scoring, and error logging — eliminating manual coordination steps that currently require email, spreadsheets, and phone calls.
- **FAST-41 timeline tracking** is pre-seeded with baseline durations for CE/EA/EIS stages, giving program managers real-time variance visibility against statutory targets without custom reporting build-out.
- **OmniScript CE Intake Wizard** (7 steps with real-time CE pre-screening) collects structured data at submission time, eliminating the request-for-information cycles that each add 2–4 weeks per round.
- **CEQ-compliant data export** (`NEPA/CEQExport` Integration Procedure) satisfies MFR #2 (Data Sharing) at Emerging maturity immediately upon activation — no additional development required.

---

## Criterion 2: User-Centered Design

### Applicant-Facing Experience

The OmniScript CE Intake Wizard guides applicants through a 7-step structured intake process with real-time CE pre-screening. At each step, the OmniScript provides conditional navigation based on prior answers — applicants are not presented with fields irrelevant to their project type. The wizard captures:

1. Federal jurisdiction and lead agency (determines CE catalog namespace)
2. Project sector and type (maps to NEPATEC classification taxonomy)
3. Action type (the primary discriminator between CE and EA: construct new vs. modify existing vs. renew/extend)
4. Physical parameters (acreage of surface disturbance, indoor/outdoor, existing footprint)
5. NAICS code (used for jurisdiction routing and extraordinary circumstances pre-screening)
6. GIS footprint submission (triggers FWS ECOS critical habitat and EPA EJScreen proximity checks)
7. Review and completeness check before submission

Applicants receive a CE pre-screening result — recommended review type, applicable CE code set, confidence level, and any extraordinary circumstances flags — before the record is formally submitted. This gives applicants actionable feedback at intake rather than weeks later.

The GIS proximity integration uses FWS ECOS (critical habitat) and EPA EJScreen (environmental justice index) via OmniIntegrationProcedure, surfacing resource sensitivities automatically without requiring applicants to interpret raw GIS datasets.

### Agency Staff Experience

NEPA Coordinators work from record pages that surface the information needed for each stage of the process without navigating multiple systems. Key design choices:

- **Separation of AI recommendation from official determination.** The CE Screener writes a recommendation to `nepa_ce_pathway_recommendation__c` (read-only to AI, visible to all users). The official pathway is `nepa_review_type__c`, which only a credentialed NEPA Coordinator can set. The system will not advance a record to downstream stage gates on the recommendation field alone.
- **Classification basis audit trail.** `nepa_classification_basis__c` records the full rule-match path for every CE screening decision, giving coordinators the specific basis for any recommendation rather than a black-box result.
- **Defensibility gap checklist.** Real-time completeness scoring flags missing required documents by review type, giving staff a prioritized action list rather than a post-hoc gap discovery during litigation.
- **Stage gate enforcement.** Before-save flows block invalid stage transitions and enforce document requirements at each gate, preventing records from advancing past required checkpoints without completing prerequisites.

### Transparency and Accessibility

All AI-generated content is flagged with `nepa_ai_generated__c` and carries a disclosure in `nepa_risk_score_factors__c`:

> `[AI-GENERATED — PermitTEC v0.1, PNNL 2025, 761 cases; circuit weights based on small sample, treat as directional]`

The AI Use Policy (included in the repository) discloses training data sources, known statistical limitations, prohibited uses, and the human confirmation requirements for each AI-assisted feature. This documentation satisfies OMB M-25-21 requirements for AI use case disclosure and supports agency AI inventory registration.

The EJ/tribal gate is non-negotiable in the design: comments containing tribal sovereignty, sacred sites, environmental justice, or civil rights keywords are routed directly to the EJ/Tribal Liaison coordinator queue. AI does not classify these comments. This gate cannot be overridden by any automated process.

---

## Criterion 3: Readiness

### Deployable Today

The accelerator deploys from the Salesforce CLI in approximately 15 minutes:

```bash
sf org login web --alias nepadev
sf project deploy start --source-dir force-app --target-org nepadev --wait 30
```

All metadata is source-tracked and version-controlled. The repository includes:

- Complete object, field, and custom metadata type definitions
- 30 flow XML files (deployable as Draft; activation is a separate step documented in QUICKSTART.md)
- Permission set with field-level security configured for all custom fields
- 6 DataRaptor Extracts and 1 Integration Procedure for CEQ-compliant data export
- Custom metadata records pre-seeded with PermitTEC litigation weights and CE screening rules
- Sample data scripts for verification

### Standards Alignment

The solution is aligned to:

- **CEQ NEPA and Permitting Data and Technology Standard v1.2** (May 30 / August 18, 2025): All 6 CEQ standard entities implemented with the 5 required provenance fields
- **CEQ Permitting Technology Action Plan (May 2025)**: Supports MFR #1 (Data Standards), MFR #2 (Data Sharing), MFR #5 (Automated Case Management), and MFR #7 (Document Management) at Foundational and Emerging maturity levels
- **OMB M-25-21**: AI features are advisory-only; AI recommends, human confirms is enforced in all flows; human override always available
- **FAST-41**: Timeline tracking pre-seeded with baseline durations; `nepa_milestone_variance_days__c` provides real-time variance against statutory targets

### Configuration, Not Code

All agency-specific parameters — CE codes, risk weights, SLA configurations, agency routing rules — are stored in 8 Custom Metadata Types. Adding a new agency requires creating custom metadata records, not modifying code or redeploying flows. This means:

- Weight updates (e.g., when a new PermitTEC corpus release is available) require only a metadata deployment, not an Apex compilation or test-class update
- Agency administrators with the `Customize Application` permission can audit and update parameters without developer access
- The audit trail for weight changes is preserved through the `Effective_Date__c` and `Update_Notes__c` fields on screening rule records — the pattern creates new records with new dates rather than overwriting existing ones

### Clear Adoption Path

The QUICKSTART.md documents the complete deployment sequence: prerequisites, org configuration, flow activation, permission set assignment, custom metadata seeding, and verification steps. Architecture Decision Records (ADRs 001–011) document every significant design choice with context, rationale, and consequences — giving adopting agencies the information needed to adapt the solution to their specific requirements without reverse-engineering design intent.

---

## Criterion 4: Multi-Agency Compatibility

### Designed for Federal Agency Diversity

The accelerator is architected for multi-agency deployment from the ground up. Every element that varies by agency is externalized into configuration:

**CE Library by Agency:** The `nepa_ce_library__c` object stores 2,105 categorical exclusions from CEQ CE Explorer v2.0 across 79 federal agencies. Each record carries the CFR authority, plain-language description, acreage threshold, indoor-only flag, and GIS review requirement for that specific exclusion. Agency-specific CE codes are fully isolated — BLM 516 DM citations, DOE 10 CFR 1021 Appendix B codes, Energy Policy Act Section 390 exclusions, and USFS 36 CFR 220.6 codes all coexist in the same library without collision.

**Agency-Specific Risk Weights:** `NEPA_Agency_Risk_Rate__mdt` holds per-agency litigation rates derived from the PermitTEC corpus. `NEPA_Circuit_Risk_Weight__mdt` holds per-circuit geographic risk multipliers. Forest Service (37 PermitTEC cases), BLM (35 cases), and FERC (15 cases) carry different baseline rates; the scoring model applies the correct agency-specific prior automatically.

**Process Type Coverage:** The accelerator covers the full NEPA review spectrum: Categorical Exclusion (CE), Environmental Assessment (EA), and Environmental Impact Statement (EIS). Stage gate logic, SLA configurations, document checklists, and Action Plan templates are each parameterized by review type. A CE process and an EIS process on the same agency follow different gate sequences, document requirements, and timeline baselines — driven by the same flow logic reading different metadata.

**Cooperating Agency Support:** The `nepa_process_related_agencies__c` junction object with `nepa_role__c` picklist (Proponent / Cooperating / Participating) supports multi-agency NEPA processes where multiple federal agencies share responsibilities. The multi-party proponent pattern was a documented design requirement: NEPA proponents span individuals, businesses, federal and state agencies, tribal nations, and joint ventures — and the data model handles all of them.

### PSS as the Multi-Agency Platform

Salesforce Public Sector Solutions is used across federal agencies for regulatory intake, case management, and public engagement. Deploying the accelerator into a PSS org that already serves multiple program offices means the NEPA accelerator operates alongside existing agency workflows without separate infrastructure. The FedRAMP Authorization to Operate covers the platform itself; agencies do not need to independently authorize a new system.

The declarative-first architecture (all 30 flows, no custom Apex for business logic) means agency IT staff can inspect, modify, and extend the automation in Salesforce Flow Builder without Salesforce developer credentials or a local development toolchain. This lowers the barrier to agency-specific customization after initial deployment.

### Extension Without Code Changes

Adding a new agency to the CE Screener requires:
1. Creating new `NEPA_CE_Screening_Rule__mdt` records for the agency's CE authorities
2. Adding the agency's CE codes to `nepa_ce_library__c` (bulk-loadable from the agency's existing CE documentation)
3. Creating `NEPA_Agency_Risk_Rate__mdt` and `NEPA_Circuit_Risk_Weight__mdt` records seeded from available litigation data

No flow XML modifications, no Apex changes, no deployment of new code.

---

## Criterion 5: Team Capacity

### Salesforce Public Sector Expertise

GPS Accelerators is a Salesforce Public Sector partner with federal permitting agency implementations. The team has direct experience deploying PSS-based solutions for regulatory intake, permitting workflows, and public engagement tracking at federal agencies — the same operational context this accelerator addresses.

The solution reflects that experience in concrete design choices: the `IndividualApplication` vs. `BusinessLicenseApplication` object selection was made because NEPA proponents are not exclusively commercial entities; the platform event error architecture was designed for the specific failure mode of Salesforce transaction rollback in bulk load scenarios; the OmniStudio isolation strategy was documented because the Flow-to-OmniIP invocation failure mode (UNKNOWN_EXCEPTION at activation, no actionable error message) is only discoverable through operational experience.

### Domain-Grounded Design

The accelerator is grounded in the NEPA process specifically, not generic permitting theory:

- Litigation risk weights are derived from actual federal NEPA litigation cases (PermitTEC v0.1, PNNL 2025), not synthetic estimates
- CE screening rules are derived from NEPATEC v2.0 analysis of 54,668 CE projects across BLM, DOE, and USDA — the largest available corpus of federal CE records
- The five NEPA challenge grounds modeled in the challenge predictor (failure to prepare, EIS/EA inadequacy, improper CE reliance, failure to supplement, adjacent statute violation) reflect the actual legal classification used in the PermitTEC corpus
- FAST-41 timeline baselines are pre-seeded from the NEPATEC v2.0 process duration data, not estimated

The AI Use Policy included in the repository discloses the known statistical limitations of each model — circuit-level weights derived from as few as 3 cases, the distinction between litigation exposure and outcome prediction, the recency limitation of pre-2010 case data — because operational deployment at federal agencies requires honest disclosure of model confidence, not optimistic framing.

### Open Source Commitment

The solution is released under an MIT license with full source code available. Architecture Decision Records document every significant design choice. The QUICKSTART.md is written for agency IT staff, not Salesforce developers. The intent is to enable agencies to adopt, adapt, and maintain the solution without ongoing dependence on any single vendor — including GPS Accelerators.

---

## Summary of Key Metrics

| Dimension | Value |
|---|---|
| CEQ standard entities implemented | 6 of 6 (all defined entities) |
| Total declarative flows | 30 |
| CE Library records | 2,105 categorical exclusions |
| Agencies covered in CE Library | 79 |
| Litigation cases in risk model | 761 (PermitTEC v0.1, PNNL 2025) |
| NEPA projects in baseline corpus | 61,881 (NEPATEC v2.0) |
| Custom metadata types | 8 |
| Custom Apex classes | 1 (infrastructure bridge only) |
| Deployment time from CLI | ~15 minutes |
| Platform FedRAMP status | Authorized (Salesforce Gov Cloud) |
| License | MIT (open source) |
| OMB M-25-21 compliance | Documented in AI-Use-Policy.md |
