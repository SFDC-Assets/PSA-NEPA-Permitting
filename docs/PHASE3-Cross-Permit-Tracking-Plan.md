# Phase 3 Cross-Permit Tracking — Implementation Plan

**Version:** 1.0  
**Date:** 2026-05-19  
**Status:** Approved for implementation  
**Baseline:** PSA-NEPA-Permitting-Data-Model v1.1

---

## Context

The [Environmental Permitting Flow Chart (AGC of America, 06-14-2017)](../Environmental%20Permitting%20Flow%20Chart%20(06-14-2017).jpg) depicts a 5-phase lifecycle. The current NEPA accelerator covers **Phases 1–2** (Planning/Development and Environmental Assessment) comprehensively. **Phase 3** (Permitting & Federal Authorizations) is structurally present but functionally hollow:

| Gap | Root cause |
|---|---|
| `nepaPermitDependencies` LWC always shows empty | `NEPA_Permit_Record_Creator` flow doesn't exist — permit records are never instantiated |
| GIS flags don't drive permit identification | `NEPA_Permit_Coordinator` only uses sector/type; ignores `nepa_nhd_proximity_flag__c`, `nepa_tribal_lands_flag__c`, `nepa_ec_usace_czma__c` |
| Only 9 of 25 permit matrix sectors covered | 16 `NEPA_Permit_Matrix__mdt` records missing from source |
| Missing federal authorizations don't affect risk score | `NEPA_Litigation_Risk_Scorer` has no permit gap penalty |
| Projects can advance to ROD/FONSI with uninitiated critical permits | `NEPA_Stage_Gate_Doc_Check` doesn't check cross-permit status |
| No SLA monitoring for cross-permit deadlines | No scheduled flow exists |

**Phases 4 (Construction Inspection) and 5 (O&M)** are out of scope — they belong to a separate asset management solution and would blur the accelerator's value proposition for federal lead agencies.

---

## Data Model Decision: `RegulatoryAuthorizationType` over custom CMT

The proposed `NEPA_Permit_Type_Catalog__mdt` (a custom metadata type as a permit lookup table) is **replaced** by the standard PSS `RegulatoryAuthorizationType` object already deployed and permissioned in this org.

**Why:**

- `RegulatoryAuthorizationType` is a standard PSS type catalog — exactly what a permit type library is
- It's already in the permission set and test factory; no new permissions needed
- Standard object means future PSS enhancements apply automatically
- Keeps custom metadata reserved for algorithmic configuration (weights, thresholds, SLA baselines) per ADR-004 intent

**What this means in practice:**

- `nepa_required_permit__c.nepa_permit_type__c` changes from a restricted Picklist → **Lookup(`RegulatoryAuthorizationType`)**
- `RegulatoryAuthorizationType` records are seeded as demo data (one per permit type) rather than CMT records
- Custom fields on `RegulatoryAuthorizationType` carry per-type configuration: `nepa_is_critical_path__c`, `nepa_default_lead_agency__c`, `nepa_statutory_deadline_days__c`, `nepa_gis_trigger_layer__c`

**What the three PSS objects are and aren't:**

| Object | What it is | Can replace `nepa_required_permit__c`? |
|---|---|---|
| `RegulatoryAuthorizationType` | Type catalog (kinds of authorizations) | No — it's a type, not an instance per process |
| `BusRegAuthorizationType` | Junction between `BusinessLicenseApplicationType` and `RegulatoryAuthorizationType` | No — parent requires `BusinessLicenseApplicationType`, incompatible with `IndividualApplication` |
| `BusRegAuthTypeDependency` | Type-to-type sequencing (A before B) | No — dependency graph between types, not instance tracking |

`nepa_required_permit__c` as a MasterDetail child of `IndividualApplication` remains the correct pattern. Nothing in PSS standard objects fills the "one instance record per process per required permit" role.

---

## Tier 1 — Schema Foundation

*Unblocks all downstream flow and scoring work.*

### 1a. Pull `nepa_required_permit__c` field definitions into source

Fields are deployed in-org but absent from source control. Create `.field-meta.xml` files for each field currently referenced in `NepaAgencyPermitService.cls`:

- `nepa_permit_type__c` — **Change from Picklist to Lookup(`RegulatoryAuthorizationType`)**
- `nepa_lead_agency__c` — Picklist (BLM, EPA, FERC, SHPO, USACE, USFWS, Other)
- `nepa_external_federal_id__c` — Text(36), ExternalId
- `nepa_agency_endpoint_key__c` — Text(40)
- `nepa_permit_status__c` — Picklist: Not Started / Under Review / Issued / Denied / Withdrawn
- `nepa_expected_completion__c` — Date
- `nepa_actual_completion__c` — Date
- `nepa_is_critical_path__c` — Checkbox, default false
- `nepa_regulatory_citation__c` — Text(80)
- `nepa_agency_system_url__c` — URL
- `nepa_last_synced__c` — DateTime
- `nepa_process__c` — MasterDetail → IndividualApplication (required for rollup in 1c)

Also create `nepa_required_permit__c.object-meta.xml` at the object root.

### 1b. Add 5 new lifecycle fields to `nepa_required_permit__c`

| Field | Type | Purpose |
|---|---|---|
| `nepa_statutory_deadline_days__c` | Number(4,0) | Days from IA start to permit deadline; populated at record creation from `RegulatoryAuthorizationType.nepa_statutory_deadline_days__c` |
| `nepa_sla_due_date__c` | Date | IA start date + statutory deadline days |
| `nepa_sla_overdue__c` | Formula Checkbox | `nepa_sla_due_date__c < TODAY() && NOT(ISPICKVAL(nepa_permit_status__c,'Issued')) && NOT(ISPICKVAL(...'Denied')) && NOT(ISPICKVAL(...'Withdrawn'))` |
| `nepa_nepa_stage_gate__c` | Picklist | NEPA stage at which permit must be initiated: `Scoping; Draft EA/EIS; Final EA/EIS; ROD/FONSI; Pre-Application; Any` |
| `nepa_permit_notes__c` | LongTextArea(2000) | Coordination history; writable by flow and Agentforce permit coordinator action |

### 1c. Add rollup summary to `IndividualApplication`

**Field:** `nepa_blocked_permit_count__c` — Rollup Summary COUNT on `nepa_required_permit__c` where `nepa_is_critical_path__c = true AND nepa_permit_status__c NOT IN (Issued, Denied, Withdrawn)`

**File:** `force-app/main/default/objects/IndividualApplication/fields/nepa_blocked_permit_count__c.field-meta.xml`

**Why this approach:** When a permit flips to Issued, the rollup recalculates and the IA field changes, which re-fires the existing `NEPA_Litigation_Risk_Scorer` trigger — no child-record trigger architecture needed.

### 1d. Add 2 fields to `NEPA_Permit_Matrix__mdt`

**Files:** `force-app/main/default/objects/NEPA_Permit_Matrix__mdt/fields/`

- **`GIS_Trigger_Layers__c`** — Text(255), DeveloperControlled — semicolon-delimited GIS layer keys that trigger this permit type regardless of sector/type match (e.g., `NHD; WETLAND; COASTAL; TRIBAL_LANDS`). Update all 9 existing records with appropriate values.
- **`Initiation_Gate__c`** — Picklist, DeveloperControlled — same values as `nepa_nepa_stage_gate__c` above.

### 1e. Add 4 custom fields to `RegulatoryAuthorizationType`

