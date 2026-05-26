# Glossary

Terms, acronyms, and concepts used throughout the NEPA and Permitting Data Model documentation.

---

## NEPA and Regulatory Terms

**Administrative Record** — The official, complete file of documents the agency considered when making a NEPA decision. Must be preserved and defensible against litigation challenge.

**BLM** — Bureau of Land Management. A U.S. Department of the Interior agency that manages public lands. One of the most-litigated federal agencies in NEPA cases.

**CE (Categorical Exclusion)** — A category of actions that an agency has determined do not individually or cumulatively have a significant effect on the environment. CE determinations do not require an EA or EIS.

**CEQ** — Council on Environmental Quality. An office within the Executive Office of the President that coordinates federal environmental efforts and issues NEPA regulations (40 CFR Parts 1500–1508).

**CUI** — Controlled Unclassified Information. A federal data classification for sensitive but unclassified information, governed by 32 CFR Part 2002 and NARA guidelines.

**EA (Environmental Assessment)** — A concise public document that provides sufficient evidence and analysis for determining whether an agency must prepare an EIS or issue a FONSI.

**EIS (Environmental Impact Statement)** — The most comprehensive NEPA document, required for major federal actions significantly affecting the quality of the human environment.

**EJ / Environmental Justice** — Executive Order 12898 and subsequent policy require agencies to identify and address disproportionately high adverse effects on minority and low-income communities.

**CEQA (California Environmental Quality Act)** — California's state analog to NEPA, requiring environmental review of projects with potentially significant effects. Administered by the Governor's Office of Planning and Research (OPR). Used in Stage 16 as the state-level process baseline for computing the federal friction multiplier (1.45× overall).

**CEQAnet** — California's online clearinghouse for CEQA documents, operated by OPR (`ceqanet.opr.ca.gov`). Does not have a bulk export API; project-level timing data is obtained from published studies such as the Holland & Knight CEQA Time Study 2022.

**CourtListener** — A free public federal court data service operated by the Free Law Project. Provides bulk downloads of federal docket records (71 million rows as of 2026-03-31). Used in Stage 14 for litigation duration profiling by agency and circuit.

**FAST-41** — Fixing America's Surface Transportation Act, Title 41. Provides a coordinated environmental review process with binding schedules and a federal permitting dashboard (PERMITTING.GOV) for major infrastructure projects.

**FERC** — Federal Energy Regulatory Commission. Regulates interstate transmission of electricity, natural gas, and oil. High litigation exposure in NEPA cases involving energy projects.

**FONSI (Finding of No Significant Impact)** — An agency determination, based on an EA, that a proposed action will not significantly affect the environment and therefore does not require an EIS.

**FRA** — Federal Railroad Administration. Also: Fiscal Responsibility Act of 2023, which introduced page limits for EA (75 pages) and EIS (150 pages) documents.

**IDI** — Internal NEPA process identifier used in the NEPATEC dataset. Example: `IDI-38709` = Carrie Placer Mine Plan of Operations.

**MFR (Minimum Functional Requirement)** — One of seven requirements issued by CEQ in the NEPA and Permitting Data and Technology Standard v1.2. Agencies listed under 42 U.S.C. 4370m-1(b)(2)(B)(i)-(xii) must implement them.

**NAICS** — North American Industry Classification System. Six-digit codes used to classify business and project types; used in CE Screener routing to determine applicable agency categorical exclusion regulations.

**NEPA** — National Environmental Policy Act (42 U.S.C. §§ 4321–4347). The foundational U.S. environmental law requiring federal agencies to assess environmental effects of proposed major federal actions before approving them.

**NEPATEC** — NEPA Trends, Efficiencies, and Case database. A PNNL (Pacific Northwest National Laboratory) research corpus. Version 2.0 contains 61,881 NEPA projects; Version 0.1 contains 761 litigation cases spanning 1970–2025.

**NOI (Notice of Intent)** — A Federal Register notice that an agency intends to prepare an EIS and a description of the proposed action and alternatives.

**OMB M-24-10** — Office of Management and Budget Memorandum on Advancing Governance, Innovation, and Risk Management for Agency Use of Artificial Intelligence. Requires disclosure of AI use in federal decisions and human-in-the-loop requirements for high-impact decisions.

**OMB M-25-05** — Office of Management and Budget Memorandum on open government data access and management under the Evidence Act. Requires agencies to publish data assets as open data where appropriate.

**PermitTEC** — Pacific Northwest National Laboratory's dataset of NEPA litigation cases (761 cases, 1970–2025), used as the training corpus for Phase 1 litigation risk scoring in this Accelerator.

