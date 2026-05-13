# Quick Start Guide — NEPA and Permitting Data Model

This guide walks you from a fresh Agentforce for Public Sector org to a fully operational NEPA permitting system with sample data loaded and all risk intelligence flows verified. End-to-end time: approximately 60 minutes.

---

## Known Manual Steps

The deploy script automates nearly everything, but two steps **cannot** be scripted due to Salesforce platform limitations. Be ready for these before you start:

| Step | What you'll do | When |
|---|---|---|
| **BRE Decision Matrix row import** | Upload 7 CSV files via Setup → Business Rules Engine → Decision Matrices | After Step 3 (deploy), before Step 7 (verification) |
| **Scheduled flow configuration** | Open `NEPA_SLA_Escalation_Monitor` in Flow Builder, set schedule to Daily 7 AM, activate | After Step 4c (Flow activation) |
| **CE Library data load** | Run `python3 scripts/load_ce_library.py --org NEPADEV` to populate 314 CE reference records | After Step 3 (deploy), see Step 4e |

The BRE import is the most common failure point. If you skip it, CE Screener and Risk Scorer will throw runtime errors. See [Step 4b](#4b-import-bre-decision-matrix-rows) for the full procedure.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Salesforce org with **Agentforce for Public Sector** | Use the [APS trial org signup](https://developer.salesforce.com/free-trials/comparison/public-sector) if you don't have one. Foundations or Advanced license required. |
| **Salesforce CLI v2** (`sf`) | Install from [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli). Verify with `sf --version`. |
| **jq** | JSON formatter used by `deploy.sh`. Install with `brew install jq` (Mac) or `apt install jq` (Linux). |
| Git | To clone this repository. |
| System Administrator profile in the target org | Required for deployment. |

---

## APS Substitution

This Accelerator depends on three APS standard objects that are not available in a standard Salesforce org:

| APS Object | CEQ Entity | Dependency |
|---|---|---|
| `IndividualApplication` | Entity 2: Process | All automation flows, permission set FLS, OmniStudio DataRaptors |
| `Program` | Entity 1: Project | Litigation risk scoring, CE screener, DataRaptor extract |
| `ApplicationTimeline` | Entity 6: Case Events | CE Determination Router, Timeline Risk Assessor, Admin Record Checker |

**If your org does not have APS installed**, substitute these objects before deploying:

1. **`IndividualApplication`** — replace with a custom object (e.g., `NEPA_Process__c`) or `Case`. Update every flow's `Get_IndividualApplication` recordLookup, all `inputAssignments` writing to `IndividualApplicationId`, and all `fieldPermissions` referencing `IndividualApplication.*` in the permission set.
2. **`Program`** — replace with a custom object or `Account`. Update the Litigation Risk Scorer's `Get_RelatedProject` lookup and the `nepa_related_project__c` lookup field on `IndividualApplication`.
3. **`ApplicationTimeline`** — replace with a custom child object. Update the `IndividualApplicationId` master-detail field name and the `nepa_related_case_event__c` lookup on `ContentVersion`.

The custom objects (`nepa_engagement__c`, `nepa_litigation__c`, `nepa_process_related_agencies__c`, `nepa_ce_library__c`, `nepa_gis_data__c`) and all custom metadata types are APS-independent and deploy without modification.

A free APS developer org is available at the [APS trial org signup](https://developer.salesforce.com/free-trials/comparison/public-sector). This is the recommended path — substituting the APS objects removes access to PSS-native features such as Action Plans, OmniStudio, and the Application data model relationships the CEQ export relies on.

---

## Step 1 — Clone the Repository and Authenticate

```bash
git clone https://github.com/your-org/PSA-NEPA-Permitting-Data-Model.git
cd PSA-NEPA-Permitting-Data-Model
```

Authenticate to your org. Replace `NEPADEV` with any alias you prefer:

```bash
sf org login web --alias NEPADEV --instance-url https://login.salesforce.com
```

For a sandbox, use `--instance-url https://test.salesforce.com`.

Confirm the connection:

```bash
sf org display --target-org NEPADEV
```

---

## Step 2 — Validate Before Deploying (Optional but Recommended)

Run a dry-run deploy to confirm there are no dependency errors before touching the org:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh NEPADEV --check
```

All 8 phases should report `Status: Succeeded`. Fix any errors before proceeding.

---

## Step 3 — Deploy All Metadata

Run the full deploy:

```bash
./scripts/deploy.sh NEPADEV
```

The script deploys in dependency order:

| Phase | Contents |
|---|---|
| 1 | Custom object schemas and custom metadata type schemas (`nepa_ce_library__c`, `nepa_decision_payload__c`, `nepa_decision_log__c`, `nepa_decision_element__c`, `NEPA_Process_Model__mdt` included) |
| 2 | Custom fields on Program, IndividualApplication, ContentVersion, PublicComplaint, ApplicationTimeline |
| 3 | Custom labels |
| 4 | NEPA_Permitting permission set |
| 5 | Custom metadata seed records (CE rules, risk weights, SLA configs, permit matrix, required docs, `NEPA_Process_Model__mdt` process type definitions) |
| 5b | BRE Decision Matrix definitions (schema only — rows imported manually after deploy) |
| 5c | BRE Expression Set definitions |
| 6 | Remote site settings and named credentials |
| 7 | Apex classes (with RunLocalTests) |
| 8 | Flows (deployed individually with retry) |
| 8b | Action Plan Templates |
| 8c | OmniStudio DataRaptors and Integration Procedures |
| 9–16 | Tabs, report types, reports, dashboards, layouts, LWC, FlexiPages, Lightning app |

Expected total time: 10–15 minutes.

---

## Step 4 — Post-Deploy Configuration

### 4a. Assign the Permission Set

```bash
sf org assign permset --name NEPA_Permitting --target-org NEPADEV
```

To assign to a specific user:

```bash
sf org assign permset --name NEPA_Permitting --on-behalf-of user@example.com --target-org NEPADEV
```

### 4b. Import BRE Decision Matrix Rows

BRE Decision Matrix rows **cannot be deployed via CLI or Metadata API** — this is a Salesforce platform limitation. After deploy, import each CSV from `decision_matrix_rows/` manually:

1. Go to **Setup → Business Rules Engine → Decision Matrices**
2. Open the matrix, click the **V1** version, then click **Import CSV**
3. Upload the CSV — column headers match automatically

| CSV file | Decision Matrix |
|---|---|
| `NEPA_CE_Screener_NAICS.csv` | NEPA CE Screener - NAICS Routing |
| `NEPA_CE_Screener_Tier1.csv` | NEPA CE Screener - Tier 1 Agency Sector Rules |
| `NEPA_CE_Screener_Tier2.csv` | NEPA CE Screener - Tier 2 Agency Action Type Rules |
| `NEPA_Risk_ReviewType.csv` | NEPA Risk Scorer - Review Type Points |
| `NEPA_Risk_Agency.csv` | NEPA Risk Scorer - Agency Risk Points |
| `NEPA_Risk_Circuit.csv` | NEPA Risk Scorer - Circuit Risk Points |
| `NEPA_Permit_Matrix_BRE.csv` | NEPA Permit Matrix |

After importing, go to **Setup → BRE → Expression Sets → NEPA CE Screener** and deactivate versions V1 and V2 — leave V3 (rank 3) as the only active version.

### 4c. Activate Flows

Deploy sets all **30 flows** to Draft. Activate the 26 listed below in order to avoid trigger dependency errors. The remaining 4 are conditional or deferred:

- `NEPA_Comment_Triage_Save` — activate only when deploying the Comment Triage Agentforce agent
- `NEPA_EIS_Section_Assembler` — requires Einstein Generative AI; activate when enabling AI document drafting
- `NEPA_Work_Order_Generator` — stub placeholder; not yet implemented
- `NEPA_CE_Intake` (screen flow) — OmniScript CEIntake is the preferred path for OmniStudio orgs; retain as fallback

Go to **Setup → Flows** in your org and activate in this order:

**Activate first (subflows and error infrastructure):**
1. `NEPA_Error_Logger`
2. `NEPA_FlowError_CountIncrementer`
3. `NEPA_Defensibility_Gap_Checker`
4. `NEPA_Stage_Gate_Doc_Check`

**Activate second (before-save triggers):**
5. `NEPA_Comment_Period_Gate`
6. `NEPA_SLA_Due_Date_Setter`
7. `NEPA_FRA_Page_Limit_Setter`
8. `NEPA_Stage_Gate`

**Activate third (after-save triggers):**
9. `NEPA_Record_Completeness_Scorer`
10. `NEPA_SLA_Due_Date_Setter` *(if not already active)*
11. `NEPA_Litigation_Risk_Scorer`
12. `NEPA_CE_Screener`
13. `NEPA_CE_Determination_Router`
14. `NEPA_CE_Intake`
15. `NEPA_Challenge_Predictor`
16. `NEPA_Defensibility_Trigger_ContentVersion`
17. `NEPA_Defensibility_Trigger_Engagement`
18. `NEPA_Timeline_Risk_Assessor`
19. `NEPA_Stage_Gate_Orchestrator`
20. `NEPA_Permit_Coordinator`
21. `NEPA_Plaintiff_Intelligence`
22. `NEPA_Administrative_Record_Checker`
23. `NEPA_AdminRecord_AutoCreate`
24. `NEPA_EIS_Section_Draft_Trigger`

**Activate fourth (platform event and autolaunched):**
25. `NEPA_Error_Event_Handler`

**Configure the scheduled flow manually in Flow Builder:**
26. `NEPA_SLA_Escalation_Monitor` — open in Flow Builder, click the Start element, set schedule to **Daily at 7:00 AM**, then activate.

**Notes on flows not included in the activation list above:**
- `NEPA_Comment_Triage_Save` — Agentforce agent script target; activate only if deploying the Comment Triage agent.
- `NEPA_EIS_Section_Assembler` — requires **Einstein Generative AI** to be provisioned in the org (uses `generateText` action). Skipped by `deploy.sh` if Einstein AI is not available. Deploy manually once enabled: `sf project deploy start --metadata "Flow:NEPA_EIS_Section_Assembler" --target-org NEPADEV --test-level NoTestRun --wait 30`. Once deployed, `NEPA_EIS_Section_Draft_Trigger` can also be activated.
- `NEPA_Work_Order_Generator` — stub; flow file not yet implemented.

### 4d. Assign Lightning Record Pages

The deployment includes custom Lightning Record Pages for all 6 CEQ entities. Assign them as org defaults:

1. Go to **Setup → Lightning App Builder**.
2. Open each of the following pages and click **Activation → Assign as Org Default**:
   - `IndividualApplication Record Page` (NEPA Process)
   - `Program Record Page` (NEPA Project)
   - `Public Comment Record Page`
   - `NEPA Engagement Record Page`
   - `NEPA Litigation Record Page`
   - `NEPA CE Library Record Page`
   - `NEPA Decision Payload Record Page`
   - `NEPA Decision Log Record Page`

### 4e. Load CE Library Reference Data

Populate the `nepa_ce_library__c` searchable CE reference library with priority-agency records from the CEQ CE Explorer v2.0 dataset (314 records covering USACE, DOE, BLM, USFWS, FHWA, and FERC):

```bash
python3 scripts/load_ce_library.py --org NEPADEV
```

This uses `sf data upsert bulk` with `nepa_ce_explorer_id__c` as the external ID — safe to re-run after a dataset update.

To load the full 2,105-record federal catalog instead (requires downloading `exclusions.json` first):

```bash
# Download full dataset
curl -o exclusions.json https://ce.permitting.innovation.gov/data/exclusions.json

# Load all records
python3 scripts/load_ce_library.py --org NEPADEV --all
```

### 4f. Activate the CE Intake OmniScript (if auto-deploy failed)

`deploy.sh` deploys the `NEPA_CEIntake` OmniScript automatically in Phase 8c. If that phase failed with "Couldn't find dependent components," the Metadata API index hadn't caught up with the newly-deployed Integration Procedures. Activate manually:

1. Go to **OmniStudio → OmniScripts**
2. Find `NEPA / CEIntake` and click **Activate**

The Integration Procedures (`NEPA_CEScreeningIP`, `NEPA_CESaveIP`) were deployed successfully in Phase 8c and are already available.

---

## Step 5 — Load Sample Data

Run this anonymous Apex script to create a complete sample dataset: one EIS project, one EA project, one CE project, public comments, engagement events, timeline milestones, and NEPA documents.

In your terminal:

```bash
sf apex run --file scripts/seed-sample-data.apex --target-org NEPADEV
```

If you don't have `scripts/seed-sample-data.apex` yet, paste the following into **Developer Console → Debug → Open Execute Anonymous Window** and click **Execute**:

```apex
// ── 1. Agency accounts ────────────────────────────────────────────────────────
Account blm = new Account(Name = 'Bureau of Land Management');
Account doe = new Account(Name = 'Department of Energy');
Account fws = new Account(Name = 'Fish and Wildlife Service');
insert new List<Account>{ blm, doe, fws };

// ── 2. Projects (CEQ Entity 1: Project) ───────────────────────────────────────
Program eisProject = new Program();
eisProject.Name                   = 'Wind River Pipeline EIS';
eisProject.nepa_project_id__c     = 'BLM-WY-2026-EIS-001';
eisProject.nepa_project_title__c  = 'Wind River Pipeline EIS';
eisProject.nepa_lead_agency__c    = blm.Id;
eisProject.nepa_project_sector__c = 'Energy';
eisProject.nepa_project_type__c   = 'EIS';
eisProject.nepa_current_status__c = 'in progress';
eisProject.nepa_circuit__c        = '9th';
eisProject.nepa_project_description__c = 
    'Proposed 47-mile natural gas pipeline across BLM-administered lands in Fremont County, WY. '
    + 'Project area includes potential raptor habitat and proximity to Wind River Indian Reservation.';

Program eaProject = new Program();
eaProject.Name                   = 'Solar Valley EA';
eaProject.nepa_project_id__c     = 'DOE-CA-2026-EA-007';
eaProject.nepa_project_title__c  = 'Solar Valley Photovoltaic EA';
eaProject.nepa_lead_agency__c    = doe.Id;
eaProject.nepa_project_sector__c = 'Energy';
eaProject.nepa_project_type__c   = 'EA';
eaProject.nepa_current_status__c = 'in progress';
eaProject.nepa_circuit__c        = '9th';
eaProject.nepa_project_description__c =
    '800-acre utility-scale solar PV facility on previously disturbed federal land. '
    + 'Requires BLM right-of-way and DOE interconnect authorization.';

Program ceProject = new Program();
ceProject.Name                   = 'Sage Creek Grazing Renewal CE';
ceProject.nepa_project_id__c     = 'BLM-MT-2026-CE-042';
ceProject.nepa_project_title__c  = 'Sage Creek Grazing Permit Renewal CE';
ceProject.nepa_lead_agency__c    = blm.Id;
ceProject.nepa_project_sector__c = 'Agriculture and Natural';
ceProject.nepa_project_type__c   = 'CE';
ceProject.nepa_current_status__c = 'in progress';
ceProject.nepa_circuit__c        = '9th';
ceProject.nepa_project_description__c =
    'Renewal of existing grazing permit for 1,200 AUMs on 4,800 acres. '
    + 'No change to existing allotment boundaries or stocking rates.';

insert new List<Program>{ eisProject, eaProject, ceProject };
System.debug('Projects created: ' + eisProject.Id + ', ' + eaProject.Id + ', ' + ceProject.Id);

// ── 3. Processes (CEQ Entity 2: Process) ─────────────────────────────────────
Date today = Date.today();

IndividualApplication eisProcess = new IndividualApplication();
eisProcess.Category                               = 'Permit';
eisProcess.nepa_related_project__c                = eisProject.Id;
eisProcess.nepa_review_type__c                    = 'EIS';
eisProcess.nepa_process_status__c                 = 'in progress';
eisProcess.nepa_process_stage__c                  = 'Draft EIS Preparation';
eisProcess.nepa_federal_unique_id__c              = 'DOI-BLM-WY-2026-EIS-001';
eisProcess.nepa_agency_id__c                      = 'BLM-WY-110-2026-EA-0001';
eisProcess.nepa_public_comment_period_start__c    = (DateTime) today.addDays(30);
eisProcess.nepa_public_comment_period_end_date__c = (DateTime) today.addDays(75);
eisProcess.nepa_start_date__c                     = today.addDays(-365);
eisProcess.nepa_last_stage_transition__c          = DateTime.now().addDays(-120);

IndividualApplication eaProcess = new IndividualApplication();
eaProcess.Category                               = 'Permit';
eaProcess.nepa_related_project__c                = eaProject.Id;
eaProcess.nepa_review_type__c                    = 'EA';
eaProcess.nepa_process_status__c                 = 'in progress';
eaProcess.nepa_process_stage__c                  = 'Comment Period';
eaProcess.nepa_federal_unique_id__c              = 'DOE-EERE-2026-EA-007';
eaProcess.nepa_agency_id__c                      = 'DOE-EERE-2026-007';
eaProcess.nepa_public_comment_period_start__c    = (DateTime) today.addDays(-5);
eaProcess.nepa_public_comment_period_end_date__c = (DateTime) today.addDays(25);
eaProcess.nepa_start_date__c                     = today.addDays(-90);
eaProcess.nepa_last_stage_transition__c          = DateTime.now().addDays(-45);

IndividualApplication ceProcess = new IndividualApplication();
ceProcess.Category                               = 'Permit';
ceProcess.nepa_related_project__c                = ceProject.Id;
ceProcess.nepa_review_type__c                    = 'CE';
ceProcess.nepa_process_status__c                 = 'in progress';
ceProcess.nepa_process_stage__c                  = 'Scoping';
ceProcess.nepa_federal_unique_id__c              = 'DOI-BLM-MT-2026-CE-042';
ceProcess.nepa_agency_id__c                      = 'BLM-MT-040-2026-CE-0042';
ceProcess.nepa_start_date__c                     = today.addDays(-14);

insert new List<IndividualApplication>{ eisProcess, eaProcess, ceProcess };
System.debug('Processes created: ' + eisProcess.Id + ', ' + eaProcess.Id + ', ' + ceProcess.Id);

// ── 4. Documents (CEQ Entity 3) ───────────────────────────────────────────────
List<ContentVersion> docs = new List<ContentVersion>();

ContentVersion noi = new ContentVersion();
noi.Title                 = 'Notice of Intent — Wind River Pipeline EIS';
noi.PathOnClient          = 'NOI_Wind_River_Pipeline.pdf';
noi.VersionData           = Blob.valueOf('Placeholder: Notice of Intent content');
noi.nepa_document_type__c = 'NOI';
noi.nepa_status__c        = 'Final';
noi.nepa_publish_date__c  = today.addDays(-365);
noi.nepa_public_access__c = true;
docs.add(noi);

ContentVersion deis = new ContentVersion();
deis.Title                 = 'Draft Environmental Impact Statement — Wind River Pipeline';
deis.PathOnClient          = 'DEIS_Wind_River_Pipeline.pdf';
deis.VersionData           = Blob.valueOf('Placeholder: Draft EIS content');
deis.nepa_document_type__c = 'DEIS';
deis.nepa_status__c        = 'Draft';
deis.nepa_publish_date__c  = today.addDays(-30);
deis.nepa_public_access__c = true;
docs.add(deis);

ContentVersion ea = new ContentVersion();
ea.Title                 = 'Environmental Assessment — Solar Valley PV';
ea.PathOnClient          = 'EA_Solar_Valley.pdf';
ea.VersionData           = Blob.valueOf('Placeholder: Environmental Assessment content');
ea.nepa_document_type__c = 'EA';
ea.nepa_status__c        = 'Draft';
ea.nepa_publish_date__c  = today.addDays(-45);
ea.nepa_public_access__c = true;
docs.add(ea);

insert docs;

// Link documents to the EIS and EA processes via ContentDocumentLink
List<Id> docIds = new List<Id>();
for (ContentVersion cv : docs) {
    docIds.add(cv.Id);
}
List<ContentVersion> withDocIds = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :docIds];

List<ContentDocumentLink> links = new List<ContentDocumentLink>();
links.add(new ContentDocumentLink(
    ContentDocumentId = withDocIds[0].ContentDocumentId,
    LinkedEntityId = eisProcess.Id, ShareType = 'V', Visibility = 'AllUsers'));
links.add(new ContentDocumentLink(
    ContentDocumentId = withDocIds[1].ContentDocumentId,
    LinkedEntityId = eisProcess.Id, ShareType = 'V', Visibility = 'AllUsers'));
links.add(new ContentDocumentLink(
    ContentDocumentId = withDocIds[2].ContentDocumentId,
    LinkedEntityId = eaProcess.Id, ShareType = 'V', Visibility = 'AllUsers'));
insert links;
System.debug('Documents linked: ' + links.size() + ' ContentDocumentLinks created');

// ── 5. Public Comments (CEQ Entity 4) ────────────────────────────────────────
List<PublicComplaint> comments = new List<PublicComplaint>();

PublicComplaint c1 = new PublicComplaint();
c1.nepa_related_process__c    = eisProcess.Id;
c1.nepa_comment_body__c       = 
    'The proposed pipeline corridor crosses cultural sites sacred to the Eastern Shoshone Tribe. '
    + 'Treaty rights under the 1868 Fort Bridger Treaty must be respected. '
    + 'We request government-to-government consultation before any further NEPA review proceeds.';
c1.nepa_commenter_name__c     = 'Eastern Shoshone Tribe Environmental Office';
c1.nepa_commenter_org__c      = 'Eastern Shoshone Tribe';
c1.nepa_date_submitted__c     = today.addDays(-15);
c1.nepa_submission_method__c  = 'Written';
c1.nepa_public_access__c      = false;
comments.add(c1);

PublicComplaint c2 = new PublicComplaint();
c2.nepa_related_process__c    = eisProcess.Id;
c2.nepa_comment_body__c       = 
    'The DEIS underestimates cumulative air quality impacts on the fence line community '
    + 'in Riverton, WY — a majority-minority, low-income environmental justice community '
    + 'already experiencing disproportionate impacts from existing energy infrastructure. '
    + 'A full cumulative impact analysis is required under CEQ regulations.';
c2.nepa_commenter_name__c     = 'Riverton EJ Coalition';
c2.nepa_commenter_org__c      = 'Riverton Environmental Justice Coalition';
c2.nepa_date_submitted__c     = today.addDays(-10);
c2.nepa_submission_method__c  = 'Email';
c2.nepa_public_access__c      = false;
comments.add(c2);

PublicComplaint c3 = new PublicComplaint();
c3.nepa_related_process__c    = eaProcess.Id;
c3.nepa_comment_body__c       = 
    'I support the Solar Valley project. The clean energy benefits and job creation '
    + 'for the region outweigh the temporary visual impact during construction. '
    + 'Please expedite the review so we can begin construction this calendar year.';
c3.nepa_commenter_name__c     = 'James Whitfield';
c3.nepa_commenter_org__c      = '';
c3.nepa_date_submitted__c     = today.addDays(-3);
c3.nepa_submission_method__c  = 'Web Form';
c3.nepa_public_access__c      = true;
comments.add(c3);

PublicComplaint c4 = new PublicComplaint();
c4.nepa_related_process__c    = eaProcess.Id;
c4.nepa_comment_body__c       = 
    'The EA fails to adequately analyze impacts to the Mojave Desert Tortoise, '
    + 'a threatened species under the Endangered Species Act. The Biological Assessment '
    + 'does not address construction-season restrictions. This omission violates '
    + '40 CFR 1502.25 and the ESA Section 7 consultation requirements.';
c4.nepa_commenter_name__c     = 'Desert Wildlife Legal Center';
c4.nepa_commenter_org__c      = 'Desert Wildlife Legal Center';
c4.nepa_date_submitted__c     = today.addDays(-2);
c4.nepa_submission_method__c  = 'Written';
c4.nepa_public_access__c      = false;
comments.add(c4);

insert comments;
System.debug('Comments created: ' + comments.size());

// ── 6. Public Engagement Events (CEQ Entity 5) ───────────────────────────────
List<nepa_engagement__c> events = new List<nepa_engagement__c>();

nepa_engagement__c hearing = new nepa_engagement__c();
hearing.nepa_process__c          = eisProcess.Id;
hearing.nepa_engagement_type__c  = 'Public Hearing';
hearing.nepa_location_format__c  = 'Hybrid';
hearing.nepa_start_datetime__c   = DateTime.now().addDays(32);
hearing.nepa_end_datetime__c     = DateTime.now().addDays(32).addHours(3);
hearing.nepa_public_access__c    = true;
hearing.nepa_registration_url__c = 'https://www.blm.gov/wind-river-eis-hearing';
events.add(hearing);

nepa_engagement__c webinar = new nepa_engagement__c();
webinar.nepa_process__c          = eaProcess.Id;
webinar.nepa_engagement_type__c  = 'Public Meeting';
webinar.nepa_location_format__c  = 'Virtual';
webinar.nepa_start_datetime__c   = DateTime.now().addDays(7);
webinar.nepa_end_datetime__c     = DateTime.now().addDays(7).addHours(2);
webinar.nepa_public_access__c    = true;
webinar.nepa_registration_url__c = 'https://www.energy.gov/solar-valley-ea-meeting';
events.add(webinar);

insert events;
System.debug('Engagement events created: ' + events.size());

// ── 7. Timeline / Case Events (CEQ Entity 6) ─────────────────────────────────
List<ApplicationTimeline> timeline = new List<ApplicationTimeline>();

ApplicationTimeline noiEvent = new ApplicationTimeline();
noiEvent.Name                    = 'Notice of Intent Published';
noiEvent.nepa_related_process__c = eisProcess.Id;
noiEvent.nepa_event_type__c      = 'NOI';
noiEvent.nepa_status__c          = 'Completed';
noiEvent.nepa_tier__c            = '1';
noiEvent.nepa_source__c          = 'Federal Register';
noiEvent.nepa_start_date__c      = today.addDays(-365);
noiEvent.nepa_end_date__c        = today.addDays(-365);
noiEvent.nepa_public_access__c   = true;
timeline.add(noiEvent);

ApplicationTimeline scopingEvent = new ApplicationTimeline();
scopingEvent.Name                    = 'Scoping Period';
scopingEvent.nepa_related_process__c = eisProcess.Id;
scopingEvent.nepa_event_type__c      = 'Scoping';
scopingEvent.nepa_status__c          = 'Completed';
scopingEvent.nepa_tier__c            = '1';
scopingEvent.nepa_source__c          = 'Agency';
scopingEvent.nepa_start_date__c      = today.addDays(-335);
scopingEvent.nepa_end_date__c        = today.addDays(-305);
scopingEvent.nepa_public_access__c   = true;
timeline.add(scopingEvent);

ApplicationTimeline commentPeriodEvent = new ApplicationTimeline();
commentPeriodEvent.Name                    = 'Draft EIS Public Comment Period';
commentPeriodEvent.nepa_related_process__c = eisProcess.Id;
commentPeriodEvent.nepa_event_type__c      = 'Comment Period';
commentPeriodEvent.nepa_status__c          = 'Planned';
commentPeriodEvent.nepa_tier__c            = '1';
commentPeriodEvent.nepa_source__c          = 'Agency';
commentPeriodEvent.nepa_start_date__c      = today.addDays(30);
commentPeriodEvent.nepa_end_date__c        = today.addDays(75);
commentPeriodEvent.nepa_public_access__c   = true;
timeline.add(commentPeriodEvent);

insert timeline;
System.debug('Timeline events created: ' + timeline.size());

System.debug('=== Sample data load complete ===');
System.debug('EIS Project: ' + eisProject.Id);
System.debug('EA Project:  ' + eaProject.Id);
System.debug('CE Project:  ' + ceProject.Id);
System.debug('EIS Process: ' + eisProcess.Id);
System.debug('EA Process:  ' + eaProcess.Id);
System.debug('CE Process:  ' + ceProcess.Id);
```

---

## Step 6 — Run the Test Suite

Confirm all Apex tests pass and code coverage is sufficient for production:

```bash
sf apex run test \
  --target-org NEPADEV \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 10
```

**Expected results:**
- All 22 test classes pass
- Overall Apex code coverage ≥ 75%
- Zero failures

If tests fail, check the `Debug Log` in the org or run a targeted class to isolate the issue:

```bash
sf apex run test --class-names NepaStageGateTest --target-org NEPADEV --result-format human
```

---

## Step 7 — Verify the Solution

Navigate to your org and walk through these verification steps.

### 7a. Verify CE Screener and AI AUP Gate

1. Open the **Wind River Pipeline EIS** process record.
2. Verify `nepa_ce_pathway_recommendation__c` is blank on an EIS record (expected — screener only fires on CE-eligible records).
3. Open the **Sage Creek Grazing Renewal CE** process record.
4. Change **Action Type** to any value and save.
5. After a few seconds, refresh the record. Verify:
   - `CE Pathway Recommendation` shows a value (e.g., `CE-Recommended` or `EA-Required`)
   - `Classification Basis` shows the rule match audit trail
   - **`NEPA Review Type` (official field) is NOT changed** — it stays blank until a coordinator sets it manually

This confirms the AI AUP guardrail is working: AI recommends, humans confirm.

### 7b. Verify Litigation Risk Scorer

The Risk Scorer uses the **NEPA_Litigation_Risk_Scorer** BRE Expression Set, which looks up ReviewType, Agency, and Circuit points from Decision Matrices. Statute points (CWA, ESA, NHPA) are pre-computed in the flow before calling the ES.

**Prerequisite:** The three Risk Scorer Decision Matrices must have rows loaded (Step 4b above) or the ES will return 0 for all DM lookups and the score will reflect only statute points.

1. Open the **Wind River Pipeline EIS** process record.
2. Change **NEPA Review Type** to `EIS` (or if already set, change it to `EA` and back to `EIS`).
3. Save and wait 5–10 seconds, then refresh.
4. Verify:
   - `Risk Score` is populated (expect 75+ for EIS + BLM + 9th Circuit once DM rows are loaded)
   - `Risk Tier` shows `Very High`
   - `Risk Score Factors` contains the text `AI-GENERATED — PermitTEC v0.1`

### 7c. Verify EJ Detector on Public Comments

1. Open the **Eastern Shoshone Tribe** comment record.
2. Verify `Requires Human Review` = **true**.
3. Verify `Detected Triggers` includes `Tribal Sovereignty` and/or `Sacred Sites`.
4. Open the James Whitfield supportive comment.
5. Verify `Requires Human Review` = **false**.

If these fields are blank, the EJ Detector runs as an Agentforce invocable action — invoke it via Developer Console:

```apex
NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
req.commentBody = [SELECT nepa_comment_body__c FROM PublicComplaint 
                   WHERE nepa_commenter_org__c = 'Eastern Shoshone Tribe' LIMIT 1]
                  .nepa_comment_body__c;
req.commentId = 'manual-test';
List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
    new List<NepaCommentEJDetector.Request>{ req });
