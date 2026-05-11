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
| Entity 7: GIS Data | `nepa_gis_data_element__c` (child of PSS `Polygon`) + Program lat/lon/polygon fields + GIS proximity flow | ✅ Implemented |
| Entity 8: User Role | `nepa_process_team_member__c` — structured role assignment linking User, Agency (Account), and Process with CEQ-required provenance fields | ✅ Implemented |
| Entity 9: Legal Structure | PSS `RegulatoryCode` (standard object) extended with `nepa_compliance_requirements__c`, `nepa_text_content__c`, and 5 provenance fields; `IndividualApplication` and `nepa_decision_element__c` lookup to `RegulatoryCode` | ✅ Implemented |

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
      <li><a href="docs/QUICKSTART.md">Quick Start Guide</a> — step-by-step deployment and configuration walkthrough</li>
      <li><a href="docs/ARCHITECTURE_DECISIONS.md">Architecture Decision Records</a> — object mapping rationale, flow design, and extension guidance</li>
      <li><a href="docs/FLOW-ARCHITECTURE.md">Flow Architecture</a> — explains the 30-flow design: error chain, stage gate split, defensibility wrapper</li>
      <li><a href="docs/AI-Use-Policy.md">AI Use Policy</a> — OMB M-24-10 compliant disclosure for CE Screening, Litigation Risk Scoring, and Comment Triage</li>
      <li><a href="docs/NEPA-Public-Comment-Processing.md">Public Comment Processing</a> — Comment Triage agent architecture, EJ/tribal gates, and audit trail design</li>
      <li><a href="docs/GIS-Proximity-Guide.md">GIS Proximity Guide</a> — deployment and extension guide for Entity 7 (GIS Data) proximity checks</li>
      <li><a href="docs/NEPA-Compliance-Improvement-Plan.md">CEQ Compliance Improvement Plan</a> — tier-based roadmap for full CEQ standard v1.2 coverage</li>
      <li><a href="docs/NEPA-Permitting-Acceleration-Plan.md">Permitting Acceleration Plan</a> — 10 ranked priorities with time-to-permit impact analysis grounded in NEPATEC2.0 data</li>
      <li><a href="docs/NEPA-Risk-Intelligence-Plan.md">Risk Intelligence Plan</a> — litigation risk scoring, challenge prediction, and defensibility gap features</li>
      <li><a href="docs/GLOSSARY.md">Glossary</a> — NEPA, regulatory, and PSS terms used throughout this project</li>
    </ul>
  </li>
</ol>


## Getting Started

This Accelerator is deployed via the Salesforce CLI from source. See **[docs/QUICKSTART.md](docs/QUICKSTART.md)** for the full step-by-step walkthrough covering prerequisites, deployment, permission set assignment, Flow activation, sample data loading, and verification.

