# NEPA Data Standard v1.2.0 - OpenAPI/Swagger Specification

**Source:** https://permitting.innovation.gov/swagger.json  
**Spec Version:** 12.2.3 (519615d)  
**API Host:** sampleserver.com (sample reference)  
**Base Path:** `/`  
**Schemes:** HTTPS  

---

## Overview

The NEPA Data Standard v1.2.0 defines a comprehensive OpenAPI 2.0 specification for environmental review and permitting data interoperability. The specification is served via PostgREST (PostgreSQL REST API) and supports JSON, CSV, and extended PostgREST formats.

**Raw Specification Location:** `/Users/shannon.schupbach/claude-projects/PSA-NEPA-Permitting-Data-Model/nepa_swagger_spec.json`

---

## Supported Content Types

### Consumes
- `application/json`
- `application/vnd.pgrst.object+json;nulls=stripped`
- `application/vnd.pgrst.object+json`
- `text/csv`

### Produces
Same as Consumes, plus:
- `application/openapi+json` (for introspection endpoint)

---

## API Endpoints (Paths)

All data endpoints support **CRUD operations**:

| Endpoint | HTTP Methods | Purpose |
|----------|--------------|---------|
| `/` | GET | OpenAPI introspection (this specification document) |
| `/legal_structure` | GET, POST, DELETE, PATCH | Legal, policy, or process data guiding NEPA |
| `/gis_data` | GET, POST, DELETE, PATCH | Location-based information container |
| `/gis_data_element` | GET, POST, DELETE, PATCH | Individual GIS data element inventory |
| `/comment` | GET, POST, DELETE, PATCH | Public feedback and comments |
| `/engagement` | GET, POST, DELETE, PATCH | Public interaction opportunities in NEPA |
| `/process_model` | GET, POST, DELETE, PATCH | Coded BPMN process representations |
| `/process_instance` | GET, POST, DELETE, PATCH | Specific environmental reviews/permits |
| `/document` | GET, POST, DELETE, PATCH | Document metadata and structure |
| `/process_decision_payload` | GET, POST, DELETE, PATCH | Decision element results/responses |
| `/user_role` | GET, POST, DELETE, PATCH | System stakeholder definitions |
| `/case_event` | GET, POST, DELETE, PATCH | Milestones/steps in review lifecycle |
| `/decision_element` | GET, POST, DELETE, PATCH | Process start/decision tree conditions |
| `/project` | GET, POST, DELETE, PATCH | Activity/decision requiring NEPA review |
| `/rpc/export_all_tables_as_jsonb` | POST | RPC endpoint for bulk export |

---

## Data Models (Definitions)

### 1. **project**
Project represents the activity or decision requiring a NEPA review process.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `title` (text)
- `description` (text)
- `type` (text)
- `sector` (text)
- `lead_agency` (text)
- `participating_agencies` (text)
- `start_date` (date)
- `current_status` (text) — pre-application, underway, paused, completed
- `sponsor` (text)
- `sponsor_contact` (json)
- `location_lat` (double)
- `location_lon` (double)
- `location_text` (text)
- `location_object` (reference to GIS object)
- `funding` (text/json)
- `parent_project_id` (bigint, FK → project.id)
- `other` (jsonb)
- Provenance: `record_owner_agency`, `data_source_agency`, `data_source_system`, `data_record_version`, `last_updated`, `retrieved_timestamp`

---

### 2. **process_instance**
Specific environmental review, permit, or authorization associated with a project.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_project_id` (bigint, FK → project.id)
- `process_model_id` (bigint, FK → process_model.id)
- `current_status` (text)
- `start_date` (date)
- `end_date` (date)
- `estimated_completion` (date)
- `process_type` (text)
- `lead_agency` (text)
- `documents` (array/relationship to document.id)
- `other` (jsonb)
- Provenance fields

---

### 3. **document**
Document metadata, structure (table of contents), and summary information. May have associated GIS objects.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_process_id` (bigint, FK → process_instance.id)
- `title` (text)
- `type` (text) — e.g., NEPA document type (EA, EIS, FONSI, ROD, etc.)
- `date_published` (date)
- `url` (text)
- `document_structure` (json) — table of contents, section headings
- `summary_text` (text)
- `version_number` (integer)
- `public_access` (boolean)
- `other` (jsonb)
- Provenance fields

---