**Files:** `force-app/main/default/objects/RegulatoryAuthorizationType/fields/`

| Field | Type | Purpose |
|---|---|---|
| `nepa_is_critical_path__c` | Checkbox | Whether this authorization type blocks process advancement |
| `nepa_default_lead_agency__c` | Text(40) | Default issuing agency abbreviation |
| `nepa_statutory_deadline_days__c` | Number(4,0) | Default statutory deadline in calendar days |
| `nepa_gis_trigger_layer__c` | Text(100) | GIS layer key that independently triggers this type (e.g., `NHD` for CWA 404) |

### 1f. Seed `RegulatoryAuthorizationType` demo data records

Seed 20 records (one per permit type) covering at minimum:

| Name / Code | Lead Agency | Critical Path | GIS Trigger | Deadline Days |
|---|---|---|---|---|
| CWA Section 404 Permit | USACE | true | NHD | 60 |
| CWA Section 401 Water Quality Certification | State Agency | false | NHD | 60 |
| ESA Section 7 Informal Consultation | USFWS | true | CRITICAL_HABITAT | 135 |
| ESA Section 7 Formal Consultation | USFWS | true | CRITICAL_HABITAT | 135 |
| NHPA Section 106 Consultation | SHPO | true | TRIBAL_LANDS | 90 |
| CZMA Federal Consistency Determination | State CZM | false | COASTAL | 180 |
| FERC Section 7(c) Certificate | FERC | true | — | 365 |
| FLPMA Title V ROW Grant | BLM | false | — | 180 |
| Clean Air Act General Conformity | EPA | false | — | 90 |
| Clean Air Act NSR/PSD | EPA | false | — | 180 |
| Rivers and Harbors Act Section 10 | USACE | false | NHD | 60 |
| RCRA Permit | EPA | false | — | 270 |
| ESA Section 10 Incidental Take Permit | USFWS | false | CRITICAL_HABITAT | 365 |
| MBTA Consultation | USFWS | false | — | 60 |
| NRC Construction/Operating License | NRC | true | — | 730 |
| Grazing Permit (43 CFR 4130) | BLM | false | — | 180 |
| SDWA UIC Permit | EPA | false | — | 180 |
| Section 4(f) Evaluation | DOT | false | — | 90 |
| MPRSA Section 103 | USACE | false | COASTAL | 60 |
| STB Construction Authority | STB | true | — | 365 |

---

## Tier 2 — Record Creator Flow + Matrix Expansion

### 2a. New flow: `NEPA_Permit_Record_Creator`

**File:** `force-app/main/default/flows/NEPA_Permit_Record_Creator.flow-meta.xml`

**Trigger:** After-save `AsyncAfterCommit` on `IndividualApplication`. Entry condition: `nepa_co_permits_required__c` IsChanged = true AND IsNull = false.

**Logic:**
1. Get the IA record and its GIS flags (`nepa_nhd_proximity_flag__c`, `nepa_tribal_lands_flag__c`, `nepa_ec_usace_czma__c`) and `nepa_start_date__c`.
2. Get the parent `Program` sector and project type.
3. Delete existing `nepa_required_permit__c` children where `nepa_permit_status__c = 'Not Started'` (safe re-run on review-type change; preserves in-progress/issued permits).
4. Query active `NEPA_Permit_Matrix__mdt` rows matching Sector + ProjectType.
5. For each matrix row, query `RegulatoryAuthorizationType` records matching the permit labels in `Required_Permits__c`. Build a `nepa_required_permit__c` record for each, populated from the `RegulatoryAuthorizationType` fields (`nepa_is_critical_path__c`, `nepa_default_lead_agency__c`, `nepa_statutory_deadline_days__c`, `Initiation_Gate__c`).
6. **GIS bridge** — regardless of matrix match, if:
   - `nepa_nhd_proximity_flag__c = true` → ensure CWA Section 404 in collection
   - `nepa_tribal_lands_flag__c = true` → ensure NHPA Section 106 in collection
   - `nepa_ec_usace_czma__c = true` → ensure CZMA Federal Consistency in collection
   
   Look up each via `RegulatoryAuthorizationType.nepa_gis_trigger_layer__c` to get structured field values.
7. Set `nepa_sla_due_date__c` = IA `nepa_start_date__c` + `nepa_statutory_deadline_days__c` on each record.
8. Single bulk `Create Records` on the collection (no DML in loop).
9. Fault connector → `NEPA_Error_Logger` subflow (ADR-003 standard).

### 2b. Update `NEPA_Permit_Coordinator` — GIS augmentation

**File:** `force-app/main/default/flows/NEPA_Permit_Coordinator.flow-meta.xml`

Add after `Get_ParentProgram`:

1. New `recordLookups` element `Get_CurrentIA` — reads `nepa_nhd_proximity_flag__c`, `nepa_tribal_lands_flag__c`, `nepa_ec_usace_czma__c` from the IA.
2. New `formulas` element `formula_GISAugmentedPermits`:
```
{!Call_NEPA_Permit_Lookup.RequiredPermits} &
IF({!Get_CurrentIA.nepa_nhd_proximity_flag__c} &&
   NOT(CONTAINS({!Call_NEPA_Permit_Lookup.RequiredPermits},"CWA Section 404")),
   "; CWA Section 404 Permit; CWA Section 401 Water Quality Certification", "") &
IF({!Get_CurrentIA.nepa_tribal_lands_flag__c} &&
   NOT(CONTAINS({!Call_NEPA_Permit_Lookup.RequiredPermits},"NHPA Section 106")),
   "; NHPA Section 106 Consultation", "") &
IF({!Get_CurrentIA.nepa_ec_usace_czma__c} &&
   NOT(CONTAINS({!Call_NEPA_Permit_Lookup.RequiredPermits},"CZMA")),
   "; CZMA Federal Consistency Determination", "")
```
3. Replace the `nepa_co_permits_required__c` assignment in `Update_IA_PermitFields` with `{!formula_GISAugmentedPermits}`.

`NEPA_Permit_Record_Creator` fires after `NEPA_Permit_Coordinator` writes the augmented string, so GIS-triggered permits flow naturally into record creation.

### 2c. Add 16 new `NEPA_Permit_Matrix__mdt` records

Source data: `data insights/3_permit_matrix.json` and `data insights/3_permit_matrix.csv`. Each record includes `GIS_Trigger_Layers__c` and `Initiation_Gate__c` from Tier 1d.

**Priority 1 (highest NEPATEC frequency):**
| File | Sector | Project Type |
|---|---|---|
| `NEPA_Permit_Matrix.Energy_Hydro_FERC.md-meta.xml` | Energy Production and Management | Hydropower/Pumped Storage |
| `NEPA_Permit_Matrix.Transportation_Bridge_FHWA.md-meta.xml` | Transportation and Infrastructure | Surface Transportation - Bridges |
| `NEPA_Permit_Matrix.Transportation_Port_USACE.md-meta.xml` | Transportation and Infrastructure | Ports and Waterways |
| `NEPA_Permit_Matrix.Agriculture_Forest_BLM.md-meta.xml` | Agriculture and Natural Resource Management | Land Use or Forest Management Plan |
| `NEPA_Permit_Matrix.Water_Irrigation_USBR.md-meta.xml` | Water and Waste Management | Water Resources - Irrigation |

