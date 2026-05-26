# Carrie Placer Mine – Demo Import Data

**Demo Story:** Carrie Placer Mine Plan of Operations  
**Case:** DOI-LMTF-ID-B030-2019-0014-EA / IDI-38709  
**Lead Agency:** LMTF Owyhee Field Office, Marsing, Idaho  
**Applicants:** Sam Uhler and David Smith  
**Historical timeline:** 25 months (Oct 2017 → Nov 2019)  
**Demo timeline:** 8 months (Mar 2019 → Nov 2019)

---

## Quick Start

```bash
# Deploy metadata first
./scripts/deploy.sh NEPADEMO

# Then load demo data
./scripts/load-demo-data.sh NEPADEMO
```

---

## Full Import Order

Load files strictly in number order. Each file's parent records must exist before loading children.

| # | File | Object | Records | Upsert Key | Key Dependency |
|---|---|---|---|---|---|
| 02 | `02_Account.csv` | Account | 5 | `External_ID__c` | None |
| 03 | `03_Contact.csv` | Contact | 9 | `External_ID__c` | Account (02) |
| 05 | `05_WorkType.csv` | WorkType | 7 | `External_ID__c` | None |
| 06 | *(skipped — Apex step 18)* | ServiceResource | 1 | — | `RelatedRecordId` requires User ID; created by Apex with running user |
| 08 | `08_Program.csv` | Program | 1 | `nepa_project_id__c` | Account (02) |
| 09 | *(skipped — Apex step 18)* | IndividualApplication | 1 | — | `LicenseTypeId` requires runtime RegulatoryAuthorizationType ID |
| 10 | *(skipped — Apex step 18)* | ContentVersion | 6 | — | `VersionData` (Blob) cannot be set via Bulk API v2 CSV |
| 11 | `11_nepa_engagement__c.csv` | nepa_engagement__c | 5 | `External_ID__c` | `nepa_process__c` wired by Apex step 18 |
| 12 | `12_ApplicationTimeline.csv` | ApplicationTimeline | 25 | `External_ID__c` | `nepa_related_process__c` wired by Apex step 18 |
| 16 | `16_PublicComplaint.csv` | PublicComplaint | 3 | `External_ID__c` | Account (02), IndividualApplication (09) |
| 17 | `17_nepa_litigation__c.csv` | nepa_litigation__c | 2 | `External_ID__c` | Program (08) |
| 18 | `18_postload_polymorphic.apex` | **Apex script** | — | — | Run after all CSVs; wires polymorphic lookups |
| 19 | `19_Task.csv` | Task | 8 | `External_ID__c` | Loaded before or after Apex; WhatId/WhoId wired by step 18 |
| 20 | `20_entities789_demo_data.apex` | **Apex script** | — | — | Run after step 18; creates RegulatoryAuthority (4), RegulatoryCode (7 standalone Entity 9), nepa_process_team_member__c (7), nepa_gis_data__c (1 GIS container), Polygon (1), nepa_gis_data_element__c (5); wires Program lat/lon/polygon |
| 21 | `21_postload_discipline.apex` | **Apex script** | — | — | Run after step 18; sets ServiceResource.nepa_discipline__c = 'NEPA Specialist' on DEMO_SR_001 (demo constraint: all 7 specialists share one SR) |
| 22 | `22_postload_gis_team_assembly.apex` | **Apex script** | — | — | Run after steps 20–21; pre-seeds GIS proximity results (nepa_detected_protection_layer__c × 4), auto-assembled team members (× 3, GIS_Auto_Assembly), and auto-generated Visits (× 3, nepa_auto_generated__c = true) for the Carrie Placer Mine; sets Program nepa_extraordinary_circumstances__c = true and nepa_gis_proximity_complete__c = true |
| 23 | `23_postload_flow_refresh.apex` | **Apex script** | — | — | Run last; re-fires all IsChanged-gated flows (Risk Scorer, CE Screener, SLA Setter, Timeline Risk, Defensibility Checker) by toggling then restoring nepa_review_type__c. Populates nepa_risk_score_factors__c, nepa_screening_confidence__c, nepa_sla_due_date__c, nepa_timeline_risk_tier__c, nepa_defensibility_gaps__c, nepa_missing_documents__c, and related computed fields. |
| 24 | `24_decision_payload.csv` | nepa_decision_payload__c | 1 | upsert via `nepa_process__r.nepa_federal_unique_id__c` | IndividualApplication (09) — load after step 23 |
| 25 | `25_ar_export.csv` | nepa_ar_export__c | 1 | upsert via `nepa_process__r.nepa_federal_unique_id__c` | IndividualApplication (09) — load after step 24 |
| 26 | `26_backfill_external_ids.apex` | **Apex script** | — | — | Run once against an org that has existing demo data without External_ID__c values. Deduplicates ApplicationTimeline (keeps oldest 25), deletes stale nepa_engagement__c records, backfills External_ID__c on PublicComplaint (2) and nepa_litigation__c (2). Safe to re-run (all DML is conditional on null). After running, re-upsert steps 11–12, 16–17 normally. |
| 27 | `27_ofd_milestones.apex` | **Apex script** | — | — | Inserts 4 ApplicationTimeline OFD coordination milestone records for IDI-38709: Scoping Notice (NEPA_Lead/Completed), ESA §7 Initiation (Agency_Consultation/In Progress/USFWS), USACE Section 404 Pre-Application Meeting (Permit_Milestone/Scheduled/USACE), Record of Decision (Joint_ROD/Pending). Requires IndividualApplication and USFWS/USACE Account records to exist. Run after step 18. |
| 28 | `28_required_permits.apex` | **Apex script** | — | — | Inserts 2 `nepa_required_permit__c` records: DEMO_RP_001 (NPDES IDG370000, status=Issued) and DEMO_RP_002 (CWA Section 404, status=Pending). DEMO_RP_001 insert triggers `NEPA_Permit_Issued_Schedule_Creator` async — 4 inspection Visits created with Idaho state risk context in `nepa_trigger_layer__c`. Run after step 18. |
| 29 | `29_scene7_inspection_visits.apex` | **Apex script** | — | — | Pre-seeds 4 NPDES inspection Visit records as fallback if step-28 async flow did not fire. Detects existing Visits by Subject before inserting — safe to run after flow has executed. Each Visit includes Idaho state risk context in `nepa_state_risk_context__c` (Scene 7-B banner). Run after step 28. |
| 30 | `30_scene7_biop_reinit.apex` | **Apex script** | — | — | Sets `nepa_reinit_new_species_listing__c = TRUE` on the Critical Habitat auto-generated Visit from step 22 — fires `NEPA_BiOp_Reinitiation_Checker` async. Pre-seeds ESA Coordinator Task and sets `nepa_challenge_risk_delta__c = 12` as fallback. Run after step 29. |
| 31a | `31a_postload_atd.apex` | **Apex script** | — | — | Creates 28 `AssessmentTaskDefinition` records (one per unique task across all 7 NEPA Visit APTs). Idempotent. Run after Phase 8b APT metadata deploy. |
| 31b | `31b_postload_apt.apex` | **Apex script** | — | — | Creates 7 `ActionPlanTemplate` records (`ActionPlanType='Retail'`, `TargetEntityType='Visit'`), 7 `ActionPlanTemplateVersion` records (Status=Draft), and 28 `ActionPlanTemplateItem` records (4 per APT, `ItemEntityType=AssessmentTask`). Must run after 31a. If 31c previously failed and left Final versions with no values, run `31b_cleanup.apex` first to reset them, then re-run 31b. |
| 31c | `31c_postload_apt_values.apex` | **Apex script** | — | — | Inserts 56 `ActionPlanTemplateItemValue` records (2 per item: `AssessmentTask.AssessmentTaskDefinitionId` + `AssessmentTask.Name`), then publishes all 7 versions from Draft → Final. Idempotent. Run after 31b. |

