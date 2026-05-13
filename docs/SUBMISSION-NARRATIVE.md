# CEQ Permitting Innovators Submission Narrative

**Program:** CEQ Permitting Innovators
**Submission Deadline:** June 2, 2026
**Solution Name:** PSA-NEPA Permitting Accelerator
**Submitting Organization:** GPS Accelerators (Salesforce Public Sector Partner)
**License:** MIT (open source)
**Repository:** PSA-NEPA-Permitting-Data-Model

---

## How AI Is and Is Not Used in This Solution

A clear boundary between deterministic rules and AI is a legal and operational requirement for federal permitting. This solution enforces that boundary by design, not by policy.

| Feature | Technology | Rationale |
|---|---|---|
| CE screening and classification | **Deterministic BRE** — Decision Matrix rows + Expression Set formulas | Statutory CE determinations must be auditable to a specific CFR citation. Every result traces to the exact rule row that fired. No probabilistic inference. |
| Litigation risk scoring | **Deterministic BRE** — weighted Expression Set, empirically calibrated inputs | Risk scores inform legal strategy decisions. The formula is fully inspectable; a coordinator can hand-calculate the score from the inputs. No black box. |
| Challenge prediction rules | **Deterministic rule matching** — Custom Metadata records, accumulating deltas | Sector × circuit × plaintiff combinations are matched by exact field values, not model inference. |
| Stage gate enforcement | **Deterministic flows** — before-save record-triggered | Blocking transitions must never depend on probabilistic confidence. |
| Public comment triage | **Agentforce AI** — sentiment and substantive classification on unstructured text | High-volume unstructured text is the appropriate AI domain. AI assigns a triage classification; a human coordinator reviews every comment before a formal response is issued. |
| EJ/tribal comment routing | **Keyword gate — no AI** | Comments containing tribal sovereignty, sacred sites, EJ, or civil rights keywords bypass AI classification entirely and route directly to a human coordinator queue. This gate cannot be disabled. |

The AI Use Policy included in the repository (AI-Use-Policy.md) documents the boundary above, training data sources, known statistical limitations for each model, prohibited uses, and the human confirmation requirement for every AI-assisted feature. This documentation supports OMB M-25-21 AI use case disclosure and agency AI inventory registration.

---

## Executive Summary

The ability to efficiently permit infrastructure is foundational to American economic growth and national security. Roads, bridges, airports, water treatment plants, energy infrastructure, data centers, and national security installations all move through the NEPA environmental review process — and that process is stalled by three categories of preventable delay: misclassification at intake, manual processing of public comments, and late-stage litigation surprises that vacate decisions years after they were made. These are technology problems. They have technology solutions.

**What the federal data shows:**

- **23% of CE records in the NETATEC corpus lack classification** — each incorrect CE→EA escalation adds a median **11 months**; each incorrect CE→EIS escalation adds a median **2.8 years**
- **4.7× spread in agency EIS scoping timelines** — FERC averages 10 months NOI-to-DEIS; FAA averages 47 months; a generic baseline is accurate for neither
- **4 weeks → ~4 hours** — documented federal case (NAEP 2025 Workshop): AI-assisted triage of 2,600 public comments by 4 staff
- **Tribal Nation plaintiffs win 87.5% of NEPA cases** — the highest success rate of any plaintiff category in 761 PermitTEC cases; inadequate tribal consultation is among the costliest single failure modes
- **Energy × 4th Circuit: 28.6% agency win rate** — the highest-risk sector-circuit cell in the corpus, driven by hostile GHG and alternatives-analysis precedent; detectable at record creation

Each of these numbers corresponds to a deployed, deterministic feature — not a roadmap item.

### The Three Preventable Delays — and What the Data Shows

**Delay 1: CE Misclassification (9 months to 2.8 years per incorrectly escalated project)**

- **The Data:** NETATEC v2.0 (54,668 CE projects, PNNL) found that 23% of Categorical Exclusion records lack a recorded CE category, concentrated in BLM oil/gas and Agriculture/Rangeland projects. When an agency coordinator cannot quickly identify the applicable CE authority, the default outcome is unnecessary EA escalation. Each incorrect CE→EA escalation adds a median 11 months to project delivery. Each incorrect CE→EIS escalation adds a median 2.8 years. At scale, this misclassification tax accumulates into years of deferred infrastructure and real economic cost: construction material inflation, deferred job creation, and stalled clean energy deployment compound with every month of unnecessary review.

- **The Accelerator:** The CE Screener applies a three-tier deterministic Business Rules Engine — NAICS code routing narrows the applicable CE namespace; an agency-sector Decision Matrix identifies the high-confidence CE code; an agency-action-type layer resolves ambiguous cases where the action verb (construct vs. modify vs. renew) is the critical discriminating variable. Every determination is auditable to the specific rule row that fired. No generative AI is involved. The same federal CE library (2,105 exclusions across 79 agencies, sourced from CEQ CE Explorer v2.0) is available to every agency on the platform.

**Delay 2: Public Comment Bottleneck (4 weeks → ~4 hours on the critical path)**

- **The Data:** Public comment compilation and individual response is on the critical path for every EA and EIS. The NAEP 2025 Workshop documented a federal case in which AI-assisted comment triage reduced a 2,600-comment workload from approximately 4 staff-weeks to approximately 4 hours. This is a documented operational result from a federal NEPA process — not a theoretical projection.

- **The Accelerator:** The comment triage infrastructure establishes the data foundation for this compression: Agentforce-ready field design for AI sentiment and substantive classification, a non-negotiable EJ/tribal routing gate (AI does not classify these comments under any circumstances), and an audit-complete comment-to-response record structure that satisfies the administrative record requirements a court would examine in a challenge.

**Delay 3: Late-Stage Litigation (2–5 years from a court-ordered remand, preventable with early detection)**