**Priority 2:**
| File | Sector | Project Type |
|---|---|---|
| `NEPA_Permit_Matrix.Energy_Offshore_BOEM.md-meta.xml` | Energy | Offshore Oil & Gas |
| `NEPA_Permit_Matrix.Energy_OffshoreWind_BOEM.md-meta.xml` | Energy | Offshore Wind |
| `NEPA_Permit_Matrix.Energy_Nuclear_NRC.md-meta.xml` | Energy | Conventional Energy - Nuclear |
| `NEPA_Permit_Matrix.Energy_Geothermal_BLM.md-meta.xml` | Energy | Renewable - Geothermal |
| `NEPA_Permit_Matrix.Transportation_Rail_FRA.md-meta.xml` | Transportation | Surface Transportation - Railroads |
| `NEPA_Permit_Matrix.Transportation_Aviation_FAA.md-meta.xml` | Transportation | Aviation - Airports |
| `NEPA_Permit_Matrix.Materials_NonMetalMine_BLM.md-meta.xml` | Materials and Manufacturing | Mining - Non-Metallic Minerals |
| `NEPA_Permit_Matrix.Materials_Manufacturing_DOE.md-meta.xml` | Materials and Manufacturing | Manufacturing |
| `NEPA_Permit_Matrix.Water_NonNuclear_BLM.md-meta.xml` | Water and Waste Management | Waste Management - Non-Nuclear |
| `NEPA_Permit_Matrix.Water_Flood_USACE.md-meta.xml` | Water and Waste Management | Water Resources - Flood Risk |
| `NEPA_Permit_Matrix.Agriculture_Vegetation_USFS.md-meta.xml` | Agriculture | Vegetation and Fuels Management |

Also update the existing 9 records with `GIS_Trigger_Layers__c` and `Initiation_Gate__c` values.

---

## Tier 3 — Risk Scorer Integration

### 3a. Update `NEPA_Litigation_Risk_Scorer`

**File:** `force-app/main/default/flows/NEPA_Litigation_Risk_Scorer.flow-meta.xml`

**Trigger condition change:** Add `nepa_blocked_permit_count__c` IsChanged as an OR condition alongside the existing trigger filters. When a child permit is issued the rollup changes the IA field, re-firing this flow automatically.

**New permit gap penalty step** (insert before the BRE Expression Set call):

1. New variable `var_PermitGapPoints` (Number, scale 1, default 0).
2. New `decisions` element `Decision_PermitGapPenalty`:
   - `$Record.nepa_blocked_permit_count__c >= 3` → assign `var_PermitGapPoints` = 15
   - `$Record.nepa_blocked_permit_count__c >= 1` → assign `var_PermitGapPoints` = 8
   - Default → `var_PermitGapPoints` = 0
3. Pass `var_PermitGapPoints` to the BRE Expression Set as a new additive input — same pattern as the existing `ScopingOverrunMonths` penalty (added directly to composite score, outside the weighted formula).
4. Extend `formula_ScoreFactorsSummary` to append:
   ```
   IF({!var_PermitGapPoints} > 0,
     "; PERMIT GAP: " & TEXT({!$Record.nepa_blocked_permit_count__c}) &
     " critical-path permit(s) not yet Issued — +" & TEXT({!var_PermitGapPoints}) & "pts", "")
   ```

---

## Tier 4 — Stage Gate + SLA Monitor

### 4a. Update `NEPA_Stage_Gate_Doc_Check` — cross-permit check at ROD/FONSI

**File:** `force-app/main/default/flows/NEPA_Stage_Gate_Doc_Check.flow-meta.xml`

Add after the existing document check loop, **only when `inp_EventType` is `ROD` or `FONSI`**:

1. New `recordLookups` element `Get_UninitiatedCriticalPermits` — queries `nepa_required_permit__c` WHERE `nepa_process__c = inp_ProcessId AND nepa_is_critical_path__c = true AND nepa_permit_status__c = 'Not Started'`.
2. New `decisions` element `Decision_UninitiatedPermits` — if collection is non-null and non-empty, append to `var_MissingDocs`: `"Critical-path permit(s) not yet initiated: [count]. Initiate all critical-path federal authorizations before issuing ROD/FONSI."`.
3. The existing `Block_Save` error path handles non-empty `var_MissingDocs` — no additional error output needed.

**Why this matters:** A project that has not initiated ESA Section 7 consultation or a CWA 404 permit before issuing a ROD is the most common procedural defect that results in NEPA litigation. This gate enforces the procedural requirement declaratively.

### 4b. New scheduled flow: `NEPA_Permit_SLA_Monitor`

**File:** `force-app/main/default/flows/NEPA_Permit_SLA_Monitor.flow-meta.xml`

**Trigger:** Scheduled Flow, daily at 06:00 UTC.

**Logic:**
1. Get all `nepa_required_permit__c` WHERE `nepa_sla_due_date__c < TODAY() AND nepa_is_critical_path__c = true AND nepa_permit_status__c NOT IN ('Issued', 'Denied', 'Withdrawn')`. Limit 2000.
2. Loop: for each overdue permit, build a `Task` record in a collection variable:
   - `Subject` = `"Permit SLA Overdue: " + nepa_permit_type__r.Name`
   - `WhatId` = permit record Id
   - `OwnerId` = `nepa_process__r.OwnerId`
   - `Priority` = High, `Status` = Not Started
3. Single bulk `Create Records` on the Task collection — no per-record DML in loop.
4. `nepa_sla_overdue__c` is a formula field — this flow does **not** write back to permit records, only creates Tasks.
5. Fault connector → `NEPA_Error_Logger`.

---

## Phase B — Regulatory Code Preprocessing & AI Classification

*This section extends the Tier 1–4 implementation above into a full AI-driven permit identification architecture.*

### The approach

Rather than relying only on the `NEPA_Permit_Matrix__mdt` lookup table (sector × project type → permit list), the goal is to:

1. **Preprocess** environmental statutes into structured, machine-readable applicability conditions stored on `RegulatoryCode`
2. **Classify** incoming applications against those conditions — deterministically where attributes are known, via LLM reasoning for novel/ambiguous cases
3. **Validate** the classifier against the NEPATEC2.0 historical corpus before production use

### Source APIs for regulatory text

**regulations.gov is the wrong source for this.** It is a public comment and rulemaking docket system — it contains proposed and final rules as PDFs, public comments, and agency notices. It does not expose the codified regulatory text (the CFR) in a structured, queryable form. Use it only if you need the preamble reasoning behind a specific final rule (the "why" behind a threshold, useful for LLM context), but not as the primary text source.

The correct sources, in priority order:

| Source | What it provides | API key required | Best use |
|---|---|---|---|
| **eCFR API** (`ecfr.gov/api/versioner/v1/full/`) | Full text of any CFR part as structured XML, current and historical, no key required | No | Primary source — fetch every relevant CFR part directly |
| **GovInfo API** (`api.govinfo.gov`) | Full CFR, USC statutes, and Federal Register; bulk ZIP downloads | Yes (free registration) | USC statutory text (e.g., 33 USC 1344); FR preambles for threshold reasoning |
| **regulations.gov API** (`api.regulations.gov`) | Rulemaking dockets, final rule PDFs, public comments | Yes (you have a key) | Secondary — preamble text for ambiguous thresholds only |

**eCFR is the primary source.** It returns complete, structured XML for any CFR part at any date, with no authentication. Verified working endpoints for the statutes in the flowchart:

