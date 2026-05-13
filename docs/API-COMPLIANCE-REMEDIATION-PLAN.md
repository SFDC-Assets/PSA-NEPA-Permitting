# API Compliance Remediation Plan

**Project:** PSA-NEPA-Permitting-Data-Model
**Standard:** CEQ NEPA and Permitting Data and Technology Standard v1.2.0
**Reference spec:** https://github.com/GSA-TTS/pic-standards — `src/openapi/openapi.yaml` (6,094 lines, 13 schemas)
**Created:** 2026-05-12
**Status:** Completed — Phases 1–6 deployed to NEPADEMO 2026-05-12

---

## Background

A field-by-field comparison of the PIC OpenAPI spec (`openapi.yaml`, v12.2.3) against the deployed PSA-NEPA data model identified coverage gaps in 5 of 13 standard entities. Two entities (`gis_data`, `user_role`) are structural gaps. Eight entities have strong coverage with the provenance pattern (`record_owner_agency`, `data_source_agency`, `data_source_system`, `data_record_version`, `retrieved_timestamp`) implemented on all objects.

### Entity Coverage Summary

| Standard Entity | Our Object | Coverage |
|---|---|---|
| `project` | `Program` | Strong |
| `process_instance` | `IndividualApplication` | Complete — nepa_process_model_id__c added (Phase 3) |
| `document` | `ContentVersion` | Strong |
| `comment` | `PublicComplaint` | Strong |
| `engagement` | `nepa_engagement__c` | Strong |
| `case_event` | `ApplicationTimeline` | Strong |
| `decision_element` | `nepa_decision_element__c` | Complete — all 9 fields added (Phase 1) |
| `process_decision_payload` | `nepa_decision_log__c` | Complete — new object created (Phase 2) |
| `process_model` | `NEPA_Process_Model__mdt` | Complete — all 5 fields added (Phase 5) |
| `gis_data` | `nepa_gis_data__c` | Complete — new object created (Phase 6) |
| `gis_data_element` | `nepa_gis_data_element__c` | Strong |
| `legal_structure` | `RegulatoryCode` (PSS standard) | Partial — platform object, no custom fields added |
| `user_role` | *(Permission Sets — no data record)* | By-design gap — Salesforce platform mechanism |

---

## Phase 1 — `decision_element` field completeness

**Priority:** High
**File:** `force-app/main/default/objects/nepa_decision_element__c.object`
**Also update:** `NEPA_Permitting.permissionset`, `package.xml`

Add 9 fields to `nepa_decision_element__c`:

| API Name | Type | Maps to standard field | Notes |
|---|---|---|---|
| `nepa_title__c` | Text(255) | `title` | Free-text name for the criterion |
| `nepa_description__c` | LongTextArea(32768) | `description` | Full description of the criterion |
| `nepa_measure__c` | Text(255) | `measure` | Measurement name (e.g., "Disturbance Acres") |
| `nepa_process_model_id__c` | Text(80) | `process_model` | Stores `NEPA_Process_Model__mdt.DeveloperName` — CMTs are not Lookup targets |
| `nepa_parent_decision_element__c` | Lookup → nepa_decision_element__c | `parent_decision_element_id` | Hierarchical criteria (deleteConstraint: SetNull) |
| `nepa_form_text__c` | LongTextArea(32768) | `form_text` | Screening form question text presented to users |
| `nepa_form_data__c` | LongTextArea(32768) | `form_data` | Structured form definition (JSON) |
| `nepa_intersect__c` | Checkbox (default false) | `intersect` | Whether spatial intersect is required |
| `nepa_response_data__c` | LongTextArea(32768) | `response_data` | Stored evaluation response data (JSON) |
| `nepa_other__c` | LongTextArea(32768) | `other` | Extension bag for non-standard properties |

**FLS:** All 10 fields → editable + readable in `NEPA_Permitting` permission set.

---

## Phase 2 — `process_decision_payload` structural realignment

**Priority:** High
**New file:** `force-app/main/default/objects/nepa_decision_log__c.object`
**Also update:** `NEPA_Permitting.permissionset`, `package.xml`

### Context

The standard's `process_decision_payload` is a **per-criterion evaluation record**: it links a `decision_element` criterion to a `process_instance`, stores the evaluation input data, and records the boolean result. Our current `nepa_decision_payload__c` is a **final decision document record** (ROD/FONSI content). These are different concepts. Decision is: keep `nepa_decision_payload__c` as-is (it's correct for what it does and deployed in flows), and add a new object `nepa_decision_log__c` that satisfies the standard's payload role.