---

## External ID Strategy

**Standard objects** — `External_ID__c` (capital ID) is a managed external ID field:
- Account, Contact, WorkType, ServiceResource, Task

**APS / custom objects** — use the domain natural ID or `External_ID__c`:
- `Program` → upsert on `nepa_project_id__c`
- `IndividualApplication` → upsert on `nepa_federal_unique_id__c`
- `ApplicationTimeline` → upsert on `External_ID__c` (`DEMO_AT_001`–`025`)
- `PublicComplaint` → upsert on `External_ID__c` (`DEMO_PC_001`–`003`)
- `nepa_engagement__c` → upsert on `External_ID__c` (`DEMO_ENG_001`–`005`)
- `nepa_litigation__c` → upsert on `External_ID__c` (`DEMO_LIT_001`–`002`)
- `ContentVersion` → **insert only** (no external ID); `VersionData` blob cannot be set via CSV

---

## Polymorphic Field Notes

The following fields cannot be set via CSV bulk upsert. `18_postload_polymorphic.apex` handles all of them:

| Field / Object | Why Apex | Resolution |
|---|---|---|
| ServiceResource `RelatedRecordId` | Requires User ID (not Contact) | Created with running user's ID; 1 SR for demo (APS enforces 1 Technician per User) |
| IndividualApplication `LicenseTypeId` | Org-specific `RegulatoryAuthorizationType` ID | Apex queries/creates "NEPA Environmental Review" RAT at runtime |
| ContentVersion `VersionData` | Bulk API v2 cannot supply base64 Blob in CSV | Created with `Blob.valueOf(' ')` placeholder; 6 documents including Comment Response required by FONSI gate CMT |
| Task `WhatId` / `WhoId` | Polymorphic lookups | Wired by querying IA and Contact IDs after all records exist |
| `nepa_process__c` | Cross-object wiring for engagement, timeline, complaint, CV | Wired by querying `nepa_federal_unique_id__c = 'IDI-38709'` |

