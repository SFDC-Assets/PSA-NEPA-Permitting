# Carrie Placer Mine – Demo Import Data

**Demo Story:** Carrie Placer Mine Plan of Operations  
**Case:** DOI-BLM-ID-B030-2019-0014-EA / IDI-38709  
**Lead Agency:** BLM Owyhee Field Office, Marsing, Idaho  
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
| 01 | `01_OperatingHours.csv` | OperatingHours | 1 | `External_ID__c` | None |
| 02 | `02_Account.csv` | Account | 5 | `External_ID__c` | None |
| 03 | `03_Contact.csv` | Contact | 9 | `External_ID__c` | Account (02) |
| 04 | `04_ServiceTerritory.csv` | ServiceTerritory | 1 | `External_ID__c` | OperatingHours (01) |
| 05 | `05_WorkType.csv` | WorkType | 7 | `External_ID__c` | None |
| 06 | *(skipped — Apex step 18)* | ServiceResource | 1 | — | `RelatedRecordId` requires User ID; created by Apex with running user |
| 07 | *(skipped — Apex step 18)* | ServiceTerritoryMember | 1 | — | Depends on ServiceResource created in step 18 |
| 08 | `08_Program.csv` | Program | 1 | `nepa_project_id__c` | Account (02) |
| 09 | *(skipped — Apex step 18)* | IndividualApplication | 1 | — | `LicenseTypeId` requires runtime RegulatoryAuthorizationType ID |
| 10 | *(skipped — Apex step 18)* | ContentVersion | 6 | — | `VersionData` (Blob) cannot be set via Bulk API v2 CSV |
| 11 | `11_nepa_engagement__c.csv` | nepa_engagement__c | 5 | insert (no ext ID) | `nepa_process__c` wired by Apex step 18 |
| 12 | `12_ApplicationTimeline.csv` | ApplicationTimeline | 125 | insert (no ext ID) | `nepa_related_process__c` wired by Apex step 18 |
| 13 | `13_WorkOrder.csv` | WorkOrder | 10 | `External_ID__c` | Account (02), ServiceTerritory (04), WorkType (05) |
| 14 | *(skipped — Apex step 18)* | ServiceAppointment | 10 | — | `ParentRecordId` polymorphic; Bulk API v2 cannot resolve via external ID |
| 15 | *(skipped — Apex step 18)* | AssignedResource | 10 | — | Depends on ServiceAppointments created in step 18 |
| 16 | `16_PublicComplaint.csv` | PublicComplaint | 2 | insert (no ext ID) | Account (02), IndividualApplication (09) |
| 17 | `17_nepa_litigation__c.csv` | nepa_litigation__c | 2 | insert (no ext ID) | Program (08) |
| 18 | `18_postload_polymorphic.apex` | **Apex script** | — | — | Run after all CSVs; wires polymorphic lookups |
| 19 | `19_Task.csv` | Task | 8 | `External_ID__c` | Loaded before or after Apex; WhatId/WhoId wired by step 18 |
| 20 | `20_entities789_demo_data.apex` | **Apex script** | — | — | Run after step 18; creates RegulatoryAuthority (4), RegulatoryCode (7), nepa_process_team_member__c (7), Polygon (1), nepa_gis_data_element__c (5); wires Program lat/lon/polygon and IndividualApplication.nepa_legal_structure__c |

---

## External ID Strategy

**FSL / standard objects** — `External_ID__c` (capital ID) is a managed external ID field:
- OperatingHours, Account, Contact, ServiceTerritory, WorkType, ServiceResource,
  ServiceTerritoryMember, WorkOrder, ServiceAppointment, AssignedResource, Task

**PSS / custom objects** — no `External_ID__c` field; use the domain natural ID:
- `Program` → upsert on `nepa_project_id__c`  
- `IndividualApplication` → upsert on `nepa_federal_unique_id__c`  
- `ApplicationTimeline`, `PublicComplaint`, `nepa_engagement__c`, `nepa_litigation__c`, `ContentVersion` → **insert only** (no external ID); re-running the load script inserts duplicates for these objects

---

## Polymorphic Field Notes

The following fields cannot be set via CSV bulk upsert. `18_postload_polymorphic.apex` handles all of them:

