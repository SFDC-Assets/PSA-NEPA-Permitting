# Quick Start Guide — NEPA and Permitting Data Model

This guide walks you from a fresh Agentforce for Public Sector org to a fully operational NEPA permitting system with sample data loaded and all risk intelligence flows verified. End-to-end time: approximately 60 minutes.

---

## Step 0 — Get a Trial Org

**If you don't already have an Agentforce for Public Sector org, start here.**

Sign up for a free APS trial org using the Salesforce PSC Trial Org setup guide:

**[https://help.salesforce.com/s/articleView?id=ind.psc_create_trial_org.htm&language=en_US&type=5](https://help.salesforce.com/s/articleView?id=ind.psc_create_trial_org.htm&language=en_US&type=5)**

The trial org includes Agentforce for Public Sector (Foundations), OmniStudio, and the standard APS objects (`Program`, `IndividualApplication`, `ApplicationTimeline`) that this accelerator requires. Provisioning typically takes 5–10 minutes.

Once your org is provisioned, note the **My Domain URL** from Setup → My Domain — you'll need it for the `sf org login` command in Step 1.

> **Already have an APS org?** Skip to Step 1.

---

## Known Manual Steps

The deploy script automates nearly everything. The following steps still require manual action:

| Step | What you'll do | When |
|---|---|---|
| **Lightning Record Page assignment** | In Setup → Lightning App Builder, assign **9** pages as Org Default (IndividualApplication, Program, PublicComplaint, Engagement, Litigation, CE Library, Decision Payload, Decision Log, Visit). The remaining 10 pages auto-apply via object assignment at deploy time. | After Step 3 (deploy), see Step 4d |
| **Agency Named Credential URLs** | In Setup → Security → Named Credentials, update the 3 agency credentials (`NEPA_Agency_USACE`, `NEPA_Agency_USFWS`, `NEPA_Agency_BLM`) from placeholder hostnames to real agency NEPA API URLs | After Step 3 (deploy), see DEVELOPER_GUIDE.md Task 6 |
| **ArcGIS API key** | Set `NEPA_Map_Config__mdt.ApiKey` to your ESRI key (Setup → Custom Metadata Types → NEPA Map Config → API Key → Edit). CSP Trusted Sites for ArcGIS are deployed automatically in Phase 6. | After Step 3 (deploy), see Step 4h |
| **NAICS code data load** | 2,129 `NEPA_NAICS_Code__mdt` records loaded via Apex anonymous — verify with count query | After Step 3 (deploy), see Step 4i |

**CE Library data and ArcGIS CSP Trusted Sites are now fully automated.** `deploy.sh` Phase 5e calls `scripts/load_ce_library.py` to populate 314 CE reference records, and Phase 6 deploys `ArcGIS_JS_CDN` and `ArcGIS_Tiles` CSP Trusted Sites from source. No Setup UI steps are required for either. If Phase 5e reports errors, re-run manually: `python3 scripts/load_ce_library.py --org <alias>`.

**BRE Decision Matrix rows and activation are now fully automated.** `deploy.sh` Phase 5b-data calls `scripts/load_decision_matrix_rows.py`, which inserts `CalculationMatrixRow` records from the CSVs and activates each Decision Matrix and Expression Set version via the Salesforce Tooling API. No Setup UI steps are required. If Phase 5b-data reports errors, re-run manually: `python3 scripts/load_decision_matrix_rows.py --org <alias> --activate-es`. See [Step 4b](#4b-bre-decision-matrix-verification) for verification queries.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Salesforce org with **Agentforce for Public Sector** | See Step 0 above. Use the [APS trial org setup guide](https://help.salesforce.com/s/articleView?id=ind.psc_create_trial_org.htm&language=en_US&type=5) if you don't have one. Foundations or Advanced license required. |
| **Salesforce CLI v2** (`sf`) | Install from [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli). Verify with `sf --version`. |
| **jq** | JSON formatter used by `deploy.sh` to parse deploy results. Install with `brew install jq` (Mac) or `apt install jq` (Linux). If missing, the script will exit with `jq: command not found`. |
| **Python 3** | Required for CE Library data load (`scripts/load_ce_library.py`). Verify with `python3 --version`. |
| Git | To clone this repository. |
| System Administrator profile in the target org | Required for deployment. |

---

## APS Substitution

This Accelerator depends on three APS standard objects that are not available in a standard Salesforce org:

| APS Object | CEQ Entity | Dependency |
|---|---|---|
| `IndividualApplication` | Entity 2: Process | All automation flows, permission set FLS; OmniStudio DataRaptors (backlog) |
| `Program` | Entity 1: Project | Litigation risk scoring, CE screener; DataRaptor extract (backlog) |
| `ApplicationTimeline` | Entity 6: Case Events | CE Determination Router, Timeline Risk Assessor, Admin Record Checker |

**If your org does not have APS installed**, substitute these objects before deploying:

1. **`IndividualApplication`** — replace with a custom object (e.g., `NEPA_Process__c`) or `Case`. Update every flow's `Get_IndividualApplication` recordLookup, all `inputAssignments` writing to `IndividualApplicationId`, and all `fieldPermissions` referencing `IndividualApplication.*` in the permission set.
2. **`Program`** — replace with a custom object or `Account`. Update the Litigation Risk Scorer's `Get_RelatedProject` lookup and the `nepa_related_project__c` lookup field on `IndividualApplication`.
3. **`ApplicationTimeline`** — replace with a custom child object. Update the `IndividualApplicationId` master-detail field name and the `nepa_related_case_event__c` lookup on `ContentVersion`.

The custom objects (`nepa_engagement__c`, `nepa_litigation__c`, `nepa_process_related_agencies__c`, `nepa_ce_library__c`, `nepa_gis_data__c`) and all custom metadata types are APS-independent and deploy without modification.

A free APS trial org is available at the [APS trial org setup guide](https://help.salesforce.com/s/articleView?id=ind.psc_create_trial_org.htm&language=en_US&type=5). This is the recommended path — substituting the APS objects removes access to PSS-native features such as Action Plans, OmniStudio, and the Application data model relationships the CEQ export relies on.

---

## Step 1 — Clone the Repository and Authenticate

```bash
git clone https://github.com/SFDC-Assets/PSA-NEPA-Permitting.git
cd PSA-NEPA-Permitting
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

All 8 phases should report `Status: Succeeded`. Each phase prints a line like `✓ Phase 1 — Status: Succeeded`. If a phase fails, the script prints the error JSON from the Salesforce CLI and exits — fix the error listed in the output and re-run the script.

---

## Step 2b — Pre-Deploy Manual Step: Convert nepa_process_stage__c to Picklist

> **Required if your org already has `IndividualApplication` records.** Salesforce blocks a Text → Picklist field type change via Metadata API when records exist. Attempting to deploy the updated field metadata without completing this step will cause the deploy to fail with an "Invalid field type change" error.

1. Go to **Setup → Object Manager → IndividualApplication → Fields and Relationships**
2. Click `nepa_process_stage__c` → **Edit**
3. Change **Data Type** from Text to Picklist, click **Next**
4. Add the 18 canonical stage values from `force-app/main/default/objects/IndividualApplication/fields/nepa_process_stage__c.field-meta.xml` as the picklist values
5. Save

After completing this step, the `deploy.sh` script will successfully deploy the field metadata, PathAssistant (`IndividualApplication_NEPA_Process_Path`), and updated FlexiPage with the Salesforce Path component.

> **New installs (no existing records):** Skip this step — `deploy.sh` handles the field type at initial creation.

---

## Step 3 — Deploy All Metadata

### Option A — Phased deploy script (first-time install, recommended)

> **First-time install? Use Option A.** Only switch to Option B when re-deploying updates to an org that already has the base schema deployed.

Run the full deploy:

```bash
./scripts/deploy.sh NEPADEV
```

The script deploys in dependency order:

| Phase | Contents |
|---|---|
| 1 | All 49 custom object and CMT type schemas — every `__c`, `__mdt`, and `__e` object in source, including `nepa_required_permit__c`, `nepa_gis_data_element__c`, `NEPA_Permit_Matrix__mdt`, `NEPA_SLA_Config__mdt`, `NEPA_Template_Catalog__mdt`, `NEPA_Slack_Config__mdt`, and all others. Must be complete before Phase 2 adds fields and Phase 5 loads CMT records. |
| 2 | Custom fields on all objects (Program, IndividualApplication, ContentVersion, PublicComplaint, ApplicationTimeline, and all custom objects) |
| 3 | Custom labels |
| 3b | Custom tabs (deployed before Phase 4b because the permission set references tab names at deploy time) |
| 3c | Queues (`NEPA_EJ_Tribal_Liaison`, `NEPA_Comment_Triage`) — must exist before Phase 8 flows; `NEPA_EJTribal_Router` queries for the EJ queue by `DeveloperName` at runtime; if missing it silently drops EJ/tribal comments |
| 5 | Custom metadata seed records (CE rules, risk weights, SLA configs, permit matrix, required docs, `NEPA_Process_Model__mdt` process type definitions, `NEPA_Map_Config__mdt` map defaults, `NEPA_Template_Catalog__mdt` 46 APT entries) |
| 5b | BRE Decision Matrix definitions (schema deploy) |
| 5b-data | BRE Decision Matrix rows loaded + versions activated via Tooling API (automated) |
| 5c | BRE Expression Set definitions |
| 5c-activate | BRE Expression Set versions activated via Tooling API (automated) |
| 5d | Regulatory seed data: 49 `RegulatoryAuthorizationType` records + 24 `RegulatoryCode` records |
| 5e | CE Library reference data: 314 `nepa_ce_library__c` records loaded from CEQ CE Explorer filtered dataset via `scripts/load_ce_library.py` (idempotent upsert; skipped gracefully if `exclusions_filtered.json` not present) |
| 6 | Remote site settings, named credentials, and CSP Trusted Sites (`ArcGIS_JS_CDN`, `ArcGIS_Tiles`) |
| 7 | Apex classes (no tests yet — tests run in Phase 8d after flows are live) |
| 7a | Apex trigger (`NepaVisitAfterInsert`) — must follow Phase 7; calls `NepaVisitActionPlanLauncher`; without it GIS-generated Visits do not automatically launch Action Plans |
| 7b | Visualforce pages (`NEPA_Site_Location_Page` — ArcGIS map iframe for site location picker) |
| 4b | `NEPA_Permitting` permission set (after Apex so Apex class references resolve) |
| 8 | 48 flows deployed individually with retry; ordered by subflow dependency tier |
| 8b | Action Plan Templates |
| 8c | OmniStudio DataRaptors, Integration Procedures, OmniScripts — **see backlog note below** |
| 8d | `RunLocalTests` (all Apex tests, after flows and permission set are live) |
| 10–16 | Report types, reports, dashboards, layouts, LWC, FlexiPages (19 record and home pages), Path Assistant (`IndividualApplication_NEPA_Process_Path`), Lightning app |

Expected automated deploy time: ~25 minutes. Add ~10 minutes for manual post-deploy steps (flow activation, field type conversion, record type setup) documented in DEVELOPER_GUIDE.md Post-Deploy Checklist. BRE row loading and activation are handled automatically during deploy. **Total end-to-end: ~35 minutes.**

After the deploy completes, the script prompts you to load the Carrie Placer Mine demo data:

```
==> Load Carrie Placer Mine demo data into NEPADEV? [y/N]
```

Answer **y** to load a full-lifecycle NEPA EA demonstration record automatically, or **N** to skip (you can run `bash scripts/load-demo-data.sh NEPADEV` at any time). See [Step 5b — Load Carrie Placer Mine Demo Data](#step-5b--load-carrie-placer-mine-demo-data) for details.

### Option B — Single-shot manifest deploy (re-deploy to existing org)

If the target org already has the base schema deployed and you need to push updates:

```bash
sf project deploy start \
  --manifest manifest/deploy_clean.xml \
  --target-org NEPADEV \
  --test-level NoTestRun \
  --wait 60
```

`manifest/deploy_clean.xml` deploys 706 components in a single call. It intentionally excludes components that require special handling:

| Excluded component | Reason |
|---|---|
| `OmniDataTransform` / `OmniIntegrationProcedure` / `OmniScript` | **BACKLOG — not verified.** Phase 8c deploys these components but end-to-end activation has NOT been confirmed. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). Excluded here because `DRUpsertDetectedLayer` requires a two-step deploy; handled in Phase 8c, but the phased deploy does not guarantee a working result. |
| `BotVersion` | Requires Agentforce agent publish workflow; deploy via Agent CLI |
| `ConnectedApp:NEPA_CEQExport_API` | XML structure error (`oauthFlows` invalid in `oauthConfig`); fix before including |
| `ExpressionSetDefinition` | Platform rejects deploy if a version is already active; activation handled by `scripts/load_decision_matrix_rows.py --activate-es` (Phase 5c-activate) |
| `FlexiPage:Program_Record_Page` | Some orgs have this page pre-bound to `CGC_Program__c`; excluded to avoid sobjectType conflict |
| `Flow:NEPA_EIS_Section_Assembler` + `NEPA_EIS_Section_Draft_Trigger` | Require Einstein Generative AI provisioning |

For a first-time install, use the phased script (Option A) — it handles the OmniStudio two-step deploy and dependency ordering.

> **Backlog — OmniStudio Phase 8c not verified**
>
> The OmniStudio DataRaptors, Integration Procedures, and OmniScript components (Phase 8c) are present in the repository and will be deployed by the script, but this deployment path was **not successfully verified**. After deployment the components may not activate correctly, and end-to-end functionality (CE intake wizard, GIS proximity via Integration Procedure, CEQ export via DataRaptors) has not been confirmed. Do not present these features as working until manually verified in your org.
>
> **What works without OmniStudio:** CE screening via BRE/Flow, GIS layer catalog, `nepa_gis_data__c` schema, CEQ REST export via Apex (`NepaCeqExportService`), and all 40+ flows operate independently of OmniStudio.
>
> See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) for the full list of backlog components and what would be required to complete them.

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

Verify the assignment succeeded:

```bash
sf data query \
  --query "SELECT Assignee.Username FROM PermissionSetAssignment WHERE PermissionSet.Name='NEPA_Permitting'" \
  --target-org NEPADEV
```

### 4b. BRE Decision Matrix Verification

BRE row loading and version activation are handled automatically by `deploy.sh` Phase 5b-data. You should see output like this during deploy:

```
==> Phase 5b-data: BRE Decision Matrix rows + activation
  NEPA_Risk_Agency_V1: 7 rows from NEPA_Risk_Agency.csv, DMDV.Status=Draft, CMV.IsEnabled=False
    Inserted 7/7 rows (0 errors)
    Activated DMDV NEPA_Risk_Agency_V1
  ...
  DM processing complete: 8/8 succeeded
```

**If Phase 5b-data fails** or you need to re-run it:

```bash
# Re-run all DMs + activate Expression Sets
python3 scripts/load_decision_matrix_rows.py --org <alias> --activate-es

# Re-run a specific DM (forces reload even if already active)
python3 scripts/load_decision_matrix_rows.py --org <alias> --dm NEPA_Risk_Agency --no-skip

# Preview without writing
python3 scripts/load_decision_matrix_rows.py --org <alias> --dry-run
```

See [decision_matrix_rows/README.md](../decision_matrix_rows/README.md) for the full re-run reference.

### 4c. Verify Flow Activation

**All 48 flows deploy with `status=Active` from source XML — no manual activation step is required.** The deploy script deploys each flow individually with retry logic (see Phase 8 in the table above). On a successful deploy, all flows are live immediately.

**Verify activation:**

```bash
sf data query \
  --query "SELECT DeveloperName, Status FROM Flow WHERE DeveloperName LIKE 'NEPA%' AND Status = 'Active' ORDER BY DeveloperName" \
  --use-tooling-api \
  --target-org NEPADEV
```

Expected: 48 active flows. Excludes 4 flows that are not deployed by the script:

| Flow | Why excluded |
|---|---|
| `NEPA_EIS_Section_Assembler` | Requires Einstein Generative AI (`generateText` action). Not deployed by script. |
| `NEPA_EIS_Section_Draft_Trigger` | Calls `NEPA_EIS_Section_Assembler` as subflow — cannot deploy until the assembler exists. |
| `NEPA_Slack_Stage_Notifier` | Requires Salesforce for Slack managed package. Deploys as Draft; activates once package is installed. See Step 9. |
| `NEPA_Slack_Risk_Alert` | Same Slack package requirement. |

**Deploy the EIS flows manually when Einstein AI is provisioned:**

```bash
sf project deploy start --metadata "Flow:NEPA_EIS_Section_Assembler" --target-org NEPADEV --test-level NoTestRun --wait 30
sf project deploy start --metadata "Flow:NEPA_EIS_Section_Draft_Trigger" --target-org NEPADEV --test-level NoTestRun --wait 30
```

**If any flow shows Draft or Inactive** after deploy (transient deploy failure), re-deploy individually:

```bash
sf project deploy start --metadata "Flow:NEPA_Error_Logger" --target-org NEPADEV --test-level NoTestRun --wait 30
```

The most common transient error is `UNKNOWN_EXCEPTION` on the Salesforce pod — the deploy script retries each flow automatically up to 3 times, but re-running manually once more resolves persistent cases.

**Scheduled flows** (`NEPA_OFD_Variance_Alert`, `NEPA_Permit_SLA_Monitor`) deploy with their schedules defined in source XML — daily at 07:00 UTC and 06:00 UTC respectively. No Flow Builder configuration is needed.

> **Note:** `NEPA_SLA_Escalation_Monitor` is a **record-triggered** after-save flow (not a scheduled flow). It fires on IndividualApplication saves, not on a clock schedule. No "set schedule in Flow Builder" step is required.

### 4d. Assign Lightning Record Pages

Phase 15 deploys **19 custom Lightning Record Pages**. Nine of these serve the 6 CEQ entities and must be manually assigned as org defaults — the rest auto-apply to their object by the platform after deploy.

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
   - `NEPA Visit Record Page`

The remaining 10 pages (`NEPA_GIS_Data_Record_Page`, `NEPA_GIS_Data_Element_Record_Page`, `NEPA_Detected_Protection_Layer_Record_Page`, `NEPA_Required_Permit_Record_Page`, `NEPA_AR_Export_Record_Page`, `NEPA_Process_Team_Member_Record_Page`, `nepa_litigation__c_Record_Page`, `RegulatoryCode_Record_Page`, `ApplicationTimeline_Record_Page`, `NEPA_Permitting_Home`) are assigned automatically to their object at deploy time and do not require manual activation.

### 4e. CE Library Reference Data (Automated)

**Phase 5e of `deploy.sh` calls `scripts/load_ce_library.py` automatically.** You should see output like this during deploy:

```
==> Phase 5e: CE Library reference data (314 priority-agency records)
    Loading records from exclusions_filtered.json...
    Upserted 314/314 records
    Verify: sf data query --query "SELECT COUNT() FROM nepa_ce_library__c" ...
```

This uses `sf data upsert bulk` with `nepa_ce_explorer_id__c` as the external ID — idempotent, safe to re-run.

**If Phase 5e was skipped** (because `exclusions_filtered.json` was not in the repo root when you ran deploy), load manually:

```bash
python3 scripts/load_ce_library.py --org NEPADEV
```

To load the full 2,105-record federal catalog (all 79 agencies):

```bash
curl -o exclusions.json https://ce.permitting.innovation.gov/data/exclusions.json
python3 scripts/load_ce_library.py --org NEPADEV --all
```

**If the script fails**, common causes: wrong org alias (verify with `sf org display --target-org NEPADEV`), missing Python package (install with `pip3 install simple_salesforce`), or network timeout (retry once — the upsert is safe to re-run).

**Verify the load:**

```bash
sf data query \
  --query "SELECT COUNT() FROM nepa_ce_library__c" \
  --target-org NEPADEV
```

Expected: 314 (priority load) or 2105 (full load).

### 4f. CE Intake OmniScript — Backlog

> **Backlog — OmniStudio not verified.** The `NEPA_CEIntake` OmniScript and its backing Integration Procedures (`NEPA_CEScreeningIP`, `NEPA_CESaveIP`) were not successfully deployed and verified. Do not attempt to activate these components as part of a standard deployment — the expected activation steps have not been confirmed to produce a working result.
>
> The **working CE intake path** is the `NEPA_CE_Intake` Screen Flow, which provides full BRE-based CE screening without OmniStudio.
>
> See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) for the full scope of OmniStudio backlog items and what would be needed to complete them.

### 4g. Configure Named Credentials for GIS Services — Backlog

> **Backlog — OmniStudio Integration Procedure path not verified.**
> The GIS proximity check (`NEPA_GISProximityIP` Integration Procedure) has not been
> successfully verified end-to-end. Three Named Credentials (USGS NHD, BLM Tribal Cadastral,
> BLM PLSS) are deployed but **configuring them will not produce working GIS checks** until
> the Integration Procedure is activated and verified.
>
> The GIS layer catalog (`NEPA_GIS_Layer__mdt`), `nepa_gis_data__c` schema, and
> `nepa_detected_protection_layer__c` schema are fully deployed and working.
> See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) and [GIS-Proximity-Guide.md](GIS-Proximity-Guide.md) for the resumption checklist.

### 4h. Configure the ArcGIS API Key (site location picker) — Backlog

> **Backlog — OmniStudio not verified.** The `nepaSiteLocationPickerOmni` LWC is an OmniScript custom component that is only used within the `NEPA_CEIntake` OmniScript wizard. Since the OmniScript itself is backlog, this configuration step is deferred. The steps below are preserved for reference when the OmniScript path is resumed.

Configuration steps are preserved in [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) for resumption; do not attempt until the OmniScript path is verified.

### 4i. Verify NAICS Code Data — Backlog (OmniScript component)

> **Backlog — OmniStudio not verified.** The `nepaIndustryCodePickerOmni` LWC is an OmniScript custom component used within the `NEPA_CEIntake` OmniScript wizard. Since the OmniScript itself is backlog, this step is deferred. The `NEPA_NAICS_Code__mdt` records are still useful for BRE and Flow-based CE screening.

NAICS data is still useful for BRE/Flow-based CE screening. To verify NAICS records are loaded for BRE use, run the SOQL in [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). Do not attempt OmniScript picker verification until the OmniScript path is verified.

---

## Step 5 — Load Sample Data

Run this anonymous Apex script to create a complete sample dataset: one EIS project, one EA project, one CE project, public comments, engagement events, timeline milestones, and NEPA documents.

In your terminal:

```bash
sf apex run --file scripts/seed-sample-data.apex --target-org NEPADEV
```

If you don't have `scripts/seed-sample-data.apex` yet, paste the following into the **Developer Console → Debug → Open Execute Anonymous Window** and click **Execute**. (Access the Developer Console from the org UI: click the gear icon ⚙ in the top-right → Developer Console.)

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

## Step 5b — Load Carrie Placer Mine Demo Data

> **Optional — recommended for demos and evaluation.** The deploy script prompts for this automatically. Run manually at any time.

```bash
bash scripts/load-demo-data.sh NEPADEV
```

This loads a realistic full-lifecycle NEPA EA record based on a real BLM Idaho permit process:

| What gets loaded | Detail |
|---|---|
| Program (Project) | Carrie Placer Mine — `DOI-BLM-ID-B030-2019-0014-EA`, BLM Salmon Field Office, 9th Circuit |
| IndividualApplication (Process) | EA record `IDI-38709` with litigation risk score, required permits, stage history |
| 7 specialist ServiceResources | Hydrologist, Wildlife Biologist, Botanist, Geologist, Cultural Resources, GIS Analyst, Project Manager |
| 30+ ApplicationTimeline events | Case events, milestones, OFD coordination tracks |
| ContentVersions | EA document, biological assessment, cultural survey — linked to the IA |
| PublicComments | Comment set including EJ/tribal concerns (tests `NEPA_EJTribal_Router`) |
| nepa_litigation__c | 9th Circuit challenge record linked to the process |
| nepa_decision_payload__c | Draft ROD payload |
| nepa_ar_export__c | Administrative record export |
| GIS proximity layers | `nepa_detected_protection_layer__c` records for NHD, PAD, and species habitat |
| Required permits | Triggered automatically by `NEPA_Permit_Record_Creator` flow during Apex load |

**Load time:** ~3–5 minutes.

**Verify after load:**

```bash
sf data query --query "SELECT Id, Name, nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709'" --target-org NEPADEV
sf data query --query "SELECT COUNT() FROM nepa_required_permit__c WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'" --target-org NEPADEV
```

Expected: 1 IA record with `nepa_risk_score__c > 0`, and 6+ required permits.

**Clean up demo data:**

```bash
# Run in reverse-dependency order
sf data delete bulk --sobject Task --where "External_ID__c LIKE 'DEMO_TASK_%'" --target-org NEPADEV --async
sf data delete bulk --sobject IndividualApplication --where "nepa_federal_unique_id__c = 'IDI-38709'" --target-org NEPADEV --async
sf data delete bulk --sobject Program --where "nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'" --target-org NEPADEV --async
sf data delete bulk --sobject Account --where "External_ID__c LIKE 'DEMO_ACCT_%'" --target-org NEPADEV --async
```

See `scripts/load-demo-data.sh` for the full cleanup command set.

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
- All 615+ tests pass across 63 test classes
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

**Prerequisite:** The three Risk Scorer Decision Matrices must have rows loaded — handled automatically by `deploy.sh` Phase 5b-data. Without rows, DM lookups return 0 for ReviewType, Agency, and Circuit and the score will reflect only statute points. Verify with the SOQL query in Step 4b.

1. Open the **Wind River Pipeline EIS** process record.
2. Change **NEPA Review Type** to `EIS` (or if already set, change it to `EA` and back to `EIS`).
3. Save and wait 5–10 seconds, then refresh.
4. Verify:
   - `Risk Score` is populated (expect 75+ for EIS + BLM + 9th Circuit; BLM=39pts + 9th Circuit=36pts + EIS base=40pts = 115 before modifiers)
   - `Risk Tier` shows `Very High` (threshold: ≥58)
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

Two endpoints are available:

**Per-process export** (returns process-level data by `nepa_federal_unique_id__c`):

```bash
INSTANCE=$(sf org display --target-org NEPADEV --json | jq -r '.result.instanceUrl')
TOKEN=$(sf org display --target-org NEPADEV --json | jq -r '.result.accessToken')

curl -s -H "Authorization: Bearer $TOKEN" \
  "$INSTANCE/services/apexrest/nepa/v1/processes/DOI-BLM-WY-2026-EIS-001" | jq .
```

Expected: `success: true`, `data` array with process fields (`federalUniqueId`, `reviewType`, `processStatus`, etc.)

**Full project graph export** (returns complete CEQ v1.2 nested payload by Program record Id):

```bash
# Replace <PROGRAM_ID> with the Salesforce record Id of the deployed Program
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"projectId": "<PROGRAM_ID>"}' \
  "$INSTANCE/services/apexrest/nepa/v1/export/project" | jq .
```

Expected:
```json
{
  "success": true,
  "data": {
    "schema_version": "1.2",
    "standard": "CEQ NEPA and Permitting Data and Technology Standard",
    "exported_at": "...",
    "project": {
      "project_id": "DOI-BLM-WY-2026-EIS-001",
      "lead_agency": "BLM",
      "processes": [
        {
          "federal_unique_id": "...",
          "nepa_review_type": "EIS",
          "documents": [...],
          "permits": [...]
        }
      ]
    }
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

To confirm BRE Decision Matrix rows were loaded correctly, query row counts via CLI:

```bash
sf data query \
  --query "SELECT CalculationMatrixVersionId, COUNT(Id) cnt FROM CalculationMatrixRow GROUP BY CalculationMatrixVersionId" \
  --target-org <alias>
```

Expected counts per active version:

| Decision Matrix | Expected rows |
|---|---|
| NEPA CE Screener - NAICS Routing | 7 |
| NEPA CE Screener - Tier 1 Agency Sector Rules | 17 |
| NEPA CE Screener - Tier 2 Agency Action Type Rules | 16 |
| NEPA Risk Scorer - Review Type Points | 4 |
| NEPA Risk Scorer - Agency Risk Points | 7 (BLM, USFS, FERC, USACE, USFWS, FHWA, Default) |
| NEPA Risk Scorer - Circuit Risk Points | 13 (12 circuits + DEFAULT wildcard) |
| NEPA Permit Matrix | 9 |
| NEPA Risk Scorer - Sector Circuit Risk Points | 17 (16 sector\|circuit cells + `*` wildcard) |

Also verify all versions are Active:

```bash
sf data query \
  --query "SELECT Name, IsEnabled FROM CalculationMatrixVersion WHERE Name LIKE 'NEPA%' ORDER BY Name" \
  --target-org <alias>
```

Expected: all 8 versions show `IsEnabled=true`.

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
Flows deploy with `status=Active` from source so this error should not occur during a normal deploy. If it does (e.g., when manually activating a flow that failed to deploy), activate subflows before parent flows. The subflow dependency tiers are documented in the Phase 8 section of `scripts/deploy.sh` — check which subflow the error names and deploy/activate that first.

**Risk score is 0 after setting `nepa_review_type__c`**
The `NEPA_Litigation_Risk_Scorer` fires async (`AsyncAfterCommit`). Wait 5–10 seconds and refresh. If still 0, check two things: (1) the related project has `nepa_circuit__c` and `nepa_lead_agency__c` set — the scorer reads both from the parent Program; (2) the BRE Decision Matrices have rows loaded (Phase 5b-data during deploy). Without rows, DM lookups return 0 for ReviewType, Agency, and Circuit — only statute points will appear. Verify with the SOQL query in Step 4b or re-run `python3 scripts/load_decision_matrix_rows.py --org <alias>`.

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

**`UNKNOWN_EXCEPTION` on deploy with no structured error**
This is a Salesforce pod-level rejection that fires before component parsing. Common causes:
- Multiple `<types>` blocks for the same metadata type in `package.xml` — deduplicate
- `<fullName>` or `<description>` elements present in a deploy manifest — these are valid in `package.xml` but invalid in `manifest/deploy_clean.xml`-style deploy manifests
- A Flow using `<actionType>generateText</actionType>` (Einstein AI) when Einstein GenAI is not provisioned — exclude the flow or provision Einstein first
- Misformatted source files in the project tree (see below)

**"Not found in zipped directory" for 100+ field components**
Fields on standard APS objects (`Program`, `IndividualApplication`, `ContentVersion`, `PublicComplaint`, `ApplicationTimeline`) must exist as individual `objects/<Object>/fields/<field>.field-meta.xml` files. Fields embedded inside a flat `.object-meta.xml` are silently ignored for standard objects. Similarly, `RecordType` and `ValidationRule` definitions must be extracted to `objects/<Object>/recordTypes/` and `objects/<Object>/validationRules/` subdirectories.

**Source-format file naming errors on fresh clone**
The Metadata API source format requires:
- `.object-meta.xml` (not bare `.object`)
- `.layout-meta.xml` (not bare `.layout`)
- `.permissionset-meta.xml` (not bare `.permissionset`)

If you see "ComponentSetError" or deployment failures citing missing metadata types, check that all files in `force-app/` have the correct `-meta.xml` suffix.

**`FlexiPage Program_Record_Page` fails with object type mismatch**
Some PSS orgs (particularly those upgraded from an older managed package) have `Program_Record_Page` pre-assigned to `CGC_Program__c`. The Metadata API cannot change the `sobjectType` of an existing Lightning page. The deploy script handles this with `allow-failure` on this page. To fully resolve: delete the existing `Program_Record_Page` in Setup → Lightning App Builder, then redeploy.

**`ConnectedApp:NEPA_CEQExport_API` parse error**
The source file has an `<oauthFlows>` element inside `<oauthConfig>` which is invalid for API v62. The ConnectedApp is excluded from `manifest/deploy_clean.xml` and the phased script. To fix: open `force-app/main/default/connectedApps/NEPA_CEQExport_API.connectedApp-meta.xml`, remove the `<oauthFlows>` block, validate against the ConnectedApp schema, and redeploy using `--metadata "ConnectedApp:NEPA_CEQExport_API"`.

**Flow gate not blocking (or always blocking) despite correct logic**
Two silent flow bugs can produce this symptom:

1. *Missing loop connector.* Every `<assignments>` node inside a collection loop must have an explicit `<connector>` back to the loop element. Omitting it is valid XML and deploys without error, but the flow terminates at that node — subsequent elements (like a `Block_Save` customErrors element) are never reached. Check flow run history: if runs show "Completed" when they should show "Fault" or a blocked save, inspect every Assign node for a missing connector.

2. *`In` operator with a literal value.* Flow record filters using `<operator>In</operator>` require a collection variable. Using `<stringValue>` (a literal) with `In` compiles silently to an empty collection — Get Records returns zero rows regardless of actual data. If a gate is never blocking, check whether any filter uses `In` with a single literal; change it to `EqualTo`.

**Flow fires when it should not (RecordType filter on object with no record types)**
A flow start filter on `{$Record.RecordType.DeveloperName}` evaluates to `"null__NotFound"` at runtime when the trigger object (`ContentVersion`, `ApplicationTimeline`) has no record types configured. The entry condition always fails and the flow never fires — or the comparison matches an unexpected string. Remove `RecordType.DeveloperName` from the start filter and guard with a Decision node immediately inside the flow instead.

**`CANNOT_EXECUTE_FLOW_TRIGGER, Limit Exceeded` on `PublicComplaint` bulk insert (tests)**
The PSS managed package process "Update Complaint Summary and Resolution Priority" fires on every `PublicComplaint` insert and consumes governor limits proportional to batch size. Batches above ~30 records in a single Apex test DML call can exhaust org-level limits. This is a PSS package ceiling, not a NEPA automation limit. Limit `PublicComplaint` bulk test inserts to **≤20 records per DML call**. At 20 records NEPA duplicate-check, plaintiff intelligence, and comment-period flows all complete within limits.

**Flow-written field values silently not saved (field length too short)**
If a Flow `Update Records` element writes a formula value to a Text field and the output string exceeds the field's declared length, the DML fails silently — any `faultConnector` on the Update element catches the error and routes to End. Downstream fields that depend on this write (e.g., `nepa_plaintiff_risk_flag__c` not set after plaintiff intelligence runs) appear unset even though the flow logic is correct. Fix: increase the Text field length to accommodate the maximum realistic formula output. Use 255 for any structured summary or tier string.

**`IsChanged = true` flow entry filter not firing in Apex tests**
If `@TestSetup` creates a record with the field already set to the target value, an `IsChanged = true` entry filter on a before-save flow will never fire when the test updates the record to the same value — no change = no entry. Symptom: flow-managed fields (e.g., `nepa_phase2_applicable__c`) stay unchanged after the update. Fix: in the test method, first update the field to a different value, then update it to the target value to guarantee a genuine change that satisfies `IsChanged = true`.
