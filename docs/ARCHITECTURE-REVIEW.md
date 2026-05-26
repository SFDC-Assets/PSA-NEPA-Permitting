# NEPA Permitting Accelerator — Architecture Review

Static analysis of four architectural areas based on the actual codebase. Each section states what is implemented, answers the technical questions posed, and identifies genuine vulnerabilities with specific mitigations.

---

## Item 13: Close Administrative Record Flow Autopsy

### Implementation Status

`NEPA_Close_Administrative_Record.flow-meta.xml` is fully implemented and Active. It fires `AsyncAfterCommit` on `IndividualApplication` when `nepa_review_type__c` changes to `ROD` or `FONSI` and `nepa_ar_locked__c = false`.

**The flow contains zero SOQL queries.** The prompt premise — a flow querying 5,000 public comments, consultation records, document collections, and risk scores — describes a hypothetical design pattern, not the current implementation. Document assembly is handled by the `NEPA_Close_Administrative_Record` Flow itself, which serializes the record to a `ContentVersion` manifest. **Note:** The `DR_Extract_AR_Manifest` DataRaptor design artifact is present in the repository (backlog — not verified); the working path is the Flow-based assembly. See [OMNISTUDIO-BACKLOG.md](OMNISTUDIO-BACKLOG.md).

---

### Node-by-Node Trace (Actual 6-Element Flow)

| Element | Type | What it does |
|---|---|---|
| `var_ManifestTitle` | Formula | `"Administrative Record Manifest — " & $Record.Name & " — " & TEXT(TODAY())` |
| `formula_ManifestFilename` | Formula | `"ar_manifest_" & $Record.Id & "_" & TEXT(TODAY()) & ".json"` |
| `formula_ManifestEnvelope` | Formula | Inline JSON string built from `$Record.*` fields: `process_id`, `process_name`, `review_type`, `outcome`, `risk_score`, `risk_tier`, `record_complete`. No SOQL. |
| `Build_JSON_Manifest` | Assignment | Copies `formula_ManifestEnvelope` → `var_ManifestJSON` |
| `Create_Manifest_ContentVersion` | RecordCreate | Inserts ContentVersion with Title, PathOnClient, VersionData (`var_ManifestJSON`), `FirstPublishLocationId = $Record.Id`, `nepa_document_type__c = 'Administrative Record Manifest'`, `nepa_ar_included__c = true` |
| `Lock_Application_Record` | RecordUpdate | Sets `nepa_ar_locked__c = true` on IndividualApplication filtered by `Id = $Record.Id` |
| `Handle_Error` / `Call_ErrorLogger` | Assignment + Subflow | Fault path on either DML step; captures `$Flow.FaultMessage`, calls `NEPA_Error_Logger` which publishes `NEPA_Error_Event__e` |

DML budget for this flow: **2 statements** (1 insert, 1 update). SOQL budget: **0 queries**.

---

### Governor Limit Analysis: What Would Break at 5,000 Comments (Hypothetical)

If the flow were redesigned to query and package linked documents, comments, and consultations directly:

**SOQL queries:** A single `Get Records` on PublicComplaint with `nepa_related_process__c = processId` consumes 1 SOQL query (not 5,000 — each `Get Records` element is one query regardless of rows returned). At 5,000 rows returned, the per-query row limit (50,000) is not breached, but:

**Heap size (6 MB async):** A 5,000-comment collection at ~500 bytes per record metadata = 2.5 MB for the SObject collection alone. Add comment body text at an average of 500 characters per body = 2.5 MB additional = 5 MB combined, approaching the 6 MB async heap ceiling before any manifest string construction begins.

**CPU time (10 seconds async):** String concatenation in Flow Assignment loops is O(n²) — each iteration copies the entire accumulated string before appending. At 5,000 iterations:
- Iteration 1: copy 0 bytes + append
- Iteration 2: copy ~500 bytes + append
- ...
- Iteration 5,000: copy ~2.5 MB + append

