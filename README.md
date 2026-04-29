![Public Sector Accelerators logo](/docs/Logo_GPSAccelerators_v01.png)

# NEPA and Permitting Data Model

Ready-made NEPA and permitting data model that aligns with the CEQ's NEPA and Permitting Data and Technology Standard v1.2.

[Accelerator Listing](https://gpsaccelerators.developer.salesforce.com/accelerator/a0wDo000000BBN7IAO/nepa-and-permitting-data-model)


## Description

The NEPA and Permitting Data Model Accelerator helps U.S. federal and state agencies modernize their permitting systems in alignment with the [_**NEPA and Permitting Data and Technology Standard v1.2**_](https://permitting.innovation.gov/CEQ_NEPA_and_Permitting_Data_and_Technology_Standard.pdf) issued by the Council on Environmental Quality (CEQ) on May 30, 2025 (updated August 18, 2025). Built on the Salesforce Public Sector Solutions (PSS) data model, this Accelerator introduces custom objects and fields to support data interoperability, transparency, and improved decision-making across environmental permitting programs.

This Accelerator is designed to help agencies meet the requirements of the CEQ [**Permitting Technology Action Plan**](https://permitting.innovation.gov) (May 30, 2025), which directs agencies listed under 42 U.S.C. 4370m-1(b)(2)(B)(i)-(xii) to adopt and begin implementing the data standard and Minimum Functional Requirements (MFRs). It supports MFRs #1 (Implement Data Standards), #5 (Automated Case Management Tools), and #7 (Improved Document Management) at foundational and emerging maturity levels.

This Accelerator extends the PSS [**Application and Authorization Data Model**](https://developer.salesforce.com/docs/atlas.en-us.psc_api.meta/psc_api/psc_data_model_application_authorization.htm) by mapping CEQ's defined entities and properties to Salesforce data components. It provides agencies with a concrete starting point to comply with Title II of the Evidence Act and open data guidance outlined in OMB Memorandum [**M-25-05**](https://www.whitehouse.gov/wp-content/uploads/2025/01/M-25-05-Phase-2-Implementation-of-the-Foundations-for-Evidence-Based-Policymaking-Act-of-2018-Open-Government-Data-Access-and-Management-Guidance.pdf).

![NEPA to Application and Authorization Data Model Mapping](/docs/NEPA%20to%20Salesforce%20Mapping.jpeg)

**Key benefits include**:
- **Compliance out of the box**: Implements 6 of the 9 CEQ standard entities using Salesforce-native components, including all 6 provenance fields required by v1.2.
- **Faster implementation**: Accelerates modernization efforts with ready-made metadata aligned to federal guidance and the August 28, 2025 implementation deadline.
- **Interoperability-first architecture**: Promotes structured, shareable data models that improve transparency and data exchange across agencies. External ID fields on Project and Process support UUID-based agency-to-agency data sharing.
- **Milestone and engagement tracking**: Extends PSS `ApplicationTimeline` for FAST-41 schedule compliance and adds a dedicated Public Engagement Events object for legally required public involvement documentation.
- **Future extensibility**: Designed to grow with your permitting system — providing a scalable foundation for GIS integration, CE screening logic, process modeling, and decision payloads.

Whether you're beginning a modernization journey or enhancing an existing permitting solution, this Accelerator gives you the head start needed to meet federal standards and accelerate public outcomes.


## CEQ Standard Coverage

This Accelerator implements the following entities from the CEQ NEPA and Permitting Data and Technology Standard v1.2:

| CEQ Entity | Salesforce Object | Status |
|---|---|---|
| Entity 1: Project | `Program` | ✅ Implemented |
| Entity 2: Process | `IndividualApplication` | ✅ Implemented |
| Entity 3: Documents | `ContentVersion` (record type: `nepa_permit_document`) | ✅ Implemented |
| Entity 4: Comments | `PublicComplaint` | ✅ Implemented |
| Entity 5: Public Engagement Events | `nepa_engagement__c` (custom) | ✅ Implemented |
| Entity 6: Case Events | `ApplicationTimeline` (PSS standard, extended) | ✅ Implemented |
| Entity 7: GIS Data | PSS `Polygon` (not yet linked) | 🔲 Tier 3 / v2.0 |
| Entity 8: User Role | Salesforce standard profiles/roles | 🔲 Use native Salesforce |
| Entity 9: Legal Structure | — | 🔲 Tier 3 / v2.0 |

All 6 implemented entities include the 5 custom provenance fields required by CEQ standard v1.2 (`Data Record Version`, `Data Source Agency`, `Data Source System`, `Record Owner Agency`, `Retrieved Timestamp`). `LastModifiedDate` (native Salesforce) satisfies the standard's `Last Updated` provenance property.


## Included Assets

This Accelerator includes the following assets:

<ol>
  <li><strong>Custom Fields</strong> on the following standard PSS objects:
    <ul>
      <li>Individual Application — 21 fields (Entity 2: Process)</li>
      <li>Content Version — 22 fields (Entity 3: Documents)</li>
      <li>Program — 20 fields (Entity 1: Project)</li>
      <li>Public Complaint — 14 fields (Entity 4: Comments)</li>
      <li>ApplicationTimeline — 17 fields (Entity 6: Case Events)</li>
    </ul>
  </li>
  <li><strong>Custom Objects</strong> (x3)
    <ul>
      <li>NEPA Public Engagement Event (<code>nepa_engagement__c</code>) — Entity 5: Public Engagement Events</li>
      <li>Process Agency Relationship (<code>nepa_process_related_agencies__c</code>)</li>
      <li>Project Agency Relationship (<code>nepa_project_agency_relationship__c</code>)</li>
    </ul>
  </li>
  <li><strong>Lightning Record Page</strong> (x1)
    <ul>
      <li>Public Comment Record Page</li>
    </ul>
  </li>
  <li><strong>Page Layouts</strong> (x5)
    <ul>
      <li>Content Version — Permit Document</li>
      <li>NEPA Public Engagement Event Layout</li>
      <li>ApplicationTimeline — NEPA Case Event Layout</li>
      <li>Process Agency Relationship Layout</li>
      <li>Project Agency Relationship Layout</li>
    </ul>
  </li>
  <li><strong>Permission Set</strong> (x1)
    <ul>
      <li>NEPA Permitting</li>
    </ul>
  </li>
  <li><strong>CEQ-Compliant Export (OmniStudio)</strong>
    <ul>
      <li><strong>DataRaptor Extracts</strong> (x6) — one per implemented entity, each mapping Salesforce fields to CEQ property names:
        <ul>
          <li><code>DR_Extract_NEPA_Project</code> — Program → CEQ Entity 1</li>
          <li><code>DR_Extract_NEPA_Process</code> — IndividualApplication → CEQ Entity 2</li>
          <li><code>DR_Extract_NEPA_Document</code> — ContentVersion → CEQ Entity 3</li>
          <li><code>DR_Extract_NEPA_Comment</code> — PublicComplaint → CEQ Entity 4</li>
          <li><code>DR_Extract_NEPA_EngagementEvent</code> — nepa_engagement__c → CEQ Entity 5</li>
          <li><code>DR_Extract_NEPA_CaseEvent</code> — ApplicationTimeline → CEQ Entity 6</li>
        </ul>
      </li>
      <li><strong>Integration Procedure</strong> (x1) — <code>NEPA/CEQExport</code>: assembles the full entity graph (Project → Processes → Documents + Comments + Case Events + Public Engagement Events) into a single CEQ standard v1.2 compliant JSON payload. Accepts <code>projectId</code> as input; expose via API Action for MFR #2 compliance.</li>
    </ul>
  </li>
  <li><strong>Documentation</strong>, including:
    <ul>
      <li>This readme file</li>
      <li><a href="docs/NEPA-Compliance-Improvement-Plan.md">NEPA Compliance Improvement Plan</a> — detailed gap analysis and implementation roadmap against CEQ standard v1.2 and the 10 Minimum Functional Requirements</li>
    </ul>
  </li>
</ol>


## Before You Install
* Spin up a Public Sector Solutions trial org [here](https://developer.salesforce.com/free-trials/comparison/public-sector)

**License Requirements** [Required]
* License Public Sector Solutions — requires Foundations or Advanced for internal; requires Communities for external

## Installation

Use the links below to install the unmanaged package into your org:

* [Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfn000001Uohx)
* [Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfn000001Uohx)

> **Note:** Installation links above reflect v1.0. Updated package links for v1.1 will be published once a new package version is created.

## Post-Install Setup & Configuration

### 1. Assign Permission Set
Assign users the Permission Set `NEPA Permitting`.

### 2. Individual Application (Entity 2: Process)
Navigate to Setup → Object Manager → `Individual Application` → Page Layouts. Edit the layout you use for permits and add the following fields:

**Process identity:**
- `Federal Unique Id`, `NEPA Review Type`, `Process Status`, `Process Stage`, `Process Code`, `Agency Process ID`

**Process details:**
- `Related Project`, `Parent Process`, `Joint Lead Agency`, `Purpose and Need`, `Process Description`, `Process Outcome`

**Timeline:**
- `Start Date`, `Completion Date`, `Public Comment Period Start`, `Public Comment Period End Date`

**Provenance (add to a collapsed section):**
- `Data Record Version`, `Data Source Agency`, `Data Source System`, `Record Owner Agency`, `Retrieved Timestamp`

**Related lists to add:**
- `Related Agencies` (from `nepa_process_related_agencies__c`)
- `Public Engagement Events` (from `nepa_engagement__c`)
- `Application Timeline` (from `ApplicationTimeline`)

### 3. Program (Entity 1: Project)
Navigate to Setup → Object Manager → `Program` → Page Layouts. Edit the layout you use for projects and add the following fields:

**Project identity:**
- `Project Title`, `Project Id`, `Project Sector`, `Project Type`, `Project Description`

**Ownership and funding:**
- `Lead Agency`, `Project Sponsor`, `Funding Source(s)`, `Current Status`, `Start Date`

**Location:**
- `Location`, `Location Latitude`, `Location Longitude`, `Location Text`

**Hierarchy:**
- `Parent Project`

**Provenance (add to a collapsed section):**
- `Data Record Version`, `Data Source Agency`, `Data Source System`, `Record Owner Agency`, `Retrieved Timestamp`

**Related lists to add:**
- `Child Projects` (from `Program`)
- `Individual Applications` (from `IndividualApplication.nepa_related_project__c`)
- `Project Agency Relationships` (from `nepa_project_agency_relationship__c`)

### 4. Content Version (Entity 3: Documents)
Navigate to Setup → Object Manager → `Content Version` → Page Layouts.

Use the Page Layout Assignment to assign the `Permit Document` page layout to profiles as appropriate for your org. The layout includes sections for Document Identity, Version Details, Document Content (summary/TOC), and Provenance.

### 5. Public Complaint (Entity 4: Comments)
Navigate to Setup → Object Manager → `Public Complaint` → Lightning Record Pages and `Public Comment Record Page`.

- Click the link and the Edit button on the corresponding page.
- Add the following fields to the page: `Related Document`, `Organization`, `Comment Category`, `Date Submitted`, `Method of Submission`, `Document Location Reference`, `Public Source`, `Agency Response`, `Public Access`.
- Add the Provenance fields to a collapsed section: `Data Record Version`, `Data Source Agency`, `Data Source System`, `Record Owner Agency`, `Retrieved Timestamp`.
- Use the Activation button to assign this page as an Org Default, App Default, etc. as appropriate for your organization.

### 6. NEPA Public Engagement Event (Entity 5)
Navigate to Setup → Object Manager → `NEPA Public Engagement Event` → Page Layouts.

The `NEPA Public Engagement Event Layout` is included and pre-configured. Assign it to the appropriate profiles.

To surface engagement events from the process record, add the `Public Engagement Events` related list to the `Individual Application` page layout (see step 2).

### 7. ApplicationTimeline — Case Events (Entity 6)
Navigate to Setup → Object Manager → `Application Timeline` → Page Layouts.

The `NEPA Case Event Layout` is included and pre-configured with NEPA event type, status, outcome, assigned entity, related document, and provenance fields. Assign it to the appropriate profiles.

To surface case events from the process record, add the `Application Timeline` related list to the `Individual Application` page layout (see step 2).


## CEQ-Compliant Data Export

This Accelerator includes an OmniStudio Integration Procedure that exports Salesforce permitting data as a CEQ standard v1.2-compliant JSON payload, supporting **MFR #2 (Data Sharing)** at the Emerging maturity level.

### How it works

The Integration Procedure `NEPA/CEQExport` accepts a `projectId` (the Salesforce `Program` record ID) and returns a nested JSON object containing all 6 implemented CEQ entities for that project.

**Output structure:**
```json
{
  "schema_version": "1.2",
  "standard": "CEQ NEPA and Permitting Data and Technology Standard",
  "exported_at": "2026-04-29T00:00:00Z",
  "project": {
    "id": "...",
    "project_id": "<UUID>",
    "project_title": "...",
    "processes": [
      {
        "federal_unique_id": "<UUID>",
        "nepa_review_type": "EIS",
        "status": "in progress",
        "documents": [
          {
            "document_type": "Draft EIS",
            "comments": [...]
          }
        ],
        "public_engagement_events": [...],
        "case_events": [...]
      }
    ]
  }
}
```

### Setup

1. **Activate DataRaptors**: In OmniStudio → DataRaptors, activate all 6 `DR_Extract_NEPA_*` DataRaptor Extracts.
2. **Activate Integration Procedure**: In OmniStudio → Integration Procedures, activate `NEPA/CEQExport`.
3. **Create API Action** (optional, for REST exposure):
   - Go to OmniStudio → API Actions → New
   - Name: `NEPA_CEQExport_API`
   - Method: `POST`; Custom API Name: `nepa_ceq_export`
   - Link to IP: `NEPA/CEQExport/English/1`
   - Map `projectId` from request body → IP input; map `CEQPayload` from IP output → response body
4. **Call the endpoint**:
   ```
   POST /services/apexrest/omnistudio/v1/integrationprocedure/NEPA_CEQExport
   Authorization: Bearer <session_token>
   Content-Type: application/json

   { "projectId": "001xx0000000001AAA" }
   ```

> **Note:** OmniStudio (formerly Vlocity) must be installed in your org. The Integration Procedure and DataRaptor metadata files are included in this package and can be deployed via SFDX. If you do not have OmniStudio, you can implement equivalent export logic using Apex or Flow.


## Data Model Notes

**Process status values** align with the CEQ standard: `planned | pre-application | in progress | paused | completed | cancelled`. These are intentionally not enumerated in the standard to allow agency flexibility — the picklist values provided are recommended defaults.

**External IDs**: `Program.nepa_project_id__c` and `IndividualApplication.nepa_federal_unique_id__c` are declared as External ID fields to support upsert operations from external agency systems. CEQ recommends UUID format for global uniqueness; field length is set to 36 characters accordingly.

**Comments as children of documents**: Per the CEQ standard Entity Relationship Diagram (Figure 1), `PublicComplaint` records should be linked to a specific `ContentVersion` document (e.g., a Draft EIS) via `nepa_parent_document__c`. The existing relationship to `IndividualApplication` may be retained for reporting convenience.

**Provenance fields**: The 5 custom provenance fields (`nepa_data_record_version__c`, `nepa_data_source_agency__c`, `nepa_data_source_system__c`, `nepa_record_owner_agency__c`, `nepa_retrieved_timestamp__c`) are present on all 6 implemented entities. `LastModifiedDate` (native) satisfies the standard's `Last Updated` property; no custom field is needed for it.

**Document type picklist**: The `nepa_document_type__c` picklist on `ContentVersion` includes: NOI, Draft EIS, Supplemental EIS, Programmatic EIS, Final EIS, ROD, Environmental Assessment, FONSI, CE Determination, Memorandum to File, Permit, Other.

**Multi-value text fields**: `Program.nepa_project_sector__c` and `Program.nepa_project_type__c` are LongTextArea fields that support multiple values separated by semicolons. Many real-world NEPA projects span multiple sectors and project types simultaneously (e.g., a resource management plan covering energy, land use, transportation, water, and agriculture). The CEQ standard does not restrict these to single values.

**Main document flag**: `ContentVersion.nepa_main_document__c` (Checkbox) distinguishes the primary document body from supporting files. Set to `true` for the main EIS/EA/CE document; `false` for appendices, attachments, maps, and supplemental files. Aligns with the NEPATEC2.0 corpus `main_document` field.


## Revision History

**1.1 (2026-04-29)** — CEQ Standard v1.2 alignment (Tier 1 + Tier 2) + CEQ-compliant export + NEPATEC2.0 compatibility
- Added OmniStudio Integration Procedure `NEPA/CEQExport` for CEQ standard v1.2-compliant JSON export (MFR #2 data sharing, Emerging maturity)
- Added 6 DataRaptor Extracts (`DR_Extract_NEPA_Project/Process/Document/Comment/EngagementEvent/CaseEvent`) mapping Salesforce fields to CEQ property names for all implemented entities
- Converted `Program.nepa_project_sector__c` from Picklist to LongTextArea(32768) to support multi-value sector assignments (e.g., NEPATEC2.0 projects with 5+ sectors)
- Converted `Program.nepa_project_type__c` from Text(255) to LongTextArea(32768) to support multi-value project type assignments (e.g., NEPATEC2.0 projects with 10+ types)
- Added `ContentVersion.nepa_main_document__c` (Checkbox) to distinguish primary documents from supporting files (appendices, attachments) — aligns with NEPATEC2.0 `main_document` flag
- Expanded `ContentVersion.nepa_volume_title__c` from Text(255) to LongTextArea(32768) to accommodate verbose section titles from published NEPA documents
- Added Entity 5 (Public Engagement Events) as new custom object `nepa_engagement__c`
- Extended PSS `ApplicationTimeline` with 17 NEPA fields for Entity 6 (Case Events) and FAST-41 milestone tracking
- Added `nepa_process_status__c` picklist to `IndividualApplication` with official CEQ status values (planned/pre-application/in progress/paused/completed/cancelled)
- Added `nepa_review_type__c` (EIS/EA/CE/Other Authorization) to `IndividualApplication`
- Added `nepa_parent_document__c` lookup on `PublicComplaint` → `ContentVersion` to correctly model the standard's comment-document relationship
- Added 5 CEQ v1.2 provenance fields to all 6 implemented entities (Program, IndividualApplication, ContentVersion, PublicComplaint, ApplicationTimeline, nepa_engagement__c)
- Added `nepa_url__c`, `nepa_related_case_event__c`, `nepa_contributing_agencies__c`, `nepa_document_summary__c`, `nepa_document_files__c`, `nepa_record_category__c` to `ContentVersion`
- Added `nepa_project_type__c`, `nepa_funding__c`, and lat/lon/text location fields to `Program`; updated status values to align with CEQ standard
- Added `nepa_organization__c`, `nepa_category__c`, `nepa_document_location_ref__c`, `nepa_public_source__c` to `PublicComplaint`
- Added `nepa_parent_process__c`, `nepa_agency_id__c`, `nepa_process_code__c`, `nepa_description__c` to `IndividualApplication`
- Expanded `ContentVersion` document type picklist (FONSI, EA, CE Determination, Programmatic EIS, Permit, Other)
- Updated ContentVersion layout into organized sections; added layouts for ApplicationTimeline and nepa_engagement__c
- Updated permission set to cover all new fields and `nepa_engagement__c` object

**1.0 (19 Sept 2025)** — Initial release: minimal viable compliance with NEPA data model


## Terms of Use

Thank you for using Global Public Sector (GPS) Accelerators. Accelerators are provided by Salesforce.com, Inc., located at 1 Market Street, San Francisco, CA 94105, United States.

By using this site and these accelerators, you are agreeing to these terms. Please read them carefully.

Accelerators are not supported by Salesforce, they are supplied as-is, and are meant to be a starting point for your organization. Salesforce is not liable for the use of accelerators.

For more about the Accelerator program, visit: [https://gpsaccelerators.developer.salesforce.com/](https://gpsaccelerators.developer.salesforce.com/)
