# NEPA CE Screener — Decision Matrix Row Data

BRE Decision Matrix rows cannot be deployed via Metadata API or CLI. Use the Salesforce Setup UI to import these CSV files.

## Import Instructions

For each CSV file:

1. Go to **Setup → Business Rules Engine → Decision Matrices**
2. Open the corresponding Decision Matrix (e.g., `NEPA CE Screener - Tier 1 Agency Sector Rules`)
3. Click the active version (V1)
4. Click **Import CSV**
5. Upload the CSV from this directory
6. Map columns (they match by header name)
7. Click **Import**

## Files

| CSV File | Decision Matrix | Input Columns | Notes |
|---|---|---|---|
| `NEPA_CE_Screener_NAICS.csv` | NEPA CE Screener - NAICS Routing | `NAICSCode` | 7 seed rows covering common NAICS codes |
| `NEPA_CE_Screener_Tier1.csv` | NEPA CE Screener - Tier 1 Agency Sector Rules | `AgencyAbbr`, `SectorKey`, `TypeKey` | 17 rows covering BLM, USFS, DOE, USFWS, EPA |
| `NEPA_CE_Screener_Tier2.csv` | NEPA CE Screener - Tier 2 Agency Action Type Rules | `AgencyAbbr`, `ActionType` | 16 rows covering Modify Existing, New Authorization, Permit Renewal |

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
