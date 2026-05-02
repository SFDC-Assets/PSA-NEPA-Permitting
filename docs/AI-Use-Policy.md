# PSA-NEPA Permitting Accelerator — AI Use Policy

**Version:** 1.0  
**Date:** 2026-05-02  
**Status:** Active  
**Scope:** All AI-assisted features in the PSA-NEPA-Permitting-Data-Model Salesforce package

---

## 1. Purpose

This document describes which features use AI, the training data they rely on, known statistical limitations, and the human confirmation requirements that must be satisfied before any AI output is treated as an official agency determination. It is required reading for NEPA Coordinators, Solicitor staff, and system administrators.

Compliance baseline: Salesforce Acceptable Use Policy for Einstein and Generative AI features; OMB M-24-10 (Federal AI Governance); 40 CFR Part 1500 (NEPA regulations).

---

## 2. AI-Assisted Features

### 2.1 CE Pathway Screening (`NEPA_CE_Screener` Flow)

| Attribute | Value |
|---|---|
| Feature | Categorical Exclusion eligibility screening |
| AI type | Rules-based classifier (custom metadata-driven decision tree) |
| Output field | `nepa_ce_pathway_recommendation__c` (recommendation only) |
| Official field | `nepa_review_type__c` (set by coordinator after review) |
| Training source | NEPATEC v2.0 feature engineering analysis (1,489 NEPA records, BLM/DOE/USDA); `2_ce_decision_tree.json` |

**Human confirmation requirement:** The CE Screener writes a recommendation to `nepa_ce_pathway_recommendation__c`. This field is **read-only to AI** and **readable by all users** but does not constitute an official NEPA determination. A credentialed NEPA Coordinator must review the recommendation and the `nepa_classification_basis__c` audit trail, then manually set `nepa_review_type__c` to make the pathway official. The system will not advance a record to downstream stage gates on the recommendation field alone.

**What coordinators should review:**
- `nepa_screening_confidence__c` — Low confidence flags ambiguous cases requiring SME judgment
- `nepa_classification_basis__c` — full rule-match audit trail
- `nepa_extraordinary_circumstances__c` — any GIS flags that disqualified CE
- `nepa_disturbance_acres__c` — acreage threshold checks

### 2.2 Litigation Risk Scoring (`NEPA_Litigation_Risk_Scorer` Flow)

| Attribute | Value |
|---|---|
| Feature | Composite litigation risk score (0–100) and tier |
| AI type | Weighted scoring model (custom metadata-driven) |
| Output fields | `nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_risk_score_factors__c` |
| Disclosure field | `nepa_risk_score_is_ai__c` (always true — formula field) |
| Training source | PermitTEC v0.1 (PNNL, 2025): 761 federal NEPA litigation cases, 1970–2025 |

**Human confirmation requirement:** The risk score is an analytical tool to direct legal review attention — it is not a legal determination and does not automatically block or approve any action. Very High tier scores (75–100) trigger a Task assigned to the NEPA Solicitor/Legal team for a "Legal Defensibility Deep-Dive." That review is the human gate; the score is the signal.

**Known statistical limitations (required disclosure):**

| Limitation | Detail |
|---|---|
| Small overall sample | PermitTEC v0.1 = 761 cases linked to 223 NEPATEC project records. Circuit-level weights are derived from as few as 1–5 cases per circuit. |
| Circuit loss rates directional only | 9th Circuit (66.7% agency loss) based on n=3 cases in linked sample. DC Circuit (0%) based on n=1. These are directional indicators, not statistically reliable estimates. |
| Recency bias | Cases span 1970–2025 but pre-2010 regulatory environment differs materially from post-CEQ 2022/2024 rules. |
| No outcome prediction | The score reflects litigation *exposure* (case filing likelihood and ground strength), not outcome prediction. Agencies have won Very High-tier cases; scores do not prejudge results. |

The `nepa_risk_score_factors__c` field always contains the disclaimer:  
> `[AI-GENERATED — PermitTEC v0.1, PNNL 2025, 761 cases; circuit weights based on small sample, treat as directional]`

### 2.3 Comment Triage (`NEPA_Comment_Triage` Agentforce Agent)

