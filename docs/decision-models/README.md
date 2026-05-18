# NEPA CE Screener — Decision Model Exports

This directory contains design-time snapshots of the decision logic embedded in the PSA-NEPA Permitting Accelerator's Business Rules Engine (BRE). These are human-readable JSON exports of the Custom Metadata Type (CMT) records that drive CE/EA/EIS routing, litigation risk scoring, and extraordinary circumstances evaluation.

**These are not generated runtime outputs.** They are structured representations of the CMT-backed rules, published here to satisfy MFR #4 (Access to Screening Criteria) under the CEQ NEPA and Permitting Data and Technology Standard v1.2. Project sponsors can review the exact decision logic before submitting, enabling pre-submission project siting adjustments.

---

## BRE Components

The CE Screener BRE consists of three tiers:

| Tier | Component | Type | Records | Purpose |
|---|---|---|---|---|
| 1 | `NEPA_CE_Screener` Flow | Decision Matrix | 8 DMs | Routes projects to CE / EA / EIS by action type, acreage, and agency |
| 2 | `NEPA_CE_Screener` Expression Set | Expression Set | 3 ESs | Applies extraordinary circumstances triggers and CE code matching |
| 3 | `NEPA_Litigation_Risk_Scorer` Flow | Expression Set | 1 ES | Computes 0–100 litigation risk score from agency, circuit, statute, and plaintiff weights |

The backing CMT types:
- `CE_Screening_Rules__mdt` — 2,105 CE authority records across 79 agencies
- `CE_Code_Catalog__mdt` — CE code descriptions, regulatory citations, and sector applicability
- `Agency_Risk_Rates__mdt` — agency-level litigation loss rates (PermitTEC v0.1, PNNL)
- `Circuit_Court_Risk_Weights__mdt` — per-circuit risk multipliers
- `Statute_Risk_Weights__mdt` — ESA, NHPA, Clean Water Act, FLPMA risk factors
- `Challenge_Prediction_Rules__mdt` — extraordinary circumstances patterns from 761 NEPA cases
- `Agency_Scoping_Baseline__mdt` — per-agency median NOI-to-DEIS timelines (CEQ EIS dataset)

---

## Files in This Directory

### DMN Decision Tables (OMG DMN 1.3)

These XML files follow the [OMG Decision Model and Notation (DMN) 1.3](https://www.omg.org/spec/DMN/1.3/) standard. They can be opened and edited visually in [Camunda Modeler](https://camunda.com/download/modeler/) or any DMN-compatible tool, and serve as the authoritative human-readable representation of each Decision Matrix's row data. The row data in these files is the source of truth for the CSVs in `decision_matrix_rows/` that are loaded into the BRE at deploy time.

| File | Decision Matrix | Rows |
|---|---|---|
| `NEPA_CE_Screener_NAICS_Routing.xml` | NEPA CE Screener - NAICS Routing | 7 |
| `NEPA_CE_Screener_Tier1_Agency_Sector_Rules.xml` | NEPA CE Screener - Tier 1 Agency Sector Rules | 17 |
| `NEPA_CE_Screener_Tier2_Agency_Action_Type_Rules.xml` | NEPA CE Screener - Tier 2 Agency Action Type Rules | 16 |
| `NEPA_Permit_Matrix.xml` | NEPA Permit Matrix | 9 |
| `NEPA_Risk_Scorer_Agency_Risk_Points.xml` | NEPA Risk Scorer - Agency Risk Points | 7 |
| `NEPA_Risk_Scorer_Circuit_Risk_Points.xml` | NEPA Risk Scorer - Circuit Risk Points | 13 |
| `NEPA_Risk_Scorer_Review_Type_Points.xml` | NEPA Risk Scorer - Review Type Points | 4 |
| `NEPA_Risk_Scorer_Sector_Circuit_Risk_Points.xml` | NEPA Risk Scorer - Sector Circuit Risk Points | 17 |

### JSON Design Snapshots (legacy)

These pre-date the DMN exports and capture the broader BRE topology including Expression Set scoring weights. Retained for reference; the DMN files above supersede them for Decision Matrix content.

| File | Description |
|---|---|
| `NEPA_Litigation_Risk_ES.json` | Expression Set: 0–100 litigation risk score formula with agency, circuit, statute, and plaintiff weights |
| `ce-screening-rules.json` | CE authority rules snapshot (2,105 records across 79 agencies) |
| `gis-layers-inventory.json` | GIS proximity layer inventory with API endpoints |
| `litigation-risk-weights.json` | Per-agency and per-circuit litigation duration and win-rate weights |

---

## Schema

Each file follows this structure:

```json
{
  "component": "<metadata developer name>",
  "type": "<DecisionMatrix | ExpressionSet>",
  "description": "<human-readable description>",
  "dataSource": "<CMT type or corpus citation>",
  "lastUpdated": "<YYYY-MM-DD>",
  "rows": [ ... ]
}
```

For Decision Matrix exports, each `row` has `conditions` (input match criteria) and `outcome` (routed result). For Expression Set exports, each `row` has `variable`, `weight`, `formula`, and `basis` fields.

---

## GIS Data Layers

The five GIS proximity checks that fire at CE intake (Step 6 of the OmniScript CE Intake Wizard) use publicly accessible data layers:

| Check | Data Source | Access |
|---|---|---|
| Critical habitat | FWS ECOS Species + Critical Habitat API | Public, no auth |
| Environmental Justice | EPA EJScreen API v2 | Public, no auth |
| Waterways / NHD | USGS National Hydrography Dataset | Public, no auth |
| Tribal boundaries | BLM Tribal Cadastral Layer | Public, no auth |
| Surface ownership | BLM PLSS / GeoCommunicator | Public, no auth |

All five calls are made at OmniScript submission via the `NEPA_GIS_Proximity_Checker` Apex class. Results are written to `nepa_gis_*` fields on the `IndividualApplication` record and included in the CE pre-screening result card returned to the applicant before formal submission.

---

## Updating Decision Logic

Because all weights and routing rules are stored in Custom Metadata Types, changes to screening criteria require zero code changes:

1. Update the relevant CMT record in Setup → Custom Metadata Types
2. The BRE reads the updated record on the next invocation — no deployment required
3. Changes are audit-logged via Salesforce Setup Audit Trail

To update CE authority records (e.g., add a new agency's CE codes): import the new `CE_Screening_Rules__mdt` records via `sf data import` or Setup UI. The 2,105 records in the current dataset are pre-seeded during deployment from `/force-app/main/default/customMetadata/`.