```
# CWA Section 404 — USACE dredge and fill permits
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-33.xml?part=323
# → 31.5 KB, 6 complete sections, 33 U.S.C. 1344 authority

# ESA Section 7 — interagency consultation
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-50.xml?part=402
# → 95.8 KB, 30 complete sections including all definitions

# NHPA Section 106 — historic properties
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-36.xml?part=800
# → 115.5 KB, 16 sections + Appendix A

# CZMA Federal Consistency
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-15.xml?part=930

# Clean Air Act General Conformity
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-40.xml?part=93

# CWA Section 401 — water quality certification
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-40.xml?part=121

# Rivers and Harbors Act Section 10
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-33.xml?part=322

# CWA Section 404(b)(1) guidelines (the substantive test)
GET https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-40.xml?part=230
```

**GovInfo** is needed only for USC statutory text (the organic statute, not the implementing regulations) and Federal Register preambles. For the extraction pipeline, the CFR implementing regulations are more useful than the USC statute text — they contain the operational definitions and thresholds the classifier needs. Use GovInfo selectively for ambiguous threshold cases where the FR preamble provides interpretive context (e.g., what "waters of the United States" means after the Sackett v. EPA 2023 decision).

**The regulations.gov API key you have** is useful for one specific task: pulling the final rule PDF for a specific rulemaking to extract the preamble discussion of how a threshold was set. The endpoint for this is `GET https://api.regulations.gov/v4/documents?filter[documentType]=Rule&filter[agencyId]=EPA&api_key={YOUR_KEY}`. Store the key in a Named Credential in Salesforce or as an environment variable in the extraction script — do not commit it to source control.

### Regulatory code preprocessing

Each statute in the flowchart (CWA 404, ESA Section 7, NHPA 106, CZMA, etc.) gets decomposed into discrete applicability predicates on a child object `nepa_applicability_condition__c`:

```
nepa_applicability_condition__c
  ├── nepa_regulatory_code__c      → MasterDetail to RegulatoryCode
  ├── nepa_condition_type__c       → Picklist: Activity | Jurisdiction | Threshold | Species | GIS
  ├── nepa_condition_attribute__c  → Text: attribute tested (e.g., "project_sector")
  ├── nepa_condition_operator__c   → Picklist: EqualTo | Contains | GreaterThan | Intersects | IsTrue
  ├── nepa_condition_value__c      → Text: trigger value (e.g., "Transportation and Infrastructure")
  ├── nepa_threshold_value__c      → Number: for threshold conditions (e.g., 0.5 acres)
  ├── nepa_logic_group__c          → Text: AND/OR group label (e.g., "A", "B")
  ├── nepa_logic_expression__c     → Text on parent RegulatoryCode: e.g., "(A AND B) OR C"
  └── nepa_gis_layer_key__c        → Text: maps to NEPA_GIS_Layer__mdt when type = GIS
```

The extraction pipeline fetches CFR full text from the eCFR API, passes it to Claude API batch processing to extract applicability conditions as JSON, and loads the results into `RegulatoryCode.nepa_text_content__c` (the raw text for RAG) and `nepa_applicability_condition__c` records (the structured predicate layer). The prose text is retained for LLM RAG reasoning; the condition records are the deterministic evaluation layer.

**Extraction script:** `scripts/fetch_regulatory_text.py` — fetches from eCFR, calls Claude API for structured extraction, outputs JSONL for Salesforce bulk load. See `scripts/validate_permit_classifier.py` for the companion validation script.

### Two-track classification at intake

**Track A — Deterministic (BRE/Flow):** A new Expression Set evaluates all active `RegulatoryCode` applicability conditions against the IA's known attributes (sector, project type, acreage, GIS flags). Returns matching `RegulatoryCode` IDs. Fast, auditable, no LLM cost.

**Track B — LLM reasoning (Agentforce):** For ambiguous cases, threshold-boundary projects, or novel project types not covered by Track A, an Agentforce action retrieves the top-K most relevant `RegulatoryCode` records via vector similarity on `nepa_text_content__c` and reasons about applicability against the project description. Returns structured output:
```json
{
  "applicable_codes": [
    { "code_id": "...", "confidence": 0.94, "rationale": "Project involves fill of wetland adjacent to NHD waterway" }
  ],
  "human_review_recommended": true,
  "review_reason": "Threshold borderline — 4.8 acres fill, CWA NWP 39 limit is 0.5 acres"
}
```

The agent output feeds `NEPA_Permit_Record_Creator` — Agentforce classifies, Flow creates records. Human review flag routes to NEPA coordinator queue.

### Synthesis: regulatory codes → permit instances

A new junction record type links `RegulatoryCode` → `RegulatoryAuthorizationType` (many-to-one, since multiple provisions may require the same permit type). The synthesis flow deduplicates by `RegulatoryAuthorizationType` and captures all triggering codes in `nepa_permit_notes__c`.

---

## Phase C — NEPATEC2.0 Validation Corpus

### What the corpus contains

The NEPATEC2.0 dataset at `../nepadata/NEPATEC2.0/` (relative to this repo) is the ground truth for validating the classifier. Key statistics:

| Metric | Value |
|---|---|
| Total records | 61,881 |
| Review types | CE, EA, EIS |
| Agencies | BLM, DOE, USDA, EPA |
| Records with lat/lon coordinates | 7,166 (11.6%) |
| Records with permit references in document text | 29,575 (47.8%) |
| Records with cooperating agency mentions | 3,955 (6.4%) |

**Directory structure:** `NEPATEC2.0/{CE,EA,EIS}/{BLM,DOE,USDA,EPA}/nepatec2_{type}_{agency}_{NNN}.jsonl`

**Record schema per line:**
```
project:
  project_ID, project_title, project_sector[], project_type[], project_sponsor[], location[]
process:
  process_family, process_type (CE | EA | EIS), lead_agency[]
documents[]:
  metadata: document_type, document_title, prepared_by, file_name, total_pages
  pages[]: page_number, page_text
```

Permit references are embedded in `page_text` — they are not pre-extracted. The validation pipeline must extract the "ground truth" permit set from the document text and compare it against the classifier's predicted permit set.

**Sector distribution across the corpus:**

| Sector | Records |
|---|---|
| Transportation and Infrastructure | 28,207 |
| Water and Waste Management | 27,797 |
| Miscellaneous and Emerging Technologies | 20,906 |
| Energy Production and Management | 20,275 |
| Land Development and Urban Planning | 19,037 |
| Agriculture and Natural Resource Management | 16,505 |
| Materials and Manufacturing | 6,765 |
| Others | ~8,000 |

### Validation methodology

This is a **held-out retrospective evaluation**: the classifier is run against historical project inputs and its predicted permit set is compared against the permits actually referenced in the completed NEPA documents. Because the permits were already required (and documented), there is a recoverable ground truth.

**Step 1 — Ground truth extraction (offline, Claude API batch)**

For each record in the validation set, extract the permit set from the document page text:

```python
# Pseudo-code for batch extraction
for record in nepatec2_corpus:
    prompt = f"""
    From the following NEPA document text, extract all federal permits and authorizations
    required or obtained for this project. Return as JSON:
    {{ "permits": [{{ "name": "...", "statute": "...", "agency": "..." }}] }}
    
    Document text: {page_text[:8000]}
    """
    ground_truth[record.project_ID] = claude_api.extract(prompt)
```

Records with `has_permit_refs = true` (the 29,575 subset) are the primary validation set. Records with lat/lon (7,166) enable GIS-aware validation.

