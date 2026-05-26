# NEPA Public Comment Processing

Design reference for the full lifecycle of public comments in the PSA-NEPA accelerator — from portal submission through intake gating, AI triage, human escalation, and audit trail.

---

## Overview

Public comments are stored as **PublicComplaint** records and flow through four coordinated layers:

1. **Intake Gating** — time-enforced deadline control before any record is persisted
2. **EJ/Tribal Sovereignty Gate** — deterministic keyword scan, runs before AI
3. **AI Triage** — sentiment and substantive merit evaluated as independent dimensions
4. **Audit and Override** — complete forensic trail; human override always available

OMB M-24-10 compliance is enforced throughout: AI acts as recommender only, mandatory human escalation is non-negotiable for EJ and tribal sovereignty topics, and every classification decision is recorded on the record.

---

## Data Model

### PublicComplaint (Entity 4: Comments)

| Field | Type | Written By | Purpose |
|---|---|---|---|
| `nepa_comment_body__c` | LongTextArea | Portal submitter | Full comment text |
| `nepa_email__c` | Email | Portal submitter | Submitter contact |
| `nepa_related_process__c` | Lookup → IndividualApplication | Portal OmniScript (backlog) / staff entry | Links comment to NEPA process; required for intake gating |
| `nepa_date_submitted__c` | DateTime | Portal OmniScript (backlog) / staff entry | Submission timestamp |
| `nepa_sentiment__c` | Picklist | AI Triage Agent | Supportive / Neutral / Opposed / Mixed |
| `nepa_is_substantive__c` | Checkbox | AI Triage Agent | True when comment meets NEPA substantive criteria |
| `nepa_cluster_id__c` | Text | AI Triage Agent | Near-duplicate grouping hint |
| `nepa_response_status__c` | Picklist | Agent / human | Pending / In Progress / Responded |
| `nepa_ai_confidence_score__c` | Number | AI Triage Agent | 0–100; below 60 triggers human review prompt |
| `nepa_ai_triage_rationale__c` | LongTextArea | AI Triage Agent | Required when `is_substantive = false`; audit record |
| `nepa_requires_human_review__c` | Checkbox | EJ Gate / Agent | Set true for EJ/tribal triggers or low confidence |
| `nepa_human_override__c` | Checkbox | Human analyst | Signals that AI classification was overridden |
| `nepa_ai_triage_timestamp__c` | DateTime | Agent | When triage was performed |

### IndividualApplication — Comment Period Fields

| Field | Type | Purpose |
|---|---|---|
| `nepa_public_comment_period_start__c` | DateTime | Period open datetime |
| `nepa_public_comment_period_end_date__c` | DateTime | Hard deadline; drives gating |
| `nepa_portal_comment_intake_open__c` | Formula Checkbox | `NOW() >= start AND NOW() < end`; portal visibility gating |

---

## Layer 1: Intake Gating

Two enforcement mechanisms work in tandem. Both are fail-open on missing configuration so that admin/batch records are never incorrectly blocked.

### 1a. Portal Visibility Formula — `nepa_portal_comment_intake_open__c`

```
AND(
  NOT(ISBLANK(nepa_public_comment_period_start__c)),
  NOT(ISBLANK(nepa_public_comment_period_end_date__c)),
  NOW() >= nepa_public_comment_period_start__c,
  NOW() < nepa_public_comment_period_end_date__c
)
```

- Recalculates on every page load — no async lag, no admin toggle
- Experience Cloud portal reads this field to show/hide the submission form
- Does not prevent API inserts (server-side enforcement below)

### 1b. Before-Save Flow — `NEPA_Comment_Period_Gate`

Runs on every `PublicComplaint` **Create** before the record is committed. Decision chain:

```
Has nepa_related_process__c?
  → NO  → allow (non-portal comments, admin records)
  → YES → Get IndividualApplication
            → IA not found?  → allow (deleted/invalid lookup, fail-open)
            → IA found?
                → No end date configured? → allow (agency hasn't set deadline)
                → End date set?
                    → start <= NOW() AND end > NOW()  → allow
                    → otherwise                        → customError (block insert)
```

The `customError` element throws an `addError`-equivalent message surfaced in Experience Cloud and returned as an API error body:

> "The public comment period for this NEPA review has closed. No further comments can be accepted. If you believe this is in error, contact the lead agency directly."

### 1c. Validation Rule — `NEPA_Comment_Period_Closed`

Belt-and-suspenders for direct API inserts that bypass the before-save flow path (bulk API, data loader, integration middleware):

```
AND(
  NOT(ISBLANK(nepa_related_process__c)),
  NOT(ISBLANK(nepa_related_process__r.nepa_public_comment_period_end_date__c)),
  nepa_related_process__r.nepa_public_comment_period_end_date__c < NOW()
)
```

Same fail-open semantics: fires only when lookup and end date are both present and deadline has passed.

