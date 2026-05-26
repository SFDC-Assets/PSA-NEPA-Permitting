# Session Status — 2026-05-24

## Branch: main
54 commits ahead of origin/main (not yet pushed)

---

## What was accomplished this session

### 1. Demo data load — fully clean on DEPLOYTEST2 and DEPLOYTEST3

`bash scripts/load-demo-data.sh DEPLOYTEST2` and DEPLOYTEST3 pass all 28 steps
with zero errors. Key fixes:

- **`Schema.Location` type conflict** — In anonymous Apex, bare `Location`
  resolves to `System.Location` (geolocation primitive). Fixed by using
  `Schema.Location` as type prefix in steps 18, 22, 29.
- **Location SObject has no address fields** — Removed `Street`, `City`,
  `PostalCode` from all Location inserts; kept only `Name`, `LocationType`,
  `IsInventoryLocation`.
- **ApplicationTimeline picklist values** — Fixed invalid values in
  `27_ofd_milestones.apex`: `'Scoping Notice Published'` → `'Scoping Open'`,
  etc. Also added required `Name` field.
- **Removed steps 24 and 25** from `load-demo-data.sh` — redundant CSV
  upserts for `nepa_decision_payload__c` and `nepa_ar_export__c`; step 27
  Apex handles both (Bulk API v2 can't use relationship-path external ID keys
  as upsert key on these objects).

### 2. Full deployment pipeline — verified clean on DEPLOYTEST3 and DEPLOYTEST4

`bash scripts/deploy.sh DEPLOYTEST3` and DEPLOYTEST4 both exit code 0.

Root cause found and fixed: **~23 custom objects had both a flat
`.object-meta.xml` AND a subdirectory**. The Metadata API ignores inline
`<fields>` blocks in flat files when a directory exists, so fields never
deployed. Fix pattern: delete duplicate flat file, copy into directory as
inner `<obj>/<obj>.object-meta.xml`, extract all inline fields to individual
`fields/<field>.field-meta.xml` files.

Objects fixed (committed `47388e5`):
- nepa_engagement__c (25 field files extracted)
- nepa_litigation__c (18 field files extracted)
- NEPA_Flow_Error__c (7 fields)
- nepa_ar_export__c (10 fields)
- nepa_comment_attribution__c (3 fields)
- nepa_decision_element__c (30 fields)
- nepa_decision_log__c (19 fields)
- nepa_decision_modification__c (10 fields)
- nepa_decision_payload__c (18 fields)
- nepa_gis_data__c (23 fields)
- nepa_process_related_agencies__c (5 fields)
- nepa_project_agency_relationship__c (2 fields)
- nepa_project_analogous_case__c (6 fields)
- ApplicationTimeline, ContentVersion, IndividualApplication, Program,
  PublicComplaint, nepa_ce_library__c, nepa_gis_data_element__c,
  nepa_process_team_member__c, NEPA_Permit_Matrix__mdt,
  NEPA_Permit_Type_Catalog__mdt (inner object-meta.xml added, no inline fields)

### 3. PathAssistant fix (DEPLOYTEST4)

`IndividualApplication_NEPA_Process_Path.pathAssistant-meta.xml` — `<info>`
was appearing before `<fieldValue>` in each step block. Salesforce Metadata
API requires `<fieldValue>` first. Fixed for all 18 steps (committed `afaadcb`).

### 4. nepa_required_permit__c metadata synced from org

Retrieved org round-trip added picklist values to `nepa_permit_type__c`
(populated by `NEPA_Permit_Record_Creator` flow running against seed data),
`actionOverrides` normalization, and `trackTrending` flags (committed `afaadcb`).

---

## Known persistent failures (all `allow-failure` — do not block pipeline)