**Step 2 — Classifier prediction**

For each record, run the Track A deterministic classifier using the record's `project_sector`, `project_type`, and (where available) location-derived GIS flags as inputs. For the GIS-aware subset, geocode the lat/lon against the same layer definitions used in `NEPA_GIS_Proximity_Check`.

**Step 3 — Metric computation**

| Metric | Definition | Target |
|---|---|---|
| Precision | Predicted permits that were actually required ÷ all predicted | ≥ 0.80 |
| Recall | Required permits correctly predicted ÷ all required | ≥ 0.75 |
| F1 | Harmonic mean of precision and recall | ≥ 0.77 |
| False negative rate | Critical-path permits missed by classifier | ≤ 0.10 |
| GIS lift | Recall improvement when GIS flags are included | Report as delta |

False negatives (missed required permits) are weighted more heavily than false positives because missing a required CWA 404 has worse downstream consequences than over-predicting an unnecessary permit.

**Step 4 — Stratified analysis**

Break down metrics by:
- Review type (CE vs. EA vs. EIS) — CE records likely have fewer permits; EIS records are the stress test
- Sector — Transportation and Energy are the largest and most complex
- Agency — BLM, DOE, USDA, EPA have different permit profiles
- GIS-available vs. location-text-only — quantifies how much GIS improves recall

**Step 5 — Confidence calibration**

For Track B (LLM predictions), compare the model's stated confidence against actual precision at each confidence band (0.9+, 0.7–0.9, below 0.7). Well-calibrated confidence scores are required before the `human_review_recommended` threshold can be set to a defensible value.

### What "increasing confidence levels" means in practice

Correct: validation against NEPATEC2.0 increases confidence that the classifier generalizes to new applications — but with important caveats:

1. **Scope match:** NEPATEC2.0 is CE/EA/EIS for BLM, DOE, USDA, and EPA. It does not cover FERC, FHWA, NRC, or USACE as lead agencies. Validation results are directly applicable to those four agency types; extrapolation to FERC pipelines or FHWA highways requires separate validation or expert review.

2. **Permit extraction quality:** Ground truth is extracted from document text by an LLM, not pre-labeled by humans. Any extraction errors propagate into the metrics. The validation set should be spot-checked: manually verify ~100 records across sectors to confirm the ground truth extraction is accurate before trusting aggregate metrics.

3. **Temporal distribution:** NEPATEC2.0 covers historical projects. If regulatory thresholds or permit requirements have changed since those projects were completed, the classifier trained on this corpus may underpredict newly applicable requirements. Flag records by decade and track metric drift.

4. **CE records as a calibration check:** CE records (90 records across BLM/DOE/USDA) should have low permit counts — primarily ESA Section 7 and NHPA 106 as extraordinary circumstance checks, not the full CWA 404 suite. If the classifier predicts a full EIS-level permit set for CE records, it is over-predicting.

### Validation tooling

The validation pipeline is an offline Python script (not Salesforce code) that:

1. Reads JSONL files from `../nepadata/NEPATEC2.0/`
2. Calls the ground truth extraction via Claude API (`claude-opus-4-7` for quality, batch mode for cost)
3. Runs the deterministic classifier logic (ported from Flow/BRE to Python for batch execution)
4. Computes metrics and outputs a report to `docs/data/validation_results.json`

The report feeds back into `NEPA_Risk_Threshold__mdt` — specifically, the `confidence_floor__c` value used by Track B to set the `human_review_recommended` flag threshold.

**File:** `scripts/validate_permit_classifier.py` (to be created in Phase C)

---

## Implementation Sequence

**Phase A — Tiers 1–4 (immediate, pre-June 2)**

| Phase | Work | Target days |
|---|---|---|
| **Tier 1** | Schema: field XML, 5 lifecycle fields, rollup summary, CMT fields, `RegulatoryAuthorizationType` fields + seed data | Days 1–3 |
| **Tier 2a** | `NEPA_Permit_Record_Creator` flow | Days 4–5 |
| **Tier 2b** | `NEPA_Permit_Coordinator` GIS augmentation | Day 5 |
| **Tier 2c** | 5 Priority 1 CMT records + update 9 existing with GIS/gate fields | Days 6–7 |
| **Tier 3** | `NEPA_Litigation_Risk_Scorer` trigger + permit gap penalty | Days 8–9 |
| **Tier 4a** | `NEPA_Stage_Gate_Doc_Check` ROD/FONSI permit gate | Day 9 |
| **Tier 4b** | `NEPA_Permit_SLA_Monitor` scheduled flow | Day 10 |
| **Remaining** | 11 Priority 2 CMT records, integration test, demo story update | Days 11–13 |
| **Buffer** | Final deploy, smoke test on demo scenario | Day 14 |

**Phase B — Regulatory code preprocessing (post-June 2, ~3 weeks)**

| Phase | Work |
|---|---|
| **B1** | Create `nepa_applicability_condition__c` object + fields; deploy to org |
| **B2** | Write `scripts/fetch_regulatory_text.py` — fetch ~40 CFR parts from eCFR API, run Claude API batch extraction, output JSONL; legal review of extracted conditions |
| **B3** | Bulk load JSONL into `RegulatoryCode` + `nepa_applicability_condition__c` records; build Track A BRE classifier; store regulations.gov API key as Named Credential for preamble lookups |
| **B4** | Build Agentforce Track B topic + action for ambiguous classifications |

**Phase C — NEPATEC2.0 validation (parallel with B2–B3, ~2 weeks)**

| Phase | Work |
|---|---|
| **C1** | Write `scripts/validate_permit_classifier.py`; extract ground truth from 29,575 permit-bearing records |
| **C2** | Run classifier against full corpus; compute precision/recall/F1 stratified by sector and review type |
| **C3** | Calibrate Track B confidence thresholds against validation results; update `NEPA_Risk_Threshold__mdt` |
| **C4** | Publish validation report to `docs/data/validation_results.json`; document known gaps |

---

## Phase D — PIC Permitting Inventory Integration

*Prioritized by impact on submission narrative. The full Airtable inventory (60+ tools) requires an authenticated browser session; the four actionable items below are from the accessible EPIC ecosystem.*

### Priority 1 — Wetlands Impact Tracker data (EPIC / Atlas Public Policy)

**Source:** `climateprogramportal.org/wetlands-impact-tracker/` → "Download Data" (AWS S3, Open Data Commons Attribution License, no auth required)

**What it contains:** 6,000+ USACE CWA Section 404 public notices (2012–present, all 34 districts); final permit data 2015–2023. Fields: USACE district, permit type (standard / nationwide / RGP / LOP), project sector, location (lat/lon + county), date submitted, date decided, status.

**Three concrete uses:**

1. **Demo data for `nepa_required_permit__c`** — map Wetlands Impact Tracker records to permit fields (`nepa_lead_agency__c` = USACE, `nepa_permit_type__c` = CWA Section 404, `nepa_regulatory_citation__c` = 33 USC 1344) and load as demo seed data. The `nepaPermitDependencies` LWC will show real USACE notice data instead of synthetic records.

2. **Empirical USACE processing time baseline** — compute median days from submission to decision by district and permit type from the dataset. Update `NEPA_Agency_Duration_Cost__mdt` USACE records with these empirical values, replacing the PermitTEC-derived synthetic estimates. This is a direct data quality improvement claimable in the submission.