### 4. **comment**
Feedback submitted by individuals or organizations during public comment periods.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_document_id` (bigint, FK → document.id)
- `commenter_entity` (text) — individual or organization
- `date_submitted` (date)
- `submission_method` (text) — online, email, mail, in-person
- `content_text` (text)
- `content_json` (json)
- `response_text` (text)
- `response_json` (json)
- `public_source` (boolean)
- `public_access` (boolean)
- `other` (jsonb)
- Provenance fields

---

### 5. **engagement**
Opportunities for public interaction in the NEPA process (meetings, consultation periods, etc.).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_process_id` (bigint, FK → process_instance.id)
- `type` (text) — e.g., public meeting, comment period, consultation
- `location` (text) — physical, virtual, or hybrid
- `related_document_id` (bigint, FK → document.id)
- `attendance` (bigint)
- `participation` (json)
- `start_datetime` (timestamp)
- `end_datetime` (timestamp)
- `notes` (text)
- `other` (jsonb)
- Provenance fields

---

### 6. **case_event**
Milestones or steps within the NEPA review (tracked in case management or task systems).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_process_id` (bigint, FK → process_instance.id)
- `event_type` (text) — milestone category
- `description` (text)
- `due_date` (date)
- `completion_date` (date)
- `owner` (text)
- `status` (text)
- `notes` (text)
- `other` (jsonb)
- Provenance fields

---

### 7. **process_model**
Coded representation of a generic process (BPMN notation) and screening criteria.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `title` (text)
- `description` (text)
- `bpmn_model` (json) — BPMN XML or diagram representation
- `legal_structure_id` (bigint, FK → legal_structure.id)
- `legal_structure_text` (text)
- `screening_description` (text)
- `screening_desc_json` (json)
- `agency` (text)
- `parent_model` (bigint, FK → process_model.id)
- `DMN_model` (jsonb) — Decision Model Notation for evaluation logic
- `other` (jsonb)
- Provenance fields

---

### 8. **decision_element**
Conditions for starting a process or resolving a decision tree (includes GIS screening).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_process_model_id` (bigint, FK → process_model.id)
- `description` (text)
- `decision_type` (text) — e.g., binary, multi-choice, GIS-based
- `gis_screening_id` (bigint, FK → gis_data_element.id)
- `gis_criteria` (json)
- `evaluation_logic` (json)
- `outcome_options` (json) — possible decision results
- `other` (jsonb)
- Provenance fields

---

### 9. **process_decision_payload**
Results and responses of the evaluation criteria in process decision elements.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `decision_element_id` (bigint, FK → decision_element.id)
- `process_instance_id` (bigint, FK → process_instance.id)
- `decision_value` (text/json)
- `reasoning` (text)
- `supporting_data` (json)
- `evaluation_timestamp` (timestamp)
- `other` (jsonb)
- Provenance fields

---

### 10. **legal_structure**
Legal, policy, or process data guiding NEPA (statutes, regulations, thresholds).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `title` (text)
- `citation` (text)
- `description` (text)
- `context` (text) — full text or excerpt
- `issuing_authority` (text)
- `effective_date` (date)
- `compliance_data` (json) — procedural mandates, thresholds, duties, actors (FLINT frames)
- `url` (text)
- `other` (jsonb)
- Provenance fields

---

### 11. **gis_data**
Container for location-based information (points, polygons, maps).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_document_id` (bigint, FK → document.id)
- `parent_process_id` (bigint, FK → process_instance.id)
- `title` (text)
- `description` (text)
- `gis_elements` (array/relationship to gis_data_element.id)
- `map_type` (text)
- `overall_extent_north` (double)
- `overall_extent_south` (double)
- `overall_extent_east` (double)
- `overall_extent_west` (double)
- `purpose` (text)
- `other` (jsonb)
- Provenance fields

---

### 12. **gis_data_element**
Individual GIS data element inventory (layers, formats, coordinate systems).

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `parent_gis` (bigint, FK → gis_data.id)
- `container_reference` (text)
- `format` (text) — GeoJSON, Shapefile, KML
- `access_method` (text) — URL, API, direct upload
- `coordinate_system` (text)
- `top_left_lat`, `top_left_lon` (double) — geographic extent
- `bot_right_lat`, `bot_right_lon` (double)
- `purpose` (text) — Bespoke (project-specific), Analysis, or Base Map
- `data_match` (text) — whether object references an identified GIS inventory item
- `access_info` (json)
- `other` (jsonb)
- Provenance fields

---

### 13. **user_role**
Defines stakeholders interacting with the NEPA IT system.

**Key Fields:**
- `id` (bigint, PK)
- `created_at` (timestamp)
- `name` (text)
- `agency_affiliation` (text)
- `role_type` (text)
- `permissions` (json)
- `other` (jsonb)
- Provenance fields

---

## Common Query Parameters

All GET endpoints support these parameters (via PostgREST):

### Filtering
- Row filters for each field (e.g., `?id=eq.123`, `?title=ilike.*NEPA*`)
- Exact match, range, text search operators

### Pagination & Ordering
- `select` — Select specific columns
- `order` — Sort order (e.g., `?order=created_at.desc`)
- `limit` — Max records per page (default depends on PostgREST config)
- `offset` — Pagination offset
- `range` — Range slicing (e.g., `?range=0-10`)
- `rangeUnit` — Range unit specification
- `preferCount` — Request count metadata in response header

### Response Format
- Default: JSON (Hypermedia-like PostgREST format)
- CSV: Add `Accept: text/csv` header
- Compact JSON: Use `application/vnd.pgrst.object+json;nulls=stripped`

---

## Relationships & Foreign Keys

```
project
  ├─ parent_project_id → project (self-referential)
  └─ location_object → gis_data