Run the Apex script:
```bash
sf apex run --file demo/import_data/18_postload_polymorphic.apex --target-org <alias>
```

---

## Relationship Map

```
Account (02)
  ├── Contact.AccountId (03)
  ├── Program.AccountId (08)
  └── PublicComplaint.AccountId (16)

Contact (03)  [polymorphic — wired by Apex]
  ├── IndividualApplication.nepa_applicant_contact__c (09)
  ├── ServiceResource.RelatedRecordId (06)
  └── Task.WhoId (19)

ServiceResource (06)
  └── Visit.VisitorId (22) — auto-generated Visits from GIS assembly

Program (08)  [nepa_project_id__c = DOI-LMTF-ID-B030-2019-0014-EA]
  ├── IndividualApplication.nepa_related_project__c (09)
  └── nepa_litigation__c.nepa_related_project__c (17)

IndividualApplication (09)  [nepa_federal_unique_id__c = IDI-38709]
  ├── ContentVersion.nepa_process__c (10) — wired by Apex
  ├── nepa_engagement__c.nepa_process__c (11)
  ├── ApplicationTimeline.nepa_related_process__c (12)
  ├── PublicComplaint.nepa_related_process__c (16)
  ├── Task.WhatId (19) — wired by Apex
  ├── nepa_process_team_member__c.nepa_process__c (20) — 7 ID team members
  (RegulatoryCode × 7 are standalone Entity 9 records — no FK on IndividualApplication)

Program (08)  [also]
  ├── nepa_location_lat__c = 42.8701 (20)
  ├── nepa_location_lon__c = -116.9227 (20)
  ├── nepa_extraordinary_circumstances__c = true (22)
  ├── nepa_gis_proximity_complete__c = true (22)
  ├── nepa_protection_areas__c = "NWI Wetlands: … / FWS Critical Habitat: … / …" (22)
  ├── nepa_polygon__c → Polygon (20)
  │     └── nepa_gis_data_element__c.nepa_polygon__c (20) — 5 GIS layers
  ├── nepa_detected_protection_layer__c.nepa_program__c (22) — 4 records (1 per active layer)
  │     ├── NWI_Wetlands       [is_hit=true,  EC=true]  — Freshwater Emergent Wetland × 3
  │     ├── FWS_Critical_Habitat [is_hit=true, EC=true] — Greater Sage-Grouse Designated PHMA
  │     ├── EPA_Superfund_NPL  [is_hit=false, EC=false] — 0 features (rural Owyhee County)
  │     └── EJScreen_EJ_Index  [is_hit=true,  EC=false] — EJ Index = 18.3 (informational)
  └── nepa_gis_data__c.nepa_parent_project__c (20) — 1 GIS container (CEQ Entity 7)
        [also nepa_gis_data__c.nepa_parent_process__c → IndividualApplication (09)]

IndividualApplication (09)  [also — permits and Scene 7 from steps 28–30]
  ├── nepa_required_permit__c.nepa_process__c (28) — 2 records
  │     ├── DEMO_RP_001: CWA Section 402 NPDES / Issued  → triggers NEPA_Permit_Issued_Schedule_Creator
  │     └── DEMO_RP_002: CWA Section 404 / Pending
  └── Visit (nepa_auto_generated__c = true, nepa_discipline__c = 'Environmental Compliance') × 4 (28/29)
        ├── NPDES Quarterly Discharge Monitoring Report Review  (High, +90 days)
        ├── NPDES Stormwater Compliance Inspection              (High, +180 days)
        ├── Reclamation Progress Inspection                     (Medium, +365 days)
        └── Wetland Buffer Compliance Inspection                (High, +120 days)
            Each Visit.nepa_trigger_layer__c = Idaho Field_Inspector_Warning__c
            Each Visit.nepa_state_risk_context__c = full Idaho risk briefing text

IndividualApplication (09)  [also — GIS auto-assembly from step 22]
  ├── nepa_process_team_member__c (nepa_assembly_source__c = 'GIS_Auto_Assembly') × 3
  │     ├── Hydrologist            ← triggered by NWI_Wetlands layer
  │     ├── Wildlife Biologist (Sage-Grouse) ← triggered by FWS_Critical_Habitat layer
  │     └── NEPA Specialist        ← triggered by EJScreen_EJ_Index layer
  └── Visit (nepa_auto_generated__c = true) × 3 [ContextId = IndividualApplication]
        ├── Hydrology and Water Quality Assessment  (High)
        ├── Critical Habitat and Species Survey     (High)
        └── Environmental Justice Analysis          (Medium)
            Each Visit → ActionPlan via NepaVisitAfterInsert trigger + NepaVisitActionPlanLauncher
```