System.debug('Requires Review: ' + results[0].requiresHumanReview);
System.debug('Triggers: ' + results[0].detectedTriggers);
```

Expected: `Requires Review: true`, `Triggers: Tribal Sovereignty, Sacred Sites`.

### 7d. Verify Defensibility Gap Checker

1. Open the **Wind River Pipeline EIS** process record.
2. Check `Defensibility Score` and `Defensibility Gaps` fields.
3. Upload a document to the record (any file). After a few seconds, refresh.
4. Verify `Defensibility Score` increased and `Defensibility Updated` timestamp changed.

### 7e. Verify SLA Escalation Monitor

1. Open the EIS process and check `SLA Due Date`. If blank, verify `NEPA_SLA_Due_Date_Setter` flow is active — it should have set the due date on save.
2. To test the escalation monitor without waiting for the daily schedule, run it directly:

```bash
sf apex run --target-org NEPADEV <<'EOF'
Flow.Interview.NEPA_SLA_Escalation_Monitor interview =
    new Flow.Interview.NEPA_SLA_Escalation_Monitor(new Map<String, Object>());
interview.start();
System.debug('SLA Escalation Monitor executed');
EOF
```

3. Check for Chatter posts on any process record where `SLA Due Date` is within 30 days.

### 7f. Verify the CEQ REST API

Test the CEQ export endpoint:

```bash
# Get the EIS process by its Federal Unique ID
sf org open --target-org NEPADEV --path "/services/apexrest/nepa/v1/processes/DOI-BLM-WY-2026-EIS-001"
```

Or using curl (replace the instance URL and session ID):

```bash
INSTANCE=$(sf org display --target-org NEPADEV --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org NEPADEV --json | jq -r '.result.accessToken')