| Field / Object | Why Apex | Resolution |
|---|---|---|
| ServiceResource `RelatedRecordId` | Requires User ID (not Contact) | Created with running user's ID; 1 SR for demo (PSS enforces 1 Technician per User) |
| ServiceTerritoryMember | Depends on SR created at runtime | Single STM created after SR |
| IndividualApplication `LicenseTypeId` | Org-specific `RegulatoryAuthorizationType` ID | Apex queries/creates "NEPA Environmental Review" RAT at runtime |
| ContentVersion `VersionData` | Bulk API v2 cannot supply base64 Blob in CSV | Created with `Blob.valueOf(' ')` placeholder; 6 documents including Comment Response required by FONSI gate CMT |
| ServiceAppointment `ParentRecordId` | Polymorphic — Bulk API v2 cannot resolve via external ID notation | SA created after querying actual WorkOrder IDs |
| AssignedResource | Depends on SA created at runtime | AR created after SA |
| Task `WhatId` / `WhoId` | Polymorphic lookups | Wired by querying IA and Contact IDs after all records exist |
| `nepa_process__c` | Cross-object wiring for engagement, timeline, complaint, CV | Wired by querying `nepa_federal_unique_id__c = 'IDI-38709'` |

Run the Apex script:
```bash
sf apex run --file demo/import_data/18_postload_polymorphic.apex --target-org <alias>
```

---

## Relationship Map

```
OperatingHours (01)
  └── ServiceTerritory.OperatingHoursId (04)

Account (02)
  ├── Contact.AccountId (03)
  ├── Program.AccountId (08)
  ├── WorkOrder.AccountId (13)
  └── PublicComplaint.AccountId (16)

Contact (03)  [polymorphic — wired by Apex]
  ├── IndividualApplication.nepa_applicant_contact__c (09)
  ├── ServiceResource.RelatedRecordId (06)
  └── Task.WhoId (19)

ServiceTerritory (04)
  ├── ServiceTerritoryMember.ServiceTerritoryId (07)
  ├── WorkOrder.ServiceTerritoryId (13)
  └── ServiceAppointment.ServiceTerritoryId (14)

ServiceResource (06)
  ├── ServiceTerritoryMember.ServiceResourceId (07)
  └── AssignedResource.ServiceResourceId (15)

Program (08)  [nepa_project_id__c = DOI-BLM-ID-B030-2019-0014-EA]
  ├── IndividualApplication.nepa_related_project__c (09)
  └── nepa_litigation__c.nepa_related_project__c (17)

IndividualApplication (09)  [nepa_federal_unique_id__c = IDI-38709]
  ├── ContentVersion.nepa_process__c (10) — wired by Apex
  ├── nepa_engagement__c.nepa_process__c (11)
  ├── ApplicationTimeline.nepa_related_process__c (12)
  ├── PublicComplaint.nepa_related_process__c (16)
  ├── Task.WhatId (19) — wired by Apex
  ├── nepa_process_team_member__c.nepa_process__c (20) — 7 ID team members
  └── nepa_legal_structure__c → RegulatoryCode '43 CFR § 3809.11' (20)

Program (08)  [also]
  ├── nepa_location_lat__c = 42.8701 (20)
  ├── nepa_location_lon__c = -116.9227 (20)
  └── nepa_polygon__c → Polygon (20)
        └── nepa_gis_data_element__c.nepa_polygon__c (20) — 5 GIS layers

WorkOrder (13)
  └── ServiceAppointment.ParentRecordId (14)

ServiceAppointment (14)
  └── AssignedResource.ServiceAppointmentId (15)
```

---

## Accounts Summary

| External_ID__c | Name | Role in Demo |
|---|---|---|
| DEMO_ACCT_001 | BLM Owyhee Field Office | Lead agency — parent for Program, WorkOrders, staff contacts |
| DEMO_ACCT_002 | Sam Uhler and David Smith | Permit applicant — applicant contact on IndividualApplication |
| DEMO_ACCT_003 | Idaho Conservation League | High-risk prior commenter — PublicComplaint DEMO_PC_001, litigation reference |
| DEMO_ACCT_004 | Office of Species Conservation | Agency commenter — PublicComplaint DEMO_PC_002 |
| DEMO_ACCT_005 | Shoshone-Paiute Tribes | Tribal consultation — nepa_engagement__c Section 106 event |

---

## Key Demo Moments → Data