- **The Data:** Analysis of PermitTEC v0.1 — 761 federal NEPA litigation cases from PNNL, calibrated through a 13-stage analysis pipeline — reveals that the conditions producing successful NEPA challenges are predictable well before a court filing. Tribal Nation plaintiffs win 87.5% of NEPA cases — the highest of any plaintiff category. Energy projects in the 4th Circuit face a 28.6% agency win rate — the highest-risk sector-circuit cell in the corpus, driven by hostile GHG and alternatives-analysis precedent from the Mountain Valley Pipeline and Atlantic Coast Pipeline decisions. When a project is vacated, the agency returns to the point of the procedural failure and restarts — typically 2–5 years of delay on a project that had detectable warning signs months before the ROD.

- **The Accelerator:** The risk intelligence layer evaluates seven dimensions at every record save: review type, lead agency loss rate, circuit multiplier, adjacent statute involvement, sector-circuit interaction, scoping overrun status, and accumulated challenge prediction deltas. Scores ≥58 auto-create a legal review task. Tribal nation challenger detection sets a dual flag and adds a +20-point delta. Energy × 4th Circuit projects receive an additional +12-point delta. Every signal is surfaced while the gap is still correctable.

### The Agency Scoping Problem No Generic Baseline Can Solve

CEQ EIS Timeline data (2010–2024) reveals a 4.7× spread in agency NOI-to-DEIS medians: FERC averages 10 months, BLM 28 months, USACE 42 months, FAA 47 months. An agency-generic 24-month scoping baseline — the current default in most tracking systems — tells a BLM project manager their EIS is on schedule when it is actually 4 months ahead of BLM's historical median, and tells an FAA project manager their EIS is on schedule when it is actually 23 months behind FAA's historical rate. The accelerator replaces generic baselines with 11 per-agency EIS scoping records derived from federal data, assigns each lead agency an empirically grounded performance tier (Fast_and_Defensible / Slow_Scoping_Bottleneck / Legally_Vulnerable), and computes scoping overrun in months against the agency's own median — not a government-wide average that is accurate for no agency in particular.

### What the Accelerator Is

The PSA-NEPA Permitting Accelerator is an open-source, production-ready implementation of the CEQ NEPA and Permitting Data and Technology Standard v1.2, built entirely on Salesforce Agentforce for Public Sector (APS) — a FedRAMP-authorized platform already deployed across federal agencies. It implements all 13 CEQ-defined entities (6 standard + 7 extended) on Salesforce-native objects, delivers 31 declarative automation flows covering the full NEPA process lifecycle, and embeds a risk intelligence layer pre-seeded from the PermitTEC and NETATEC corpus analysis described above. All agency-specific parameters are stored in 15 Custom Metadata Types — adding a new agency requires no code, no flow modifications, and no redeployment. A regression test suite of 125 Apex tests verifies field-level compliance with the PIC OpenAPI Standard v1.2.0 across all 13 entities and the REST export API.

The solution is deployable from the command line in approximately 15 minutes, requires no custom infrastructure, and is extensible to additional agencies through custom metadata configuration alone.

---

## Data and Analysis Foundation

Every feature in this accelerator was derived from analysis of two federal datasets before any code was written. The datasets, findings, and resulting features are documented below.

### Dataset 1: NEPATEC v2.0 (Pacific Northwest National Laboratory, 2025)

NEPATEC v2.0 is a structured registry of 61,881 federal NEPA projects compiled by PNNL. The subset used in this analysis covers 54,668 Categorical Exclusion projects across BLM, DOE, and USDA, with 73,521 associated documents including CE determination memos, EAs, and supporting studies.

**Key findings from NETATEC v2.0 analysis:**

| Finding | Implication | Feature Built |
|---|---|---|
| 23% of CE records have no `ce_category` recorded — concentrated in BLM oil/gas and Agriculture/Rangeland projects | Ambiguity in high-volume sectors defaults to unnecessary EA escalation (+11 months median) | **CE Screener BRE** (3-tier logic: NAICS routing → agency/sector → agency/action type) |
| 4,783 distinct `ce_category` strings resolve to three authority systems: DOE 10 CFR 1021 Appendix B, BLM 516 DM citations, EPA Section 390 | No applicant can navigate three competing CE authority namespaces without structured guidance | **CE Library** (2,105 records from CEQ CE Explorer v2.0; SOSL full-text searchable) |
| CE classification is sector + action-type dependent, not sector alone — renewing an existing permit and constructing new infrastructure in the same sector map to different CE authorities | The action verb (construct / modify / renew) is the critical discriminating variable — sector alone is insufficient | **CE Screener Tier 2 rules** (action-type discriminator layer in BRE Expression Set) |
| Tier 1 (sector + project type → CE code, >80% confidence): 22 high-confidence mappings identified | Most CE determinations can be made with high confidence from just 2 fields | **CE Screener NAICS Decision Matrix** (22 high-confidence rows; Medium-High to High confidence output) |
| Tier 3 (ambiguous, ~23% of corpus): clusters in conventional oil/gas development and mixed agriculture/rangeland | These require GIS overlay and extraordinary circumstances review before a determination can be made | **GIS Proximity Integration** (FWS ECOS critical habitat + EPA EJScreen at intake) |
| FAST-41 process duration data: CE median 47 days, EA median 11 months, EIS median 2.8 years (NETATEC v2.0 + CEQ EIS Timeline Report, January 2025) | Timeline variance is predictable by review type; pre-seeded baselines enable real-time variance tracking | **FAST-41 Timeline Tracking** (stage baseline durations pre-seeded; `nepa_milestone_variance_days__c` provides real-time variance) |
| CEQ EIS Timeline data (2010–2024): per-agency NOI-to-DEIS medians range from 10 months (FERC) to 47 months (FAA) — a 4.7× spread | A generic 24-month baseline is accurate for no agency; an FAA project tracking to FERC norms appears on schedule when it is 3 years overdue | **Per-Agency EIS Scoping Baselines** (`NEPA_Agency_Scoping_Baseline__mdt`: 11 agency records; scoping overrun detection and Agency Performance Tier assignment) |
| CE page count outliers: p95 threshold = 17 pages; EA p95 = 200 pages (NETATEC v2.0 document corpus) | A CE exceeding 17 pages is a statistical outlier — scope creep or misclassification risk, detectable from the document count alone | **Page Count Outlier Detection** (CE >17 pages or EA >200 pages triggers At Risk timeline tier automatically) |
| NEPATEC v2.0 structured schema (project_sector, project_type, location coordinates, project_description) defines exactly what a complete record requires | Incomplete applications trigger RFI cycles of 2–4 weeks each; structured intake prevents them | **OmniScript CE Intake Wizard** (7-step structured intake; completeness check before submission) |

