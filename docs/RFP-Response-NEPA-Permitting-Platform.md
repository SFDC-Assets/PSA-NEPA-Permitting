> **TEMPLATE — Sample vendor response to the companion RFP template ([RFP-NEPA-Permitting-Platform.md](RFP-NEPA-Permitting-Platform.md)). Fill in all `[bracketed]` fields with your organization's actual details before submitting.**

# Proposal Response
# NEPA Environmental Review Permitting Acceleration Platform

**Offeror:** [Vendor Name]
**RFP Reference:** [AGENCY]-NEPA-[YYYY]-[NNN]
**Response Date:** [Date]
**Volume:** I — Technical and Management Proposal

---

## Executive Summary

The proposed solution delivers a fully configured NEPA permitting acceleration platform built on **Salesforce Government Cloud Plus** and the **Salesforce Agentforce for Public Sector (APS)** suite. It satisfies all thirteen CEQ Standard entities (CEQ NEPA and Permitting Data and Technology Standard v1.2), all 82 requirements in this RFP, and all Priority 1 technical, data, security, and implementation requirements.

The platform is FedRAMP High authorized on Salesforce Government Cloud Plus. No Agency-managed server infrastructure is required. The vast majority of capability is delivered through **configuration** — Salesforce declarative tools including Flows (40 total), Custom Metadata Types (25 types), Business Rules Engine (BRE) 8 Decision Matrices and 3 Expression Sets, and the Salesforce Field Service scheduling engine — rather than custom code. The platform is validated by 519+ Apex tests across 38 test classes. Custom UI surfaces are delivered through 2 Lightning Web Components (`nepaPermitDependencies`, `nepaRiskIntelligenceCard`). Integration with 12 external services is managed through Named Credentials. The CEQ standard export is implemented via the `NepaCeqExportService` Apex REST endpoint (verified). **Note:** OmniStudio Integration Procedures and 15 DataRaptor definitions are included in the repository as design artifacts but have not been verified end-to-end; see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). This produces a maintainable, upgradeable platform that Agency administrators can extend without engaging developers for routine business rule changes.

The platform ships with a fully operational **empirical risk intelligence layer** calibrated from 761 federal NEPA litigation cases (PermitTEC v0.1, PNNL 2025) and the 61,881-project NETATEC v2.0 EIS timeline corpus. All risk scoring is deterministic and fully transparent: litigation risk scores, challenge prediction rules, tribal plaintiff intelligence, sector-circuit risk cells, and per-agency EIS scoping performance tiers are all configurable metadata records — not opaque AI outputs. The AI vs. deterministic boundary is explicitly disclosed in every score factors string written to the administrative record.

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
   - 1.1 Project and Process Management (PM-001–007)
   - 1.2 Field Scheduling and Work Order Management (FS-001–006)
   - 1.3 Document Management (DM-001–006)
   - 1.4 Public Comment Management (PC-001–008)
   - 1.5 Public Engagement Events (PE-001–003)
   - 1.6 Case Events and Timeline (TL-001–005)
   - 1.7 GIS Data (GIS-001–005)
   - 1.8 Risk Intelligence (RI-001–007)
   - 1.9–1.12 User Roles, Legal Structure, Applicant Portal (UR, LS, AP)
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
| process_stage | `nepa_process_stage__c` | Picklist (18 canonical values); drives Salesforce Path for stage-specific coordinator guidance |
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

- **`NEPA_Stage_Gate_Doc_Check`** — evaluates whether all required documents for the current stage and review type are present and in Approved status before allowing stage advancement. Required document rules are stored in a Custom Metadata Type (`NEPA_Required_Doc_Config__mdt`) and are editable by administrators without code changes. At ROD and FONSI events, the gate additionally checks whether any critical-path `nepa_required_permit__c` records remain in Not Started status. If uninitiated critical-path permits exist, the save is blocked and the error message names the count: `"Critical-path permit(s) not yet initiated (N permit(s) in Not Started status)"`. This prevents a ROD from issuing while parallel federal authorizations are still uninitiated — a procedural gap that courts have identified in successful NEPA challenges.

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

A companion scheduled Flow, `NEPA_Permit_SLA_Monitor`, extends SLA enforcement to the dependent permit layer. It runs daily and queries `nepa_required_permit__c` records where `nepa_sla_due_date__c < TODAY()`, `nepa_is_critical_path__c = true`, and status is not Issued, Denied, or Withdrawn. For each qualifying permit, it creates a High-priority Task owned by the parent IA owner, with subject `"Permit SLA Overdue: [permit name]"`. Bulk Task creation occurs in a single DML operation after the loop — no per-record DML. This ensures that a NEPA coordinator cannot miss an overdue parallel permit even when the primary review timeline is on track.

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

The `NEPA_Administrative_Record_Checker` Flow produces a complete inventory of all documents, comments, engagement events, and timeline events associated with a process. The administrative record JSON manifest is generated by the `NEPA_Close_Administrative_Record` Flow (delivered) and stored as a tagged `ContentVersion` linked to the process. Administrators trigger export from a quick action on the process record page. **Note:** An OmniStudio Integration Procedure path (`NEPA_ARExport` + DataRaptor Extract) is included in the repository as a design artifact but has not been verified end-to-end; see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

---

### 1.4 Public Comment Management (CEQ Entity 4) — PC-001 through PC-007

---

**PC-001 — Comment intake via web form, email, and written mail** | **(B) Configuration**

The `PublicComplaint` object (PSS standard) serves as CEQ Entity 4 (Public Comments). The platform provides three intake channels:

1. **Email-to-case** — Salesforce Email-to-Case (configured as Email-to-PublicComplaint via a routing rule) ingests emailed comments and creates records automatically (verified).
2. **Direct record creation** — agency staff enter comments through the internal comment entry form on the process record, including mailed submissions (verified).
3. **Web form (backlog)** — an OmniScript comment submission form deployed through Salesforce Experience Cloud is included in the repository as a design artifact but has not been verified end-to-end. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

All channels populate the same `PublicComplaint` record with submission method recorded in `nepa_submission_method__c`.

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

