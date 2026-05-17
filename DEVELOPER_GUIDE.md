# PSA-NEPA Permitting Accelerator — Developer Guide

**For:** Developers contributing to or extending the PSA-NEPA accelerator  
**Org type:** Salesforce Agentforce for Public Sector (APS)

This guide covers build tasks and the demo validation sprint, in priority order. Each section is self-contained: read the section for the task you're working on, execute it top to bottom, verify, then move to the next.

---

## Post-Deploy Checklist (Required After Every Deployment to a New Org)

The `sf project deploy start` command deploys all metadata — but four items require manual Setup steps that the Metadata API cannot automate. **Do not skip these.** The CE Screener and Administrative Record flows will not work until all four are complete.

| # | Step | Where in Setup | Time |
|---|---|---|---|
| **1** | **Activate each BRE Decision Matrix** | Setup → Business Rules Engine → Decision Tables. Open each table → click **Activate**. Repeat for all Expression Sets. | ~5 min |
| **2** | **Import Decision Matrix row CSVs** | Setup → Business Rules Engine → [table name] → Import. Upload the corresponding CSV from `/decision_matrix_rows/`. Activate after import. | ~5 min |
| **3** | **Convert `nepa_process_stage__c` from Text to Picklist** (first-time only, or if deploying to an org with existing records) | Setup → Object Manager → IndividualApplication → Fields and Relationships → `nepa_process_stage__c` → Edit → change type to Picklist → Save. Then re-deploy the field. | ~3 min |
| **4** | **Add ROD and FONSI record types** | Setup → Object Manager → IndividualApplication → Record Types → New. Add `ROD` and `FONSI` record types. Required for the `NEPA_Close_Administrative_Record` flow entry condition. | ~2 min |

**Total: ~15 minutes of automated deployment + ~15 minutes of manual post-deploy steps ≈ 30 minutes end-to-end.**

---

## Prerequisites

Before starting any task, confirm the following are in place.

### Tools required
```bash
# Salesforce CLI (sf v2)
sf --version          # must be ≥ 2.0.0

# Node.js (required by the Salesforce CLI plugin system — not used directly by deploy scripts)
node --version        # must be ≥ 18

# Git
git --version
```

Install if missing: https://developer.salesforce.com/tools/salesforcecli

### Org access
You need Developer Admin access to the target Salesforce APS org. Log in and set an alias:
```bash
sf org login web --alias nepadev
sf org display --target-org nepadev   # confirm you see the org username
```

### Retrieve metadata from an org into the local project

The `force-app/` directory is already present in this repo and contains all deployed metadata. Use the retrieve command only if you want to pull changes made directly in an org back into your local project:

```bash
# Retrieve all custom objects, fields, flows, and CMTs from org to local
sf project retrieve start \
  --metadata "CustomObject,CustomField,Flow,CustomMetadata,OmniIntegrationProcedure,EmbeddedServiceConfig" \
  --target-org nepadev \
  --output-dir force-app \
  --wait 30
```

After retrieval, commit the changes to git before making additional edits:
```bash
git add force-app/
git commit -m "sync: retrieve updated metadata from org"
```

---

## Task 1 — MFR 4: Publish BRE Decision Logic to GitHub

**What:** Export the CE Screener business rules as structured JSON files and publish them to the public GitHub repo under `/docs/decision-models/`. This lets project sponsors (and CEQ evaluators) see exactly how CE screening decisions are made — meeting MFR 4 Emerging maturity.

**Time estimate:** 1 day  
**No Salesforce deployment required** — this is a documentation export task.

### Step 1 — Create the directory structure

```bash
mkdir -p docs/decision-models
mkdir -p docs/decision-models/ce-screening-rules
mkdir -p docs/decision-models/litigation-risk-weights
mkdir -p docs/decision-models/gis-layers
```

### Step 2 — Create the CE Screening Rules export

Create `docs/decision-models/ce-screening-rules/ce_screening_rules.json`:

```json
{
  "schema_version": "1.0",
  "generated_from": "NEPA_CE_Screener BRE (Salesforce Decision Matrix)",
  "data_source": "NETATEC v2.0 (PNNL) — 399 CE records across BLM, DOE, USDA",
  "last_updated": "2026-05-14",
  "rules": [
    {
      "rule_id": "BLM-CE-001",
      "developer_name": "BLM_OG_MinorDisturbance",
      "lead_agency": "BLM",
      "ce_code": "EPAct_390_b_1",
      "regulatory_cite": "42 USC 15942(b)(1)",
      "plain_language": "BLM oil and gas operations with individual surface disturbance less than 5 acres and total lease size 150 acres or less, where prior NEPA exists",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "BLM" },
          { "field": "Surface_Disturbance_Acres__c", "operator": "less_than", "value": 5 },
          { "field": "Lease_Total_Acres__c", "operator": "less_than_or_equal", "value": 150 },
          { "field": "Prior_NEPA_Exists__c", "operator": "equals", "value": true }
        ]
      },
      "disqualifiers": [
        "Wild and Scenic River corridor (43 CFR 46.215(h))",
        "Special Area designation (43 CFR 2932.5)",
        "T&E species habitat or sage-grouse PHMA (43 CFR 46.215(c))",
        "Section 106 not concluded (54 USC 306108)",
        "Tribal lands or ANCSA selected lands (E.O. 13175)",
        "Riparian or wetland disturbance (43 CFR 46.215(j))"
      ],
      "corpus_frequency": 47
    },
    {
      "rule_id": "BLM-CE-002",
      "developer_name": "BLM_OG_NewWell_DevField",
      "lead_agency": "BLM",
      "ce_code": "EPAct_390_b_3",
      "regulatory_cite": "42 USC 15942(b)(3)",
      "plain_language": "BLM oil and gas new well in a developed field where prior NEPA was completed within 5 years",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "BLM" },
          { "field": "Project_Type__c", "operator": "equals", "value": "Drill Well" },
          { "field": "Prior_NEPA_Exists__c", "operator": "equals", "value": true },
          { "field": "Prior_NEPA_Age_Years__c", "operator": "less_than_or_equal", "value": 5 }
        ]
      },
      "disqualifiers": [
        "Same extraordinary circumstances as EPAct_390_b_1"
      ],
      "corpus_frequency": 31
    },
    {
      "rule_id": "BLM-CE-003",
      "developer_name": "BLM_Realty_Renewal",
      "lead_agency": "BLM",
      "ce_code": "DM_516_11_9_E9",
      "regulatory_cite": "DOI Departmental Manual Part 516 Ch 11.9 Appendix 4 E(9)",
      "plain_language": "BLM renewals and assignments of leases, permits, or rights-of-way where no additional rights are conveyed and no new surface disturbance occurs",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "BLM" },
          { "field": "No_New_Disturbance__c", "operator": "equals", "value": true },
          { "field": "No_New_Rights_Conveyed__c", "operator": "equals", "value": true }
        ]
      },
      "disqualifiers": [],
      "corpus_frequency": 22
    },
    {
      "rule_id": "BLM-CE-004",
      "developer_name": "BLM_ROW_Within_Existing",
      "lead_agency": "BLM",
      "ce_code": "DM_516_11_9_E12",
      "regulatory_cite": "DOI Departmental Manual Part 516 Ch 11.9 Appendix 4 E(12)",
      "plain_language": "BLM grants of rights-of-way wholly within the boundaries of other compatibly developed rights-of-way",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "BLM" },
          { "field": "Within_Existing_ROW__c", "operator": "equals", "value": true },
          { "field": "No_New_Rights_Conveyed__c", "operator": "equals", "value": true }
        ]
      },
      "disqualifiers": [],
      "corpus_frequency": 18
    },
    {
      "rule_id": "USFS-CE-001",
      "developer_name": "USFS_Timber_Salvage",
      "lead_agency": "USFS",
      "ce_code": "USFS_36CFR220.6e6",
      "regulatory_cite": "36 CFR 220.6(e)(6)",
      "plain_language": "USFS timber salvage sales affecting 250 acres or fewer, with no new permanent road construction",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "USFS" },
          { "field": "Project_Type__c", "operator": "in", "value": ["Timber Salvage", "Vegetation Management"] },
          { "field": "Surface_Disturbance_Acres__c", "operator": "less_than_or_equal", "value": 250 }
        ]
      },
      "disqualifiers": [
        "New permanent road construction",
        "Inventoried roadless area",
        "Old-growth forest per agency guidance"
      ],
      "corpus_frequency": 19
    },
    {
      "rule_id": "DOE-CE-001",
      "developer_name": "DOE_SmallResearch",
      "lead_agency": "DOE",
      "ce_code": "DOE_B3.6",
      "regulatory_cite": "10 CFR Part 1021 Subpart D Appendix B B3.6",
      "plain_language": "DOE small-scale research, development, and demonstration projects at existing facilities",
      "conditions": {
        "all_of": [
          { "field": "Lead_Agency__c", "operator": "equals", "value": "DOE" },
          { "field": "Project_Type__c", "operator": "equals", "value": "Research and Development" },
          { "field": "Surface_Disturbance_Acres__c", "operator": "less_than", "value": 1 }
        ]
      },
      "disqualifiers": [
        "Use of hazardous materials in quantities requiring RCRA permit",
        "Work in floodplain or wetland"
      ],
      "corpus_frequency": 24
    }
  ],
  "complexity_rule": {
    "rule_id": "COMPLEXITY-001",
    "description": "When a project spans 3 or more sectors simultaneously AND involves both Energy and Water/Waste sectors, categorical exclusion is inappropriate regardless of other rule matches.",
    "condition": {
      "all_of": [
        { "field": "Num_Sectors__c", "operator": "greater_than_or_equal", "value": 3 },
        { "field": "Sector__c", "operator": "contains", "value": "Energy" }
      ]
    },
    "result": "Set CE_Complexity_Flag__c = ELEVATED; block CE pathway; escalate to EA minimum"
  }
}
```