3. **Phase C classifier validation** — cross-reference Wetlands Impact Tracker records with NEPATEC2.0 corpus records that contain CWA 404 references to tighten the precision/recall baseline for the CWA 404 trigger condition specifically.

**Narrative update:** Under MFR #7 (cross-agency coordination) in `docs/SUBMISSION-NARRATIVE.md`, cite Wetlands Impact Tracker as the empirical source for USACE CWA 404 processing time baselines and note conceptual interoperability with the tracker's public notice data model.

---

### Priority 2 — OpenWetlandsMap as 6th GIS layer (EPIC / OpenStreetMap US)

**Source:** OpenStreetMap-standard community wetlands dataset, pilot phase, 50+ partners. Addresses the NWI currency gap — National Wetlands Inventory was last systematically updated in the 1970s–80s.

**Why accuracy matters:** NHD (the current 5th GIS layer) detects waterways, not wetland extent. CWA 404 triggers on wetlands, not just proximate waterways. A project near a river but outside any mapped wetland boundary should not trigger a 404 permit record; one near a mapped wetland should even without NHD intersection. Adding OpenWetlandsMap reduces both false positives and false negatives for the CWA 404 trigger.

**Technical work:**

1. Add `NEPA_GIS_Layer__mdt` record: `DeveloperName = OpenWetlandsMap`, `Layer_URL__c` = OSM Overpass API endpoint for wetland features, `Extraordinary_Circumstance_Flag__c = nepa_wetlands_flag__c`
2. Add `nepa_wetlands_flag__c` Checkbox field to `IndividualApplication` — file: `force-app/main/default/objects/IndividualApplication/fields/nepa_wetlands_flag__c.field-meta.xml`
3. Update `NEPA_GIS_Proximity_Check` flow — add a new GIS callout step for this layer, set `nepa_wetlands_flag__c` on the IA
4. Update `NEPA_Permit_Coordinator` GIS augmentation formula (Tier 2b) — add `nepa_wetlands_flag__c = true` as a parallel CWA 404 trigger alongside `nepa_nhd_proximity_flag__c`
5. Update `NEPA_Permit_Record_Creator` GIS bridge (Tier 2a) — check `nepa_wetlands_flag__c` in addition to NHD flag when ensuring CWA 404 is in the collection

**Key constraint:** OpenWetlandsMap is in pilot phase; coverage is incomplete. The flow must treat `wetlands_flag = false` as "no mapped wetland found" — not "no wetland present." The NHD proximity check must remain a parallel, independent trigger. Graceful degradation (ADR-013 pattern): if the OSM endpoint is unavailable, log a coordinator Task and continue without blocking intake.

**Narrative update:** Change "5 GIS services" to "6 GIS services" in `docs/SUBMISSION-NARRATIVE.md` MFR #5; add a note that the sixth layer addresses the NWI currency gap using community-sourced wetlands data.

---

### Priority 3 — EPIC "Nine Types of Permitting Reform" — Narrative alignment

**What it is:** EPIC's own framework for categorizing permitting reform. PIC evaluators authored and use this taxonomy.

**No technical work required.** Add one paragraph (4–5 sentences) to the Solution Abstract section of `docs/SUBMISSION-NARRATIVE.md` mapping the accelerator's capabilities to the relevant Nine Types:

| Nine Types category | Accelerator capabilities |
|---|---|
| Faster Government | Stage gates, SLA monitoring, scoping overrun detection, per-agency baseline timelines |
| Technology | Agentforce AI comment triage, BRE CE screening, GIS proximity at intake |
| Unlocking Finance | Cross-permit critical-path identification reduces time-to-permit, directly shortening financing close timelines |
| Supporting Communities | Unconditional EJ/tribal sovereignty comment gate, E.O. 13175 tracking, tribal consultation flag |

Framing the solution in EPIC's own language signals to evaluators that the design was intentional — not incidentally aligned.

---

### Priority 4 — EPIC Restoration Permitting Database — Matrix gap data

**Source:** `policyinnovation.org/restoration/database` — quarterly-updated database of permitting innovations for ecological restoration projects, local/state/federal.

**Work required:** Manual review (< 2 hours) of the restoration database for permit sequences in Agriculture / Forest Management and Vegetation Management sectors — the two most restoration-relevant rows among the 16 missing `NEPA_Permit_Matrix__mdt` records. Extract sector/agency combinations and permit sequences not already in `data insights/3_permit_matrix.json`. Feeds Tier 2c matrix expansion work with real precedent rather than synthetic data.

No new technical scope — this is a data-gathering step before writing the CMT XML.

---

### What NOT to incorporate

| Tool | Reason |
|---|---|
| Virginia PEEP / VPT | State-only system; not integrable; pattern reference only — ADR already chose the cross-agency callout approach |
| FPISC dashboard (permits.performance.gov) | Returns HTTP 403; not publicly accessible |
| EPA Lead / Water tools | Unrelated to NEPA permitting |
| EPIC Drinking Water Explorer | Unrelated |
| CEJST, EJScreen, CDC EJ Index | Already integrated in GIS proximity check |

---

### Submission narrative change summary (all priorities)

| Location in `docs/SUBMISSION-NARRATIVE.md` | Change |
|---|---|
| Solution Abstract | Add paragraph mapping to EPIC Nine Types framework (Priority 3) |
| MFR #5 (GIS intake) | "5 GIS services" → "6 GIS services"; note OpenWetlandsMap wetlands layer + NWI gap rationale (Priority 2) |
| MFR #7 (cross-agency coordination) | Add Wetlands Impact Tracker citation as empirical source for USACE CWA 404 processing baselines (Priority 1) |
| Datasets Used | Add: Wetlands Impact Tracker (EPIC/Atlas Public Policy) and OpenWetlandsMap (EPIC/OSM US) |

---

## Phase E — ArcGIS Endpoint Integration (Submission Narrative + GIS Trigger Expansion)

**Goal:** Replace or supplement the 5 existing GIS layers with validated federal ArcGIS REST endpoints that directly trigger permit identification. Expands the submission narrative claim from "5 GIS services" to "12 GIS services" and closes permit trigger gaps for CWA 404 (wetlands), NHPA Section 106 (historic properties), Clean Air Act general conformity, RCRA/hazardous waste, Rivers & Harbors Act, BLM extraordinary circumstances, and E.O. 13175 tribal consultation.

### Existing GIS Layers (pre-Phase E)

| Layer Key | Source | Permit Triggered |
|---|---|---|
| `CRITICAL_HABITAT` | FWS ECOS (web app) | ESA Section 7 |
| `EJSCREEN` | EPA EJScreen | EJ extraordinary circumstances |
| `NHD` | USGS NHD | CWA Section 404 (waterways, not wetland extent) |
| `TRIBAL_CADASTRAL` | BLM tribal cadastral | E.O. 13175 tribal consultation |
| `CZMA` / `COASTAL` | NOAA coastal zone boundary | CZMA Federal Consistency |

### Validated New Endpoints (tested 2026-05-19)

All endpoints verified by HTTP request with `?f=json` returning `esriGeometry*` response.