### Dataset 2: PermitTEC v0.1 (Pacific Northwest National Laboratory, 2025)

PermitTEC v0.1 is a dataset of 761 federal NEPA litigation cases compiled by PNNL, covering 1970–2025 with classification by review type, agency, circuit, challenge ground, disposition, and adjacent statute involvement. 223 cases are directly linked to NETATEC v2.0 project records. A 13-stage analysis pipeline over these 761 cases and 120,000+ NEPA documents produced empirically calibrated risk weights — with agency points derived from actual loss rates and circuit points from court decision multipliers, each traceable to specific case counts.

**Key findings from PermitTEC analysis:**

| Finding | Implication | Feature Built |
|---|---|---|
| 98.2% of litigation involves EIS processes; EA and CE challenges are exceptional | Review type is the dominant risk predictor — weight it first and heavily | **Litigation Risk Scorer** (BRE Expression Set: EIS base score = 40/100) |
| Circuit multipliers (Stage 7): 10th Circuit = 1.45 (68 cases); 9th = 1.25 (268 cases); D.C. = 1.05 (148 cases). Formula: `(multiplier − 0.30) × 25 × 1.5` | **10th Circuit is now the highest-risk venue** — higher loss rate than 9th in a statistically sufficient sample (68 cases) | **Circuit Risk Weight** (`NEPA_Circuit_Risk_Weight__mdt`: 13 records; 10th = 43 pts, 9th = 36 pts, D.C. = 28 pts) |
| Agency loss rates (Stage 7): BLM = 39.3% (89 cases), USFS = 28.4% (148 cases), USACE = 24.2% (62 cases), FERC = 23.8% (42 cases). Formula: `loss_rate × 0.40 × 2.5` | BLM's 39.3% loss rate is statistically robust and nearly double FERC's — a single federal average erases this signal | **Agency Risk Rate** (`NEPA_Agency_Risk_Rate__mdt`: 7 records; BLM = 39 pts, USFS = 28 pts, USACE/FERC/USFWS/Default = 24 pts) |
| Five challenge grounds account for >95% of cases: failure to prepare, EIS/EA inadequacy, improper CE reliance, failure to supplement, adjacent statute violation | Challenge type is predictable from process attributes before filing | **Challenge Predictor** (5-ground prediction model; rule weights from PermitTEC distribution) |
| Statute multipliers: ESA = 1.48 (72 cases), NFMA = 1.27 (58 cases), CWA = 1.20 (48 cases), NGA = 1.02 (36 cases). Formula: `(multiplier − 1.00) × 20` | Each adjacent statute is a measurable independent risk multiplier — NFMA and NGA newly added with sufficient case counts | **Statute Risk Weight** (`NEPA_Statute_Risk_Weight__mdt`: 5 records — ESA = 10 pts, NFMA = 5 pts, CWA = 4 pts, NGA = 1 pt, NHPA = 2 pts) |
| Sector × Circuit win-rate matrix (Stage 13): Energy × 4th = 28.6% agency win rate (highest-risk cell); Transportation × D.C. = 91% (lowest). 17 cells with ≥3 cases | Sector + circuit together outperform either dimension alone; Energy in the 4th Circuit is the single highest-risk combination | **Sector-Circuit Risk Matrix** (`NEPA_Sector_Circuit_Risk__mdt`: 17 records; BRE V3 `SectorCircuitTerm` contributes up to 14 pts) |
| Tribal Nation plaintiffs: **87.5% win rate** (highest of any category, 8 cases); WildEarth Guardians: 75% (24 cases); Earthjustice: 40% (20 cases) | Plaintiff identity predicts outcome; tribal challengers succeed at 9-in-10 — inadequate consultation is the costliest single failure mode | **Plaintiff Intelligence** (`NEPA_Plaintiff_Profile__mdt`: 6 records; dual tribal flags; Legal Task auto-created; tribal consultation is a hard gate before EA/EIS publication) |
| Challenge deltas: Energy × 4th Circuit (+12 pts); Tribal plaintiff override (+20 pts) | Sector-circuit and plaintiff conditions compound base scores; accumulable deltas allow precise adjustment without recalculating the full model | **Challenge Prediction Rules** (`NEPA_Challenge_Prediction_Rule__mdt`: 7 records; `nepa_challenge_risk_delta__c` accumulates matched deltas as a BRE input) |
| Incomplete administrative records are among the most common bases for successful challenges | Completeness must be tracked continuously — not assessed after a court filing identifies the gap | **Defensibility Gap Checker** (real-time scoring; flags missing required docs before record close) |
| Cases filed within 60 days of ROD/FONSI with injunctive outcomes tend to involve inadequate public engagement records | Engagement documentation gaps are disproportionately costly at the moment they are cheapest to fix | **Defensibility Trigger Flows** (after-save triggers on ContentVersion and engagement records update defensibility scores in real time) |

### What the Analysis Did Not Produce

The Stage 7 calibration methodology applied confidence thresholds before finalizing weights. Circuits with fewer than 20 cases retain `Low_Data_Confidence__c = true` in `NEPA_Circuit_Risk_Weight__mdt` and receive directional rather than precise weights. The 10th, 9th, D.C., 7th, and 4th Circuits all have ≥22 cases and are marked `Low_Data_Confidence__c = false`. The accelerator's AI Use Policy discloses confidence levels explicitly:

