# NEPA Flow Architecture

30 flows total. This document explains the three non-obvious structural patterns — why the error handling, stage gate, and defensibility scoring are split the way they are.

---

## 1. Error Chain

```
Any flow (fault path)
  └─► NEPA_Error_Logger          (autolaunched subflow — called from fault connector)
        └─► NEPA_Error_Event__e  (platform event — Create Records)
              └─► NEPA_Error_Event_Handler    (platform-event-triggered flow)
                    └─► NEPA_Flow_Error__c    (Create Records)
                          └─► NEPA_FlowError_CountIncrementer  (before-save on NEPA_Flow_Error__c)
```

**Why platform events, not direct DML:** A fault path fires inside a transaction that has already rolled back. Any `Create Records` targeting a custom object in that same transaction would also roll back, losing the error record. A platform event is published outside the current transaction boundary, so the event and the resulting `NEPA_Flow_Error__c` record survive even when the originating flow transaction fails.

**How to add error handling to a new flow:** Add a fault connector from any data-changing element to a Subflow element calling `NEPA_Error_Logger`. Pass `{!$Flow.FaultMessage}` as the error message input. Do not wire the fault path back to the main flow — it is terminal.

---

## 2. Stage Gate Split

Two flows govern stage transitions on `IndividualApplication`, but they operate on different objects in different transaction phases:

| Flow | Trigger object | Phase | Responsibility |
|---|---|---|---|
| `NEPA_Stage_Gate` | `IndividualApplication` | Before-save | Blocks invalid stage transitions; enforces document gate via `NEPA_Stage_Gate_Doc_Check` |
| `NEPA_Stage_Gate_Orchestrator` | `ApplicationTimeline` | After-save (async) | Advances the process stage when a timeline event is completed |

**Why two flows instead of one:** Before-save fires before the record is written — the right place to block an invalid transition. After-save fires after the `ApplicationTimeline` completion event is committed — the right place to then progress the parent `IndividualApplication`. Combining both in one flow would require an after-save trigger on `IndividualApplication` doing a related-record update, which creates a re-entry loop. Splitting by object and phase keeps each flow in its correct governor limit context.

**NEPA_Stage_Gate_Doc_Check** is a third supporting subflow called by `NEPA_Stage_Gate`. It queries `ContentVersion` records linked to the process and returns whether the stage's document requirements are satisfied. Extracting it keeps the gate logic readable and makes the document check independently testable.

---

## 3. Defensibility Wrapper Pattern

```
Record-triggered (ContentVersion insert/update)
  └─► NEPA_Defensibility_Trigger_ContentVersion
        └─► NEPA_Defensibility_Gap_Checker  (subflow — scoring engine)

Record-triggered (nepa_engagement__c insert)
  └─► NEPA_Defensibility_Trigger_Engagement
        └─► NEPA_Defensibility_Gap_Checker  (same subflow)
```

**Why two thin wrappers and one engine:** The scoring logic (document coverage, engagement coverage, gap detection) is identical regardless of what triggered the recalculation. Duplicating it in each trigger flow would mean maintaining two copies. The wrappers exist only to: (1) detect the triggering event type, (2) resolve the parent `IndividualApplication` ID from either a `ContentDocumentLink` or `nepa_process__c` lookup, and (3) call the shared subflow.

**NEPA_Defensibility_Gap_Checker** itself is an autolaunched subflow. It takes `inp_ProcessId` as input, queries all linked documents and engagements in bulk (no Get Records in loops), computes `nepa_defensibility_score__c` (0–100), populates `nepa_defensibility_gaps__c` with a human-readable gap list, and writes both fields back to the `IndividualApplication` via a single Update Records element.

---

## Full Flow Inventory

| Flow | Type | Trigger / Entry |
|---|---|---|
| NEPA_Administrative_Record_Checker | Autolaunched subflow | Called from Stage Gate |
| NEPA_AdminRecord_AutoCreate | After-save | ContentVersion insert |
| NEPA_CE_Determination_Router | After-save | IndividualApplication (CE pathway) |
| NEPA_CE_Intake | Before-save | IndividualApplication insert (CE) |
| NEPA_CE_Screener | After-save | IndividualApplication (CE, on update) |
| NEPA_Challenge_Predictor | After-save | nepa_litigation__c insert/update |
| NEPA_Comment_Period_Gate | Before-save | IndividualApplication update |
| NEPA_Comment_Triage_Save | Autolaunched | Invoked from Apex / Agent |
| NEPA_Defensibility_Gap_Checker | Autolaunched subflow | Called from trigger wrappers |
| NEPA_Defensibility_Trigger_ContentVersion | After-save | ContentVersion insert/update |
| NEPA_Defensibility_Trigger_Engagement | After-save | nepa_engagement__c insert |
| NEPA_EIS_Section_Assembler | Autolaunched | Invoked from Agent |
| NEPA_EIS_Section_Draft_Trigger | After-save | ContentVersion insert (EIS) |
| NEPA_Error_Event_Handler | Platform-event triggered | NEPA_Error_Event__e |
| NEPA_Error_Logger | Autolaunched subflow | Called from fault connectors |
| NEPA_FlowError_CountIncrementer | Before-save | NEPA_Flow_Error__c insert |
| NEPA_FRA_Page_Limit_Setter | Before-save | ContentVersion insert (Final EA/EIS) |
| NEPA_GIS_Proximity_Check | Autolaunched subflow | Called from CE Screener |
| NEPA_Litigation_Risk_Scorer | Autolaunched | Invoked from BRE / Agent |
| NEPA_Permit_Coordinator | Autolaunched | Invoked from Agent |
| NEPA_Plaintiff_Intelligence | After-save | nepa_litigation__c insert/update |
| NEPA_Record_Completeness_Scorer | After-save | IndividualApplication update |
| NEPA_SLA_Due_Date_Setter | Before-save | ApplicationTimeline insert |
| NEPA_SLA_Escalation_Monitor | Scheduled | Daily on overdue ApplicationTimeline |
| NEPA_Stage_Gate | Before-save | IndividualApplication update |
| NEPA_Stage_Gate_Doc_Check | Autolaunched subflow | Called from Stage Gate |
| NEPA_Stage_Gate_Orchestrator | After-save | ApplicationTimeline (Completed) |
| NEPA_Team_Assembly_Orchestrator | After-save | IndividualApplication insert |
| NEPA_Timeline_Risk_Assessor | After-save | IndividualApplication update (stage change) |
| NEPA_WO_Milestone_Setter | Before-save | ApplicationTimeline insert/update |