---

## Accounts Summary

| External_ID__c | Name | Role in Demo |
|---|---|---|
| DEMO_ACCT_001 | LMTF Owyhee Field Office | Lead agency — parent for Program, Visits, staff contacts |
| DEMO_ACCT_002 | Sam Uhler and David Smith | Permit applicant — applicant contact on IndividualApplication |
| DEMO_ACCT_003 | Idaho Conservation League | High-risk prior commenter — PublicComplaint DEMO_PC_001, litigation reference |
| DEMO_ACCT_004 | Office of Species Conservation | Agency commenter — PublicComplaint DEMO_PC_002 |
| DEMO_ACCT_005 | Shoshone-Paiute Tribes | Tribal consultation — nepa_engagement__c Section 106 event |

---

## Key Demo Moments → Data

| Demo Scene | Records |
|---|---|
| Sam books pre-app; system auto-assembles ID Team | `DEMO_ENG_001`; `DEMO_CON_001–007`; `DEMO_SR_001–007` |
| GIS check fires on lat/lon save; detects NWI Wetlands + FWS Critical Habitat → EC flag set | `nepa_detected_protection_layer__c` × 4; `Program.nepa_extraordinary_circumstances__c = true` |
| System auto-assembles ID Team from GIS results; creates 3 auto-generated Visits | GIS_Auto_Assembly `nepa_process_team_member__c` × 3; `nepa_auto_generated__c` Visit × 3 |
| Each auto-generated Visit gets an Action Plan via NepaVisitAfterInsert trigger | Visit × 3 → ActionPlan × 3; each ActionPlan has 4 AssessmentTasks from the discipline-specific Visit APT (steps 31a–31c) |
| Plaintiff Intelligence flags ICL; creates Task for legal review | `DEMO_PC_001`; `DEMO_TASK_004` |
| OSC comment creates Task for NEPA coordinator | `DEMO_PC_002`; `DEMO_TASK_005` |
| Required Document Registry all five green | Documents in ContentVersion load; `DEMO_TASK_007` |
| Field Manager issues Decision Record; applicant notified | ApplicationTimeline Decision Record event; `DEMO_TASK_008` |
| Decision payload shows FONSI, Alt B, 3 alternatives, 5 mitigations | `nepa_decision_payload__c` (step 24) |
| Administrative record package auto-generated at decision — 6 docs, 3 comments, status Completed | `nepa_ar_export__c` (step 25) |
| OFD Coordination Tracker shows 4 milestones across NEPA_Lead / Agency_Consultation / Permit_Milestone / Joint_ROD tracks | `ApplicationTimeline` OFD records (step 27) |
| NPDES permit issued → 4 inspection Visit tasks auto-scheduled | `DEMO_RP_001` (step 28); Visit × 4 auto-created by `NEPA_Permit_Issued_Schedule_Creator`; fallback pre-seeded by step 29 |
| Inspector opens Visit — state risk briefing shows Idaho litigation context | `nepa_state_risk_context__c` and `nepa_trigger_layer__c` on Visit (step 29); banner visible when field is non-blank |
| Biologist checks BiOp reinitiation trigger → ESA Task + risk delta +12 | `nepa_reinit_new_species_listing__c = TRUE` on Critical Habitat Visit (step 30); Task subject "ESA §7 Reinitiation Required — Review BiOp Compliance"; `nepa_challenge_risk_delta__c = 12` |
| AR lock at ROD → post-decision monitoring Tasks bulk-created | `nepa_ar_locked__c = TRUE` in CSV (step 09); `NEPA_PostDecision_Monitor_Scheduler` fired by flow-refresh toggle in step 23 |