### Step 3 — Create the Litigation Risk Weights export

Create `docs/decision-models/litigation-risk-weights/agency_risk_rates.json`:

```json
{
  "schema_version": "1.0",
  "data_source": "PermitTEC v0.1 (PNNL) — 684 usable cases after ambiguous outcomes excluded",
  "calibration_date": "2026-05-13",
  "formula": {
    "description": "Composite Litigation Risk Score v2",
    "components": [
      { "component": "agency_loss_rate", "weight": 0.40, "source_field": "Agency_Risk_Rate__mdt.Loss_Rate__c" },
      { "component": "circuit_multiplier", "weight": "((circuit_risk_multiplier - 0.30) * 25)", "source_field": "Circuit_Court_Risk_Weights__mdt.Risk_Weight__c" },
      { "component": "statute_bonus", "weight": "max_statute_risk_multiplier * 15", "source_field": "Statute_Risk_Weights__mdt.Risk_Weight__c" },
      { "component": "plaintiff_bonus", "weight": 15, "condition": "Plaintiff_Risk_Flag__c == true" },
      { "component": "scoping_overrun_bonus", "weight": 10, "condition": "NOI_to_DEIS_months > agency_baseline_months" }
    ],
    "thresholds": {
      "LOW": "score < 35",
      "MEDIUM": "score 35-44",
      "HIGH": "score 45-57",
      "VERY_HIGH": "score >= 58"
    },
    "auto_legal_review_threshold": 58
  },
  "agency_rates": [
    { "abbreviation": "BLM", "full_name": "Bureau of Land Management", "cases": 89, "losses": 35, "loss_rate_pct": 39.3, "risk_tier": "HIGH" },
    { "abbreviation": "USFS", "full_name": "United States Forest Service", "cases": 148, "losses": 42, "loss_rate_pct": 28.4, "risk_tier": "MEDIUM" },
    { "abbreviation": "USACE", "full_name": "Army Corps of Engineers", "cases": 62, "losses": 15, "loss_rate_pct": 24.2, "risk_tier": "MEDIUM" },
    { "abbreviation": "FERC", "full_name": "Federal Energy Regulatory Commission", "cases": 42, "losses": 10, "loss_rate_pct": 23.8, "risk_tier": "MEDIUM" },
    { "abbreviation": "FWS", "full_name": "Fish and Wildlife Service", "cases": 48, "losses": 14, "loss_rate_pct": 29.2, "risk_tier": "MEDIUM" },
    { "abbreviation": "FHWA", "full_name": "Federal Highway Administration", "cases": 38, "losses": 7, "loss_rate_pct": 18.4, "risk_tier": "LOW" },
    { "abbreviation": "FAA", "full_name": "Federal Aviation Administration", "cases": 26, "losses": 3, "loss_rate_pct": 11.5, "risk_tier": "LOW" },
    { "abbreviation": "NMFS", "full_name": "National Marine Fisheries Service", "cases": 28, "losses": 8, "loss_rate_pct": 28.6, "risk_tier": "MEDIUM" }
  ],
  "circuit_multipliers": [
    { "circuit": "10th", "cases": 68, "loss_rate_pct": 35.3, "multiplier": 1.45 },
    { "circuit": "4th", "cases": 42, "loss_rate_pct": 33.3, "multiplier": 1.35 },
    { "circuit": "9th", "cases": 268, "loss_rate_pct": 30.6, "multiplier": 1.25 },
    { "circuit": "DC", "cases": 148, "loss_rate_pct": 25.7, "multiplier": 1.05 },
    { "circuit": "7th", "cases": 22, "loss_rate_pct": 18.2, "multiplier": 0.75 }
  ],
  "statute_multipliers": [
    { "statute": "ESA §7", "citation": "16 USC 1536", "cases": 72, "loss_rate_pct": 36.1, "multiplier": 1.48 },
    { "statute": "NFMA", "citation": "16 USC 1600", "cases": 58, "loss_rate_pct": 31.0, "multiplier": 1.27 },
    { "statute": "CWA §404", "citation": "33 USC 1344", "cases": 48, "loss_rate_pct": 29.2, "multiplier": 1.20 },
    { "statute": "NGA §7", "citation": "15 USC 717f", "cases": 36, "loss_rate_pct": 25.0, "multiplier": 1.02 }
  ]
}
```

### Step 4 — Create the GIS layers README

Create `docs/decision-models/gis-layers/README.md`:

```markdown
# GIS Data Layers Used in CE Screening

The PSA-NEPA Permitting Accelerator calls five external GIS services at intake
via OmniIntegrationProcedure. These calls are triggered automatically when an
applicant submits GIS coordinates (latitude/longitude bounding box) on the
CE Intake Wizard.

| Service | Provider | API | What it checks | EC trigger |
|---------|----------|-----|----------------|------------|
| Critical Habitat | FWS ECOS | `https://ecos.fws.gov/ServCat/DownloadFile/63803` | T&E species habitat within project footprint | 43 CFR 46.215(c) |
| EJ Screen | EPA | `https://ejscreen.epa.gov/mapper/ejscreenRESTbroker.aspx` | Environmental justice indicators; minority/low-income population percentages | Agency EJ policy |
| National Hydrography | USGS NHD | `https://hydro.nationalmap.gov/arcgis/rest/services/NHDPlus_HR/MapServer` | Rivers, streams, wetlands within 300ft of project footprint | 43 CFR 46.215(j) |
| Tribal Land Boundaries | BIA/BLM | `https://gis.blm.gov/arcgis/rest/services/Tribal_Boundaries/MapServer` | Tribal trust land, ANCSA selections | E.O. 13175 |
| Public Land Survey | BLM PLSS | `https://gis.blm.gov/arcgis/rest/services/Cadastral/BLM_Natl_PLSS_CadNSDI/MapServer` | Surface ownership, land status | FLPMA §302 |