### Race Condition Coverage

The three-layer approach handles the "load at 11:55 PM, submit at 12:01 AM" scenario:

| Channel | Formula | Before-Save Flow | Validation Rule |
|---|---|---|---|
| Portal form | Hides form (prevents load) | Blocks insert if submitted anyway | Backstop |
| OmniScript direct (backlog) | Read formula client-side | Blocks at DB layer | Backstop |
| REST API | N/A | Blocks at DB layer | Backstop |
| Bulk/Data Loader | N/A | N/A | Blocks at DB layer |

---

## Layer 2: EJ/Tribal Sovereignty Gate

**`NepaCommentEJDetector`** — Apex invocable class, called as `apex://NepaCommentEJDetector` by the agent.

This gate is **deterministic** — no LLM is involved. It runs before any AI call regardless of comment content.

### Trigger Categories and Keywords

| Category | Sample Keywords |
|---|---|
| Tribal Sovereignty | tribe, tribal, sovereignty, treaty rights, indigenous, first nation, native american, pueblo, navajo, cherokee, lakota, sioux, federally recognized |
| Sacred Sites | sacred site, sacred ground, ancestral land, burial ground, ceremonial site, culturally significant |
| Environmental Justice | environmental justice, ej community, overburdened community, cumulative impact, disproportionate impact, fence line community, sacrifice zone |
| Low-Income Impact | low income, low-income, poverty, affordable housing, public housing, disadvantaged community, title vi, communities of color |
| Civil Rights | civil rights, equal protection, disparate impact, discrimination, 14th amendment, fair housing, environmental racism |

Matching is case-insensitive. One match in any category is sufficient to set `requiresHumanReview = true`.

### Gate Outcomes

- **Trigger matched** → `requiresHumanReview = true`, `detectedTriggers` list populated, no AI classification performed
- **No triggers** → proceed to AI triage

When escalated, the agent writes the trigger details as the `nepa_ai_triage_rationale__c` and sets `nepa_requires_human_review__c = true` with zero AI confidence score. The comment goes to the EJ/Tribal Liaison coordinator queue without any AI sentiment or substantive label.

---

## Layer 3: AI Triage

For comments that clear the EJ gate, the **NEPA_Comment_Triage Agentforce Employee Agent** performs two independent evaluations.

### Prompt Template — `NEPA_Comment_Triage_Analysis`

Model: `sfdc_ai__DefaultAnthropic`  
Inputs: `CommentBody` (required), `ProcessContext` (optional — review type, project, agency)

Returns structured JSON:

```json
{
  "sentiment": "Opposed",
  "is_substantive": true,
  "confidence_score": 85,
  "cluster_hint": "water quality concern",
  "response_status": "Pending",
  "triage_rationale": "Substantive: raises specific water quality claim..."
}
```

### Substantive Definition (OMB M-24-10)

A comment **is** substantive if it contains **any** of:
- Factual observations about environmental conditions (water, air, soil, wildlife, noise)
- Local or traditional ecological knowledge
- Specific community impact concerns (health, safety, property, livelihoods)
- Proposed alternatives or mitigation measures
- Claims of flawed analysis or missing information
- Economic concerns tied to environmental impacts

A comment is **not** substantive **only** if it contains solely general support/opposition with no environmental basis, is entirely off-topic, or is a duplicate form letter.

**Grammar, spelling, emotional language, and writing quality are irrelevant to the substantive determination.**

### Sentiment vs. Substance — Independent Dimensions

These are evaluated separately. Tone does not influence merit:

| Comment | Sentiment | Substantive |
|---|---|---|
| "I hate this pipeline, it's going to ruin the water table on my farm" | Opposed | TRUE |
| "This project will be a wonderful addition to our community!" | Supportive | FALSE |
| "The noise levels during blasting will exceed OSHA limits and affect the school 0.3 miles away" | Neutral | TRUE |

### JSON Parser — `NepaCommentTriageParser`

Apex invocable called as `apex://NepaCommentTriageParser`. Converts the raw JSON string into typed fields for deterministic downstream use. Handles:
- Markdown code fences (` ```json ` / ` ``` `) — stripped before parse
- Unknown sentiment values — defaulted to `Neutral`
- Missing optional fields — defaulted to empty/false/zero
- Malformed JSON — returns `parseSuccess = false` with error message

### Low Confidence Handling

When `confidence_score < 60`, the agent pauses and presents the tentative classification to the analyst with three options:

1. Accept as-is and save
2. Override sentiment and/or substantive determination
3. Flag for mandatory human review

The analyst's response determines whether the record is saved with the AI classification or routed to human review.

---

## Layer 4: Save and Audit Trail

**`NEPA_Comment_Triage_Save`** — AutoLaunched Flow, called as `flow://NEPA_Comment_Triage_Save` from both the EJ escalation path and the AI triage path.