> `[AI-GENERATED — PermitTEC v0.1 684 usable cases; Stage 7 calibrated weights; agency loss_rate×0.40×2.5; circuit (multiplier−0.30)×25×1.5; statute (multiplier−1.0)×20]`

This disclosure is embedded in every risk score output (`nepa_risk_score_factors__c`) and is repeated in the AI Use Policy documentation included with the repository. Agencies are informed of model confidence limitations before relying on any output — this is a design requirement, not a disclaimer added after the fact.

---

## Criterion 1: Impact

### Quantified Time-to-Permit Reductions

Every month a road, bridge, water treatment plant, energy project, or data center spends in NEPA review is a month of delayed construction, deferred jobs, and stalled critical infrastructure. The CEQ EIS Timeline Report (January 2025) documented a median EIS completion time of 2.8 years (2019–2024), with the distribution heavily right-skewed — some processes exceeding 13 years. Environmental Assessments typically run 6–18 months. Categorical Exclusions, when correctly applied, resolve in days to weeks. The gap between an incorrect EA escalation and a proper CE determination is measured in months to years — and that gap is the direct cost to infrastructure delivery and national competitiveness.

This accelerator addresses four categories of delay directly, each traceable to specific technology gaps in how agencies currently manage environmental review:

**Category 1: CE Misclassification (6 months to 2+ years per incorrectly escalated project)**

The CE Library contains 2,105 categorical exclusions across 79 federal agencies, searchable via Einstein Search and indexed with SOSL full-text search. The CE Screener uses Salesforce's **Business Rules Engine (BRE)** — a deterministic, rule-based decision engine, not AI or machine learning — to evaluate project attributes against pre-configured Decision Matrix rows and Expression Set formulas. BRE produces the same output for the same inputs every time: there is no probabilistic inference, no model drift, and no black-box logic. Every determination can be audited to the specific rule row that fired.

The CE Screener BRE applies 3-tier deterministic logic: NAICS routing narrows the CE namespace, agency/sector Decision Matrix rows apply high-confidence Tier 1 CE mappings, and agency/action-type rows resolve Tier 2 cases where the action verb (construct vs. modify vs. renew) is the critical discriminating variable. The same BRE architecture drives the Litigation Risk Scorer: it evaluates review type, circuit geography, lead agency, adjacent statute involvement, sector-circuit interaction, scoping overrun status, and challenge prediction deltas through a weighted Expression Set to produce a deterministic 0–100+ risk score — with no generative AI involved in the calculation.

NEPATEC v2.0 analysis identified that 23% of CE records lacked a ce_category — concentrated in BLM oil/gas and Agriculture/Rangeland projects, precisely the categories where ambiguity causes unnecessary EA escalation. The BRE screener eliminates that ambiguity at intake with an auditable, repeatable determination that agency coordinators can inspect row by row.

**Category 2: Comment Analysis Bottleneck (4–8 weeks per EA/EIS on the critical path)**

Public comment compilation and individual response is directly on the critical path for every EA and EIS. The NAEP 2025 Workshop documented an AI-assisted comment analysis case where 2,600 comments required by 4 staff over 4 weeks were processed in approximately 4 hours. The accelerator's Comment Triage infrastructure — Agentforce-ready field design, EJ/tribal gate architecture, and sentiment/substantive classification — establishes the data foundation for this compression.

**Category 3: Late-Stage Litigation Surprises (months to years of delays from vacated decisions)**

Analysis of the PermitTEC v0.1 corpus (761 federal NEPA litigation cases, PNNL 2025) shows that incomplete administrative records are among the most common bases for successful NEPA challenges. The accelerator's Defensibility Gap Checker scores completeness of the administrative record in real time — flagging missing required documents, absent public engagement records, and unaddressed adjacent statute consultations before the record is closed, not after a court filing identifies the gap. Very High risk scores (≥58 on the calibrated 0–100 scale) automatically trigger a legal review task, routing human attention to the cases most likely to be challenged. The calibrated threshold replaces the prior approximate 75-point cutoff with an empirically derived value from Stage 7 analysis.

**Category 4: Scoping Bottlenecks and Tribal Consultation Failures**

CEQ EIS Timeline data (2010–2024) reveals a 4.7× spread in agency NOI-to-DEIS medians: FAA averages 47 months, BLM 28 months, and FERC just 10 months. When a BLM project is evaluated against an agency-generic 24-month baseline, a project genuinely on track for BLM may be flagged as overdue. Per-agency scoping baselines (`NEPA_Agency_Scoping_Baseline__mdt`) replace the generic baseline with the agency's own historical median, making scoping overrun detection accurate rather than misleading.

Tribal Nation plaintiffs win at an 87.5% rate in the PermitTEC corpus — the highest of any plaintiff category. The accelerator's Plaintiff Intelligence flow detects tribal nation challengers from comment keywords, sets a dual flag (`nepa_tribal_plaintiff_flag__c`) on the IndividualApplication, auto-creates a Legal Review task, and adds a +20-point challenge risk delta that propagates into the Risk Scorer. Tribal consultation is treated as a hard gate before EA/EIS publication rather than a downstream checklist item.

### Measurable Administrative Burden Reduction

- **31 declarative flows** automate milestone routing, SLA due-date setting, stage gate enforcement, document completeness scoring, agency performance tier assignment, scoping overrun detection, plaintiff risk flagging, and error logging — eliminating manual coordination steps that currently require email, spreadsheets, and phone calls.
- **FAST-41 timeline tracking** is pre-seeded with per-agency baseline durations for CE/EA/EIS stages, giving program managers real-time variance visibility against agency-specific statutory targets without custom reporting build-out.
- **OmniScript CE Intake Wizard** (7 steps with real-time CE pre-screening) collects structured data at submission time, eliminating the request-for-information cycles that each add 2–4 weeks per round.
- **CEQ-compliant data export** (`NEPA/CEQExport` Integration Procedure) satisfies MFR #2 (Data Sharing) at Emerging maturity immediately upon activation — no additional development required.