Any positive hit on layers 1, 3, 4, or 5 automatically sets the corresponding
extraordinary circumstances flag on the IndividualApplication record and adds
the applicable regulatory citation to the CE screening disqualifier list.
```

### Step 5 — Create the top-level README for the decision models folder

Create `docs/decision-models/README.md`:

```markdown
# PSA-NEPA Decision Models

This directory publishes the decision logic embedded in the PSA-NEPA
Permitting Accelerator's Business Rules Engine (BRE). These files allow
project sponsors, agency staff, and third-party developers to understand
exactly how CE screening and litigation risk scoring decisions are made —
without needing access to the Salesforce org.

This satisfies CEQ Permitting Technology Action Plan MFR #4 (Access to
Screening Criteria) at Emerging maturity.

## Files

| File | Contents |
|------|----------|
| `ce-screening-rules/ce_screening_rules.json` | All CE screening rules: conditions, regulatory citations, disqualifiers, corpus frequency |
| `litigation-risk-weights/agency_risk_rates.json` | Agency loss rates, circuit multipliers, statute multipliers, and composite score formula |
| `gis-layers/README.md` | GIS services used for proximity screening at intake |

## Traceability

Every rule in these files maps 1:1 to a Custom Metadata Type record in the
Salesforce org:

| JSON field | Salesforce CMT |
|-----------|---------------|
| `developer_name` | `DeveloperName` on the CMT record |
| `regulatory_cite` | `Citation__c` or `Regulatory_Cite__c` |
| `conditions` | Decision Matrix row conditions |

## How to update

When PNNL releases an updated PermitTEC corpus:
1. Re-run the calibration pipeline (`pipeline_extended.py` stages 7–13)
2. Update `agency_risk_rates.json` with new loss rates
3. Deploy updated CMT records to the Salesforce org:
   `sf project deploy start --metadata "CustomMetadata" --target-org nepadev`
4. Commit this file with a version note in the commit message
```

### Step 6 — Push to GitHub

```bash
git add docs/
git commit -m "feat(mfr4): publish BRE decision models as open DMN-format JSON

Adds CE screening rules, litigation risk weights, and GIS layer inventory
to docs/decision-models/ — satisfying MFR 4 (Access to Screening Criteria)
at Emerging maturity per CEQ Permitting Technology Action Plan."

git push origin main
```

### Verification for Task 1

- Open the public GitHub repo in a browser
- Navigate to `docs/decision-models/` and confirm all three subdirectories and files are visible
- Click `ce_screening_rules.json` and confirm it renders as valid JSON with at least 6 rules
- Copy the GitHub URL to the `docs/decision-models/README.md` permalink — you'll put this URL in the SUBMISSION-NARRATIVE.md MFR 4 section

---

## Task 2 — MFR 6: Expand GIS Integrations to Five Services

**What:** Add three new external GIS services to the existing OmniIntegrationProcedure that handles GIS proximity checks at intake. The existing procedure already calls FWS ECOS and EPA EJScreen. You're adding USGS NHD, BLM tribal cadastral boundaries, and BLM PLSS.

**Time estimate:** 2 days  
**Platform:** Salesforce OmniStudio (OmniIntegrationProcedure + Named Credentials)

### Step 1 — Create the three Named Credentials

Do this in the Salesforce Setup UI: **Setup → Security → Named Credentials → New**.

Create each one with these exact values:

**Named Credential 1 — USGS NHD**

| Field | Value |
|-------|-------|
| Label | `USGS NHD Plus HR` |
| Name | `USGS_NHD_PlusHR` |
| URL | `https://hydro.nationalmap.gov` |
| Identity Type | `Anonymous` |
| Authentication Protocol | `No Authentication` |
| Allow Merge Fields in HTTP Header | checked |
| Allow Merge Fields in HTTP Body | checked |

**Named Credential 2 — BLM Tribal Boundaries**

| Field | Value |
|-------|-------|
| Label | `BLM Tribal Land Boundaries` |
| Name | `BLM_Tribal_Boundaries` |
| URL | `https://gis.blm.gov` |
| Identity Type | `Anonymous` |
| Authentication Protocol | `No Authentication` |
| Allow Merge Fields in HTTP Header | checked |
| Allow Merge Fields in HTTP Body | checked |

**Named Credential 3 — BLM PLSS**

| Field | Value |
|-------|-------|
| Label | `BLM PLSS Cadastral` |
| Name | `BLM_PLSS_Cadastral` |
| URL | `https://gis.blm.gov` |
| Identity Type | `Anonymous` |
| Authentication Protocol | `No Authentication` |
| Allow Merge Fields in HTTP Header | checked |
| Allow Merge Fields in HTTP Body | checked |

> **Note:** BLM Tribal Boundaries and BLM PLSS share the same base URL (`https://gis.blm.gov`) but use different paths. You can use a single Named Credential for both if you prefer — just make sure the path difference is handled in the Integration Procedure steps below.

### Step 2 — Add three new custom fields for GIS results

Go to **Setup → Object Manager → IndividualApplication → Fields & Relationships → New** for each:

| API Name | Field Type | Length | Description |
|----------|-----------|--------|-------------|
| `nepa_gis_nhd_proximity__c` | Checkbox | — | TRUE when project footprint is within 300 ft of a waterway per USGS NHD |
| `nepa_gis_tribal_land__c` | Checkbox | — | TRUE when project footprint intersects tribal trust land or ANCSA selections |
| `nepa_gis_plss_ownership__c` | Text | 255 | Surface ownership classification returned by BLM PLSS (e.g., "BLM Surface / Federal Subsurface") |

These join the existing `nepa_gis_critical_habitat__c` and `nepa_gis_ej_flag__c` fields that the current Integration Procedure already sets.

### Step 3 — Extend the OmniIntegrationProcedure

Open **OmniStudio → Integration Procedures → NEPA_GIS_ProximityCheck** (the existing procedure). You'll add three new Remote Action steps — one for each new service. Add them after the existing EPA EJScreen step.

**Add Step: USGS_NHD_Check**

| Setting | Value |
|---------|-------|
| Step type | Remote Action |
| Step name | `USGS_NHD_Check` |
| Remote Class/Method | HTTP Callout |
| Named Credential | `USGS_NHD_PlusHR` |
| HTTP Method | GET |
| Endpoint path | `/arcgis/rest/services/NHDPlus_HR/MapServer/find?searchText={!latitude},{!longitude}&layers=all&f=json` |
| Input key | `latitude` = `{IndividualApplication.nepa_gis_latitude__c}` |
| Input key | `longitude` = `{IndividualApplication.nepa_gis_longitude__c}` |

After this step, add a **Set Values** step named `Set_NHD_Result`:
- Condition: `{USGS_NHD_Check.results.length} > 0`
- If true: Set `nepa_gis_nhd_proximity__c` = `true`
- If false: Set `nepa_gis_nhd_proximity__c` = `false`

**Add Step: BLM_Tribal_Check**

| Setting | Value |
|---------|-------|
| Step type | Remote Action |
| Step name | `BLM_Tribal_Check` |
| Named Credential | `BLM_Tribal_Boundaries` |
| HTTP Method | GET |
| Endpoint path | `/arcgis/rest/services/Tribal_Boundaries/MapServer/0/query?geometry={!longitude},{!latitude}&geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects&f=json` |
| Input key | `latitude` = `{IndividualApplication.nepa_gis_latitude__c}` |
| Input key | `longitude` = `{IndividualApplication.nepa_gis_longitude__c}` |

After this step, add **Set Values** step named `Set_Tribal_Result`:
- Condition: `{BLM_Tribal_Check.features.length} > 0`
- If true: Set `nepa_gis_tribal_land__c` = `true`
- If false: Set `nepa_gis_tribal_land__c` = `false`

**Add Step: BLM_PLSS_Check**