Total bytes copied ≈ n² × avg_size / 2 ≈ 12.5 billion bytes of string copy operations. This would exceed the 10-second CPU limit before iteration 1,000 for any realistic comment body size.

**Safe architecture (current working design):** The `NEPA_Close_Administrative_Record` Flow handles assembly within normal Flow limits — the manifest is a serialized JSON `ContentVersion`, not a multi-query assembly. **Backlog alternative:** The DataRaptor pattern (delegating to OmniStudio's bulk extraction context with paginated extraction) is a design artifact in the repository but has not been verified; see [OMNISTUDIO-BACKLOG.md](OMNISTUDIO-BACKLOG.md).

---

### Fault Path Analysis

**`Create_Manifest_ContentVersion` faults:** `Handle_Error` captures the message → `Call_ErrorLogger` publishes `NEPA_Error_Event__e`. Record is **not locked** — correct behavior, allows retry on next save.

**`Lock_Application_Record` faults:** Same error path. However, `Create_Manifest_ContentVersion` already succeeded — the ContentVersion exists. The record remains unlocked. On the next qualifying save, the flow runs again and creates a **second manifest ContentVersion**. There is no guard that checks for an existing manifest before creating.

**`formula_ManifestEnvelope` with null numeric fields:** `TEXT({!$Record.nepa_risk_score__c})` returns empty string (`''`) for a null Number field. The JSON produced will contain `"risk_score":` followed by an empty string, producing invalid JSON. A null-guarded formula (`IF(ISNULL(nepa_risk_score__c), "null", TEXT(nepa_risk_score__c))`) would produce valid JSON.

**Formula length ceiling:** Salesforce formula fields have a maximum compiled length of 3,900 characters (operator limit) and runtime evaluation limit of 131,072 characters. `formula_ManifestEnvelope` currently evaluates well under this limit; adding fields to the manifest in future iterations risks silent truncation of `VersionData`.

---

### Static Vulnerabilities

| # | Vulnerability | Location | Severity | Mitigation |
|---|---|---|---|---|
| V1 | Duplicate manifest on lock failure | Between `Create_Manifest_ContentVersion` and `Lock_Application_Record` | Medium | Add a `Get Records` check for existing ContentVersion with `nepa_document_type__c = 'Administrative Record Manifest'` and `FirstPublishLocationId = $Record.Id` before the Create step; skip if found |
| V2 | Invalid JSON on null risk_score | `formula_ManifestEnvelope` line: `TEXT({!$Record.nepa_risk_score__c})` | Low | Wrap numeric fields in `IF(ISNULL(...), "null", TEXT(...))` |
| V3 | No async retry mechanism | `AsyncAfterCommit` path has no platform retry | Low | The error log (`NEPA_Flow_Error__c`) provides an audit trail; a scheduled flow querying for unlocked processes with `nepa_review_type__c` IN ('ROD','FONSI') that lack a manifest ContentVersion would provide a recovery path |
| V4 | Formula length growth risk | `formula_ManifestEnvelope` | Low | Monitor formula character count if fields are added to the manifest; consider switching to Apex-built JSON (or a DataRaptor approach once the backlog OmniStudio path is verified) if the envelope grows beyond 2,000 characters |

---

## Item 14: Record-Triggered Flow Order of Execution Audit

### Implementation Status

The accelerator contains **38 record-triggered and supporting flows**, not 31. The figure "31" predates the addition of: `NEPA_Error_Event_Handler` (platform event subscriber), `NEPA_Comment_Triage_Save` (Agentforce agent target), `NEPA_Defensibility_Trigger_Engagement`, `NEPA_FlowError_CountIncrementer`, `NEPA_EJTribal_Router`, `NEPA_Plaintiff_Intelligence`, `NEPA_Visit_Survey_Window_Setter`, and `NEPA_Visit_Completion_Assessor`. (`NEPA_WO_Milestone_Setter` has been replaced by the `NepaVisitAfterInsert` Apex trigger + `NepaVisitActionPlanLauncher` handler.)

### Full Trigger Map

| Trigger Object | Flow Name | Type | Phase |
|---|---|---|---|
| **IndividualApplication (9)** | | | |
| | `NEPA_Stage_Gate` | RecordBeforeSave | Before-save sync |
| | `NEPA_SLA_Due_Date_Setter` | RecordBeforeSave | Before-save sync |
| | `NEPA_Phase2_Applicability_Setter` | RecordBeforeSave | Before-save sync |
| | `NEPA_Litigation_Risk_Scorer` | RecordAfterSave (async) | After-commit async |
| | `NEPA_CE_Screener` | RecordAfterSave (async) | After-commit async |
| | `NEPA_CE_Determination_Router` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Timeline_Risk_Assessor` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Challenge_Predictor` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Close_Administrative_Record` | RecordAfterSave (async) | After-commit async |
| **ContentVersion (5)** | | | |
| | `NEPA_FRA_Page_Limit_Setter` | RecordBeforeSave | Before-save sync |
| | `NEPA_Administrative_Record_Checker` | RecordAfterSave (async) | After-commit async |
| | `NEPA_AdminRecord_AutoCreate` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Defensibility_Trigger_ContentVersion` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Record_Completeness_Scorer` | RecordAfterSave (async) | After-commit async |
| **ApplicationTimeline (3)** | | | |
| | `NEPA_Stage_Gate_Doc_Check` | RecordBeforeSave | Before-save sync |
| | `NEPA_Stage_Gate_Orchestrator` | RecordAfterSave (async) | After-commit async |
| | `NEPA_EIS_Section_Draft_Trigger` | RecordAfterSave (async) | After-commit async |
| **PublicComplaint (3)** | | | |
| | `NEPA_Comment_Period_Gate` | RecordBeforeSave | Before-save sync |
| | `NEPA_Comment_AI_Router` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Plaintiff_Intelligence` | RecordAfterSave (async) | After-commit async |
| **Program (3)** | | | |
| | `NEPA_GIS_Proximity_Check` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Team_Assembly_Orchestrator` | RecordAfterSave (async) | After-commit async |
| | `NEPA_Agency_Tier_Setter` | RecordAfterSave (async) | After-commit async |
| **Visit (3)** | | | |
| | `NEPA_Visit_Survey_Window_Setter` | RecordBeforeSave (insert only) | Before-save sync |
| | `NEPA_Visit_Completion_Assessor` | RecordAfterSave (async) | After-commit async |
| | `NepaVisitAfterInsert` → `NepaVisitActionPlanLauncher` | Apex trigger (after insert) | Synchronous after-insert |
| **NEPA_Flow_Error__c (1)** | `NEPA_FlowError_CountIncrementer` | RecordAfterSave (async) | After-commit async |
| **NEPA_Error_Event__e (1)** | `NEPA_Error_Event_Handler` | PlatformEvent | Platform event subscriber |
| **Scheduled (1)** | `NEPA_SLA_Escalation_Monitor` | Scheduled | Daily batch |
| **Invocable (7)** | Defensibility_Gap_Checker, Comment_ResponseTask_Creator, EIS_Section_Assembler, Comment_Duplicate_Check, EJTribal_Router, Comment_Triage_Save, Error_Logger | Invocable subflow | Called by flows or agents |

---

### Simultaneous Multi-Flow Scenario

A single `IndividualApplication` save where `nepa_review_type__c`, `nepa_process_stage__c`, and `nepa_process_status__c` all change simultaneously activates up to **9 flows**:

**Before-save (synchronous, same transaction, sequenced by last-modified date):**
1. `NEPA_Stage_Gate` — validates stage transition, stamps `nepa_last_stage_transition__c`, computes `nepa_target_completion_date__c`
2. `NEPA_SLA_Due_Date_Setter` — computes `nepa_sla_due_date__c` from SLA CMT lookup
3. `NEPA_Phase2_Applicability_Setter` — sets phase 2 eligibility flag

These three run sequentially in the same transaction. Each field written by one before-save flow is visible to subsequently ordered before-save flows on the same record via `$Record`.

**After-save async (separate transactions, potentially parallel):**
4. `NEPA_Litigation_Risk_Scorer`
5. `NEPA_CE_Screener`
6. `NEPA_CE_Determination_Router`
7. `NEPA_Timeline_Risk_Assessor`
8. `NEPA_Challenge_Predictor`
9. `NEPA_Close_Administrative_Record` (if review_type = ROD or FONSI)

The platform does not guarantee sequencing among async flows. They may execute in any order, potentially overlapping.

---

### Recursion Prevention — Node-Level Trace

**`NEPA_Stage_Gate` (before-save)** writes `nepa_last_stage_transition__c` and `nepa_target_completion_date__c`. Its entry filter watches `nepa_process_stage__c`, `nepa_review_type__c`, `nepa_process_status__c` with `OR` logic. Writing `nepa_last_stage_transition__c` does **not** re-trigger Stage_Gate. **No loop.**

**`NEPA_Litigation_Risk_Scorer` (async)** writes `nepa_risk_score__c` and `nepa_risk_tier__c`. Its entry condition watches agency, review_type, acreage, statute flag fields — not the score output fields. Writing the score does **not** re-trigger the scorer. **No loop.**

**`NEPA_CE_Screener` (async)** writes `nepa_ce_pathway_recommendation__c` and `nepa_screening_confidence__c`. `NEPA_CE_Determination_Router` fires when those two fields change (`IsChanged = true` filter on each). `CE_Determination_Router` writes to `ApplicationTimeline` (inserts a CE Determination event record) and `Task` — it does **not** write back to any `IndividualApplication` fields that `CE_Screener` watches. **No loop.** (Confirmed by reviewing `CE_Determination_Router` RecordCreate/RecordUpdate element targets.)

**`NEPA_Visit_Survey_Window_Setter` (before-save, insert only)** reads `NEPA_Layer_Discipline__mdt` (CMT query, governor-exempt) and writes `nepa_hard_gate__c`, `PlannedVisitStartTime`, `PlannedVisitEndTime` to `$Record`. Entry filter limits to insert + `nepa_auto_generated__c = true`. The flow itself causes no DML and does not re-trigger. **No loop.**

**`NEPA_Visit_Completion_Assessor` (async, on Status change to Completed)** queries open hard-gate Visits and updates `nepa_surveys_complete__c` on `IndividualApplication`. Entry condition requires `Status IsChanged = true` AND `nepa_hard_gate__c = true`. The `IndividualApplication` update does not touch any Visit field. **Cross-object, no re-entry.**

**`NepaVisitAfterInsert` (Apex trigger, after insert)** calls `NepaVisitActionPlanLauncher.createActionPlans()` which queries `NEPA_Layer_Discipline__mdt` and inserts `ActionPlan` records targeting the Visit. `ActionPlan` insert does not trigger any Visit flow. **Cross-object, no re-entry.**

**`NEPA_Defensibility_Trigger_ContentVersion` (async on ContentVersion)** calls `NEPA_Defensibility_Gap_Checker` (invocable). That checker writes `nepa_defensibility_score__c` and `nepa_defensibility_gaps__c` on IndividualApplication. If `NEPA_Timeline_Risk_Assessor` watches either of those fields, a chain could form. This interaction should be verified before adding defensibility output fields to Timeline_Risk_Assessor's entry conditions.

---

### `$Record` and `$Record__Prior` Variable Risk

**Before-save flows:** `$Record__Prior` is stable and guaranteed by the platform within the before-save transaction context. Accessing `$Record__Prior.nepa_process_stage__c` in `NEPA_Stage_Gate` is safe.

**After-save async flows:** Each async flow receives a snapshot of `$Record` at the time the async path was scheduled (immediately after commit). If two async flows run near-simultaneously and one writes back to IndividualApplication (e.g., `NEPA_Litigation_Risk_Scorer` writing `nepa_risk_score__c`), the second async flow's `$Record` snapshot may be stale. **Last-write-wins applies.** There is no platform locking for async flow record access.

Practical risk: `NEPA_CE_Screener` and `NEPA_Litigation_Risk_Scorer` both update IndividualApplication fields in async transactions. If they overlap, one update silently overwrites the other's changes. The current field partitioning (scorer writes risk score/tier; CE_Screener writes recommendation/CE_code/confidence) means the fields are non-overlapping — this is safe only because the two flows write to disjoint field sets. Any future change combining those writes into a single flow update would create a race.

---

### Entry Condition Strictness Requirements

The entry filter pattern `fieldValue = X` without `IsChanged = true` re-fires the flow on **every save** that preserves `fieldValue = X` — including unrelated field updates on the same record. For example, a public comment response updating a related IndividualApplication timestamp could re-trigger the entire litigation risk scorer if the scorer's entry condition watches `nepa_review_type__c = 'EIS'` without a change guard.

**Required pattern for all async after-save flows:**
```
filter: fieldA IsChanged = true
filter: fieldA EqualTo [target value]
filterLogic: (1 AND 2)
```

Flows confirmed to use `IsChanged` guards: `NEPA_Close_Administrative_Record` (filter 1: `nepa_review_type__c IsChanged = true`), `NEPA_CE_Determination_Router` (both watched fields use `IsChanged`). Any flow not following this pattern is a re-fire risk on every save.

---

## Item 15: OmniScript & GIS Integration Procedure Trace

> **Backlog — OmniStudio components described in this section are not verified.**
> The OmniScript CE intake, Integration Procedures, and GIS IP trace below document
> the intended architecture. None of these components have been successfully activated
> end-to-end. Do not interpret `isActive = false` as a staged rollout — these components
> have not been verified as production-ready. See [OMNISTUDIO-BACKLOG.md](OMNISTUDIO-BACKLOG.md).

### Design Artifact Status

The CE Intake OmniScript (`NEPA_CEIntake_OmniScript_1`) is present in the repository as a design artifact (7 steps, `isActive = false` — backlog, not a staged rollout). Three Integration Procedures are present as design artifacts: `NEPA_CEScreeningIP` (pre-screening heuristic), `NEPA_CESaveIP` (record persistence), and `NEPA_GISProximityIP` (GIS proximity loop). None have been verified end-to-end.

The GIS Integration Procedure (design artifact) does **not** call five hardcoded agency endpoints. The intended design loops over `NEPA_GIS_Layer__mdt` custom metadata records — each CMT record supplying the endpoint URL, named credential, layer number, buffer miles, and result key field. This is the architecturally correct pattern for endpoint configurability. However, this IP has not been verified end-to-end.

---

### Data Variable Path: OmniScript → DataRaptor → IndividualApplication (Design Artifact)

| Step | Action | Variable Name | Maps To |
|---|---|---|---|
| Step 1 (Project Identity) | User input | `AgencyAbbr` | `nepa_data_source_agency__c` |
| Step 1 | User input | `Name` | `Name` |
| Step 1 | User input | `nepa_description__c`, `nepa_purpose_need__c` | Direct field mapping |
| Step 2 (Action Details) | User input | `nepa_action_type__c`, `nepa_project_sector__c` | Direct field mapping |
| Step 3 (Site Factors) | User input | `nepa_disturbance_acres__c` | Number field |
| Step 3 | User checkbox | `ExtraordinaryCircumstances` | `nepa_extraordinary_circumstances__c` |
| Step 3 (conditional, Military) | User checkbox | `nepa_extraordinary_circumstance_multi_dod__c` | Boolean field; only shown when `nepa_project_sector__c == 'Military'` |
| Step 3 (conditional, Water/Coastal) | User checkbox | `nepa_extraordinary_circumstance_usace_czma__c` | Boolean field; only shown when `nepa_project_sector__c == 'Water/Coastal'` |
| Step 4 (Pre-Screening) | Pre-action IP call | `NEPA_CEScreeningIP` → `ScreeningResult:Recommendation` | Displayed as read-only; not yet persisted |
| Step 6 (Submit) | Post-action IP call | `NEPA_CESaveIP` | Calls `DR_Load_NEPA_Process` → upsert on `nepa_federal_unique_id__c` |
| Step 6 | IP stamps `nepa_start_date__c` | `TODAY()` | Stamped at save time (not at OmniScript open time) |

`NEPA_CESaveIP` sets `failOnStepError: true` — a DataRaptor upsert failure blocks the confirmation step and displays an error in the OmniScript UI. The user cannot reach Step 7 (Confirmation) unless the record saves successfully.

---

### GIS 503 Scenario: One Layer Fails, Others Succeed

`NEPA_GISProximityIP` element `CallGISEndpoint` (step 7 in the IP loop) is configured with:
- `failOnStepError: false`
- `errorPath: GISCalloutError`
- `timeout: 10000ms`
- Success codes: 200

**When a single layer returns a 503:**

1. `CallGISEndpoint` routes to `errorPath: GISCalloutError` (instead of the normal `ParseLayerResponse` path)
2. `HandleCalloutError` (step 12) executes inside the loop: appends `"[LayerLabel] — query failed - check endpoint availability"` to `ProtectionAreasSummary`. Clears `GISCalloutError` to null for the next iteration.
3. `AccumulateLayerRecord` records `nepa_is_hit__c = false`, `nepa_ec_triggered__c = false` for the failed layer (no-hit defaults)
4. Loop continues to the next layer — the 503 does **not** abort the remaining layers
5. `ExtraordinaryCircumstancesFound` can only be set `true` by successfully parsed layers (step 9, `CheckExtraordinaryCircumstances` runs after `ParseLayerResponse`, which only executes on success)
6. `SaveDetectedLayers` (post-loop DataRaptor upsert) persists all accumulated records — four records with real GIS data, one record with no-hit defaults
7. `SaveResultsToProject` updates the Program record with `nepa_gis_proximity_complete__c = true` and the combined `ProtectionAreasSummary` string regardless of partial failure

**Critical gap:** There is no partial-complete state. A partially successful GIS run (4 of 5 layers) sets `nepa_gis_proximity_complete__c = true`, which triggers `NEPA_Team_Assembly_Orchestrator` to proceed with team assembly using only the four successful layer records. The failed layer (e.g., a missing ESA/tribal lands result) contributes no EC flag and no team member assembly for that discipline.

---

### JSON Array Mapping: GIS Responses → Structured Fields

In `ParseLayerResponse` (step 8 of the loop), the GIS feature array is handled as:
- `FeatureCount` = array length of `LayerResponse:features`
- `HasFeatures` = `FeatureCount > 0`
- `FirstFeatureName` = first element of the features array, key field from `CurrentLayer:Result_Key_Field__c`
- For EJScreen layers (`Layer_Number__c == -1`): `EJIndexValue` = `LayerResponse:EJINDEX` (scalar, not array)

The Integration Procedure does not map GIS arrays to repeating structured fields on IndividualApplication. Instead it:
1. Writes one `nepa_detected_protection_layer__c` record per layer (structured object with hit/no-hit, feature name, EC flag, run timestamp)
2. Appends a human-readable summary line per layer to `ProtectionAreasSummary` (written to Program's `nepa_gis_summary__c`)

This is intentional — GIS results are stored as normalized child records, not flattened arrays on the parent.

---

### Null NAICS Input Path

An applicant submitting with `nepa_applicant_naics__c` blank:

1. OmniScript Step 3: `nepa_applicant_naics__c` is optional (`required: false`)
2. Step 4 passes `NAICSCode: ''` (empty string) to `NEPA_CEScreeningIP`
3. `NEPA_CEScreeningIP` passes `NAICSCode` to the BRE expression set `NEPA_CE_Screener`
4. `NEPA_CE_Screener_NAICS` decision matrix lookup with empty `NAICSCode` input returns empty-string output columns
5. BRE consolidation step: `IF(LEN(NAICS__ReviewType) > 0, ...)` evaluates `LEN('') > 0 = false` → falls through to Tier1 lookup
6. Tier1 and Tier2 lookups proceed normally using `AgencyAbbr`, `SectorKey`, `ActionType`

**No breakage.** Null or empty NAICS is fully handled by the `LEN() > 0` guard pattern used throughout the BRE consolidation logic. The screener degrades gracefully to the agency/sector/action-type matching path.

---

## Item 16: CE Screener Business Rules Engine Matrix Review

### Implementation Status

The CE Screener BRE is implemented as `NEPA_CE_Screener` Expression Set version V3 (activated 2026-05-08). It is Active and invoked by a record-triggered flow after `IndividualApplication` save. It is **not** a Decision Matrix — it is an Expression Set that calls three Decision Matrices as sub-lookups and consolidates their outputs.

---

### Input Variables Entering the BRE

| Variable | Type | Source |
|---|---|---|
| `AgencyAbbr` | Text | `nepa_data_source_agency__c` |
| `ActionType` | Text | `nepa_action_type__c` |
| `NAICSCode` | Text | `nepa_applicant_naics__c` (optional) |
| `SectorKey` | Text | `nepa_project_sector__c` |
| `TypeKey` | Text | Derived project type key |
| `DisturbanceAcres` | Numeric | `nepa_disturbance_acres__c` (default: 0) |
| `ExtraordinaryCircumstances` | Text/Boolean | `nepa_extraordinary_circumstances__c` |

---

### Three-Tier Decision Structure

The BRE evaluates all three Decision Matrices in parallel, then applies a **waterfall priority chain** (not AND/OR logic) to consolidate outputs:

```
ReviewType = IF( LEN(NAICS__ReviewType) > 0, NAICS__ReviewType,
                IF( LEN(Tier1__ReviewType) > 0, Tier1__ReviewType,
                    IF( LEN(Tier2__ReviewType) > 0, Tier2__ReviewType, 'EA' )))
```

A NAICS match fully overrides Tier1 and Tier2 results. Priority order: NAICS > Tier1 (Agency + Sector + TypeKey) > Tier2 (Agency + ActionType).

After consolidation, a fifth BRE step applies the acreage override:
```
IF( ReviewType == 'CE' AND DisturbanceAcres > 250, 'EA', ReviewType )
```
The 250-acre threshold is a hardcoded constant in the formula (`CONST_AcreageThreshold = 250`).

---

### Extraordinary Circumstances Evaluation: AND/OR Gate

**The BRE does not evaluate EC as an AND/OR gate.** `ExtraordinaryCircumstances` is received as a passive input variable. Individual Decision Matrix rows may reference EC as an input column condition, but the Expression Set itself contains no consolidation step that says "IF ExtraordinaryCircumstances = true THEN escalate to EA."

EC determination actually occurs in two separate, independent paths:
1. **OmniScript Step 3:** User self-reports EC via checkbox. This value is passed to the BRE as an input but is not acted on by any BRE formula step. The OmniScript shows an advisory notice when checked but does not modify the classification output.
2. **GIS Integration Procedure:** `CheckExtraordinaryCircumstances` step (in the GIS loop) independently sets `ExtraordinaryCircumstancesFound = true` based on layer keyword matching. This sets a field on the Program record, separate from the BRE pathway.

There is no gate in the BRE that triggers on EC = true. A project with `ExtraordinaryCircumstances = true`, DisturbanceAcres ≤ 250, and a matching CE code in a Decision Matrix will receive a **CE recommendation** from the BRE.

---

### Zero-Match Outcome (Action Type Maps to No CE Codes)

When all three Decision Matrices return empty-string outputs for a given input combination:

| Output Field | Value Written | Mechanism |
|---|---|---|
| `ReviewType` | `'EA'` | Hardcoded fallback in the `IF(LEN(...) > 0, ...)` chain |
| `CECode` | `''` (empty) | `IF(ReviewType == 'CE', CECode, '')` step clears it |
| `Confidence` | `'Low'` | Fallback in consolidation chain |
| `ClassificationBasis` | `'No screening rule matched; defaulted to EA for manual review'` | Fallback string |

These values are written to `nepa_ce_pathway_recommendation__c = 'EA'`, `nepa_ce_code__c = ''`, `nepa_screening_confidence__c = 'Low'`, `nepa_classification_basis__c = 'No screening rule matched...'`.

**The process does not halt.** `NEPA_CE_Determination_Router` flow fires when `nepa_ce_pathway_recommendation__c` changes, reads the `'EA'` recommendation, creates an `ApplicationTimeline` event of type `'CE Determination'` with status `'Pending'`, and creates a `Task` for the NEPA coordinator to initiate a full NEPA review. The process routes to the EA track automatically.

---

### Logical Dead-Ends and Gaps

| # | Gap | Location | Severity | Mitigation |
|---|---|---|---|---|
| G1 | **EC bypass** — EC = true does not auto-escalate CE to EA | `NEPA_CE_Screener` expression set, post-consolidation step | **High** | Add a BRE step after acreage override: `IF(ExtraordinaryCircumstances = true AND ReviewType = 'CE', 'EA', ReviewType)` with `Confidence = 'High'` and `ClassificationBasis = 'EC override — categorical exclusion does not apply when extraordinary circumstances are present (40 CFR 1508.1(d))'` |
| G2 | **No EIS output path** — BRE maximum output is EA | All three decision matrices; consolidation step | Low (intentional) | Document explicitly: EIS determination is a coordinator judgment, not an automated classification. The screener's purpose is CE eligibility screening, not EIS triggering. Add language to the OmniScript Step 4 display: "EIS-track projects must be escalated by your NEPA coordinator." |
| G3 | **250-acre threshold not CMT-configurable** — agency-specific thresholds require BRE formula change + version activation | `CONST_AcreageThreshold = 250` in `NEPA_CE_Screener_V3` | Medium | Move threshold to `NEPA_CE_Screening_Rule__mdt` per-agency record as `Acreage_Threshold__c` field (already exists on the CMT). Look up the agency's threshold from the CMT at BRE evaluation time instead of using a hardcoded constant. |
| G4 | **Stale version silent continuation** — if V4 is published but not activated, V3 runs without notification | Expression Set version management | Low | Add a scheduled flow or CMT record tracking "last BRE activation date"; send a notification Task to the NEPA system admin when a new version exists but is not activated |
| G5 | **GIS EC and BRE EC are decoupled** — BRE uses user-reported EC checkbox; GIS uses keyword detection; neither gates the other | OmniScript Step 3, GIS IP `CheckExtraordinaryCircumstances`, BRE input variable | Medium | Wire `nepa_extraordinary_circumstances__c` on IndividualApplication to be set by **either** the user checkbox OR the GIS EC flag (via a before-save flow OR formula field: `nepa_extraordinary_circumstances__c OR nepa_gis_ec_detected__c`). Ensure the BRE reads the unified field, not only the user-reported checkbox. |