---

## Verification Queries

```bash
TARGET=NEPADEMO

sf data query --target-org $TARGET \
  --query "SELECT Id, Name FROM Program WHERE nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'"

sf data query --target-org $TARGET \
  --query "SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM ContentVersion WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND IsLatest = true"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT nepa_layer_developer_name__c, nepa_is_hit__c, nepa_extraordinary_circumstances_triggered__c, nepa_feature_name__c FROM nepa_detected_protection_layer__c WHERE nepa_program__r.nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA' ORDER BY nepa_layer_developer_name__c"

sf data query --target-org $TARGET \
  --query "SELECT nepa_discipline__c, nepa_assembly_source__c, nepa_active__c FROM nepa_process_team_member__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND nepa_assembly_source__c = 'GIS_Auto_Assembly'"

sf data query --target-org $TARGET \
  --query "SELECT InstructionDescription, nepa_discipline__c, VisitPriority, Status FROM Visit WHERE nepa_auto_generated__c = true AND nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT Name, nepa_centroid_lat__c, nepa_centroid_lon__c, nepa_extent__c, nepa_data_source_system__c FROM nepa_gis_data__c WHERE nepa_parent_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT nepa_decision_type__c, nepa_decision_date__c, nepa_selected_alternative__c, nepa_alternatives_considered__c, nepa_significant_impacts__c FROM nepa_decision_payload__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT nepa_export_status__c, nepa_export_type__c, nepa_document_count__c, nepa_comment_count__c, nepa_completed_date__c FROM nepa_ar_export__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT nepa_ofd_track__c, nepa_event_type__c, nepa_status__c, nepa_coordinating_agency__r.Name FROM ApplicationTimeline WHERE nepa_ofd_track__c != null AND nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709' ORDER BY nepa_target_date__c"

# Step 28 — required permits
sf data query --target-org $TARGET \
  --query "SELECT External_ID__c, nepa_permit_type__c, nepa_permit_status__c, nepa_lead_agency__c FROM nepa_required_permit__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' ORDER BY External_ID__c"

# Step 29 — inspection Visits with state risk context
sf data query --target-org $TARGET \
  --query "SELECT Subject, Status, VisitPriority, nepa_trigger_layer__c, PlannedVisitStartTime FROM Visit WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND nepa_auto_generated__c = true ORDER BY PlannedVisitStartTime"

# Step 30 — BiOp reinitiation trigger and ESA Task
sf data query --target-org $TARGET \
  --query "SELECT nepa_reinit_new_species_listing__c, nepa_discipline__c FROM Visit WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND nepa_reinit_new_species_listing__c = true"

sf data query --target-org $TARGET \
  --query "SELECT Subject, Priority, ActivityDate, Status FROM Task WHERE What.nepa_federal_unique_id__c = 'IDI-38709' AND Subject LIKE 'ESA%'"

sf data query --target-org $TARGET \
  --query "SELECT nepa_challenge_risk_delta__c, nepa_ar_locked__c, nepa_has_active_biop__c, nepa_state_code__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'"

# Step 23 (post-decision Tasks fired by flow refresh)
sf data query --target-org $TARGET \
  --query "SELECT Subject, ActivityDate FROM Task WHERE What.nepa_federal_unique_id__c = 'IDI-38709' AND (Subject LIKE '%SWPPP%' OR Subject LIKE '%NPDES DMR%' OR Subject LIKE '%Reclamation%' OR Subject LIKE '%Adaptive Management%' OR Subject LIKE '%BiOp ITS%' OR Subject LIKE '%BiOp RPA%') ORDER BY ActivityDate"
```

