# NEPA Permitting Acceleration Plan
## Beyond Compliance: Using Salesforce Public Sector Solutions to Expedite Permit Decisions

**Version:** 1.1  
**Date:** April 29, 2026  
**Baseline:** PSA-NEPA-Permitting-Data-Model v1.1 (CEQ Standard v1.2 compliant)

**Decision Matrix Data Files** (in `docs/data/`):

| File | Description | Rows |
|---|---|---|
| [`ce_matrix_tier1_high_confidence.csv`](data/ce_matrix_tier1_high_confidence.csv) | Agency + sector + project type combinations with ≥80% dominant CE code — high-confidence Expression Set rules | 22 |
| [`ce_matrix_tier2_ambiguous.csv`](data/ce_matrix_tier2_ambiguous.csv) | Combinations where multiple CE code families coexist — requires `nepa_action_type__c` to resolve | 530 |
| [`ce_code_catalog.csv`](data/ce_code_catalog.csv) | Full CE code catalog: normalized code, CFR authority, plain-language description, acreage threshold, indoor flag, GIS review flag | 292 |
| [`naics_ce_routing.csv`](data/naics_ce_routing.csv) | NAICS code → likely agency + CE namespace routing table; confidence modifier and action-type notes | 20 |

These files are derived from the complete NEPATEC v2.0 corpus (54,668 CE projects, 73,521 documents across BLM, DOE, USDA, and DOD). They are intended as the seed data for the `nepa_ce_code__mdt` custom metadata type and the Business Rules Engine Expression Sets in Priority 2.

---

## Background & Framing

The CEQ EIS Timeline Report (January 2025) documents a median EIS completion time of **2.8 years** (2019–2024), with the distribution heavily right-skewed — some processes taking 13+ years. Environmental Assessments typically run 6–18 months. Categorical Exclusions, when correctly applied, resolve in days to weeks.

The NAEP 2025 Workshop at PNNL documented three AI case studies with measured results:

| Tool | Task | Manual Effort | With AI |
|---|---|---|---|
| AI Scope Assist (INL) | CE documentation drafting | Weeks per document | ~1 week total including development |
| Jacobs AI-Engage | Comment analysis & response | 4 people × 4 weeks | ~4 hours (2,600 comments) |
| Paces | EA/EIS report section generation | 2–12 weeks | 2–20 minutes (initial draft) |

These are not theoretical gains. The CEQ Permitting Technology Action Plan (May 2025) mandates 10 Minimum Functional Requirements (MFRs) precisely because technology has proven it can compress the NEPA timeline — but only when implemented with deliberate process design, not just data model compliance.

This plan prioritizes features by their estimated impact on **time to permit decision** — moving from features that can eliminate entire process phases (months to years saved) to features that optimize within phases (days to weeks saved).

---

## Priority Framework

Features are ranked on three axes:

- **Phase eliminated or compressed** — Does this feature remove a required step, shorten a critical-path phase, or prevent re-work?
- **Frequency of impact** — CE projects (54,668 in NEPATEC2.0) vs. EA (3,083) vs. EIS (4,130); high-frequency wins at lower impact still aggregate well.
- **PSS implementation feasibility** — Uses commercially available PSS capabilities without requiring custom-built ML infrastructure.

---

## Feature Implementations, Ranked by Time-to-Permit Impact

---

### PRIORITY 1: AI-Assisted Public Comment Analysis
**Time Reduction Estimate: 4–8 weeks per EA/EIS on critical path**

**Why this ranks first:** Public comment compilation and response is directly on the critical path for every EA and EIS. The Jacobs case study showed a 99% reduction in analyst effort (4 people × 4 weeks compressed to ~4 hours for 2,600 comments). Most EA/EIS processes receive hundreds to thousands of comments; federal agencies are legally required to address substantive comments individually. This is not an optional phase that can be parallelized — it blocks the final document.

**PSS Capability:** Agentforce AI Agents + Einstein NLP + existing `PublicComplaint` object

**Implementation Approach:**

1. **Comment Intake via Experience Cloud** — OmniScript-driven public comment submission form captures structured metadata (commenter, organization, topic area, specific section referenced) at submission time rather than requiring manual coding later.

2. **Agentforce Comment Triage Agent** — An Agentforce agent autonomously:
   - Classifies each `PublicComplaint` record into topic categories using the existing `nepa_category__c` field (predefined: Air Quality, Water Resources, Wildlife, Cultural Resources, Socioeconomics, Alternatives, Cumulative Impacts, Procedural, Duplicate/Form Letter)
   - Assigns sentiment (Supportive / Neutral / Opposed / Mixed)
   - Flags substantive vs. non-substantive comments (determines which require individual responses)
   - Groups near-duplicate form letters and quantifies them as a single response cluster
   - Populates `nepa_agency_response__c` with a draft response leveraging prior response language from the knowledge base

3. **Comment Response FlexCard** — Staff review the agent's categorization and draft responses in a single-screen FlexCard showing comment, classification, draft response, and related document section side-by-side. Accepts, edits, or rejects with one click.

4. **Comment Analytics Dashboard** — CRM Analytics dashboard showing comment distribution by topic, sentiment trends, and response completion rate, enabling team leads to prioritize review effort.

**Data Foundations Required:**
- `PublicComplaint.nepa_category__c` — already implemented in v1.1
- `PublicComplaint.nepa_agency_response__c` — already implemented in v1.1
- `PublicComplaint.nepa_parent_document__c` — already implemented in v1.1
- Add: `nepa_sentiment__c` (Picklist: Supportive / Neutral / Opposed / Mixed)
- Add: `nepa_is_substantive__c` (Checkbox, AI-assigned, human-validated)
- Add: `nepa_cluster_id__c` (Text: groups near-duplicate form letters)
- Add: `nepa_response_status__c` (Picklist: Pending / Draft / Reviewed / Finalized)

**Dependencies:** Agentforce license, Experience Cloud for public intake

---

### PRIORITY 2: Automated CE Screening & Project Classification
**Time Reduction Estimate: 6 months to 2+ years per project correctly classified as CE (instead of EA or EIS)**