curl -s -H "Authorization: Bearer $TOKEN" \
  "$INSTANCE/services/apexrest/nepa/v1/processes/DOI-BLM-WY-2026-EIS-001" | jq .
```

Expected response shape:
```json
{
  "success": true,
  "data": {
    "federalUniqueId": "DOI-BLM-WY-2026-EIS-001",
    "reviewType": "EIS",
    "processStatus": "in progress",
    "riskScore": 83,
    "riskTier": "Very High"
  }
}
```

### 7g. Verify Custom Metadata and BRE Data Loaded

Spot-check the CE screening rules and risk weight tables:

```bash
sf data query \
  --query "SELECT Label, Agency__c, Sector_Key__c, CE_Code__c FROM NEPA_CE_Screening_Rule__mdt ORDER BY Priority__c LIMIT 10" \
  --target-org NEPADEV
```

Expected: 10 rows showing BLM, DOE, and USDA CE rules.

```bash
sf data query \
  --query "SELECT Label, Circuit_Key__c, Risk_Points__c, Low_Data_Confidence__c FROM NEPA_Circuit_Risk_Weight__mdt ORDER BY Circuit_Key__c" \
  --target-org NEPADEV
```

Expected: 14 rows (13 circuits + Default).

To confirm BRE Decision Matrix rows were imported correctly, check row counts in Setup → Business Rules Engine → Decision Matrices. Expected counts after importing all CSVs:

| Decision Matrix | Expected rows |
|---|---|
| NEPA CE Screener - NAICS Routing | 7 |
| NEPA CE Screener - Tier 1 Agency Sector Rules | 17 |
| NEPA CE Screener - Tier 2 Agency Action Type Rules | 16 |
| NEPA Risk Scorer - Review Type Points | 4 |
| NEPA Risk Scorer - Agency Risk Points | 6 |
| NEPA Risk Scorer - Circuit Risk Points | 13 |
| NEPA Permit Matrix | 9 |

Note: `NEPA_Permit_Matrix__mdt` CMT records remain in the repo as the authoritative source of truth for permit matrix data. The BRE Decision Matrix (`NEPA_Permit_Matrix_BRE`) mirrors these rows and is the runtime lookup used by the `NEPA_Permit_Coordinator` flow.

### 7h. Verify CE Library

Confirm records loaded and are SOSL-searchable:

```bash
# Count CE Library records
sf data query \
  --query "SELECT COUNT() FROM nepa_ce_library__c WHERE nepa_active__c = true" \
  --target-org NEPADEV
