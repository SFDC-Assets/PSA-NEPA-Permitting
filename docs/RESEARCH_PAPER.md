# Quantifying Federal NEPA Permitting Risk: An AI-Assisted Analysis of Timelines, Litigation Patterns, and Scoping Bottlenecks

**Shannon Schupbach**  
*Published: May 2026*

---

## Executive Summary

This report presents a systematic, data-driven analysis of federal permitting under the National Environmental Policy Act (NEPA), drawing on three complementary corpora: 120,000+ NEPA documents spanning Categorical Exclusions (CEs), Environmental Assessments (EAs), and Environmental Impact Statements (EISs); 761 federal court cases challenging NEPA decisions; and 1,903 Final EIS timeline records from the Council on Environmental Quality (CEQ). An AI-assisted 13-stage analysis pipeline extracts, calibrates, and synthesizes findings across these datasets.

**Five headline findings for policymakers:**

1. **Scoping is the bottleneck, not public review.** Across 34 of 36 federal agencies, the pre-DEIS scoping phase (NOI→DEIS) consumes 60–75% of total EIS time. Cutting public comment or review periods has minimal leverage; upstream scoping reform is where time is lost.

2. **A 2-year statutory scoping cap would save nearly 2,000 agency-years.** Under a 24-month NOI→DEIS cap, 849 projects (44.8% of the 2010–2024 corpus) would be affected, saving an estimated 1,987 agency-years at an average of 28 months per project. FHWA (118 projects, 37 months saved), NPS (82 projects, 84% exceedance rate), and USACE (102 projects, 42 months saved) are the priority targets.

3. **NEPA timelines improved 49% since the 2016 peak.** Median NOI→ROD duration fell from 4.46 years in 2016 to 2.28 years in 2024. FAST-41, One Federal Decision, and the CEQ 2023 rule changes appear to be working; sustaining these gains requires statutory codification.

4. **Speed and legal defensibility are positively correlated.** Fast agencies win more litigation. FERC (1.88-year median, 74% agency win rate) and BOEM (2.24 years, 100% win) substantially outperform slow agencies like USFWS (4.38 years, 54% win) and Bureau of Reclamation (4.69 years, 50% win). The assumption that slow processes produce more defensible records is empirically false.

5. **Sector × circuit interaction is the strongest litigation risk predictor.** Energy projects in the 4th Circuit face a 28.6% agency win rate — the single highest-risk cell in the analysis. Transportation projects in the DC Circuit achieve a 90.9% win rate — the safest. The same sector can span a 3× range in litigation outcomes depending solely on venue.

---

## 1. Introduction

### 1.1 Background

The National Environmental Policy Act of 1969 (42 U.S.C. §4321 et seq.) requires federal agencies to evaluate the environmental consequences of proposed actions before making decisions. This review takes one of three forms depending on anticipated significance: a Categorical Exclusion (CE), which applies where a class of action has been determined not to have a significant effect and no extraordinary circumstances are present; an Environmental Assessment (EA), which evaluates whether significant impacts may occur and terminates in either a Finding of No Significant Impact (FONSI) or a requirement to prepare a full EIS; or an Environmental Impact Statement (EIS), which is required for actions with significant environmental effects and involves notice of intent (NOI), scoping, a Draft EIS (DEIS), public comment, a Final EIS (FEIS), and a Record of Decision (ROD).

NEPA litigation is a structurally important feature of this process. Challengers — typically environmental organizations, industry associations, tribal nations, or state governments — can challenge agency decisions at each tier. Case outcomes establish judicial precedents that constrain agency practice. Yet despite the volume and significance of this litigation, there has been no systematic, cross-agency, machine-readable analysis of what factors predict litigation loss, how timeline length relates to legal defensibility, and which regulatory statutes and federal circuits carry the greatest risk.

### 1.2 Problem Statement

Federal agencies face permitting decisions with limited empirical guidance. Individual agency experience is siloed. CEQ publishes aggregated timeline statistics but not cross-referenced litigation outcomes. No publicly available analysis combines NEPA document characteristics, judicial outcomes, and timeline data into an integrated quantitative framework that practitioners can act on.

The result: agencies with poor litigation track records (BLM: 39.3% loss rate) continue practices similar to agencies with excellent ones (FERC: 25.9% loss rate), without systematic evidence of what distinguishes them. Project sponsors filing in high-risk circuits (10th Circuit: 1.45× loss multiplier) receive no venue-specific guidance. Statutory reform proposals lack empirical grounding for where caps and deadlines would have the most impact.

### 1.3 Contribution

This report provides the first integrated, cross-agency quantitative analysis of federal NEPA permitting risk by combining three public datasets — NEPATEC 2.0, PermitTEC v0.1, and CEQ EIS Timeline Data 2010–2024 — through a reproducible 13-stage AI-assisted pipeline. Specific contributions include:

- A **CE/EA/EIS classification feature matrix** with sector-level EIS probability scores and CE code screening rules derived from 120,000+ NEPA documents
- A **35-row interagency permit prediction matrix** mapping project sector, type, lead agency, and location to cooperating agencies, required permits, and EIS likelihood
- **Composite litigation risk scores** calibrated from 684 federal court cases, incorporating agency loss rates, statute multipliers, circuit multipliers, and sector×circuit interaction terms
- A **scoping cap impact model** showing projected time savings at 1-, 2-, and 3-year cap levels across 1,897 CEQ EIS records
- A **sector × circuit win-rate matrix** quantifying the interaction between project sector and federal circuit across 684 litigation cases

All analysis code, prompts, and dataset pointers are provided for full reproducibility (Section 7).

---

## 2. Datasets

### 2.1 NEPATEC 2.0

**Source:** Pacific Northwest National Laboratory (PNNL), funded by the U.S. Department of Energy Office of Energy Efficiency and Renewable Energy.  
**Access:** Hugging Face — `PNNL/NEPATEC2.0`  
**License:** CC0-1.0  
**Local path:** `NEPATEC2.0/`

NEPATEC 2.0 is a corpus of 61,881 NEPA projects (120,000+ documents, 6.97 million pages) organized by process type and lead agency. This analysis uses nine strata: CE, EA, and EIS records from BLM, DOE, and USDA, plus EIS records from EPA.

| Process Type | Projects (corpus) | Strata Used |
|---|---|---|
| CE | 54,668 | BLM, DOE, USDA |
| EA | 3,083 | BLM, DOE, USDA |
| EIS | 4,130 | BLM, DOE, EPA |

Each record contains structured project metadata (process type, agency, sector, project type, location, CE code, page count) and document-level data. The pipeline uses a stratified sample of 1,489 records (see Section 5.1) rather than the full corpus, with the sample cache stored in `samples/` as JSONL files.