> Decision Explainer (Salesforce Industries feature) may natively serve this role. Evaluate when assessing PSS feature availability in target org. If Decision Explainer is available, `nepa_decision_log__c` can be deprecated in favor of it.

### New object: `nepa_decision_log__c`

Object settings:
- Label: NEPA Decision Log
- Plural: NEPA Decision Logs
- Description: CEQ Standard Entity — process_decision_payload. Per-criterion evaluation record linking a decision element criterion to a process instance. Stores evaluation inputs, result, and explanation data. Supports structured screening audit trail and administrative record completeness.
- enableHistory: false
- enableReports: true
- enableSearch: true
- sharingModel: ControlledByParent

| API Name | Type | Maps to standard field | Notes |
|---|---|---|---|
| `nepa_process__c` | MasterDetail → IndividualApplication | `process` | relationshipOrder: 0 |
| `nepa_decision_element__c` | Lookup → nepa_decision_element__c | `process_decision_element` | deleteConstraint: SetNull |
| `nepa_project__c` | Lookup → Program | `project` | deleteConstraint: SetNull |
| `nepa_evaluation_data__c` | LongTextArea(32768) | `evaluation_data` | Input data used for evaluation (JSON) |
| `nepa_response__c` | LongTextArea(32768) | `response` | Narrative response to the decision element |
| `nepa_result__c` | Text(255) | `result` | Outcome text (e.g., "Qualifies for CE") |
| `nepa_result_bool__c` | Checkbox (default false) | `result_bool` | Boolean pass/fail result |
| `nepa_result_notes__c` | LongTextArea(32768) | `result_notes` | Supplemental notes on the result |
| `nepa_result_data__c` | LongTextArea(32768) | `result_data` | Structured result data (JSON) |
| `nepa_result_source__c` | Text(255) | `result_source` | Source of evaluation (e.g., BRE, manual, AI) |
| `nepa_parent_log__c` | Lookup → nepa_decision_log__c | `parent_payload` | Hierarchical log chain; deleteConstraint: SetNull |
| `nepa_data_annotation__c` | LongTextArea(32768) | `data_annotation` | Annotation on the evaluation data |
| `nepa_evaluation_data_annotation__c` | LongTextArea(32768) | `evaluation_data_annotation` | Structured annotation (JSON) |
| `nepa_other__c` | LongTextArea(32768) | `other` | Extension bag |
| `nepa_data_record_version__c` | Text(50) | `data_record_version` | Provenance |
| `nepa_data_source_agency__c` | Text(255) | `data_source_agency` | Provenance |
| `nepa_data_source_system__c` | Text(255) | `data_source_system` | Provenance |
| `nepa_record_owner_agency__c` | Text(255) | `record_owner_agency` | Provenance |
| `nepa_retrieved_timestamp__c` | DateTime | `retrieved_timestamp` | Provenance |

**FLS:** All 19 fields → editable + readable in `NEPA_Permitting` permission set.

---

## Phase 3 — `process_instance` process model FK

**Priority:** Medium
**File:** `force-app/main/default/objects/IndividualApplication.object`
**Also update:** `NEPA_Permitting.permissionset`, `package.xml`

Add 1 field:

| API Name | Type | Maps to standard field | Notes |
|---|---|---|---|
| `nepa_process_model_id__c` | Text(80) | `process_model` | Stores `NEPA_Process_Model__mdt.DeveloperName`; CMTs cannot be Lookup targets |

**FLS:** editable + readable in `NEPA_Permitting` permission set.

---

## Phase 4 — `other` extension bag on all core objects

**Priority:** Low
**Files:** 8 object files listed below
**Also update:** `NEPA_Permitting.permissionset`, `package.xml`

Add `nepa_other__c` (LongTextArea, 32768, label "Other (JSON)") to each object that does not already have it. Satisfies the `other: jsonb` extension bag present on every standard entity.

| Object file | Already has `nepa_other__c`? |
|---|---|
| `Program.object` | No — add |
| `IndividualApplication.object` | No — add |
| `ContentVersion.object` | No — add |
| `PublicComplaint.object` | No — add |
| `nepa_engagement__c.object` | No — add |
| `ApplicationTimeline.object` | No — add |
| `nepa_decision_element__c.object` | Added in Phase 1 |
| `nepa_decision_payload__c.object` | No — add |

**Note:** `ContentVersion` and `PublicComplaint` are PSS standard objects. FLS on standard object fields is handled differently — only add the custom `nepa_other__c` field, not platform fields. Confirm FLS is applied via permission set, not profile.