| Setting | Value |
|---------|-------|
| Step type | Remote Action |
| Step name | `BLM_PLSS_Check` |
| Named Credential | `BLM_PLSS_Cadastral` |
| HTTP Method | GET |
| Endpoint path | `/arcgis/rest/services/Cadastral/BLM_Natl_PLSS_CadNSDI/MapServer/0/query?geometry={!longitude},{!latitude}&geometryType=esriGeometryPoint&inSR=4326&outFields=OWNERNME&f=json` |
| Input key | `latitude` = `{IndividualApplication.nepa_gis_latitude__c}` |
| Input key | `longitude` = `{IndividualApplication.nepa_gis_longitude__c}` |

After this step, add **Set Values** step named `Set_PLSS_Result`:
- Condition: `{BLM_PLSS_Check.features.length} > 0`
- If true: Set `nepa_gis_plss_ownership__c` = `{BLM_PLSS_Check.features[0].attributes.OWNERNME}`
- If false: Set `nepa_gis_plss_ownership__c` = `"Unknown"`

### Step 4 — Wire GIS results to CE Screener extraordinary circumstances

Open the existing `NEPA_CE_Screener` flow in **Setup → Flows**. Add three new Decision elements after the existing GIS result checks:

**Decision: NHD Proximity Check**
- Condition: `{IndividualApplication.nepa_gis_nhd_proximity__c} = true`
- True outcome: Add `"Riparian or wetland disturbance (43 CFR 46.215(j))"` to `disqualifying_conditions` collection variable
- False outcome: continue

**Decision: Tribal Land Check**
- Condition: `{IndividualApplication.nepa_gis_tribal_land__c} = true`
- True outcome: Add `"Project intersects tribal trust lands — E.O. 13175 consultation required"` to `disqualifying_conditions`; set `nepa_engagement__c.Tribal_Consultation__c = true` on the related engagement record
- False outcome: continue

**Decision: PLSS Ownership Check**
- Condition: `{IndividualApplication.nepa_gis_plss_ownership__c}` contains `"BLM"` or `"Federal"`
- True outcome: Add `"BLM/Federal surface — FLPMA ROW grant required"` to required permits
- False outcome: continue

### Step 5 — Deploy

```bash
sf project retrieve start \
  --metadata "OmniIntegrationProcedure:NEPA_GIS_ProximityCheck,Flow:NEPA_CE_Screener" \
  --target-org nepadev \
  --output-dir force-app

git add force-app/
git commit -m "feat(mfr6): add USGS NHD, BLM tribal, BLM PLSS GIS integrations"
```

### Verification for Task 2

Create a test IndividualApplication with coordinates inside a known critical area (e.g., lat/lon within a tribal reservation in Idaho), activate the GIS check, and confirm:
- `nepa_gis_tribal_land__c` = `true`
- A `nepa_engagement__c` record is created with `Tribal_Consultation__c = true`
- The CE Screener shows "E.O. 13175" in its disqualifier list

If you get a callout error, check: Setup → Monitoring → Debug Logs to see the HTTP response code from the named credential.

---

## Task 3 — MFR 8: Agentforce Comment Classification Agent

**What:** Deploy a native Agentforce Agent that processes public comments submitted as `PublicComplaint` records. The agent classifies each comment, deduplicates similar submissions, routes them appropriately, and creates response tasks. This is the mechanism behind the "2,600 comments in 4 hours" outcome cited in the submission.

**Time estimate:** 4 days  
**Platform:** Salesforce Agentforce + Flows + Apex test

### Step 1 — Add two new fields to PublicComplaint

**Setup → Object Manager → PublicComplaint → Fields & Relationships → New**

| API Name | Field Type | Length | Description |
|----------|-----------|--------|-------------|
| `nepa_comment_classification__c` | Picklist | — | Values: `Substantive`, `Procedural`, `Duplicate`, `EJ_Tribal`, `Scope`, `Unclassified` |
| `nepa_comment_ai_label__c` | Long Text Area | 32,768 | AI classification label with category, confidence (0–100), and one-sentence reasoning |

For `nepa_comment_classification__c`, set default value = `Unclassified`.

### Step 2 — Create the Agentforce Agent

Go to **Agentforce → Agent Builder → New Agent**.

| Setting | Value |
|---------|-------|
| Agent Name | `NEPA Comment Classifier` |
| API Name | `NEPA_Comment_Classifier` |
| Description | `Classifies, deduplicates, and routes public comments submitted on NEPA IndividualApplication records` |
| Primary Object | `PublicComplaint` |

### Step 3 — Create Agent Topics and Actions

In the Agent Builder, create **one Topic** with **five Actions**:

**Topic: Comment Processing**
- Topic Label: `Comment Processing`
- Description: `Handle incoming public comments: classify content, detect duplicates, route EJ/tribal comments, and create response tasks for substantive issues.`
- Scope: `You process public comments submitted on NEPA environmental review cases. Classify each comment by type, flag duplicates, route sensitive comments to the correct specialist, and ensure every substantive issue receives a response task. Never route EJ or tribal comments through AI classification — always send them directly to the EJ/Tribal Liaison queue.`

**Action 1: Classify Comment**

| Setting | Value |
|---------|-------|
| Action Name | `Classify Comment` |
| API Name | `NEPA_ClassifyComment` |
| Type | Prompt Template |
| Prompt | See below |

Prompt template:
```
You are classifying a public comment submitted on a federal NEPA environmental review.

Comment text: {!PublicComplaint.Description}
Commenter organization: {!PublicComplaint.Commenter_Organization__c}
Review type: {!PublicComplaint.IndividualApplication__r.NEPA_Pathway__c}
Project sector: {!PublicComplaint.IndividualApplication__r.Program__r.Sector__c}

Classify this comment into EXACTLY ONE of these categories. Return only the category name and a confidence score (0-100) and one sentence of reasoning.

Categories:
- Substantive: raises a specific legal, scientific, or procedural issue that must be addressed in the NEPA document
- Procedural: concerns the review process itself (timing, notice, scope) rather than project impacts
- Duplicate: substantially similar to another comment already received (same core argument)
- EJ_Tribal: involves environmental justice, tribal sovereignty, sacred sites, treaty rights, or civil rights — NOTE: if you see any of these keywords, classify as EJ_Tribal regardless of other content
- Scope: attempts to expand or narrow the defined scope of review
- Unclassified: cannot be reliably classified

IMPORTANT: Any comment mentioning tribal nations, sacred sites, indigenous rights, treaty rights, environmental justice, Title VI, or civil rights MUST be classified as EJ_Tribal. Do not classify these as Substantive even if they also raise scientific issues.

Response format (JSON only, no other text):
{"category": "<category>", "confidence": <0-100>, "reasoning": "<one sentence>"}
```

**Action 2: Check for Duplicate**

| Setting | Value |
|---------|-------|
| Action Name | `Check for Duplicate` |
| API Name | `NEPA_CheckDuplicate` |
| Type | Flow Action |
| Flow | `NEPA_Comment_Duplicate_Check` (create this flow — see Step 4) |

**Action 3: Route EJ/Tribal Comment**

| Setting | Value |
|---------|-------|
| Action Name | `Route EJ Tribal Comment` |
| API Name | `NEPA_RouteEJTribal` |
| Type | Flow Action |
| Flow | `NEPA_EJTribal_Router` (this flow likely already exists — check; if not, see Step 4) |

**Action 4: Create Response Task**

| Setting | Value |
|---------|-------|
| Action Name | `Create Response Task` |
| API Name | `NEPA_CreateResponseTask` |
| Type | Flow Action |
| Flow | `NEPA_Comment_ResponseTask_Creator` (see Step 4) |

**Action 5: Write Classification Result**

| Setting | Value |
|---------|-------|
| Action Name | `Write Classification Result` |
| API Name | `NEPA_WriteClassification` |
| Type | Record Update |
| Object | `PublicComplaint` |
| Fields to update | `nepa_comment_classification__c`, `nepa_comment_ai_label__c`, `Substantive_Flag__c` |

### Step 4 — Create the three supporting flows

