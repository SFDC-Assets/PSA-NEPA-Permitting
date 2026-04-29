# NEPA Compliance Improvement Plan
**PSA-NEPA-Permitting-Data-Model v1.0 → CEQ NEPA and Permitting Data and Technology Standard v1.2**

*Prepared: 2026-04-29*
*Standards References:*
- *[CEQ NEPA and Permitting Data and Technology Standard v1.2](https://permitting.innovation.gov) — May 30, 2025, updated August 18, 2025 (authoritative)*
- *[CEQ Permitting Technology Action Plan](https://permitting.innovation.gov) — May 30, 2025*
- *[PIC NEPA Data Standard v1.2.0 (GitHub)](https://github.com/GSA-TTS/pic-standards) — technical implementation of the CEQ standard*
- *PSS Reference: Public Sector Solutions Developer Guide, Version 65.0 (Winter '26)*

---

## Urgency and Compliance Deadline

On April 15, 2025, President Trump signed the Presidential Memorandum *Updating Permitting Technology for the 21st Century*, directing Federal agencies to make maximum use of technology in environmental review and permitting. CEQ published the Permitting Technology Action Plan and initial data standard on May 30, 2025.

**The Presidential Memorandum specifically directs the agencies listed in 42 U.S.C. 4370m-1(b)(2)(B)(i)-(xii) to adopt and begin implementing the data standard and Minimum Functional Requirements within 90 days — deadline: August 28, 2025.**

CEQ has established the Permitting Innovation Center (April 30, 2025) at permitting.innovation.gov to coordinate implementation. Agencies should be moving to MFR foundational compliance now.

---

## Executive Summary

The accelerator currently implements **4 of the 9 entities** defined in the CEQ NEPA and Permitting Data and Technology Standard v1.2 and has field-level gaps within those 4. Two compliance-critical entities — `Public Engagement Events` (public meetings/hearings) and `Case Events` (process milestones/FAST-41 schedule) — are entirely absent. Several properties required by the standard are missing across all four implemented entities, including all 6 provenance fields added in v1.2.

This plan is organized in three tiers aligned to the CEQ Minimum Functional Requirements (MFRs) maturity model (Foundational → Emerging → Leading-Edge):

| Tier | Focus | MFRs Addressed | Effort |
|---|---|---|---|
| 1 | Critical compliance gaps — MFR foundational baseline | MFR #1, #5 | Medium |
| 2 | Data completeness + new objects | MFR #1, #2, #3, #4, #5, #7, #8 | Medium-High |
| 3 | Full standard coverage + leading-edge | MFR #2, #3, #4, #6, #7, #8, #9, #10 | High |

**On value enumeration:** The CEQ standard intentionally does not define enumerated value lists for most properties, to allow maximum agency flexibility. The picklist values in this plan are recommended defaults; agencies should adjust them for their specific processes and requirements.

**On identifiers:** CEQ recommends UUID format for all entity IDs. For document IDs, a [Document Object Identifier (DOI)](https://www.doi.org/) is best practice where available. The existing `nepa_federal_unique_id__c` and `nepa_project_id__c` fields should be validated as UUID-format-compatible.

---

## Current State

### Objects Currently Used

| Salesforce Object | Maps To CEQ Standard | Purpose |
|---|---|---|
| `Program` | Entity 1: Project | Permitting project metadata |
| `IndividualApplication` | Entity 2: Process | NEPA review process |
| `ContentVersion` (record type: `nepa_permit_document`) | Entity 3: Documents | NEPA documents (NOI, EIS, ROD, etc.) |
| `PublicComplaint` | Entity 4: Comments | Public comments |
| `nepa_process_related_agencies__c` | Process cooperating/participating agencies | Agency-process relationship junction |
| `nepa_project_agency_relationship__c` | Project participating agencies | Agency-project relationship junction |

### CEQ Entity Relationship Summary

Per Figure 1 of the CEQ standard, the official entity relationships are:
- **Project → Process**: One-to-many
- **Process → Documents**: One-to-many
- **Documents → Public Comments**: One-to-many *(comments are children of documents, not processes)*
- **Process → Public Engagement Events**: One-to-many
- **Process → Case Events**: One-to-many
- **Project, Process, Document, Case Event, Engagement Event, Comment → GIS Data**: One-to-many *(GIS can relate to any entity)*
- **GIS Data → GIS Data Element**: One-to-many
- **Process Model → Process, Decision Elements**: One-to-many
- **Legal Structure → Decision Element, Process Model**: One-to-many

The current accelerator models comments as children of `IndividualApplication` (process). The official standard places comments as children of documents. Both relationships should be present.

### PSS Objects Available But Unused

| PSS Object | Relevant For | Page |
|---|---|---|
| `ApplicationTimeline` | Case Events — process milestone tracking | 85 |
| `Polygon` | GIS Data — GeoJSON/KML spatial data | 632 |
| `RegulatoryAuthorizationType` | Process type classification (EIS/EA/CE) | 707 |
| `ActionPlan` / `ActionPlanTemplate` | Structured NEPA workflow templates | 25/34 |
| `PublicApplicationParticipant` | Engagement attendee tracking | 656 |

---

## Tier 1: Critical Compliance Gaps

*MFR #1 (Implement Data Standards) — Foundational. MFR #5 (Automated Case Management Tools) — Foundational.*

### 1.1 Add NEPA Process Type to `IndividualApplication`

**Standard requirement:** Entity 2 Process — `Process Type`: Level of NEPA review or other permit or authorization (for reference see Federal Environmental Review and Authorization Inventory).

**Gap:** Without this field, structured reporting on EIS vs. EA vs. CE volumes is impossible from the data model.

**Recommendation:** Add a picklist field `nepa_review_type__c` to `IndividualApplication`.

```
Field API Name:  nepa_review_type__c
Label:           NEPA Review Type
Type:            Picklist (restricted)
Values:          EIS | EA | CE | Other Authorization
Required:        Yes
```

**Alternative:** Map to the existing PSS `RegulatoryAuthorizationType` object (p.707), which is already referenced in the permission set. This allows agencies to maintain their own authorization type registry without hardcoding picklist values, which aligns with the standard's intent to avoid enumerated lists.

---

### 1.2 Fix Process Status — Align to Official Standard Values

**Standard requirement:** Entity 2 Process — `Process Status*`: Indicates status of process.
**Official values:** `planned | pre-application | in progress | paused | completed | cancelled`

**Gap:** `nepa_process_stage__c` is currently a free-text `Text(255)` field. This prevents filtering, reporting, or interoperability on process status. The `Program` object uses `nepa_current_status__c` with partially aligned values but `IndividualApplication` has no structured status field.

**Corrections from prior plan version:**
- "underway" → **"in progress"** (official standard term)
- Add **"pre-application"** (project in scoping/pre-filing stage)
- Add **"cancelled"** (process terminated before completion)

**Recommendation:** Add a new picklist field `nepa_process_status__c` to `IndividualApplication`, leaving the existing free-text `nepa_process_stage__c` for the `Process Stage` narrative property (which the standard says may be derived from the last case event).

```
Field API Name:  nepa_process_status__c
Label:           Process Status
Type:            Picklist (restricted)
Values:          planned | pre-application | in progress | paused | completed | cancelled
Required:        Yes
```

Also update `Program.nepa_current_status__c` to include "cancelled":
```
Updated Values:  pre-application | in progress | paused | completed | cancelled
```

---

### 1.3 Add Public Engagement Events Entity

**Standard requirement:** Entity 5: Public Engagement Events — opportunities for interaction in the environmental review or process, including consultation. Distinct from case events; documents windows for public involvement.

**NEPA legal basis:** 40 CFR 1501.9 (public involvement), 40 CFR 1503.1 (inviting comments), tribal consultation requirements.

**Gap:** No engagement tracking exists in the current model. Public comments (`PublicComplaint`) exist but are distinct from the events at which those comments were gathered.

**Recommendation — Option A (Preferred): New custom object `nepa_engagement__c`**

Maps cleanly to Entity 5 properties:

```
Object API Name:     nepa_engagement__c
Label:               NEPA Public Engagement Event
Relationships:
  nepa_process__c    Master-Detail → IndividualApplication  (required)
  nepa_document__c   Lookup → ContentVersion               (optional; related documents released for event)

Fields matching CEQ standard properties:
  nepa_engagement_type__c     Picklist   Public Meeting | Notice | Solicitation |
                                         Tribal Consultation | Scoping | Other
  nepa_start_datetime__c      DateTime   (Required — event date/time)
  nepa_end_datetime__c        DateTime
  nepa_location_format__c     Picklist   In-Person | Virtual | Hybrid
  nepa_location__c            Lookup → Location (existing PSS object)
  nepa_attendance_count__c    Number     (Attendance — participant count)
  nepa_notes__c               LongTextArea(32768)
  nepa_public_access__c       Checkbox   (Public/internal)
```

**Note on PSS Engagement (Chapter 16, p.1400):** The PSS Engagement module (`EngagementInteraction`, `EngagementAttendee`) is designed for call-center citizen interactions, not NEPA public hearing events. It requires a CTI integration license and its data model does not map to Entity 5. A custom object is the appropriate choice.

---

### 1.4 Add Case Events Entity — ApplicationTimeline Extension

**Standard requirement:** Entity 6: Case Events — milestones or steps within the environmental review or permit process, tracked in a case management system. FAST-41 (42 U.S.C. 4370m) requires schedule reporting for covered infrastructure projects.

**Gap:** No milestone/timeline tracking exists. The EIS Timeline Report (Jan 2025) confirms median EIS completion is 2.2 years in 2024 — meeting the statutory 2-year target requires structured milestone data.

**Recommendation — Option A (Preferred): Extend PSS `ApplicationTimeline` (p.85)**

PSS `ApplicationTimeline` is specifically designed for tracking application stage history with timestamps and links natively to `IndividualApplication`. Extend with NEPA-specific fields matching Entity 6 properties:

```
Custom fields to add to ApplicationTimeline:

nepa_event_type__c          Picklist   NOI | Scoping Open | Scoping Complete |
                                       Draft EIS Published | Comment Period Open |
                                       Comment Period Closed | Final EIS Published |
                                       ROD Issued | CE Determination | FONSI Issued |
                                       Permit Issued | Process Paused | Other
nepa_event_description__c   LongTextArea(32768)  (Event Description)
nepa_source__c              URL        (Source — link to information about event)
nepa_tier__c                Text(255)  (Optional hierarchy — e.g., "Tier 1 NOI")
nepa_status__c              Picklist   Pending | In Progress | Completed
nepa_outcome__c             LongTextArea(32768)  (Result or action taken)
nepa_assigned_entity__c     Text(255)  (Assigned Personnel — responsible individual/agency)
nepa_following_segment__c   Text(255)  (Name of next process segment)
nepa_public_access__c       Checkbox   (Whether event is displayed publicly)
nepa_document__c            Lookup → ContentVersion    (Related Document ID)
nepa_parent_case_event__c   Lookup → ApplicationTimeline  (Parent Case Event ID)
nepa_related_engagement__c  Lookup → nepa_engagement__c   (Related Engagement Events)
```

**Recommendation — Option B:** If PSS `ApplicationTimeline` proves too constrained, a standalone custom object `nepa_case_event__c` gives full flexibility matching Entity 6 exactly.

---

### 1.5 Link `PublicComplaint` to `ContentVersion` (Document)

**Standard requirement:** Entity 4 Comments — `Related Document ID*`: Reference to the document to which the comment is related. Per the official ERD (Figure 1), comments are children of documents, not processes.

**Gap:** `PublicComplaint` currently links only to `IndividualApplication` (process). The standard requires the primary relationship to be with a specific document (e.g., a Draft EIS).

**Recommendation:** Add a lookup field on `PublicComplaint` to `ContentVersion`:

```
Field API Name:  nepa_parent_document__c
Label:           Related Document
Type:            Lookup → ContentVersion
Required:        Yes (for new records; nullable for legacy)
```

The existing `IndividualApplication` relationship may be retained as a convenience denormalization for reporting, consistent with Entity 4's `Related Process ID` (optional secondary reference).

---

## Tier 2: Data Completeness and New Capabilities

*MFR #1 (Emerging), MFR #2, #3, #4 (Foundational/Emerging), MFR #7, #8 (Foundational/Emerging)*

### 2.1 Provenance Fields (All Objects)

CEQ Standard v1.2 (updated August 18, 2025 in the v1.1→v1.2 changelog) requires **6 provenance fields** on every entity for OMB M-25-05 / Evidence Act Title II compliance.

Add to: `Program`, `IndividualApplication`, `ContentVersion` (NEPA record type), `PublicComplaint`, `ApplicationTimeline`, `nepa_engagement__c`

| Field API Name | Label | Type | Standard Property |
|---|---|---|---|
| `nepa_data_record_version__c` | Data Record Version | Text(50) | Data Record Version |
| `nepa_data_source_agency__c` | Data Source Agency | Text(255) | Data Source Agency |
| `nepa_data_source_system__c` | Data Source System | Text(255) | Data Source System |
| `nepa_record_owner_agency__c` | Record Owner Agency | Text(255) | Record Owner Agency |
| `nepa_retrieved_timestamp__c` | Retrieved Timestamp | DateTime | Retrieved Timestamp |

**Note:** `LastModifiedDate` is the native Salesforce system field that satisfies `Last Updated`. No custom field needed for that property.

**Note:** The standard does NOT have a `created_at` provenance field in v1.2. `CreatedDate` (native) is useful for internal tracking but does not map to a standard provenance property.

---

### 2.2 `Program` Field Gaps

| Field API Name | Label | Type | Standard Property |
|---|---|---|---|
| `nepa_project_type__c` | Project Type | Text(255) | `Project Type` — sub-classification (e.g., "pipeline", "highway") |
| `nepa_funding__c` | Funding Source(s) | Text(255) | `Funding Source(s) or other Project Reference` |
| `nepa_location_lat__c` | Location Latitude | Number(18,8) | `Location` (centroid) |
| `nepa_location_lon__c` | Location Longitude | Number(18,8) | `Location` (centroid) |
| `nepa_location_text__c` | Location Text | Text(255) | `Location` (text/WKT) |
| `nepa_parent_project__c` | Parent Project | Lookup → Program | `Parent Project ID` |
| `nepa_polygon__c` | Project Boundary | Lookup → Polygon | `Location` (GIS object; Tier 3 prerequisite) |

**Note on `Program.Status`:** The PSS standard `Status` field has values `Active | Cancelled | Completed | Planned`. The current model uses a custom `nepa_current_status__c` picklist with standard-aligned values. This is correct — keep the custom field. However, update the values (see 1.2 above) to include "cancelled" and align "in progress" wording.

---

### 2.3 `IndividualApplication` Field Gaps

| Field API Name | Label | Type | Standard Property |
|---|---|---|---|
| `nepa_agency_id__c` | Agency Process ID | Text(255) | `Agency ID` — agency-assigned ID distinct from federal unique ID |
| `nepa_process_code__c` | Process Code | Text(50) | `Process Code` — CE code or other classification |
| `nepa_description__c` | Process Description | LongTextArea(32768) | `Process Description` |
| `nepa_purpose_and_need__c` | Purpose and Need | LongTextArea(32768) | `Purpose and Need` |
| `nepa_notes__c` | Notes | LongTextArea(32768) | (additional notes) |
| `nepa_comment_period_start__c` | Comment Period Start | Date | `Public Comment Period` (start) |
| `nepa_comment_period_end__c` | Comment Period End | Date | `Public Comment Period` (end) |
| `nepa_process_outcome__c` | Process Outcome | Text(255) | `Process Outcome` — e.g., ROD issued, permit issuance |
| `nepa_joint_lead_agency__c` | Joint Lead Agency | Text(255) | `Joint Lead Agency` |
| `nepa_parent_process__c` | Parent Process | Lookup → IndividualApplication | `Parent Process ID` — nested/phased reviews |

---

### 2.4 `ContentVersion` Field Gaps

| Field API Name | Label | Type | Standard Property |
|---|---|---|---|
| `nepa_related_case_event__c` | Related Case Event | Lookup → ApplicationTimeline | `Related Case Event ID*` — document tied to a specific milestone |
| `nepa_contributing_agencies__c` | Contributing Agencies | LongTextArea(32768) | `Contributing Agencies` — agencies that contributed to preparation |
| `nepa_volume_title__c` | Volume Title | Text(255) | `Volume Title` — e.g., "Appendix" |
| `nepa_document_revision__c` | Document Revision | Text(50) | `Document Revision` — e.g., "first revised Draft EIS" |
| `nepa_supplement_number__c` | Supplement Number | Number(3,0) | `Supplement Number` |
| `nepa_prepared_by__c` | Prepared By | Text(255) | `Prepared By*` — responsible entity |
| `nepa_url__c` | Document URL | URL | `URL` — public link |
| `nepa_related_document__c` | Related Document | Lookup → ContentVersion | `Related Document IDs` |
| `nepa_document_summary__c` | Document Summary | LongTextArea(131072) | `Document Structures` — summary/TOC |
| `nepa_notes__c` | Notes | LongTextArea(32768) | (additional notes) |

**Note on `public_access`:** The current `nepa_public_access__c` picklist (`Disclosable | Non-disclosable`) satisfies the standard's `Public Access` property. No change needed.

**Note on `nepa_prepared_by__c`:** Verify whether the standard PSS `ContentVersion` object has a native `Prepared By` or author field before adding a custom one.

---

### 2.5 `PublicComplaint` Field Gaps

| Field API Name | Label | Type | Standard Property |
|---|---|---|---|
| `nepa_organization__c` | Organization | Text(255) | `Organization` — optional affiliation |
| `nepa_category__c` | Comment Category | Text(255) | `Category` — topic tag or type of comment |
| `nepa_date_submitted__c` | Date Submitted | Date | `Date Submitted*` — verify PSS native field first |
| `nepa_method_of_submission__c` | Method of Submission | Picklist | `Method of Submission*` — Online \| Email \| Mail \| In-Person |
| `nepa_document_location_ref__c` | Document Location Reference | Text(255) | `Document location reference` — part of document being referenced |
| `nepa_agency_response__c` | Agency Response | LongTextArea(32768) | `Agency Response` — formal reply |
| `nepa_public_source__c` | Public Source | Checkbox | `Public Access` — public or internal |

**Note:** `commenter_entity` and `content_text` likely map to standard PSS `PublicComplaint` fields. Verify `PublicComplaint` native fields (p.660 of objects.pdf) before adding custom fields for commenter name and comment content.

---

### 2.6 Application Data Sharing Strategy — MFR #2

**MFR requirement:** Enable automated transfer of application data among agencies and systems. Foundational: web-based upload with portal processing. Leading-edge: portal-agnostic acceptance with API-based automated transfer.

**Current gap:** No API exposure or data sharing pattern defined. The accelerator uses standard Salesforce REST/SOAP APIs inherently, but no NEPA-specific API contract is defined.

**Recommendations:**

1. **External ID fields:** Ensure `nepa_federal_unique_id__c` and `nepa_project_id__c` are declared as External ID fields in Salesforce to support upsert operations from external agency systems. Validate UUID compatibility.

2. **Named Credential / Connected App:** Define a Connected App configuration for agency-to-agency data sharing with appropriate OAuth scopes.

3. **API naming convention:** Use the CEQ standard entity names as the canonical data model for any Salesforce API responses — map Salesforce field names to standard property names in integration layer documentation.

---

### 2.7 Automated Project Screening — MFR #3 (Foundational)

**MFR requirement:** Develop screening systems that assist staff in determining whether a CE, programmatic consultation, or general permit applies. Foundational: define decision logic for CEs and configure case management to support low-impact NEPA review.

**Standard mapping:** This capability maps to Entity 2 (Process) — Process Model, Decision Elements, and Decision Payload sub-entities.

**Recommendation (Foundational — Tier 2):** Implement decision logic using the PSS Business Rules Engine (Expression Sets / Decision Tables, Chapter 12). CE criteria become Expression Set rules evaluated against process and project data. This avoids a custom object and integrates with OmniStudio.

Minimum configuration:
- Define Expression Sets for each CE category applicable to the agency
- Link evaluation results to `IndividualApplication` via `nepa_process_code__c` (the CE code field)
- Store screening outcome in `nepa_process_outcome__c`

---

### 2.8 Document Management — MFR #7 (Foundational/Emerging)

**MFR requirement:** Foundational: consistent metadata enrichment. Emerging: digital-first approach with structured data packages.

**Current state:** The accelerator uses `ContentVersion` with a `nepa_permit_document` record type. This is a solid foundation.

**Recommendations:**

1. **Digital-first document metadata:** The `nepa_document_summary__c` field should capture a machine-readable table of contents (heading structure) per the CEQ Document Structures guidance. Agencies should include at minimum: Project, Process, high-level Case Events, and associated GIS data in the document metadata package.

2. **Document Files field:** The standard's `Document Files` property (added in v1.2) supports optionally including actual document files in JSON format. Consider adding `nepa_document_files__c` as a LongTextArea(131072) to store JSON references to document file attachments or external URLs.

---

### 2.9 Comment Compilation — MFR #8 (Foundational)

**MFR requirement:** Foundational: comment analysis tools exist; agencies starting to use NLP. Emerging: end-to-end comment process tools with AI-assisted categorization.

**Current state:** `PublicComplaint` captures individual comments. No aggregation or analysis tooling.

**Recommendations:**

1. The new `nepa_category__c` field (section 2.5) enables manual and automated categorization of comments by topic — a prerequisite for any comment analysis tooling.

2. For Emerging maturity: evaluate Salesforce Einstein NLP / Einstein Classification to auto-categorize incoming `PublicComplaint` records by topic based on comment text.

3. For bulk comment ingestion from Regulations.gov or the Federal Docket Management System: define a data import process using the `nepa_parent_document__c` relationship added in Tier 1 to correctly associate imported comments to the specific document they reference.

---

## Tier 3: Full Standard Coverage

*MFR #2, #3, #4 (Leading-Edge), MFR #6 (all), MFR #9, #10*

These capabilities require significant design work or external integration. Recommended for v2.0.

### 3.1 GIS Data — MFR #6 (Integrated GIS Analysis Tools)

**Use PSS `Polygon` object as the foundation.** `Polygon` (p.632) stores GeoJSON, KML, or other polygon data natively.

Per the official ERD, GIS Data can relate to: Project, Process, Document, Case Event, Engagement Event, and Comment. Implement as:

1. Add lookup `nepa_polygon__c` → `Polygon` on `Program` (Project GIS boundary)
2. Add lookup `nepa_polygon__c` → `Polygon` on `IndividualApplication` (Process analysis area)
3. Create `nepa_gis_data_element__c` custom object as a child of `Polygon` to store Container Inventory metadata:
   - Format (GeoJSON, KML, GML, GeoTIFF)
   - Access Method (URL, API, direct upload)
   - Coordinate System
   - Bounding Box
   - Purpose (Bespoke, Analysis, Base map)
   - Reference to Database (whether this references an official GIS inventory entry)
   - Access Information

For Leading-Edge (MFR #6): GIS datasets should be exposed via API for cross-agency sharing; integrate with EPA NEPAssist or similar for automated cross-reference against federal resource layers.

---

### 3.2 Screening Criteria Access — MFR #4

**MFR requirement:** Agencies should publish CE and permitting decision models in standardized format (DMN) for public access. Leading-edge: screening criteria and GIS data available by API.

**Standard mapping:** Entity 2 (Process Model) — Decision Elements (Category, Legal Reference, Evaluation Method, Threshold, Spatial Indicator, Spatial Reference, DMN Model).

**Recommendation:** Extend the Expression Set approach from MFR #3 (section 2.7) with:

1. A custom object `nepa_decision_element__c` to store the structured decision criteria as data:
   - Legal Reference (Lookup → `nepa_legal_structure__c`)
   - Category (limitation/condition/core/extraordinary circumstances)
   - Threshold (numeric value)
   - Spatial Indicator (checkbox)
   - Evaluation Method (Text — DMN notation or free text)
   - Expected Evaluation Data (LongText — JSON spec)

2. Export mechanism: a Salesforce Site or Experience Cloud page that publishes decision elements as structured data, satisfying the public availability requirement.

---

### 3.3 Legal Structure — Entity 9

Custom object `nepa_legal_structure__c`:

```
nepa_title__c               Text(255)   Official name
nepa_citation__c            Text(255)   CFR/USC citation (Required)
nepa_description__c         LongTextArea  Summary and relevance
nepa_text_content__c        LongTextArea  Full text or excerpt
nepa_issuing_authority__c   Text(255)   Government body
nepa_effective_date__c      Date        Implementation date
nepa_compliance_reqs__c     LongTextArea  Procedural mandates
```

Lookup relationships: from `IndividualApplication` → `nepa_legal_structure__c`, and from `nepa_decision_element__c` → `nepa_legal_structure__c`.

---

### 3.4 Process Model — Entity 2 / MFR #3 Leading-Edge

BPMN workflow templates for standard NEPA review types. Use PSS **OmniProcess** / **ServiceProcess** (Chapter 25) — supports structured process definitions with flow steps and avoids a custom object. OmniProcess integrates with the existing OmniStudio toolset in PSS.

The Process Model entity's `DMN Model` property maps to OmniProcess configuration. `Decision Elements` map to the Expression Sets / `nepa_decision_element__c` objects developed in Tier 3.2.

---

### 3.5 Administrative Record Management — MFR #9

**MFR requirement:** Automated, data-driven administrative record supporting FOIA and litigation needs. Leading-edge: administrative record materials generated automatically from decision support tools and available as data via API.

**Foundational approach:** The current `ContentVersion` model already stores documents. Extend toward administrative record completeness by:

1. Add a record type or field `nepa_record_category__c` on `ContentVersion` to classify documents as: Supporting Analysis | Public Comment | Agency Communication | Decision Record | Permit | Other
2. Ensure all Case Events (`ApplicationTimeline`) that produce documents have the `nepa_document__c` lookup populated — this creates a complete audit trail linking milestones to their documentary evidence
3. For automated record generation (Emerging): use Salesforce Flow to automatically create `ContentVersion` records when key `ApplicationTimeline` milestone events are completed

---

### 3.6 Interoperable Agency Services — MFR #10

**MFR requirement:** Majority of NEPA and permitting services integrated or provided through shared services. This is the leading-edge state requiring CEQ coordination and shared infrastructure.

**Accelerator positioning:** The PSA accelerator, as an open-source Salesforce configuration, is itself a reusable shared service artifact. Agencies adopting it gain a common codebase. For full MFR #10 compliance, the accelerator should be paired with:

1. A Connected App configuration for CEQ/Permitting Innovation Center API integration
2. Outbound change data capture (CDC) on key objects to support event-driven integration with other agency systems
3. An Experience Cloud portal for public-facing project status and document access (satisfying transparency requirements)

---

## PSS Objects: Evaluated and Not Recommended

| PSS Object | Considered For | Decision |
|---|---|---|
| `EngagementInteraction` / `EngagementAttendee` (Ch.16) | NEPA public engagement events | **No** — requires CTI license; designed for call-center interactions, not public hearings |
| `ActionPlan` / `ActionPlanTemplate` | NEPA workflow/milestones | **Partial** — suitable for checklist-style action items; `ApplicationTimeline` better fits Entity 6 Case Events |
| `PublicApplicationParticipant` | Engagement attendee tracking | **No standalone** — linked to `IndividualApplication`, not to engagement events; use as supporting object if attendance detail is needed |
| PSS `Program.Status` field | Replace `nepa_current_status__c` | **No** — PSS values (`Active/Cancelled/Completed/Planned`) don't match standard values; keep custom field |

---

## Recommended Implementation Sequence

### Phase 1 — Immediate (v1.1 patch, MFR #1 Foundational baseline)

1. Add `nepa_review_type__c` (Process Type) to `IndividualApplication`
2. Add `nepa_process_status__c` with official values (planned/pre-application/in progress/paused/completed/cancelled)
3. Update `Program.nepa_current_status__c` to add "cancelled" and align "in progress" wording
4. Add `nepa_parent_document__c` lookup on `PublicComplaint` → `ContentVersion`
5. Add `nepa_url__c` to `ContentVersion`
6. Add `nepa_related_case_event__c` (Lookup → ApplicationTimeline) to `ContentVersion`
7. Add `nepa_contributing_agencies__c`, `nepa_volume_title__c`, `nepa_document_revision__c`, `nepa_supplement_number__c`, `nepa_prepared_by__c` to `ContentVersion`
8. Add `nepa_organization__c`, `nepa_category__c`, `nepa_method_of_submission__c`, `nepa_document_location_ref__c`, `nepa_agency_response__c` to `PublicComplaint`
9. Update permission set and page layouts for all new fields

### Phase 2 — Near-term (v1.2, MFR #1 Emerging, MFR #5 Foundational)

10. Create `nepa_engagement__c` custom object with process relationship (Entity 5)
11. Extend `ApplicationTimeline` with NEPA case event fields (Entity 6)
12. Add all Tier 2 field-level gaps across Program, IndividualApplication, ContentVersion, PublicComplaint
13. Add all 5 provenance fields to all objects (Program, IndividualApplication, ContentVersion, PublicComplaint, ApplicationTimeline, nepa_engagement__c)
14. Add `nepa_record_category__c` classification to `ContentVersion`
15. Declare `nepa_federal_unique_id__c` and `nepa_project_id__c` as External ID fields
16. Update permission set and layouts

### Phase 3 — Medium-term (v1.3, MFR #2, #3, #7, #8 Foundational)

17. Implement CE decision logic via Salesforce Expression Sets (MFR #3 Foundational)
18. Define Connected App and External ID-based API integration pattern (MFR #2)
19. Configure Flow automation for administrative record creation on milestone completion (MFR #9 Foundational)
20. Add Einstein Classification for comment categorization (MFR #8 Emerging)

### Phase 4 — Long-term (v2.0, MFR #4, #6, #9, #10 and full standard)

21. Link `Program` → `Polygon` for native GIS support
22. Create `nepa_gis_data_element__c` for GIS layer metadata
23. Create `nepa_decision_element__c` and publish via Experience Cloud (MFR #4)
24. Create `nepa_legal_structure__c` for regulatory citation traceability
25. Evaluate OmniProcess for `process_model` implementation (MFR #3 Leading-Edge)
26. Experience Cloud portal for public project/document transparency (MFR #10)

---

## CEQ Minimum Functional Requirements — Accelerator Coverage Map

| MFR | Description | Current State | Target (this plan) |
|---|---|---|---|
| #1 | Implement Data Standards | Partial — 4 of 9 entities, missing fields | Tier 1+2: All 9 entities, full field coverage |
| #2 | Application Data Sharing | Foundational (Salesforce REST API) | Tier 2/3: Named Connected App, External IDs, API contract |
| #3 | Automated Project Screening | Not implemented | Tier 2: Expression Sets for CE logic (Foundational) |
| #4 | Access to Screening Criteria | Not implemented | Tier 3: decision_element object + Experience Cloud publication |
| #5 | Automated Case Management | Not implemented | Tier 1: ApplicationTimeline extension (Foundational) |
| #6 | Integrated GIS Analysis Tools | Not implemented | Tier 3: Polygon integration + gis_data_element |
| #7 | Improved Document Management | Foundational | Tier 2: Metadata enrichment, document structure summary |
| #8 | Automated Comment Compilation | Not implemented | Tier 2: Comment category field + Einstein NLP |
| #9 | Administrative Record Management | Foundational (ContentVersion) | Tier 2/3: Record category + Flow automation |
| #10 | Common/Interoperable Services | Not implemented | Tier 3: Experience Cloud portal + CDC integration |

---

## What the Current Model Does Well

- Agency relationship modeling (`nepa_role__c`: Cooperating/Participating) correctly captures the standard's agency classification
- Document types (NOI, Draft EIS, Final EIS, ROD, FONSI) align with the standard's vocabulary
- Project sector picklist covers and extends the standard's sector categories appropriately
- External IDs (`nepa_federal_unique_id__c`, `nepa_project_id__c`) support federal system interoperability
- Project/process/document/comment hierarchy correctly mirrors the standard's nesting model
- The accelerator's use of `Program` for project and `IndividualApplication` for process is the right PSS object choice — both are core to the Application and Authorization data model
- Using `ContentVersion` with a custom record type is consistent with PSS patterns and avoids unnecessary custom objects