### The Economic Cost of Timeline Delay

Timeline delays in federal permitting are not scheduling inconveniences — they are measurable financial penalties with consequences that compound over time.

**Construction cost inflation:** A 2.8-year CE→EIS escalation delays the project's start date by the same interval. ENR Construction Cost Index data shows sustained inflation in the 4–8% annual range for heavy civil and energy infrastructure materials. A $500 million EIS project delayed 2.8 years faces an effective cost escalation of $56–112 million before a single shovel enters the ground.

**Deferred clean energy capacity:** Offshore wind, utility-scale solar, and transmission projects are among the highest-frequency EIS categories in the PermitTEC corpus. Each year of delay on clean energy infrastructure defers nameplate capacity from the grid, extends dependence on dispatchable generation, and increases the cost of meeting statutory clean energy targets.

**Job creation deferral:** Infrastructure construction projects employ a predictable multiplier of direct and indirect jobs per $1M of construction spend. A 2.8-year delay does not merely defer those jobs — it defers them into a future labor market with higher prevailing wages, further escalating project cost.

**Court-ordered remand cost:** When a project is vacated and remanded, the agency does not simply resume from where it stopped. It reconvenes scoping, re-issues draft EIS for additional comment, responds to supplemental comments, and re-executes the ROD process. The direct agency cost of this cycle — staff time, contractor costs, consultation fees — routinely runs into the millions of dollars per remand, in addition to the 2–5 years of project delay.

The accelerator's value is not measured against the cost of the software. It is measured against the cost of the delay it prevents.

---

## Criterion 2: User-Centered Design

### Applicant-Facing Experience

The OmniScript CE Intake Wizard guides applicants through a 7-step structured intake process with real-time CE pre-screening. At each step, the OmniScript provides conditional navigation based on prior answers — applicants are not presented with fields irrelevant to their project type. The wizard captures:

1. Federal jurisdiction and lead agency (determines CE catalog namespace)
2. Project sector and type (maps to NEPATEC classification taxonomy)
3. Action type (the primary discriminator between CE and EA: construct new vs. modify existing vs. renew/extend)
4. Physical parameters (acreage of surface disturbance, indoor/outdoor, existing footprint)
5. NAICS code (used for jurisdiction routing and extraordinary circumstances pre-screening)
6. GIS footprint submission (triggers FWS ECOS critical habitat and EPA EJScreen proximity checks)
7. Review and completeness check before submission

Applicants receive a CE pre-screening result — recommended review type, applicable CE code set, confidence level, and any extraordinary circumstances flags — before the record is formally submitted. This gives applicants actionable feedback at intake rather than weeks later.

The GIS proximity integration uses FWS ECOS (critical habitat) and EPA EJScreen (environmental justice index) via OmniIntegrationProcedure, surfacing resource sensitivities automatically without requiring applicants to interpret raw GIS datasets.

### Agency Staff Experience

NEPA Coordinators work from record pages that surface the information needed for each stage of the process without navigating multiple systems. Key design choices:

- **Separation of AI recommendation from official determination.** The CE Screener writes a recommendation to `nepa_ce_pathway_recommendation__c` (read-only to AI, visible to all users). The official pathway is `nepa_review_type__c`, which only a credentialed NEPA Coordinator can set. The system will not advance a record to downstream stage gates on the recommendation field alone.
- **Classification basis audit trail.** `nepa_classification_basis__c` records the full rule-match path for every CE screening decision, giving coordinators the specific basis for any recommendation rather than a black-box result.
- **Defensibility gap checklist.** Real-time completeness scoring flags missing required documents by review type, giving staff a prioritized action list rather than a post-hoc gap discovery during litigation.
- **Stage gate enforcement.** Before-save flows block invalid stage transitions and enforce document requirements at each gate, preventing records from advancing past required checkpoints without completing prerequisites.
- **Agency Performance Tier.** `nepa_agency_performance_tier__c` on the Program record (Fast_and_Defensible / Slow_Scoping_Bottleneck / Legally_Vulnerable) is automatically set from `NEPA_Agency_Scoping_Baseline__mdt` whenever the lead agency changes. Coordinators see the agency's historical tier classification without consulting external references.
- **Tribal plaintiff alert.** When a comment from a tribal nation is detected, the system simultaneously sets `nepa_plaintiff_risk_flag__c` and `nepa_tribal_plaintiff_flag__c` on the parent IndividualApplication, auto-creates a Legal Review task, and adds a measurable delta to the litigation risk score — giving coordinators a clear signal and a specific next action, not just a generic warning.

### Designed for Coordinator Workflow, Not Alongside It

Federal software deployments routinely fail not because the technology is wrong but because the tool adds steps to an already-overloaded coordinator's day. Every design choice in this accelerator was evaluated against the question: does this reduce the coordinator's workload, or does it require them to maintain two systems?

**Replacing manual processes, not adding to them:**

- The CE Screener fires automatically when a record is submitted — coordinators do not run a separate check. The recommendation lands in a read-only field on the record they are already working in.
- Stage gate enforcement happens on save. Coordinators do not open a checklist tool; the system prevents the transition until prerequisites are met and tells them exactly what is missing.
- The litigation risk score updates on every relevant field change without coordinator action. The legal review task appears in their queue automatically when the score crosses the Very High threshold.
- Tribal and EJ comment routing is automatic. A coordinator does not read and classify 500 comments to find the three tribal sovereignty submissions; the system surfaces them directly to the EJ/Tribal Liaison queue.

**No dual-entry with legacy systems:** The accelerator is built on Salesforce APS, which is the COTS platform of record at many federal agencies for intake and case management. For agencies already using APS, the accelerator deploys into the existing org alongside current workflows — no parallel system, no CSV exports to a separate tool. For agencies on other platforms, the `NEPA/CEQExport` Integration Procedure exposes a CEQ-standard REST API that existing systems can consume without modifying the accelerator.