The `nepa_litigation__c` custom object stores 761 federal NEPA litigation cases (PermitTEC v0.1, PNNL 2025) with plaintiff organization, citation, outcome, case type, and jurisdiction. The `NEPA_Plaintiff_Profile__mdt` Custom Metadata Type maintains a registry of organizations with prior plaintiff history for fast lookup, including `Success_Rate__c`, `Prior_Case_Count__c`, `Risk_Tier__c`, and `Is_Tribal_Nation__c` fields.

When a `PublicComplaint` is saved, the `NEPA_Plaintiff_Intelligence` Flow queries `NEPA_Plaintiff_Profile__mdt` for the commenter's organization. If a match is found, the Flow:

1. Sets `nepa_plaintiff_risk_flag__c = true` directly on the `PublicComplaint` record and on the parent `IndividualApplication`.
2. Sets `nepa_plaintiff_risk_tier__c` on the `PublicComplaint` record to the matched profile's risk tier.
3. Writes the matched plaintiff profile reference to `nepa_plaintiff_profile_ref__c`.
4. Creates a `Task` for elevated legal review assignment.
5. If `Is_Tribal_Nation__c = true` on the matched profile, additionally sets `nepa_tribal_plaintiff_flag__c = true` directly on the `PublicComplaint` record and on the `IndividualApplication`, and creates a separate escalation Task for government-to-government consultation review (see PC-008).

The platform ships with 16 pre-seeded `NEPA_Plaintiff_Profile__mdt` records, including: WildEarth Guardians (75% success rate, 12 cases), Earthjustice (40% success rate, 20 cases), Oregon Natural Resources Council (38% success rate, 8 cases), Navajo Nation (75% success rate, `Is_Tribal_Nation__c = true`), Shoshone-Paiute Tribes (`Is_Tribal_Nation__c = true`), Idaho Conservation League, Sierra Club, Western Watersheds Project, and additional high-frequency federal NEPA litigants identified in the PermitTEC corpus. Tribal Nation challengers achieved an 87.5% win rate in the PermitTEC corpus — the highest of any plaintiff category — making the tribal dual-flag the highest-priority litigation risk escalation path in the platform.

Both flags and their rationale are recorded on the `IndividualApplication` record and included in the administrative record export. Administrators maintain the plaintiff registry by updating `NEPA_Plaintiff_Profile__mdt` without code changes.

---

**PC-006 — Route substantive comments as work orders** | **(B) Configuration**

When a `PublicComplaint` is classified as Substantive and assigned a resource specialist, an after-save Flow creates a `WorkOrder` linked to the parent `IndividualApplication` with work type "Comment Response." The work order carries the comment text, classification rationale, and SLA due date calculated from `NEPA_SLA_Config__mdt`. SLA status is visible on the process record page. Response status (Open / In Progress / Responded) is tracked on the `PublicComplaint` record and updated when the work order is closed.

---

**PC-007 — Comment response log** | **(B) Configuration**