**Flow A: `NEPA_Comment_Duplicate_Check`**

Trigger: Autolaunched (called by agent)  
Input variable: `recordId` (Text) — the PublicComplaint Id

Steps:
1. Get Records: query `PublicComplaint` where `IndividualApplication__c = {recordId's parent IA}` AND `Id != {recordId}` AND `CreatedDate > LAST_N_DAYS:30`
2. Loop over results; for each, call a Text Comparison formula: `CONTAINS({loop.Description}, LEFT({recordId.Description}, 100))`
3. If match found AND current record's classification = `Unclassified`: Set `nepa_comment_classification__c = "Duplicate"` on current record
4. Update current record

**Flow B: `NEPA_EJTribal_Router`**

This should already exist from the original implementation. If it does:
- Confirm it assigns `OwnerId` to the EJ/Tribal Liaison queue
- Confirm it sets `nepa_comment_classification__c = "EJ_Tribal"`

If it does not exist, create it:

Trigger: Autolaunched  
Input variable: `recordId` (Text) — the PublicComplaint Id

Steps:
1. Get Records: Get the `Group` record where `Name = "EJ Tribal Liaison"` and `Type = "Queue"`
2. Update PublicComplaint: Set `OwnerId = {queue.Id}`, `nepa_comment_classification__c = "EJ_Tribal"`
3. Create Task: Subject = `"EJ/Tribal Comment — Mandatory Human Review"`, WhatId = PublicComplaint's `IndividualApplication__c`, Priority = `"High"`, OwnerId = queue.Id, Description = `"This comment was flagged for EJ or tribal content. It has been routed directly to the EJ/Tribal Liaison queue and bypassed AI classification. Human review is required before the comment period closes."`

**Flow C: `NEPA_Comment_ResponseTask_Creator`**

Trigger: Autolaunched  
Input variable: `recordId` (Text) — the PublicComplaint Id

Steps:
1. Get Records: Get the PublicComplaint record and its parent IndividualApplication
2. Decision: Is `nepa_comment_classification__c` = `"Substantive"`?
   - Yes → continue
   - No → end (no task needed)
3. Get Records: Get the IndividualApplication's `NEPA_Coordinator__c` user
4. Create Task:
   - Subject: `"Substantive Comment Response Required — " + PublicComplaint.Commenter_Organization__c`
   - WhatId: `IndividualApplication.Id`
   - WhoId: null
   - Priority: `"Normal"`
   - ActivityDate: TODAY() + 30 (30-day response window)
   - OwnerId: `IndividualApplication.NEPA_Coordinator__c`
   - Description: `"Comment from " + PublicComplaint.Commenter_Organization__c + " classified as Substantive (confidence: " + nepa_comment_ai_label__c confidence portion + "). This comment must receive a written response in the final NEPA document. Reasoning: " + nepa_comment_ai_label__c reasoning portion`

### Step 5 — Create the triggering flow: `NEPA_Comment_AI_Router`

This is the record-triggered flow that fires on every new `PublicComplaint` and orchestrates the agent.

**Setup → Flows → New Flow → Record-Triggered Flow**

| Setting | Value |
|---------|-------|
| Object | `PublicComplaint` |
| Trigger | A record is created |
| Run When | `Always` |
| Optimize for | Actions and Related Records |

Steps:
1. **Decision: EJ/Tribal Keyword Check** (run BEFORE agent)
   - Condition: `CONTAINS({$Record.Description}, "tribal") OR CONTAINS({$Record.Description}, "sacred") OR CONTAINS({$Record.Description}, "indigenous") OR CONTAINS({$Record.Description}, "treaty rights") OR CONTAINS({$Record.Description}, "environmental justice") OR CONTAINS({$Record.Description}, "EJ") OR CONTAINS({$Record.Description}, "Title VI") OR CONTAINS({$Record.Description}, "civil rights")`
   - True path → Subflow: call `NEPA_EJTribal_Router` with `recordId = {$Record.Id}` → **END** (do not invoke AI)
   - False path → continue to Step 2

2. **Action: Invoke Agentforce Agent** — call `NEPA_Comment_Classifier` with `recordId = {$Record.Id}`

3. **Subflow: NEPA_Comment_Duplicate_Check** — call with `recordId = {$Record.Id}`

4. **Decision: Is classification Substantive?**
   - Get updated PublicComplaint record (re-query after agent wrote result)
   - Condition: `nepa_comment_classification__c = "Substantive"`
   - True → Subflow: `NEPA_Comment_ResponseTask_Creator`
   - False → continue to Step 5

5. **Record Update: write Substantive_Flag__c**
   - If `nepa_comment_classification__c = "Substantive"`: Set `Substantive_Flag__c = true`
   - Else: leave as-is

Activate the flow.

### Step 6 — Write the Apex test class

Create a new Apex class: **Setup → Apex Classes → New** (or add file to `force-app/main/default/classes/`).

Class name: `NepaCommentAgentTest`

```apex
@IsTest
private class NepaCommentAgentTest {

    @TestSetup
    static void makeData() {
        // Create parent Account
        Account agency = new Account(Name = 'Test BLM Office');
        insert agency;

        // Create Program
        Program__c prog = new Program__c(
            Name = 'Test Program',
            Lead_Agency__c = 'BLM',
            Project_State__c = 'ID',
            Project_Circuit__c = '9th',
            AccountId = agency.Id
        );
        insert prog;

        // Create IndividualApplication
        IndividualApplication ia = new IndividualApplication(
            Name = 'Test NEPA Process',
            ProgramId = prog.Id,
            AccountId = agency.Id,
            NEPA_Pathway__c = 'EA',
            Stage__c = 'Coordination'
        );
        insert ia;
    }

    // Test 1: EJ/tribal keyword triggers hard-gate route, bypasses AI
    @IsTest
    static void testEJTribalHardGate() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        Account acct = [SELECT Id FROM Account LIMIT 1];

        PublicComplaint pc = new PublicComplaint(
            AccountId = acct.Id,
            IndividualApplication__c = ia.Id,
            Description = 'The Shoshone-Paiute Tribes have treaty rights in this area. Tribal consultation under E.O. 13175 is required before any environmental review proceeds.',
            Commenter_Organization__c = 'Shoshone-Paiute Tribes'
        );

        Test.startTest();
        insert pc;
        Test.stopTest();

        PublicComplaint result = [
            SELECT nepa_comment_classification__c, OwnerId
            FROM PublicComplaint WHERE Id = :pc.Id
        ];

        // Must be classified as EJ_Tribal regardless of AI result
        System.assertEquals('EJ_Tribal', result.nepa_comment_classification__c,
            'Tribal keyword comment must be classified EJ_Tribal and bypass AI');

        // Must be owned by the EJ/Tribal Liaison queue, not coordinator
        Group ejQueue = [SELECT Id FROM Group WHERE Name = 'EJ Tribal Liaison' AND Type = 'Queue' LIMIT 1];
        System.assertEquals(ejQueue.Id, result.OwnerId,
            'EJ/Tribal comment must be routed to EJ Tribal Liaison queue');
    }

    // Test 2: Substantive comment creates response task
    @IsTest
    static void testSubstantiveCommentCreatesTask() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        Account acct = [SELECT Id FROM Account LIMIT 1];

        PublicComplaint pc = new PublicComplaint(
            AccountId = acct.Id,
            IndividualApplication__c = ia.Id,
            Description = 'The draft EA fails to analyze cumulative impacts of the proposed mine on sage-grouse habitat under 40 CFR 1508.7. The cumulative analysis must include the three adjacent BLM leases issued in 2021.',
            Commenter_Organization__c = 'Idaho Conservation League'
        );

        Test.startTest();
        insert pc;
        // Simulate agent writing Substantive classification
        pc.nepa_comment_classification__c = 'Substantive';
        pc.Substantive_Flag__c = true;
        pc.nepa_comment_ai_label__c = '{"category":"Substantive","confidence":91,"reasoning":"Raises specific 40 CFR 1508.7 cumulative impact deficiency requiring response."}';
        update pc;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Priority, ActivityDate
            FROM Task WHERE WhatId = :ia.Id
        ];

        System.assertNotEquals(0, tasks.size(),
            'Substantive comment must generate a response task on the parent IndividualApplication');
        System.assert(tasks[0].Subject.contains('Substantive'),
            'Task subject must indicate substantive comment response required');
        System.assertEquals('Normal', tasks[0].Priority);
    }

    // Test 3: Duplicate comment does NOT create a task
    @IsTest
    static void testDuplicateCommentNoTask() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        Account acct = [SELECT Id FROM Account LIMIT 1];

        // Insert first comment
        PublicComplaint pc1 = new PublicComplaint(
            AccountId = acct.Id,
            IndividualApplication__c = ia.Id,
            Description = 'I oppose this mine because it will hurt fish.',
            Commenter_Organization__c = 'Concerned Citizen A',
            nepa_comment_classification__c = 'Procedural'
        );
        insert pc1;

        // Insert duplicate
        PublicComplaint pc2 = new PublicComplaint(
            AccountId = acct.Id,
            IndividualApplication__c = ia.Id,
            Description = 'I oppose this mine because it will hurt fish.',
            Commenter_Organization__c = 'Concerned Citizen B'
        );

        Test.startTest();
        insert pc2;
        pc2.nepa_comment_classification__c = 'Duplicate';
        update pc2;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Duplicate comment must not generate a response task');
    }

    // Test 4: Classification label is written to the record
    @IsTest
    static void testAILabelWrittenToRecord() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        Account acct = [SELECT Id FROM Account LIMIT 1];

        PublicComplaint pc = new PublicComplaint(
            AccountId = acct.Id,
            IndividualApplication__c = ia.Id,
            Description = 'The scoping notice was not published in the local newspaper as required by 40 CFR 1501.9.',
            Commenter_Organization__c = 'Test Organization'
        );
        insert pc;

        // Simulate agent writing result
        pc.nepa_comment_classification__c = 'Procedural';
        pc.nepa_comment_ai_label__c = '{"category":"Procedural","confidence":88,"reasoning":"Challenges adequacy of scoping notice publication, a procedural NEPA requirement."}';
        update pc;

        PublicComplaint result = [
            SELECT nepa_comment_ai_label__c, nepa_comment_classification__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];

        System.assertNotEquals(null, result.nepa_comment_ai_label__c,
            'AI label must be written to nepa_comment_ai_label__c');
        System.assertEquals('Procedural', result.nepa_comment_classification__c);
    }
}
```