---

## Phase 5 — `process_model` CMT completeness

**Priority:** Low
**File:** `force-app/main/default/objects/NEPA_Process_Model__mdt.object`
**Also update:** `package.xml` (CustomMetadata members, not FLS — CMTs don't use permission sets)

Add 5 fields to `NEPA_Process_Model__mdt`:

| API Name | Type | Maps to standard field | Notes |
|---|---|---|---|
| `Description__c` | LongTextArea(32768) | `description` | Process model description |
| `Agency__c` | Text(255) | `agency` | Owning agency (e.g., BLM, USFS) |
| `Legal_Structure_Citation__c` | Text(255) | `legal_structure_id` | CFR/USC citation text — CMTs cannot FK to RegulatoryCode |
| `Parent_Model_Developer_Name__c` | Text(80) | `parent_model` | DeveloperName of parent process model |
| `Screening_Description__c` | LongTextArea(32768) | `screening_description` | Human-readable description of the screening process |

---

## Phase 6 — `gis_data` container object (Deferred)

**Status:** Complete — deployed 2026-05-12
`nepa_gis_data__c` custom object created with 6 parent lookups (Program, IndividualApplication, ApplicationTimeline, PublicComplaint, nepa_engagement__c; ContentDocument as Text(18)), geometry fields, creator fields, data container fields, provenance, and extension bag. FLS in NEPA_Permitting permission set. Layout and FlexiPage created.

**Standard fields to implement when addressed:**

| Standard field | Type | Notes |
|---|---|---|
| `parent_project_id` | Lookup → Program | |
| `parent_process_id` | Lookup → IndividualApplication | |
| `parent_document_id` | Lookup → ContentVersion | |
| `parent_case_event_id` | Lookup → ApplicationTimeline | |
| `parent_comment_id` | Lookup → PublicComplaint | |
| `parent_engagement_id` | Lookup → nepa_engagement__c | |
| `description` | LongTextArea | |
| `extent` | Text(255) | Bounding box or extent description |
| `centroid_lat` | Number | |
| `centroid_lon` | Number | |
| `creator` | Text(255) | |
| `creator_contact` | LongTextArea (JSON) | |
| `notes` | LongTextArea | |
| `container_inventory` | LongTextArea (JSON) | |
| `map_image` | LongTextArea (JSON) | |
| `data_container` | LongTextArea (JSON) | |
| `address` | Text(255) | |
| + 4 provenance fields | Text/DateTime | Standard pattern |
| `nepa_other__c` | LongTextArea | Extension bag |

---

## Execution Order

```
Phase 1  ✓  nepa_decision_element__c fields + FLS + package.xml (deployed 2026-05-12)
Phase 2  ✓  nepa_decision_log__c new object + FLS + package.xml (deployed 2026-05-12)
Phase 3  ✓  IndividualApplication process_model FK + FLS + package.xml (deployed 2026-05-12)
Phase 4  ✓  nepa_other__c on 7 remaining objects + FLS + package.xml (deployed 2026-05-12)
Phase 5  ✓  NEPA_Process_Model__mdt 5 new CMT fields + package.xml (deployed 2026-05-12)
Phase 6  ✓  nepa_gis_data__c new object + FLS + package.xml (2026-05-12)
```

NepaApiComplianceTest passes all tests in NEPADEMO as of 2026-05-12 (note: ContentVersion DML tests
use Schema.describeSObjectFields() assertions due to SDO package trigger interference in this demo org).

---

## Notes and Constraints

- **CMT FK limitation:** `NEPA_Process_Model__mdt` cannot be a Lookup target from custom objects. All `process_model` FKs use Text fields storing `DeveloperName`.
- **ContentDocument FK limitation:** Salesforce does not support Lookup fields to `ContentDocument` or `ContentVersion`. Document references use Text(18) storing the `ContentDocumentId`.
- **Decision Explainer evaluation:** Salesforce Industries Decision Explainer may natively cover the `nepa_decision_log__c` role (per-criterion evaluation audit). If it is available in the target PSS org, evaluate replacing `nepa_decision_log__c` with native Decision Explainer records. Defer this evaluation; proceed with custom object now.
- **`user_role` entity:** Not implemented. Salesforce Permission Sets are the platform mechanism for role-based access. No custom data record is needed unless multi-agency data exchange requires publishing role definitions as data.
- **`legal_structure` entity:** Covered by PSS `RegulatoryCode` standard object. No custom fields required — RegulatoryCode already carries citation, description, and authority fields.
