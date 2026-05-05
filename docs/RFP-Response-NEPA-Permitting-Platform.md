# Proposal Response
# NEPA Environmental Review Permitting Acceleration Platform

**Offeror:** [Vendor Name]
**RFP Reference:** [AGENCY]-NEPA-[YYYY]-[NNN]
**Response Date:** [Date]
**Volume:** I — Technical and Management Proposal

---

## Executive Summary

The proposed solution delivers a fully configured NEPA permitting acceleration platform built on **Salesforce Government Cloud Plus** and the **Salesforce Public Sector Solutions (PSS)** suite. It satisfies all nine CEQ Standard entities (CEQ NEPA and Permitting Data and Technology Standard v1.2), all Priority 1 functional requirements, and all Priority 1 technical, data, security, and implementation requirements.

The platform is FedRAMP High authorized on Salesforce Government Cloud Plus. No Agency-managed server infrastructure is required. The vast majority of capability is delivered through **configuration** — Salesforce declarative tools including Flows, Custom Metadata Types, OmniStudio Integration Procedures and DataRaptors, and the Salesforce Field Service scheduling engine — rather than custom code. This produces a maintainable, upgradeable platform that Agency administrators can extend without engaging developers for routine business rule changes.

**Capability classification key used throughout this response:**

| Code | Meaning |
|---|---|
| **(A)** | Available in current COTS/GOTS product without Agency-specific configuration |
| **(B)** | Achievable through platform configuration (Flows, Custom Metadata, OmniStudio, permission sets, page layouts) |
| **(C)** | Requires targeted custom development (Apex, custom LWC) |

Where **(C)** applies, the scope is bounded and identified.

---

## Table of Contents