Expected for step 27 (OFD milestones): 4 rows — NEPA_Lead / Agency_Consultation / Permit_Milestone / Joint_ROD.

Expected for step 28: 2 rows — DEMO_RP_001 (NPDES/Issued) and DEMO_RP_002 (CWA Section 404/Pending).

Expected for step 29: 4+ Visit rows with `nepa_trigger_layer__c` populated with Idaho warning text.

Expected for step 30: 1 Visit with `nepa_reinit_new_species_listing__c = true`; 1 Task with Subject "ESA §7 Reinitiation Required — Review BiOp Compliance"; IA with `nepa_challenge_risk_delta__c = 12`.

Expected for step 23 (post-decision Tasks): 6–10 Task rows from `NEPA_PostDecision_Monitor_Scheduler` covering SWPPP, NPDES DMR, Reclamation, Adaptive Management, BiOp ITS, BiOp RPA (depends on EA review type filter in flow).

```bash
# Steps 31a–31c — NEPA Visit Action Plan Templates
sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM AssessmentTaskDefinition WHERE Name LIKE '%Survey%' OR Name LIKE '%Lek%' OR Name LIKE '%Riparian%'"

sf data query --target-org $TARGET \
  --query "SELECT UniqueName, Name FROM ActionPlanTemplate WHERE UniqueName LIKE 'NEPA_Visit_%' ORDER BY UniqueName"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM ActionPlanTemplateVersion WHERE ActionPlanTemplateId IN (SELECT Id FROM ActionPlanTemplate WHERE UniqueName LIKE 'NEPA_Visit_%') AND Status = 'Final'"

sf data query --target-org $TARGET \
  --query "SELECT Name, TargetId FROM ActionPlan WHERE Name LIKE '%Field Survey%' ORDER BY CreatedDate DESC LIMIT 10"
```

Expected for steps 31a–31c: 28 `AssessmentTaskDefinition` records; 7 `ActionPlanTemplate` records with `NEPA_Visit_*` unique names; 7 `ActionPlanTemplateVersion` records with `Status = 'Final'`; 3 `ActionPlan` records (one per GIS-auto-generated Visit from step 22), each with 4 `AssessmentTask` items.

---

## Partial Import Recovery

If the load script fails midway, use the cleanup commands below to return to a clean state before retrying. The safest recovery is always full cleanup → full reload.

**Identify how far you got:**
```bash
TARGET=NEPADEMO

# Check which anchor records exist
sf data query --target-org $TARGET --query "SELECT Id FROM Program WHERE nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'"
sf data query --target-org $TARGET --query "SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'"
sf data query --target-org $TARGET --query "SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'"
```

**If failure is in steps 01–17 (CSV phase):** Run the full cleanup below, then re-run `load-demo-data.sh`.

**If failure is in steps 18–23 (Apex phase):** The CSV data is intact. Re-run the failing Apex script individually:
```bash
sf apex run --file demo/import_data/18_postload_polymorphic.apex --target-org $TARGET
sf apex run --file demo/import_data/20_entities789_demo_data.apex --target-org $TARGET
sf apex run --file demo/import_data/21_postload_discipline.apex   --target-org $TARGET
sf apex run --file demo/import_data/22_postload_gis_team_assembly.apex --target-org $TARGET
sf apex run --file demo/import_data/23_postload_flow_refresh.apex --target-org $TARGET
```
Apex scripts are idempotent for the step-20 entities (upsert-safe). Steps 18 and 22 may insert duplicates if retried after partial success — run full cleanup first if you see duplicate records.

**If failure is in steps 31a–31c (Visit APT phase):** These scripts are idempotent and safe to re-run individually. The one exception: if 31b ran and created Draft versions but 31c failed partway, subsequent runs of 31c may fail with "available for template versions in Draft state" if versions were partially published. In that case:
```bash
# Reset broken Final versions (no item values), then re-run 31b and 31c
sf apex run --file demo/import_data/31b_cleanup.apex --target-org $TARGET
sf apex run --file demo/import_data/31b_postload_apt.apex --target-org $TARGET
sf apex run --file demo/import_data/31c_postload_apt_values.apex --target-org $TARGET
```

**If re-importing fails with `DUPLICATE_VALUE` errors:** The cleanup below was not run completely or a prior import left orphaned records. Query for and delete any records matching the demo external IDs before reloading.

---

