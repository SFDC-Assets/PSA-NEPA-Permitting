# Request for Proposal
# NEPA Environmental Review Permitting Acceleration Platform

**Issuing Agency:** [Agency Name]
**Program Office:** [NEPA Program / Environmental Planning Division]
**RFP Number:** [AGENCY]-NEPA-[YYYY]-[NNN]
**Issue Date:** [Date]
**Proposal Due Date:** [Date]
**Period of Performance:** [Base Year + Option Years]
**NAICS Code:** 541511 — Custom Computer Programming Services
**Place of Performance:** [Agency Field Offices / Remote]

---

## Table of Contents

1. [Introduction and Background](#1-introduction-and-background)
2. [Scope of Work](#2-scope-of-work)
3. [Functional Requirements](#3-functional-requirements)
4. [Technical Requirements](#4-technical-requirements)
5. [Data and Interoperability Requirements](#5-data-and-interoperability-requirements)
6. [Security and Compliance Requirements](#6-security-and-compliance-requirements)
7. [Implementation Requirements](#7-implementation-requirements)
8. [Performance Standards](#8-performance-standards)
9. [Deliverables](#9-deliverables)
10. [Evaluation Criteria](#10-evaluation-criteria)
11. [Proposal Instructions](#11-proposal-instructions)

---

## 1. Introduction and Background

### 1.1 Purpose

[Agency Name] (hereinafter "the Agency") seeks proposals for a commercial off-the-shelf (COTS) or government off-the-shelf (GOTS) software platform — with configuration and integration services — to modernize the Agency's National Environmental Policy Act (NEPA) environmental review and permitting workflow. The platform shall accelerate permit processing timelines, reduce administrative burden on field staff, improve applicant transparency, and strengthen the defensibility of Agency decisions against litigation.

### 1.2 Background

NEPA (42 U.S.C. §§ 4321–4347) requires federal agencies to evaluate the environmental effects of proposed major federal actions before approving them. The Agency processes approximately [N] environmental reviews annually across [N] field offices, comprising Categorical Exclusions (CEs), Environmental Assessments (EAs), and Environmental Impact Statements (EISs).

Current-state challenges include:

- **Sequential scheduling:** Interdisciplinary team field surveys are scheduled independently, causing missed seasonal windows, wasted site visits, and timeline delays of 3–12 months per project.
- **Parallel permit drift:** Co-permits required from other agencies (e.g., EPA NPDES, state water rights, ESA Section 7 consultations) begin late or are tracked outside the primary review system, adding months of post-decision delay.
- **Administrative record gaps:** Required documents are tracked through email and spreadsheets; missing documents are discovered late in the review cycle, requiring re-opening completed stages.
- **Public comment lag:** Substantive public comments take 60–120 days to route, analyze, and incorporate into final documents. Prior litigation history of commenters is not systematically checked at intake.
- **Applicant visibility:** Applicants have no self-service access to permit status, generating high volumes of inbound status inquiries to field staff.
- **Data fragmentation:** NEPA project data is not structured to the CEQ NEPA and Permitting Data and Technology Standard, limiting interoperability with federal permitting dashboards and cross-agency reporting.

### 1.3 Applicable Statutes and Policy

The platform shall support compliance with:

- National Environmental Policy Act of 1969 (42 U.S.C. §§ 4321–4347)
- CEQ NEPA Implementing Regulations (40 CFR Parts 1500–1508)
- Fiscal Responsibility Act of 2023, Title II (FAST-41 Permitting Council reforms)
- Federal Permitting Improvement Steering Council (FPISC) reporting requirements
- OMB Memorandum M-25-05 — Permitting and Environmental Review Modernization
- OMB Memorandum M-24-10 — Advancing the Responsible Use of Artificial Intelligence
- CEQ NEPA and Permitting Data and Technology Standard v1.2 (May 30 / August 18, 2025)
- Agency-specific NEPA implementing procedures ([43 CFR Part 46 / 36 CFR Part 220 / etc.])
- ESA Section 7 (16 U.S.C. § 1536)
- NHPA Section 106 (54 U.S.C. § 306108)

---

## 2. Scope of Work

### 2.1 In Scope

The Contractor shall deliver a configured, integrated, and operational NEPA permitting platform including:

1. **Case management** — structured lifecycle tracking for CE, EA, and EIS review processes from intake through decision
2. **Field scheduling and optimization** — automated work order generation, seasonal constraint enforcement, and resource conflict resolution for interdisciplinary team surveys
3. **Document management and required document registry** — stage-gated document tracking with configurable required document rules by review type and stage
4. **Public comment intake and management** — structured comment submission, triage, routing, and response tracking
5. **Applicant self-service portal** — authenticated portal for permit status, document delivery, and action items
6. **Risk intelligence** — litigation risk scoring, challenge prediction, and defensibility gap detection using agency-configurable rules and historical data
7. **Parallel permit coordination** — automated task creation and SLA tracking for co-permits and interagency consultations
8. **Tribal and agency consultation tracking** — structured tracking of government-to-government and cooperating agency consultation with stage gate enforcement
9. **GIS integration** — proximity checking against federal spatial datasets (protected areas, critical habitat, wetlands, cultural resources) with configurable layer registry
10. **CEQ-standard data export** — structured JSON export conforming to CEQ NEPA and Permitting Data and Technology Standard v1.2 for all nine CEQ standard entities
11. **AI-assisted capabilities** — comment triage, CE/EA routing at intake, EIS section drafting assistance, and timeline risk flagging, all subject to human review and audit trail requirements

### 2.2 Out of Scope

- Procurement of agency GIS data licenses
- Development of agency-specific NEPA implementing procedures or policy
- Legal review services
- Production of environmental documents (EA, EIS content)

---

## 3. Functional Requirements

Requirements are designated Priority 1 (mandatory at contract award), Priority 2 (mandatory within base year), or Priority 3 (optional/enhanced capability).

### 3.1 Project and Process Management (CEQ Entities 1 and 2)

| ID | Priority | Requirement |
|---|---|---|
| PM-001 | 1 | The system shall maintain a structured project record (CEQ Entity 1) capturing federal unique project ID, project title, lead agency, project sector, project type, location (text, lat/lon, polygon), start date, and provenance fields per CEQ standard v1.2. |
| PM-002 | 1 | The system shall maintain a structured process record (CEQ Entity 2) for each NEPA review, capturing review type (CE/EA/EIS), process status, process stage, comment period dates, completion date, and all required CEQ v1.2 process properties. |
| PM-003 | 1 | The system shall support parallel multiple processes linked to a single project (tiered reviews, supplemental EIS). |
| PM-004 | 1 | The system shall enforce configurable stage gates that prevent advancement to the next review stage until all required conditions are met (documents present, consultations certified, prior stage closed). |
| PM-005 | 1 | The system shall support CE, EA, and EIS review pathways with configurable stage definitions and required documents per pathway. |
| PM-006 | 2 | The system shall capture and display an FRA statutory deadline clock per 42 U.S.C. § 4336a, including pause/resume logic for applicant-caused delays. |
| PM-007 | 2 | The system shall provide SLA monitoring with configurable warning thresholds and automated escalation notification when deadlines are at risk. |

### 3.2 Field Scheduling and Work Order Management

| ID | Priority | Requirement |
|---|---|---|
| FS-001 | 1 | The system shall generate field work orders for interdisciplinary team surveys automatically upon completion of a configurable trigger event (e.g., pre-application consultation closed). |
| FS-002 | 1 | The system shall encode seasonal survey constraints as configurable rules by work type and species/resource, and shall prevent scheduling of surveys outside their valid seasonal window. |
| FS-003 | 1 | The system shall model shared physical access resources (e.g., locked gates, access roads) and enforce non-overlapping scheduling across specialists using the same access point. |
| FS-004 | 1 | The system shall support offline mobile work order completion with automatic data synchronization upon restoration of connectivity. |
| FS-005 | 2 | The system shall include an optimization engine that sequences multiple work orders against seasonal constraints, resource availability, and travel efficiency simultaneously. |
| FS-006 | 2 | The system shall automatically create co-permit initiation tasks with SLA tracking when a designated work order is closed. |

### 3.3 Document Management (CEQ Entity 3)

| ID | Priority | Requirement |
|---|---|---|
| DM-001 | 1 | The system shall maintain document records conforming to CEQ Entity 3 properties including document type, status, publish date, public access flag, and all five CEQ provenance fields. |
| DM-002 | 1 | The system shall enforce a configurable required document registry: for each review type and stage, a defined list of required document types must be present and in an approved status before the stage gate can fire. |
| DM-003 | 1 | The system shall support document versioning with a clear latest-version designation and version history. |
| DM-004 | 1 | The system shall enforce page limit rules per 40 CFR 1502.7 (EIS page limits) with configurable thresholds by document type and review pathway. |
| DM-005 | 2 | The system shall support AI-assisted generation of EIS section drafts from structured process data, with mandatory human review before any draft is designated as a work product. |
| DM-006 | 2 | The system shall maintain a complete administrative record export function producing a date-stamped, indexed archive of all documents, comments, and correspondence associated with a process. |

### 3.4 Public Comment Management (CEQ Entity 4)

| ID | Priority | Requirement |
|---|---|---|
| PC-001 | 1 | The system shall accept public comment submissions via web form, email, and written mail intake, capturing commenter name, organization, submission method, date, and comment body. |
| PC-002 | 1 | The system shall enforce comment period gating: the system shall reject comment submissions received outside the open comment period window. |
| PC-003 | 1 | The system shall classify comments as substantive or non-substantive, with the classification visible to agency reviewers and subject to human override with audit trail. |
| PC-004 | 2 | The system shall provide AI-assisted comment triage including sentiment analysis, topic clustering, and substantive issue identification, subject to human review and compliant with OMB M-24-10 audit trail requirements. |
| PC-005 | 2 | The system shall check commenter organizations against a configurable litigation history registry and flag prior plaintiffs for elevated legal review, with the flag and rationale recorded in the administrative record. |
| PC-006 | 2 | The system shall route substantive comments as work orders to the appropriate resource specialist with SLA tracking and response status visible on the process record. |
| PC-007 | 1 | The system shall maintain a complete comment response log linking each substantive comment to its final agency response and the document section in which it was addressed. |

### 3.5 Public Engagement Events (CEQ Entity 5)

| ID | Priority | Requirement |
|---|---|---|
| PE-001 | 1 | The system shall track public engagement events (public hearings, scoping meetings, tribal consultations) with event type, format (in-person/virtual/hybrid), date/time, location, attendance count, and public access designation per CEQ Entity 5. |
| PE-002 | 1 | The system shall track ADA accessibility provisions, translation services, and advance notice days per engagement event. |
| PE-003 | 1 | Tribal government-to-government consultation events shall be trackable as a distinct engagement type with configurable response window SLA and a hard stage gate blocking EA/EIS publication until consultation is certified complete. |

### 3.6 Case Events and Timeline (CEQ Entity 6)

| ID | Priority | Requirement |
|---|---|---|
| TL-001 | 1 | The system shall maintain a structured case event timeline per process, conforming to CEQ Entity 6 properties including event type, status, tier, source, start/end dates, and public access designation. |
| TL-002 | 1 | The system shall display the timeline in chronological order with completed, in-progress, and planned events visually distinguished. |
| TL-003 | 2 | The system shall calculate and display projected completion dates based on remaining required events and historical stage duration data. |

### 3.7 GIS Data (CEQ Entity 7)

| ID | Priority | Requirement |
|---|---|---|
| GIS-001 | 1 | The system shall maintain GIS data element records per CEQ Entity 7, capturing spatial data format, access method, coordinate system, bounding box, purpose, and access information for each layer associated with a project. |
| GIS-002 | 1 | The system shall support storage of project location as a point (lat/lon) and polygon geometry. |
| GIS-003 | 2 | The system shall perform automated proximity checks against a configurable registry of federal spatial datasets (protected areas, critical habitat, wetlands, floodplains, cultural resources, environmental justice indices) when project coordinates are set or updated. |
| GIS-004 | 2 | Proximity check results shall be written back to the project record and shall flag extraordinary circumstances for CE eligibility screening. |
| GIS-005 | 2 | The GIS layer registry shall be configurable by administrators without code changes, supporting addition of new ArcGIS FeatureServer endpoints or other OGC-compliant services. |

### 3.8 User Role Management (CEQ Entity 8)

| ID | Priority | Requirement |
|---|---|---|
| UR-001 | 1 | The system shall support structured assignment of users to processes with a defined role type (Lead NEPA Coordinator, Cooperating Agency Rep, Reviewer, Preparer, Legal Reviewer, Tribal Liaison, GIS Specialist, Field Team Member), assignment dates, and agency affiliation. |
| UR-002 | 1 | The system shall maintain an active/inactive flag on assignments to support audit trail preservation without deletion when an assignment ends. |
| UR-003 | 1 | Role assignments shall be exportable as part of the CEQ-standard process data payload. |

### 3.9 Legal Structure (CEQ Entity 9)

| ID | Priority | Requirement |
|---|---|---|
| LS-001 | 1 | The system shall support linkage of each NEPA process to one or more regulatory citations capturing citation text, issuing authority, effective dates, compliance requirements, and full regulatory text. |
| LS-002 | 1 | Regulatory citations shall be linkable to configurable decision elements (CE criteria, threshold values, extraordinary circumstance conditions) that drive automated screening logic. |
| LS-003 | 2 | The citation registry shall be configurable by administrators and shall support EffectiveTo dating to mark superseded regulations without deletion. |

### 3.10 Applicant Self-Service Portal

| ID | Priority | Requirement |
|---|---|---|
| AP-001 | 1 | The system shall provide a public-facing authenticated portal for applicants to view the current status, active stage, and projected milestones of their permits. |
| AP-002 | 1 | The system shall deliver automatically generated notifications to applicants upon configurable trigger events (comment period open, decision issued, document published, action item assigned). |
| AP-003 | 1 | Applicants shall be able to submit public comments through the portal when the comment period is open; the portal shall enforce the comment period gate. |
| AP-004 | 2 | The portal shall allow applicants to view published documents associated with their permit and receive the signed decision record electronically upon issuance. |
| AP-005 | 2 | The portal shall display co-permit action items assigned to the applicant with due dates and status. |

---

## 4. Technical Requirements

| ID | Priority | Requirement |
|---|---|---|
| TR-001 | 1 | The platform shall be a cloud-hosted SaaS solution requiring no Agency-managed server infrastructure. |
| TR-002 | 1 | The platform shall support configuration-driven customization of business rules, document requirements, stage gates, and screening thresholds without custom code. Rule changes shall not require a deployment cycle. |
| TR-003 | 1 | All configuration tables (CE rules, SLA thresholds, document registries, GIS layer registries, risk weights) shall be stored as structured metadata records editable by authorized administrators. |
| TR-004 | 1 | The platform shall provide a REST API for all core entities to support integration with Agency and federal permitting systems. |
| TR-005 | 1 | The platform shall support bulk data operations for import, export, and migration of at least 10,000 records per operation. |
| TR-006 | 2 | The platform shall support mobile field operations including offline capability, photo capture, and work order completion without network connectivity. |
| TR-007 | 2 | AI/ML capabilities shall be explainable: the system shall provide a human-readable rationale for each AI-generated classification, score, or recommendation that is stored in the record. |
| TR-008 | 1 | AI/ML models used for substantive decisions (routing, risk scoring, comment classification) shall be auditable. The Contractor shall provide documentation of training data provenance, model type, and accuracy metrics upon request. |

---

## 5. Data and Interoperability Requirements

| ID | Priority | Requirement |
|---|---|---|
| DI-001 | 1 | The platform's data model shall conform to the nine CEQ Standard entities defined in the CEQ NEPA and Permitting Data and Technology Standard v1.2: Project, Process, Documents, Public Comments, Public Engagement Events, Case Events, GIS Data, User Roles, and Legal Structure. |
| DI-002 | 1 | The platform shall produce a structured JSON export payload per project that maps all nine CEQ entity properties to the standard's required output field names. |
| DI-003 | 1 | The export payload shall include schema version, standard name, and export timestamp metadata. |
| DI-004 | 2 | The platform shall support automated periodic export to the FPISC Permitting Dashboard and any other federal reporting system designated by the Agency, via REST API or SFTP. |
| DI-005 | 1 | All data records shall carry the five CEQ provenance fields: data_record_version, data_source_agency, data_source_system, record_owner_agency, retrieved_timestamp. |
| DI-006 | 2 | The platform shall support ingestion of existing project data from Agency legacy systems via bulk import with configurable field mapping. |

---

## 6. Security and Compliance Requirements

| ID | Priority | Requirement |
|---|---|---|
| SC-001 | 1 | The platform shall operate on infrastructure authorized under FedRAMP High or FedRAMP Moderate, as required by Agency data classification. |
| SC-002 | 1 | The platform shall support role-based access control (RBAC) with field-level security configurable per role. Public-facing portal users shall have access only to records designated with a public access flag. |
| SC-003 | 1 | All data in transit shall be encrypted using TLS 1.2 or higher. All data at rest shall be encrypted using AES-256 or equivalent. |
| SC-004 | 1 | The platform shall comply with Section 508 of the Rehabilitation Act for all applicant-facing portal components. |
| SC-005 | 1 | The platform shall maintain a complete, immutable audit log of all record creation, modification, and deletion events, including the user, timestamp, and field-level changes. |
| SC-006 | 1 | The platform shall support PIV/CAC authentication for Agency staff and MFA for all user accounts. |
| SC-007 | 1 | AI-generated outputs used in any decision-affecting workflow shall comply with OMB M-24-10, including: (a) human review before any AI output is acted upon, (b) audit trail recording the AI output, confidence score, human review decision, and any override, and (c) no fully automated adverse actions against applicants or commenters. |
| SC-008 | 2 | The platform shall support data residency within the continental United States. |
| SC-009 | 1 | The Contractor shall provide a System Security Plan (SSP) and Authority to Operate (ATO) documentation within 90 days of contract award. |

---

## 7. Implementation Requirements

| ID | Priority | Requirement |
|---|---|---|
| IR-001 | 1 | The Contractor shall provide a phased implementation plan that delivers core case management, document registry, and applicant portal capabilities within the base period (12 months). |
| IR-002 | 1 | The Contractor shall conduct a current-state data inventory and provide a data migration plan for existing NEPA project records within 60 days of contract award. |
| IR-003 | 1 | The Contractor shall deliver role-based training for field staff, NEPA coordinators, and administrators. Training materials shall be retained for Agency use after the contract period. |
| IR-004 | 1 | The Contractor shall provide a dedicated implementation project manager as a named resource for the duration of the base period. |
| IR-005 | 2 | The Contractor shall provide a pilot deployment to one designated field office prior to agency-wide rollout, with a defined success criteria gate before expansion. |
| IR-006 | 1 | The Contractor shall provide a configuration management plan documenting all Agency-specific configurations so they can be reproduced, version-controlled, and migrated to future environments. |

---

## 8. Performance Standards

| Metric | Standard | Measurement Period |
|---|---|---|
| Platform availability | ≥ 99.5% uptime (excluding scheduled maintenance) | Monthly |
| Portal page load time | ≤ 3 seconds at P95 under normal load | Weekly |
| API response time | ≤ 2 seconds at P95 for single-record queries | Weekly |
| Bulk export response | ≤ 60 seconds for full project export (all 9 entities) | Per transaction |
| Security patching | Critical CVEs patched within 72 hours | Per incident |
| Help desk response — Priority 1 (system down) | ≤ 2 hours | Per incident |
| Help desk response — Priority 2 (major function impaired) | ≤ 8 hours | Per incident |
| Help desk response — Priority 3 (minor issue) | ≤ 3 business days | Per incident |

---

## 9. Deliverables

| # | Deliverable | Due |
|---|---|---|
| D-01 | Project Management Plan | 30 days after award |
| D-02 | System Security Plan (SSP) draft | 60 days after award |
| D-03 | Data Migration Plan | 60 days after award |
| D-04 | Configuration Management Plan | 90 days after award |
| D-05 | Authority to Operate (ATO) documentation | 90 days after award |
| D-06 | Pilot deployment — one field office | 6 months after award |
| D-07 | Training materials (role-based) | 8 months after award |
| D-08 | Agency-wide production deployment | 12 months after award |
| D-09 | CEQ-standard export API — operational | 12 months after award |
| D-10 | Monthly status reports | Monthly throughout PoP |
| D-11 | Annual system performance report | Annually |

---

## 10. Evaluation Criteria

Proposals will be evaluated on a Best Value basis using the following factors, listed in descending order of importance:

### Factor 1 — Technical Approach (40%)

- Demonstrated conformance of proposed platform's data model to CEQ NEPA and Permitting Data and Technology Standard v1.2 (all nine entities)
- Maturity and completeness of field scheduling and optimization capability, including seasonal constraint enforcement
- Approach to AI-assisted capabilities, human-in-the-loop controls, and OMB M-24-10 compliance
- Configurability of business rules, stage gates, and document registries without code changes
- Quality of CEQ-standard data export implementation

### Factor 2 — Past Performance (25%)

- Prior delivery of NEPA, permitting, or environmental review case management systems for federal or state land management agencies
- Prior delivery of field service scheduling and optimization for natural resource or infrastructure field operations
- Prior delivery of FedRAMP-authorized SaaS platforms to federal civilian agencies

### Factor 3 — Management Approach (20%)

- Staffing plan including named key personnel (PM, technical lead, data architect)
- Phased implementation plan with defined pilot criteria and agency-wide rollout milestone
- Training and change management approach for field staff in remote locations

### Factor 4 — Price (15%)

- Total evaluated price across base year and all option years
- Transparency of licensing, configuration, integration, training, and ongoing support pricing

---

## 11. Proposal Instructions

### 11.1 Submission Format

Proposals shall be submitted electronically to [Contracting Officer email] no later than [Date] at [Time] [Timezone].

Proposals shall consist of two volumes submitted as separate files:

**Volume I — Technical and Management Proposal** (page limit: 50 pages)
- Section 1: Technical Approach — address each functional requirement category in Section 3 and technical requirements in Section 4. For each requirement, state whether the capability is: (a) available in current COTS/GOTS product without configuration, (b) achievable through configuration, or (c) requires custom development.
- Section 2: Data and Interoperability Approach — demonstrate CEQ standard v1.2 conformance with a sample data model mapping
- Section 3: Security and AI Governance Approach
- Section 4: Implementation Plan with milestone schedule
- Section 5: Past Performance — up to three relevant contracts with agency POC contact information

**Volume II — Price Proposal** (no page limit)
- Labor categories, rates, and hours by phase
- Software licensing costs by user tier
- Integration, training, and ongoing support costs
- Total evaluated price summary by base year and option year

### 11.2 Questions

Questions shall be submitted in writing to [Contracting Officer email] no later than [Date]. Answers will be posted as an amendment to this RFP on [SAM.gov or agency portal] no later than [Date].

### 11.3 Oral Presentations

The Agency reserves the right to conduct oral presentations or demonstrations with offerors in the competitive range. If scheduled, offerors will be notified at least [N] business days in advance.

---

*This document is issued for proposal purposes only. The Agency reserves the right to amend, cancel, or withdraw this RFP at any time. Issuance of this RFP does not obligate the Agency to award a contract.*