| Priority | Layer Key | Service URL | Geometry | Permit Triggered | Replaces/Augments |
|---|---|---|---|---|---|
| 1 | `NWI_WETLANDS` | `https://fwspublicservices.wim.usgs.gov/wetlandsmapservice/rest/services/Wetlands/MapServer/0` | Polygon | CWA Section 404 — wetland extent (closes NHD gap) | Augments NHD |
| 2 | `CRITICAL_HABITAT_GIS` | `https://services.arcgis.com/QVENGdaPbd4LUkLV/ArcGIS/rest/services/USFWS_Critical_Habitat/FeatureServer/0` | Polygon | ESA Section 7 — spatial footprint query | Replaces ECOS web scrape |
| 3 | `EPA_AIR_NONATTAINMENT` | `https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/Nonattainment_Areas_and_Designations/FeatureServer/2` | Polygon | Clean Air Act General Conformity (ozone 2015) | New trigger |
| 4 | `EPA_TRIBAL_LANDS` | `https://geopub.epa.gov/arcgis/rest/services/EMEF/tribal/MapServer/2` | Polygon | E.O. 13175 tribal consultation — American Indian Reservations | Augments BLM tribal cadastral |
| 5 | `FEMA_FLOOD` | `https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Flood_Hazard_Reduced_Set_gdb/FeatureServer/0` | Polygon | CWA 404 floodplain; CZMA coastal; Section 404(b)(1) alternatives | New trigger |
| 6 | `BLM_ACEC` | `https://services1.arcgis.com/IAQQkLXctKHrf8Av/ArcGIS/rest/services/Area_of_Critical_Environmental_Concern/FeatureServer/0` | Polygon | BLM extraordinary circumstances; FLPMA Title V ROW | New trigger |
| 7 | `WILD_SCENIC_RIVERS` | `https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_WildScenicRiverSegments_01/MapServer/1` | Polyline | Wild & Scenic Rivers Act; Rivers & Harbors Act Section 10 | New trigger |
| 8 | `USACE_FUDS` | `https://services7.arcgis.com/n1YM8pTrFmm7L4hs/ArcGIS/rest/services/fuds/FeatureServer/3` | Polygon | RCRA/CERCLA hazardous waste review; Army FUDS munitions response | New trigger |

### Endpoints Tested But Not Valid

| Endpoint Tested | Result | Disposition |
|---|---|---|
| `fws.gov/wetlands/arcgis/rest/services/Wetlands/MapServer/0` | 503 Service Unavailable | Replaced with `fwspublicservices.wim.usgs.gov` mirror (USGS-hosted NWI) |
| `fws.gov/wetlands/arcgis/rest/services/Riparian/MapServer/0` | 503 Service Unavailable | Coverage addressed by NWI Wetlands layer (includes riparian) |
| `mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/1` | 500 Service not started | No live ArcGIS REST endpoint found for NRHP; use NPS NRHP bulk data download for demo seed data |
| `hazards.fema.gov/gis/nfhl/rest/services/public/NFHL/MapServer/28` | 404 | Replaced with ESRI-hosted `USA_Flood_Hazard_Reduced_Set_gdb/FeatureServer/0` |
| `geopub.epa.gov/arcgis/rest/services/EMEF/tribal/MapServer/4` | 200 but wrong layer (Oklahoma Tribal Statistical Areas) | Corrected to layer 2 (American Indian Reservations) |

### Implementation Work Required

#### E1. New `NEPA_GIS_Layer__mdt` records (8 records)

Create one CMT record per validated endpoint above. Each record follows the existing pattern:

```xml
<!-- example: NWI_WETLANDS -->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>NWI Wetlands (FWS/USGS)</label>
    <protected>false</protected>
    <values>
        <field>Layer_URL__c</field>
        <value xsi:type="xsd:string">https://fwspublicservices.wim.usgs.gov/wetlandsmapservice/rest/services/Wetlands/MapServer/0</value>
    </values>
    <values>
        <field>Extraordinary_Circumstance_Flag__c</field>
        <value xsi:type="xsd:string">nepa_wetlands_flag__c</value>
    </values>
    <values>
        <field>Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
```