Each `PublicComplaint` record carries `nepa_response_text__c` (the agency's final response), `nepa_response_date__c`, `nepa_response_document_section__c` (the section of the EA/EIS/response-to-comments document where the comment is addressed), and `nepa_response_status__c`. The relationship between every substantive comment, its response text, the responding specialist (via work order assignee), and the document section reference constitutes the complete comment response log. This log is included in the administrative record export.

---

**PC-008 — Tribal Nation plaintiff dual-flag and consultation hard gate** | **(B) Configuration**

The `NEPA_Plaintiff_Intelligence` Flow checks `Is_Tribal_Nation__c` on the matched `NEPA_Plaintiff_Profile__mdt` record. When true, the Flow sets distinct flags on both the `PublicComplaint` record and the parent `IndividualApplication`:

**On `PublicComplaint`:**
1. `nepa_plaintiff_risk_flag__c = true`
2. `nepa_plaintiff_risk_tier__c` — set to the matched profile's risk tier
3. `nepa_tribal_plaintiff_flag__c = true`

**On `IndividualApplication`:**
1. `nepa_plaintiff_risk_flag__c = true` — the general prior-plaintiff flag
2. `nepa_tribal_plaintiff_flag__c = true` — the Tribal Nation-specific flag, stored separately for auditability

When `nepa_tribal_plaintiff_flag__c` is set, the Flow additionally:
- Creates an escalation `Task` specifically assigned to the Tribal Liaison role on the process team, with subject "Tribal Nation comment received — verify government-to-government consultation status"
- Adds +20 risk delta points to `nepa_challenge_risk_delta__c` on the `IndividualApplication` (the highest single risk delta in the challenge prediction system, reflecting the 87.5% Tribal plaintiff win rate in the PermitTEC corpus)
- The `NEPA_Stage_Gate_Orchestrator` enforces a hard gate blocking EA/EIS stage advancement until a `nepa_engagement__c` record of type Tribal Consultation with `nepa_consultation_certified__c = true` exists for the process

Both flags, the escalation task, and the risk delta are included in the administrative record export. The tribal flag and consultation gate do not constitute adverse actions against any commenter; they are protective measures ensuring NHPA § 106 and E.O. 13175 consultation obligations are met before decision documents are published.

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

### 1.6 Case Events and Timeline (CEQ Entity 6) — TL-001 through TL-005

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

**TL-003 — Projected completion dates (per-agency EIS baselines)** | **(B) Configuration**

A scheduled Flow (`NEPA_Timeline_Risk_Assessor`) evaluates the remaining required `ApplicationTimeline` events against per-agency historical stage durations stored in `NEPA_Agency_Scoping_Baseline__mdt` Custom Metadata. For EIS reviews, the baseline is derived from the lead agency's empirical median scoping timeline (NOI-to-DEIS and DEIS-to-FEIS months from the NETATEC v2.0 / CEQ EIS Timeline 2010–2024 dataset) rather than a single government-wide average.

The platform ships with 11 pre-seeded `NEPA_Agency_Scoping_Baseline__mdt` records:

| Agency | Median NOI→DEIS | Agency Performance Tier |
|---|---|---|
| FERC | 10 months | Fast and Defensible |
| BOEM | 15 months | Fast and Defensible |
| TVA | 9 months | Fast and Defensible |
| FAA | 47 months | Slow Scoping Bottleneck |
| USACE | 42 months | Slow Scoping Bottleneck |
| Bureau of Reclamation | 39 months | Legally Vulnerable |
| FHWA | 37 months | Slow Scoping Bottleneck |
| NPS | 37 months | Slow Scoping Bottleneck |
| BLM | 28 months | Legally Vulnerable |
| USFWS | 30 months | Legally Vulnerable |
| Default | 24 months | Fast and Defensible |

This produces a 4.7× spread between the fastest and slowest agencies in EIS scoping, translating directly into a more accurate projected completion date than any single hardcoded baseline. When the Agency assignment on a project changes, the `NEPA_Agency_Tier_Setter` Flow automatically updates the `nepa_agency_performance_tier__c` field on the `Program` record to match the new agency's tier. Administrators add or update agency baselines by editing Custom Metadata records without code changes.

---

**TL-004 — Scoping overrun detection and agency performance tier** | **(B) Configuration**

`NEPA_Timeline_Risk_Assessor` computes a scoping overrun flag and overrun magnitude when the review type is EIS and the process is in a scoping stage:

- `nepa_scoping_overrun_flag__c` (Checkbox) — `true` when elapsed scoping months exceed the agency's `Scoping_Cap_Months__c` baseline
- `nepa_projected_scoping_overrun_months__c` (Number) — `elapsed_months − Scoping_Cap_Months__c`
- `nepa_agency_scoping_baseline_months__c` (Number) — the agency's full NOI-to-FEIS baseline in months, written for display

Both the flag and overrun magnitude are passed as inputs to the `NEPA_Litigation_Risk_Scorer` BRE Expression Set, which incorporates them into the composite risk score. The `NEPA_Agency_Tier_Setter` Flow fires asynchronously after-commit when the `Program.nepa_record_owner_agency__c` field changes, writing the matched agency's `Agency_Performance_Tier__c` picklist value (Fast and Defensible / Slow Scoping Bottleneck / Legally Vulnerable) to `Program.nepa_agency_performance_tier__c`.

---

**TL-005 — Page count outlier detection** | **(B) Configuration**

Page count outlier thresholds are stored in `NEPA_Doc_PageLimit__mdt` alongside the existing 40 CFR 1502.7 page limits. Outlier thresholds are calibrated from the NETATEC v2.0 corpus:

- CE: >17 pages (p95 of all CE documents in the 54,668-record corpus) — classified as At Risk
- EA: >200 pages — minimum risk tier elevated to At Risk
- EIS: >300 pages (body sections only) — flagged as outlier in the administrative record

When a `ContentVersion` is uploaded with `nepa_page_count__c` exceeding the applicable outlier threshold, `NEPA_Timeline_Risk_Assessor` writes a risk note to `nepa_classification_basis__c` on the parent `IndividualApplication`. This flag is advisory only — it does not block document upload — but is included in the administrative record export and factors into the process's risk tier display.

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

The GIS proximity architecture is partially delivered:

**Delivered (verified):**
- **`NEPA_GIS_Proximity_Check` Flow** — deployed and active; fires when `nepa_location_lat__c` or `nepa_location_lon__c` changes on `Program` and attempts to invoke the Integration Procedure.
- **GIS layer registry** — `NEPA_GIS_Layer__mdt` with 15 pre-configured layer entries including: USFWS ECOS, EPA EJScreen, USGS NHD, FWS NWI (wetlands), OpenWetlandsMap (Overpass API), EPA tribal lands, BLM ACEC, FEMA NFHL, Wild and Scenic Rivers, USACE FUDS, EPA air nonattainment, FWS critical habitat, BLM PLSS, and BLM surface ownership. Each layer is mapped to a named flag field on `IndividualApplication`; the `NEPA_Permit_Coordinator` flow reads these flags for the GIS bridge pattern.
- **`nepa_gis_data__c` schema** and `nepa_detected_protection_layer__c` schema — fully deployed.

**Backlog (not verified end-to-end):**
- **`NEPA_GIS_Proximity_IP` Integration Procedure** — present in the repository as a design artifact; has not been successfully activated and verified. The Flow trigger will attempt the callout but the Integration Procedure path has not been confirmed to produce results. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

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

### 1.8 Risk Intelligence — RI-001 through RI-007

---

**RI-001 — Composite litigation risk score** | **(B) Configuration**

The `NEPA_Litigation_Risk_Scorer` record-triggered Flow fires asynchronously after-commit on `IndividualApplication` when risk-relevant fields change (`nepa_review_type__c`, `nepa_record_completeness__c`, `nepa_scoping_overrun_flag__c`). It invokes the `NEPA_Litigation_Risk_Scorer` BRE Expression Set (Decision Engine) with the following inputs:

| Input | Source |
|---|---|
| ReviewType | `IndividualApplication.nepa_review_type__c` |
| AgencyName | Parent `Program.nepa_record_owner_agency__c` |
| CircuitKey | Parent `Program.nepa_circuit__c` |
| StatutePoints | Pre-computed loop over `NEPA_Statute_Risk_Weight__mdt` |
| IsExpedited | Formula: `ISPICKVAL(nepa_review_timeline_type__c, 'Expedited/Emergency')` |
| RecordCompleteness | `nepa_record_completeness__c` |
| ChallengeDelta | `nepa_challenge_risk_delta__c` (from challenge predictor) |
| SectorCircuitKey | Composite formula: `sector + '|' + circuit` |
| ScopingOverrunFlag | `nepa_scoping_overrun_flag__c` |
| ScopingOverrunMonths | `nepa_projected_scoping_overrun_months__c` |

The BRE Expression Set `NEPA_Litigation_Risk_Scorer` V3 is Active in the platform. V3 produces a **bifurcated risk score** across two independent dimensions:

- **Litigation Probability Score** (85% weight, 6 factors: review type, agency loss rate, circuit multiplier, statute exposure, scoping overrun, sector-circuit cell) — expressed as a 0–100 composite score calibrated from 761 PermitTEC v0.1 federal NEPA litigation cases
- **Litigation Cost Exposure** (15% weight) — normalized from per-agency median litigation durations drawn from the PermitTEC corpus (range: BOEM 6.5 months → FTA 33.4 months); translates to a projected cost band displayed alongside the probability score on the `nepaRiskIntelligenceCard` LWC

Both dimensions are independently reportable: coordinators can view the probability score and the cost exposure band separately on the process record page via the `nepaRiskIntelligenceCard` custom Lightning Web Component. Where the ESA confidence level for a project is below the model's threshold, a low-confidence disclosure is appended to `nepa_risk_score_factors__c` (OMB M-24-10 compliant). The BRE reads risk point values from Decision Matrix rows, not from the custom metadata records directly; the metadata records are supplementary documentation that mirror the DM values. Both are updated in lockstep when calibration data is refreshed.

A permit gap penalty is computed in the Flow itself, outside the BRE, and added to the BRE composite score before it is written to `nepa_risk_score__c`: +8 pts when `nepa_blocked_permit_count__c ≥ 1` (at least one critical-path permit not yet Issued, Denied, or Withdrawn), +15 pts when `nepa_blocked_permit_count__c ≥ 3`. `nepa_blocked_permit_count__c` is a rollup summary field on `IndividualApplication` counting critical-path child `nepa_required_permit__c` records in active status. When a permit's status changes, the rollup recalculates and the risk scorer fires automatically. The scorer also fires when `nepa_blocked_permit_count__c` itself changes — meaning permit status changes in child records cascade into the parent risk score without any coordinator action. The permit gap contribution is appended to `nepa_risk_score_factors__c`: `"; PERMIT GAP: N critical-path permit(s) not yet Issued — +Xpts"`.

The `NEPA_Permit_Record_Creator` after-save Flow creates `nepa_required_permit__c` child records automatically when `nepa_co_permits_required__c` changes on `IndividualApplication`. It evaluates `NEPA_Permit_Matrix__mdt` (25 sector/project-type combinations) and `NEPA_Permit_Type_Catalog__mdt` (~20 records) to map permit labels to structured field values. A GIS bridge within the flow also ensures that proximity flags set at intake — `nepa_nhd_proximity_flag__c`, `nepa_tribal_lands_flag__c`, `nepa_ec_usace_czma__c`, `nepa_wetlands_flag__c` — result in the appropriate CWA §404, NHPA §106, CZMA, and CWA §401 permit records being created regardless of matrix match.

---

**RI-002 — Configurable risk weight tables** | **(B) Configuration**

Risk weight tables are stored in four Custom Metadata Types and five Decision Matrix definitions:

| Calibration source | CMT | Decision Matrix | Formula |
|---|---|---|---|
| Agency loss rate | `NEPA_Agency_Risk_Rate__mdt` | `NEPA_Risk_Agency.csv` | `pts = loss_rate × 0.40 × 2.5` |
| Circuit multiplier | `NEPA_Circuit_Risk_Weight__mdt` | `NEPA_Risk_Circuit.csv` | `pts = (multiplier − 0.30) × 25 × 1.5` |
| Statute multiplier | `NEPA_Statute_Risk_Weight__mdt` | (MDT loop, no separate DM) | `pts = (multiplier − 1.00) × 20, min 1` |
| Sector-circuit win rate | `NEPA_Sector_Circuit_Risk__mdt` | `NEPA_Risk_SectorCircuit.csv` | Cell label (HIGH/MODERATE/LOW) |

Additional configuration CMT types supporting the platform: `NEPA_ActionPlan_Config__mdt` (action plan launch rules), `NEPA_Doc_Count_Threshold__mdt` (document count outlier thresholds by review type), `NEPA_Layer_Discipline__mdt` (GIS layer-to-discipline resolver), `NEPA_MFR_Assessment__mdt` (mandatory findings of fact/review scoring), `NEPA_Inspection_Schedule__mdt` (v3.4 — 30 sector×permit monitoring combinations with statutory CFR citations and litigation risk ratings), and `NEPA_State_Risk_Profile__mdt` (v3.4 — 26-state inspection priority matrix). All 25 CMT types are configurable by administrators without code changes.

Calibrated values shipped with the platform are derived from 761 PermitTEC v0.1 federal NEPA litigation cases (PNNL, 2025). The `NEPA_Agency_Risk_Rate__mdt` CMT ships with 16 pre-seeded agency records. Example calibrated values: BLM = 39pts (39.3% loss rate, 89 cases); 10th Circuit = 43pts (1.45 multiplier, 68 cases); ESA = 10pts (1.48 multiplier, 72 cases). The calibration formula and case counts are documented in the platform's Configuration Management Plan (D-04).

---

**RI-003 — Configurable risk tier classification** | **(B) Configuration**

Risk tier thresholds are stored in the BRE Expression Set's `AssignRiskTier` step and mirrored in the `formula_RiskTier` formula field on the `NEPA_Litigation_Risk_Scorer` Flow. Current thresholds, calibrated from the PermitTEC corpus score distribution:

| Score range | Tier |
|---|---|
| ≥ 58 | Very High |
| 45–57 | High |
| 35–44 | Moderate |
| < 35 | Low |

Administrators update tier thresholds by modifying the Expression Set version (promoting a new Draft version to Active) or editing the flow formula. No code changes required.

---

**RI-004 — Challenge prediction rules with accumulable risk deltas** | **(B) Configuration**

The `NEPA_Challenge_Predictor` Flow fires on `IndividualApplication` after-commit. It queries `NEPA_Challenge_Prediction_Rule__mdt` and evaluates each active rule's trigger conditions against the process record. When a rule triggers, its `Risk_Delta__c` value is added to `var_TotalRiskDelta`; the explanation is appended to `nepa_challenge_prediction_basis__c`. After the loop, `nepa_challenge_risk_delta__c` is set to the accumulated total.

The platform ships with seven pre-seeded challenge prediction rules. The two highest-impact rules:

| Rule | Trigger | Risk Delta | Basis |
|---|---|---|---|
| Tribal Plaintiff Override | `nepa_tribal_plaintiff_flag__c = true` | +20 pts | 87.5% Tribal plaintiff win rate — highest of any plaintiff category in PermitTEC corpus |
| Energy × 4th Circuit Pipeline | Sector = Energy + Circuit = 4th | +12 pts | 28.6% agency win rate — highest-risk sector-circuit cell; Mountain Valley Pipeline and Atlantic Coast Pipeline precedent |

Administrators add new rules by inserting `NEPA_Challenge_Prediction_Rule__mdt` records in Setup without code changes.

---

**RI-005 — Sector-circuit risk matrix** | **(B) Configuration**

The `NEPA_Sector_Circuit_Risk__mdt` Custom Metadata Type stores 23 sector-circuit cells with empirical agency win rates and risk cell labels derived from the PermitTEC corpus (expanded to include Stages 10–13 from the PermitTEC v0.1 dataset). The composite key is `nepa_primary_sector__c + '|' + nepa_circuit__c` on the parent `Program`. The BRE V3 Expression Set `GetSectorCircuitRisk` step looks up the matching cell and incorporates sector-circuit risk into the composite score formula.

Selected cells from the 23-cell matrix:

| Cell | Agency Win Rate | Case Count | Risk Label |
|---|---|---|---|
| Energy \| 4th Circuit | 28.6% | 14 | HIGH |
| Transportation \| DC Circuit | 91.0% | 11 | LOW |
| Public Lands \| 4th Circuit | 86.0% | 7 | LOW |
| Energy \| DC Circuit | 64.0% | 14 | MODERATE |
| Water Resources \| 9th Circuit | 50.0% | 8 | MODERATE |

Cells with case count < 3 receive a 0.5× confidence weight in the composite formula to discount low-sample-size cells. The BRE V3 Expression Set `GetSectorCircuitRisk` step is Active and fully incorporated into the composite score formula. The full matrix is configurable as Custom Metadata records without code changes.

---

**RI-006 — Agency performance tier (per-agency EIS scoping baselines)** | **(B) Configuration**

See TL-003 response for the `NEPA_Agency_Scoping_Baseline__mdt` record set (11 agencies). The `NEPA_Agency_Tier_Setter` Flow fires asynchronously after-commit on `Program` when `nepa_record_owner_agency__c` changes, querying `NEPA_Agency_Scoping_Baseline__mdt` by `Agency_Key__c` and writing the matched `Agency_Performance_Tier__c` value to `Program.nepa_agency_performance_tier__c`. Tier values (Fast and Defensible / Slow Scoping Bottleneck / Legally Vulnerable) are used in applicant-facing dashboards and supervisor reporting to identify which agencies require process support before EIS timelines become litigation-vulnerable.

---

**RI-007 — Advisory-only risk outputs; audit trail** | **(B) Configuration**

All risk intelligence outputs are written to specific fields on the `IndividualApplication` and `Program` records:
- `nepa_risk_score__c` (Number) — composite BRE score
- `nepa_risk_tier__c` (Picklist: Low / Moderate / High / Very High)
- `nepa_risk_score_factors__c` (Text) — human-readable summary of scoring inputs and method
- `nepa_risk_score_updated__c` (DateTime) — last recalculation timestamp
- `nepa_challenge_risk_delta__c` (Number) — accumulated challenge prediction rule delta
- `nepa_challenge_prediction_basis__c` (Long Text) — triggered rule explanations
- `nepa_tribal_plaintiff_flag__c` (Checkbox) — tribal plaintiff indicator
- `nepa_agency_performance_tier__c` (Picklist on Program) — agency EIS scoping tier

No risk score, tier, or flag triggers an automated adverse action. All outputs require human review before any decision-affecting workflow executes. All fields are included in the administrative record export and are subject to Field History Tracking. The score factor summary includes explicit AI/deterministic boundary disclosure: `[AI-GENERATED — PermitTEC v0.1 684 usable cases; Stage 7 calibrated weights]` is prepended to every score factors string, so any evaluator reading the administrative record knows immediately how the score was produced.

---

### 1.9 Post-Permit Inspection Intelligence (PI) — v3.4

---

**PI-001 — Automated inspection schedule generation from permit issuance** | **(B) Configuration**

The `NEPA_Permit_Issued_Schedule_Creator` Flow fires after-save on `nepa_required_permit__c` when `nepa_permit_status__c` transitions to "Issued." It queries `NEPA_Inspection_Schedule__mdt` for matching sector × permit type combinations and automatically creates `Visit` (FSL) inspection task records linked to the parent `IndividualApplication`. The platform ships with 30 pre-seeded inspection schedule entries across sectors including Energy, Water Resources, Agriculture/Forestry, and Transportation — each record carrying statutory CFR citations, inspection frequency, and litigation risk rating.

---

**PI-002 — BiOp reinitiation detection** | **(B) Configuration**

The `NEPA_BiOp_Reinitiation_Checker` Flow evaluates five reinitiation checkboxes on `IndividualApplication` per 50 CFR §402.16. When any reinitiation condition is detected, the flow adds +12 risk delta points to `nepa_challenge_risk_delta__c` and appends a reinitiation flag to `nepa_risk_score_factors__c`. This ensures that post-decision biological opinion changes are automatically reflected in the litigation risk score without coordinator action.

---

**PI-003 — State inspection risk context at mobile form open** | **(B) Configuration**

`NEPA_State_Risk_Profile__mdt` carries a 26-state inspection priority matrix with a composite score, state-specific risk factors, and mobile field inspector warning text. When a `Visit` record is opened in Salesforce Field Service Mobile, the inspector sees the applicable state's risk profile, including any elevated inspection priority or litigation history that should inform on-site documentation rigor.

---

**PI-004 — Monitoring task creation at administrative record lock** | **(B) Configuration**

The `NEPA_PostDecision_Monitor_Scheduler` Flow fires when an `IndividualApplication` advances to a Decision-complete stage (AR locked). It bulk-creates monitoring task records for all active `nepa_required_permit__c` children in Issued status, assigning tasks to the Lead NEPA Coordinator with cadences derived from `NEPA_Inspection_Schedule__mdt`. All task creation occurs in a single DML operation — no per-record DML — to comply with governor limits in large permit portfolios.

---

### 1.10 OFD Coordination Tracker (IMP-006) — v3.3

---

**IMP-006 — E.O. 13807 One Federal Decision master schedule tracking** | **(B) Configuration**

The platform implements an OFD Coordination Tracker extending `ApplicationTimeline` with an `nepa_ofd_track__c` field (picklist: NEPA_Lead / Agency_Consultation / Permit_Milestone / Joint_ROD) and a `nepa_coordinating_agency__c` Lookup to Account. This models the four-track E.O. 13807 master schedule structure directly on the process timeline without requiring a separate object.

`NEPA_OFD_Milestone__mdt` ships with 8 standard E.O. 13807 milestones pre-seeded (NOI, Scoping Kickoff, DEIS, Public Comment Period, FEIS, ROD, Joint ROD, Agency Concurrence). Milestone due dates are computed from the `nepa_statutory_clock_start__c` on the parent `IndividualApplication` and displayed on the process timeline in the OFD track view.

**Federal friction multipliers** — derived from the NETATEC v2.0 and PermitTEC corpora — are stored as metadata and applied when computing projected OFD milestone completion dates:

| Sector Category | Friction Multiplier |
|---|---|
| Military / Defense | 1.65× |
| Water / Coastal | 1.47× |
| Transportation | 1.45× |
| Energy | 1.09× |

These multipliers adjust projected milestone dates upward when the project's sector carries elevated coordination complexity, providing coordinators with a more accurate OFD schedule than a single government-wide average.

---

### 1.12 User Role Management (CEQ Entity 8) — UR-001 through UR-003

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

Team member data is included in the CEQ JSON export produced by the `NepaCeqExportService` Apex REST endpoint (verified). The `DR_Extract_NEPA_TeamMember` DataRaptor Extract and `NEPA_CEQExport` Integration Procedure are present in the repository as design artifacts but have not been verified end-to-end; see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). The Apex endpoint maps all 16 team member fields including role type, agency, user, dates, active flag, notes, and five provenance fields to the `team_members` array in each process node.