| Attribute | Value |
|---|---|
| Feature | Sentiment and substantive merit classification of public comments |
| AI type | LLM-based (Agentforce, `sfdc_ai__DefaultAnthropic`) |
| Output fields | `nepa_sentiment__c`, `nepa_is_substantive__c`, `nepa_ai_confidence_score__c`, `nepa_ai_triage_rationale__c` |
| Training source | CEQ NEPA substantive comment definition (40 CFR 1503.3); no corpus training — prompt-based classification |

**Human confirmation requirements (non-negotiable):**

1. **EJ/Tribal gate runs before AI** — comments containing tribal sovereignty, sacred sites, environmental justice, low-income impact, or civil rights keywords are routed directly to the EJ/Tribal Liaison coordinator queue. AI does not classify these comments. This cannot be overridden by AI.
2. **Low confidence escalation** — when `nepa_ai_confidence_score__c < 60`, the agent pauses and presents a confirmation dialog to the analyst before saving.
3. **Human override always available** — `nepa_human_override__c` checkbox allows analysts to correct any AI classification at any time. All overrides are recorded in the administrative record.
4. **AI cannot set `nepa_requires_human_review__c = false`** on an EJ-escalated comment.

**Audit trail:** All triage fields, rationale, confidence scores, and override flags are written to the PublicComplaint record and included in the CEQ DataRaptor extract (`DR_Extract_NEPA_Comment`) as part of the litigation-reviewable administrative record.

---

## 3. Data Provenance

| Dataset | Source | Version | Record Count | Coverage |
|---|---|---|---|---|
| PermitTEC | Pacific Northwest National Laboratory (PNNL) | v0.1, 2025 | 761 litigation cases | 1970–2025, federal NEPA challenges |
| NEPATEC | Federal NEPA process registry | v2.0 | 61,881 project records | Multi-agency, multi-decade |
| CE Decision Tree | Analysis of NEPATEC BLM/DOE/USDA CE records | 2026-04 | 1,489 classified records | BLM, DOE, USDA Forest Service |
| Permit Matrix | Analysis of NEPATEC sector/agency routing patterns | 2026-04 | 30+ sector-agency combinations | Multi-agency |

---

## 4. Prohibited Uses

The following uses of AI features in this package are prohibited under Salesforce AUP and OMB M-24-10:

- Using `nepa_ce_pathway_recommendation__c` as the sole basis for issuing a CE determination memo without coordinator review
- Treating `nepa_risk_score__c` as a legal risk opinion or using it in court filings without independent legal analysis
- Relying on AI comment triage classifications as a substitute for human review of substantive comments that must receive agency responses under 40 CFR 1503.4
- Using AI sentiment classification to deprioritize or suppress comments from any community group
- Allowing AI to set or override `nepa_requires_human_review__c = false` on EJ-escalated comments

---

## 5. Weight Update Procedure

When a new PermitTEC corpus release becomes available:

1. Download updated corpus from PNNL data repository
2. Re-run feature engineering analysis against the new case set
3. Update custom metadata records in the following types:
   - `NEPA_Agency_Risk_Rate__mdt` — update `Risk_Points__c` per agency
   - `NEPA_Circuit_Risk_Weight__mdt` — update `Risk_Points__c` per circuit; update `Low_Data_Confidence__c` flag if sample size < 20
   - `NEPA_Statute_Risk_Weight__mdt` — update if new statutory challenge patterns emerge
4. Document the update in this policy (version number, date, corpus size change)
5. Deploy via `sf project deploy start` following the standard deployment sequence
6. Notify all NEPA Coordinator users of the weight update and updated statistical limitations

---

## 6. Incident Reporting

If an AI feature produces an output that materially affects a permitting decision and is later found to be erroneous:

1. File an incident in the project issue tracker with label `ai-error`
2. Preserve the `nepa_risk_score_factors__c` or `nepa_classification_basis__c` value from the affected record
3. Notify the system administrator and NEPA program office
4. Do not delete or modify the affected record pending investigation

---

## 7. References

- Salesforce Einstein Acceptable Use Policy — salesforce.com/company/legal/
- OMB M-24-10, Advancing Governance, Innovation, and Risk Management for Agency Use of Artificial Intelligence
- 40 CFR Part 1500 (NEPA Regulations)
- PermitTEC v0.1 dataset — PNNL, 2025
- CEQ NEPA and Permitting Data and Technology Standard v1.2 (May 30 / August 18, 2025)