Files:
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.NWI_Wetlands.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.Critical_Habitat_GIS.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.EPA_Air_Nonattainment.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.EPA_Tribal_Lands.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.FEMA_Flood.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.BLM_ACEC.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.Wild_Scenic_Rivers.md-meta.xml`
- `force-app/main/default/customMetadata/NEPA_GIS_Layer.USACE_FUDS.md-meta.xml`

#### E2. New checkbox fields on `IndividualApplication`

| Field API name | Purpose | Permit gate |
|---|---|---|
| `nepa_wetlands_flag__c` | NWI wetland polygon intersection | CWA 404 trigger; supersedes NHD-only logic |
| `nepa_air_nonattainment_flag__c` | EPA ozone nonattainment area | Clean Air Act General Conformity trigger |
| `nepa_fema_flood_flag__c` | FEMA special flood hazard area | Floodplain permit / 404(b)(1) alternatives analysis |
| `nepa_blm_acec_flag__c` | BLM Area of Critical Environmental Concern | FLPMA extraordinary circumstances |
| `nepa_wild_scenic_river_flag__c` | Wild & Scenic River corridor | Wild & Scenic Rivers Act; R&H Act Section 10 |
| `nepa_fuds_flag__c` | USACE FUDS munitions response site | RCRA/CERCLA review trigger |

Files: `force-app/main/default/objects/IndividualApplication/fields/<field>.field-meta.xml` (6 files)

#### E3. Update `NEPA_GIS_Proximity_Check` flow

Add one `httpCallOut` + `decisions` + `assignments` block per new layer, following the existing ADR-013 graceful-degradation pattern: if callout fails → log coordinator task → continue. Evaluate each new flag field and write result to the corresponding `IndividualApplication` checkbox.

**Note on `CRITICAL_HABITAT_GIS`:** This is a FeatureServer (point/polygon query by bounding box), not a simple proximity check. Use the existing ECOS callout as the primary; add this as a secondary spatial confirmation only if ECOS is unavailable (graceful degradation already implemented in `NepaAgencyPermitService`).

#### E4. Update `NEPA_Permit_Coordinator` GIS augmentation formula

Extend `formula_GISAugmentedPermits` to add four additional permit triggers:

```
IF({!Get_CurrentIA.nepa_air_nonattainment_flag__c} && NOT(CONTAINS(...,"Clean Air Act")), "; Clean Air Act General Conformity Determination", "") &
IF({!Get_CurrentIA.nepa_fema_flood_flag__c} && NOT(CONTAINS(...,"Floodplain")), "; FEMA Floodplain Executive Order 11988 Compliance", "") &
IF({!Get_CurrentIA.nepa_blm_acec_flag__c} && NOT(CONTAINS(...,"FLPMA")), "; FLPMA Title V ROW Permit", "") &
IF({!Get_CurrentIA.nepa_wild_scenic_river_flag__c} && NOT(CONTAINS(...,"Wild & Scenic")), "; Wild & Scenic Rivers Act Section 7 Compliance", "")
```

#### E5. Update `NEPA_Permit_Matrix__mdt` — GIS_Trigger_Layers__c values

Update the `GIS_Trigger_Layers__c` field on existing and new matrix records to include the new layer keys:

| Sector | Add to GIS_Trigger_Layers__c |
|---|---|
| All water-adjacent sectors | `NWI_WETLANDS` |
| Energy/Transmission, Transportation/Highway, Transportation/Bridge | `EPA_AIR_NONATTAINMENT` |
| All construction sectors | `FEMA_FLOOD` |
| Energy/Pipelines, Materials/Mining, Energy/OilGas | `USACE_FUDS` |
| BLM-managed land sectors (Energy/Solar, Energy/Transmission, Materials/Mining) | `BLM_ACEC` |
| Water/Irrigation, Energy/Hydro | `WILD_SCENIC_RIVERS` |

#### E6. NRHP Section 106 — data approach (no live ArcGIS endpoint)

The NPS ArcGIS NRHP service is not currently operational (500 error). Two alternatives:

1. **Demo data only:** Download NPS NRHP bulk CSV (`nps.gov/subjects/nationalregister/database-research.htm`) and seed 20–30 records into a `nepa_nrhp_site__c` custom object (lightweight, child of `IndividualApplication`) for demo purposes. This satisfies the submission narrative claim without requiring a live callout.
2. **Production path:** Monitor NPS service recovery; integrate when available. Use `nepa_tribal_lands_flag__c` (already set) as a proxy trigger for NHPA Section 106 in the interim (tribal lands proximity already implies Section 106 consultation).

### Submission Narrative Impact

| Current claim | Updated claim after Phase E |
|---|---|
| "5 GIS services at intake" | "12 federal GIS services at intake covering wetlands, critical habitat, tribal lands, air quality nonattainment, flood hazard, BLM extraordinary circumstances, Wild & Scenic Rivers, and munitions/hazardous waste" |
| "Live cross-agency permit status for CWA 404" | Strengthened: NWI spatial query directly triggers CWA 404 record creation with empirical USACE timeline data from Wetlands Impact Tracker |
| "ESA Section 7 critical habitat check" | Strengthened: FeatureServer spatial query replaces ECOS web-app lookup; FWS-published geometry |
| "E.O. 13175 tribal consultation" | Strengthened: EPA tribal lands layer (American Indian Reservations) + existing BLM tribal cadastral = dual-source tribal proximity confirmation |

### Phase E Implementation Sequence

| Step | Work | Files |
|---|---|---|
| E1 | 8 NEPA_GIS_Layer__mdt CMT records | `customMetadata/` (8 files) |
| E2 | 6 checkbox fields on IndividualApplication | `objects/IndividualApplication/fields/` (6 files) |
| E3 | NEPA_GIS_Proximity_Check flow update (6 new callout blocks) | `flows/NEPA_GIS_Proximity_Check.flow-meta.xml` |
| E4 | NEPA_Permit_Coordinator formula extension (4 new clauses) | `flows/NEPA_Permit_Coordinator.flow-meta.xml` |
| E5 | NEPA_Permit_Matrix__mdt GIS_Trigger_Layers updates | 25 CMT records |
| E6 | NRHP demo data seed (NPS bulk CSV → demo records) | `data/demo/nrhp_demo_sites.json` |

**Dependency:** Phase E step E2 (fields) must deploy before E3 (flow references the fields). E3 must deploy before E4 (coordinator reads flags written by proximity check).

---

## Critical Files

| File | Change |
|---|---|
| `force-app/.../objects/nepa_required_permit__c/` | Add field XMLs + object root; change permit type to Lookup |
| `force-app/.../objects/IndividualApplication/fields/nepa_blocked_permit_count__c.field-meta.xml` | New rollup summary |
| `force-app/.../objects/IndividualApplication/fields/nepa_wetlands_flag__c.field-meta.xml` | New GIS flag (Phase D Priority 2) |
| `force-app/.../objects/NEPA_Permit_Matrix__mdt/fields/` | Two new fields |
| `force-app/.../objects/RegulatoryAuthorizationType/fields/` | Four new NEPA fields |
| `force-app/.../flows/NEPA_Permit_Record_Creator.flow-meta.xml` | New flow; includes wetlands flag in GIS bridge |
| `force-app/.../flows/NEPA_Permit_Coordinator.flow-meta.xml` | GIS augmentation (3 new elements + wetlands flag) |
| `force-app/.../flows/NEPA_GIS_Proximity_Check.flow-meta.xml` | Add OpenWetlandsMap layer callout |
| `force-app/.../flows/NEPA_Litigation_Risk_Scorer.flow-meta.xml` | Permit gap penalty + trigger condition |
| `force-app/.../flows/NEPA_Stage_Gate_Doc_Check.flow-meta.xml` | ROD/FONSI cross-permit gate (2 new elements) |
| `force-app/.../flows/NEPA_Permit_SLA_Monitor.flow-meta.xml` | New scheduled flow |
| `force-app/.../customMetadata/NEPA_GIS_Layer.OpenWetlandsMap.md-meta.xml` | New GIS layer CMT record (Phase D) |
| `force-app/.../customMetadata/NEPA_GIS_Layer.NWI_Wetlands.md-meta.xml` | NWI wetlands endpoint (Phase E) |
| `force-app/.../customMetadata/NEPA_GIS_Layer.Critical_Habitat_GIS.md-meta.xml` + 6 more | Phase E: 8 new validated federal GIS layer records |
| `force-app/.../objects/IndividualApplication/fields/nepa_air_nonattainment_flag__c.field-meta.xml` + 5 more | Phase E: 6 new GIS flag checkboxes on IndividualApplication |
| `force-app/.../customMetadata/NEPA_Permit_Matrix.*.md-meta.xml` | 16 new records + update 9 existing |
| `data/demo/` | 20 `RegulatoryAuthorizationType` seed records + Wetlands Impact Tracker–sourced CWA 404 demo permits |
| `docs/SUBMISSION-NARRATIVE.md` | 4 targeted updates (Nine Types paragraph, GIS count, Wetlands Tracker citation, datasets list) |

---

## Verification

1. **End-to-end:** Create `IndividualApplication` with Program sector = "Energy Production and Management" / project type = "Pipelines" + set `nepa_nhd_proximity_flag__c = true`. Confirm:
   - `NEPA_Permit_Coordinator` fires → `nepa_co_permits_required__c` includes FERC cert + CWA 404 appended via GIS
   - `NEPA_Permit_Record_Creator` fires → 6+ individual `nepa_required_permit__c` records created
   - `nepaPermitDependencies` LWC shows records with correct status badges (not the empty state)

2. **Risk scorer:** Set one critical permit to `Not Started`. Confirm `nepa_blocked_permit_count__c` = 1 and `nepa_risk_score__c` increases by 8 pts. Flip to `Issued`, confirm rollup drops to 0 and score decreases.

3. **Stage gate:** Attempt to advance IA to ROD with 1+ critical permits in `Not Started`. Confirm save is blocked with permit gap message.

4. **SLA monitor:** Set `nepa_sla_due_date__c` to yesterday on a `Not Started` critical permit. Run `NEPA_Permit_SLA_Monitor` via Setup → Run Flow. Confirm Task created on the IA.

5. **Regression:** Run all Apex tests; confirm 0 failures. `NepaAgencyPermitServiceTest` should pass against seeded `nepa_required_permit__c` records.

6. **Demo:** Walk Carrie Placer Mine demo story; confirm permit dependency card shows populated data with correct agency badges.

7. **Phase E GIS:** Create `IndividualApplication` with lat/lon inside a known NWI wetland polygon. Confirm `NEPA_GIS_Proximity_Check` sets `nepa_wetlands_flag__c = true` and `NEPA_Permit_Record_Creator` creates a CWA Section 404 permit record. Confirm `nepaPermitDependencies` LWC shows the 404 permit with USACE as lead agency.

8. **Phase E Air Quality:** Create `IndividualApplication` with lat/lon inside an EPA ozone nonattainment area. Confirm `nepa_air_nonattainment_flag__c = true` and a Clean Air Act General Conformity permit record is created.