### 2.2 PermitTEC v0.1

**Source:** Pacific Northwest National Laboratory (PNNL), funded by the U.S. Department of Energy.  
**Access:** Hugging Face — `PNNL/PermitTECv0.1`; also available as `PermitTECv0.1/dataset.json` in this repository  
**License:** CC0-1.0  
**Local path:** `PermitTECv0.1/dataset.json`  
**Citation:** Bhattacharjee et al. (2026). *Permitting Text Corpus (PermitTEC) v0.1.* Hugging Face.

PermitTEC v0.1 is a curated metadata corpus of 761 federal court cases related to NEPA and adjacent environmental statutes (ESA §7, CWA §404, NFMA, NGA §7, FLPMA). Case metadata was extracted using LLM-assisted pipelines and validated through human annotation. The `prevailing_party` field records `Agency`, `Challenger`, or `Cannot be determined` for each case.

**Linkage to NEPATEC.** Each PermitTEC record includes a `nepatec_project_uuid` field where a match to a NEPATEC project was identified. Of 761 cases:

| Linkage Status | Cases | % |
|---|---|---|
| Mapped to NEPATEC v2.0 project | 223 | 29.3% |
| No NEPA document challenged | 197 | 25.9% |
| NEPA challenge — not in NEPATEC | 341 | 44.8% |

The pipeline joins PermitTEC to NEPATEC via `nepatec_project_uuid` for stages requiring document-level context (Stages 4, 9). For litigation statistics (Stages 7, 10, 11, 12, 13), all 761 cases are used after filtering 77 records with ambiguous outcomes, yielding a working sample of 684 usable cases.

**Case metadata provenance.** Human annotators validated all records against source court documents. Fields are tagged with one of three provenance values: `llm_extracted_and_manually_validated`, `llm_extracted_and_manually_corrected`, or `llm_extracted_no_manual_review`. Citation accuracy is 53.9% LLM-extracted (46.1% manually corrected); plaintiff accuracy is 75.7% LLM-extracted (24.3% corrected).

### 2.3 CEQ EIS Timeline Data 2010–2024

**Source:** Council on Environmental Quality (CEQ), Executive Office of the President  
**Access:** Download from `https://ceq.doe.gov/docs/nepa-practice/CEQ_EIS_Timeline_Data_2024_1_13_2025.xlsx`  
**License:** U.S. Government public domain  
**Local path:** `ceq_eis_timelines.xlsx`

The CEQ EIS timeline dataset contains 1,903 Final EIS records from 2010–2024, with dates for NOI publication, DEIS publication, FEIS publication, and ROD issuance. The analysis computes derived duration fields (NOI→DEIS as proxy for scoping phase duration; DEIS→FEIS as proxy for review phase duration; NOI→ROD as total timeline) and aggregates by agency, state, and year.

Coverage is limited to Final EIS records. CE and EA timeline data is not included in this dataset. The 2024 cohort (n=51) is smaller than earlier years (2010: n=192), which may reflect right-censoring of slow ongoing projects or a genuine reduction in EIS initiations.

### 2.4 Dataset Integration

Three integration steps connect the datasets:

1. **PermitTEC → NEPATEC (UUID join):** Direct match via `nepatec_project_uuid`. Used in Stages 4 and 9.
2. **PermitTEC → CEQ (regex agency match):** Defendant text in PermitTEC cases is mapped to CEQ agency abbreviations using a 19-agency regex table (e.g., "Bureau of Land Management" → "BLM"). Used in Stages 12 and 13.
3. **Stage output chaining:** Each stage reads outputs from prior stages (e.g., Stage 7 litigation weights are used in Stage 13 risk score v2 construction).

---

## 3. Methodology

### 3.1 Pipeline Architecture

The analysis is implemented as a 13-stage Python pipeline across two orchestrator files:

- `pipeline.py` — Stages 1–5: feature engineering, CE ambiguity resolution, permit matrix construction, litigation guardrail extraction, Salesforce translation
- `pipeline_extended.py` — Stages 6–13: timeline risk profiling, litigation weight calibration, CE code catalog, document registry, plaintiff intelligence, geographic risk mapping, CEQ timeline cross-analysis, scoping cap model

