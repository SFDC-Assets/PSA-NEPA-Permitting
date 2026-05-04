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
| 06 | `06_ServiceResource.csv` | ServiceResource | 7 | `External_ID__c` | None (RelatedRecordId wired by Apex step 18) |
| 07 | `07_ServiceTerritoryMember.csv` | ServiceTerritoryMember | 7 | `External_ID__c` | ServiceTerritory (04), ServiceResource (06) |
| 08 | `08_Program.csv` | Program | 1 | `nepa_project_id__c` | Account (02) |
| 09 | `09_IndividualApplication.csv` | IndividualApplication | 1 | `nepa_federal_unique_id__c` | Program (08), Contact (03) |
| 10 | `10_ContentVersion.csv` | ContentVersion | 5 | insert (no ext ID) | IndividualApplication (09) — `nepa_process__c` wired by Apex step 18 |
| 11 | `11_nepa_engagement__c.csv` | nepa_engagement__c | 5 | insert (no ext ID) | IndividualApplication (09) |
| 12 | `12_ApplicationTimeline.csv` | ApplicationTimeline | 25 | insert (no ext ID) | IndividualApplication (09) |
| 13 | `13_WorkOrder.csv` | WorkOrder | 10 | `External_ID__c` | Account (02), ServiceTerritory (04), WorkType (05) |
| 14 | `14_ServiceAppointment.csv` | ServiceAppointment | 10 | `External_ID__c` | WorkOrder (13), ServiceTerritory (04) |
| 15 | `15_AssignedResource.csv` | AssignedResource | 11 | `External_ID__c` | ServiceAppointment (14), ServiceResource (06) |
| 16 | `16_PublicComplaint.csv` | PublicComplaint | 2 | insert (no ext ID) | Account (02), IndividualApplication (09) |
| 17 | `17_nepa_litigation__c.csv` | nepa_litigation__c | 2 | insert (no ext ID) | Program (08) |
| 18 | `18_postload_polymorphic.apex` | **Apex script** | — | — | Run after all CSVs; wires polymorphic lookups |
| 19 | `19_Task.csv` | Task | 8 | `External_ID__c` | Loaded before or after Apex; WhatId/WhoId wired by step 18 |

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

| Field | Object | Resolution |
|---|---|---|
| `RelatedRecordId` | ServiceResource | Linked to Contact by `External_ID__c` match |
| `WhatId` | Task | Linked to IndividualApplication (PSS standard object, no `__c`) |
| `WhoId` | Task | Linked to Contact |
| `nepa_process__c` | ContentVersion | Custom lookup to IndividualApplication — wired via Title match |

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
  └── Task.WhatId (19) — wired by Apex

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
  --query "SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'Carrie Placer%' AND IsLatest = true"

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
sf data delete bulk --sobject ContentVersion          --where "Title LIKE 'Carrie Placer Mine%'"   --target-org $TARGET --async
sf data delete bulk --sobject IndividualApplication   --where "nepa_federal_unique_id__c = 'IDI-38709'" --target-org $TARGET --async
sf data delete bulk --sobject Program                 --where "nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'" --target-org $TARGET --async
sf data delete bulk --sobject ServiceTerritoryMember  --where "External_ID__c LIKE 'DEMO_STM_%'"  --target-org $TARGET --async
sf data delete bulk --sobject ServiceResource         --where "External_ID__c LIKE 'DEMO_SR_%'"    --target-org $TARGET --async
sf data delete bulk --sobject WorkType                --where "External_ID__c LIKE 'DEMO_WT_%'"    --target-org $TARGET --async
sf data delete bulk --sobject ServiceTerritory        --where "External_ID__c LIKE 'DEMO_TERR_%'"  --target-org $TARGET --async
sf data delete bulk --sobject Contact                 --where "External_ID__c LIKE 'DEMO_CON_%'"   --target-org $TARGET --async
sf data delete bulk --sobject Account                 --where "External_ID__c LIKE 'DEMO_ACCT_%'"  --target-org $TARGET --async
sf data delete bulk --sobject OperatingHours          --where "External_ID__c LIKE 'DEMO_OH_%'"    --target-org $TARGET --async
```