```

Expected: 314 (priority-agency load) or 2105 (full load).

Spot-check agency coverage:

```bash
sf data query \
  --query "SELECT nepa_agency_abbr__c, COUNT(Id) cnt FROM nepa_ce_library__c GROUP BY nepa_agency_abbr__c ORDER BY cnt DESC" \
  --target-org NEPADEV
```

Expected agencies: `DOI - BLM`, `DOI - USFWS`, `DOD - USACE`, `DOE`, `DOT - FHWA`, `FERC`.

Test full-text search (SOSL):

```bash
sf apex run --target-org NEPADEV <<'EOF'
List<List<SObject>> results = [FIND 'pipeline' IN ALL FIELDS
    RETURNING nepa_ce_library__c(Id, nepa_agency_abbr__c, nepa_exclusion_text__c LIMIT 3)];
System.debug('CE Library search hits: ' + results[0].size());
for (SObject r : results[0]) {
    System.debug(r.get('nepa_agency_abbr__c') + ': ' + String.valueOf(r.get('nepa_exclusion_text__c')).left(80));
}
EOF
```

Expected: 1 or more CE Library records matching the term "pipeline" across exclusion text.

---

## Quick Reference: Key Objects and Fields

| What you're looking at | Object | Key fields |
|---|---|---|
| NEPA project / action | `Program` | `nepa_project_id__c`, `nepa_lead_agency__c`, `nepa_circuit__c` |
| NEPA process / review | `IndividualApplication` | `nepa_review_type__c`, `nepa_process_stage__c`, `nepa_ce_pathway_recommendation__c` |
| Risk intelligence | `IndividualApplication` | `nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_risk_score_factors__c` |
| SLA tracking | `IndividualApplication` | `nepa_sla_due_date__c`, `nepa_sla_overdue__c`, `nepa_sla_warning_sent__c` |
| Comment | `PublicComplaint` | `nepa_comment_body__c`, `nepa_requires_human_review__c`, `nepa_is_substantive__c` |
| Document | `ContentVersion` | `nepa_document_type__c`, `nepa_status__c`, `nepa_public_access__c` |
| Engagement event | `nepa_engagement__c` | `nepa_engagement_type__c`, `nepa_start_datetime__c`, `nepa_public_access__c` |
| Timeline milestone | `ApplicationTimeline` | `nepa_event_type__c`, `nepa_status__c`, `nepa_public_access__c` |
| Litigation case | `nepa_litigation__c` | `nepa_case_name__c`, `nepa_circuit__c`, `nepa_outcome__c` |
| CE reference library | `nepa_ce_library__c` | `nepa_agency_abbr__c`, `nepa_exclusion_text__c`, `nepa_active__c` — SOSL/Einstein Search-indexed |
| Decision payload (ROD/FONSI/CE det.) | `nepa_decision_payload__c` | `nepa_decision_type__c`, `nepa_decision_date__c`, `nepa_rationale__c` |
| Screening criterion definition | `nepa_decision_element__c` | `nepa_title__c`, `nepa_determination_type__c`, `nepa_form_text__c` |
| Per-criterion evaluation log | `nepa_decision_log__c` | `nepa_process__c`, `nepa_decision_element__c`, `nepa_result_bool__c`, `nepa_result__c` |

---

## Troubleshooting

**Flows not firing after activation**
Verify the flow version that is Active is the correct one. Check Setup → Flows → click the flow name → confirm the Active version is the latest.

**`CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` on flow activation**
Activate subflows before parent flows. The order in Step 4b is designed to prevent this. If you see it, check which subflow the error names and activate that first.

**Risk score is 0 after setting `nepa_review_type__c`**
The `NEPA_Litigation_Risk_Scorer` fires async (`AsyncAfterCommit`). Wait 5–10 seconds and refresh. If still 0, check two things: (1) the related project has `nepa_circuit__c` and `nepa_lead_agency__c` set — the scorer reads both from the parent Program; (2) the BRE Decision Matrices have rows loaded (Step 4b). Without rows, DM lookups return 0 for ReviewType, Agency, and Circuit — only statute points will appear.

**CE Screener does not fire**
The screener fires when `nepa_action_type__c`, `nepa_disturbance_acres__c`, or `nepa_applicant_naics__c` changes on an IndividualApplication that has a related Program. Ensure the process is linked to a project.

**Test suite coverage below 75%**
Run `sf apex run test --target-org NEPADEV --test-level RunLocalTests --code-coverage` and look for classes with 0% coverage. These are typically flow-invoked Apex classes that need their corresponding flow to be active during the test run.

**Permission denied errors when querying**
Ensure the `NEPA_Permitting` permission set is assigned to your user. Run:
```bash
sf data query --query "SELECT Id FROM PermissionSetAssignment WHERE Assignee.Username = 'your@user.com' AND PermissionSet.Name = 'NEPA_Permitting'" --target-org NEPADEV
```

**`generate_ce_explorer_cmt.py` — this script is obsolete**
The earlier approach stored CE Explorer data as Custom Metadata records in `NEPA_CE_Code__mdt`. This was replaced by the `nepa_ce_library__c` custom object approach (SOSL-searchable, Einstein Search-discoverable, Experience Cloud guest-accessible). Use `scripts/load_ce_library.py` instead. The `generate_ce_explorer_cmt.py` file is preserved in `scripts/` for reference only.