**PNNL** — Pacific Northwest National Laboratory. DOE national lab that published both NEPATEC and PermitTEC datasets.

**ROD (Record of Decision)** — A document that announces an agency's decision about a proposed action analyzed in an EIS, identifying the selected alternative and mitigation measures.

**Section 106** — Section 106 of the National Historic Preservation Act (54 U.S.C. § 306108). Requires federal agencies to consult with State Historic Preservation Offices and tribal groups before taking actions affecting historic properties.

**Section 7** — Section 7 of the Endangered Species Act (16 U.S.C. § 1536(a)). Requires federal agencies to consult with USFWS or NOAA Fisheries when a proposed action may affect threatened or endangered species.

**USACE** — U.S. Army Corps of Engineers. Issues Clean Water Act Section 404 dredge/fill permits; high NEPA litigation exposure.

**USFS** — U.S. Forest Service. Manages National Forests under the Department of Agriculture; one of the highest-litigation federal agencies in NEPA cases.

**USFWS** — U.S. Fish and Wildlife Service. Issues Endangered Species Act Section 7 consultations and manages critical habitat designations.

---

## Salesforce Platform Terms

**ADR (Architecture Decision Record)** — A document capturing the reasoning behind a significant architectural choice. This project's ADRs are in [`docs/ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md).

**Apex** — Salesforce's proprietary Java-like programming language for server-side logic. This Accelerator uses Apex sparingly — primarily for the OmniIP bridge and data loading scripts.

**ApplicationTimeline** — A PSS standard object (API name: `ApplicationTimeline`) used in this Accelerator for CEQ Entity 6 (Case Events) and FAST-41 milestone tracking.

**BRE (Business Rules Engine)** — A Salesforce platform feature that allows declarative rule evaluation via Decision Matrices and Expression Sets. Used in this Accelerator for CE Screener routing and Permit Matrix lookups.

**CMT (Custom Metadata Type)** — Salesforce metadata that stores configuration records deployable via CLI. Used extensively for risk weights, SLA configs, CE rules, and permit matrix data.

**ContentVersion** — Salesforce's file storage object. Used in this Accelerator for CEQ Entity 3 (Documents) with a custom record type (`nepa_permit_document`).

**DataRaptor** — An OmniStudio component for reading or writing Salesforce data. This Accelerator includes 15 DataRaptor definitions (`DR_Extract_NEPA_*`) as design artifacts in the repository (backlog — not verified). The CEQ export is implemented via the Apex `NepaCeqExportService` REST endpoint. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

**Decision Matrix (DM)** — A BRE component that evaluates input values against a table of rows and returns output values. Decision Matrix rows are loaded automatically by `scripts/load_decision_matrix_rows.py` (Phase 5b-data in `scripts/deploy.sh`) — no manual Setup UI import is required.

**Expression Set (ES)** — A BRE component that orchestrates one or more Decision Matrices into a rule evaluation pipeline with weighted scoring.

**FedRAMP** — Federal Risk and Authorization Management Program. U.S. government cloud security authorization framework. Federal agencies handling CUI should deploy to FedRAMP Moderate or High-authorized Salesforce orgs (Government Cloud or Government Cloud Plus).

**FLS (Field-Level Security)** — Salesforce permission control that governs whether a user can read or edit a specific field. Object access alone does not grant field visibility — FLS must be explicitly set.

**FlexCard** — An OmniStudio component for building data-driven card UI in Experience Cloud or the Salesforce app.

**FSL (Field Service Lightning)** — Salesforce's field service management product. Not used in this Accelerator. NEPA field survey scheduling uses the standard `Visit` object and Action Plan Templates, which do not require an FSL license.

**IndividualApplication** — A PSS standard object (API name: `IndividualApplication`) used in this Accelerator for CEQ Entity 2 (Process). Chosen over `BusinessLicenseApplication` because NEPA proponents include individuals, tribes, and agencies — not exclusively commercial entities.

**Integration Procedure (IP / OmniIP)** — An OmniStudio component that orchestrates multi-step data operations server-side. The `NEPA_CEQExport` Integration Procedure is a backlog design artifact in this Accelerator — the working CEQ export uses the Apex REST endpoint (`NepaCeqExportService`). See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

**LDV (Large Data Volume)** — Salesforce term for orgs with millions of records. LDV mitigations (selective SOQL, skinny tables, deferred sharing recalculation) are documented in ADR-007.

**LWC (Lightning Web Component)** — Salesforce's modern web component framework for building UI in the Salesforce app and Experience Cloud.

**LWR (Lightning Web Runtime)** — The newer Salesforce runtime for Experience Cloud sites; replaces Aura runtime. Relevant for portal development — LWC sandbox limitations apply.

