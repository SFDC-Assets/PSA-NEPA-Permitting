# NEPA BRE — Decision Matrix Row Data

BRE Decision Matrix rows cannot be deployed via Metadata API or CLI. Use the Salesforce Setup UI to import these CSV files into the corresponding Decision Matrix versions.

## Activation Requirement (CRITICAL)

Deploying DM or Expression Set metadata via Metadata API does **not** create the `LatestVersionSnapshotId` that the BRE runtime requires. Without this snapshot the BRE engine fails at runtime with:

```
Cannot invoke "RulesEngineInputInterview.getDecisionInterviewMap()" because
"rulesEngineInputInterview" is null
```

This is a Salesforce platform limitation — there is no CLI workaround.

**After every Metadata API deploy of BRE assets, you must:**

1. Go to **Setup → Business Rules Engine → Decision Matrices**
2. Open each DM, click the deployed version, and click **Activate**
3. Go to **Setup → Business Rules Engine → Expression Sets**
4. Open each ES, click the deployed version, and click **Activate**

Only after UI activation will the BRE runtime initialize correctly.

## Import Instructions

For each CSV file:

1. Go to **Setup → Business Rules Engine → Decision Matrices**
2. Open the corresponding Decision Matrix
3. Click the active version (V1)
4. Click **Import CSV**
5. Upload the CSV from this directory (`decision_matrix_rows/`)
6. Map columns (they match by header name)
7. Click **Import**

## Files

| CSV File | Decision Matrix | Input Columns | Notes |
|---|---|---|---|
| `NEPA_CE_Screener_NAICS.csv` | NEPA CE Screener - NAICS Routing | `NAICSCode` | 7 seed rows covering common NAICS codes |
| `NEPA_CE_Screener_Tier1.csv` | NEPA CE Screener - Tier 1 Agency Sector Rules | `AgencyAbbr`, `SectorKey`, `TypeKey` | 17 rows covering BLM, USFS, DOE, USFWS, EPA |
| `NEPA_CE_Screener_Tier2.csv` | NEPA CE Screener - Tier 2 Agency Action Type Rules | `AgencyAbbr`, `ActionType` | 16 rows covering Modify Existing, New Authorization, Permit Renewal |
| `NEPA_Risk_ReviewType.csv` | NEPA Risk Scorer - Review Type Points | `ReviewType` | 4 rows: EIS=40, EA=20, CE=5, Other=3 |
| `NEPA_Risk_Agency.csv` | NEPA Risk Scorer - Agency Risk Points | `AgencyName` | 6 rows using picklist abbreviations (USFS=25, BLM=23, FERC=15, USACE=12, USFWS=10, Default=5); values must match `Program.nepa_record_owner_agency__c` picklist |
| `NEPA_Risk_Circuit.csv` | NEPA Risk Scorer - Circuit Risk Points | `CircuitKey` | 13 rows sourced from NEPA_Circuit_Risk_Weight__mdt; wildcard default row (DEFAULT, MatchScore=0) |
| `NEPA_Permit_Matrix_BRE.csv` | NEPA Permit Matrix | `Sector`, `ProjectType` | 9 rows mirroring NEPA_Permit_Matrix__mdt |

## Demo Record Routing

For IDI-38709 (IA-0000000432):
- Agency: `BLM` | Sector: `Agriculture and Natural Resource Management` | TypeKey: `Mineral Extraction - Placer Mining` | NAICS: `212111` | ActionType: `Modify Existing`
- **NAICS lookup** → `CE` (43 CFR 3809.10(e), High confidence)
- **Tier1 lookup** → `CE` (43 CFR 3809.10(e), High confidence)
- Expected recommendation: `CE-Recommended`

## Output Value Reference

| ES Output | Flow writes to | Picklist values |
|---|---|---|
| `ReviewType` (CE/EA/EIS) | `nepa_ce_pathway_recommendation__c` (mapped to CE-Recommended/EA-Required/EIS-Required) | Restricted picklist |
| `CECode` | `nepa_process_code__c` | Free text |
| `Confidence` | `nepa_screening_confidence__c` | High / Medium-High / Medium / Low |
| `ClassificationBasis` | `nepa_classification_basis__c` | Free text |