Write sequence:
1. Guard: `inp_CommentId` is not blank → if missing, return `out_Success = false`
2. Get Records: load `PublicComplaint` by Id with fault path
3. Guard: record found → if missing, return `out_Success = false`
4. Assignment: set all triage fields on the sObject variable
5. Update Records: write back with fault path
6. Return `out_Success = true`

Fields written on every save:

| Field | EJ Escalation Path | AI Triage Path |
|---|---|---|
| `nepa_sentiment__c` | empty | AI value |
| `nepa_is_substantive__c` | false | AI value |
| `nepa_cluster_id__c` | empty | AI value |
| `nepa_ai_confidence_score__c` | 0 | AI value |
| `nepa_ai_triage_rationale__c` | EJ trigger details | AI rationale |
| `nepa_requires_human_review__c` | true | false (or true if low confidence + analyst chose escalation) |
| `nepa_response_status__c` | Pending | Pending |

---

## Agent Flow Diagram

```
Portal/OmniScript submit (OmniScript path: backlog — see OMNISTUDIO-BACKLOG.md)
         │
         ▼
┌─────────────────────────────────────┐
│  NEPA_Comment_Period_Gate (Flow)     │  before-save
│  + nepa_portal_comment_intake_open__c│  formula (portal visibility)
│  + NEPA_Comment_Period_Closed (VR)   │  belt-and-suspenders
└────────────────┬────────────────────┘
                 │ insert allowed
                 ▼
         PublicComplaint created
                 │
                 ▼ (analyst opens in agent)
┌─────────────────────────────────────┐
│  NEPA_Comment_Triage Agent          │
│  start_agent entry                  │
│  → collect comment_id + body        │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│  topic: ej_gate                     │
│  NepaCommentEJDetector (Apex)        │
│  deterministic keyword scan          │
└──────┬──────────────────────────────┘
       │                   │
  EJ trigger          No trigger
       │                   │
       ▼                   ▼
┌──────────────┐   ┌───────────────────┐
│ topic:       │   │  topic: ai_triage  │
│ ej_escalation│   │  NEPA_Comment_     │
│              │   │  Triage_Analysis   │
│ Save:        │   │  prompt template   │
│  requires_   │   │  + NepaComment-    │
│  human=true  │   │  TriageParser      │
│  no AI labels│   └──────┬────────────┘
└──────┬───────┘          │
       │            confidence < 60?
       │               ┌──┴──┐
       │              YES    NO
       │               │     │
       │               ▼     ▼
       │       ┌──────────────────┐
       │       │ topic:           │
       │       │ low_confidence_  │
       │       │ review           │
       │       │ analyst confirm/ │
       │       │ override/escalate│
       │       └──────┬───────────┘
       │              │
       └──────────────┤
                      ▼
              ┌───────────────┐
              │ topic:        │
              │ save_triage   │
              │ NEPA_Comment_ │
              │ Triage_Save   │
              │ (Flow)        │
              └───────┬───────┘
                      │
                      ▼
              ┌───────────────┐
              │ topic:        │
              │ triage_summary│
              │ show result;  │
              │ offer override│
              └───────────────┘
```

---

## Compliance Notes

**OMB M-24-10 (Federal AI Governance)**
- EJ gate is deterministic and runs before any AI call — AI cannot override the mandatory escalation
- Every classification is recorded in `nepa_ai_triage_rationale__c` with confidence score
- `nepa_requires_human_review__c` is immutable via AI on escalated records
- `nepa_human_override__c` checkbox provides auditable record of any analyst correction
- Non-substantive determinations require a written rationale explaining which NEPA criteria were not met

**Federal EJ Guidelines**
- Tribal sovereignty, sacred sites, low-income impact, and civil rights triggers route to the EJ/Tribal Liaison coordinator queue, not to AI classification
- No sentiment label is applied to EJ-escalated comments

**APA / Administrative Record**
- All triage fields are written to the PublicComplaint record and included in the CEQ export via `NepaCeqExportService` (verified); `DR_Extract_NEPA_Comment` DataRaptor is a backlog design artifact
- The full comment body, triage rationale, confidence score, and human override flag are part of the administrative record available for litigation review

---

## Deployment Dependencies

Deploy in this order to avoid reference errors:

1. `PublicComplaint.object` — `nepa_related_process__c`, AI triage fields
2. `IndividualApplication.object` — `nepa_portal_comment_intake_open__c` formula
3. `NepaCommentEJDetector.cls`, `NepaCommentTriageParser.cls`
4. `NEPA_Comment_Triage_Analysis.genAiPromptTemplate`
5. `NEPA_Comment_Triage_Save.flow` (AutoLaunched — activate after deploy)
6. `NEPA_Comment_Period_Gate.flow` (before-save — activate after deploy)
7. `NEPA_Comment_Triage.agent` (requires flows and Apex to be active)
8. Assign `NEPA_Permitting` permission set to agent user and analysts