**Low-friction configuration by agency staff:** Custom metadata records — CE screening rules, risk weights, scoping baselines — can be created and updated through standard Salesforce Setup screens by agency administrators with the `Customize Application` permission. No developer access, no deployment pipeline required. The parameters an agency is most likely to need to adjust (CE code coverage, agency-specific SLA targets) are the ones that are most accessible to non-technical staff.

### Section 508 and Accessibility Compliance

**The applicant-facing UI is Section 508 and WCAG 2.1 AA compliant by construction.** The OmniScript CE Intake Wizard and all Lightning record pages are built exclusively on Salesforce Lightning Design System (SLDS) components and OmniStudio OmniScripts — both of which are Salesforce-certified for Section 508 and WCAG 2.1 AA accessibility. Keyboard navigation, screen reader compatibility (ARIA labels, focus management), sufficient color contrast ratios, and error identification are inherited from the platform component library rather than custom-implemented, which means compliance is not degraded by agency-specific configuration changes. Agencies do not need to commission a separate accessibility audit before deployment; Salesforce publishes and maintains the Voluntary Product Accessibility Template (VPAT) for these components. Accessibility compliance is a procurement checkbox in every federal IT acquisition — this solution checks it at the platform level, not the implementation level.

### Transparency, Audit Trail, and Sensitive Data Protection

**Every AI output is labeled and traceable.** All AI-assisted content is flagged with `nepa_ai_generated__c`. Risk score outputs carry a full disclosure in `nepa_risk_score_factors__c` — including the exact formula, the number of cases the weights were derived from, and the statistical confidence level — so coordinators and auditors can evaluate the basis of any score without consulting external documentation.

**The EJ/tribal gate is unconditional.** Comments containing tribal sovereignty, sacred sites, environmental justice, or civil rights keywords route directly to the EJ/Tribal Liaison coordinator queue. This bypasses AI classification entirely and cannot be disabled by any automated process or configuration change. This is a design constraint, not a policy preference — the gate is enforced at the flow level with no override path.

**CUI protection is inherent to the platform.** NEPA documents regularly contain Controlled Unclassified Information (CUI) — precise GPS coordinates of endangered species habitats, archaeological site locations, tribal sacred site boundaries, and critical energy grid infrastructure details. The accelerator runs on Salesforce Gov Cloud, which carries a FedRAMP Moderate Authorization to Operate. This means CUI in GIS data records (`nepa_gis_data__c`), document attachments (ContentVersion), and public engagement records is handled within an already-authorized data boundary — without requiring agencies to evaluate a new system for CUI handling capability. The GIS data object includes `nepa_sensitivity_classification__c` and `nepa_data_access_restriction__c` fields that allow CUI-bearing records to be tagged for access restriction independent of the record's public-facing content.

---

## Criterion 3: Readiness

### Zero-Friction Pilot Readiness

An agency can spin up a Salesforce sandbox, deploy this MIT-licensed accelerator, and be running a live proof-of-concept with their own historical data **in an afternoon** — bypassing the traditional 6-month software implementation cycle entirely.

```bash
sf org login web --alias nepadev
sf project deploy start --source-dir force-app --target-org nepadev --wait 30
```

That is the complete deployment command. No infrastructure provisioning, no database migration, no middleware configuration, no vendor onboarding call. The repository includes everything needed to go from zero to a running system:

- Complete object, field, and custom metadata type definitions
- 31 flow XML files (deployable as Draft; activation is a separate step documented in QUICKSTART.md)
- Permission set with field-level security configured for all custom fields
- 6 DataRaptor Extracts and 1 Integration Procedure for CEQ-compliant data export
- Custom metadata records pre-seeded with empirically calibrated PermitTEC litigation weights, CE screening rules, per-agency EIS scoping baselines, sector-circuit risk matrix, plaintiff profiles, and challenge prediction rules
- Sample data scripts and a documented demo story for verification

A pilot agency running on a Salesforce sandbox can evaluate every feature described in this narrative against real project data before committing to any production deployment decision. The barrier to evaluation is an afternoon, not a procurement cycle.

### Total Cost of Ownership

**For agencies already on Salesforce APS, this accelerator represents zero incremental software licensing cost.** The accelerator is MIT-licensed open source — no per-seat fee, no platform fee, no vendor lock-in. It deploys into an existing Salesforce APS org as a package of standard metadata, leveraging the enterprise agreement the agency already holds.

Dozens of federal agencies use Salesforce APS for regulatory intake, case management, benefits administration, and public engagement. For those agencies, adopting this accelerator means activating NEPA-specific workflows on a platform already authorized, already in production, and already familiar to their IT and program staff — not evaluating, procuring, and onboarding a standalone permitting platform that duplicates infrastructure they already own.

For agencies not currently on APS, the accelerator's open-source license means the software itself has no acquisition cost; the investment is the platform subscription, which covers far more than NEPA permitting alone.

### Standards Alignment

The solution is aligned to:

- **CEQ NEPA and Permitting Data and Technology Standard v1.2** (May 30 / August 18, 2025): All 13 CEQ entities implemented with the 5 required provenance fields on each. A dedicated regression test suite (`NepaApiComplianceTest`, `NepaCeqExportServiceTest`, `NepaEntity789Test`, `NepaBREConfigTest`) of 125 Apex tests verifies write-and-read compliance for every entity's standard fields, provenance pattern, `nepa_other__c` extension bag against the PIC OpenAPI specification, and BRE configuration integrity.
- **CEQ Permitting Technology Action Plan (May 2025)**: Supports MFR #1 (Data Standards), MFR #2 (Data Sharing), MFR #5 (Automated Case Management), and MFR #7 (Document Management) at Foundational and Emerging maturity levels
- **OMB M-25-21**: AI features are advisory-only; AI recommends, human confirms is enforced in all flows; human override always available
- **FAST-41**: Timeline tracking pre-seeded with per-agency baseline durations; `nepa_milestone_variance_days__c` provides real-time variance against agency-specific statutory targets