| Demo Scene | Records |
|---|---|
| Sam books pre-app; system auto-assembles ID Team | `DEMO_ENG_001`; `DEMO_CON_001–007`; `DEMO_SR_001–007` |
| Optimization engine sequences 6 work orders against seasonal windows | `DEMO_WO_001–008`; `DEMO_WT_001–007` |
| Colleen Trese closes sage-grouse WO from mobile at Jordan Creek trailhead | `DEMO_WO_001`; `DEMO_SA_001` |
| Gate access non-overlap (shared resource constraint enforced) | `DEMO_SA_001–008` — no overlapping gate dates |
| Hydrologist closes WO → IDWR permit task auto-fires | `DEMO_WO_002`; `DEMO_TASK_001` |
| Geologist closes WO → EPA NPDES NOI task auto-fires | `DEMO_WO_003`; `DEMO_TASK_002` |
| Plaintiff Intelligence flags ICL; routes as work order | `DEMO_PC_001`; `DEMO_WO_009`; `DEMO_TASK_004` |
| OSC comment routed as work order | `DEMO_PC_002`; `DEMO_WO_010`; `DEMO_TASK_005` |
| Required Document Registry all five green | Documents in ContentVersion load; `DEMO_TASK_007` |
| Field Manager issues Decision Record; applicant notified | ApplicationTimeline Decision Record event; `DEMO_TASK_008` |

---

## Verification Queries

```bash
TARGET=NEPADEMO

sf data query --target-org $TARGET \
  --query "SELECT Id, Name FROM Program WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'"

sf data query --target-org $TARGET \
  --query "SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM ApplicationTimeline WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM ContentVersion WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709' AND IsLatest = true"

sf data query --target-org $TARGET \
  --query "SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'"
```

---

## Cleanup (reverse-dependency order)

```bash
TARGET=NEPADEMO

sf data delete bulk --sobject Task                   --where "External_ID__c LIKE 'DEMO_TASK_%'"  --target-org $TARGET --async
sf data delete bulk --sobject AssignedResource        --where "External_ID__c LIKE 'DEMO_AR_%'"    --target-org $TARGET --async
sf data delete bulk --sobject ServiceAppointment      --where "External_ID__c LIKE 'DEMO_SA_%'"    --target-org $TARGET --async
sf data delete bulk --sobject WorkOrder               --where "External_ID__c LIKE 'DEMO_WO_%'"    --target-org $TARGET --async
sf data delete bulk --sobject PublicComplaint         --where "Subject LIKE 'ICL Comment%' OR Subject LIKE 'OSC Comment%'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_litigation__c      --where "nepa_citation__c LIKE '%9th Cir%'"  --target-org $TARGET --async
sf data delete bulk --sobject ApplicationTimeline     --where "nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject nepa_engagement__c      --where "nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject ContentVersion          --where "nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject IndividualApplication   --where "nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject Program                 --where "nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'" --target-org $TARGET --async
sf data delete bulk --sobject ServiceTerritoryMember  --where "External_ID__c LIKE 'DEMO_STM_%'"  --target-org $TARGET --async
sf data delete bulk --sobject ServiceResource         --where "External_ID__c LIKE 'DEMO_SR_%'"    --target-org $TARGET --async
sf data delete bulk --sobject WorkType                --where "External_ID__c LIKE 'DEMO_WT_%'"    --target-org $TARGET --async
sf data delete bulk --sobject ServiceTerritory        --where "External_ID__c LIKE 'DEMO_TERR_%'"  --target-org $TARGET --async
sf data delete bulk --sobject Contact                 --where "External_ID__c LIKE 'DEMO_CON_%'"   --target-org $TARGET --async
sf data delete bulk --sobject Account                 --where "External_ID__c LIKE 'DEMO_ACCT_%'"  --target-org $TARGET --async
sf data delete bulk --sobject OperatingHours          --where "External_ID__c LIKE 'DEMO_OH_%'"    --target-org $TARGET --async

# Step 20 cleanup (run before Program/IndividualApplication deletes above)
sf data delete bulk --sobject nepa_gis_data_element__c --where "nepa_data_source_system__c IN ('BLM GeoBOE','NHD+ High Resolution','ArcGIS Online — SGMA PHMA','USFWS ArcGIS Online — ESA Critical Habitat','National Wetlands Inventory')" --target-org $TARGET --async
sf data delete bulk --sobject nepa_process_team_member__c --where "nepa_data_source_system__c = 'eNEPA'" --target-org $TARGET --async
sf data delete bulk --sobject Polygon                 --where "Name = 'Carrie Placer Mine Claim Boundary — IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject RegulatoryCode          --where "Name IN ('42 U.S.C. § 4321','40 CFR § 1501.5','40 CFR § 1501.9','43 CFR § 3809.11','16 U.S.C. § 1536(a)','54 U.S.C. § 306108','33 U.S.C. § 1342')" --target-org $TARGET --async
sf data delete bulk --sobject RegulatoryAuthority     --where "Name IN ('CEQ','DOI-BLM','Congress','EPA')" --target-org $TARGET --async
```