**Named Credential** — A Salesforce configuration object that stores endpoint URL and authentication for external callouts. Used by the GIS proximity check flows.

**OmniScript** — An OmniStudio component for building guided, multi-step forms and wizards.

**OmniStudio** — Salesforce's declarative integration and UI framework (formerly Vlocity). Included in PSS. The CEQ export Integration Procedure, DataRaptors, and OmniScript wizards in this Accelerator are backlog — not verified end-to-end. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).

**Permission Set** — A Salesforce configuration that grants object, field, and feature access to users without modifying profiles. `NEPA_Permitting` is the primary permission set for this Accelerator.

**Program** — A PSS standard object (API name: `Program`) used in this Accelerator for CEQ Entity 1 (Project). Represents the overall NEPA project/undertaking.

**APS (Agentforce for Public Sector)** — Salesforce's industry cloud for government agencies (formerly called Public Sector Solutions / PSS). Provides `IndividualApplication`, `Program`, `ApplicationTimeline`, Action Plans, and OmniStudio as licensed components.

**PublicComplaint** — A PSS standard object used in this Accelerator for CEQ Entity 4 (Comments). Records public comments received during NEPA review periods.

**RegulatoryCode** — A PSS standard object used in this Accelerator for CEQ Entity 9 (Legal Structure). Stores applicable laws, regulations, and permit conditions.

**Remote Site Setting** — A Salesforce security configuration that must be created before Apex or Flow can make callouts to an external URL. Required for GIS proximity check callouts.

**Scratch Org** — A temporary, source-driven Salesforce org for development and testing. Requires Dev Hub.

---

## Project-Specific Terms

**Carrie Placer Mine** — The primary demo scenario: DOI-BLM-ID-B030-2019-0014-EA, a BLM placer mining Plan of Operations EA in Owyhee County, Idaho. NEPATEC ID: IDI-38709.

**CE Screener** — The Accelerator's automated CE pathway recommendation engine. Uses a three-tier BRE Decision Matrix (NAICS code, agency-sector-type, agency-action-type) to recommend CE, EA, or EIS review type. Non-binding — requires human confirmation per OMB M-24-10.

**Defensibility Score** — A 0–100 computed field on `IndividualApplication` (`nepa_defensibility_score__c`) that reflects the completeness of the administrative record: document coverage, public engagement coverage, and detected gaps. Powered by `NEPA_Defensibility_Gap_Checker`.

**Demo Story** — The Carrie Placer Mine scenario documented in [`demo/carrie_placer_mine_demo_story.md`](../demo/carrie_placer_mine_demo_story.md); used for sales and agency demonstrations.

**GIS Proximity Check** — An automated check triggered when a `Program` record receives lat/lon coordinates. Queries five ArcGIS feature services (NWI Wetlands, FWS Critical Habitat, EPA Superfund, EJScreen, BLM GeoBOE) to detect protection layers and flag extraordinary circumstances.

**NEPA Permitting Acceleration Plan** — Internal roadmap document ranking 10 platform features by time-to-permit impact, grounded in NEPATEC2.0 corpus analysis. See [`docs/NEPA-Permitting-Acceleration-Plan.md`](NEPA-Permitting-Acceleration-Plan.md).

**Federal Friction Multiplier** — The ratio of federal NEPA EIS median duration to California CEQA EIR median duration for the same project sector. Computed in Stage 16 using Holland & Knight CEQA Time Study 2022 benchmarks. Overall weighted value: 1.45×; range: 1.09× (Energy) to 1.65× (Military). Indicates that federal friction is concentrated in multi-agency coordination overhead, not analytical rigor.

**Litigation Duration Cost** — A normalized [0,1] value representing per-agency median litigation duration in months, derived from CourtListener bulk dockets (Stage 14). Used as the `Litigation_Duration_Cost__c` input to the v3 composite risk formula. Duration is a cost proxy only — it is statistically independent of case outcome (agency-won median: 15.1 months; challenger-won: 16.3 months).

**Risk Score** — A 0–100 litigation risk score computed on `IndividualApplication` (`nepa_litigation_risk_score__c`) by the `NEPA_Litigation_Risk_Scorer` flow and BRE Expression Set. Inputs (v3): agency loss rate, circuit loss rate, plaintiff organization strength, sector volatility, procedural posture risk, and litigation duration cost. Sourced from PermitTEC v0.1 corpus and CourtListener bulk dockets.

**Risk Tier** — Categorical label derived from the Risk Score: `Low` (0–29), `Medium` (30–49), `High` (50–74), `Critical` (75–100). Stored in `nepa_risk_tier__c`.