Run the tests:
```bash
sf apex run test \
  --class-names NepaCommentAgentTest \
  --target-org nepadev \
  --result-format human \
  --wait 10
```

All 4 tests must pass before proceeding.

### Step 7 — Deploy and retrieve

```bash
sf project retrieve start \
  --metadata "Flow:NEPA_Comment_AI_Router,Flow:NEPA_Comment_Duplicate_Check,Flow:NEPA_EJTribal_Router,Flow:NEPA_Comment_ResponseTask_Creator,CustomField:PublicComplaint.nepa_comment_classification__c,CustomField:PublicComplaint.nepa_comment_ai_label__c" \
  --target-org nepadev \
  --output-dir force-app

git add force-app/
git commit -m "feat(mfr8): Agentforce comment classification agent + flows + Apex tests

Deploys NEPA_Comment_Classifier agent with 5 actions, triggering flow,
3 supporting flows, and 4 Apex tests. EJ/tribal hard gate is unconditional
and bypasses AI classification. Satisfies MFR 8 at Emerging maturity."
```

### Verification for Task 3

1. Open a test IndividualApplication in the org
2. Create a new PublicComplaint with `Description = "The Navajo Nation has treaty rights..."`
3. Confirm: `nepa_comment_classification__c = "EJ_Tribal"`, owned by EJ queue, no AI label written
4. Create a second PublicComplaint with a substantive scientific objection (no tribal keywords)
5. Confirm: agent writes `nepa_comment_ai_label__c`, creates a Task with 30-day due date
6. Create a third PublicComplaint that is an exact copy of the second
7. Confirm: classified as Duplicate, no Task created

---

## Task 4 — MFR 9: Administrative Record Package Flow

**What:** Add a flow that fires when a NEPA review reaches decision. It assembles a machine-readable JSON manifest of the complete administrative record and writes it as a locked ContentVersion — making the AR available as data, not just a pile of PDFs.

**Time estimate:** 2 days  
**Platform:** Salesforce Flows + DataRaptor Extract

### Step 1 — Add required fields

**On IndividualApplication** — check if `AR_Locked__c` already exists. If not:

| API Name | Field Type | Description |
|----------|-----------|-------------|
| `AR_Locked__c` | Checkbox | TRUE when the administrative record has been locked; prevents post-hoc edits |

**On ContentVersion** — check if `nepa_ar_package__c` already exists. If not:

| API Name | Field Type | Description |
|----------|-----------|-------------|
| `nepa_ar_package__c` | Checkbox | TRUE when this ContentVersion is the machine-readable AR manifest package |

### Step 2 — Create the DataRaptor Extract: `NEPA_AR_Manifest_Extract`

Go to **OmniStudio → DataRaptors → New → Extract**.

| Setting | Value |
|---------|-------|
| Name | `NEPA_AR_Manifest_Extract` |
| Object | `IndividualApplication` |

Configure these output nodes:

**Node 1: Application Summary**
- Object: `IndividualApplication`
- Fields: `Id`, `Name`, `NEPA_Pathway__c`, `Stage__c`, `Lead_Agency__c`, `Litigation_Risk_Score__c`, `Defensibility_Status__c`, `CE_Code__c`, `CE_Regulatory_Cite__c`
- Filter: `Id = {recordId}`

**Node 2: Documents**
- Child relationship: `ContentDocumentLinks → ContentVersion`
- Fields: `Id`, `Title`, `Doc_Type__c`, `AR_Index_Position__c`, `CreatedDate`, `ContentSize`
- Filter: `Doc_Type__c != null`
- Sort by: `AR_Index_Position__c` ASC

**Node 3: Milestones**
- Child relationship: `ApplicationTimelines`
- Fields: `Id`, `Name`, `Milestone_Type__c`, `Statutory_Deadline__c`, `Actual_Date__c`
- Sort by: `Actual_Date__c` ASC

**Node 4: Consultations**
- Child relationship: `nepa_engagements__r`
- Fields: `Id`, `Name`, `Event_Type__c`, `Tribal_Consultation__c`, `Attendance_Count__c`, `CreatedDate`

**Node 5: Comments and Responses**
- Child relationship: `PublicComplaints`
- Fields: `Id`, `Commenter_Organization__c`, `nepa_comment_classification__c`, `Substantive_Flag__c`, `nepa_comment_ai_label__c`, `CreatedDate`

**Node 6: Litigation Risk Snapshot**
- Child relationship: `nepa_litigations__r`
- Fields: `Id`, `Litigation_Risk_Score__c`, `Circuit__c`, `Plaintiff_Org__c`, `Procedural_Failure_Type__c`

Save and activate the DataRaptor.

### Step 3 — Create the flow: `NEPA_Close_Administrative_Record`

**Setup → Flows → New Flow → Record-Triggered Flow**

| Setting | Value |
|---------|-------|
| Object | `IndividualApplication` |
| Trigger | A record is updated |
| Entry Condition | `Stage__c` changes to `Decision_Issued` AND `AR_Locked__c = false` |
| Run When | Entry condition is met |
| Optimize for | Actions and Related Records |

**Step 1: Validation — Check required documents**

Get Records: query `ContentVersion` where `IndividualApplication__c = {$Record.Id}` AND `AR_Index_Position__c != null`  
Store count in variable `arDocCount`