**Why this ranks second:** The gap between CE and EA/EIS is measured in years, not weeks. NEPATEC2.0 contains 54,668 CE projects across BLM, DOE, and USDA. Full analysis of all 73,521 CE documents reveals 4,783 distinct ce_category strings resolving to roughly three authority systems (DOE 10 CFR 1021 Appendix B short codes, BLM 516 DM manual citations, and Energy Policy Act Section 390 statutory authority). The problem is not that agencies lack CE criteria — it is that applicants and project managers either don't know which CE applies, apply the wrong one, or escalate to EA out of excessive caution. Notably, 23% of CE documents in NEPATEC2.0 have no ce_category recorded, concentrated in BLM oil/gas and Agriculture/Rangeland projects — precisely the high-volume categories where ambiguity causes unnecessary EA escalation.

**PSS Capability:** Business Rules Engine (Expression Sets) + OmniScript + OmniProcess

---

#### What the NEPATEC2.0 Data Reveals About Classification Logic

Analysis of 54,668 CE records across BLM, DOE, and USDA produces a decision matrix with three tiers of signal strength:

**Tier 1 — High-confidence mappings (sector + project type → CE code, >80% predictive):**

| Sector(s) | Project Type(s) | CE Code | Count | Authority |
|---|---|---|---|---|
| Miscellaneous / Emerging Tech | Routine Maintenance | B1.3 | 885 | DOE 10 CFR 1021 B1.3: O&M at existing facilities |
| Miscellaneous / Emerging Tech + Water/Waste | Nuclear Tech + R&D + Waste | B3.6 | 883 | DOE: indoor bench-scale research/operations |
| Transportation + Infrastructure | Electricity Transmission + Utilities | B1.3 | 345 | DOE: O&M at existing transmission facilities |
| Materials/Manufacturing + R&D | Manufacturing + R&D | B3.6 | 238 | DOE: indoor bench-scale research |
| Land Development | Public and Recreational Land Use | 516 DM 11.5(E) 19 | 195 | BLM: short-term ROW (≤3 years) |
| Energy + Transportation | Oil & Gas + Pipelines + Utilities | 516 DM 11.9 E9 | 158 | BLM: ROW renewals with no additional rights |
| Agriculture + Nat. Resource Mgmt | Rangeland Management | 516 DM 11.9 D(1) | 134 | BLM: grazing preference transfers |
| Energy Production | Land-based Oil & Gas | Energy Policy Act Sec.390 Cat.3 | 81 | Drilling oil/gas wells |
| Energy + Transportation | Oil & Gas + Pipelines | Energy Policy Act Sec.390(b)(4) | 50 | Pipeline placement in approved ROW |

**Tier 2 — Moderate-confidence mappings (require action-type qualifier):**

The same sector+type combination produces different CE codes depending on the *action verb* — what the applicant is actually doing. The data shows three critical discriminating dimensions that sector and project type alone cannot resolve:

1. **Existing vs. new infrastructure** — "Renewing an existing right-of-way" maps to 516 DM 11.9 E9; "constructing a new right-of-way" escalates to EA. An Energy + Pipelines project could be either.
2. **Acreage/disturbance threshold** — Energy Policy Act Sec.390 Exclusion 1 explicitly requires individual surface disturbance < 5 acres. The same project type at 6 acres does not qualify.
3. **Indoor vs. outdoor** — B3.6 applies specifically to "indoor bench-scale research." The same R&D activity conducted outdoors uses different codes or may require EA.

**Tier 3 — Ambiguous mappings (23% of corpus; require GIS + extraordinary circumstances review):**
Projects without a ce_category in NEPATEC2.0 cluster in: conventional oil/gas development on federal lands (BLM jurisdiction), land development and urban planning, and mixed agriculture/rangeland management. These are the highest-risk ambiguity cases for the automated screener.

---

#### Multi-Code Pattern

A significant subset of projects cite multiple CE codes simultaneously (A9 + B3.6, A9 + A11, A9 + A11 + B3.6, etc.). CE codes in DOE practice are additive — a project may qualify under several independent authorities simultaneously. The screener must return a code set, not a single code, and must flag when multiple codes apply as a positive signal (broader authority, lower risk of challenge).

---

#### On Using NAICS Codes

NAICS codes describe the applicant's primary business activity — not the specific action being proposed. Analysis confirms this is the wrong primary signal: NAICS 486 (Pipeline Transportation) applicants appear in both B1.3 records (routine maintenance) and Energy Policy Act Sec.390 records (new drilling/pipeline placement) — the same NAICS, radically different CE authority. NAICS does have value as a **secondary signal** for two purposes:

1. **Jurisdiction routing** — NAICS helps identify which agency's CE list is applicable. NAICS 221 (Utilities/Power) applicants on federal land → likely DOE B-codes or BLM 516 DM. NAICS 112 (Animal Production/Agriculture) → USDA/USFS 36 CFR 220.6 codes. This narrows the code namespace before the action-type rules fire.
2. **Extraordinary circumstances pre-screening** — NAICS 212 (Mining) and NAICS 211 (Oil/Gas) projects carry higher baseline extraordinary-circumstances risk and should default to Low confidence regardless of other signals.

NAICS codes are available via SAM.gov for registered federal contractors and grantees, making them a feasible intake data element for applicants who are registered federal entities.

---

#### Adjacent Data Sources That Strengthen the Decision Matrix

Beyond sector, project type, and NAICS, five additional data inputs substantially reduce ambiguity:

