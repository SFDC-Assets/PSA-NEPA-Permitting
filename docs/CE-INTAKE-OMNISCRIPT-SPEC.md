# CE Intake OmniScript — Developer Specification
## NEPA_CE_Intake / NEPA_CEIntake

**Audience:** Junior developer reimplementing the CE Intake OmniScript from scratch.  
**Version:** v1 (current active)  
**Last updated:** 2026-05-23

---

## Table of Contents

1. [What This Does and Why](#1-what-this-does-and-why)
2. [Component Inventory](#2-component-inventory)
3. [Architecture Overview](#3-architecture-overview)
4. [End-to-End Data Flow](#4-end-to-end-data-flow)
5. [OmniScript Page Specifications](#5-omniscript-page-specifications)
   - [Step 1 — Project Selection](#step-1--project-selection)
   - [Step 2 — Process Details](#step-2--process-details)
   - [Step 3 — Site and Scope](#step-3--site-and-scope)
   - [Step 4 — CE Screening Result (AI)](#step-4--ce-screening-result-ai)
   - [Done / Redirect](#done--redirect)
6. [Integration Procedure: NEPA_CE_Screening_IP](#6-integration-procedure-nepa_ce_screening_ip)
7. [Integration Procedure: NEPA_CE_Save_IP](#7-integration-procedure-nepa_ce_save_ip)
8. [BRE Expression Set: NEPA_CE_Screener](#8-bre-expression-set-nepa_ce_screener)
9. [DataRaptor: DR_Load_NEPA_Process](#9-dataraptor-dr_load_nepa_process)
10. [DataRaptor: DRExtractCELibraryByAgency](#10-dataraptor-drextractcelibrarybyagency)
11. [Post-Save Async Flow: NEPA_CE_Screener](#11-post-save-async-flow-nepa_ce_screener)
12. [IndividualApplication Field Reference](#12-individualapplication-field-reference)
13. [Important Design Decisions](#13-important-design-decisions)

---

## 1. What This Does and Why

The CE Intake OmniScript is the guided wizard an agency staff member or applicant uses to submit a new NEPA environmental review request — specifically, one they believe qualifies as a Categorical Exclusion (CE).

The wizard collects four categories of information:

| Category | What it captures |
|---|---|
| Project linkage | Which parent Project (Program record) this review belongs to |
| Process identity | Review name, agency identifier, start date, description, purpose and need |
| Site scope | Action type, surface disturbance in acres, extraordinary circumstances flag |
| Screening result | Preliminary AI recommendation: CE / EA / EIS; coordinator override option |

On submission, the wizard creates an `IndividualApplication` record (the NEPA Process record) with status `Draft` and stage `Intake`, linked to the selected parent `Program`. Immediately after commit, an asynchronous record-triggered Flow (`NEPA_CE_Screener`) fires to run the authoritative three-tier BRE classification and write the official recommendation.

**Critical distinction — two classifications run at different times:**

```
During the wizard:  NEPA_CE_Screening_IP  →  preliminary recommendation (shown to user)
After save:         NEPA_CE_Screener Flow →  authoritative BRE classification (written async)
```

The preliminary recommendation shown during the wizard is based on simple acreage thresholds. The authoritative classification is based on three Decision Matrices (NAICS, Agency+Sector, Agency+ActionType) plus an acreage override. A human NEPA Coordinator must review and confirm before `nepa_review_type__c` is officially set.

---

## 2. Component Inventory

| File | Type | Active | Role |
|---|---|---|---|
| `NEPA_CE_Intake.json` | OmniScript | Yes | 4-step guided intake wizard |
| `NEPA_CEIntake_OmniScript_1.os-meta.xml` | OmniScript (source XML) | No | Older v1 — reference only |
| `NEPA_CE_Screening_IP.json` | Integration Procedure | Yes | Pre-screening called during wizard (Step 3 → Step 4 transition) |
| `NEPA_CEScreeningIP_Procedure_1.oip-meta.xml` | IP (source XML) | Yes | Deployed version of screening IP |
| `NEPA_CE_Save_IP.json` | Integration Procedure | Yes | Saves the new IA record on submit |
| `NEPA_CESaveIP_Procedure_1.oip-meta.xml` | IP (source XML) | Yes | Deployed version of save IP |
| `NEPA_CE_Screener.expressionSetDefinition-meta.xml` | BRE Expression Set | Yes | Three-tier CE classification engine |
| `NEPA_CE_Screener_NAICS.decisionMatrixDefinition-meta.xml` | Decision Matrix | Yes | NAICS-to-CE routing table |
| `NEPA_CE_Screener_Tier1.decisionMatrixDefinition-meta.xml` | Decision Matrix | Yes | Agency + Sector + Type routing |
| `NEPA_CE_Screener_Tier2.decisionMatrixDefinition-meta.xml` | Decision Matrix | Yes | Agency + ActionType routing |
| `DRExtractCELibraryByAgency_1.rpt-meta.xml` | DataRaptor Extract | Yes | Fetches CE library entries for the screening step display |
| `DR_Load_NEPA_Process.json` | DataRaptor Load | Yes | Upserts the IndividualApplication record |
| `NEPA_CE_Screener.flow-meta.xml` | Record-Triggered Flow | Active | Async post-save BRE runner; writes `nepa_ce_pathway_recommendation__c` |
| `NEPA_CE_Intake.flow-meta.xml` | Screen Flow | Draft | Alternative Flow-based intake; see [§13](#13-important-design-decisions) |

**OmniScript key:** `NEPA/CE_Intake/English/1`  
**OmniScript type/subtype:** `NEPA` / `CEIntake`  
**Process key:** `NEPACEIntake`

---

## 3. Architecture Overview

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    CE INTAKE OMNISCRIPT ARCHITECTURE                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║   ┌─────────────────────────────────────────────────────────────────────┐   ║
║   │                    NEPA_CE_Intake OmniScript                        │   ║
║   │                                                                     │   ║
║   │  Step 1      Step 2        Step 3         Step 4        Done        │   ║
║   │  Project  →  Process   →  Site &    →   Screening  →  [Redirect]   │   ║
║   │  Select      Details      Scope          Result                     │   ║
║   │                             │                ▲                      │   ║
║   └─────────────────────────────┼────────────────┼──────────────────────┘   ║
║                                 │                │                           ║
║                     ┌───────────▼────────────┐   │                          ║
║                     │  NEPA_CE_Screening_IP  │───┘  Returns:                ║
║                     │  (IP Action, pre-step) │      • ReviewType            ║
║                     │                        │      • CECode                ║
║                     │  1. DR Extract Process │      • Confidence            ║
║                     │  2. DR Extract Project │      • ClassificationBasis   ║
║                     │  3. Set Values (inputs)│                              ║
║                     │  4. Call CE Screener   │◄─── NEPA_CE_Screener         ║
║                     │     Expression Set BRE │     Expression Set           ║
║                     │  5. Set Values (output)│     (preliminary pass)       ║
║                     └────────────────────────┘                              ║
║                                                                              ║
║                     After user confirms Step 4:                             ║
║                     ┌──────────────────────────┐                            ║
║                     │   NEPA_CE_Save_IP        │  Writes to DB:             ║
║                     │   (IP Action, post-step) │  IndividualApplication     ║
║                     │                          │  status = Draft            ║
║                     │  1. Set Values (payload) │  stage  = Intake           ║
║                     │  2. DR Load NEPA Process │                            ║
║                     │  3. Set Values (returns  │  Returns:                  ║
║                     │     processId)           │  • processId (IA record Id)║
║                     └──────────────────────────┘                            ║
║                                  │                                          ║
║         ┌────────────────────────▼────────────────────────┐                 ║
║         │   NEPA_CE_Screener Record-Triggered Flow        │                 ║
║         │   (AsyncAfterCommit — fires automatically)      │                 ║
║         │                                                  │                ║
║         │  1. Get_RelatedProject  (Program lookup)        │                 ║
║         │  2. Call_NEPA_Evaluate_CE (BRE Expression Set)  │                 ║
║         │  3. Update_ScreeningFields                      │  Writes to IA:  ║
║         │     → nepa_ce_pathway_recommendation__c         │  (advisory only)║
║         │     → nepa_process_code__c                      │                 ║
║         │     → nepa_screening_confidence__c              │                 ║
║         │     → nepa_classification_basis__c              │                 ║
║         │     → nepa_screener_last_run__c                 │                 ║
║         │  4. GIS EC flag evaluation (if any flag set)    │                 ║
║         └──────────────────────────────────────────────────┘                ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 4. End-to-End Data Flow

The following shows exactly which values flow between components. Pay close attention to the naming: OmniScript fields, IP inputs/outputs, and IA database fields all have different names.

```
USER INPUT                   OMNISCRIPT DATA             SAVED TO IA FIELD
─────────────────────────────────────────────────────────────────────────────

[Step 1]
  Project search         →   projectId                →  nepa_related_project__c
  (read-only display)    ←   projectId:Name           ←  Program.Name

[Step 2]
  Review Name            →   processName              →  Name
  Agency Identifier      →   agencyId                 →  nepa_agency_id__c
  Start Date             →   startDate                →  nepa_start_date__c
  Purpose and Need       →   purposeNeed              →  nepa_purpose_need__c
  Description            →   description              →  nepa_description__c

[Step 3 → NEPA_CE_Screening_IP]
  Action Type            →   actionType               →  nepa_action_type__c
  Disturbance Acres      →   disturbanceAcres         →  nepa_disturbance_acres__c
  Extraordinary Circs    →   extraordinaryCircumstances (bool, not yet saved)

  ── NEPA_CE_Screening_IP is called here ──
  Input to IP:                projectId / processId
  IP fetches:                 ProcessData (via DR_Extract_NEPA_Process)
                              ProjectData (via DR_Extract_NEPA_Project)
  IP builds inputs:           AgencyAbbr   ← ProcessData:nepa_data_source_agency__c
                              NAICSCode    ← ProjectData:nepa_applicant_naics__c
                              SectorKey    ← ProjectData:nepa_project_sector__c
                              TypeKey      ← ProjectData:nepa_project_type__c
                              ActionType   ← ProcessData:nepa_action_type__c
                              DisturbanceAcres ← ProcessData:nepa_disturbance_acres__c
  BRE returns:                ReviewType, CECode, Confidence, ClassificationBasis
  IP output path:             ScreeningIPResult{}

[Step 4 — displayed from ScreeningIPResult]
  (read-only) Review Type     ScreeningIPResult:ReviewType
  (read-only) CE Code         ScreeningIPResult:CECode
  (read-only) Confidence      ScreeningIPResult:Confidence
  (read-only) Basis           ScreeningIPResult:ClassificationBasis
  (editable)  Override        reviewTypeOverride       (null = accept recommendation)
  (editable)  Override Rationale overrideRationale

  ── NEPA_CE_Save_IP is called on Next/Submit ──
  Final review type:          reviewTypeOverride || ScreeningIPResult:ReviewType

  Save IP writes to IA:       Name                     ← processName
                              nepa_related_project__c  ← projectId
                              nepa_agency_id__c        ← agencyId
                              nepa_start_date__c       ← startDate
                              nepa_purpose_need__c     ← purposeNeed
                              nepa_description__c      ← description
                              nepa_action_type__c      ← actionType
                              nepa_disturbance_acres__c ← disturbanceAcres
                              nepa_extraordinary_circumstances__c ← (bool/text)
                              nepa_review_type__c      ← reviewTypeOverride || ReviewType
                              nepa_regulatory_citation__c ← ceCode (CE code)
                              nepa_screening_confidence__c ← confidence
                              nepa_classification_basis__c ← classificationBasis
                              nepa_process_status__c   = "Draft"  (hardcoded)
                              nepa_process_stage__c    = "Intake" (hardcoded)
  Returns:                    SaveResult:processId     ← UpsertResult:Id

[Post-save — NEPA_CE_Screener Flow fires async]
  Trigger:                    IA saved/updated, action/acres/EC/GIS changed
  Reads:                      Related Program for AgencyAbbr, SectorKey, TypeKey, NAICSCode
  BRE inputs:                 Same 6 inputs as screening IP
  BRE outputs written to IA:
    nepa_ce_pathway_recommendation__c  ← ReviewType (mapped to CE-Recommended/EA-Required/EIS-Required)
    nepa_process_code__c               ← CECode
    nepa_screening_confidence__c       ← Confidence
    nepa_classification_basis__c       ← ClassificationBasis (audit trail)
    nepa_screener_last_run__c          ← NOW()
  GIS EC evaluation:
    If nepa_nhd_proximity_flag__c = true  → appends "NHD Waterway Proximity"
    If nepa_tribal_lands_flag__c = true   → appends "Tribal Lands Proximity"
    If nepa_plss_flag__c = true           → appends "PLSS Public Land"
    If any GIS flag → writes to nepa_extraordinary_circumstances__c

[Done]
  OmniScript redirects to:   /lightning/r/IndividualApplication/{processId}/view
```

---

## 5. OmniScript Page Specifications

### Global OmniScript Settings

| Property | Value |
|---|---|
| Type | NEPA |
| SubType | CEIntake |
| Language | English |
| Version | 1 |
| Process Key | NEPACEIntake |
| Done Action | Redirect to `/lightning/r/IndividualApplication/{SaveResult:processId}/view` |
| Finish Button Label | Submit CE Screening Request |
| Progress Bar | Bottom |
| Actions Display | Bottom |
| LWC Runtime | Enabled |
| Persistent Component | true |

---

### Step 1 — Project Selection

**Purpose:** Link this NEPA process to an existing Project (Program record).

**Element name:** `Step1_ProjectSelection`  
**Sequence number:** 1  
**Level:** 0

```
┌─────────────────────────────────────────────────────────┐
│  ● ○ ○ ○   CE Intake — Step 1 of 4                     │
│  ─────────────────────────────────────────────────────  │
│  Project Selection                                       │
│  Search for the Project this NEPA process belongs to.   │
│                                                         │
│  Project *                                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │  🔍 Search by name, project ID, or title...    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Project Title (read-only)                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Populated when project is selected             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                                          [ Next →  ]   │
└─────────────────────────────────────────────────────────┘
```

**Fields:**

| Element Name | OmniScript Type | Required | Binding / Notes |
|---|---|---|---|
| `projectId` | Lookup | Yes | Object: `Program`; display field: `Name`; search fields: `Name`, `nepa_project_title__c`, `nepa_project_id__c`; value stored: record Id |
| `projectTitle` | Text | — | Read-only; value: `%projectId:Name%`; auto-populates when project is selected |

**Validation:** Next is blocked until `projectId` is populated.

**OmniScript Lookup behavior:** The Lookup element calls a SOQL search against `Program` in real time. The user types at least 2 characters to trigger the search. The returned value is the record `Id`, not the name — the name is displayed separately in `projectTitle`.

---

### Step 2 — Process Details

**Purpose:** Capture the identifying information for this NEPA process.

**Element name:** `Step2_ProcessDetails`  
**Sequence number:** 2  
**Level:** 0

```
┌─────────────────────────────────────────────────────────┐
│  ● ● ○ ○   CE Intake — Step 2 of 4                     │
│  ─────────────────────────────────────────────────────  │
│  Process Details                                         │
│  Enter the key attributes of this NEPA process.         │
│                                                         │
│  Review Name *                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  e.g., "Carrie Placer Mine Phase II CE Review"  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Agency Process Identifier *                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Internal agency tracking ID                    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Start Date *                                           │
│  ┌──────────────┐                                      │
│  │  MM/DD/YYYY  │                                      │
│  └──────────────┘                                      │
│                                                         │
│  Purpose and Need                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  (optional, long text)                          │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Project Description                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  (optional, long text)                          │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                               [ ← Back ]  [ Next → ]   │
└─────────────────────────────────────────────────────────┘
```

**Fields:**

| Element Name | OmniScript Type | Required | Max Length | Maps to IA Field |
|---|---|---|---|---|
| `processName` | Text | Yes | 255 | `Name` |
| `agencyId` | Text | Yes | 50 | `nepa_agency_id__c` |
| `startDate` | Date | Yes | — | `nepa_start_date__c` |
| `purposeNeed` | TextArea | No | 32,768 | `nepa_purpose_need__c` |
| `description` | TextArea | No | 32,768 | `nepa_description__c` |

**Validation:** `processName`, `agencyId`, and `startDate` are required. Next is blocked until all three are populated.

---

### Step 3 — Site and Scope

**Purpose:** Capture the site-specific parameters that drive CE eligibility: action type, disturbance acreage, and extraordinary circumstances.

**Element name:** `Step3_SiteAndScope`  
**Sequence number:** 3  
**Level:** 0

```
┌─────────────────────────────────────────────────────────┐
│  ● ● ● ○   CE Intake — Step 3 of 4                     │
│  ─────────────────────────────────────────────────────  │
│  Site and Scope                                          │
│  Provide site-specific data used to determine the        │
│  appropriate level of NEPA review.                       │
│                                                         │
│  Action Type *                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  -- Select --                              ▼    │   │
│  │  Abandon or Decommission                        │   │
│  │  Construct New                                  │   │
│  │  Modify Existing                                │   │
│  │  Operate or Maintain Existing                   │   │
│  │  Renew or Extend Existing                       │   │
│  │  Research or Study                              │   │
│  │  Other                                          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Surface Disturbance (acres)                           │
│  ┌──────────────────────────────┐                      │
│  │  0.00                        │                      │
│  └──────────────────────────────┘                      │
│  Minimum: 0, precision: 2 decimal places               │
│                                                         │
│  ☐ Extraordinary Circumstances Present                 │
│     Check if any extraordinary circumstances per       │
│     40 CFR 1501.4(b) apply to this action.             │
│                                                         │
│                               [ ← Back ]  [ Next → ]   │
│                                                         │
│  (Clicking Next triggers CE Screening — may take        │
│   a few seconds)                                        │
└─────────────────────────────────────────────────────────┘
```

**Fields:**

| Element Name | OmniScript Type | Required | Default | Maps to IA Field |
|---|---|---|---|---|
| `actionType` | Select | Yes | — | `nepa_action_type__c` |
| `disturbanceAcres` | Number | No | 0 | `nepa_disturbance_acres__c` (scale 2) |
| `extraordinaryCircumstances` | Checkbox | No | false | See note below |

**`actionType` picklist values** (must match `nepa_action_type__c` picklist exactly):

| Display Label | API Value |
|---|---|
| Abandon or Decommission | `Abandon or Decommission` |
| Construct New | `Construct New` |
| Modify Existing | `Modify Existing` |
| Operate or Maintain Existing | `Operate or Maintain Existing` |
| Renew or Extend Existing | `Renew or Extend Existing` |
| Research or Study | `Research or Study` |
| Other | `Other` |

> **Note on `extraordinaryCircumstances`:** The checkbox in the OmniScript is a boolean (`true`/`false`). The field on `IndividualApplication` (`nepa_extraordinary_circumstances__c`) is a **Text** field (255 chars), used to store a semicolon-delimited list of specific EC conditions written by GIS proximity checks. The Save IP maps the boolean to `'Yes'` (if true) or `null` (if false) when writing to the database. Do not try to save a boolean directly into a text field — use Set Values in the Save IP to convert.

**What happens after clicking Next on Step 3:**

Before Step 4 is displayed, the OmniScript fires `IPAction_RunCEScreener`, an Integration Procedure Action element that calls `NEPA_CE_Screening_IP`. This is a **blocking call** — the user sees a spinner until the IP returns. The IP result is stored in the `ScreeningIPResult` output path, and Step 4 is then rendered using those values.

**IP Action element properties:**

| Property | Value |
|---|---|
| Element name | `IPAction_RunCEScreener` |
| Type | Integration Procedure Action |
| IP name | `NEPA_CE_Screening_IP` |
| Chains on | `Step3_SiteAndScope` |
| Input map | `processId` |
| Output path | `ScreeningIPResult` |
| Fail on error | false (screening failure should not block submission) |
| Remote timeout | 10,000 ms |

---

### Step 4 — CE Screening Result (AI)

**Purpose:** Display the preliminary AI screening recommendation and let the coordinator accept or override before saving.

**Element name:** `Step4_ScreeningResult`  
**Sequence number:** 5 (sequence 4 is the IP Action that fires between steps 3 and 4)  
**Level:** 0

```
┌─────────────────────────────────────────────────────────┐
│  ● ● ● ●   CE Intake — Step 4 of 4                     │
│  ─────────────────────────────────────────────────────  │
│  CE Screening Result                                     │
│  Review the recommended NEPA review classification.      │
│  You may override before saving.                         │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ ℹ  AI SCREENING RECOMMENDATION                    │  │
│  │    This result is generated by the NEPA_CE_Screener│  │
│  │    BRE. A coordinator must confirm before routing. │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  Recommended Review Type (read-only)                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  CE                                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Applicable CE Code (read-only)                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │  43 CFR 46.210(i)                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Classification Confidence (read-only)                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │  High                                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Classification Basis (read-only)                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Tier 1 match: BLM + Public Lands sector.       │   │
│  │  Action type "Renew or Extend Existing" matches │   │
│  │  43 CFR 46.210(i) (renewal of existing permit). │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ── OVERRIDE (optional) ──────────────────────────────  │
│                                                         │
│  Override Review Type                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  -- Accept Recommendation --               ▼    │   │
│  │  CE                                             │   │
│  │  EA                                             │   │
│  │  EIS                                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Override Rationale  (required if override selected)   │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  (only visible when CE, EA, or EIS selected)    │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                   [ ← Back ]  [ Submit CE Request  ]   │
└─────────────────────────────────────────────────────────┘
```

**Fields:**

| Element Name | OmniScript Type | Editable | Value Source | Maps to IA Field |
|---|---|---|---|---|
| `recommendedReviewType` | Text | No (read-only) | `%ScreeningIPResult:ReviewType%` | (displayed only; final type determined by override) |
| `recommendedCECode` | Text | No (read-only) | `%ScreeningIPResult:CECode%` | (displayed only) |
| `confidence` | Text | No (read-only) | `%ScreeningIPResult:Confidence%` | `nepa_screening_confidence__c` (via Save IP) |
| `classificationBasis` | TextArea | No (read-only) | `%ScreeningIPResult:ClassificationBasis%` | `nepa_classification_basis__c` (via Save IP) |
| `reviewTypeOverride` | Select | Yes | — | Merged with recommendation before save |
| `overrideRationale` | TextArea | Yes | — | Saved as addendum to `nepa_classification_basis__c` |

**`reviewTypeOverride` picklist values:**

| Display Label | API Value | Behavior |
|---|---|---|
| -- Accept Recommendation -- | (empty/null) | Use `ScreeningIPResult:ReviewType` as final value |
| CE | `CE` | Override to CE |
| EA | `EA` | Override to EA |
| EIS | `EIS` | Override to EIS |

**Conditional display rule for `overrideRationale`:**  
Visible only when `reviewTypeOverride` has a non-empty value (i.e., CE, EA, or EIS is selected). Hidden when "Accept Recommendation" is selected. Implemented as a `controllingElements` condition referencing `reviewTypeOverride` with values `['CE', 'EA', 'EIS']`.

**Final review type computation (in Save IP):**  
The Save IP resolves the final `nepa_review_type__c` using the formula:
```
reviewTypeOverride || ScreeningIPResult:ReviewType
```
If `reviewTypeOverride` is non-null, it wins. Otherwise the IP recommendation is used.

**What happens when the user clicks Submit:**

The OmniScript fires `IPAction_SaveProcess`, another Integration Procedure Action that calls `NEPA_CE_Save_IP`. This is a **blocking call** — the user sees a spinner until the record is saved. On success, the OmniScript redirects to the new `IndividualApplication` record.

**Save IP Action element properties:**

| Property | Value |
|---|---|
| Element name | `IPAction_SaveProcess` |
| Type | Integration Procedure Action |
| IP name | `NEPA_CE_Save_IP` |
| Chains on | `Step4_ScreeningResult` |
| Input map | 14 parameters (see [§7](#7-integration-procedure-nepa_ce_save_ip)) |
| Output path | `SaveResult` |
| Fail on error | true (submission must succeed or the user stays on the page) |
| Remote timeout | 15,000 ms |

---

### Done / Redirect

After `NEPA_CE_Save_IP` returns successfully, the OmniScript executes its `doneAction`:

```
Redirect to: /lightning/r/IndividualApplication/{SaveResult:processId}/view
```

The `processId` is the Salesforce record `Id` of the newly created `IndividualApplication`, returned from the Save IP's output path `SaveResult`.

---

## 6. Integration Procedure: NEPA_CE_Screening_IP

**IP Key:** `NEPACEScreeningIP`  
**Type/Subtype:** `NEPA` / `CEScreeningIP`  
**When called:** During the OmniScript, between Step 3 and Step 4  
**Purpose:** Run the NEPA_CE_Screener BRE Expression Set and return a preliminary recommendation for display before the user submits.

### Inputs

| Input Name | Source in OmniScript | Type | Notes |
|---|---|---|---|
| `processId` | OmniScript `projectId` value | String | May be blank for a new (unsaved) process — see design note |

> **Design note for new intake:** For a brand-new process being entered, `processId` may be null or a draft ID. The screening IP is designed to work when called from an existing process record in edit mode. For a truly new intake, the screening IP handles missing process/project data gracefully (`failOnStepError: false`) by falling back to the BRE's default output (EA recommendation). When reimplementing, consider also accepting `actionType`, `disturbanceAcres`, `agencyAbbr`, `sectorKey`, `naicsCode` directly as fallback inputs so the IP can screen without a pre-existing record.

### Steps

**Step 1 — GetProcessForScreening**

```
Type:           DataRaptor Extract Action
DR name:        DR_Extract_NEPA_Process
Input:          processId
Output path:    ProcessData
Fail on error:  true
```

Reads back the `IndividualApplication` record to get `nepa_action_type__c`, `nepa_disturbance_acres__c`, `nepa_data_source_agency__c` (lead agency abbreviation), and `nepa_related_project__c`.

**Step 2 — GetProjectForScreening**

```
Type:           DataRaptor Extract Action
DR name:        DR_Extract_NEPA_Project
Input:          projectId = %ProcessData:nepa_related_project__c%
Output path:    ProjectData
Chains on:      GetProcessForScreening
Fail on error:  false
```

Reads the parent `Program` record to get `nepa_project_sector__c`, `nepa_project_type__c`, `nepa_applicant_naics__c`.

**Step 3 — BuildScreeningInputs**

```
Type:           Set Values
Chains on:      GetProjectForScreening
```

Assembles the 6 inputs required by the NEPA_CE_Screener BRE:

| Output Variable | Source | Notes |
|---|---|---|
| `AgencyAbbr` | `%ProcessData:nepa_data_source_agency__c%` | e.g., `BLM`, `DOE`, `USFS` |
| `NAICSCode` | `%ProjectData:nepa_applicant_naics__c%` | e.g., `2111` — 4-digit or 6-digit |
| `SectorKey` | `%ProjectData:nepa_project_sector__c%` | e.g., `Energy`, `Water` |
| `TypeKey` | `%ProjectData:nepa_project_type__c%` | project sub-type within sector |
| `ActionType` | `%ProcessData:nepa_action_type__c%` | maps to `nepa_action_type__c` picklist |
| `DisturbanceAcres` | `%ProcessData:nepa_disturbance_acres__c%` | decimal number |

**Step 4 — CallCEScreenerBRE**

```
Type:                   Expression Set (or Calculation Action in older orgs)
Expression Set name:    NEPA_CE_Screener
Input:                  6 variables from BuildScreeningInputs
Output path:            ScreeningResult
Chains on:              BuildScreeningInputs
Fail on error:          false
```

> **OmniStudio version note:** In OmniStudio orgs where the `Expression Set` element type is not registered in the OmniProcessElement picklist, use element type `Calculation Action` instead. The `propertySetConfig` schema differs:
> - `Expression Set` uses: `expressionSetApiName: "NEPA_CE_Screener"` + `inputMap`
> - `Calculation Action` uses: `remoteOptions: { configurationName: "NEPA CE Screener" }` (the **label**, not the API name) + `elementValueMap` + `responseJSONPath`

Returns: `ReviewType`, `CECode`, `Confidence`, `ClassificationBasis`.

**Step 5 — BuildScreeningResponse**

```
Type:   Set Values
```

Promotes the BRE output into the top-level output path:

| Output Variable | Source |
|---|---|
| `ReviewType` | `%ScreeningResult:ReviewType%` |
| `CECode` | `%ScreeningResult:CECode%` |
| `Confidence` | `%ScreeningResult:Confidence%` |
| `ClassificationBasis` | `%ScreeningResult:ClassificationBasis%` |
| `ScreeningComplete` | `true` (hardcoded boolean) |

The OmniScript consumes these via `%ScreeningIPResult:ReviewType%`, `%ScreeningIPResult:CECode%`, etc. (the `ScreeningIPResult` prefix comes from the IP Action's `outputPath` setting).

---

## 7. Integration Procedure: NEPA_CE_Save_IP

**IP Key:** `NEPACESaveIP`  
**Type/Subtype:** `NEPA` / `CESaveIP`  
**When called:** After the user clicks Submit on Step 4  
**Purpose:** Upsert the `IndividualApplication` record and return the saved record's Id.

### Inputs received from OmniScript

| Input Name | OmniScript Source | Notes |
|---|---|---|
| `projectId` | `projectId` | Program record Id |
| `processName` | `processName` | Maps to `Name` |
| `agencyId` | `agencyId` | Maps to `nepa_agency_id__c` |
| `startDate` | `startDate` | Maps to `nepa_start_date__c` |
| `purposeNeed` | `purposeNeed` | Maps to `nepa_purpose_need__c` |
| `description` | `description` | Maps to `nepa_description__c` |
| `actionType` | `actionType` | Maps to `nepa_action_type__c` |
| `disturbanceAcres` | `disturbanceAcres` | Maps to `nepa_disturbance_acres__c` |
| `extraordinaryCircumstances` | `extraordinaryCircumstances` | Boolean → converted to text |
| `reviewType` | `reviewTypeOverride \|\| ScreeningIPResult:ReviewType` | Maps to `nepa_review_type__c` |
| `ceCode` | `ScreeningIPResult:CECode` | Maps to `nepa_regulatory_citation__c` |
| `confidence` | `ScreeningIPResult:Confidence` | Maps to `nepa_screening_confidence__c` |
| `classificationBasis` | `ScreeningIPResult:ClassificationBasis` | Maps to `nepa_classification_basis__c` |

### Steps

**Step 1 — BuildProcessPayload**

```
Type:   Set Values
```

Assembles all inputs into a nested `ProcessPayload` object that the DataRaptor can consume. **Two fields are hardcoded here — they are never editable by the user:**

| Hardcoded Assignment | Value | Reason |
|---|---|---|
| `ProcessPayload:nepa_process_status__c` | `"Draft"` | New intake always starts as Draft |
| `ProcessPayload:nepa_process_stage__c` | `"Intake"` | Stage gate starts at Intake |

All other `ProcessPayload:*` fields are mapped from inputs.

> **`extraordinaryCircumstances` conversion:** The checkbox boolean must be converted before saving. Set Values converts it: `true` → `'Yes'`, `false` → `null`. The `nepa_extraordinary_circumstances__c` field on IA is a Text(255) field, not a Boolean. GIS proximity flags later overwrite this field with a semicolon-delimited string like `"NHD Waterway Proximity; Tribal Lands Proximity"`.

**Step 2 — UpsertProcess**

```
Type:           DataRaptor Load Action
DR name:        DR_Load_NEPA_Process
Input:          ProcessPayload{}
Output path:    UpsertResult
Chains on:      BuildProcessPayload
Fail on error:  true
Merge output with parent: false
```

The DataRaptor Load (`DR_Load_NEPA_Process`) upserts by `nepa_federal_unique_id__c`. For a new record, this field is blank, so the DataRaptor performs an insert and Salesforce assigns a new Id. For an edit of an existing process, if `nepa_federal_unique_id__c` is populated, the DataRaptor updates the matching record.

Returns `UpsertResult` containing the record `Id`.

**Step 3 — ExtractSavedId**

```
Type:   Set Values
```

Extracts the record Id into a clean top-level variable:

| Output Variable | Source |
|---|---|
| `processId` | `%UpsertResult:Id%` |

The OmniScript reads this as `%SaveResult:processId%` for the redirect URL.

### Output

| Output Key | Value | Used by |
|---|---|---|
| `SaveResult:processId` | Salesforce record Id of the new IA | OmniScript redirect URL |

---

## 8. BRE Expression Set: NEPA_CE_Screener

**API name:** `NEPA_CE_Screener`  
**Label:** `NEPA CE Screener`  
**Version:** V3 (Active)  
**Start date:** 2026-05-08  
**Process type:** BRE

The Expression Set runs in two contexts:
1. **During the OmniScript** — called by `NEPA_CE_Screening_IP` (preliminary, shown to user)
2. **Post-save** — called by `NEPA_CE_Screener` Flow (authoritative, written to record)

### Variables

**Inputs (6):**

| Variable | Type | Description |
|---|---|---|
| `AgencyAbbr` | Text | Lead agency abbreviation (e.g., `BLM`, `DOE`, `USFS`, `FERC`) |
| `NAICSCode` | Text | 4- or 6-digit NAICS code of the applicant's primary activity |
| `SectorKey` | Text | Project sector (e.g., `Energy`, `Water`, `Agriculture`) |
| `TypeKey` | Text | Project sub-type within the sector |
| `ActionType` | Text | Action verb (must match `nepa_action_type__c` picklist API value) |
| `DisturbanceAcres` | Number | Surface disturbance in acres |

**Outputs (4):**

| Variable | Type | Description |
|---|---|---|
| `ReviewType` | Text | `CE`, `EA`, or `EIS` |
| `CECode` | Text | CFR citation of the applicable CE (e.g., `43 CFR 46.210(i)`) or blank |
| `Confidence` | Text | `High`, `Medium-High`, `Medium`, or `Low` |
| `ClassificationBasis` | Text | Human-readable explanation of which rule matched and why |

**Internal constant:**

| Variable | Value | Purpose |
|---|---|---|
| `CONST_AcreageThreshold` | `250` | Override threshold — acreage above this forces EA even if a CE rule matches |

### Steps (10)

The BRE evaluates the 10 steps sequentially. Later steps can overwrite values set by earlier steps.

```
Step 1  NAICSLookup
        ↓ queries NEPA_CE_Screener_NAICS decision matrix
        ↓ input: NAICSCode
        ↓ output: ReviewType, CECode, Confidence, ClassificationBasis

Step 2  Tier1AgencySectorLookup
        ↓ queries NEPA_CE_Screener_Tier1 decision matrix
        ↓ input: AgencyAbbr, SectorKey, TypeKey
        ↓ output: ReviewType, CECode, Confidence, ClassificationBasis

Step 3  Tier2AgencyActionTypeLookup
        ↓ queries NEPA_CE_Screener_Tier2 decision matrix
        ↓ input: AgencyAbbr, ActionType
        ↓ output: ReviewType, CECode, Confidence, ClassificationBasis

Step 4  ConsolidateReviewType
        ↓ Priority: NAICS match > Tier1 match > Tier2 match > default EA
        ↓ If no matrix matched → ReviewType = "EA"

Step 5  ConsolidateCECode
        ↓ Takes the CE code from the winning match (or blank if no CE)

Step 6  ConsolidateConfidence
        ↓ Takes confidence from the winning match (default: "Low")

Step 7  ConsolidateClassificationBasis
        ↓ Takes explanation from the winning match
        ↓ Default: "No screening rule matched; defaulted to EA for manual review"

Step 8  ApplyAcreageOverride
        ↓ IF DisturbanceAcres > CONST_AcreageThreshold (250 acres)
        ↓ AND ReviewType = "CE"
        ↓ THEN ReviewType = "EA"
             Confidence = "High"
             ClassificationBasis appended with:
             " [ACREAGE OVERRIDE: {acres} acres > 250-acre CE threshold]"

Step 9  ClearCECodeOnNonCE
        ↓ IF ReviewType != "CE" THEN CECode = ""

Step 10 OutputScreeningResult
        ↓ Final ReviewType is surfaced as the BRE result
```

### Decision Matrix Schemas

**NEPA_CE_Screener_NAICS** — routes by industry code

| Input Column | Type | Example Values |
|---|---|---|
| `NAICSCode` | Text (exact match) | `2111`, `2212`, `486`, `9281` |

| Output Column | Type | Example Values |
|---|---|---|
| `ReviewType` | Text | `CE`, `EA` |
| `CECode` | Text | CFR citation or blank |
| `Confidence` | Text | `High`, `Medium-High`, `Medium`, `Low` |
| `ClassificationBasis` | Text | Rule explanation text |

**NEPA_CE_Screener_Tier1** — routes by agency + sector + project type

| Input Column | Type | Example Values |
|---|---|---|
| `AgencyAbbr` | Text | `BLM`, `DOE`, `USFS`, `FERC` |
| `SectorKey` | Text | `Energy`, `Water`, `Agriculture` |
| `TypeKey` | Text | Project sub-type |

| Output Column | Type | Example Values |
|---|---|---|
| `ReviewType` | Text | `CE`, `EA`, `EIS` |
| `CECode` | Text | CFR citation |
| `Confidence` | Text | Confidence level |
| `ClassificationBasis` | Text | Rule explanation |

**NEPA_CE_Screener_Tier2** — routes by agency + action type (catch-all for when Tier1 has no match)

| Input Column | Type | Example Values |
|---|---|---|
| `AgencyAbbr` | Text | `BLM`, `DOE`, `USFS` |
| `ActionType` | Text | `Renew or Extend Existing`, `Construct New` |

| Output Column | Type | Example Values |
|---|---|---|
| `ReviewType` | Text | `CE`, `EA` |
| `CECode` | Text | CFR citation |
| `Confidence` | Text | Confidence level |
| `ClassificationBasis` | Text | Rule explanation |

**How the three tiers cascade:**

```
Input arrives
    │
    ▼
Tier NAICS lookup  ──── match found? → use this result (highest priority)
    │ no match
    ▼
Tier1 lookup       ──── match found? → use this result
    │ no match
    ▼
Tier2 lookup       ──── match found? → use this result
    │ no match
    ▼
Default: ReviewType = EA, Confidence = Low
         ClassificationBasis = "No screening rule matched; defaulted to EA for manual review"
```

The `NEPA_CE_Screening_Rule__mdt` Custom Metadata records in the project correspond to rows in these decision matrices. The metadata prefixes give you the tier: `T1_` = Tier1 rows, `T2_` = Tier2 rows, `NAICS_` = NAICS rows.

---

## 9. DataRaptor: DR_Load_NEPA_Process

**Unique name:** `DRLoadNEPAProcess_1`  
**Type:** Load (upsert)  
**Target object:** `IndividualApplication`  
**Upsert key:** `nepa_federal_unique_id__c` (blank = insert new record)

This DataRaptor receives the `ProcessPayload` object from the Save IP and writes each mapped field to the `IndividualApplication` record.

**Field mappings (input → IA field):**

| DR Input Path | IA Field | Type | Notes |
|---|---|---|---|
| `Name` | `Name` | Text | Required. The process title. |
| `nepa_related_project__c` | `nepa_related_project__c` | Lookup → Program | Parent project Id |
| `nepa_agency_id__c` | `nepa_agency_id__c` | Text(50) | Agency-assigned tracking number |
| `nepa_start_date__c` | `nepa_start_date__c` | Date | |
| `nepa_purpose_need__c` | `nepa_purpose_need__c` | Long Text | |
| `nepa_description__c` | `nepa_description__c` | Long Text | |
| `nepa_action_type__c` | `nepa_action_type__c` | Picklist | Must match exact API value |
| `nepa_disturbance_acres__c` | `nepa_disturbance_acres__c` | Number | |
| `nepa_extraordinary_circumstances__c` | `nepa_extraordinary_circumstances__c` | Text(255) | `'Yes'` or null from checkbox conversion |
| `nepa_review_type__c` | `nepa_review_type__c` | Picklist | `CE`, `EA`, or `EIS` |
| `nepa_regulatory_citation__c` | `nepa_regulatory_citation__c` | Text | The CE code (e.g., `43 CFR 46.210(i)`) |
| `nepa_screening_confidence__c` | `nepa_screening_confidence__c` | Picklist | `High`, `Medium-High`, `Medium`, `Low` |
| `nepa_classification_basis__c` | `nepa_classification_basis__c` | Long Text | BRE audit trail |
| `nepa_process_status__c` | `nepa_process_status__c` | Picklist | Hardcoded: `Draft` |
| `nepa_process_stage__c` | `nepa_process_stage__c` | Picklist | Hardcoded: `Intake` |

**Output:** Returns the record `Id` in `UpsertResult`.

---

## 10. DataRaptor: DRExtractCELibraryByAgency

**Unique name:** `DRExtractCELibraryByAgency_1`  
**Type:** Extract  
**Source object:** `nepa_ce_library__c`  
**Called by:** The v1 XML OmniScript's Step 4 CE library display (not the JSON version's main screening flow)

**Purpose:** Returns a list of CE entries for the selected agency so the user can see matching CEs before submitting. This is a browse/reference display — it does not drive the BRE classification.

**Query filters:**

| Filter | Operator | Input |
|---|---|---|
| `nepa_agency_abbr__c` | = | `AgencyAbbr` (from OmniScript) |
| `nepa_active__c` | = | `true` (hardcoded) |

**Output fields (mapped to `LibraryEntries` array):**

| Source Field | Output Key | Type |
|---|---|---|
| `Id` | `id` | Text |
| `nepa_ce_explorer_id__c` | `ce_explorer_id` | Text |
| `nepa_agency_abbr__c` | `agency_abbr` | Text |
| `nepa_context__c` | `context` | Text |
| `nepa_origin__c` | `origin` | Text |
| `nepa_exclusion_text__c` | `exclusion_text` | Long Text |
| `nepa_source_url__c` | `source_url` | URL |

**Note on `nepa_ce_library__c`:** This is a custom object that stores the full text of agency CE provisions — the CE Explorer library. It is distinct from the `NEPA_CE_Code__mdt` Custom Metadata Type (which stores short CE code identifiers). The library object holds the complete regulatory text that an applicant reads to understand which CE they are applying under.

---

## 11. Post-Save Async Flow: NEPA_CE_Screener

**Flow API name:** `NEPA_CE_Screener`  
**Type:** Record-Triggered Flow (After Save, Async After Commit)  
**Object:** `IndividualApplication`  
**Status:** Active

This flow fires automatically — the OmniScript does not call it. It runs asynchronously in a separate transaction after the `IndividualApplication` record commits to the database.

### Trigger Conditions

The flow fires when **any of these fields change** AND the review type is not already locked to EA or EIS:

**Field change triggers (OR logic — any one is sufficient):**
- `nepa_action_type__c` changed
- `nepa_disturbance_acres__c` changed
- `nepa_extraordinary_circumstances__c` changed
- `nepa_related_project__c` changed
- `nepa_nhd_proximity_flag__c` changed
- `nepa_tribal_lands_flag__c` changed
- `nepa_plss_flag__c` changed

**Guard conditions (AND — both must be true):**
- `nepa_review_type__c` ≠ `EIS`
- `nepa_review_type__c` ≠ `EA`

> **Why the guard conditions?** Once a coordinator has upgraded a process to EA or EIS, the screener should not re-evaluate and potentially recommend CE. The guards prevent the async flow from downgrading a decision.

### Flow Elements

**1. Get_RelatedProject**

```
Type:       Record Lookup
Object:     Program
Filter:     Id = {!$Record.nepa_related_project__c}
Fields:     Id, nepa_record_owner_agency__c, nepa_project_sector__c,
            nepa_project_type__c, nepa_applicant_naics__c
Stored in:  rec_RelatedProject
```

**2. Call_NEPA_Evaluate_CE**

```
Type:    Action (runExpressionSet)
ES:      NEPA_CE_Screener

Inputs:
  AgencyAbbr      = rec_RelatedProject.nepa_record_owner_agency__c
  NAICSCode       = rec_RelatedProject.nepa_applicant_naics__c
  SectorKey       = rec_RelatedProject.nepa_project_sector__c
  TypeKey         = rec_RelatedProject.nepa_project_type__c
  ActionType      = {!$Record.nepa_action_type__c}
  DisturbanceAcres = {!$Record.nepa_disturbance_acres__c}
  ExtraordinaryCircumstances = {!$Record.nepa_extraordinary_circumstances__c}

Outputs:
  ReviewType           → var_ReviewType
  CECode               → var_CECode
  Confidence           → var_Confidence
  ClassificationBasis  → var_ClassificationBasis
```

**3. var_RecommendationPicklist (Formula)**

Maps the BRE ReviewType value to the `nepa_ce_pathway_recommendation__c` picklist values:

```
CE  → "CE-Recommended"
EA  → "EA-Required"
EIS → "EIS-Required"
```

This mapping exists because `nepa_ce_pathway_recommendation__c` uses longer picklist values (`CE-Recommended`, `EA-Required`, `EIS-Required`) while the BRE outputs short values (`CE`, `EA`, `EIS`). Do **not** confuse these fields — the BRE output should never be written directly to `nepa_review_type__c` (that would violate the AI human-in-the-loop requirement).

**4. var_GIS_EC_Formula (Formula)**

Builds a semicolon-delimited string of active GIS extraordinary circumstances flags:

```apex
IF(  {!$Record.nepa_nhd_proximity_flag__c},    "NHD Waterway Proximity",  ""  )  &
IF(  {!$Record.nepa_tribal_lands_flag__c},     "; Tribal Lands Proximity", "" )  &
IF(  {!$Record.nepa_plss_flag__c},             "; PLSS Public Land",       "" )
```

**5. Update_ScreeningFields**

```
Type:   Record Update
Object: IndividualApplication
Id:     {!$Record.Id}

Fields written:
  nepa_ce_pathway_recommendation__c  = var_RecommendationPicklist   ← AI recommendation
  nepa_process_code__c               = var_CECode                   ← CE code (e.g., "43 CFR 46.210(i)")
  nepa_screening_confidence__c       = var_Confidence               ← High/Medium-High/Medium/Low
  nepa_classification_basis__c       = var_ClassificationBasis      ← audit trail text
  nepa_screener_last_run__c          = {!$Flow.CurrentDateTime}     ← timestamp
```

> **Critical:** The flow writes to `nepa_ce_pathway_recommendation__c` (the AI advisory field), NOT to `nepa_review_type__c` (the official determination). A NEPA Coordinator must manually confirm `nepa_review_type__c` on the process record. This implements the OMB M-24-10 human-in-the-loop requirement.

**6–9. GIS EC Flag Evaluation (Decisions + Update)**

Three decisions (`Check_NHD_Flag`, `Check_Tribal_Flag`, `Check_PLSS_Flag`) evaluate each GIS proximity flag independently. If **any** is true, `Check_Any_GIS_Active` routes to `Update_EC_From_GIS`:

```
Type:   Record Update
Object: IndividualApplication
Id:     {!$Record.Id}

Fields written:
  nepa_extraordinary_circumstances__c = var_GIS_EC_Formula
```

This overwrites the manual checkbox input from the OmniScript with the GIS-detected EC string. If GIS flags are set, they are authoritative over the user's manual checkbox.

**10–11. Error Handling**

`Handle_Error` assigns `$Flow.FaultMessage` to `var_ErrorMessage`, then `Call_ErrorLogger` invokes the `NEPA_Error_Logger` subflow with:
- `inp_FlowName = "NEPA_CE_Screener"`
- `inp_ErrorMessage = var_ErrorMessage`
- `inp_RecordId = {!$Record.Id}`
- `inp_RunningUserId = {!$User.Id}`
- `inp_FailedStep` (whichever step faulted)

---

## 12. IndividualApplication Field Reference

Fields written by the CE Intake pathway, in the order they appear in the data flow:

| Field API Name | Label | Type | Written By | Value |
|---|---|---|---|---|
| `Name` | Process Name | Text(255) | Save IP | User input |
| `nepa_related_project__c` | Related Project | Lookup(Program) | Save IP | Selected project Id |
| `nepa_agency_id__c` | Agency Process Identifier | Text(50) | Save IP | User input |
| `nepa_start_date__c` | Start Date | Date | Save IP | User input |
| `nepa_purpose_need__c` | Purpose and Need | Long Text | Save IP | User input |
| `nepa_description__c` | Project Description | Long Text | Save IP | User input |
| `nepa_action_type__c` | Action Type | Picklist | Save IP | User input (7 values) |
| `nepa_disturbance_acres__c` | Surface Disturbance Acres | Number(12,2) | Save IP | User input |
| `nepa_extraordinary_circumstances__c` | Extraordinary Circumstances | Text(255) | Save IP / Screener Flow | `'Yes'` from checkbox; overwritten by GIS flag string |
| `nepa_review_type__c` | NEPA Review Type | Picklist | Save IP | User-selected or IP recommendation (`CE`, `EA`, `EIS`, etc.) |
| `nepa_regulatory_citation__c` | Regulatory Citation | Text(255) | Save IP | CE code from BRE (e.g., `43 CFR 46.210(i)`) |
| `nepa_screening_confidence__c` | Screening Confidence | Picklist | Save IP → Screener Flow | `High` / `Medium-High` / `Medium` / `Low` |
| `nepa_classification_basis__c` | Classification Basis | Long Text | Save IP → Screener Flow | BRE audit trail text |
| `nepa_process_status__c` | Process Status | Picklist | Save IP | Hardcoded: `Draft` |
| `nepa_process_stage__c` | Process Stage | Picklist | Save IP | Hardcoded: `Intake` |
| `nepa_ce_pathway_recommendation__c` | CE Pathway Recommendation (AI) | Picklist | Screener Flow (async) | `CE-Recommended` / `EA-Required` / `EIS-Required` / `Pending` |
| `nepa_process_code__c` | Process Code | Text(50) | Screener Flow (async) | CE code string from authoritative BRE pass |
| `nepa_screener_last_run__c` | Screener Last Run | DateTime | Screener Flow (async) | Timestamp of async run |

**Fields NOT set during intake (but triggered shortly after):**

| Field API Name | Written By | When |
|---|---|---|
| `nepa_nhd_proximity_flag__c` | GIS Proximity Flow | After `nepa_location_lat__c`/`lon__c` are set on the parent Program |
| `nepa_tribal_lands_flag__c` | GIS Proximity Flow | Same |
| `nepa_plss_flag__c` | GIS Proximity Flow | Same |
| `nepa_risk_score__c` | Risk Scorer Flow | After intake fields + GIS flags are set |

---

## 13. Important Design Decisions

### AI vs. Human Field Distinction

The platform deliberately uses **two separate fields** for the CE recommendation:

| Field | Written by | Meaning | Who can change it |
|---|---|---|---|
| `nepa_ce_pathway_recommendation__c` | `NEPA_CE_Screener` Flow (automated) | AI's advisory opinion | Read-only to staff; only the Flow writes this |
| `nepa_review_type__c` | Coordinator action / Save IP | Official determination | Staff (via record edit), and the Save IP on intake |

This separation implements OMB M-24-10 compliance. If you merge these into one field, you lose the AI audit trail and violate the human-in-the-loop requirement. The `nepa_ce_pathway_recommendation__c` field description explicitly states: "Human NEPA Coordinator must confirm and set nepa_review_type__c before the pathway is official."

### Two Screenings, Different Purposes

The preliminary screening (during the wizard) and the authoritative screening (async post-save) both call the same `NEPA_CE_Screener` BRE, but they exist for different reasons:

- **Preliminary (in wizard):** Shows the user what the system thinks while they are still filling out the form. Gives immediate feedback so they can course-correct. Stored in `ScreeningIPResult` in the OmniScript data node — NOT written to the database at this point.
- **Authoritative (async):** Runs against the saved record with all fields populated, including project-level sector and type data from the parent Program. This is the version that gets recorded in the administrative record. Fires every time a trigger field changes, so it stays current as the record evolves.

### Flow-Based Alternative (NEPA_CE_Intake.flow-meta.xml)

A Screen Flow version (`NEPA_CE_Intake.flow-meta.xml`) exists as a `Draft` (not Active). It provides the same intake functionality using Salesforce native Flows rather than OmniScript. Key differences:

- Launched from an **existing** `IndividualApplication` record (requires a `processId` input variable); it cannot create a new record from scratch without modification
- Saves directly via Record Update elements (no DataRaptor Load)
- The CE screening result is displayed as a formula field on the final screen, not a live BRE call during the flow
- Does not support the CE library browsing display

The OmniScript version is the production path. The Flow version may be used in orgs without OmniStudio licenses or for embedded quick-action scenarios on the IA record.

### Why DataRaptor Load Instead of Direct OmniScript Save

OmniScript can save records directly using a "DataRaptor Post" or a built-in Save element. The platform uses a dedicated Integration Procedure + DataRaptor Load for three reasons:

1. **Upsert by external ID:** The `nepa_federal_unique_id__c` field allows idempotent resubmission. A direct OmniScript save would always insert. The DataRaptor Load handles upsert automatically.
2. **Payload transformation:** The Save IP's `BuildProcessPayload` step performs type conversions (boolean to text) and sets hardcoded field values (`status = Draft`) before the DataRaptor sees any data.
3. **Separation of concerns:** The IP can be called from other sources (Agentforce actions, other OmniScripts, REST API) using the same save logic.

### Testing the Save IP

`NepaCESaveIPTest.cls` tests the field persistence of the Save IP by directly inserting `IndividualApplication` records using `insertViaDirectSimulation()`, which replicates the exact field mapping the IP would produce. Key assertions to replicate if you rebuild:

- `nepa_review_type__c` = `'CE'` after intake
- `nepa_process_status__c` = `'submitted'` (note: the test was written before the Save IP was updated to `'Draft'`; verify current status value against the IP)
- `nepa_process_stage__c` = `'Scoping'` (same note — current IP sets `'Intake'`)
- `nepa_disturbance_acres__c` persists the decimal value
- External ID upsert produces exactly one record on re-submission
- Sector-conditional fields: `nepa_ec_multi_dod__c` = true only on Military sector; `nepa_ec_usace_czma__c` = true only on Water sector

---

*This document reflects the implementation as of 2026-05-23. The canonical source of truth is the metadata in `force-app/main/default/omniScripts/`, `omniIntegrationProcedures/`, `omniProcesses/`, `flows/`, and `expressionSetDefinition/`.*
