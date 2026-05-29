# Multicase Demo Data

Six NEPA cases covering all three review types across four agencies. Cases A–E are extracted from the `nepadata/samples` corpus; case F is a synthetic FAA EIS demonstrating aviation sector compliance, engagement events, and public comments. These supplement the primary Carrie Placer Mine case study (in `demo/import_data/`) with a diverse portfolio.

## Cases

| Case | Review Type | Agency | Sector | Project |
|------|------------|--------|--------|---------|
| `case_A_ce_blm` | **CE** | BLM (Buffalo FO) | Rangeland Management | Sahara Draw Allotment Grazing Lease Renewal |
| `case_B_ea_blm` | **EA** | BLM (Arizona) | Renewable Energy — Solar | Pinyon Solar Project |
| `case_C_ea_doe` | **EA** | DOE | Materials & Manufacturing | APEX Battery Manufacturing Plant (NexGen Battery Materials, KY) |
| `case_D_eis_blm` | **EIS** | BLM (Nevada) | Mining — Metals | Arturo Mine Project (Summit Metals Joint Venture, Elko County NV) |
| `case_E_ea_usda` | **EA** | USDA Forest Service | Vegetation / Fuels | SKILLEM Integrated Resource Restoration (Douglas County, OR) |
| `case_F_eis_faa` | **EIS** | FAA | Transportation — Aviation | Denver TRACON Airspace Redesign (Denver Metro Area, CO) |

## Files per case

Core files present in all cases:

| File | Object | Records | External ID |
|------|--------|---------|-------------|
| `02_Account.csv` | Account | 1–2 | `External_ID__c` = `SAMPLE_ACCT_<CASE>_NN` |
| `08_Program.csv` | Program | 1 | `nepa_project_id__c` = `SAMPLE-<UUID8>` |
| `09_IndividualApplication.csv` | IndividualApplication | 1 | `nepa_federal_unique_id__c` = `SAMPLE-<UUID8>` |
| `10_ContentVersion.csv` | ContentVersion | 1–4 | `nepa_document_key__c` = `SAMPLE-DOC-<UUID8>` |
| `12_ApplicationTimeline.csv` | ApplicationTimeline | 5–9 | `External_ID__c` = `SAMPLE_<CASE>_AT_NN` |

Additional files present in case_F (and loadable in any case that includes them):

| File | Object | Records | External ID |
|------|--------|---------|-------------|
| `11_nepa_engagement__c.csv` | nepa_engagement__c | 2–5 | `External_ID__c` = `DEMO_<CASE>_ENG_NN` |
| `16_PublicComplaint.csv` | PublicComplaint | 1–3 | `External_ID__c` = `DEMO_<CASE>_PC_NN` |

## Load order (all cases at once)

```bash
./scripts/load-multicase-demo.sh <org-alias>
```

Or run a single case (example uses case_F which has all file types):

```bash
TARGET=NEPADEMO
CASE=demo/import_data/multicase/case_F_eis_faa

sf data upsert bulk -s Account               -f "$CASE/02_Account.csv"               -i External_ID__c             -o $TARGET -w 10
sf data upsert bulk -s Program               -f "$CASE/08_Program.csv"               -i nepa_project_id__c         -o $TARGET -w 10
sf data upsert bulk -s IndividualApplication -f "$CASE/09_IndividualApplication.csv"  -i nepa_federal_unique_id__c  -o $TARGET -w 10
sf data upsert bulk -s ApplicationTimeline   -f "$CASE/12_ApplicationTimeline.csv"    -i External_ID__c             -o $TARGET -w 10
sf data upsert bulk -s nepa_engagement__c    -f "$CASE/11_nepa_engagement__c.csv"     -i External_ID__c             -o $TARGET -w 10
sf data upsert bulk -s PublicComplaint       -f "$CASE/16_PublicComplaint.csv"        -i External_ID__c             -o $TARGET -w 10
# ContentVersion requires Apex post-load (VersionData is a Blob):
sf apex run --file demo/import_data/multicase/10_postload_content_versions.apex -o $TARGET
```

## Regenerating CSVs

```bash
SAMPLES=/path/to/nepadata/samples

python3 scripts/extract_demo_from_samples.py \
  --file "$SAMPLES/sample_CE_BLM.jsonl" \
  --project-id c7c614db-06e2-8d10-5b70-73b4236514a0 \
  --case-name case_A_ce_blm

python3 scripts/extract_demo_from_samples.py \
  --file "$SAMPLES/sample_EA_BLM.jsonl" \
  --project-id e70ea3ad \
  --case-name case_B_ea_blm

python3 scripts/extract_demo_from_samples.py \
  --file "$SAMPLES/sample_EA_DOE.jsonl" \
  --project-id a8f2a17d \
  --case-name case_C_ea_doe

python3 scripts/extract_demo_from_samples.py \
  --file "$SAMPLES/sample_EIS_BLM.jsonl" \
  --project-id 13839469 \
  --case-name case_D_eis_blm

python3 scripts/extract_demo_from_samples.py \
  --file "$SAMPLES/sample_EA_USDA.jsonl" \
  --project-id 13438d6b \
  --case-name case_E_ea_usda
```

## Cleanup

```bash
sf data query --query "SELECT Id FROM ApplicationTimeline WHERE External_ID__c LIKE 'SAMPLE_%'" -o NEPADEMO --json \
  | jq -r '.result.records[].Id' \
  | xargs -I{} sf data delete record -s ApplicationTimeline -i {} -o NEPADEMO

sf data query --query "SELECT Id FROM ContentVersion WHERE nepa_document_key__c LIKE 'SAMPLE-DOC-%'" -o NEPADEMO --json \
  | jq -r '.result.records[].Id' \
  | xargs -I{} sf data delete record -s ContentVersion -i {} -o NEPADEMO

sf data query --query "SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c LIKE 'SAMPLE-%'" -o NEPADEMO --json \
  | jq -r '.result.records[].Id' \
  | xargs -I{} sf data delete record -s IndividualApplication -i {} -o NEPADEMO

sf data query --query "SELECT Id FROM Program WHERE nepa_project_id__c LIKE 'SAMPLE-%'" -o NEPADEMO --json \
  | jq -r '.result.records[].Id' \
  | xargs -I{} sf data delete record -s Program -i {} -o NEPADEMO

sf data query --query "SELECT Id FROM Account WHERE External_ID__c LIKE 'SAMPLE_ACCT_%'" -o NEPADEMO --json \
  | jq -r '.result.records[].Id' \
  | xargs -I{} sf data delete record -s Account -i {} -o NEPADEMO
```

## Source corpus

JSONL files at `/path/to/nepadata/samples/` — 1,489 real NEPA projects from BLM, DOE, and USDA across CE, EA, and EIS review types. Extracted via `scripts/extract_demo_from_samples.py`.