| Data Source | Signal Provided | Integration Approach |
|---|---|---|
| **GIS resource overlay** (Priority 8 — USFWS IPaC, NWI, NHPA) | Extraordinary circumstances flags: ESA Critical Habitat, wetlands, cultural resources, tribal lands | OmniProcess API calls on project footprint submission; feeds Expression Set as binary flags |
| **Federal land ownership** (BLM Surface Management Agency layer) | Determines which agency's CE catalog applies; non-federal land = different analysis | GIS overlay from Priority 8; maps to jurisdiction routing in Expression Set |
| **Project acreage / disturbance area** | Threshold discriminator for Energy Policy Act Sec.390 (< 5 acres), BLM 516 DM provisions | Intake field: `nepa_disturbance_acres__c`; used as Expression Set numeric comparison |
| **Action verb taxonomy** (structured controlled vocabulary) | "Renew/extend existing" vs. "construct new" vs. "modify existing" vs. "abandon/decommission" — the single strongest CE vs. EA discriminator | New intake picklist: `nepa_action_type__c`; see field list below |
| **CFR regulatory citation** (agency's own CE authority) | Direct code resolution when applicant or agency coordinator knows the applicable CFR section | Optional intake field: `nepa_regulatory_citation__c`; pre-populates `nepa_process_code__c` when supplied |

---

#### Implementation Approach

1. **Structured Pre-Application Intake OmniScript** — A guided OmniScript questionnaire collects the structured project attributes needed to evaluate CE eligibility in the correct sequence:
   - Step 1: Lead agency / federal jurisdiction (determines CE catalog namespace)
   - Step 2: Project sector and type (NEPATEC taxonomy — maps to Tier 1 matrix)
   - Step 3: **Action type** — controlled picklist: Construct New / Modify Existing / Renew/Extend Existing / Abandon/Decommission / Operate/Maintain Existing / Research/Study / Other (the primary Tier 2 discriminator)
   - Step 4: Physical parameters — acreage of surface disturbance, indoor/outdoor, existing footprint Y/N
   - Step 5: Applicant NAICS code (optional, from SAM.gov registration — used for jurisdiction routing and extraordinary circumstances pre-screen)
   - Step 6: GIS footprint submission (triggers Priority 8 resource overlay)

2. **CE Classification Expression Set** — A Business Rules Engine Expression Set codifies the three-tier decision matrix as sequential rule groups. Rule evaluation order: (1) jurisdiction routing by agency + NAICS → narrows code namespace; (2) Tier 1 sector/type rules → high-confidence matches; (3) Tier 2 action-type + threshold rules → resolves ambiguous Tier 1 matches; (4) extraordinary circumstances flags from GIS overlay → disqualify CE or reduce confidence. Outputs:
   - Recommended NEPA review type (CE / EA / EIS) — populates `nepa_review_type__c`
   - Applicable CE code set (one or more) — populates `nepa_process_code__c`
   - Confidence level (High / Medium / Low) — populates `nepa_screening_confidence__c`
   - Extraordinary circumstances flags list — populates `nepa_extraordinary_circumstances__c`
   - Classification basis narrative (rule path taken) — populates `nepa_classification_basis__c` for administrative record

3. **CE Determination Workflow** — High confidence + no extraordinary circumstances: automatically creates an `IndividualApplication` record with `nepa_review_type__c = CE`, `nepa_process_status__c = in progress`, and spawns an Action Plan for CE document preparation. Medium confidence: routes to NEPA coordinator for review with pre-populated draft determination. Low confidence or EIS: routes to NEPA coordinator for full scoping with reasoning documented.

4. **NEPATEC-Derived Decision Matrices** — Four CSV files derived from the full NEPATEC v2.0 corpus (all 73,521 CE documents) seed the Expression Set rule base:

   - **`ce_matrix_tier1_high_confidence.csv`** (22 rows) — Agency + sector + project type combinations where ≥80% of coded records map to a single CE code family. These become deterministic Tier 1 Expression Set rules with High or Medium-High confidence output.
   - **`ce_matrix_tier2_ambiguous.csv`** (530 rows) — Combinations where multiple CE code families coexist. Each row identifies the top competing codes and the `discriminating_input` (always `nepa_action_type__c`, with or without acreage check). These become conditional Tier 2 rules that branch on action type.
   - **`ce_code_catalog.csv`** (292 rows) — The full normalized CE code catalog: CFR authority, plain-language description, indoor-only flag, acreage threshold, and GIS review requirement flag. This seeds the `nepa_ce_code__mdt` custom metadata type.
   - **`naics_ce_routing.csv`** (20 rows) — NAICS code → likely lead agency + CE code namespace mapping. Used as the first routing step in the Expression Set before sector/type rules fire.

   Over time, the agency's own closed CE records in Salesforce supersede the NEPATEC baselines as the higher-quality training corpus. DataRaptor-based refresh cycles can re-derive Tier 1 and Tier 2 rules from the live record set annually.

**Data Foundations Required:**
- `IndividualApplication.nepa_review_type__c` — already implemented in v1.1
- `IndividualApplication.nepa_process_code__c` — already implemented in v1.1
- Add: `IndividualApplication.nepa_screening_confidence__c` (Picklist: High / Medium / Low)
- Add: `IndividualApplication.nepa_extraordinary_circumstances__c` (LongTextArea: flags from GIS + rules)
- Add: `IndividualApplication.nepa_classification_basis__c` (LongTextArea: rule path for administrative record)
- Add: `IndividualApplication.nepa_action_type__c` (Picklist: Construct New / Modify Existing / Renew or Extend Existing / Abandon or Decommission / Operate or Maintain Existing / Research or Study / Other)
- Add: `IndividualApplication.nepa_disturbance_acres__c` (Number 10,2: surface disturbance threshold input)
- Add: `Program.nepa_applicant_naics__c` (Text 6: 6-digit NAICS code from SAM.gov registration)
- Add: `IndividualApplication.nepa_regulatory_citation__c` (Text 255: optional CFR citation from applicant)
- Add: `nepa_ce_code__mdt` custom metadata type (CE code catalog: agency, code, description, authority_cfr, acreage_threshold, action_types, sectors, indoor_only — drives lookup table)

**Dependencies:** PSS Advanced or Industry add-on for Business Rules Engine; OmniStudio license (already required); Priority 8 GIS overlay for extraordinary circumstances flags

---

### PRIORITY 3: CLM-Driven Document Assembly with AI-Generated Narrative
**Time Reduction Estimate: 2–8 weeks per document on critical path**

**Why this ranks third:** Paces demonstrated 2–20 minutes for initial report section drafts versus 2–12 weeks manual. The NEPA process requires producing multiple major documents in sequence: Scoping Report → Draft EA/EIS → Final EA/EIS → FONSI/ROD. Each document is on the critical path. Even reducing the initial drafting phase by 50% across all documents adds up to months saved per EIS.

NEPA documents have two fundamentally different content types that call for different tools: **repeatable standard language** (regulatory citations, standard mitigation clauses, boilerplate FONSI rationale, ROD structure) that should never vary without deliberate legal review; and **project-specific narrative** (the Affected Environment description for a particular watershed, the Environmental Consequences analysis for a specific project footprint) that is unique every time. Separating these two layers into CLM and Agentforce respectively gives each the right tool.

**PSS Capability:** Contract Lifecycle Management (CLM) clause library + Agentforce + Einstein Document Understanding + `ContentVersion` (existing)

**Implementation Approach:**

**Layer 1: CLM Template & Clause Library (standard, repeatable content)**

1. **Document Template Library** — CLM templates define the skeleton for each NEPA document type: EA, EIS, FONSI, ROD, CE Determination, Scoping Report. Each template specifies required sections in order, maps to `ContentVersion.nepa_document_type__c`, and enforces section structure that cannot be removed without override.

2. **Clause Library by Review Type and Sector** — Pre-approved, legally reviewed clause text is stored as discrete CLM clause records organized by:
   - *Document type* (FONSI rationale, ROD decision language, CE extraordinary circumstances certification)
   - *Project sector* (standard pipeline waterbody crossing mitigation, renewable energy visual impact language, rangeland management commitments)
   - *Resource type* (ESA Section 7 consultation coordination language, Section 106 consulting party notification, Clean Water Act 404/401 coordination text)

3. **Rules-Based Clause Selection** — CLM clause rules evaluate `IndividualApplication` fields (`nepa_review_type__c`, `nepa_project_type__c`) and `Program` fields (`nepa_project_sector__c`) plus GIS resource flags from Priority 8 (`nepa_gis_data_element__c.nepa_resource_type__c`) to automatically include or exclude clauses. An EIS for a pipeline project with ESA Critical Habitat overlap assembles a different clause set than one for a renewable energy project on non-sensitive land — automatically, without analyst judgment required for the standard language.

4. **CLM Approval Workflow** — Standard and non-standard clauses route through different approval paths. Agency legal counsel approves clause library additions once; individual documents using only approved clauses bypass legal review. Documents containing non-standard or modified clauses are automatically flagged for legal review before publication.

**Layer 2: Agentforce AI (project-specific narrative content)**

5. **Context Assembly Integration Procedure** — Before AI generation, an OmniProcess Integration Procedure assembles project-specific context: structured fields from `Program` and `IndividualApplication`, GIS resource overlay results from `nepa_gis_data_element__c`, prior approved documents for similar project types from `ContentVersion`, and any agency-specific baseline data.

6. **Narrative Section Generation Agent** — An Agentforce agent generates draft text for the sections that are inherently project-specific and cannot come from a clause library:
   - Affected Environment (resource-by-resource, site-specific)
   - Environmental Consequences per alternative
   - Alternatives description and comparative analysis
   - Project description narrative

   All AI-generated content is tagged `nepa_ai_generated__c = true` and `nepa_status__c = Draft` for mandatory SME review before promotion to Approved.

7. **Unified SME Review Interface** — A FlexCard-based review screen surfaces the full assembled document: CLM-sourced clauses (marked as pre-approved, read-only by default), AI-generated sections (marked for required review), and any flagged non-standard clauses. Reviewers accept, edit, or reject AI sections; request clause substitutions from the library; and escalate non-standard language to legal — all from one screen.

8. **Document Version Control** — `ContentVersion` fields (`nepa_revision_number__c`, `nepa_document_revision__c`, `nepa_status__c`) track the full lifecycle — CLM assembly → AI draft → SME review → legal review (if triggered) → approved → published — via Flow triggers on CLM approval events.

**Data Foundations Required:**
- All `ContentVersion` fields already implemented in v1.1
- Add: `nepa_ai_generated__c` (Checkbox: marks AI-generated sections for mandatory disclosure and SME review routing)
- Add: `nepa_clm_template_id__c` (Text 36: CLM template used to generate this document, for audit trail)
- Add: `nepa_reviewer__c` (Lookup → User: SME who reviewed/approved)
- Add: `nepa_reviewed_date__c` (Date: when SME review was completed)

**Dependencies:** CLM license (included in PSS Advanced); Agentforce license; existing OmniStudio Integration Procedure pattern (CEQExport is already implemented as a template)

---

### PRIORITY 4: Intelligent Process Tiering & Early Warning System
**Time Reduction Estimate: Prevents the worst 10–15% of projects from taking 5–13+ years**

**Why this ranks fourth:** The EIS Timeline Report shows the distribution is highly right-skewed — most complete in 2–4 years, but a long tail takes decades. The difference between a project completing in 3 years and one completing in 13 years is often identifiable early: project sector, agency, circuit, number of cooperating agencies, adjacent statute requirements, and public controversy indicators. Einstein Discovery can learn these patterns from NEPATEC2.0 data. Catching at-risk projects in year 1 rather than year 5 allows for resource prioritization, scope adjustment, or early mediation.

**PSS Capability:** CRM Analytics + Einstein Discovery + `ApplicationTimeline` (existing) + `nepa_litigation__c` (existing)

**Implementation Approach:**

1. **Timeline Baseline Dataset** — CRM Analytics dataset built from closed `IndividualApplication` records, computing actual duration of each process stage (NOI to Scoping, Scoping to Draft EIS, Draft EIS to Final EIS, Final EIS to ROD). Segmented by review type, lead agency, sector, and number of cooperating agencies.

2. **Einstein Discovery Risk Model** — Trained on NEPATEC2.0 project attributes and `nepa_litigation__c` outcomes (761 federal NEPA litigation cases with PermitTEC linkage) to predict:
   - `nepa_estimated_completion_date__c` — projected completion given current stage and project profile
   - `nepa_timeline_risk_tier__c` — On Track / At Risk / Stalled / Overdue
   - `nepa_risk_score__c` — 0–100 composite risk score
   - `nepa_predicted_challenge_grounds__c` — top litigation risk factors

3. **Automated Risk Alerts** — Flow trigger fires when `nepa_timeline_risk_tier__c` changes to At Risk or worse: creates a Case assigned to the NEPA coordinator, adds an ApplicationTimeline event with `nepa_event_type__c = Process Paused` if applicable, and escalates to supervisor after 30 days without resolution.

4. **Agency Performance Dashboard** — CRM Analytics dashboard comparing actual vs. predicted timelines by agency, sector, and review type. Surfaces which CE/EA/EIS categories consistently run over baseline and enables proactive staffing adjustments.

**Data Foundations Required:**
- `IndividualApplication.nepa_process_status__c` — already implemented
- `ApplicationTimeline.nepa_event_type__c`, `nepa_status__c` — already implemented
- `nepa_litigation__c` full object — already implemented
- Add: `IndividualApplication.nepa_estimated_completion_date__c` (Date: Einstein-predicted)
- Add: `IndividualApplication.nepa_timeline_risk_tier__c` (Picklist: On Track / At Risk / Stalled / Overdue)
- Add: `IndividualApplication.nepa_risk_score__c` (Number: 0–100)
- Add: `IndividualApplication.nepa_days_in_current_stage__c` (Formula: today minus last stage transition date)
- Add: `IndividualApplication.nepa_last_stage_transition__c` (DateTime: set by Flow on stage change)

**Dependencies:** CRM Analytics license; Einstein Discovery; sufficient historical closed-process data (NEPATEC2.0 import accelerates cold-start)

---

### PRIORITY 5: Applicant Self-Service Portal with Smart Intake
**Time Reduction Estimate: 2–6 weeks per project in pre-application phase**

**Why this ranks fifth:** Incomplete or incorrect applications trigger Requests for Information (RFIs) that pause the clock while applicants gather missing data. Each RFI cycle typically adds 2–4 weeks. A guided intake portal that validates completeness before submission eliminates most RFI rounds. The NEPATEC2.0 structured schema (project_sector, project_type, location coordinates, project_description) establishes exactly what data a complete record requires.

**PSS Capability:** Experience Cloud + OmniScript + FlexCards + Action Plans + Business Rules Engine

**Implementation Approach:**

1. **Applicant Experience Cloud Portal** — An Experience Cloud site provides applicants with a self-service hub: submit new project applications, track existing application status, respond to RFIs, view public comment periods, and download decision documents. Leverages existing `Program` and `IndividualApplication` objects as the data backbone.

2. **Smart Intake OmniScript** — A multi-step OmniScript guides applicants through structured project information capture:
   - Step 1: Project identification (title, sponsor, location — with map-based point picker populating `nepa_location_lat__c` / `nepa_location_lon__c`)
   - Step 2: Project type classification (sector/type picklists aligned to NEPATEC taxonomy, populating `nepa_project_sector__c`)
   - Step 3: Resource screening questionnaire (feeds CE classification Expression Set from Priority 2)
   - Step 4: Document upload (populates `ContentVersion` with `nepa_document_type__c`)
   - Step 5: Review and completeness check (inline validation before submission)

3. **Completeness Validation** — Business Rules Engine validates submission completeness against review-type-specific requirements. An incomplete EA application cannot be submitted without: purpose and need statement, project description, location data, and at least one supporting document. Populates `nepa_screening_confidence__c` from Priority 2 as a by-product.

4. **Applicant Action Plan** — When a new application is received, an Action Plan Template generates an applicant task list: upload cultural resources survey, submit agency consultation letters, provide supplemental GIS data. Applicant completes tasks within the portal; staff receive completion notifications.

5. **Application Status FlexCard** — Public-facing FlexCard shows applicants their current process stage, next milestone, and any outstanding RFI items without requiring a phone call or email.

**Data Foundations Required:**
- All existing `Program`, `IndividualApplication`, `ContentVersion` fields usable as-is
- Requires: Experience Cloud license + Guest/Partner user profiles configured
- Add: `IndividualApplication.nepa_applicant_contact__c` (Lookup → Contact: portal user)
- Add: `IndividualApplication.nepa_submission_complete__c` (Checkbox: validation gate)
- Add: `IndividualApplication.nepa_rfi_count__c` (Rollup: count of open RFI tasks)

---

### PRIORITY 6: Automated Workflow & Milestone Orchestration
**Time Reduction Estimate: 1–3 weeks per process phase from elimination of administrative idle time**

**Why this ranks sixth:** The CEQ Permitting Technology Action Plan explicitly identifies "fragmented data management and disconnected digital tools" as a primary delay cause. When a milestone completes, the next task should automatically route to the right person with a deadline, not sit in an email inbox until someone notices. This is a horizontal accelerator that compounds across every phase.

**PSS Capability:** OmniProcess + Flow + Action Plan Templates + ApplicationTimeline (existing)

**Implementation Approach:**

1. **Review-Type-Specific Action Plan Templates** — Three Action Plan Templates (CE, EA, EIS) define the standard task sequence for each review type with default durations:
   - **CE Template:** Screening → CE Documentation → Supervisor Review → Approval (target: 30 days)
   - **EA Template:** Scoping → Purpose & Need → Alternatives Analysis → Affected Environment → Environmental Consequences → Mitigation → FONSI/ROD (target: 180 days)
   - **EIS Template:** NOI → Scoping → Draft EIS → Comment Period → Response to Comments → Final EIS → ROD (target: 730 days per CEQ 2024 guidance)

2. **Stage-Gate Flow Automation** — When an ApplicationTimeline event's `nepa_status__c` transitions to Completed, a Flow:
   - Updates `IndividualApplication.nepa_process_stage__c`
   - Records `nepa_last_stage_transition__c` timestamp (feeds Priority 4 risk model)
   - Closes the current Action Plan task
   - Opens the next Action Plan task with an assignee and due date
   - Sends email/in-app notification to the next responsible party

3. **SLA Escalation Rules** — Tasks approaching due date (3 days out) and overdue tasks automatically escalate: first to the task owner's supervisor, then to the NEPA Program Manager. Escalation chain is configurable by agency.

4. **Administrative Record Auto-Creation** — When a `ContentVersion` record with `nepa_document_type__c` in (NOI, Draft EIS, Final EIS, ROD, EA, FONSI, CE Determination) is uploaded, Flow automatically creates an `ApplicationTimeline` event with the matching `nepa_event_type__c` and `nepa_public_access__c = true`, eliminating the manual step of logging milestones that are already captured by document uploads.

**Data Foundations Required:**
- `ApplicationTimeline` extension already implemented in v1.1
- Action Plan Templates (PSS native feature, requires configuration)
- Add: `IndividualApplication.nepa_last_stage_transition__c` (DateTime: Flow-maintained)
- Add: `IndividualApplication.nepa_target_completion_date__c` (Date: set at Action Plan creation)

---

### PRIORITY 7: Interagency Coordination Hub
**Time Reduction Estimate: 2–6 weeks on multi-agency processes**

**Why this ranks seventh:** The EIS Timeline Report specifically calls out joint lead agency and cooperating agency coordination as a delay factor. Cooperating agencies (Army Corps of Engineers, EPA, Fish & Wildlife Service, etc.) must provide formal inputs at defined milestones. Without a shared workspace, agencies coordinate by email with long turnaround times, unclear ownership, and version confusion.

**PSS Capability:** Experience Cloud Partner Community + nepa_process_related_agencies__c (existing) + Document Sharing

**Implementation Approach:**

1. **Cooperating Agency Community** — An Experience Cloud Partner Community site gives cooperating and participating agencies authenticated access to project records without requiring a Salesforce license. Partners see only the projects their agency is associated with (via `nepa_process_related_agencies__c.nepa_role__c`).

2. **Agency Input Submission** — Cooperating agencies submit formal inputs (biological opinions, Section 106 consultations, Water Quality Certifications) directly to the portal. Submissions create `ContentVersion` records with `nepa_record_category__c = Agency Communication` and `nepa_contributing_agencies__c` pre-populated.

3. **Agency Task Assignments** — The Action Plan system from Priority 6 routes specific tasks to cooperating agencies through the partner portal. An Army Corps cooperating agency sees only their assigned tasks (e.g., "Submit Section 404 Jurisdictional Determination by [date]") with clear deadlines.

4. **Document Version Sync** — Lead agency publishes draft documents to the portal; cooperating agencies comment on specific sections using the `PublicComplaint` object with `nepa_public_access__c = Internal`. This captures interagency comments in the same system as public comments, creating a unified administrative record.

**Data Foundations Required:**
- `nepa_process_related_agencies__c` already implemented
- `nepa_engagement__c` for agency meeting tracking already implemented
- Requires: Experience Cloud license; Partner Community configuration
- Add: `nepa_process_related_agencies__c.nepa_input_due_date__c` (Date: agency-specific deadline)
- Add: `nepa_process_related_agencies__c.nepa_input_status__c` (Picklist: Pending / In Progress / Submitted / Accepted)

---

### PRIORITY 8: GIS-Integrated Resource Screening
**Time Reduction Estimate: 1–3 weeks in scoping phase per project**

**Why this ranks eighth:** Early identification of affected resources (wetlands, ESA-listed species habitat, cultural resource areas, floodplains, tribal lands) determines whether extraordinary circumstances exist that would disqualify a CE or require elevated analysis in an EA. Manual GIS research during scoping typically takes a geospatial analyst days to weeks. Automated resource overlay at project intake compresses this to seconds.

**PSS Capability:** PSS Polygon object + ArcGIS / ESRI integration + GIS data services (USFWS IPaC, NLCD, NWI, NHPA databases)

**Implementation Approach:**

1. **Project Footprint Capture** — Extend the Smart Intake OmniScript (Priority 5) to include a polygon drawing tool (ArcGIS Maps for Salesforce component) populating the PSS `Polygon` object linked to `Program.nepa_location__c`. Captures project boundary as a spatial geometry, not just a point coordinate.

2. **Automated Resource Overlay Integration Procedure** — On project footprint submission, an OmniProcess Integration Procedure calls:
   - **USFWS IPaC API** — returns ESA-listed species within the project footprint
   - **USFWS National Wetlands Inventory API** — returns wetland type and acreage overlap
   - **USGS National Hydrography Dataset** — returns waterway crossings
   - **BLM Surface Management Agency data** — returns land ownership/management classification
   Results are stored in a new `nepa_gis_data_element__c` object linked to `Program`.

3. **Extraordinary Circumstances Auto-Flag** — Business Rules Engine evaluates the resource overlay results and flags extraordinary circumstances that would disqualify CE treatment: presence of ESA Critical Habitat, wetland area > threshold, proximity to tribal sacred sites, etc. Flags feed directly into the CE Classification Expression Set (Priority 2).

4. **Resource Summary FlexCard** — NEPA coordinator's project view shows a resource summary card: species list, wetland acreage, resource sensitivities, and a map thumbnail — all in the Salesforce record page without leaving the application.

**Data Foundations Required:**
- PSS Polygon object (referenced in roadmap but not yet linked)
- Add: `nepa_gis_data_element__c` custom object with fields: `nepa_project__c` (Lookup → Program), `nepa_resource_type__c` (Picklist), `nepa_resource_name__c` (Text), `nepa_overlap_acreage__c` (Number), `nepa_sensitivity_level__c` (Picklist: None / Moderate / High / Critical), `nepa_data_source__c` (Text), `nepa_retrieved_date__c` (DateTime)
- Requires: ArcGIS Maps for Salesforce (ESRI partnership); Named Credentials for federal GIS APIs

---

### PRIORITY 9: Administrative Record Automation & Completeness Scoring
**Time Reduction Estimate: Prevents litigation-driven delays (months to years)**

**Why this ranks ninth:** While not directly compressing the permitting timeline, an incomplete administrative record is the most common basis for successful NEPA legal challenges — which can add years to final permit decisions. The `nepa_litigation__c` object already tracks 761 federal NEPA cases; the pattern is clear: agencies that maintain complete administrative records prevail more often. Automated completeness scoring ensures nothing is missing before the record is needed.

**PSS Capability:** Flow + ContentVersion (existing) + Einstein Document Understanding + CRM Analytics

**Implementation Approach:**

1. **Record Completeness Checklist by Review Type** — A metadata-driven completeness definition lists required documents for each NEPA review type:
   - **CE:** CE Determination form, extraordinary circumstances review, project description
   - **EA:** NOI (if public), Purpose & Need, Alternatives Analysis, Affected Environment, FONSI
   - **EIS:** NOI, Scoping Report, Draft EIS, Comment Response Matrix, Final EIS, ROD

2. **Flow-Based Completeness Scoring** — When any `ContentVersion` record is uploaded with `nepa_permit_document` record type, a Flow recalculates `IndividualApplication.nepa_record_completeness__c` (Percent) based on which required document types have at least one Approved document attached. Score is visible on the Application record page.

3. **Missing Document Alerts** — If a process reaches a stage gate (e.g., "Final EIS Published") but required predecessor documents are missing (e.g., no Comment Response Matrix), the Stage Gate Flow from Priority 6 raises an error and requires supervisor override with justification documented in an ApplicationTimeline event.

4. **Einstein Document Understanding Validation** — For high-complexity EIS documents, Einstein Document Understanding can validate that required sections (Purpose and Need, Alternatives, Affected Environment, Environmental Consequences, Mitigation) are present within the document before marking it as Approved.

**Data Foundations Required:**
- `ContentVersion` fields all implemented in v1.1
- `ApplicationTimeline` fields all implemented in v1.1
- Add: `IndividualApplication.nepa_record_completeness__c` (Percent Formula)
- Add: `nepa_required_document_type__c` custom metadata type (defines checklist by review type)

---

### PRIORITY 10: Cross-Agency Data Exchange & Interoperability
**Time Reduction Estimate: Weeks saved per project from eliminating manual data re-entry**

**Why this ranks tenth:** CEQ MFR #2 (Application Data Sharing) requires agencies to share permitting data with the government-wide permitting dashboard and CEQ. The OmniStudio CEQExport Integration Procedure already implements the technical foundation. Extending it to also ingest data from other agency systems (DOE's PAMS, BLM's NEPA Register, DOT's FAST-41 dashboard) eliminates duplicate data entry and keeps Salesforce records current without manual synchronization.

**PSS Capability:** OmniProcess (existing CEQExport IP) + Change Data Capture + Connected App + External Data Sources

**Implementation Approach:**

1. **CEQ Export Activation** — Activate the existing `NEPA/CEQExport` Integration Procedure as a REST API Action. Configure a Connected App for OAuth 2.0 access. This fulfills MFR #2 at Emerging maturity with minimal additional work — the foundation is already built in v1.1.

2. **Inbound Agency Data Ingestion** — Extend the OmniProcess pattern to accept inbound data from external agency systems via REST. An `upsert` operation keyed on `nepa_federal_unique_id__c` (already External ID) and `nepa_project_id__c` keeps records synchronized when agencies use their own systems as the system of record.

3. **Change Data Capture Subscriptions** — Configure CDC on `IndividualApplication`, `Program`, and `ApplicationTimeline` to emit real-time event streams to the Permitting Council's FAST-41 dashboard and other subscribers. Eliminates scheduled batch synchronization delays.

4. **Federal Register Integration** — Integration Procedure calls the Federal Register API to pull NOI publication dates, comment period open/close dates, and ROD publication dates directly into `ApplicationTimeline` records — eliminating manual data entry of public milestones.

**Data Foundations Required:**
- `nepa_federal_unique_id__c` and `nepa_project_id__c` External IDs already implemented
- All OmniStudio DataRaptors and CEQExport IP already implemented in v1.1
- Requires: Named Credential for Federal Register API, Connected App configuration

---

## Summary Roadmap

| Priority | Feature | Primary PSS Capability | Effort | Time Saved (per project) |
|---|---|---|---|---|
| 1 | AI-Assisted Comment Analysis | Agentforce + Einstein NLP | Medium | 4–8 weeks |
| 2 | Automated CE Screening & Classification | Business Rules Engine (Expression Sets) | Medium | 6 months – 2+ years |
| 3 | CLM-Driven Document Assembly + AI Narrative | CLM Clause Library + Agentforce | High | 2–8 weeks per document |
| 4 | Timeline Risk Prediction & Early Warning | CRM Analytics + Einstein Discovery | High | Prevents 5–13 year outliers |
| 5 | Applicant Self-Service Portal | Experience Cloud + OmniScript | High | 2–6 weeks |
| 6 | Automated Workflow & Milestone Orchestration | OmniProcess + Flow + Action Plans | Medium | 1–3 weeks per phase |
| 7 | Interagency Coordination Hub | Experience Cloud Partner Community | Medium | 2–6 weeks |
| 8 | GIS-Integrated Resource Screening | PSS Polygon + ArcGIS + External APIs | High | 1–3 weeks in scoping |
| 9 | Administrative Record Automation | Flow + Einstein Doc Understanding | Low | Prevents litigation delays |
| 10 | Cross-Agency Data Exchange | OmniProcess + CDC + Connected App | Low | Days per project |

### Implementation Sequencing

**Phase 1 (0–90 days): Data & Workflow Foundation**
- Priority 6: Automated workflow (Action Plan Templates + Flow stage gates) — fast to implement, immediate operational value
- Priority 10: Activate CEQ Export (already built, just needs activation) — fulfills MFR #2 immediately
- Priority 9: Administrative record completeness scoring — low effort, high compliance value

**Phase 2 (90–180 days): Intelligent Screening & Intake**
- Priority 2: CE Screening Expression Sets — highest leverage feature, eliminates entire EA/EIS processes
- Priority 5: Applicant self-service portal — requires Experience Cloud + OmniScript
- Priority 7: Interagency coordination hub — extends the Experience Cloud investment from Priority 5

**Phase 3 (180–365 days): AI-Powered Analysis**
- Priority 1: Comment analysis Agentforce agent — requires Agentforce license and training data
- Priority 3: Document generation — requires Agentforce with document capability
- Priority 4: Risk prediction — requires sufficient historical data from Phase 1+2 deployments

**Phase 4 (Year 2): Spatial Intelligence**
- Priority 8: GIS resource screening — requires ArcGIS Maps for Salesforce and API agreements with federal GIS services

---

## New Data Elements Required (Not in v1.1)

The following custom fields should be added to support the above features. All follow the existing `nepa_` namespace convention.

### `PublicComplaint` additions
- `nepa_sentiment__c` (Picklist: Supportive / Neutral / Opposed / Mixed)
- `nepa_is_substantive__c` (Checkbox)
- `nepa_cluster_id__c` (Text 36: form letter grouping)
- `nepa_response_status__c` (Picklist: Pending / Draft / Reviewed / Finalized)

### `IndividualApplication` additions
- `nepa_screening_confidence__c` (Picklist: High / Medium / Low)
- `nepa_extraordinary_circumstances__c` (LongTextArea 32,768)
- `nepa_classification_basis__c` (LongTextArea 32,768)
- `nepa_action_type__c` (Picklist: Construct New / Modify Existing / Renew or Extend Existing / Abandon or Decommission / Operate or Maintain Existing / Research or Study / Other)
- `nepa_disturbance_acres__c` (Number 10,2)
- `nepa_regulatory_citation__c` (Text 255)
- `nepa_estimated_completion_date__c` (Date)
- `nepa_timeline_risk_tier__c` (Picklist: On Track / At Risk / Stalled / Overdue)
- `nepa_risk_score__c` (Number 3,0)
- `nepa_days_in_current_stage__c` (Formula Number)
- `nepa_last_stage_transition__c` (DateTime)
- `nepa_target_completion_date__c` (Date)
- `nepa_applicant_contact__c` (Lookup → Contact)
- `nepa_submission_complete__c` (Checkbox)
- `nepa_rfi_count__c` (Rollup COUNT on open tasks)
- `nepa_record_completeness__c` (Percent Formula)
- `nepa_predicted_challenge_grounds__c` (LongTextArea 32,768)

### `ContentVersion` additions
- `nepa_ai_generated__c` (Checkbox)
- `nepa_clm_template_id__c` (Text 36: CLM template used to assemble this document)
- `nepa_reviewer__c` (Lookup → User)
- `nepa_reviewed_date__c` (Date)

### `nepa_process_related_agencies__c` additions
- `nepa_input_due_date__c` (Date)
- `nepa_input_status__c` (Picklist: Pending / In Progress / Submitted / Accepted)

### New Custom Object: `nepa_gis_data_element__c`
- `nepa_project__c` (Lookup → Program)
- `nepa_resource_type__c` (Picklist: Wetlands / ESA Species / ESA Critical Habitat / Cultural Resources / Tribal Lands / Floodplain / Other)
- `nepa_resource_name__c` (Text 255)
- `nepa_overlap_acreage__c` (Number 18,4)
- `nepa_sensitivity_level__c` (Picklist: None / Moderate / High / Critical)
- `nepa_data_source__c` (Text 255)
- `nepa_retrieved_date__c` (DateTime)

### `Program` additions
- `nepa_applicant_naics__c` (Text 6: 6-digit NAICS code from SAM.gov)

### New Custom Metadata Type: `nepa_ce_code__mdt` (CE catalog — seeded from `ce_code_catalog.csv`)
- `Agency__c` (Text 10: DOE / BLM / USFS / EPA / DOD / All)
- `Code__c` (Text 80: normalized code, e.g., `B1.3`, `516 DM 11.9`, `Energy Policy Act 2005 Sec.390(b)(4)`)
- `Authority_CFR__c` (Text 150: e.g., `DOE 10 CFR 1021 App.B §B1.3`)
- `Plain_Language_Description__c` (TextArea 255: human-readable description)
- `Action_Types__c` (Text 255: semicolon-separated from `ce_matrix_tier1_high_confidence.csv` and `tier2` data)
- `Applicable_Sectors__c` (LongText: semicolon-separated NEPATEC sectors)
- `Indoor_Only__c` (Checkbox: `B3.6 = true`; flags facility-level indoor-only applicability)
- `Acreage_Threshold__c` (Number 8,2: max surface disturbance acres; 5.0 for EPA Sec.390(b)(1))
- `Requires_GIS_Review__c` (Checkbox: `true` for FLPMA 402(h), 43 CFR 46.210, EPA Sec.390(b)(1) — triggers extraordinary circumstances overlay)
- `Record_Count_NEPATEC__c` (Number: corpus frequency — used to sort results in Expression Set output)
- `Is_Multi_Code__c` (Checkbox: true for compound codes like `A9 + B3.6`; indicates CE authority is additive)

### New Custom Metadata Type: `NEPA_Required_Document__mdt`
- `Review_Type__c` (Picklist: CE / EA / EIS)
- `Document_Type__c` (Picklist — mirrors `nepa_document_type__c` values)
- `Is_Required__c` (Checkbox)
- `Stage_Required_By__c` (Text: which process stage requires this document)

---

## License Requirements Summary

| Feature | Additional License Required |
|---|---|
| OmniStudio (DataRaptors, OmniScript, Integration Procedure) | OmniStudio add-on (or PSS Advanced) |
| Business Rules Engine (Expression Sets) | PSS Advanced or Industry Cloud |
| Experience Cloud (Portal) | Experience Cloud license + Communities |
| CLM (Clause Library, Templates, Approval Workflows) | Included in PSS Advanced |
| Agentforce (AI Agents) | Agentforce license |
| Einstein Discovery | CRM Analytics + Einstein Predictions |
| CRM Analytics Dashboards | CRM Analytics |
| ArcGIS Maps for Salesforce | ESRI ArcGIS Maps for Salesforce |

---

*This plan is grounded in: CEQ Permitting Technology Action Plan (May 2025), CEQ EIS Timeline Report (January 2025), NAEP 2025 PNNL Workshop Report (April 2025), CEQ NEPA and Permitting Data and Technology Standard v1.2, NEPATEC v2.0 dataset (61,881 projects), PermitTEC litigation dataset (761 cases), and Salesforce Public Sector Solutions documentation (March 2026).*
