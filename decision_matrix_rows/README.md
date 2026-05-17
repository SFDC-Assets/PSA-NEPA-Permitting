# NEPA BRE — Decision Matrix Row Data

A **Decision Matrix** is a Salesforce Business Rules Engine (BRE) component that maps input conditions to output values using a table of rows — similar to a lookup table with multiple condition columns. The BRE (Business Rules Engine) evaluates these rows at runtime to produce recommendations like CE/EA/EIS review type or risk scores.

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
6. Map columns (they match by header name — column headers are case-sensitive and must exactly match the Decision Matrix input column names listed in the table below)
7. Click **Import**
8. Verify the import succeeded by checking the row count in the Decision Matrix version matches the CSV row count (minus the header row)

## Files

| CSV File | Decision Matrix | Input Columns | Notes |
|---|---|---|---|
| `NEPA_CE_Screener_NAICS.csv` | NEPA CE Screener - NAICS Routing | `NAICSCode` | 7 seed rows covering common NAICS codes |
| `NEPA_CE_Screener_Tier1.csv` | NEPA CE Screener - Tier 1 Agency Sector Rules | `AgencyAbbr`, `SectorKey`, `TypeKey` | 17 rows covering BLM, USFS, DOE, USFWS, EPA |
| `NEPA_CE_Screener_Tier2.csv` | NEPA CE Screener - Tier 2 Agency Action Type Rules | `AgencyAbbr`, `ActionType` | 16 rows covering Modify Existing, New Authorization, Permit Renewal |
| `NEPA_Risk_ReviewType.csv` | NEPA Risk Scorer - Review Type Points | `ReviewType` | 4 rows: EIS=40, EA=20, CE=5, Other=3 |
| `NEPA_Risk_Agency.csv` | NEPA Risk Scorer - Agency Risk Points | `AgencyName` | 6 rows using picklist abbreviations (USFS=25, BLM=23, FERC=15, USACE=12, USFWS=10, Default=5); values must match `Program.nepa_record_owner_agency__c` picklist |
| `NEPA_Risk_Circuit.csv` | NEPA Risk Scorer - Circuit Risk Points | `CircuitKey` | 13 rows sourced from NEPA_Circuit_Risk_Weight__mdt; wildcard default row (DEFAULT, MatchScore=0) — the wildcard row is a catch-all fallback that fires when no other row matches, preventing a "No matching row" runtime error |
| `NEPA_Permit_Matrix_BRE.csv` | NEPA Permit Matrix | `Sector`, `ProjectType` | 9 rows mirroring NEPA_Permit_Matrix__mdt |
| `NEPA_Risk_SectorCircuit.csv` | NEPA Risk Scorer - Sector Circuit Risk Points | `SectorCircuitKey` | 17 rows: composite `Sector\|Circuit` key → WinRatePct, CaseCount, RiskCellLabel; wildcard `*` default row. Used by BRE V3 SectorCircuitTerm. **Import only after activating NEPA_Risk_SectorCircuit DM V1. Keep ES V3 in Draft until after import and sandbox validation.** |

## Demo Record Routing

The record IDs below (`IDI-38709`, `IA-0000000432`) come from the Carrie Placer Mine demo dataset in `demo/import_data/`. If you have not loaded the demo data, use any `IndividualApplication` record ID from your org for routing validation.

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

---

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `Cannot invoke "RulesEngineInputInterview.getDecisionInterviewMap()" because "rulesEngineInputInterview" is null` | BRE runtime has no snapshot — DM/ES deployed via CLI but never activated via UI | Open each DM and ES in Setup → Business Rules Engine, open the deployed version, and click **Activate** |
| `INVALID_FIELD: No such column 'NAICSCode'` during CSV import | Column header in CSV doesn't match the DM input column name exactly | Check that the CSV header row matches the column names in the Files table above — they are case-sensitive. You can view the exact expected column names by opening the Decision Matrix version in Setup → BRE → Decision Matrices → [matrix name] → V1 before importing |
| CSV import completes but zero rows appear | Wrong DM version selected — imported into an inactive version | Open the DM, confirm you clicked the correct active version (V1 after first UI activation), then re-import |
| CE Screener returns no recommendation | Decision Matrix rows not imported yet, or Expression Set not activated | Confirm all 7 CSVs are imported and all Expression Sets are activated in Setup → BRE |
| `NEPA_Risk_Agency.csv` rows have no effect | Agency value in `Program.nepa_record_owner_agency__c` doesn't match the picklist abbreviation in the CSV | Verify the agency abbreviation in the CSV matches the picklist value exactly: `USFS`, `BLM`, `FERC`, `USACE`, `USFWS`; unmatched rows fall through to the `Default=5` wildcard row |
| Import button is greyed out | Decision Matrix version is already active with a snapshot | Deactivate the version, import the CSV, then reactivate |
