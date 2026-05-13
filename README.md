![Public Sector Accelerators logo](/docs/Logo_GPSAccelerators_v01.png)

# PSA-NEPA Permitting Accelerator

**Open-source NEPA permitting data model, workflow automation, and risk intelligence — built on Salesforce Agentforce for Public Sector. Aligned to CEQ NEPA and Permitting Data and Technology Standard v1.2. Deployable from the CLI in one command.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.txt)
[![Platform: FedRAMP Authorized](https://img.shields.io/badge/Platform-FedRAMP%20Authorized-green.svg)](https://marketplace.fedramp.gov/)
[![CEQ Standard: v1.2 Compliant](https://img.shields.io/badge/CEQ%20Standard-v1.2%20Compliant-brightgreen.svg)](https://permitting.innovation.gov/CEQ_NEPA_and_Permitting_Data_and_Technology_Standard.pdf)
[![Apex Tests: 125 passing](https://img.shields.io/badge/Apex%20Tests-125%20passing-brightgreen.svg)](force-app/main/default/classes/)
[![Section 508: WCAG 2.1 AA](https://img.shields.io/badge/Section%20508-WCAG%202.1%20AA-blue.svg)](https://www.salesforce.com/company/legal/508_accessibility/)

> **CEQ Permitting Innovators submission (June 2, 2026):** See [docs/SUBMISSION-NARRATIVE.md](docs/SUBMISSION-NARRATIVE.md) for the full solution narrative structured around the 5 evaluation criteria.

[GPS Accelerators Listing](https://gpsaccelerators.developer.salesforce.com/accelerator/a0wDo000000BBN7IAO/nepa-and-permitting-data-model)

---

## The Problem This Solves

Three categories of preventable delay drive most of the gap between the current median NEPA timeline and what the process could be:

| Delay | Federal Data | This Accelerator |
|---|---|---|
| **CE Misclassification** | 23% of CE records in NETATEC v2.0 lack classification — each incorrect CE→EA escalation adds a median 11 months; CE→EIS adds 2.8 years | 3-tier deterministic BRE CE Screener: NAICS routing → agency/sector Decision Matrix → agency/action-type rules. Auditable to the specific rule row that fired. No AI. |
| **Comment Processing Bottleneck** | 2,600 comments: 4 staff, 4 weeks manually → ~4 hours with AI-assisted triage (NAEP 2025 Workshop, documented federal case) | Agentforce-ready comment triage with non-negotiable EJ/tribal keyword gate that bypasses AI entirely and routes to a human coordinator queue |
| **Late-Stage Litigation Surprises** | Tribal Nation plaintiffs win 87.5% of NEPA cases (761 cases, PermitTEC v0.1). Energy × 4th Circuit: 28.6% agency win rate — highest-risk sector-circuit cell in the corpus | Composite 0–100 litigation risk score, 7 dimensions, recalculated on every save. Scores ≥58 auto-create a legal review task. Tribal challengers trigger dual flag + +20pt delta. All signals surfaced before the record closes. |

**Each number above corresponds to a deployed, deterministic feature — not a roadmap item.**

---

## At a Glance

| Dimension | Value |
|---|---|
| CEQ entities implemented | 13 of 13 (6 standard + 7 extended, per PIC OpenAPI v1.2.0) |
| Declarative flows | 31 |
| CE Library records | 2,105 categorical exclusions across 79 federal agencies |
| Litigation cases in risk model | 761 (PermitTEC v0.1, PNNL 2025) |
| NEPA projects in baseline corpus | 61,881 (NETATEC v2.0, PNNL 2025) |
| Custom metadata types | 15 |
| BRE Decision Matrices + Expression Sets | 8 DMs + 3 ESs (deterministic, not AI) |
| Apex compliance tests | 125 across 4 test classes |
| Platform | Salesforce Agentforce for Public Sector (FedRAMP Authorized) |
| Section 508 / WCAG 2.1 AA | Compliant — inherited from Salesforce Lightning Design System and OmniScript components |
| Software license cost | $0 (MIT open source) |
| Deployment time | ~15 minutes from CLI |

---

## How AI Is and Is Not Used

A clear AI/rules boundary is a legal requirement for federal permitting. This solution enforces it by design.

| Feature | Technology | Why |
|---|---|---|
| CE screening and classification | **Deterministic BRE** | Statutory CE determinations must trace to a specific CFR citation and rule row. No probabilistic inference. |
| Litigation risk scoring | **Deterministic BRE** | Formulas are fully inspectable; a coordinator can hand-calculate the score from the inputs. No black box. |
| Challenge prediction rules | **Deterministic rule matching** | Exact field-value matching, not model inference. |
| Stage gate enforcement | **Deterministic flows** | Blocking transitions must never depend on probabilistic confidence. |
| Public comment triage | **Agentforce AI** | High-volume unstructured text. AI classifies; human reviews every comment before formal response. |
| EJ/tribal comment routing | **Keyword gate — no AI** | Tribal sovereignty, sacred sites, EJ, civil rights keywords bypass AI and route to a human queue. Cannot be disabled. |

---

## Zero-Friction Pilot Readiness

An agency can spin up a Salesforce sandbox, deploy this MIT-licensed accelerator, and be running a live proof-of-concept with their own historical data **in an afternoon** — bypassing the traditional 6-month software implementation cycle.

**Prerequisites:** Salesforce Agentforce for Public Sector org (Foundations or Advanced). A free APS developer org is available at the [APS trial link](https://developer.salesforce.com/free-trials/comparison/public-sector).

```bash
sf org login web --alias nepadev
sf project deploy start --source-dir force-app --target-org nepadev --wait 30
```

That is the complete deployment command. No infrastructure provisioning, no database migration, no middleware configuration. For the complete post-deploy sequence (BRE activation, Decision Matrix CSV import, flow activation, permission set assignment, sample data load), see **[docs/QUICKSTART.md](docs/QUICKSTART.md)**.

**For agencies already on Salesforce APS:** this accelerator represents zero incremental software licensing cost — it deploys into an existing org as a package of standard metadata, leveraging the enterprise agreement already in place.

---

## Repository Map

| Path | Contents | Why It Matters |
|---|---|---|
| `force-app/main/default/objects/` | 13 CEQ entity object definitions + 15 custom metadata type schemas | The complete data model — start here to understand the schema |
| `force-app/main/default/flows/` | 31 flow XML files | All automation: stage gates, risk scoring, CE screening, plaintiff intelligence, scoping baselines, error logging |
| `force-app/main/default/expressionSetDefinition/` | 3 BRE Expression Set definitions (CE Screener, Litigation Risk Scorer V2/V3, Permit Coordinator) | The deterministic scoring engines |
| `force-app/main/default/decisionMatrixDefinition/` | 8 BRE Decision Matrix definitions | Rule tables that feed the Expression Sets |
| `decision_matrix_rows/` | CSV files for each Decision Matrix + import instructions | **BRE row data cannot be deployed via CLI — must be imported via Setup UI. Read [README](decision_matrix_rows/README.md) first.** |
| `force-app/main/default/customMetadata/` | Pre-seeded risk weights, CE screening rules, plaintiff profiles, scoping baselines, sector-circuit matrix | The empirically calibrated data that powers the intelligence layer |
| `force-app/main/default/classes/` | 4 Apex test classes (125 tests total) | Compliance verification — run `sf apex run test` against your org |
| `force-app/main/default/omniStudio/` | 6 DataRaptor Extracts + `NEPA/CEQExport` Integration Procedure | CEQ-standard JSON export (MFR #2 compliance) |
| `demo/` | Demo story + import data CSVs | Carrie's Placer Mine scenario — full end-to-end walkthrough of CE screening, risk scoring, tribal plaintiff detection |
| `docs/SUBMISSION-NARRATIVE.md` | CEQ Permitting Innovators submission narrative | Full solution narrative structured around 5 evaluation criteria |
| `docs/QUICKSTART.md` | Step-by-step deployment and configuration | Start here after cloning |
| `docs/AI-Use-Policy.md` | OMB M-25-21 AI disclosure | Training data sources, limitations, prohibited uses, human confirmation requirements |
| `docs/ARCHITECTURE_DECISIONS.md` | ADRs 001–011 | Every significant design choice with context, rationale, and consequences |
| `docs/FLOW-ARCHITECTURE.md` | 31-flow design: error chain, stage gates, defensibility wrapper | Flow orchestration reference |

---

## Standards and Compliance

| Standard | Coverage |
|---|---|
| **CEQ NEPA and Permitting Data and Technology Standard v1.2** | All 13 entities implemented; 5 required provenance fields on each; 125 Apex tests verify field-level compliance |
| **CEQ Permitting Technology Action Plan (May 2025)** | MFR #1 (Data Standards), MFR #2 (Data Sharing), MFR #5 (Automated Case Management), MFR #7 (Document Management) — Foundational and Emerging maturity |
| **OMB M-25-21** | AI advisory-only; AI recommends, human confirms enforced in all flows; EJ/tribal gate non-negotiable |
| **FAST-41** | Per-agency baseline durations pre-seeded; `nepa_milestone_variance_days__c` provides real-time variance against agency-specific statutory targets |
| **Section 508 / WCAG 2.1 AA** | Compliant — UI built exclusively on Salesforce Lightning Design System and OmniScript components, both Salesforce-certified for 508/WCAG 2.1 AA. Salesforce VPAT available. |
| **FedRAMP** | Authorized — Salesforce Gov Cloud. CUI in GIS coordinates, archaeological sites, and tribal data is handled within the existing authorized data boundary. No separate ATO required. |

---

## CEQ Entity Coverage

| CEQ Entity | Salesforce Object | Status |
|---|---|---|
| Entity 1: Project | `Program` | ✅ Implemented |
| Entity 2: Process | `IndividualApplication` | ✅ Implemented |
| Entity 3: Documents | `ContentVersion` (record type: `nepa_permit_document`) | ✅ Implemented |
| Entity 4: Comments | `PublicComplaint` | ✅ Implemented |
| Entity 5: Public Engagement Events | `nepa_engagement__c` (custom) | ✅ Implemented |
| Entity 6: Case Events | `ApplicationTimeline` (APS standard, extended) | ✅ Implemented |
| Entity 7: GIS Data | `nepa_gis_data__c` (child of APS `Polygon`) + Program lat/lon/polygon fields + GIS proximity flow | ✅ Implemented |
| Entity 8: User Role | `nepa_process_team_member__c` — structured role assignment linking User, Agency (Account), and Process | ✅ Implemented |
| Entity 9: Legal Structure | APS `RegulatoryCode` extended with `nepa_compliance_requirements__c`, `nepa_text_content__c`, and 5 provenance fields | ✅ Implemented |

All 13 entities include the 5 custom provenance fields required by CEQ standard v1.2 (`Data Record Version`, `Data Source Agency`, `Data Source System`, `Record Owner Agency`, `Retrieved Timestamp`). `LastModifiedDate` (native Salesforce) satisfies the standard's `Last Updated` provenance property.

---

## Data Sources

**NETATEC v2.0 (PNNL, 2025):** 61,881 federal NEPA projects compiled by Pacific Northwest National Laboratory. The analysis subset covers 54,668 CE projects across BLM, DOE, and USDA with 73,521 associated documents. Used to derive CE screening rules, page count outlier thresholds (CE p95 = 17 pages, EA p95 = 200 pages), per-agency EIS scoping baselines, and FAST-41 timeline durations.

**PermitTEC v0.1 (PNNL, 2025):** 761 federal NEPA litigation cases compiled by Pacific Northwest National Laboratory, covering 1970–2025. A 13-stage calibration pipeline produced empirically derived risk weights: agency points from observed loss rates (`loss_rate × 0.40 × 2.5`), circuit points from court decision multipliers (`(multiplier − 0.30) × 25 × 1.5`), statute points from involvement multipliers (`(multiplier − 1.00) × 20`), and a 17-cell sector-circuit win-rate matrix. All weights are traceable to specific case counts. Low-confidence weights (fewer than 20 cases) are flagged with `Low_Data_Confidence__c = true` in the custom metadata records and disclosed in every risk score output.

---

## Included Assets

<ol>
  <li><strong>Custom Fields</strong> on the following standard APS objects:
    <ul>
      <li>IndividualApplication — 40+ fields (Entity 2: Process + risk intelligence)</li>
      <li>ContentVersion — 22 fields (Entity 3: Documents)</li>
      <li>Program — 25+ fields (Entity 1: Project + agency performance tier)</li>
      <li>PublicComplaint — 14 fields (Entity 4: Comments)</li>
      <li>ApplicationTimeline — 17 fields (Entity 6: Case Events)</li>
    </ul>
  </li>
  <li><strong>Custom Objects</strong> (x5)
    <ul>
      <li>NEPA Public Engagement Event (<code>nepa_engagement__c</code>) — Entity 5</li>
      <li>NEPA GIS Data Element (<code>nepa_gis_data__c</code>) — Entity 7</li>
      <li>NEPA Decision Log (<code>nepa_decision_log__c</code>) — process decision payload</li>
      <li>NEPA Decision Element (<code>nepa_decision_element__c</code>) — screening criteria definitions</li>
      <li>Process Agency Relationship (<code>nepa_process_related_agencies__c</code>)</li>
    </ul>
  </li>
  <li><strong>Custom Metadata Types</strong> (x15) — all agency-specific parameters externalized as configuration:
    <ul>
      <li><code>NEPA_Agency_Risk_Rate__mdt</code> — per-agency litigation loss rates (7 records)</li>
      <li><code>NEPA_Circuit_Risk_Weight__mdt</code> — per-circuit risk multipliers (13 records)</li>
      <li><code>NEPA_Statute_Risk_Weight__mdt</code> — adjacent statute risk weights (5 records: ESA, NFMA, CWA, NGA, NHPA)</li>
      <li><code>NEPA_Sector_Circuit_Risk__mdt</code> — sector × circuit win-rate matrix (17 cells)</li>
      <li><code>NEPA_Plaintiff_Profile__mdt</code> — known plaintiff profiles with win rates and tribal flag (6 records)</li>
      <li><code>NEPA_Challenge_Prediction_Rule__mdt</code> — challenge prediction rules with risk deltas (7 records)</li>
      <li><code>NEPA_Agency_Scoping_Baseline__mdt</code> — per-agency EIS scoping medians and performance tier (11 records)</li>
      <li><code>NEPA_CE_Screening_Rule__mdt</code>, <code>NEPA_CE_Code__mdt</code> — CE screening rules and CE Library</li>
      <li><code>NEPA_SLA_Config__mdt</code>, <code>NEPA_Stage_Baseline_Duration__mdt</code>, <code>NEPA_Required_Document__mdt</code>, <code>NEPA_Process_Model__mdt</code>, <code>NEPA_Permit_Matrix__mdt</code>, <code>NEPA_GIS_Layer__mdt</code> — process configuration</li>
    </ul>
  </li>
  <li><strong>BRE Decision Matrices</strong> (x8) and <strong>Expression Sets</strong> (x3):
    <ul>
      <li>CE Screener: NAICS Routing, Tier 1 Agency/Sector, Tier 2 Agency/Action Type</li>
      <li>Litigation Risk Scorer: Review Type, Agency, Circuit, Sector-Circuit (V3 input) — Expression Set V2 Active, V3 Draft</li>
      <li>Permit Coordinator: Permit Matrix</li>
    </ul>
  </li>
  <li><strong>Declarative Flows</strong> (x31) — all automation is Flow-based; no custom Apex for business logic</li>
  <li><strong>OmniStudio</strong>: 6 DataRaptor Extracts + <code>NEPA/CEQExport</code> Integration Procedure (MFR #2 data sharing)</li>
  <li><strong>Permission Set</strong>: <code>NEPA_Permitting</code> with FLS configured for all custom fields</li>
  <li><strong>CE Library</strong>: 2,105 categorical exclusions across 79 federal agencies (sourced from CEQ CE Explorer v2.0)</li>
  <li><strong>Apex Test Suite</strong>: 125 tests across 4 classes verifying CEQ entity compliance, export service, BRE configuration integrity, and API contract</li>
</ol>

---

## CEQ-Compliant Data Export

The `NEPA/CEQExport` Integration Procedure accepts a `projectId` and returns a nested JSON payload containing all 13 implemented CEQ entities for that project, aligned to PIC OpenAPI v1.2.0. Exposes via API Action for MFR #2 compliance.

```json
{
  "schema_version": "1.2",
  "standard": "CEQ NEPA and Permitting Data and Technology Standard",
  "exported_at": "2026-05-13T00:00:00Z",
  "project": {
    "id": "...",
    "project_id": "<UUID>",
    "project_title": "...",
    "processes": [
      {
        "federal_unique_id": "<UUID>",
        "nepa_review_type": "EIS",
        "status": "in progress",
        "documents": [...],
        "public_engagement_events": [...],
        "case_events": [...]
      }
    ]
  }
}
```

See [docs/QUICKSTART.md](docs/QUICKSTART.md) for activation and API setup instructions.

---

## Key Documentation

| Document | Purpose |
|---|---|
| [QUICKSTART.md](docs/QUICKSTART.md) | Complete deployment and configuration walkthrough |
| [SUBMISSION-NARRATIVE.md](docs/SUBMISSION-NARRATIVE.md) | CEQ Permitting Innovators submission — 5 evaluation criteria |
| [AI-Use-Policy.md](docs/AI-Use-Policy.md) | OMB M-25-21 AI disclosure: data sources, limitations, prohibited uses |
| [ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md) | ADRs 001–011: design rationale and consequences |
| [FLOW-ARCHITECTURE.md](docs/FLOW-ARCHITECTURE.md) | 31-flow design: error chain, stage gates, defensibility wrapper |
| [NEPA-Risk-Intelligence-Plan.md](docs/NEPA-Risk-Intelligence-Plan.md) | Litigation risk scoring and defensibility gap features |
| [NEPA-Permitting-Acceleration-Plan.md](docs/NEPA-Permitting-Acceleration-Plan.md) | 10 priorities ranked by time-to-permit impact |
| [decision_matrix_rows/README.md](decision_matrix_rows/README.md) | BRE Decision Matrix CSV import instructions — **required post-deploy step** |

---

## Data Model Notes

**`IndividualApplication` vs. `BusinessLicenseApplication`:** The APS standard object chosen for CEQ Entity 2 (Process) is `IndividualApplication`, not `BusinessLicenseApplication`. NEPA proponents include individuals, joint ventures, tribes, federal agencies, and businesses — not exclusively commercial entities. `IndividualApplication` carries the stage, status, and outcome workflow fields that map directly to CEQ's Process entity properties. The APS object label can be overridden to "NEPA Process" or "Permit Application" in Setup without changing any API names or downstream metadata.

**External IDs:** `Program.nepa_project_id__c` and `IndividualApplication.nepa_federal_unique_id__c` are External ID fields supporting upsert operations from external agency systems. CEQ recommends UUID format; field length is set to 36 characters.

**Process status values** align with CEQ standard: `planned | pre-application | in progress | paused | completed | cancelled`.

**Multi-value text fields:** `Program.nepa_project_sector__c` and `Program.nepa_project_type__c` are LongTextArea fields supporting multiple semicolon-separated values. Many real-world NEPA projects span multiple sectors simultaneously.

**Provenance fields:** All 5 custom provenance fields (`nepa_data_record_version__c`, `nepa_data_source_agency__c`, `nepa_data_source_system__c`, `nepa_record_owner_agency__c`, `nepa_retrieved_timestamp__c`) are present on all 13 implemented entities. `LastModifiedDate` (native) satisfies the standard's `Last Updated` property.

**BRE activation requirement:** Deploying Decision Matrix and Expression Set metadata via CLI does not create the `LatestVersionSnapshotId` required by the BRE runtime. After every deploy, open each DM and ES in Setup → Business Rules Engine and click **Activate**. See [decision_matrix_rows/README.md](decision_matrix_rows/README.md) for the full sequence including CSV import.

---

## Revision History

**2.0 (2026-05-13)** — Risk intelligence layer (Phases 1–5): empirically calibrated weights from 13-stage PermitTEC pipeline

- Phase 1: Recalibrated all risk weights from Stage 7 analysis (agency loss rates, circuit multipliers, statute multipliers). 10th Circuit replaces 9th as highest-risk venue (43pts, 68 cases). FHWA added as new agency. NFMA and NGA added as new statute weights. Risk tier thresholds recalibrated to LOW <35 / MEDIUM 35–44 / HIGH 45–57 / VERY HIGH ≥58.
- Phase 2: Tribal plaintiff intelligence — `Is_Tribal_Nation__c` on `NEPA_Plaintiff_Profile__mdt`; dual flags (`nepa_plaintiff_risk_flag__c` + `nepa_tribal_plaintiff_flag__c`) on `IndividualApplication`; tribal consultation hard gate before EA/EIS publication. Added Navajo Nation, Sierra Club, Earthjustice, ONRC, WildEarth Guardians (updated), Western Watersheds Project plaintiff profiles.
- Phase 3: Challenge prediction rules with accumulable risk deltas — Energy × 4th Circuit (+12pts), Tribal plaintiff override (+20pts based on 87.5% win rate). `NEPA_Agency_Scoping_Baseline__mdt` with 11 per-agency EIS scoping medians from CEQ EIS Timeline 2010–2024 data. Scoping overrun detection fields on `IndividualApplication`.
- Phase 4: `nepa_agency_performance_tier__c` on Program (Fast_and_Defensible / Slow_Scoping_Bottleneck / Legally_Vulnerable). `NEPA_Agency_Tier_Setter` async after-save flow. Per-agency EIS baselines in Timeline Risk Assessor. Page count outlier detection (CE >17 pages, EA >200 pages → At Risk).
- Phase 5: `NEPA_Sector_Circuit_Risk__mdt` (17-cell sector × circuit win-rate matrix from Stage 13 analysis). `NEPA_Risk_SectorCircuit` BRE Decision Matrix. Litigation Risk Scorer BRE Expression Set V3 (Draft) with `SectorCircuitTerm` and `ScopingTerm` composite formula. `formula_SectorCircuitKey` and 3 new BRE input parameters in Risk Scorer flow.
- Added `NepaBREConfigTest.cls` (36 tests) covering Phase 1–5 BRE configuration integrity.

**1.1 (2026-04-29)** — CEQ Standard v1.2 alignment (Tier 1 + Tier 2) + CEQ-compliant export + NETATEC v2.0 compatibility

- Added OmniStudio `NEPA/CEQExport` Integration Procedure and 6 DataRaptor Extracts for MFR #2 data sharing compliance
- Added Entities 7, 8, 9 (GIS Data, User Role, Legal Structure)
- Added 30 declarative flows for stage gate orchestration, CE screening, risk scoring, defensibility tracking, and error logging
- Added CE Library (2,105 records) and CE Screener BRE (3-tier logic)
- Added litigation risk intelligence pre-seeded from PermitTEC v0.1 corpus

**1.0 (2025-09-19)** — Initial release: minimal viable CEQ data model compliance

---

## APS Dependency

This accelerator requires **Salesforce Agentforce for Public Sector (APS)**. If your org does not have APS installed, see [QUICKSTART.md — APS Substitution](docs/QUICKSTART.md#pss-substitution) for object replacement guidance. A free APS developer org is available at the [APS trial link](https://developer.salesforce.com/free-trials/comparison/public-sector).

---

## License and Terms

MIT. See [LICENSE.txt](LICENSE.txt). Accelerators are provided as-is and are not supported by Salesforce.

For more about the GPS Accelerators program, visit: [https://gpsaccelerators.developer.salesforce.com/](https://gpsaccelerators.developer.salesforce.com/)