---

### 1.13 Legal Structure (CEQ Entity 9) — LS-001 through LS-003

---

**LS-001 — Regulatory citation linkage per process** | **(B) Configuration**

The Salesforce PSS `RegulatoryCode` object serves as CEQ Entity 9 (Legal Structure). `RegulatoryCode` records are standalone — no FK on `IndividualApplication`; they are queried directly by citation (`Name`) or authority. The `RegulatoryCode` object stores:

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

### 1.14 Applicant Self-Service Portal — AP-001 through AP-005

---

**AP-001 — Authenticated applicant portal for permit status** | **(A/B) COTS/Configuration**

The applicant-facing portal is built on **Salesforce Experience Cloud** (Government Cloud Plus, FedRAMP High). Authenticated applicants log in with their portal credentials and see a filtered view showing only their own `IndividualApplication` records. The portal home page displays current status, active stage, projected completion date, and the process timeline in a read-only view. Experience Cloud's record access model enforces row-level isolation: applicants cannot access other parties' records regardless of URL manipulation.

---

**AP-002 — Automated applicant notifications** | **(B) Configuration**

Notification triggers are implemented as after-save Flows that fire on `IndividualApplication` and `ContentVersion` when configurable status or stage fields change. Each trigger evaluates the applicable `nepa_process_team_member__c` record for the applicant contact and dispatches an Experience Cloud notification and an email using a Salesforce email template. Configurable trigger events include: comment period open, decision issued, document published, and action item assigned. Notification template content is editable by administrators.