Decision: Is `arDocCount >= 3`?
- No → Create Task: Subject = `"AR Package Blocked — Insufficient Indexed Documents"`, WhatId = `{$Record.Id}`, Priority = `"High"` → End (do not lock)
- Yes → continue

**Step 2: Call DataRaptor to assemble manifest**

Action: OmniStudio DataRaptor Extract  
- DataRaptor: `NEPA_AR_Manifest_Extract`
- Input: `recordId = {$Record.Id}`
- Output variable: `arManifestJSON` (Text, 131,072 chars)

**Step 3: Create the AR ContentVersion**

Create Records: `ContentVersion`
- `Title` = `"NEPA Administrative Record — " + {$Record.Name} + " — " + TEXT(TODAY())`
- `PathOnClient` = `"ar_manifest.json"`
- `VersionData` = `BLOB({arManifestJSON})` — Note: use the `Base64Encode` formula or a linked Apex action for the BLOB conversion if the Flow's native BLOB support is unavailable in your org version
- `Doc_Type__c` = `"AR_Manifest"`
- `nepa_ar_package__c` = `true`
- `AR_Index_Position__c` = `999` (always last in index)
- `FirstPublishLocationId` = `{$Record.Id}` — set via Apex post-step if polymorphic

**Step 4: Lock the administrative record**

Update Records: `IndividualApplication`
- `AR_Locked__c` = `true`
- `Defensibility_Status__c` = `"PASS"` (only if no gaps identified — add a prior check against Expression Set results if needed)

**Step 5: Create completion task**

Create Records: `Task`
- `Subject` = `"Administrative Record Locked — Review AR Manifest"`
- `WhatId` = `{$Record.Id}`
- `Priority` = `"Normal"`
- `OwnerId` = `{$Record.NEPA_Coordinator__c}`
- `Description` = `"The administrative record has been locked and the JSON manifest has been generated. Review the manifest (Doc_Type__c = AR_Manifest) and confirm all required documents are indexed before issuing the ROD."`

Activate the flow.

### Step 4 — Wire AR package to the CEQExport API

Open **OmniStudio → Integration Procedures → NEPA_CEQExport**. Add a new step at the end:

**Step: Include_AR_Manifest**
- Type: DataRaptor Extract
- DataRaptor: a new single-query DR that fetches `ContentVersion` where `IndividualApplication__c = {recordId}` AND `nepa_ar_package__c = true`
- Map output to `admin_record_manifest` key in the final JSON payload

This means the CEQExport response now includes the complete AR manifest as a nested object — any downstream system pulling the CEQ API gets the full AR without a second request.

### Step 5 — Deploy and retrieve

```bash
sf project retrieve start \
  --metadata "Flow:NEPA_Close_Administrative_Record,CustomField:IndividualApplication.AR_Locked__c,CustomField:ContentVersion.nepa_ar_package__c,OmniDataTransform:NEPA_AR_Manifest_Extract" \
  --target-org nepadev \
  --output-dir force-app

git add force-app/
git commit -m "feat(mfr9): AR package flow + DataRaptor manifest extract

Assembles machine-readable JSON administrative record on decision issuance,
locks IndividualApplication against modification, and surfaces AR manifest
through CEQExport API. Satisfies MFR 9 at Emerging maturity."
```

### Verification for Task 4

1. Open a test IndividualApplication in the org that has at least 3 indexed ContentVersion records (`AR_Index_Position__c` set)
2. Change `Stage__c` to `Decision_Issued`
3. Confirm: `AR_Locked__c = true`
4. Confirm: a new ContentVersion with `nepa_ar_package__c = true` and `Doc_Type__c = "AR_Manifest"` was created
5. Download the ContentVersion file — confirm it's valid JSON with at least keys: `application`, `documents`, `milestones`, `comments`
6. Call the CEQExport API: `GET /services/apexrest/NEPA/CEQExport?id={applicationId}` — confirm the response includes `admin_record_manifest`

---

## Task 5 — Demo Validation and Production Sandbox

**What:** Load the Carrie Placer Mine demo dataset into a scratch org, walk all 4 demo scenes, record a Loom video, and set up a persistent sandbox.

**Time estimate:** 3 days  
**Files:** `outputs/demo/import_data/` (19 files)

### Step 1 — Create a scratch org for validation

```bash
# Create a fresh APS scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias nepademoscratch \
  --duration-days 30 \
  --wait 10

# Deploy the full accelerator metadata first
sf project deploy start \
  --source-dir force-app \
  --target-org nepademoscratch \
  --wait 30

# Confirm 385 tests pass
sf apex run test \
  --target-org nepademoscratch \
  --result-format human \
  --wait 30
```

### Step 2 — Load demo data (strict order)

Run each command and wait for it to complete before running the next:

```bash
ALIAS=nepademoscratch
DATA=outputs/demo/import_data

sf data import bulk --file $DATA/01_OperatingHours.csv          --sobject OperatingHours        --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/02_Account.csv                 --sobject Account               --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/03_Contact.csv                 --sobject Contact               --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/04_ServiceTerritory.csv        --sobject ServiceTerritory      --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/05_WorkType.csv                --sobject WorkType              --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/06_ServiceResource.csv         --sobject ServiceResource       --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/07_ServiceTerritoryMember.csv  --sobject ServiceTerritoryMember --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/08_Program.csv                 --sobject Program               --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/09_IndividualApplication.csv   --sobject IndividualApplication --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/10_ContentVersion.csv          --sobject ContentVersion        --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/11_nepa_engagement__c.csv      --sobject nepa_engagement__c    --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/12_ApplicationTimeline.csv     --sobject ApplicationTimeline   --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/13_WorkOrder.csv               --sobject WorkOrder             --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/14_ServiceAppointment.csv      --sobject ServiceAppointment    --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/15_AssignedResource.csv        --sobject AssignedResource      --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/16_PublicComplaint.csv         --sobject PublicComplaint       --target-org $ALIAS --wait 5
sf data import bulk --file $DATA/17_nepa_litigation__c.csv      --sobject nepa_litigation__c    --target-org $ALIAS --wait 5

# Wire polymorphic lookups
sf apex run --file $DATA/18_postload_polymorphic.apex --target-org $ALIAS

# Load tasks (after Apex)
sf data import bulk --file $DATA/19_Task.csv --sobject Task --target-org $ALIAS --wait 5
```

If any step fails, check the error output and fix the data file before re-running. Common issues:
- Missing parent record: a parent from a prior step didn't load. Re-run the failed parent step.
- External ID not found: the `External_Id__c` field must be present on the object. Check Setup → Object Manager → [Object] → Fields to confirm it exists.

### Step 3 — Verify all 4 demo scenes manually

Open the org: `sf org open --target-org nepademoscratch`

Walk through each scene using `outputs/demo/carrie_placer_mine_demo_story.md` as your script:

**Scene 1: Intake and team assembly**
- Navigate to the Carrie Placer Mine `IndividualApplication` record (`DEMO_APP_001`)
- Confirm the 7 resource contacts are populated (botanist, hydrologist, wildlife biologist, etc.)
- Confirm the CE Intake Wizard fired and `NEPA_Pathway__c = "EA"` (it correctly escalated because of the sage-grouse extraordinary circumstance)

**Scene 2: Optimization engine sequences work orders**
- Open the Service Appointment timeline for the application
- Confirm the 8 work orders are scheduled in the correct seasonal windows (no overlap on gate access)
- The botanical survey should be in May–July; the aquatic survey should be before April 15

**Scene 3: Plaintiff intelligence and comment routing**
- Open `PublicComplaint DEMO_PC_001` (Idaho Conservation League)
- Confirm `Plaintiff_Risk_Flag__c = true` on the parent IndividualApplication
- Confirm a Task was created for Legal Counsel with the plaintiff's win rate
- Open `PublicComplaint DEMO_PC_002` (Office of Species Conservation) — this is a standard comment, should not set the plaintiff flag