| Item | Reason | Resolution |
|---|---|---|
| `NEPA_Litigation_Risk_Scorer` | Expression Set not active | Manual activation in Setup → Expression Sets |
| `NEPA_Slack_Risk_Alert` | Slack managed package not installed | Install Salesforce for Slack from AppExchange |
| `NEPA_Slack_Stage_Notifier` | Slack managed package not installed (UNKNOWN_EXCEPTION) | Same |
| 5 BLM APTs (`NEPA_WO_*_BLM`) | Target object requires FSL WorkOrder setup | FSL licensing / setup |
| `NEPA_BiOp_Reinitiation_Checker` | Transient UNKNOWN_EXCEPTION (pod routing) | Re-run: `sf project deploy start --metadata "Flow:NEPA_BiOp_Reinitiation_Checker" --target-org <alias> --test-level NoTestRun --wait 30` |
| `NEPA_Permit_Issued_Schedule_Creator` | Transient UNKNOWN_EXCEPTION | Same pattern |
| `NEPA_PostDecision_Monitor_Scheduler` | Transient UNKNOWN_EXCEPTION | Same pattern |
| Layout `Required_Permits__r` | Metadata API timing issue at deploy; re-deploy succeeds | Re-run layout deploy after full pipeline |
| FlexiPage `All_IndividualApplications` | Standard list view not yet created in fresh org | Create list view or accept warning |
| FlexiPage `cxInCustomGuidanceCenter` | Managed package component (CX Platform) not installed | Uninstall or skip |

---

## Commits to push (54 total, all on main)

Most recent 4 commits this session:
- `afaadcb` Fix PathAssistant element order and sync nepa_required_permit__c metadata from org
- `0d6b831` Remove stale FSL references after WorkOrder-to-Visit migration
- `47388e5` Fix object metadata structure: extract inline fields to directory format
- `0ec60f9` Remove redundant CSV upsert steps 24 and 25 from demo load

**NOT committed / NOT pushed:** `docs/COMPETITIVE-FEATURE-ROADMAP.md` —
permanently in `.gitignore`, never commit.

---

## OmniStudio Backlog Reclassification (2026-05-25)

All documentation has been updated to accurately reflect that OmniStudio components (DataRaptors, Integration Procedures, OmniScript) are backlog — not delivered. Key changes:

- Created `docs/OMNISTUDIO-BACKLOG.md` — canonical reference for all 4 backlog features (F1 CE Intake Wizard, F2 GIS Proximity IP, F3 CEQ DataRaptor export, F4 Pre-App Screening IP)
- Updated `SUBMISSION-NARRATIVE.md` — MFR #2, #3, Readiness section, User-Centered Design, Proposed Solution Approach
- Updated `QUICKSTART.md` — Phase 8c table, section 4f (OmniScript activation), 4h (site picker), 4i (NAICS picker)
- Updated `NEPA-Permitting-Acceleration-Plan.md` — Priority 2, 5, and 10 sections
- Updated `CE-INTAKE-OMNISCRIPT-SPEC.md` — added backlog header
- Updated `GIS-Proximity-Guide.md` — added backlog header
- Updated `ARCHITECTURE_DECISIONS.md` — ADR 005 and ADR 011 status notes
- Updated `NEPA-Portal-Component-Manifest.md` — added backlog header
- Updated `TESTING-GUIDE.md` — sections 16 (GIS) and 22b (site picker) marked backlog
- Updated `build_status.md` memory — OmniStudio moved from delivered to backlog

What remains delivered: CE screening via BRE/Flow, all 40+ flows, GIS layer catalog (`NEPA_GIS_Layer__mdt`), `nepa_gis_data__c` schema, CEQ REST export via Apex (`NepaCeqExportService`).

---

## Outstanding tasks

- [ ] Push 54 commits to `origin/main`
- [ ] Run `bash scripts/load-demo-data.sh DEPLOYTEST4` to verify end-to-end on DEPLOYTEST4
- [ ] Retry 4 transient flow deploys on DEPLOYTEST4 (BiOp, PermitIssuedScheduleCreator, PostDecisionMonitor, SlackStageNotifier)
- [ ] Fix layout `Required_Permits__r` failure — investigate whether a deploy-order change in `deploy.sh` resolves it cleanly (currently re-deploy works; first-pass fails)

---

## Verification queries (run against any test org)

```bash
TARGET=DEPLOYTEST4

sf data query --query "SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET
sf data query --query "SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET
sf data query --query "SELECT COUNT() FROM ContentVersion WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND IsLatest = true" --target-org $TARGET
sf data query --query "SELECT COUNT() FROM nepa_required_permit__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET
```

Expected (after demo data load): IA risk score 87.4 High, 29 ApplicationTimeline records, 6 ContentVersions, 2+ required permits.