**License requirement:** Salesforce Public Sector Solutions — Foundations or Advanced for internal users; Communities license for external portal users. A free PSS developer org is available at the [PSS trial link](https://developer.salesforce.com/free-trials/comparison/public-sector).


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


## PSS Dependency

This Accelerator is built on **Salesforce Public Sector Solutions (PSS)** and depends on three PSS standard objects that are not available in a standard Salesforce org:

| PSS Object | CEQ Entity | Dependency |
|---|---|---|
| `IndividualApplication` | Entity 2: Process | All 11 automation flows, permission set FLS, OmniStudio DataRaptor |
| `Program` | Entity 1: Project | Litigation risk scoring, CE screener, DataRaptor extract |
| `ApplicationTimeline` | Entity 6: Case Events | CE Determination Router, Timeline Risk Assessor, Admin Record Checker |

**If your org does not have PSS installed**, you will need to substitute these objects before deploying:

1. **`IndividualApplication`** — replace with a custom object (e.g., `NEPA_Process__c`) or a standard object such as `Case`. Update every flow's `Get_IndividualApplication` recordLookup, all `inputAssignments` writing to `IndividualApplicationId`, and all `fieldPermissions` referencing `IndividualApplication.*` in the permission set.
2. **`Program`** — replace with a custom object or `Account`. Update the Litigation Risk Scorer's `Get_RelatedProject` lookup and the `nepa_related_project__c` lookup field on `IndividualApplication`.
3. **`ApplicationTimeline`** — replace with a custom child object. Update the `IndividualApplicationId` master-detail field name and the `nepa_related_case_event__c` lookup on `ContentVersion`.

The three custom objects (`nepa_engagement__c`, `nepa_litigation__c`, `nepa_process_related_agencies__c`) and all custom metadata types are PSS-independent and deploy without modification.

**Installing PSS**: A free PSS developer org is available at the [PSS trial link](https://developer.salesforce.com/free-trials/comparison/public-sector) listed in Before You Install below. This is the recommended path — substituting the PSS objects removes access to PSS-native features such as Action Plans, OmniStudio, and the Application and Authorization data model relationships that the CEQ export relies on.


## Data Model Notes

**Process status values** align with the CEQ standard: `planned | pre-application | in progress | paused | completed | cancelled`. These are intentionally not enumerated in the standard to allow agency flexibility — the picklist values provided are recommended defaults.

**External IDs**: `Program.nepa_project_id__c` and `IndividualApplication.nepa_federal_unique_id__c` are declared as External ID fields to support upsert operations from external agency systems. CEQ recommends UUID format for global uniqueness; field length is set to 36 characters accordingly.

**Comments as children of documents**: Per the CEQ standard Entity Relationship Diagram (Figure 1), `PublicComplaint` records should be linked to a specific `ContentVersion` document (e.g., a Draft EIS) via `nepa_parent_document__c`. The existing relationship to `IndividualApplication` may be retained for reporting convenience.

**Provenance fields**: The 5 custom provenance fields (`nepa_data_record_version__c`, `nepa_data_source_agency__c`, `nepa_data_source_system__c`, `nepa_record_owner_agency__c`, `nepa_retrieved_timestamp__c`) are present on all 6 implemented entities. `LastModifiedDate` (native) satisfies the standard's `Last Updated` property; no custom field is needed for it.

**Document type picklist**: The `nepa_document_type__c` picklist on `ContentVersion` includes: NOI, Draft EIS, Supplemental EIS, Programmatic EIS, Final EIS, ROD, Environmental Assessment, FONSI, CE Determination, Memorandum to File, Permit, Other.

**Multi-value text fields**: `Program.nepa_project_sector__c` and `Program.nepa_project_type__c` are LongTextArea fields that support multiple values separated by semicolons. Many real-world NEPA projects span multiple sectors and project types simultaneously (e.g., a resource management plan covering energy, land use, transportation, water, and agriculture). The CEQ standard does not restrict these to single values.

**Main document flag**: `ContentVersion.nepa_main_document__c` (Checkbox) distinguishes the primary document body from supporting files. Set to `true` for the main EIS/EA/CE document; `false` for appendices, attachments, maps, and supplemental files. Aligns with the NEPATEC2.0 corpus `main_document` field.

**Object choice — `IndividualApplication` vs. `BusinessLicenseApplication`**: The PSS standard object chosen for CEQ Entity 2 (Process) is `IndividualApplication`, not `BusinessLicenseApplication`. This is intentional. NEPA proponents include individuals, joint ventures, tribes, federal agencies, and businesses — not exclusively commercial entities — so `BusinessLicenseApplication`'s business-licensing assumptions (renewal cycles, license numbers, business entity links) do not fit the NEPA process lifecycle. `IndividualApplication` carries the stage, status, and outcome workflow fields that map directly to CEQ's Process entity properties. The PSS object label can be overridden to "NEPA Process" or "Permit Application" in Setup → Object Manager without changing the API name or any downstream metadata.


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