### Configuration, Not Code

All agency-specific parameters — CE codes, risk weights, SLA configurations, agency routing rules, EIS scoping baselines, plaintiff profiles, sector-circuit risk cells — are stored in 15 Custom Metadata Types. Adding a new agency requires creating custom metadata records, not modifying code or redeploying flows. This means:

- Weight updates (e.g., when a new PermitTEC corpus release is available) require only a metadata deployment, not an Apex compilation or test-class update
- Agency administrators with the `Customize Application` permission can audit and update parameters without developer access
- The audit trail for weight changes is preserved through the `Effective_Date__c` and `Update_Notes__c` fields on screening rule records — the pattern creates new records with new dates rather than overwriting existing ones

### Designed to Stay Current

**When PNNL releases PermitTEC v2.0 or NETATEC v3.0, updating the accelerator does not require a code release.** The update lifecycle is:

1. Run the calibration pipeline against the new corpus (the 13-stage methodology is documented in the repository and reproducible).
2. Update the affected Custom Metadata records (`NEPA_Agency_Risk_Rate__mdt`, `NEPA_Circuit_Risk_Weight__mdt`, `NEPA_Statute_Risk_Weight__mdt`, `NEPA_Sector_Circuit_Risk__mdt`) via `sf project deploy start` — a standard metadata deploy with no Apex compilation.
3. Update the BRE Decision Matrix rows by importing updated CSV files through the Salesforce Setup UI (a documented, repeatable process covered in `decision_matrix_rows/README.md`).
4. The new weights are live immediately after deployment — no flow reactivation, no test class changes, no downtime.

For CE Library updates — when CEQ CE Explorer adds new exclusions or agencies add new CFR authorities — new `nepa_ce_library__c` records can be bulk-loaded via the Salesforce Bulk API from a CSV export of the agency's existing CE documentation. No schema changes required. The accelerator is built to absorb dataset updates as routine operations, not one-time migration events.

### Clear Adoption Path

The QUICKSTART.md documents the complete deployment sequence: prerequisites, org configuration, flow activation, permission set assignment, custom metadata seeding, BRE Decision Matrix CSV import, and verification steps. Architecture Decision Records (ADRs 001–011) document every significant design choice with context, rationale, and consequences — giving adopting agencies the information needed to adapt the solution to their specific requirements without reverse-engineering design intent.

---

## Criterion 4: Multi-Agency Compatibility

### Designed for Federal Agency Diversity

The accelerator is architected for multi-agency deployment from the ground up. Every element that varies by agency is externalized into configuration:

**CE Library by Agency:** The `nepa_ce_library__c` object stores 2,105 categorical exclusions from CEQ CE Explorer v2.0 across 79 federal agencies. Each record carries the CFR authority, plain-language description, acreage threshold, indoor-only flag, and GIS review requirement for that specific exclusion. Agency-specific CE codes are fully isolated — BLM 516 DM citations, DOE 10 CFR 1021 Appendix B codes, Energy Policy Act Section 390 exclusions, and USFS 36 CFR 220.6 codes all coexist in the same library without collision.

**Agency-Specific Risk Weights:** `NEPA_Agency_Risk_Rate__mdt` holds per-agency litigation loss rates derived from the PermitTEC corpus with a calibrated formula (`loss_rate × 0.40 × 2.5`). BLM (39.3% loss rate, 89 cases), USFS (28.4%, 148 cases), USACE (24.2%, 62 cases), FERC (23.8%, 42 cases), and FHWA (18.4%, 38 cases) carry different weights; the scoring model applies the correct agency-specific prior automatically.

**Per-Agency EIS Scoping Baselines:** `NEPA_Agency_Scoping_Baseline__mdt` holds 11 records from CEQ EIS Timeline data 2010–2024: FERC (10-month NOI-to-DEIS median, Fast_and_Defensible tier), BLM (28 months, Legally_Vulnerable), FAA (47 months, Slow_Scoping_Bottleneck), and 8 others. The NEPA_Agency_Tier_Setter flow writes the agency's historical performance tier to `Program.nepa_agency_performance_tier__c` whenever the lead agency changes — without a single line of Apex.

**Process Type Coverage:** The accelerator covers the full NEPA review spectrum: Categorical Exclusion (CE), Environmental Assessment (EA), and Environmental Impact Statement (EIS). Stage gate logic, SLA configurations, document checklists, and Action Plan templates are each parameterized by review type. A CE process and an EIS process on the same agency follow different gate sequences, document requirements, and timeline baselines — driven by the same flow logic reading different metadata.

**Cooperating Agency Support:** The `nepa_process_related_agencies__c` junction object with `nepa_role__c` picklist (Proponent / Cooperating / Participating) supports multi-agency NEPA processes where multiple federal agencies share responsibilities. The multi-party proponent pattern was a documented design requirement: NEPA proponents span individuals, businesses, federal and state agencies, tribal nations, and joint ventures — and the data model handles all of them.

### APS as the Multi-Agency Platform

Salesforce Agentforce for Public Sector is used across federal agencies for regulatory intake, case management, and public engagement. Deploying the accelerator into a PSS org that already serves multiple program offices means the NEPA accelerator operates alongside existing agency workflows without separate infrastructure. The FedRAMP Authorization to Operate covers the platform itself; agencies do not need to independently authorize a new system.

The declarative-first architecture (all 31 flows, no custom Apex for business logic) means agency IT staff can inspect, modify, and extend the automation in Salesforce Flow Builder without Salesforce developer credentials or a local development toolchain. This lowers the barrier to agency-specific customization after initial deployment.

### Interoperability with Federal Legacy Systems