## Cleanup (reverse-dependency order)

```bash
TARGET=NEPADEMO

sf data delete bulk --sobject Task                   --where "External_ID__c LIKE 'DEMO_TASK_%'"  --target-org $TARGET --async
sf data delete bulk --sobject PublicComplaint         --where "External_ID__c LIKE 'DEMO_PC_%'"   --target-org $TARGET --async
sf data delete bulk --sobject nepa_litigation__c      --where "External_ID__c LIKE 'DEMO_LIT_%'"  --target-org $TARGET --async
sf data delete bulk --sobject ApplicationTimeline     --where "External_ID__c LIKE 'DEMO_AT_%'"   --target-org $TARGET --async
sf data delete bulk --sobject nepa_engagement__c      --where "External_ID__c LIKE 'DEMO_ENG_%'"  --target-org $TARGET --async
sf data delete bulk --sobject ContentVersion          --where "nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject IndividualApplication   --where "nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject Program                 --where "nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'" --target-org $TARGET --async
sf data delete bulk --sobject ServiceResource         --where "External_ID__c LIKE 'DEMO_SR_%'"    --target-org $TARGET --async
sf data delete bulk --sobject WorkType                --where "External_ID__c LIKE 'DEMO_WT_%'"    --target-org $TARGET --async
sf data delete bulk --sobject Contact                 --where "External_ID__c LIKE 'DEMO_CON_%'"   --target-org $TARGET --async
sf data delete bulk --sobject Account                 --where "External_ID__c LIKE 'DEMO_ACCT_%'"  --target-org $TARGET --async

# Steps 28–30 cleanup (run before IndividualApplication deletes above)
sf data delete bulk --sobject nepa_required_permit__c --where "External_ID__c LIKE 'DEMO_RP_%'" --target-org $TARGET --async
sf data delete bulk --sobject Task --where "Subject = 'ESA §7 Reinitiation Required — Review BiOp Compliance'" --target-org $TARGET --async
sf data delete bulk --sobject Task --where "Subject LIKE '%Post-Decision%' OR Subject LIKE '%SWPPP%' OR Subject LIKE '%NPDES DMR%' OR Subject LIKE '%Reclamation Progress%' OR Subject LIKE '%Adaptive Management%' OR Subject LIKE '%BiOp%'" --target-org $TARGET --async

# Step 22 cleanup (run before IndividualApplication deletes above)
sf data delete bulk --sobject Visit --where "nepa_auto_generated__c = true AND nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_process_team_member__c --where "nepa_assembly_source__c = 'GIS_Auto_Assembly' AND nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_detected_protection_layer__c --where "nepa_program__r.nepa_project_id__c = 'DOI-LMTF-ID-B030-2019-0014-EA'" --target-org $TARGET --async

# Step 20 cleanup (run before Program/IndividualApplication deletes above)
sf data delete bulk --sobject nepa_gis_data__c        --where "nepa_data_source_system__c = 'NEPA_GIS_Proximity_Check'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_gis_data_element__c --where "nepa_data_source_system__c IN ('BLM GeoBOE','NHD+ High Resolution','ArcGIS Online — SGMA PHMA','USFWS ArcGIS Online — ESA Critical Habitat','National Wetlands Inventory')" --target-org $TARGET --async
sf data delete bulk --sobject nepa_process_team_member__c --where "nepa_data_source_system__c = 'eNEPA'" --target-org $TARGET --async
sf data delete bulk --sobject Polygon                 --where "Name = 'Carrie Placer Mine Claim Boundary — IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject RegulatoryCode          --where "Name IN ('42 U.S.C. § 4321','40 CFR § 1501.5','40 CFR § 1501.9','43 CFR § 3809.11','16 U.S.C. § 1536(a)','54 U.S.C. § 306108','33 U.S.C. § 1342')" --target-org $TARGET --async
sf data delete bulk --sobject RegulatoryAuthority     --where "Name IN ('CEQ','DOI-LMTF','Congress','EPA')" --target-org $TARGET --async

# Steps 24–25 cleanup
sf data delete bulk --sobject nepa_ar_export__c       --where "nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_decision_payload__c --where "nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async

# Step 27 cleanup (OFD milestones — run before ApplicationTimeline and IndividualApplication deletes above)
sf data delete bulk --sobject ApplicationTimeline --where "nepa_ofd_track__c != null AND nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
```