**LLM-driven synthesis.** Each stage constructs a structured system prompt (stored in `prompts/`) and user prompt incorporating Python-preprocessed data. Prompts are sent to `claude-opus-4-7` via the Anthropic API with `MAX_TOKENS_RESPONSE = 16,000`. The model returns structured JSON or Markdown; responses are parsed via `utils/output_parsers.py`. Prompt caching (Anthropic's cache-control headers) is used for multi-batch stages to reduce cost and latency.

**Python statistical preprocessing.** Quantitative results — medians, win rates, percentile thresholds, loss rate tables, sector×circuit matrices — are computed in Python before the LLM sees the data. The LLM's role is synthesis, interpretation, and rule generation from structured statistical inputs, not raw calculation. This design prevents LLM arithmetic errors from contaminating quantitative outputs.

**Stratified sampling.** The NEPATEC corpus is not read in full. A stratified sample cache is built by `sample_data.py` targeting proportional representation across process types and agencies. Sample targets: 560 CE/BLM, 761 CE/DOE, 50 CE/USDA, 50 EA/BLM, 50 EA/DOE, 50 EA/USDA, 100 EIS/BLM, 100 EIS/DOE, 100 EIS/EPA (rounded to available records). The sample files are stored in `samples/` as JSONL.

### 3.2 Stage-by-Stage Summary

| Stage | Name | Input Records | Method | Output |
|---|---|---|---|---|
| 1 | Feature Engineering | 1,489 NEPATEC sampled records | Batch LLM extraction (500/batch); sector EIS probability matrix | `1_feature_engineering.json` |
| 2 | CE Code Ambiguity | 200 ambiguous CE records (18 agency/sector pairs) | Stratified sample of ambiguous (agency, sector) combinations; LLM statutory analysis | `2_ce_decision_tree.json` |
| 3 | Permit Matrix | 150 EIS/EA records | Pivot table [sector × type × agency × location]; LLM synthesis of 35 input combinations | `3_permit_matrix.json`, `3_permit_matrix.csv` |
| 4 | Litigation Guardrails | 223 PermitTEC cases (UUID-linked) | Outcome normalization; LLM procedural failure extraction from matched cases | `4_litigation_guardrails.json` |
| 6 | Timeline Risk Profile | 1,489 NEPATEC records | Page count percentiles (p50/p75/p90/p95) by process type; outlier flagging | `6_timeline_risk_profile.json` |
| 7 | Litigation Risk Weights | 684 usable PermitTEC cases | Per-agency, per-statute, per-circuit loss rate computation; composite risk score formula v1 | `7_litigation_risk_weights.json` |
| 8 | CE Code Catalog | 399 CE records (BLM/DOE/USDA) | Batch extraction capped at top-25 CE codes; 14 screening rules generated | `8_ce_code_catalog.json` |
| 9 | Document Registry | 50 records/stratum | Document-type sequence frequency analysis; blocking gate logic | `9_document_registry.json` |
| 10 | Plaintiff Intelligence | 684 cases (32 repeat filers identified) | Group-by plaintiff; stratified resample; LLM profiling of plaintiff strategy | `10_plaintiff_intelligence.json` |
| 11 | Geographic Risk Map | 761 cases (26 states with ≥4 cases) | State-level challenger win rate computation; regional clustering | `11_geographic_risk_map.json` |
| 12 | CEQ Timeline Cross-Analysis | 1,903 CEQ records + 761 PermitTEC cases | Median NOI→DEIS and DEIS→FEIS by agency; regex cross-join to litigation outcomes; bottleneck ratio; year-trend table | `12_ceq_timeline_cross.json` |
| 13 | Scoping Cap + Sector × Circuit | 1,897 CEQ records + 684 PermitTEC cases | Cap impact model (1/2/3-year); 7×12 sector×circuit win-rate matrix; composite risk score v2 | `13_scoping_circuit_risk.json` |

*Note: Stage 5 (Salesforce implementation translation) is excluded from this report's scope.*

### 3.3 Composite Litigation Risk Score

**Version 1 (Stage 7)** — calibrated from agency loss rates, circuit multipliers, and statute multipliers:

```
score_v1 = (agency_loss_rate_pct × 0.40)
         + ((circuit_risk_multiplier − 0.30) × 25)
         + (max_statute_risk_multiplier_bonus × 15)

Risk tiers:  LOW < 35  |  MEDIUM 35–44  |  HIGH 45–57  |  VERY HIGH ≥ 58

Example (HIGH risk): BLM + 10th Circuit + ESA §7
  = (39.3 × 0.40) + ((1.45 − 0.30) × 25) + (1.49 × 15)
  = 15.7 + 28.8 + 22.3 = 66.8 → VERY HIGH

Example (LOW risk): FHWA + 8th Circuit + no adjacent statute
  = (18.4 × 0.40) + ((0.75 − 0.30) × 25) + (1.0 × 15)
  = 7.4 + 11.3 + 15.0 = 33.6 → LOW
```

**Version 2 (Stage 13)** — extends v1 with scoping overrun and sector×circuit terms:

```
score_v2 = score_v1
  + (0.15 × Scoping_Overrun_Flag)
  + (0.10 × MIN(Projected_Scoping_Overrun_Months / 48, 1.0))
  + (0.20 × (1 − Sector_Circuit_Win_Rate / 100)
            × IF(Sector_Circuit_Case_Count ≥ 3, 1.0, 0.5))
```

The scoping overrun flag adds 15 points when a project's projected NOI→DEIS exceeds agency baseline. The sector×circuit term adds up to 20 points based on the empirical win rate for the project's sector-circuit cell (discounted by 50% when the cell has fewer than 3 observed cases).

---

## 4. Results

### 4.1 What Determines Process Type?

**Top predictive features for CE vs. EA/EIS classification (Stage 1).** Across 1,489 sampled records, five features carry the most predictive weight:

1. `ce_category` — presence of a CE code is the strongest predictor of non-EIS disposition (0.95 lift)
2. `project_type` — predicts process tier with ~73% accuracy alone
3. `title` — keyword signals (pipeline, dam, highway) elevate EIS probability
4. `description` — adds ~8% accuracy over title alone
5. `total_pages` — page count correlates with process complexity (0.68 lift)

**Sector EIS probability matrix.** Military and defense projects are 2.6× more EIS-prone than the government-wide average. Technology and data management projects almost never require an EIS:

| Sector | CE% | EA% | EIS% | n |
|---|---|---|---|---|
| Military, Defense & Emergency Response | 79.3% | 6.9% | **13.8%** | 58 |
| Agriculture & Natural Resource Management | 83.3% | 7.9% | 8.8% | 419 |
| Materials & Manufacturing | 85.4% | 6.7% | 7.9% | 164 |
| Environmental Policy & Regulation | 89.2% | 4.5% | 6.3% | 111 |
| Energy Production & Management | 88.7% | 6.0% | 5.3% | 586 |
| Transportation & Infrastructure | 90.6% | 4.2% | 5.3% | 741 |
| Water & Waste Management | 93.2% | 4.2% | 2.6% | 574 |
| Technology & Data Management | 98.4% | 0.0% | 1.6% | 64 |

**CE code ambiguity and extraordinary circumstances (Stage 2).** Among 200 ambiguous CE records (18 agency/sector pairs), the principal resolution mechanism is statutory thresholds: EPAct 2005 §390(b)(1) sets a 5-acre individual disturbance / 150-acre total lease ceiling for BLM oil and gas CEs; 36 CFR 220.6 sets a 250-acre vegetation alteration ceiling for USFS CEs. Six extraordinary circumstances triggers automatically escalate CE determinations to EA: Wild & Scenic River corridor (43 CFR 46.215(h)); Special Area designation (43 CFR 2932.5); T&E species habitat or sage-grouse PHMA (43 CFR 46.215(c)); Section 106 not concluded (54 U.S.C. 306108); tribal lands or ANCSA selected lands (E.O. 13175); and riparian or wetland disturbance (43 CFR 46.215(j)).

**CE code catalog (Stage 8).** The five highest-frequency CE codes across the BLM/DOE/USDA corpus are:

| Code | Agency | Description |
|---|---|---|
| BLM-516DM-11.9C8 | BLM | Temporary use permits / road construction < 1 mile |
| BLM-EPAct390-b1 | BLM | O&G operations < 5 acres surface disturbance |
| DOE-B3.6 | DOE | Small-scale research/laboratory operations |
| DOE-A9 | DOE | Construction/modification of small facilities |
| USFS-36CFR220.6e6 | USDA/USFS | Timber salvage sales < 250 acres |

Fourteen CE screening rules were generated from this corpus, with 5 sector complexity rules flagging elevated complexity when Energy + Water sectors co-occur.

### 4.2 The Interagency Permit Landscape

**Permit matrix (Stage 3).** Mapping 150 EIS/EA records across sector × project type × lead agency × location type produces a 35-row matrix of typical cooperating agency configurations, required permits, and EIS likelihood. Key observations:

- **Energy pipelines (FERC/DOE):** 6+ cooperating agencies (USACE, USFWS, EPA, USFS, BLM, SHPO); required permits include NGA §7 Certificate, CWA §404, CWA §401 WQC, Rivers & Harbors Act §10, ESA §7 Consultation, and FLPMA ROW Grant; 60% EIS likelihood; 24-month typical timeline.
- **Offshore energy (BOEM):** 95% EIS likelihood; 30-month typical timeline.
- **Routine USFS timber harvest (36 CFR 220.6):** 40% EIS likelihood; 8-month typical timeline.

**Statutory clustering.** NEPA is nearly always accompanied by ESA §7, CWA §404, and NHPA §106 for natural resource projects. ESA §7 is the single statute most predictive of litigation loss (Section 4.4).

### 4.3 Where Time Is Lost: The Scoping Bottleneck

**Scoping consumes 60–75% of total EIS time (Stage 12).** Analyzing 1,903 CEQ EIS timeline records across 36 agencies reveals a near-universal pattern: the pre-DEIS scoping phase (NOI→DEIS) takes far longer than the post-DEIS review phase (DEIS→FEIS). Only GSA shows a review-dominated bottleneck.

| Agency | NOI→DEIS (median yrs) | DEIS→FEIS (median yrs) | Scoping Ratio | NOI→ROD (median yrs) |
|---|---|---|---|---|
| FERC | 0.98 | 0.42 | 2.3× | **1.88** |
| TVA | 1.04 | 0.61 | 1.7× | **1.81** |
| BOEM | 1.25 | 0.82 | 1.5× | 2.24 |
| BLM | 1.94 | 0.96 | 2.0× | 3.79 |
| USFWS | 2.34 | 0.90 | 2.6× | 4.38 |
| USACE | 2.49 | 1.17 | 2.1× | 4.46 |
| NPS | **4.07** | 1.30 | **3.1×** | 6.27 |
| OSMRE | **4.36** | 0.90 | **4.8×** | 5.83 |
| FHWA | 3.35 | 1.90 | 1.8× | 6.65 |
| BIA | 2.28 | 1.34 | 1.7× | **7.39** |

**Agency variance spans 6.6×.** TVA completes EISs at a median of 1.81 years; BIA takes 7.39 years. This spread is not explained by project complexity alone — FERC handles technically complex energy infrastructure at 1.88 years. Agency-specific procedural reform offers far greater leverage than blanket NEPA rule changes.

**Timeline trend 2010–2024.** Median NOI→ROD peaked at 4.46 years in 2016, then declined sharply. The 2022–2024 average (2.65 years) is the lowest in the 15-year series:

| Year | n | Median NOI→ROD (yrs) |
|---|---|---|
| 2010 | 192 | 3.02 |
| 2013 | 139 | 3.45 |
| 2016 | 134 | **4.46** (peak) |
| 2019 | 121 | 3.76 |
| 2021 | 55 | 2.76 |
| 2023 | 60 | 2.70 |
| 2024 | 51 | **2.28** |

This 49% reduction from peak is the strongest evidence that recent policy interventions — FAST-41, One Federal Decision, and the CEQ 2023 regulatory changes — are effective. However, the 2024 sample is smaller (n=51 vs. n=192 in 2010), which may reflect right-censoring of slow ongoing projects.

**Scoping cap impact model (Stage 13).** Applying three cap levels to the 1,897 CEQ records with scoping data:

| Cap Level | Projects Affected | % of Corpus | Total Agency-Years Saved | Avg Months Saved/Project |
|---|---|---|---|---|
| 1-year cap | 1,455 | 76.7% | 3,121 | 26 |
| **2-year cap (recommended)** | **849** | **44.8%** | **1,987** | **28** |
| 3-year cap | 549 | 28.9% | 1,301 | 28 |

The 2-year cap is recommended because it captures 64% of the maximum achievable savings while affecting only 45% of projects. A 1-year cap would disrupt even well-run processes (FERC's median scoping is already 0.98 years); a 3-year cap leaves 687 agency-years of avoidable delay unaddressed.

**Priority agencies under a 2-year cap:**

| Agency | Projects Exceeding Cap | % of Agency Total | Avg Months Saved |
|---|---|---|---|
| NPS | 82 | **83.7%** | 37 |
| FHWA | 118 | 73.8% | 37 |
| FRA | 18 | 72.0% | 27 |
| FAA | 8 | 62.0% | 47 |
| BR | 34 | 61.8% | 39 |
| USFWS | 44 | 58.7% | 28 |
| USACE | 102 | 58.3% | 42 |
| BLM | 115 | 48.9% | 26 |

**Agency tier classification (Stage 12):**

| Tier | Agencies |
|---|---|
| Fast & Defensible (median <2.25 yr, win ≥74%) | FERC, BOEM, TVA, NHTSA, HUD |
| Slow Scoping Bottleneck (median ≥4.46 yr) | BIA, FHWA, NPS, FAA, OSMRE, FRA, BR, USACE |
| Legally Vulnerable (slow AND low win rate) | BR, USFWS, BLM, NOAA |

Note: Several agencies (FTA, BIA, NPS, FAA, FHWA) are slow but achieve high litigation win rates — indicating their delays, while operationally costly, do produce defensible records. USFWS and BLM are both slow *and* legally weak, representing the worst-case combination.

**Extreme outliers.** 25 projects in the CEQ corpus exceed 14 years. FHWA and USACE account for 18 of 25. The longest project in the dataset is FHWA's US 70 Havelock Bypass at 24.2 years NOI→ROD. These are not single linear NEPA processes — they involve multi-decade project-restart cycles driven by scope changes, supplemental EIS requirements, and multi-jurisdictional ROW acquisition.

### 4.4 Litigation Risk Factors

**Agency loss rates (Stage 7).** Computed from 684 usable PermitTEC cases after excluding 77 records with ambiguous outcomes:

| Agency | Cases | Loss Rate | Risk Tier |
|---|---|---|---|
| BLM | 89 | **39.3%** | HIGH |
| USFS | 148 | 28.4% | MEDIUM |
| USACE | 62 | 24.2% | MEDIUM |
| FERC | 42 | 23.8% | MEDIUM |
| NOAA | 22 | 31.8% | MEDIUM |
| USFWS | 37 | 45.9% | HIGH |
| BR | 14 | 50.0% | HIGH |
| FHWA | 26 | 15.4% | LOW |
| NRC | 13 | 7.7% | LOW |

**Statute risk multipliers.** ESA §7 involvement increases litigation loss probability by 1.48× relative to the baseline loss rate of 24.4%:

| Statute | Cases | Loss Rate | Multiplier |
|---|---|---|---|
| ESA §7 | 72 | 36.1% | **1.48×** |
| NFMA | 58 | 31.0% | 1.27× |
| CWA §404 | 48 | 29.2% | 1.20× |
| NGA §7 | 36 | 25.0% | 1.02× |
| Baseline | — | 24.4% | 1.00× |

**Circuit risk multipliers.** The 10th Circuit (covering Colorado, Wyoming, Utah, Kansas, Oklahoma, New Mexico) carries the highest multiplier:

| Circuit | Cases | Loss Rate | Multiplier |
|---|---|---|---|
| 10th | 68 | 35.3% | **1.45×** |
| 4th | 42 | 33.3% | 1.35× |
| 9th | 268 | 30.6% | 1.25× |
| DC | 148 | 25.7% | 1.05× |
| 7th | 22 | 18.2% | **0.75×** |

**Top procedural failures (Stage 4).** Analyzing the 223 PermitTEC cases linked to NEPATEC projects reveals three failure patterns that appear in nearly every lost case:

1. **Inadequate cumulative/connected actions analysis.** Agency prepared an EIS but failed to analyze connected actions or relied on a prior EIS without reassessing changed circumstances (e.g., BLM reliance on prior Echanis wind project EIS for transmission without cumulative sage-grouse analysis). Regulatory cite: 40 CFR 1502.9(c).
2. **Failure to supplement when new information required.** ROD issued or project proceeded without supplemental EIS after material changes — new species data, project scope change, or more than 5 years elapsed since ROD.
3. **EA-to-EIS threshold error.** Agency used EA/FONSI where project significance clearly warranted EIS; challenger argued improper significance determination under 40 CFR 1501.3.

**Plaintiff type win rates (Stage 10).** Tribal Nation plaintiffs achieve an 87.5% win rate against federal agencies — the highest of any plaintiff category by a substantial margin:

| Plaintiff Type | Organizations | Challenger Win Rate | Dominant Circuit |
|---|---|---|---|
| Tribal Nations | 2 | **87.5%** | 9th |
| Industry Associations | 2 | 50.0% | DC |
| Environmental NGOs | 22 | 28.5% | 9th |
| State Governments | 5 | 20.0% | Mixed |

Highest-risk plaintiff–agency pairings identified:

| Plaintiff | Target Agency | Cases | Challenger Win Rate |
|---|---|---|---|
| WildEarth Guardians | BLM / OSM | 4 | 75% |
| Navajo Nation | Bureau of Reclamation / BIA | 4 | 75% |
| Western Watersheds Project | BLM / APHIS | 8 | 62.5% |
| Sierra Club | FERC | 4 | 25% |

**Geographic risk (Stage 11).** State-level challenger win rates across 26 states with 4+ cases show clear regional clustering:

| Risk Zone | States | Challenger Win Rate Driver |
|---|---|---|
| Interior West — Federal Minerals | WY, CO, UT | BLM mineral leasing; 10th Circuit 1.45× multiplier |
| Pacific Northwest — Forest/Grazing | OR, NV | USFS; 9th Circuit; Alliance for the Wild Rockies concentration |
| Northern Rockies | MT, ID, AZ | Mixed BLM/USFS; moderate 9th Circuit exposure |
| Mid-Atlantic Corridor | VA, MD, PA | FERC/FHWA lead; DC Circuit deference |
| Pacific (Defense/Deference) | AK, WA, CA | Military deference; strong NEPA records |

Colorado (50% challenger win rate, n=20) and Oregon (42.9%, n=87) are the highest-risk individual states with sufficient case volume to draw conclusions.

### 4.5 Sector × Circuit Interaction

**The sector × circuit matrix is the strongest single litigation risk predictor (Stage 13).** Constructing a win-rate matrix across 7 sectors and 12 circuits from 684 PermitTEC cases reveals that the same agency in the same sector can face dramatically different outcomes depending solely on the circuit in which it is sued:

| Sector | DC Circuit | 4th Circuit | 9th Circuit | 10th Circuit |
|---|---|---|---|---|
| Transportation | **91%** | 78% | 77% | 62% |
| Energy | 64% | **29%** | 71% | 83% |
| Water/Coastal | 56% | — | **50%** | — |
| Public Lands | 67% | 86% | 70% | 83% |
| Wildlife | 63% | — | **64%** | — |

*(Cells with fewer than 3 cases shown as —; percentages are agency win rates)*

**Highest-risk cell: Energy in the 4th Circuit (28.6% agency win rate, n=7).** The Mountain Valley Pipeline and Atlantic Coast Pipeline decisions in the 4th Circuit set hostile precedent on cumulative GHG analysis and ESA §7 consultation scope. Energy project sponsors in Virginia, West Virginia, North Carolina, South Carolina, and Maryland face the most adverse litigation environment in the country.

**Safest cell: Transportation in the DC Circuit (90.9% agency win rate, n=22).** FHWA and FTA projects challenged in the DC Circuit achieve near-universal success — the DC Circuit applies strong deference to agency expertise in technical transportation matters.

**Implication:** Project sponsors selecting between alternative FERC and DOE approval pathways, or FERC vs. state agency leads, should factor circuit exposure into project structuring before EIS scoping begins.

### 4.6 Document Adequacy and Procedural Gates

**Document registry (Stage 9).** Seven blocking gates are required for legally defensible records — documents whose absence creates HIGH litigation risk:

| Document | Process | Blocking | Primary Risk if Absent |
|---|---|---|---|
| CE Determination | CE | Yes | Improper CE reliance challenge |
| Extraordinary Circumstances Memo | CE | Yes | EA-to-EIS threshold error |
| EA Final / FONSI | EA | Yes | Significance determination challenge |
| EIS NOI | EIS | Yes | Procedural standing issues |
| DEIS | EIS | Yes | Inadequate public comment opportunity |
| FEIS | EIS | Yes | ROD without final record |
| ROD | EIS | Yes | Failure to close process |

**Stage gate conditions for EA transition.** The EA Draft-to-Final gate requires: (1) `Public_Comment_Period_Completed = true`, and (2) `Cumulative_Connected_Actions_Analyzed = true`. The second condition directly addresses the most common procedural failure (Section 4.4).

---

## 5. Policy Implications

The findings above converge on five actionable reform priorities, ordered by projected impact:

### 5.1 Statutory 24-Month Scoping Cap

**Recommendation:** Amend NEPA §102(2)(C) to require DEIS publication within 24 months of NOI, with failure triggering automatic elevation to CEQ for expedited resolution within 60 days.

**Evidence basis:** A 2-year cap affects 849 projects (44.8% of the 2010–2024 corpus) and saves 1,987 agency-years at an average of 28 months per project. The cap's target agencies — NPS (83.7% exceedance rate), FHWA (73.8%), FRA (72%), and USACE (58.3%) — have median scoping durations of 3–4+ years with no corresponding improvement in litigation outcomes.

**Precedent:** The Fiscal Responsibility Act of 2023 §321 established page limits and schedule requirements for EIS documents. A scoping deadline extends this logic to the upstream phase where most time is lost.

### 5.2 Scoping Kickoff Checklists for CE Determinations

**Recommendation:** Mandate agency-specific CE kickoff checklists incorporating the extraordinary circumstances triggers identified in Stage 2, reducing the rate of EA-to-EIS escalation errors and improper CE reliance challenges.

**Evidence basis:** The third most common procedural failure is an EA-to-EIS threshold error. The six extraordinary circumstances triggers (Section 4.1) are well-established in regulation but inconsistently applied. Codifying them as mandatory intake checklist items reduces discretionary ambiguity.

### 5.3 Plaintiff Early-Warning System

**Recommendation:** Federal agencies with active NEPA projects should monitor known high-win-rate plaintiffs (Tribal Nations: 87.5%, Western Watersheds Project: 62.5%, WildEarth Guardians: 75%) and engage proactively in pre-NOI government-to-government consultation or pre-filing coordination.

**Evidence basis:** The highest-risk plaintiff–agency pairings (Navajo Nation vs. Bureau of Reclamation, WildEarth Guardians vs. BLM) reflect predictable conflict patterns that predate case filing. Early coordination has demonstrably reduced litigation rates in FERC's pre-filing consultation model (Section 5.5).

### 5.4 Circuit-Aware EIS Strategy for Energy Projects

**Recommendation:** Energy project sponsors and lead agencies in Virginia, West Virginia, North Carolina, South Carolina, and Maryland (4th Circuit) should structure NEPA records with explicit GHG cumulative analysis, scoping documentation for ESA §7, and expanded alternatives analysis before filing for any federal permit.

**Evidence basis:** The 4th Circuit achieves a 28.6% agency win rate for energy projects — less than one win in three. This is not simply a product of project complexity; the same energy sector achieves 83% agency win rates in the 10th Circuit and 71% in the 9th. The 4th Circuit's pattern reflects specific jurisprudential holdings (MVP, ACP) that require affirmative documentation to overcome.

### 5.5 Replicate FERC's Pre-Filing Consultation Model

**Recommendation:** Extend FERC's pre-filing consultation framework — in which project sponsors engage cooperating agencies and stakeholders before the NOI is published — to natural resource agencies (USFWS, BLM, NOAA, Bureau of Reclamation).

**Evidence basis:** FERC achieves a 1.88-year median timeline with a 74% litigation win rate. Its procedural model front-loads issue identification and cooperating agency coordination before the formal NEPA clock starts. The USFWS achieves a 4.38-year median with a 54.1% win rate on comparable project types — the pre-filing model applied to USFWS's ESA §7 consultation process would likely compress both timeline and litigation risk simultaneously.

---

## 6. Limitations

**PermitTEC coverage gap.** 44.8% of PermitTEC cases involve NEPA challenges for which the underlying project is not in NEPATEC v2.0 (`NEPA Challenge — Not in NEPATEC`). These cases are concentrated in older litigation and tiered decisions. Win rate statistics computed from PermitTEC cases without NEPATEC linkage (Stages 7, 10, 11, 12, 13) may not be representative of the full NEPA litigation universe.

**LLM synthesis uncertainty.** Qualitative outputs — decision trees, narrative findings, plaintiff strategy profiles — are generated by Claude via structured prompts. While the model's quantitative inputs are Python-computed, synthesis outputs can reflect training data biases or prompt artifacts. All quantitative figures cited in this report are derived from Python-preprocessed statistics, not LLM arithmetic.

**Sector classification in Stage 13.** The sector × circuit matrix uses keyword inference from project titles to assign sector labels. This is not a validated taxonomy — projects with ambiguous titles may be misclassified, which would blur sector-specific win rates. Cells with n < 3 are excluded.

**CEQ timeline data covers Final EIS only.** CE and EA timelines are not included in the CEQ dataset. The scoping cap model (Stage 13) applies only to EIS processes. CE and EA process reform would require a separate, currently unavailable dataset.

**FAST-41 data not obtained.** The FAST-41 permitting milestone database (permits.performance.gov) returned 403 errors at the time of analysis. Inter-agency handoff delays and target-vs.-actual FAST-41 milestone comparisons would substantially enrich the timeline analysis. Contact FAST-41@permitting.gov for bulk data access.

**Small sample sizes in some cells.** Some sector × circuit cells have 3–5 cases. Win rates in these cells are reported with the caveat that small-n results are highly sensitive to individual case outcomes. The composite risk score v2 discounts sector × circuit cells with n < 3 by 50%.

---

## 7. Reproducibility Guide

All pipeline code, prompts, and utility scripts are included in this repository. The following steps reproduce all 13 stages of analysis from scratch.

### 7.1 Prerequisites

- Python 3.10 or later
- An Anthropic API key with access to `claude-opus-4-7`
- The `anthropic` and `openpyxl` Python packages
- Approximately 2 GB of disk space for the sample cache

**Estimated API cost:** Running all 13 stages requires approximately 1.5–3 million tokens of API calls depending on cache hit rate. Add your estimated cost here based on current Anthropic pricing.

**Estimated wall time:** 2–4 hours for a full pipeline run with API latency.

### 7.2 Data Setup

**Step 1 — NEPATEC 2.0**

NEPATEC 2.0 is publicly available on Hugging Face:

```python
from datasets import load_dataset
ds = load_dataset("PNNL/NEPATEC2.0")
```

Alternatively, download and organize locally:
- CE records → `NEPATEC2.0/CE/BLM/`, `NEPATEC2.0/CE/DOE/`, `NEPATEC2.0/CE/USDA/`
- EA records → `NEPATEC2.0/EA/BLM/`, `NEPATEC2.0/EA/DOE/`, `NEPATEC2.0/EA/USDA/`
- EIS records → `NEPATEC2.0/EIS/BLM/`, `NEPATEC2.0/EIS/DOE/`, `NEPATEC2.0/EIS/EPA/`

Each agency subdirectory contains JSONL files with one project record per line.

**Step 2 — PermitTEC v0.1**

PermitTEC v0.1 is publicly available on Hugging Face:

```python
from datasets import load_dataset
ds = load_dataset("PNNL/PermitTECv0.1")
```

Or download directly: `PermitTECv0.1/dataset.json` (included in this repository)

**Step 3 — CEQ EIS Timeline Data**

Download directly from CEQ:

```bash
curl -o ceq_eis_timelines.xlsx \
  "https://ceq.doe.gov/docs/nepa-practice/CEQ_EIS_Timeline_Data_2024_1_13_2025.xlsx"
```

Place in the project root as `ceq_eis_timelines.xlsx`.

### 7.3 Environment Setup

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate          # macOS/Linux
# .venv\Scripts\activate           # Windows

# Install dependencies
pip install anthropic openpyxl

# Set required environment variables
export ANTHROPIC_AUTH_TOKEN="your-api-key-here"
export ANTHROPIC_BASE_URL="https://api.anthropic.com"   # or your gateway URL
```

If your organization uses a custom API gateway with a CA bundle:

```bash
export NODE_EXTRA_CA_CERTS="/path/to/ca-bundle.pem"
```

### 7.4 Build Sample Cache

The pipeline does not read the full NEPATEC corpus directly. Build a stratified sample cache first:

```bash
.venv/bin/python sample_data.py
```

This creates 9 JSONL files in `samples/` (one per stratum: CE/BLM, CE/DOE, CE/USDA, EA/BLM, EA/DOE, EA/USDA, EIS/BLM, EIS/DOE, EIS/EPA) and a `samples/manifest.json`. Total size is approximately 610 MB.

Sample targets are configured in `config.py`:

```python
SAMPLE_TARGETS = [
    ("CE", "BLM"),   ("CE", "DOE"),  ("CE", "USDA"),
    ("EA", "BLM"),   ("EA", "DOE"),  ("EA", "USDA"),
    ("EIS", "BLM"),  ("EIS", "DOE"), ("EIS", "EPA"),
]
```

### 7.5 Run the Pipeline

**Stages 1–5:**

```bash
# Run all stages
.venv/bin/python pipeline.py

# Run a single stage (e.g., Stage 2 only)
.venv/bin/python pipeline.py --stage 2

# Force re-sampling before running
.venv/bin/python pipeline.py --resample
```

**Stages 6–13:**

```bash
# Run all extended stages
.venv/bin/python pipeline_extended.py

# Run a single extended stage (e.g., Stage 12 only)
.venv/bin/python pipeline_extended.py --stage 12
```

### 7.6 Outputs

All stage outputs are written to `outputs/`:

| File | Stage | Description |
|---|---|---|
| `1_feature_engineering.json` | 1 | Feature importance rankings; sector EIS probability matrix |
| `2_ce_decision_tree.json` | 2 | CE decision tree by agency; extraordinary circumstances triggers |
| `3_permit_matrix.json` | 3 | 35-row interagency permit matrix (JSON) |
| `3_permit_matrix.csv` | 3 | Same matrix as CSV (for spreadsheet import) |
| `4_litigation_guardrails.json` | 4 | Top procedural failures; validation rules |
| `6_timeline_risk_profile.json` | 6 | Page count thresholds by process type |
| `7_litigation_risk_weights.json` | 7 | Agency/statute/circuit loss rates; composite score v1 |
| `8_ce_code_catalog.json` | 8 | CE code catalog; 14 screening rules |
| `9_document_registry.json` | 9 | Required document registry; blocking gates |
| `10_plaintiff_intelligence.json` | 10 | Plaintiff profiles; high-risk pairings |
| `11_geographic_risk_map.json` | 11 | State win rates; regional risk zones |
| `12_ceq_timeline_cross.json` | 12 | Agency tier table; bottleneck analysis; year trend |
| `13_scoping_circuit_risk.json` | 13 | Scoping cap model; sector×circuit matrix; score v2 |
| `pipeline_insights.md` | All | Consolidated findings reference (358 lines) |

### 7.7 Configuration

Key configuration parameters in `config.py`:

```python
MODEL = "claude-opus-4-7"
MAX_TOKENS_RESPONSE = 16000       # gateway maximum; do not increase without streaming
RANDOM_SEED = 42
CE_AMBIGUITY_SAMPLE = 200         # records for Stage 2
PERMIT_MATRIX_SAMPLE = 150        # records for Stage 3
```

System prompts for each stage are in `prompts/` and can be modified to retarget analyses for different agencies, sectors, or time periods.

---

## 8. Appendix

### Appendix A: NEPATEC 2.0 Key Fields

| Field | Type | Description |
|---|---|---|
| `project.project_ID.value` | text | UUID — join key for PermitTEC linkage |
| `project.project_title.value` | text | Project title (used for sector keyword inference in Stage 13) |
| `project.project_sector.value` | list[text] | Sector classification |
| `project.project_type.value` | list[text] | Project type |
| `project.project_sponsor.value` | list[text] | Lead agency or sponsor |
| `project.location.value` | list[text] | Project location(s) |
| `ce_category` | text | CE code, if applicable (strongest classification predictor) |
| `total_pages` | integer | Total document pages across all project documents |

### Appendix B: PermitTEC v0.1 Schema Summary

| Field | Description |
|---|---|
| `case_uuid` | Unique case identifier |
| `case_metadata.case_title.value` | Case title |
| `case_metadata.citation.value` | Legal citation (e.g., *2 F.4th 953*) |
| `case_metadata.circuit.value` | Federal circuit (e.g., "9th Circuit", "District of Columbia") |
| `case_metadata.plaintiff.value` | Plaintiff/challenger name |
| `case_metadata.defendant.value` | Defendant agency |
| `case_metadata.prevailing_party.value` | `Agency` \| `Challenger` \| `Cannot be determined` |
| `linked_to.in_nepatec` | Boolean — whether project is matched to NEPATEC |
| `linked_to.nepatec_project_uuid` | UUID join key to NEPATEC `project_ID` |

All fields carry a `.source` provenance tag. Fields tagged `llm_extracted_no_manual_review` should be treated with caution in precision-sensitive applications. For bulk access: `load_dataset("PNNL/PermitTECv0.1")` via the Hugging Face `datasets` library.

### Appendix C: Composite Risk Score Specifications

**Version 1 (Stage 7 output: `7_litigation_risk_weights.json`)**

```
Input variables:
  agency_loss_rate_pct          — from Stage 7 agency loss rate table
  circuit_risk_multiplier       — from Stage 7 circuit multiplier table
  max_statute_risk_multiplier   — max multiplier across statutes invoked by the project

Formula:
  score_v1 = (agency_loss_rate_pct × 0.40)
           + ((circuit_risk_multiplier − 0.30) × 25)
           + (max_statute_risk_multiplier × 15)

Risk tiers:
  LOW       < 35
  MEDIUM    35–44
  HIGH      45–57
  VERY HIGH ≥ 58
```

**Version 2 (Stage 13 output: `13_scoping_circuit_risk.json`)**

```
Additional input variables:
  Scoping_Overrun_Flag           — 1 if projected NOI→DEIS > agency baseline cap, else 0
  Projected_Scoping_Overrun_Months — months of projected overrun (0 if under cap)
  Sector_Circuit_Win_Rate        — agency win rate % for this sector×circuit cell
  Sector_Circuit_Case_Count      — number of observed cases in the cell

Formula:
  score_v2 = score_v1
           + (0.15 × Scoping_Overrun_Flag)
           + (0.10 × MIN(Projected_Scoping_Overrun_Months / 48, 1.0))
           + (0.20 × (1 − Sector_Circuit_Win_Rate / 100)
                     × IF(Sector_Circuit_Case_Count ≥ 3, 1.0, 0.5))
```

### Appendix D: Full Agency Timeline Table (All 36 Agencies)

| Agency | n (EIS) | NOI→DEIS (median yrs) | DEIS→FEIS (median yrs) | NOI→ROD (median yrs) | Bottleneck | Litigation Win % |
|---|---|---|---|---|---|---|
| TVA | 22 | 1.04 | 0.61 | **1.81** | scoping | — |
| NHTSA | 5 | 0.96 | 0.86 | 1.86 | scoping | — |
| FERC | 80 | 0.98 | 0.42 | 1.88 | scoping | 74.1% |
| HUD | 11 | 1.02 | 0.35 | 2.01 | scoping | — |
| BOEM | 30 | 1.25 | 0.82 | 2.24 | scoping | 100.0% |
| NRCS | 8 | 1.44 | 0.40 | 2.26 | scoping | — |
| GSA | 12 | 0.85 | 0.96 | 2.38 | **review** | — |
| USA | 22 | 1.22 | 1.04 | 2.52 | scoping | — |
| USAF | 40 | 0.89 | 0.69 | 2.59 | scoping | — |
| APHIS | 13 | 1.71 | 0.56 | 2.61 | scoping | — |
| NRC | 48 | 1.37 | 0.94 | 2.66 | scoping | 92.3% |
| VA | 5 | 1.48 | 1.00 | 2.66 | scoping | — |
| NSF | 5 | 1.60 | 0.77 | 2.79 | scoping | — |
| NASA | 5 | 1.83 | 0.67 | 2.81 | scoping | — |
| DOE | 20 | 1.56 | 0.90 | 2.88 | scoping | 75.0% |
| RUS | 7 | 1.63 | 0.65 | 2.89 | scoping | — |
| NOAA | 89 | 1.58 | 0.86 | 2.92 | scoping | 68.2% |
| FirstNet | 5 | 1.75 | 1.05 | 2.93 | scoping | — |
| USCG | 10 | 1.42 | 1.21 | 2.96 | scoping | — |
| BPA | 9 | 1.52 | 0.71 | 2.97 | scoping | — |
| WAPA | 13 | 1.65 | 0.82 | 3.03 | scoping | — |
| USFS | 368 | 1.48 | 0.98 | 3.11 | scoping | 71.3% |
| USMC | 10 | 1.67 | 0.73 | 3.45 | scoping | — |
| USN | 33 | 1.91 | 1.25 | 3.47 | scoping | — |
| NNSA | 5 | 2.25 | 1.09 | 3.55 | scoping | — |
| BLM | 219 | 1.94 | 0.96 | 3.79 | scoping | 61.0% |
| FTA | 37 | 2.31 | 1.61 | 4.30 | scoping | 100.0% |
| USFWS | 65 | 2.34 | 0.90 | 4.38 | scoping | 54.1% |
| USACE | 156 | 2.49 | 1.17 | 4.46 | scoping | 76.9% |
| BR | 48 | 3.19 | 1.02 | 4.69 | scoping | 50.0% |
| FRA | 24 | 3.31 | 1.40 | 5.06 | scoping | — |
| OSMRE | 5 | 4.36 | 0.90 | 5.83 | scoping | — |
| FAA | 12 | 3.41 | 1.13 | 6.13 | scoping | 86.4% |
| NPS | 96 | 4.07 | 1.30 | 6.27 | scoping | 75.0% |
| FHWA | 148 | 3.35 | 1.90 | 6.65 | scoping | 84.6% |
| BIA | 28 | 2.28 | 1.34 | **7.39** | scoping | 100.0% |

### Appendix E: Datasets Still Needed

| Dataset | Gap It Fills | Access Route |
|---|---|---|
| FAST-41 milestone data | Inter-agency handoff delays; target vs. actual dates by agency pair | Email FAST-41@permitting.gov |
| EPA EIS Database (BIS) | Public comment volume as delay predictor; Federal Register dates | No bulk export; web scrape or FOIA |
| DOJ ENRD annual caseload | Which statutes drive most NEPA litigation government-wide | Annual PDF reports; manual extraction |
| RegInfo.gov OIRA data | Upstream bottleneck: OMB approval delays for permit application forms | Structured XML at reginfo.gov |
| GAO report appendices | Workforce/staffing deficits (BIA, OSMRE understaffing) | PDF only; manual extraction |

---

## References

Council on Environmental Quality. (2025). *CEQ EIS Timeline Data 2010–2024* [Dataset]. Executive Office of the President. Retrieved from https://ceq.doe.gov/docs/nepa-practice/CEQ_EIS_Timeline_Data_2024_1_13_2025.xlsx

Bhattacharjee, K., Mohankumar, N. M., Puccio, J., Mukherjee, S., Spear, L., Hess, O., Ashraf, R., Serrano, T., Ayton, E., Bandy, J., et al. (2026). *Permitting Text Corpus (PermitTEC) v0.1* [Dataset]. Hugging Face. https://huggingface.co/datasets/PNNL/PermitTECv0.1

Pacific Northwest National Laboratory. (2024). *NEPA Text Corpus (NEPATEC) v2.0* [Dataset]. Hugging Face. https://huggingface.co/datasets/PNNL/NEPATEC2.0

Fiscal Responsibility Act of 2023, Pub. L. No. 118-5, §321, 137 Stat. 10 (2023) (NEPA page and schedule limits).

National Environmental Policy Act of 1969, 42 U.S.C. §§ 4321–4370m (2023 amendments).

Council on Environmental Quality. (2023). *National Environmental Policy Act Implementing Regulations Revisions Phase 2*, 88 Fed. Reg. 49924 (July 31, 2023).