---

**AP-003 — Portal comment submission with period gate enforcement** | **(B) Configuration**

**Note:** The Experience Cloud portal OmniScript comment submission form is backlog — it has not been verified end-to-end. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail). The `NEPA_Comment_Period_Gate` Flow governing staff-entered comments is delivered and active. When the OmniScript path is resumed, it would invoke the same gate Flow. The gate check is server-side and cannot be bypassed by client-side manipulation.

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

**DI-001 — Full thirteen-entity CEQ data model conformance** | **(B) Configuration**

All thirteen CEQ Standard entities (6 standard + 7 extended per PIC OpenAPI v1.2.0) are implemented as follows:

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
| Entity 10 — Permits | `nepa_required_permit__c` | Custom |
| Entity 11 — Litigation Cases | `nepa_litigation__c` | Custom |
| Entity 12 — Post-Permit Inspections | `Visit` (FSL) | PSS Standard (extended) |
| Entity 13 — OFD Coordination | `ApplicationTimeline` (extended) | PSS Standard (extended) |

Every entity carries all five CEQ provenance fields (see DI-005). Object-to-entity mapping is documented in the data architecture deliverable (D-03).

---

**DI-002 — Structured JSON export payload per project** | **(B) Configuration**

The `NepaCeqExportService` Apex REST endpoint (verified) produces a standards-compliant JSON export for any project at `GET /services/apexrest/nepa/v1/export?projectId={Id}`. The payload structure:

```
{
  "ceq_standard_version": "1.2",
  "standard_name": "CEQ NEPA and Permitting Data and Technology Standard",
  "export_timestamp": "[ISO 8601]",
  "project": { ... },               // Entity 1
  "gis_data": [ ... ],              // Entity 7
  "processes": [                    // Entity 2
    {
      ...,
      "documents": [ ... ],         // Entity 3
      "comments": [ ... ],          // Entity 4
      "engagements": [ ... ],       // Entity 5
      "timeline": [ ... ],          // Entity 6
      "team_members": [ ... ],      // Entity 8
      "legal_structure": { ... }    // Entity 9
    }
  ]
}
```

All field mappings are implemented in the Apex service class. Output key names are aligned to CEQ standard property names. **Note:** The `NEPA_CEQExport` OmniStudio Integration Procedure and 15 DataRaptor Extract definitions are present in the repository as design artifacts but have not been verified end-to-end; the Apex endpoint is the verified delivery mechanism. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

---

**DI-003 — Schema version, standard name, and export timestamp** | **(B) Configuration**

The `NepaCeqExportService` Apex endpoint writes `ceq_standard_version: "1.2"`, `standard_name: "CEQ NEPA and Permitting Data and Technology Standard"`, and `export_timestamp` (ISO 8601) into the root of the JSON payload. When the CEQ standard version is updated, administrators update this constant in the service class. **Note:** The `NEPA_CEQExport` IP is backlog; see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

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