**Scene 4: Document completeness and decision**
- Navigate to the ContentVersion documents on the application
- Confirm all 5 required documents are present and indexed (`AR_Index_Position__c` set)
- Confirm `Defensibility_Status__c = "PASS"`
- Change `Stage__c = "Decision_Issued"` and confirm `AR_Locked__c` flips to `true`

If any scene fails, document the specific record and field that's wrong, fix the CSV or Apex script, clean up, and re-load.

### Step 4 — Add Scene 5 to the demo story (comment agent)

Open `outputs/demo/carrie_placer_mine_demo_story.md` and add a new section after Scene 4. This is the new MFR 8 scene.

Add the following to the demo story file:

```markdown
---

## Scene 5: Comment Agent — 2,600 Comments in 4 Hours

**Total demo time for this scene:** 3–4 minutes

### Setup Tell
"The public comment period just closed on this EA. The field office received 2,600 comments — standard for a controversial mining project near tribal lands. In the old world, four staff would spend four weeks reading and sorting these. Let me show you what the new world looks like."

### Show
- Navigate to the PublicComplaint list view filtered to this IndividualApplication
- Show the classification dashboard: pie chart of Substantive / Procedural / Duplicate / EJ_Tribal
- Open one EJ_Tribal comment — show it was routed to the EJ/Tribal Liaison queue automatically, AI label field is blank (hard gate enforced)
- Open one Substantive comment — show the AI label: category, confidence score, one-sentence reasoning
- Open the Task list on the IndividualApplication — show all Substantive comments have 30-day response tasks
- Show the Duplicate group — sorted, deduplicated, one response task for the representative comment

### Landing Tell
"The AI handled classification and deduplication. Human staff handled review. The four-week bottleneck became a one-day review of the substantive issues — and not a single EJ or tribal comment went through the AI queue."

### Demo Data to Load for Scene 5

Before recording the video, load 10 additional PublicComplaint records to make this scene compelling. Create a new CSV file at `outputs/demo/import_data/20_PublicComplaints_Agent_Demo.csv`:

| External_Id__c | IndividualApplication__c | Commenter_Organization__c | Description | Substantive_Flag__c |
|---|---|---|---|---|
| DEMO_PC_003 | DEMO_APP_001 | Western Watersheds Project | The EA fails to analyze cumulative impacts on Bruneau sage-grouse habitat under 40 CFR 1508.7. Three adjacent leases issued in 2021 must be included in the analysis. | false |
| DEMO_PC_004 | DEMO_APP_001 | Idaho Conservation League | Same concern — cumulative impacts on sage-grouse habitat not analyzed. | false |
| DEMO_PC_005 | DEMO_APP_001 | Shoshone-Paiute Tribes | The Shoshone-Paiute Tribes have treaty rights in the Owyhee watershed. Tribal consultation under E.O. 13175 has not been completed. We request a 90-day extension. | false |
| DEMO_PC_006 | DEMO_APP_001 | Citizen Comment | I don't want a mine near my property. | false |
| DEMO_PC_007 | DEMO_APP_001 | Citizen Comment | Same as above — please stop this mine. | false |
| DEMO_PC_008 | DEMO_APP_001 | Idaho Rivers United | The hydrological analysis does not address dewatering impacts on Jordan Creek tributaries. A USGS NHD overlay shows the project footprint is within 100 feet of a perennial stream. | false |
| DEMO_PC_009 | DEMO_APP_001 | Mining Association of Idaho | We support this project and believe the EA is thorough and appropriate. | false |
| DEMO_PC_010 | DEMO_APP_001 | Office of Species Conservation | Sage-grouse survey methodology does not meet protocol standards (SAGEBRUSH protocol 2022). Results are unreliable. | false |
| DEMO_PC_011 | DEMO_APP_001 | Citizen Comment | Please protect our environment. | false |
| DEMO_PC_012 | DEMO_APP_001 | Citizen Comment | I don't want a mine near my property. | false |

Load this file:
```bash
sf data import bulk \
  --file outputs/demo/import_data/20_PublicComplaints_Agent_Demo.csv \
  --sobject PublicComplaint \
  --target-org nepademoscratch \
  --wait 5
```

Expected results after load + agent processing:
- DEMO_PC_003, 008, 010: Substantive — generate response tasks
- DEMO_PC_004, 006, 007, 011, 012: Duplicate or Procedural — no tasks
- DEMO_PC_005: EJ_Tribal — routed to EJ queue, AI bypassed
- DEMO_PC_009: Procedural (support comment) — no task
```

### Step 5 — Set up the persistent live sandbox

This is separate from the scratch org (which expires). Create a persistent Developer Edition org or APS sandbox for evaluators to access.

```bash
# Deploy to persistent sandbox
sf org login web --alias nepadelive
sf project deploy start \
  --source-dir force-app \
  --target-org nepadelive \
  --wait 30

# Run the same import sequence against nepadelive
# (repeat Step 2 commands with --target-org nepadelive)
```

Create a read-only guest user profile so evaluators can log in without being able to modify data:
- Setup → Profiles → New Profile → clone "Minimum Access" → name it "NEPA Demo Guest"
- Grant read access to all NEPA objects
- Create a user with this profile and share the credentials in the submission

### Step 6 — Record the Loom video

**Recording checklist:**
- [ ] Org loaded with all demo data including Scene 5 comments
- [ ] Screen resolution 1920×1080, browser at 100% zoom
- [ ] Loom recording in HD
- [ ] Follow the script in `outputs/demo/carrie_placer_mine_demo_story.md` — use exact Setup Tell / Show / Landing Tell structure
- [ ] Total runtime: 22–28 minutes (4 scenes + Scene 5 = 5 scenes)
- [ ] Upload to YouTube (unlisted) or Loom; get shareable link
- [ ] Add the demo link to both the GitHub repo README and the SUBMISSION-NARRATIVE.md Readiness section

---

## Final Pre-Submission Checklist

Run through this before hitting submit at permittinginnovators.awardsplatform.com.

### Code
- [ ] All Apex tests pass (`sf apex run test --target-org nepadev --wait 30`)
- [ ] Deploy to a clean scratch org and confirm 15-minute estimate is still accurate
- [ ] No debug logs showing uncaught exceptions
- [ ] `NEPA_Comment_AI_Router` flow is activated
- [ ] `NEPA_Close_Administrative_Record` flow is activated

### GitHub repo
- [ ] `docs/decision-models/` directory exists and is publicly visible
- [ ] `ce_screening_rules.json` is valid JSON (paste into jsonlint.com)
- [ ] `agency_risk_rates.json` is valid JSON
- [ ] `gis-layers/README.md` is readable
- [ ] Top-level README links to the decision models directory
- [ ] License file present (MIT)

### Demo
- [ ] Carrie Placer Mine data loaded in live sandbox
- [ ] All 5 demo scenes walkable end-to-end
- [ ] Loom video recorded and link works from incognito browser
- [ ] Live sandbox guest user credentials documented

### Narrative (`SUBMISSION-NARRATIVE.md`)
- [ ] MFR 4 section includes GitHub link to `/docs/decision-models/`
- [ ] MFR 6 section names all 5 GIS services
- [ ] MFR 8 section describes the Agentforce comment agent
- [ ] Readiness section includes live sandbox URL and Loom video link
- [ ] Page count ≤ 6 pages at 12pt font / 1-inch margins (check in Google Docs or Word)
- [ ] "NEPATEC" spelling is consistent throughout — all instances should read "NETATEC v2.0"

### Submission form (permittinginnovators.awardsplatform.com)
- [ ] Solution name: `PSA-NEPA Permitting Accelerator: Open-Source Federal NEPA Intelligence Platform`
- [ ] Concept paper: uploaded as PDF from SUBMISSION-NARRATIVE.md
- [ ] Solution demonstration link: Loom video URL (primary) + GitHub repo URL
- [ ] Both checkboxes checked (rules agreement + Expo attendance)
- [ ] Solutions Catalog permission granted
- [ ] Submit before June 2, 2026