1. [Technical Approach — Functional Requirements](#1-technical-approach--functional-requirements)
2. [Data and Interoperability Approach](#2-data-and-interoperability-approach)
3. [Security and AI Governance Approach](#3-security-and-ai-governance-approach)
4. [Implementation Plan](#4-implementation-plan)
5. [Past Performance](#5-past-performance)

---

## 1. Technical Approach — Functional Requirements

### 1.1 Project and Process Management (CEQ Entities 1 and 2) — PM-001 through PM-007

---

**PM-001 — Structured project record conforming to CEQ Entity 1** | **(B) Configuration**

The Salesforce PSS `Program` object serves as CEQ Entity 1 (Project). The platform extends the native `Program` object with the following custom fields pre-configured to CEQ v1.2 property names:

| CEQ Property | Salesforce Field | Type |
|---|---|---|
| federal_unique_project_id | `nepa_project_id__c` | Text (External ID, Unique) |
| project_title | `Name` | Standard |
| lead_agency | `AccountId` (lookup → Account) | Standard lookup |
| project_sector | `nepa_project_sector__c` | Picklist |
| project_type | `nepa_project_type__c` | Picklist |
| location_text | `nepa_location_description__c` | Text Area |
| location_lat / location_lon | `nepa_location_lat__c` / `nepa_location_lon__c` | Number (8,4) |
| location_polygon | `nepa_polygon__c` (lookup → Polygon) | Lookup |
| start_date | `nepa_start_date__c` | Date |
| + 5 CEQ provenance fields | `nepa_data_record_version__c`, `nepa_data_source_agency__c`, `nepa_data_source_system__c`, `nepa_record_owner_agency__c`, `nepa_retrieved_timestamp__c` | See DI-005 |

The `Polygon` object (native PSS) stores geometry as GeoJSON or KML in its `Data` field with a `DataType` picklist (GEOJSON / KML / OTHER). All fields are configurable by administrators and all five CEQ provenance fields are present on every record.

---

**PM-002 — Structured process record conforming to CEQ Entity 2** | **(B) Configuration**

The Salesforce PSS `IndividualApplication` object serves as CEQ Entity 2 (Process). This object was selected over `BusinessLicenseApplication` because NEPA proponents span individuals, businesses, agencies, tribes, and joint ventures — not exclusively commercial entities — and `IndividualApplication` carries the stage/status/outcome lifecycle fields that align with CEQ's Process properties. `BusinessLicenseApplication` carries renewal cycle and license-number assumptions that do not fit NEPA.

| CEQ Property | Salesforce Field | Notes |
|---|---|---|
| federal_unique_process_id | `nepa_federal_unique_id__c` | External ID, Unique |
| review_type | `nepa_review_type__c` | Picklist: CE / EA / EIS |
| process_status | `StatusCode` | PSS native lifecycle field |
| process_stage | `nepa_process_stage__c` | Picklist aligned to stage gate model |
| comment_period_start / end | `nepa_comment_start_date__c` / `nepa_comment_end_date__c` | Date |
| completion_date | `nepa_completion_date__c` | Date |
| related_project | `nepa_related_project__c` | Lookup → Program |
| + all remaining CEQ v1.2 process properties | Custom fields | See DI-001 |

---

**PM-003 — Multiple processes per project** | **(A) COTS**

Multiple `IndividualApplication` records link to a single `Program` via `nepa_related_project__c`. No limit is imposed by the platform. Tiered reviews, supplemental EIS records, and concurrent regulatory process tracks are fully supported. The Program record page displays all linked processes in a related list with review type, status, and stage visible at a glance.

---

**PM-004 — Configurable stage gates** | **(B) Configuration**

Stage gate enforcement is implemented through two declarative Flows:

- **`NEPA_Stage_Gate_Doc_Check`** — evaluates whether all required documents for the current stage and review type are present and in Approved status before allowing stage advancement. Required document rules are stored in a Custom Metadata Type (`NEPA_Required_Doc_Config__mdt`) and are editable by administrators without code changes.

- **`NEPA_Stage_Gate_Orchestrator`** — coordinates the full gate check sequence: document check, consultation certification, prior stage status, and custom rule evaluation. It blocks the `IndividualApplication` status field from advancing if any gate condition is unmet and surfaces a specific error message identifying the unmet condition.

Gate configurations (which documents are required, which consultations must be certified, and which stage transitions they govern) are all stored as Custom Metadata records. Administrators add or modify gate rules in Setup without modifying Flow XML.

---

**PM-005 — CE, EA, and EIS review pathways** | **(B) Configuration**

Three review pathways are pre-configured as distinct branches within `NEPA_Stage_Gate_Orchestrator`, each with its own stage sequence and required document registry entries in `NEPA_Required_Doc_Config__mdt`. The `nepa_review_type__c` picklist value (CE / EA / EIS) drives pathway selection. Administrators may define additional review pathways by adding Custom Metadata records for stage definitions and required document rules.

The CE pathway includes an automated screening step (`NEPA_CE_Screener` Flow) that evaluates the application against configurable CE criteria and extraordinary circumstance conditions stored in Custom Metadata, and can auto-advance eligible applications or flag them for human review.

---

**PM-006 — FRA statutory deadline clock** | **(B) Configuration**

The statutory deadline clock per 42 U.S.C. § 4336a is implemented as a formula field on `IndividualApplication` that calculates elapsed time from `nepa_statutory_clock_start__c`. Pause/resume logic is implemented through two date fields (`nepa_clock_pause_date__c` and `nepa_clock_resume_date__c`) and an accumulated pause-days number field. An after-save Flow updates the accumulated pause days when a resume event is recorded. The SLA monitor (`NEPA_SLA_Escalation_Monitor`) references the adjusted deadline for warning and escalation calculations. Administrators configure warning thresholds as Custom Metadata records.

---

**PM-007 — SLA monitoring with automated escalation** | **(B) Configuration**

The `NEPA_SLA_Escalation_Monitor` scheduled Flow runs on a configurable daily cadence. It evaluates every active `IndividualApplication` against configurable deadline and warning thresholds stored in `NEPA_SLA_Config__mdt`. When a deadline is at risk, it creates an escalation task and triggers a notification to the Lead NEPA Coordinator assigned on the process team. Thresholds are configurable per review type and stage without code changes.

---

### 1.2 Field Scheduling and Work Order Management — FS-001 through FS-006

---

**FS-001 — Automatic work order generation** | **(B) Configuration**

Salesforce **Field Service** (`WorkOrder`) is the platform's scheduling foundation. An after-save record-triggered Flow fires on `IndividualApplication` when a configurable trigger event occurs (e.g., pre-application consultation stage closes). The Flow generates `WorkOrder` records for each interdisciplinary team survey type defined in the `WorkType` registry for the applicable review pathway. Work type definitions are stored as `WorkType` records and are configurable by administrators. The Carrie Placer Mine demo ships with seven work types: Archaeology, Botany, Wildlife/Sage-Grouse, Hydrology, Geology, Access Evaluation, and Project Management Coordination.

---

**FS-002 — Seasonal survey constraints** | **(B) Configuration**

Seasonal window enforcement is implemented at two layers:

1. **`WorkType` scheduling rules** — each survey type carries earliest/latest date constraints encoded as `ServiceAppointment` scheduling policy rules in the Field Service Scheduling Policy configuration. These prevent the optimizer from scheduling a survey outside its valid seasonal window.
2. **Custom Metadata (`NEPA_Seasonal_Window__mdt`)** — stores species- or resource-specific seasonal constraints (e.g., sage-grouse lek survey window: March 1 – June 15) that are evaluated by a Flow validation at the `ServiceAppointment` save event. Administrators add or update seasonal windows by editing Custom Metadata records in Setup without code changes.

---

**FS-003 — Shared physical access resource enforcement** | **(B) Configuration**

Shared physical access points (locked gates, access roads) are modeled as `ServiceResource` records of type "Equipment" linked to the relevant `ServiceTerritory`. The Field Service Scheduling Policy enforces non-overlapping scheduling across resources. When two specialists require the same gate on the same day, the scheduling engine resolves the conflict by shifting one appointment to the next available non-conflicting slot. The demo dataset ships with a Jordan Creek gate resource illustrating non-overlapping gate date enforcement across seven specialists.

---

**FS-004 — Offline mobile work order completion** | **(A) COTS**

The **Salesforce Field Service Mobile** application (iOS and Android) provides native offline capability. Field specialists can view assigned work orders, complete inspection checklists, capture photos and GPS coordinates, and close work orders without network connectivity. Data automatically synchronizes to the org when connectivity is restored. No additional configuration is required for core offline functionality; sync conflict resolution policies are configurable by administrators.

---

**FS-005 — Optimization engine** | **(A) COTS with (B) configuration**

The **Salesforce Field Service Scheduling Optimizer** simultaneously sequences multiple work orders against seasonal constraints, resource availability, travel efficiency, and skill requirements. Optimization policies (constraint weights, travel-time thresholds, skill match rules) are configurable as Scheduling Policy records by administrators. The optimizer is invoked as a managed package capability requiring no custom code.

---

**FS-006 — Co-permit task creation on work order close** | **(B) Configuration**

An after-save Flow triggers on `WorkOrder` status change to "Completed" and evaluates a Custom Metadata mapping (`NEPA_Copermit_Trigger__mdt`) to determine whether the closed work type requires a co-permit initiation task. If so, the Flow creates a `Task` with the appropriate subject (e.g., "Initiate EPA NPDES NOI," "Initiate IDWR Water Right Permit") and SLA due date, assigns it to the configured responsible role, and links it to the parent `IndividualApplication`. The co-permit mapping is fully editable in Custom Metadata without code changes.

---

### 1.3 Document Management (CEQ Entity 3) — DM-001 through DM-006

---

**DM-001 — Document records conforming to CEQ Entity 3** | **(B) Configuration**

Salesforce `ContentVersion` serves as CEQ Entity 3 (Documents). Custom fields extend the standard object to capture all CEQ v1.2 document properties:

| CEQ Property | Salesforce Field |
|---|---|
| document_type | `nepa_document_type__c` (Picklist) |
| document_status | `nepa_document_status__c` (Picklist) |
| publish_date | `nepa_publish_date__c` (Date) |
| public_access | `nepa_public_access__c` (Checkbox) |
| process_link | `nepa_process__c` (Lookup → IndividualApplication) |
| + 5 CEQ provenance fields | Standard pattern — all 5 fields present |

The `IsLatest` flag on `ContentVersion` is a standard Salesforce field providing automatic latest-version designation.

---

**DM-002 — Required document registry with stage gate enforcement** | **(B) Configuration**

The `NEPA_Required_Doc_Config__mdt` Custom Metadata Type stores a registry of required document types keyed by review type and stage. Each record specifies: review type (CE/EA/EIS), stage name, required document type, and whether the document must be in Approved status. The `NEPA_Stage_Gate_Doc_Check` Flow queries this registry at stage-gate evaluation time and verifies that matching `ContentVersion` records exist with approved status. If any required document is missing, the gate blocks advancement and names the missing document in the error message. Administrators add new requirements by inserting Custom Metadata records without modifying Flow logic.

---

**DM-003 — Document versioning** | **(A) COTS**

Salesforce `ContentVersion` provides native document versioning. Each upload creates a new version linked to the same `ContentDocument`. `IsLatest = true` designates the current version. Full version history is accessible from the Files related list on any linked record. No configuration is required.

---

**DM-004 — Page limit enforcement per 40 CFR 1502.7** | **(B) Configuration**

Page limit thresholds are stored as Custom Metadata records (`NEPA_Doc_PageLimit__mdt`) keyed by document type and review pathway (e.g., EIS draft body: 150 pages; EA: 75 pages). A validation rule on `ContentVersion` evaluates the `nepa_page_count__c` field against the applicable Custom Metadata record when a document is saved in draft or approved status. Administrators update page limit thresholds by editing Custom Metadata records.

---

**DM-005 — AI-assisted EIS section drafts** | **(B) Configuration with (A) Einstein**

EIS section drafting assistance is delivered through **Salesforce Einstein** (Prompt Builder / Einstein Copilot actions) configured to pull structured data from the `IndividualApplication`, linked `ContentVersion` records, and `ApplicationTimeline` events as grounding context for draft generation. Human review is enforced at the workflow level: the AI-generated draft is written to a `ContentVersion` with `nepa_document_status__c = 'AI Draft — Pending Review'`. The stage gate blocks the document from advancing to Approved until a human reviewer changes the status, creating the mandatory human-in-the-loop control required by OMB M-24-10. No AI draft can reach Approved status without a human state change.

---

**DM-006 — Administrative record export** | **(B) Configuration**

The `NEPA_Administrative_Record_Checker` Flow produces a complete inventory of all documents, comments, engagement events, and timeline events associated with a process. An OmniStudio Integration Procedure (`NEPA_ARExport`) assembles this inventory into a date-stamped, indexed export via a DataRaptor Extract. The export record is written to `nepa_ar_export__c` and the archive is generated as a `ContentVersion` zip manifest linked to the process. Administrators trigger export from a quick action on the process record page.

---

### 1.4 Public Comment Management (CEQ Entity 4) — PC-001 through PC-007

---

**PC-001 — Comment intake via web form, email, and written mail** | **(B) Configuration**

The `PublicComplaint` object (PSS standard) serves as CEQ Entity 4 (Public Comments). The platform provides three intake channels:

1. **Web form** — an OmniScript (`NEPA_CE_Intake` or a dedicated comment submission OmniScript) deployed through Salesforce Experience Cloud collects commenter name, organization, submission method, date, and comment body and creates a `PublicComplaint` record directly.
2. **Email-to-case** — Salesforce Email-to-Case (configured as Email-to-PublicComplaint via a routing rule) ingests emailed comments and creates records automatically.
3. **Written mail** — agency staff manually enter mailed comments through the internal comment entry form on the process record.

All three channels populate the same `PublicComplaint` record with submission method recorded in `nepa_submission_method__c`.

---

**PC-002 — Comment period gating** | **(B) Configuration**

The `NEPA_Comment_Period_Gate` Flow fires before save on `PublicComplaint`. It compares the submission timestamp against `nepa_comment_start_date__c` and `nepa_comment_end_date__c` on the parent `IndividualApplication`. If the submission falls outside the open window, the Flow throws an error that prevents the record from saving and returns a user-facing message. The Experience Cloud portal's comment submission form invokes the same gate, preventing portal submissions outside the comment period without exposing the enforcement logic to the public user.

---

**PC-003 — Substantive / non-substantive classification** | **(B) Configuration**

A `nepa_comment_classification__c` picklist field on `PublicComplaint` captures the classification (Substantive / Non-Substantive / Pending Review). An AI-assisted default classification is set by the `NEPA_Comment_Triage_Save` Flow (see PC-004), but the field is always editable by agency reviewers. Any change to the classification is captured in Salesforce's field history tracking and the full field audit trail, satisfying OMB M-24-10 override documentation requirements. The AI-generated classification and the human reviewer's final classification are both preserved with timestamps and user identity.

---

**PC-004 — AI-assisted comment triage** | **(B) Configuration**

The `NEPA_Comment_Triage_Save` Flow invokes an Einstein Prompt Template that performs sentiment analysis, topic clustering, and substantive issue identification on the comment body. The Flow:

1. Calls the Einstein action and receives a structured classification response.
2. Writes the AI-suggested classification to `nepa_ai_classification__c` (read-only to reviewers).
3. Writes the AI confidence score to `nepa_ai_confidence__c`.
4. Writes the human-readable AI rationale to `nepa_ai_rationale__c`.
5. Sets `nepa_comment_classification__c` to the AI suggestion as a default, leaving it editable.
6. Requires no human action to persist the AI output; human override is tracked in field history.

All AI output fields are included in the administrative record export, satisfying OMB M-24-10 audit trail requirements.

---

**PC-005 — Litigation history registry** | **(B) Configuration**

The `nepa_litigation__c` custom object stores prior NEPA litigation cases with plaintiff organization, citation, outcome, case type, and jurisdiction. The `NEPA_Plaintiff_Profile__mdt` Custom Metadata Type maintains a registry of organizations with prior plaintiff history for fast lookup.

When a `PublicComplaint` is saved, the `NEPA_Litigation_Risk_Scorer` Flow queries `NEPA_Plaintiff_Profile__mdt` for the commenter's organization. If a match is found, the Flow:

1. Sets `nepa_plaintiff_flag__c = true` on the `PublicComplaint`.
2. Writes the matching litigation case reference to `nepa_litigation_reference__c`.
3. Creates a `Task` for elevated legal review assignment.

The flag and rationale (which prior case triggered it) are recorded on the `PublicComplaint` record and included in the administrative record export. Administrators maintain the plaintiff registry by updating `NEPA_Plaintiff_Profile__mdt` without code changes.

---

**PC-006 — Route substantive comments as work orders** | **(B) Configuration**

When a `PublicComplaint` is classified as Substantive and assigned a resource specialist, an after-save Flow creates a `WorkOrder` linked to the parent `IndividualApplication` with work type "Comment Response." The work order carries the comment text, classification rationale, and SLA due date calculated from `NEPA_SLA_Config__mdt`. SLA status is visible on the process record page. Response status (Open / In Progress / Responded) is tracked on the `PublicComplaint` record and updated when the work order is closed.

---

**PC-007 — Comment response log** | **(B) Configuration**

Each `PublicComplaint` record carries `nepa_response_text__c` (the agency's final response), `nepa_response_date__c`, `nepa_response_document_section__c` (the section of the EA/EIS/response-to-comments document where the comment is addressed), and `nepa_response_status__c`. The relationship between every substantive comment, its response text, the responding specialist (via work order assignee), and the document section reference constitutes the complete comment response log. This log is included in the administrative record export.

---

### 1.5 Public Engagement Events (CEQ Entity 5) — PE-001 through PE-003

---

**PE-001 — Engagement event tracking per CEQ Entity 5** | **(B) Configuration**

The `nepa_engagement__c` custom object serves as CEQ Entity 5 (Public Engagement Events). Fields map directly to CEQ v1.2 properties:

| CEQ Property | Salesforce Field |
|---|---|
| event_type | `nepa_event_type__c` (Picklist: Public Hearing, Scoping Meeting, Tribal Consultation, Cooperating Agency Meeting, Notice of Intent, Other) |
| event_format | `nepa_event_format__c` (Picklist: In-Person / Virtual / Hybrid) |
| event_date | `nepa_event_date__c` (DateTime) |
| location | `nepa_event_location__c` (Text) |
| attendance_count | `nepa_attendance_count__c` (Number) |
| public_access | `nepa_public_access__c` (Checkbox) |
| process_link | `nepa_process__c` (Lookup → IndividualApplication) |
| + 5 provenance fields | Standard pattern |

---

**PE-002 — ADA accessibility, translation services, advance notice** | **(B) Configuration**

Three fields on `nepa_engagement__c` capture these compliance properties:

- `nepa_ada_provisions__c` (Long Text Area) — describes ADA accommodations provided
- `nepa_translation_services__c` (Multi-Select Picklist) — languages provided
- `nepa_advance_notice_days__c` (Number) — days of public notice before the event

These are reportable fields and are included in the CEQ export payload.

---

**PE-003 — Tribal consultation gate** | **(B) Configuration**

Tribal consultation events are designated by `nepa_event_type__c = 'Tribal Consultation'` and carry a dedicated response window SLA field (`nepa_tribal_response_deadline__c`). The `NEPA_Stage_Gate_Orchestrator` Flow checks for the existence of at least one `nepa_engagement__c` record of type Tribal Consultation with `nepa_consultation_certified__c = true` before permitting EA/EIS publication stage advancement. This creates a hard gate that blocks document publication until consultation is certified complete. Certification is performed by the Lead NEPA Coordinator via a quick action on the engagement record.

---

### 1.6 Case Events and Timeline (CEQ Entity 6) — TL-001 through TL-003

---

**TL-001 — Structured case event timeline per CEQ Entity 6** | **(B) Configuration**

The Salesforce PSS `ApplicationTimeline` object serves as CEQ Entity 6 (Case Events). Fields map to CEQ v1.2 properties:

| CEQ Property | Salesforce Field |
|---|---|
| event_type | `Type` (Picklist — standard PSS) |
| event_status | `Status` (standard PSS) |
| tier | `nepa_tier__c` (Picklist: Federal / State / Local / Tribal) |
| source | `nepa_source__c` (Text) |
| start_date | `StartDate` (Date — standard) |
| end_date | `EndDate` (Date — standard) |
| public_access | `nepa_public_access__c` (Checkbox) |
| process_link | `nepa_related_process__c` (Lookup → IndividualApplication) |

The Carrie Placer Mine demo ships with 125 `ApplicationTimeline` records spanning the full 8-month review lifecycle from pre-application through Decision Record issuance.

---

**TL-002 — Timeline display** | **(B) Configuration**

The `IndividualApplication` record page is configured with a timeline component that displays `ApplicationTimeline` records in chronological order. Completed events display with a closed-status indicator; in-progress events display with an active indicator; planned events display with a future-state indicator. The visual distinction is driven by the `Status` field value mapped in the Lightning component configuration.

---

**TL-003 — Projected completion dates** | **(B) Configuration**

A scheduled Flow (`NEPA_Timeline_Risk_Assessor`) evaluates the remaining required `ApplicationTimeline` events against historical average stage durations stored in `NEPA_Stage_Duration_Benchmark__mdt` Custom Metadata. The Flow calculates a projected completion date and writes it to `nepa_projected_completion_date__c` on `IndividualApplication`. The projection is recalculated nightly and displayed on the process record page and the applicant portal.

---

### 1.7 GIS Data (CEQ Entity 7) — GIS-001 through GIS-005

---

**GIS-001 — GIS data element records per CEQ Entity 7** | **(B) Configuration**

The `nepa_gis_data_element__c` custom object serves as CEQ Entity 7 (GIS Data). Fields map to CEQ v1.2 properties:

| CEQ Property | Salesforce Field |
|---|---|
| format | `nepa_format__c` (Picklist: GeoJSON / KML / Shapefile / WMS / WFS / Other) |
| access_method | `nepa_access_method__c` (Picklist: API / Download / Portal / Internal) |
| coordinate_system | `nepa_coordinate_system__c` (Text, e.g., "WGS 84 (EPSG:4326)") |
| bounding_box | `nepa_bounding_box__c` (Text, min/max lat/lon) |
| purpose | `nepa_purpose__c` (Text) |
| access_information | `nepa_access_information__c` (URL) |
| database_reference | `nepa_database_reference__c` (Checkbox — indicates whether the layer is registered in the platform's GIS layer registry) |
| polygon_link | `nepa_polygon__c` (Lookup → Polygon) |
| data_source_system | `nepa_data_source_system__c` |
| + 5 provenance fields | Standard pattern |

The Carrie Placer Mine demo ships with five `nepa_gis_data_element__c` records: BLM Claim Boundary (GeoBOE), Jordan Creek Watershed (NHD+ High Resolution), Sage-Grouse PHMA (ArcGIS Online), ESA Critical Habitat — Columbia Spotted Frog (USFWS), and NWI Wetlands (National Wetlands Inventory).

---

**GIS-002 — Point and polygon storage** | **(B) Configuration**

Project location is stored at two levels:

- **Point**: `nepa_location_lat__c` and `nepa_location_lon__c` (Number fields) on the `Program` object.
- **Polygon**: `nepa_polygon__c` (Lookup → Polygon) on `Program`. The PSS `Polygon` object stores geometry in its `Data` field (Long Text Area) with a `DataType` picklist (GEOJSON / KML / OTHER). The Carrie Placer Mine demo ships with a GeoJSON polygon representing the mine claim boundary.

---

**GIS-003 — Automated proximity checks against federal spatial datasets** | **(B) Configuration**

Automated proximity checking is implemented through two declarative components:

1. **`NEPA_GIS_Proximity_Check` Flow** — an after-save record-triggered Flow on `Program` that fires when `nepa_location_lat__c` or `nepa_location_lon__c` changes and both are non-null. The Flow calls `NEPA_GIS_Proximity_IP`, an OmniStudio Integration Procedure.

2. **`NEPA_GIS_Proximity_IP` Integration Procedure** — iterates over the GIS layer registry (Custom Metadata Type `NEPA_GIS_Layer__mdt`) and calls each registered ArcGIS FeatureServer endpoint via Named Credentials. For each layer, it evaluates whether the project point falls within the proximity buffer. Results are written back to the `Program` record and create `nepa_gis_data_element__c` records for each triggered layer.

The platform ships with four pre-configured layer entries: BLM Surface Management, USFWS Critical Habitat, National Wetlands Inventory, and EPA EJSCREEN Environmental Justice Index.

---

**GIS-004 — Proximity results written back to project record; CE flag** | **(B) Configuration**

`NEPA_GIS_Proximity_IP` writes the following back to the `Program` record upon completion:

- `nepa_proximity_result_summary__c` — human-readable summary of triggered layers
- `nepa_extraordinary_circumstances_flag__c` — Boolean set to `true` if any triggered layer matches a layer designated as an extraordinary circumstance trigger in `NEPA_GIS_Layer__mdt`

The extraordinary circumstances flag is evaluated by `NEPA_CE_Screener` during CE eligibility screening. If `true`, the screener routes the application for elevated review rather than auto-advancing to CE determination.

---

**GIS-005 — Configurable GIS layer registry without code changes** | **(A/B) COTS/Configuration**

The GIS layer registry (`NEPA_GIS_Layer__mdt`) is a Custom Metadata Type. Each record stores: layer name, FeatureServer URL, Named Credential reference, proximity buffer (meters), extraordinary circumstances flag, and active/inactive toggle. Administrators add, update, or deactivate layers by editing Custom Metadata records in Salesforce Setup. No code changes, no deployment cycle required. Named Credentials are managed separately in the Salesforce security settings and support OAuth 2.0 and API key authentication to any OGC-compliant or ArcGIS REST service.

---

### 1.8 User Role Management (CEQ Entity 8) — UR-001 through UR-003

---

**UR-001 — Structured process team member assignments** | **(B) Configuration**

The `nepa_process_team_member__c` custom object serves as CEQ Entity 8 (User Roles). Each record is a MasterDetail child of `IndividualApplication`, linking a Salesforce User, an agency Account, a role type, and assignment dates to a specific process:

| CEQ Property | Salesforce Field |
|---|---|
| role_type | `nepa_role_type__c` (Picklist: Lead NEPA Coordinator, Cooperating Agency Rep, Reviewer, Preparer, Legal Reviewer, Tribal Liaison, GIS Specialist, Field Team Member, Other) |
| user | `nepa_user__c` (Lookup → User) |
| agency | `nepa_agency__c` (Lookup → Account) |
| process | `nepa_process__c` (MasterDetail → IndividualApplication) |
| start_date | `nepa_start_date__c` (Date) |
| end_date | `nepa_end_date__c` (Date) |
| + 5 provenance fields | Standard pattern |

The Carrie Placer Mine demo ships with seven team member records covering the BLM Owyhee Field Office interdisciplinary team.

---

**UR-002 — Active/inactive assignment flag** | **(B) Configuration**

`nepa_active__c` (Checkbox, default `true`) on `nepa_process_team_member__c` provides the active/inactive designation. When an assignment ends, the record is not deleted — `nepa_active__c` is set to `false` and `nepa_end_date__c` is populated. The full assignment history is preserved in the process administrative record. Field history tracking on `nepa_active__c` provides an immutable record of when assignments were deactivated and by whom.

---

**UR-003 — Team members exportable in CEQ payload** | **(B) Configuration**

The `DR_Extract_NEPA_TeamMember` DataRaptor Extract queries `nepa_process_team_member__c` filtered by `nepa_process__c`. It is invoked by the `NEPA_CEQExport` Integration Procedure within the process loop (`LoopProcesses` step) and contributes a `team_members` array to each process node in the CEQ JSON payload. All 16 mapped fields including role type, agency, user, dates, active flag, notes, and five provenance fields are included.

---

### 1.9 Legal Structure (CEQ Entity 9) — LS-001 through LS-003

---

**LS-001 — Regulatory citation linkage per process** | **(B) Configuration**

The Salesforce PSS `RegulatoryCode` object serves as CEQ Entity 9 (Legal Structure). `IndividualApplication` carries a `nepa_legal_structure__c` lookup field pointing to the primary `RegulatoryCode` for the process. The `RegulatoryCode` object stores:

| CEQ Property | Salesforce Field |
|---|---|
| citation | `Name` |
| issuing_authority | `RegulatoryAuthorityId` (Lookup → RegulatoryAuthority) |
| effective_date | `EffectiveFrom` (Date — PSS native) |
| expiry_date | `EffectiveTo` (Date — PSS native) |
| compliance_requirements | `nepa_compliance_requirements__c` (Long Text Area) |
| regulatory_text | `nepa_text_content__c` (Long Text Area) |
| description | `Description` (standard) |
| external_url | `ExternalUrl` (standard) |

The Carrie Placer Mine demo ships with seven `RegulatoryCode` records covering: 42 U.S.C. § 4321 (NEPA), 40 CFR § 1501.5 (Lead Agency), 40 CFR § 1501.9 (Scoping), 43 CFR § 3809.11 (BLM Surface Management), 16 U.S.C. § 1536(a) (ESA Section 7), 54 U.S.C. § 306108 (NHPA Section 106), and 33 U.S.C. § 1342 (Clean Water Act NPDES).

---

**LS-002 — Citations linkable to decision elements** | **(B) Configuration**

The `nepa_decision_element__c` custom object stores configurable decision elements (CE criteria, threshold values, extraordinary circumstance conditions). Each record carries a lookup to `RegulatoryCode`, associating the decision element with its legal authority. `NEPA_CE_Screener` queries `nepa_decision_element__c` records linked to the applicable `RegulatoryCode` to drive automated CE screening logic. Administrators add or modify decision elements and their citation linkages without code changes.

---

**LS-003 — Configurable citation registry with EffectiveTo dating** | **(A/B) COTS/Configuration**

`RegulatoryCode` is a native PSS object with standard `EffectiveTo` and `EffectiveFrom` date fields. When a regulation is superseded, administrators set `EffectiveTo` to the supersession date; the record is never deleted. Active citations are distinguished by `EffectiveTo = null` or `EffectiveTo > today`. Administrators manage the citation registry through the Legal Structure tab in the NEPA Permitting app without code changes.

---

### 1.10 Applicant Self-Service Portal — AP-001 through AP-005

---

**AP-001 — Authenticated applicant portal for permit status** | **(A/B) COTS/Configuration**

The applicant-facing portal is built on **Salesforce Experience Cloud** (Government Cloud Plus, FedRAMP High). Authenticated applicants log in with their portal credentials and see a filtered view showing only their own `IndividualApplication` records. The portal home page displays current status, active stage, projected completion date, and the process timeline in a read-only view. Experience Cloud's record access model enforces row-level isolation: applicants cannot access other parties' records regardless of URL manipulation.

---

**AP-002 — Automated applicant notifications** | **(B) Configuration**

Notification triggers are implemented as after-save Flows that fire on `IndividualApplication` and `ContentVersion` when configurable status or stage fields change. Each trigger evaluates the applicable `nepa_process_team_member__c` record for the applicant contact and dispatches an Experience Cloud notification and an email using a Salesforce email template. Configurable trigger events include: comment period open, decision issued, document published, and action item assigned. Notification template content is editable by administrators.

---

**AP-003 — Portal comment submission with period gate enforcement** | **(B) Configuration**

The Experience Cloud portal includes a comment submission form (OmniScript) accessible to authenticated applicants. The OmniScript invokes the same `NEPA_Comment_Period_Gate` Flow that governs staff-entered comments. If the comment period is closed, the portal displays a specific message ("The comment period for this review closed on [date]") and does not create a `PublicComplaint` record. The gate check is server-side; it cannot be bypassed by client-side manipulation.

---

**AP-004 — Published document access and signed decision delivery** | **(B) Configuration**

`ContentVersion` records with `nepa_public_access__c = true` are exposed to the portal through a file sharing configuration on the Experience Cloud site. Applicants see a documents tab on their process record filtered to public-access documents. When a Decision Record is published, a Flow triggers email delivery of a signed PDF (stored as a `ContentVersion`) to the applicant's registered email address and posts it to the portal documents tab.

---

**AP-005 — Co-permit action items on portal** | **(B) Configuration**

`Task` records assigned to the applicant contact with `nepa_task_category__c = 'Co-Permit Action'` are surfaced on the portal in a tasks component. Each task displays subject, due date, and status. Applicants can mark tasks complete on the portal; completion is written back to the Salesforce `Task` record and triggers a notification to the assigned agency coordinator.

---

## 2. Data and Interoperability Approach

### CEQ Standard v1.2 Conformance Mapping

---

**DI-001 — Full nine-entity CEQ data model conformance** | **(B) Configuration**

All nine CEQ Standard entities are implemented as follows:

| CEQ Entity | Salesforce Object | Type |
|---|---|---|
| Entity 1 — Project | `Program` | PSS Standard (extended) |
| Entity 2 — Process | `IndividualApplication` | PSS Standard (extended) |
| Entity 3 — Documents | `ContentVersion` | Platform Standard (extended) |
| Entity 4 — Public Comments | `PublicComplaint` | PSS Standard (extended) |
| Entity 5 — Public Engagement Events | `nepa_engagement__c` | Custom |
| Entity 6 — Case Events | `ApplicationTimeline` | PSS Standard (extended) |
| Entity 7 — GIS Data | `nepa_gis_data_element__c` | Custom |
| Entity 8 — User Roles | `nepa_process_team_member__c` | Custom Junction |
| Entity 9 — Legal Structure | `RegulatoryCode` | PSS Standard (extended) |

Every entity carries all five CEQ provenance fields (see DI-005). Object-to-entity mapping is documented in the data architecture deliverable (D-03).

---

**DI-002 — Structured JSON export payload per project** | **(B) Configuration**

The `NEPA_CEQExport` OmniStudio Integration Procedure produces a standards-compliant JSON export for any project. It is invocable via REST API call to the OmniStudio endpoint. The payload structure:

```
{
  "ceq_standard_version": "1.2",
  "standard_name": "CEQ NEPA and Permitting Data and Technology Standard",
  "export_timestamp": "[ISO 8601]",
  "project": { ... },               // Entity 1 — DR_Extract_NEPA_Project
  "gis_data": [ ... ],              // Entity 7 — DR_Extract_NEPA_GISData
  "processes": [                    // Entity 2 — DR_Extract_NEPA_Process
    {
      ...,
      "documents": [ ... ],         // Entity 3 — DR_Extract_NEPA_Documents
      "comments": [ ... ],          // Entity 4 — DR_Extract_NEPA_Comments
      "engagements": [ ... ],       // Entity 5 — DR_Extract_NEPA_Engagement
      "timeline": [ ... ],          // Entity 6 — DR_Extract_NEPA_Timeline
      "team_members": [ ... ],      // Entity 8 — DR_Extract_NEPA_TeamMember
      "legal_structure": { ... }    // Entity 9 — DR_Extract_NEPA_LegalStructure
    }
  ]
}
```

Nine DataRaptor Extract definitions supply all field mappings. Output key names are aligned to CEQ standard property names.

---

**DI-003 — Schema version, standard name, and export timestamp** | **(B) Configuration**

The `AssembleCEQPayload` Set Values step in `NEPA_CEQExport` writes `ceq_standard_version: "1.2"`, `standard_name: "CEQ NEPA and Permitting Data and Technology Standard"`, and `export_timestamp` (populated from `{!$Flow.CurrentDateTime}`) into the root of the JSON payload before output. When the CEQ standard version is updated, administrators update this constant in the IP configuration.

---

**DI-004 — Automated periodic export to FPISC and federal reporting systems** | **(B) Configuration**

A Salesforce Scheduled Flow triggers `NEPA_CEQExport` on a configurable cadence (default: nightly) for all active projects. The output payload is delivered to the target federal system via a Salesforce Named Credential-authenticated HTTP callout to the FPISC REST endpoint or an outbound SFTP transfer. The export schedule and target endpoint are configurable as Custom Metadata records without code changes.

---

**DI-005 — All records carry five CEQ provenance fields** | **(B) Configuration**

Every custom object and every extended standard object in the platform carries the following five fields, populated either at record creation or via system defaults:

| CEQ Provenance Property | Salesforce Field | Population |
|---|---|---|
| data_record_version | `nepa_data_record_version__c` | Auto-incremented on each save |
| data_source_agency | `nepa_data_source_agency__c` | Default from org config; overridable |
| data_source_system | `nepa_data_source_system__c` | Default from org config; overridable |
| record_owner_agency | `nepa_record_owner_agency__c` | Inherited from lead agency Account |
| retrieved_timestamp | `nepa_retrieved_timestamp__c` | DateTime stamp at record creation |

Objects carrying these fields: `Program`, `IndividualApplication`, `ContentVersion`, `PublicComplaint`, `nepa_engagement__c`, `ApplicationTimeline`, `nepa_gis_data_element__c`, `nepa_process_team_member__c`, `RegulatoryCode`.

---

**DI-006 — Legacy data ingestion via bulk import** | **(A/B) COTS/Configuration**

The Salesforce **Bulk API 2.0** supports import of at least 10,000 records per operation for all platform objects. The platform ships with a set of CSV templates and an import script (`scripts/load-demo-data.sh`) that demonstrates the full import sequence. For legacy system migration, a field mapping specification document is produced during the data migration plan deliverable (D-03). Polymorphic lookups and blob fields that cannot be resolved via Bulk API v2 CSV are handled by post-load Apex scripts following the same pattern used in the Carrie Placer Mine demo dataset.

---

## 3. Security and AI Governance Approach

---

**SC-001 — FedRAMP High / Moderate authorization** | **(A) COTS**

**Salesforce Government Cloud Plus** holds a FedRAMP High Provisional Authorization to Operate (P-ATO) issued by the FedRAMP PMO. The platform operates exclusively on Government Cloud Plus infrastructure. The offeror will provide the Salesforce FedRAMP package documentation including the System Security Plan, Control Implementation Summary, and current ATO letter within 14 days of contract award. No Agency procurement of separate cloud infrastructure is required.

---

**SC-002 — Role-based access control with field-level security** | **(A/B) COTS/Configuration**

Salesforce's permission model provides three-layer access control:

1. **Object-level CRUD** — controlled per permission set; NEPA Permitting staff are assigned the `NEPA_Permitting` permission set granting CRUD on all platform objects.
2. **Field-level security (FLS)** — each sensitive field (litigation flag, AI classification, plaintiff flag, attorney-client privileged notes) carries explicit read/edit permissions per permission set, configurable without code changes.
3. **Record-level sharing** — Experience Cloud portal users access only records where their Contact is the applicant of record. The public access flag (`nepa_public_access__c`) on documents and comments controls portal visibility.

Role hierarchy, permission sets, and sharing rules are all configurable by administrators. The `NEPA_Permitting` permission set and `NEPA_Portal_User` permission set are pre-built and version-controlled in source control.

---

**SC-003 — TLS 1.2+ in transit, AES-256 at rest** | **(A) COTS**

Salesforce Government Cloud Plus enforces TLS 1.2 minimum for all data in transit and AES-256 encryption for all data at rest by default. No Agency configuration is required. Salesforce Shield Platform Encryption is available for additional field-level encryption of sensitive data at rest if the Agency's data classification requires it.

---

**SC-004 — Section 508 compliance for portal** | **(A) COTS**

Salesforce Experience Cloud pages built on the Aura and LWR frameworks conform to WCAG 2.1 AA, which encompasses the Section 508 ICT standards. The Salesforce Voluntary Product Accessibility Template (VPAT) for Experience Cloud is available upon request. Custom OmniScript components deployed on the portal are authored following Salesforce's Lightning accessibility guidelines with semantic HTML, ARIA attributes, and keyboard-navigability requirements.

---

**SC-005 — Immutable audit log** | **(A) COTS**

Salesforce provides two layers of immutable audit logging:

1. **Field History Tracking** — captures before/after values for up to 20 tracked fields per object, with user, timestamp, and change type. Enabled on all key workflow-driving fields (process status, stage, comment classification, plaintiff flag, AI classification).
2. **Salesforce Shield Field Audit Trail** — extends field history retention to 10 years and supports up to 60 tracked fields per object. Recommended for the Agency's administrative record retention requirements.
3. **Setup Audit Trail** — captures all configuration changes (metadata, permission assignments, sharing rule changes) with user and timestamp.

No record creation, modification, or deletion event at any level is unlogged. The audit trail is read-only and cannot be modified by any user including system administrators.

---

**SC-006 — PIV/CAC authentication and MFA** | **(A/B) COTS/Configuration**

Salesforce Government Cloud Plus supports:

- **PIV/CAC via SAML 2.0 SSO** — configured to the Agency's identity provider (e.g., agency Active Directory Federation Services or a GSA Login.gov integration). Agency staff authenticate via PIV/CAC through the existing agency IdP; no separate Salesforce credential required.
- **MFA enforcement** — Salesforce enforces MFA for all user logins as a platform-level control. MFA cannot be disabled by org administrators; it is enforced at the infrastructure level on Government Cloud Plus.

Portal applicants (non-PIV users) authenticate via username/password + TOTP or via Login.gov integration, both of which satisfy MFA requirements.

---

**SC-007 — OMB M-24-10 AI governance compliance** | **(B) Configuration**

All AI-assisted workflows in the platform are designed with explicit OMB M-24-10 controls:

**(a) Human review before action:** No AI-generated output (comment classification, CE routing, litigation risk score, timeline risk flag) is acted upon automatically. AI outputs are written to read-only staging fields. The workflow-triggering state change (e.g., `nepa_comment_classification__c` advancing from "Pending Review" to "Substantive") requires a human user action to execute.

**(b) Audit trail:** For every AI action, four fields are populated on the record: `nepa_ai_output__c` (the AI result), `nepa_ai_confidence__c` (score), `nepa_ai_rationale__c` (human-readable explanation), and `nepa_ai_timestamp__c` (when the AI ran). When a human reviewer overrides the AI suggestion, the override is captured in field history tracking with user identity and timestamp. Both the AI suggestion and the human final decision are preserved permanently.

**(c) No fully automated adverse actions:** The platform contains no workflow that automatically denies, rejects, routes adversely, or takes a negative action against any applicant or commenter based solely on AI output. Every AI output is a default suggestion requiring human confirmation.

AI governance documentation — including training data sources, model type, and accuracy metrics for each AI capability — will be provided as Appendix A of the System Security Plan (D-02).

---

**SC-008 — CONUS data residency** | **(A) COTS**

Salesforce Government Cloud Plus instances are hosted exclusively in data centers located within the continental United States. Data residency is guaranteed by the Salesforce Government Cloud Plus data processing agreement and FedRAMP package documentation. No data is replicated to non-CONUS infrastructure.

---

**SC-009 — System Security Plan and ATO documentation** | **Service Deliverable**

The offeror will deliver:

- **SSP Draft (D-02):** Within 60 days of contract award. The SSP will reference the Salesforce FedRAMP High P-ATO as the infrastructure authorization baseline and document Agency-specific control implementations, AI governance procedures, and configuration management controls.
- **ATO Package (D-05):** Within 90 days of contract award, incorporating SSP, privacy impact assessment, and interconnection security agreements. The Salesforce FedRAMP package dramatically reduces the time required for Agency ATO by providing pre-validated infrastructure controls.

---

## 4. Implementation Plan

### Phase 1 — Foundation (Months 1–4)

**Milestone 1.1 — Project kickoff and data inventory** (30 days)
Deliver Project Management Plan (D-01). Conduct current-state data inventory with Agency NEPA program staff. Identify all existing project records, their locations, and field mapping to CEQ standard properties.

**Milestone 1.2 — SSP draft and data migration plan** (60 days)
Deliver SSP Draft (D-02) and Data Migration Plan (D-03). Configure org with all custom objects, fields, permission sets, and named credentials. Complete dry-run deploy validation.

**Milestone 1.3 — Configuration management plan and ATO package** (90 days)
Deliver Configuration Management Plan (D-06) and ATO documentation (D-05). All source metadata version-controlled in Agency git repository. Deployment pipeline documented.

### Phase 2 — Pilot Deployment (Months 4–6)

**Milestone 2.1 — Pilot field office deployment** (Month 6, Deliverable D-06)
Deploy to one designated field office. Load existing project records via data migration. Train field staff, NEPA coordinators, and administrators (role-based). Defined success criteria gate before expansion: 10 active cases under management, comment period gate validated, two work order optimization cycles completed.

### Phase 3 — Core Capability Delivery (Months 6–10)

**Milestone 3.1 — Field scheduling optimization and portal**
FSL Scheduling Optimizer configured with seasonal constraints, resource rules, and co-permit triggers. Experience Cloud portal deployed for applicant access.

**Milestone 3.2 — AI capabilities and risk intelligence**
Einstein AI triage, CE screener, litigation risk scoring, and timeline risk assessor activated. OMB M-24-10 audit trail validated.

**Milestone 3.3 — GIS proximity integration**
Named Credentials configured for all four default GIS layers. Proximity check flow activated. Layer registry populated.

**Milestone 3.4 — Training materials delivered** (Month 8, Deliverable D-07)

### Phase 4 — Agency-Wide Deployment (Months 10–12)

**Milestone 4.1 — Agency-wide production deployment** (Month 12, Deliverable D-08)
Phased rollout to all remaining field offices. Data migration for all legacy records complete.

**Milestone 4.2 — CEQ-standard export API operational** (Month 12, Deliverable D-09)
`NEPA_CEQExport` Integration Procedure validated against CEQ standard v1.2 schema. Automated FPISC export configured and tested.

---

## 5. Past Performance

*[Offeror to complete with up to three relevant federal or state contracts demonstrating: NEPA or environmental review case management, field service scheduling for natural resource or infrastructure operations, and FedRAMP-authorized SaaS delivery to federal civilian agencies.]*

| Contract | Agency | Period | Relevance |
|---|---|---|---|
| [Contract 1] | [Agency] | [Dates] | [NEPA case management / FSL scheduling / FedRAMP] |
| [Contract 2] | [Agency] | [Dates] | [Relevance] |
| [Contract 3] | [Agency] | [Dates] | [Relevance] |

Agency points of contact for each reference are provided under separate cover per proposal submission instructions.

---

## Appendix A — Requirement Compliance Matrix

| ID | Requirement Summary | Classification | Met? | Notes |
|---|---|---|---|---|
| PM-001 | CEQ Entity 1 project record | (B) | ✅ | Program + custom fields + provenance |
| PM-002 | CEQ Entity 2 process record | (B) | ✅ | IndividualApplication + custom fields |
| PM-003 | Multiple processes per project | (A) | ✅ | Lookup nepa_related_project__c |
| PM-004 | Configurable stage gates | (B) | ✅ | NEPA_Stage_Gate_Orchestrator + CMT |
| PM-005 | CE/EA/EIS pathways | (B) | ✅ | NEPA_CE_Screener + CMT |
| PM-006 | FRA statutory deadline clock | (B) | ✅ | Formula + accumulated pause days |
| PM-007 | SLA monitoring with escalation | (B) | ✅ | NEPA_SLA_Escalation_Monitor |
| FS-001 | Auto work order generation | (B) | ✅ | After-save Flow + WorkType registry |
| FS-002 | Seasonal survey constraints | (B) | ✅ | FSL policy + NEPA_Seasonal_Window__mdt |
| FS-003 | Shared access resource enforcement | (B) | ✅ | FSL ServiceResource + scheduling policy |
| FS-004 | Offline mobile | (A) | ✅ | Salesforce Field Service Mobile |
| FS-005 | Scheduling optimization engine | (A) | ✅ | FSL Scheduler Optimizer |
| FS-006 | Co-permit task on work order close | (B) | ✅ | After-save Flow + NEPA_Copermit_Trigger__mdt |
| DM-001 | CEQ Entity 3 document records | (B) | ✅ | ContentVersion + custom fields |
| DM-002 | Required document registry | (B) | ✅ | NEPA_Stage_Gate_Doc_Check + CMT |
| DM-003 | Document versioning | (A) | ✅ | ContentVersion IsLatest native |
| DM-004 | Page limit rules | (B) | ✅ | Validation rule + NEPA_Doc_PageLimit__mdt |
| DM-005 | AI-assisted EIS drafts | (B) | ✅ | Einstein Prompt Builder + human review gate |
| DM-006 | Administrative record export | (B) | ✅ | NEPA_Administrative_Record_Checker + IP |
| PC-001 | Comment intake — web/email/mail | (B) | ✅ | PublicComplaint + OmniScript + Email-to-Case |
| PC-002 | Comment period gating | (B) | ✅ | NEPA_Comment_Period_Gate |
| PC-003 | Substantive classification | (B) | ✅ | Field + AI default + human override + audit |
| PC-004 | AI comment triage | (B) | ✅ | NEPA_Comment_Triage_Save + Einstein |
| PC-005 | Litigation history registry | (B) | ✅ | nepa_litigation__c + NEPA_Plaintiff_Profile__mdt |
| PC-006 | Route comments as work orders | (B) | ✅ | After-save Flow + FSL |
| PC-007 | Comment response log | (B) | ✅ | PublicComplaint response fields + AR export |
| PE-001 | CEQ Entity 5 engagement events | (B) | ✅ | nepa_engagement__c |
| PE-002 | ADA/translation/notice tracking | (B) | ✅ | Fields on nepa_engagement__c |
| PE-003 | Tribal consultation gate | (B) | ✅ | Stage gate + nepa_consultation_certified__c |
| TL-001 | CEQ Entity 6 case events | (B) | ✅ | ApplicationTimeline + custom fields |
| TL-002 | Timeline display | (B) | ✅ | FlexiPage timeline component |
| TL-003 | Projected completion dates | (B) | ✅ | NEPA_Timeline_Risk_Assessor + benchmark CMT |
| GIS-001 | CEQ Entity 7 GIS data elements | (B) | ✅ | nepa_gis_data_element__c |
| GIS-002 | Point and polygon storage | (B) | ✅ | lat/lon on Program + Polygon object |
| GIS-003 | Automated proximity checks | (B) | ✅ | NEPA_GIS_Proximity_Check + NEPA_GIS_Proximity_IP |
| GIS-004 | Proximity results write-back; CE flag | (B) | ✅ | IP writes to Program; CE screener consumes |
| GIS-005 | Configurable GIS layer registry | (A/B) | ✅ | NEPA_GIS_Layer__mdt + Named Credentials |
| UR-001 | Structured team role assignments | (B) | ✅ | nepa_process_team_member__c |
| UR-002 | Active/inactive assignment flag | (B) | ✅ | nepa_active__c + field history |
| UR-003 | Team members exportable in CEQ | (B) | ✅ | DR_Extract_NEPA_TeamMember |
| LS-001 | Regulatory citation linkage | (B) | ✅ | RegulatoryCode + nepa_legal_structure__c |
| LS-002 | Citations linked to decision elements | (B) | ✅ | nepa_decision_element__c + RegulatoryCode lookup |
| LS-003 | Configurable citation registry | (A/B) | ✅ | RegulatoryCode EffectiveTo native |
| AP-001 | Authenticated applicant portal | (A/B) | ✅ | Experience Cloud |
| AP-002 | Automated applicant notifications | (B) | ✅ | After-save Flows + email templates |
| AP-003 | Portal comment submission + gate | (B) | ✅ | OmniScript + NEPA_Comment_Period_Gate |
| AP-004 | Published document access | (B) | ✅ | ContentVersion portal sharing |
| AP-005 | Co-permit action items on portal | (B) | ✅ | Task portal component |
| TR-001 | Cloud-hosted SaaS | (A) | ✅ | Salesforce Government Cloud Plus |
| TR-002 | Config-driven rules without code | (A/B) | ✅ | CMT + Flows + OmniStudio |
| TR-003 | Config tables as metadata records | (A) | ✅ | Custom Metadata Types |
| TR-004 | REST API for all core entities | (A) | ✅ | Salesforce REST API |
| TR-005 | Bulk operations 10,000+ records | (A) | ✅ | Salesforce Bulk API 2.0 |
| TR-006 | Mobile offline capability | (A) | ✅ | Salesforce Field Service Mobile |
| TR-007 | Explainable AI rationale | (B) | ✅ | AI rationale fields on every scored record |
| TR-008 | AI auditability documentation | Service | ✅ | Provided in SSP Appendix A |
| DI-001 | Nine-entity CEQ data model | (B) | ✅ | All 9 entities implemented (see table) |
| DI-002 | Structured JSON export per project | (B) | ✅ | NEPA_CEQExport IP + 9 DataRaptors |
| DI-003 | Schema version + timestamp in export | (B) | ✅ | AssembleCEQPayload Set Values step |
| DI-004 | Automated periodic export | (B) | ✅ | Scheduled Flow + Named Credential callout |
| DI-005 | Five CEQ provenance fields on all records | (B) | ✅ | All 9 entity objects carry all 5 fields |
| DI-006 | Legacy data ingestion | (A/B) | ✅ | Bulk API 2.0 + post-load Apex scripts |
| SC-001 | FedRAMP High/Moderate | (A) | ✅ | Government Cloud Plus FedRAMP High P-ATO |
| SC-002 | RBAC + FLS + portal isolation | (A/B) | ✅ | Permission sets + Experience Cloud row access |
| SC-003 | TLS 1.2+ / AES-256 | (A) | ✅ | Government Cloud Plus baseline |
| SC-004 | Section 508 portal compliance | (A) | ✅ | Experience Cloud WCAG 2.1 AA |
| SC-005 | Immutable audit log | (A) | ✅ | Field History + Shield Field Audit Trail |
| SC-006 | PIV/CAC + MFA | (A/B) | ✅ | SAML SSO to agency IdP + platform MFA |
| SC-007 | OMB M-24-10 AI governance | (B) | ✅ | Human gate + audit fields + no auto adverse action |
| SC-008 | CONUS data residency | (A) | ✅ | Government Cloud Plus CONUS-only |
| SC-009 | SSP + ATO documentation | Service | ✅ | Delivered D-02 (60 days) and D-05 (90 days) |
| IR-001 | Phased implementation plan | Service | ✅ | See Section 4 |
| IR-002 | Data migration plan | Service | ✅ | D-03 at 60 days |
| IR-003 | Role-based training | Service | ✅ | D-07 at 8 months |
| IR-004 | Dedicated implementation PM | Service | ✅ | Named resource for base period |
| IR-005 | Pilot deployment with success gate | Service | ✅ | D-06 at 6 months |
| IR-006 | Configuration management plan | Service | ✅ | D-04; Salesforce DX + git version control |

**Summary:** 63 requirements addressed. 0 marked as unable to meet. Classification breakdown: (A) COTS — 14; (A/B) COTS/Configuration — 9; (B) Configuration — 33; Service Deliverable — 7.

---

*This proposal response is submitted in accordance with RFP [AGENCY]-NEPA-[YYYY]-[NNN]. All capability claims reflect the configured state of the proposed platform as described in the technical volume. Demonstration of any capability is available upon request during oral presentations.*