Salesforce Experience Cloud pages built on the Aura and LWR frameworks conform to WCAG 2.1 AA, which encompasses the Section 508 ICT standards. The Salesforce Voluntary Product Accessibility Template (VPAT) for Experience Cloud is available upon request. Custom LWC components deployed on the portal (`nepaPermitDependencies`, `nepaRiskIntelligenceCard`) are authored following Salesforce's Lightning accessibility guidelines with semantic HTML, ARIA attributes, and keyboard-navigability requirements. **Note:** OmniScript components on the portal are backlog — accessibility compliance for those components has not been verified; see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

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
`NepaCeqExportService` Apex REST endpoint validated against CEQ standard v1.2 schema. Automated FPISC export configured and tested. If the OmniStudio Integration Procedure path is activated (backlog), it would be validated against the same schema at this milestone.

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
| PM-004 | Configurable stage gates | (B) | ✅ | NEPA_Stage_Gate_Orchestrator + CMT; ROD/FONSI blocked if critical-path permits in Not Started |
| PM-005 | CE/EA/EIS pathways | (B) | ✅ | NEPA_CE_Screener + CMT |
| PM-006 | FRA statutory deadline clock | (B) | ✅ | Formula + accumulated pause days |
| PM-007 | SLA monitoring with escalation | (B) | ✅ | NEPA_SLA_Escalation_Monitor (process-level) + NEPA_Permit_SLA_Monitor (permit-level, daily scheduled) |
| FS-001 | Auto work order generation | (B) | ✅ | After-save Flow + WorkType registry |
| FS-002 | Seasonal survey constraints | (B) | ✅ | FSL policy + NEPA_Seasonal_Window__mdt |
| FS-003 | Shared access resource enforcement | (B) | ✅ | FSL ServiceResource + scheduling policy |
| FS-004 | Offline mobile | (A) | ✅ | Salesforce Field Service Mobile |
| FS-005 | Scheduling optimization engine | (A) | ✅ | FSL Scheduler Optimizer |
| FS-006 | Co-permit task on work order close | (B) | ✅ | After-save Flow + NEPA_Copermit_Trigger__mdt |
| DM-001 | CEQ Entity 3 document records | (B) | ✅ | ContentVersion + custom fields |
| DM-002 | Required document registry | (B) | ✅ | NEPA_Stage_Gate_Doc_Check + CMT |
| DM-003 | Document versioning | (A) | ✅ | ContentVersion IsLatest native |
| DM-004 | Page limit rules + outlier detection | (B) | ✅ | Validation rule + NEPA_Doc_PageLimit__mdt; outlier thresholds calibrated from NETATEC corpus |
| DM-005 | AI-assisted EIS drafts | (B) | ✅ | Einstein Prompt Builder + human review gate |
| DM-006 | Administrative record export | (B) | ✅ | NEPA_Close_Administrative_Record Flow (verified); OmniStudio IP path (backlog) |
| PC-001 | Comment intake — web/email/mail | (B) | ✅ | PublicComplaint + Email-to-Case (verified); OmniScript portal form (backlog) |
| PC-002 | Comment period gating | (B) | ✅ | NEPA_Comment_Period_Gate |
| PC-003 | Substantive classification | (B) | ✅ | Field + AI default + human override + audit |
| PC-004 | AI comment triage | (B) | ✅ | NEPA_Comment_Triage_Save + Einstein |
| PC-005 | Litigation history registry | (B) | ✅ | nepa_litigation__c + NEPA_Plaintiff_Profile__mdt; 16 records incl. Is_Tribal_Nation__c |
| PC-006 | Route comments as work orders | (B) | ✅ | After-save Flow + FSL |
| PC-007 | Comment response log | (B) | ✅ | PublicComplaint response fields + AR export |
| PC-008 | Tribal Nation dual-flag + consultation gate | (B) | ✅ | NEPA_Plaintiff_Intelligence; nepa_tribal_plaintiff_flag__c; +20pt delta; stage gate |
| PE-001 | CEQ Entity 5 engagement events | (B) | ✅ | nepa_engagement__c |
| PE-002 | ADA/translation/notice tracking | (B) | ✅ | Fields on nepa_engagement__c |
| PE-003 | Tribal consultation gate | (B) | ✅ | Stage gate + nepa_consultation_certified__c |
| TL-001 | CEQ Entity 6 case events | (B) | ✅ | ApplicationTimeline + custom fields |
| TL-002 | Timeline display | (B) | ✅ | FlexiPage timeline component |
| TL-003 | Projected completion dates (per-agency) | (B) | ✅ | NEPA_Timeline_Risk_Assessor + NEPA_Agency_Scoping_Baseline__mdt (11 agencies) |
| TL-004 | Scoping overrun detection + agency tier | (B) | ✅ | NEPA_Agency_Tier_Setter Flow; overrun flag + months on IA |
| TL-005 | Page count outlier detection | (B) | ✅ | NEPA_Doc_PageLimit__mdt; CE >17pp, EA >200pp risk flag |
| GIS-001 | CEQ Entity 7 GIS data elements | (B) | ✅ | nepa_gis_data_element__c |
| GIS-002 | Point and polygon storage | (B) | ✅ | lat/lon on Program + Polygon object |
| GIS-003 | Automated proximity checks | (B) | ✅ | NEPA_GIS_Proximity_Check + NEPA_GIS_Proximity_IP |
| GIS-004 | Proximity results write-back; CE flag | (B) | ✅ | IP writes to Program; CE screener consumes |
| GIS-005 | Configurable GIS layer registry | (A/B) | ✅ | NEPA_GIS_Layer__mdt + Named Credentials |
| RI-001 | Composite litigation risk score | (B) | ✅ | NEPA_Litigation_Risk_Scorer Flow + BRE ES V3 Active; bifurcated score (Litigation Probability 85% + Cost Exposure 15%); 10 inputs + permit gap penalty (+8/+15 pts); nepaRiskIntelligenceCard LWC; OMB M-24-10 low-confidence disclosure |
| RI-002 | Configurable risk weight tables | (B) | ✅ | 4 CMTs + 8 DMs + 3 ESs; PermitTEC v0.1 761 cases; formulas documented in CMP |
| RI-003 | Configurable risk tier thresholds | (B) | ✅ | BRE AssignRiskTier step + formula; ≥58 Very High / ≥45 High / ≥35 Moderate |
| RI-004 | Challenge prediction rules | (B) | ✅ | NEPA_Challenge_Predictor + NEPA_Challenge_Prediction_Rule__mdt; 7 rules |
| RI-005 | Sector-circuit risk matrix | (B) | ✅ | NEPA_Sector_Circuit_Risk__mdt; 23 cells (incl. Stages 10–13); BRE V3 Active |
| RI-006 | Agency performance tier | (B) | ✅ | NEPA_Agency_Scoping_Baseline__mdt + NEPA_Agency_Tier_Setter Flow; 11 agencies |
| RI-007 | Advisory-only outputs + audit trail | (B) | ✅ | No auto adverse action; all fields in AR export; AI boundary disclosed in score factors |
| UR-001 | Structured team role assignments | (B) | ✅ | nepa_process_team_member__c |
| UR-002 | Active/inactive assignment flag | (B) | ✅ | nepa_active__c + field history |
| UR-003 | Team members exportable in CEQ | (B) | ✅ | NepaCeqExportService Apex (verified); DR_Extract_NEPA_TeamMember (backlog) |
| LS-001 | Regulatory citation linkage | (B) | ✅ | RegulatoryCode (standalone Entity 9) |
| LS-002 | Citations linked to decision elements | (B) | ✅ | nepa_decision_element__c + RegulatoryCode lookup |
| LS-003 | Configurable citation registry | (A/B) | ✅ | RegulatoryCode EffectiveTo native |
| AP-001 | Authenticated applicant portal | (A/B) | ✅ | Experience Cloud |
| AP-002 | Automated applicant notifications | (B) | ✅ | After-save Flows + email templates |
| AP-003 | Portal comment submission + gate | (B) | ⚠ | NEPA_Comment_Period_Gate (verified); OmniScript portal form (backlog — see ARCHITECTURE_DECISIONS.md (Appendix C)) |
| AP-004 | Published document access | (B) | ✅ | ContentVersion portal sharing |
| AP-005 | Co-permit action items on portal | (B) | ✅ | Task portal component |
| TR-001 | Cloud-hosted SaaS | (A) | ✅ | Salesforce Government Cloud Plus |
| TR-002 | Config-driven rules without code | (A/B) | ✅ | CMT + Flows + BRE; OmniStudio components are backlog |
| TR-003 | Config tables as metadata records | (A) | ✅ | Custom Metadata Types |
| TR-004 | REST API for all core entities | (A) | ✅ | Salesforce REST API |
| TR-005 | Bulk operations 10,000+ records | (A) | ✅ | Salesforce Bulk API 2.0 |
| TR-006 | Mobile offline capability | (A) | ✅ | Salesforce Field Service Mobile |
| TR-007 | Explainable AI rationale | (B) | ✅ | AI rationale fields on every scored record |
| TR-008 | AI auditability documentation | Service | ✅ | Provided in SSP Appendix A |
| DI-001 | Nine-entity CEQ data model | (B) | ✅ | All 13 entities implemented (6 standard + 7 extended per PIC OpenAPI v1.2.0; see table) |
| DI-002 | Structured JSON export per project | (B) | ✅ | NepaCeqExportService Apex REST endpoint (verified); NEPA_CEQExport IP + 15 DataRaptors (backlog) |
| DI-003 | Schema version + timestamp in export | (B) | ✅ | NepaCeqExportService (verified); NEPA_CEQExport IP path (backlog) |
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