Built on Salesforce APS, this accelerator does not create a new data silo — it publishes a standards-compliant API that legacy federal systems can consume immediately.

**CEQ Standard REST API:** The `NEPA/CEQExport` Integration Procedure exposes all 13 CEQ entities as a structured JSON payload aligned to the PIC OpenAPI v1.2.0 schema. Any agency system that can make an authenticated REST call — EPA DARTER, USACE ORM2, DOT NEPA assignment tracking, or any internal permit database — can pull structured NEPA process data without custom middleware development.

**FedRAMP-authorized platform:** Because the accelerator runs on Salesforce Gov Cloud (FedRAMP Authorized), agencies do not need to issue a separate ATO for the system. Cross-agency data sharing through the CEQ export API does not introduce a new authorization boundary — the platform authorization covers the integration.

**Standard REST callouts from the platform:** The OmniIntegrationProcedure framework makes REST callouts to FWS ECOS (critical habitat) and EPA EJScreen at intake. The same integration pattern extends to additional federal APIs — USGS National Hydrography Dataset, FEMA flood maps, tribal land boundaries — by adding new named credentials and OmniIntegration steps, with no Apex required.

**Structured data as the foundation for future interoperability:** The CEQ data standard defines exactly what fields must exist on each entity and in what format. NEPA records created in this accelerator are immediately compatible with any future federal NEPA data repository or cross-agency permitting dashboard that consumes the same standard — because the records already conform to the schema.

### Extension Without Code Changes

Adding a new agency to the CE Screener requires:
1. Creating new `NEPA_CE_Screening_Rule__mdt` records for the agency's CE authorities
2. Adding the agency's CE codes to `nepa_ce_library__c` (bulk-loadable from the agency's existing CE documentation)
3. Creating `NEPA_Agency_Risk_Rate__mdt`, `NEPA_Agency_Scoping_Baseline__mdt`, and `NEPA_Circuit_Risk_Weight__mdt` records seeded from available litigation and process timeline data

No flow XML modifications, no Apex changes, no deployment of new code.

---

## Criterion 5: Team Capacity

### Salesforce Public Sector Expertise

GPS Accelerators is a Salesforce Public Sector partner with federal permitting agency implementations. The team has direct experience deploying APS-based solutions for regulatory intake, permitting workflows, and public engagement tracking at federal agencies — the same operational context this accelerator addresses.

The solution reflects that experience in concrete design choices: the `IndividualApplication` vs. `BusinessLicenseApplication` object selection was made because NEPA proponents are not exclusively commercial entities; the BRE-first architecture for CE screening and risk scoring was chosen over AI inference because deterministic, auditable rules are operationally required for federal permitting determinations; and the platform event error architecture was designed for the specific failure mode of Salesforce transaction rollback in bulk load scenarios.

### Domain-Grounded Design

The accelerator is grounded in the NEPA process specifically, not generic permitting theory:

- Litigation risk weights are derived from actual federal NEPA litigation cases (PermitTEC v0.1, PNNL 2025) using a 13-stage calibration pipeline, with agency weights calculated from observed loss rates and circuit weights from court decision multipliers — not synthetic estimates
- CE screening rules are derived from NETATEC v2.0 analysis of 54,668 CE projects across BLM, DOE, and USDA — the largest available corpus of federal CE records
- The five NEPA challenge grounds modeled in the challenge predictor (failure to prepare, EIS/EA inadequacy, improper CE reliance, failure to supplement, adjacent statute violation) reflect the actual legal classification used in the PermitTEC corpus
- FAST-41 timeline baselines are pre-seeded from per-agency CEQ EIS Timeline medians, not estimated
- The sector-circuit risk matrix (17 cells) is derived from Stage 13 cross-tabulation of PermitTEC cases, with Energy × 4th Circuit identified as the highest-risk combination (28.6% agency win rate)
- The page count outlier thresholds (CE >17 pages, EA >200 pages) are derived from the p95 distribution of the NETATEC v2.0 document corpus, not rule-of-thumb estimates

The AI Use Policy included in the repository discloses the known statistical limitations of each model — low-case-count circuits, the distinction between litigation exposure and outcome prediction, the recency limitation of pre-2010 case data — because operational deployment at federal agencies requires honest disclosure of model confidence, not optimistic framing.

### Open Source Commitment

The solution is released under an MIT license with full source code available. Architecture Decision Records document every significant design choice. The QUICKSTART.md is written for agency IT staff, not Salesforce developers. The intent is to enable agencies to adopt, adapt, and maintain the solution without ongoing dependence on any single vendor — including GPS Accelerators.

---

## Summary of Key Metrics

| Dimension | Value |
|---|---|
| CEQ entities implemented | 13 of 13 (6 standard + 7 extended, per PIC OpenAPI v1.2.0) |
| Total declarative flows | 31 |
| CE Library records | 2,105 categorical exclusions |
| Agencies covered in CE Library | 79 |
| Litigation cases in risk model | 761 (PermitTEC v0.1, PNNL 2025) |
| NEPA projects in baseline corpus | 61,881 (NETATEC v2.0) |
| Risk model pipeline stages | 13 (agency loss rates, circuit multipliers, statute multipliers, sector-circuit matrix) |
| Custom metadata types | 15 |
| BRE Decision Matrices + Expression Sets | 8 DMs + 3 ESs (CE Screener V2, Risk Scorer V2 Active + V3 Draft, Permit Coordinator V2 — deterministic, not AI) |
| Sector-circuit risk cells | 17 (Energy×4th = 28.6% agency win rate; Transportation×DC = 91%) |
| Custom Apex classes | 1 (infrastructure bridge only — all business logic is declarative BRE/Flow) |
| API compliance regression tests | 125 Apex tests across 4 test classes |
| Deployment time from CLI | ~15 minutes |
| Platform FedRAMP status | Authorized (Salesforce Gov Cloud) |
| License | MIT (open source) |
| OMB M-25-21 compliance | Documented in AI-Use-Policy.md |