process_instance
  ├─ parent_project_id → project
  ├─ process_model_id → process_model
  └─ documents → document (1-to-many)

document
  ├─ parent_process_id → process_instance
  ├─ gis_objects → gis_data (1-to-many)
  └─ comments → comment (1-to-many)

comment
  └─ parent_document_id → document

engagement
  ├─ parent_process_id → process_instance
  └─ related_document_id → document

case_event
  └─ parent_process_id → process_instance

process_model
  ├─ legal_structure_id → legal_structure
  ├─ parent_model → process_model (self-referential)
  └─ decision_elements → decision_element (1-to-many)

decision_element
  ├─ parent_process_model_id → process_model
  └─ gis_screening_id → gis_data_element

process_decision_payload
  ├─ decision_element_id → decision_element
  └─ process_instance_id → process_instance

gis_data
  ├─ parent_document_id → document
  ├─ parent_process_id → process_instance
  └─ gis_elements → gis_data_element (1-to-many)

gis_data_element
  └─ parent_gis → gis_data
```

---

## Provenance Fields (All Models)

Every model includes:
- `record_owner_agency` — authoritative data source
- `data_source_agency` — agency from which data was sent/retrieved/stored
- `data_source_system` — system where data resides
- `data_record_version` — version of this record
- `last_updated` — last update timestamp
- `retrieved_timestamp` — timestamp of retrieval/transmission

---

## RPC Endpoint

### `/rpc/export_all_tables_as_jsonb` (POST)
Bulk export of all tables as JSONB. Useful for data synchronization and backups.

---

## Alignment with PSA-NEPA Project

### CEQ Entity Mapping

| NEPA Data Standard | PSA-NEPA Salesforce Object | Notes |
|-------------------|---------------------------|-------|
| `project` | `Program__c` | Project/initiative-level entity |
| `process_instance` | `IndividualApplication__c` | Environmental review stage/lifecycle |
| `document` | `ContentVersion` | Document storage with metadata |
| `comment` | `PublicComplaint__c` | Public feedback and comments |
| `engagement` | `nepa_engagement__c` | Public participation events |
| `case_event` | `ApplicationTimeline__c` | Milestones and case events |
| `gis_data` + `gis_data_element` | Custom objects (planned) | Geographic boundary and analysis data |
| `legal_structure` | Custom metadata `NEPA_Process_Model__mdt` | Legal/regulatory framework |
| `process_model` | Flows + `NEPA_Process_Model__mdt` | NEPA process workflows (CE Screener, Timeline Risk Assessor, etc.) |
| `decision_element` | Flow Decision elements + metadata | Conditions for process routing |
| `process_decision_payload` | Custom metadata for decision results | Evaluation outcomes and risk scoring |

---

## Integration Notes

1. **GIS Data:** The standard supports geospatial data via `gis_data` and `gis_data_element`. PSA-NEPA can leverage this for project boundary, affected resource area, and analysis layer management.

2. **Document Structure:** `document.document_structure` (json) allows for structured table of contents, which aligns with NEPA_Defensibility_Gap_Checker flows that analyze document completeness.

3. **Decision Logic:** `process_model.DMN_model` (Decision Model Notation) and `decision_element` support complex routing logic similar to PSA-NEPA's risk scoring and CE screening workflows.

4. **Comment Triage:** `comment` model includes `content_text`, `content_json`, and `response_text`, which maps to PSA-NEPA's planned Comment Triage agent for sentiment, issue clustering, and response generation.

5. **Compliance & Provenance:** Built-in `record_owner_agency` and `data_source_agency` fields support audit trail requirements per OMB M-24-10.

---

## PostgREST Documentation

For detailed query syntax and advanced filtering, see: https://postgrest.org/en/v12/references/api.html

---

## Raw Specification File

The complete OpenAPI 2.0 specification (7,869 lines) is available at:
- **Local path:** `/Users/shannon.schupbach/claude-projects/PSA-NEPA-Permitting-Data-Model/nepa_swagger_spec.json`
- **Remote URL:** `https://permitting.innovation.gov/swagger.json`