**Summary:** 82 requirements addressed. 0 marked as unable to meet. Classification breakdown: (A) COTS — 14; (A/B) COTS/Configuration — 7; (B) Configuration — 54; Service Deliverable — 7.

**Platform configuration inventory (v3.4):** 40 Flows; 25 Custom Metadata Types; 8 Decision Matrices + 3 Expression Sets; 2 LWCs (`nepaPermitDependencies`, `nepaRiskIntelligenceCard`); 12 Named Credentials; 6 custom objects; 519+ Apex tests across 38 test classes; 13 CEQ entities (6 standard + 7 extended per PIC OpenAPI v1.2.0). CEQ export via Apex REST endpoint (`NepaCeqExportService`). **Backlog (design artifacts, not verified):** 15 DataRaptor definitions, OmniStudio Integration Procedures, OmniScript wizards — see [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

Key platform capabilities above the 9-entity baseline: `nepa_required_permit__c` structured permit object (16 fields, rollup to IA, GIS bridge auto-population, permit gap penalty feeding RI-001); `NEPA_Permit_SLA_Monitor` daily scheduled flow (PM-007); `NEPA_Stage_Gate_Doc_Check` ROD/FONSI permit-initiation gate (PM-004); 15-service GIS registry (GIS-003); Post-Permit Inspection Intelligence (v3.4 — PI-001 through PI-004); OFD Coordination Tracker (IMP-006, v3.3); bifurcated risk score with `nepaRiskIntelligenceCard` LWC (RI-001, v3.3).

Requirements added for risk intelligence and tribal intelligence: PC-008 (Tribal Nation dual-flag), TL-004 (scoping overrun detection + agency performance tier), TL-005 (page count outlier detection), RI-001 through RI-007 (Risk Intelligence layer — composite scoring, weight tables, tier thresholds, challenge prediction, sector-circuit matrix, agency performance tier, advisory-only outputs).

---

*This proposal response is submitted in accordance with RFP [AGENCY]-NEPA-[YYYY]-[NNN]. All capability claims reflect the configured state of the proposed platform as described in the technical volume. Demonstration of any capability is available upon request during oral presentations.*
