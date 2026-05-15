# PSA-NEPA Permitting Accelerator — Architecture Diagrams

Architecture and data-flow reference for the PSA-NEPA permitting accelerator. Companion to [ARCHITECTURE_DECISIONS.md](ARCHITECTURE_DECISIONS.md) (the why) and [FLOW-ARCHITECTURE.md](FLOW-ARCHITECTURE.md) (the flow inventory).

---

## Table of Contents

1. [System Context](#1-system-context)
2. [Data Model — Core CEQ Entities](#2-data-model--core-ceq-entities)
3. [Risk Intelligence Pipeline](#3-risk-intelligence-pipeline)
4. [CE Screening and Intake Flow](#4-ce-screening-and-intake-flow)
5. [Stage Gate and Timeline Architecture](#5-stage-gate-and-timeline-architecture)
6. [Error Handling Architecture](#6-error-handling-architecture)
7. [GIS Proximity Check Flow](#7-gis-proximity-check-flow)
8. [Public Comment and Tribal Intelligence Flow](#8-public-comment-and-tribal-intelligence-flow)
9. [BRE / Decision Engine Layer](#9-bre--decision-engine-layer)
10. [Deployment Package Map](#10-deployment-package-map)

---

## 1. System Context

How the accelerator fits within Salesforce APS, external federal systems, and agency users.

```mermaid
C4Context
    title PSA-NEPA Permitting Accelerator — System Context

    Person(coord, "NEPA Coordinator", "Agency staff managing EIS/EA/CE reviews")
    Person(applicant, "Applicant / Proponent", "Submits permit applications and comments")
    Person(legal, "Legal / Risk Reviewer", "Reviews litigation risk flags and tribal escalations")

    System(nepa, "PSA-NEPA Accelerator", "Salesforce APS — case management, risk intelligence, GIS proximity, comment triage, CEQ export")

    System_Ext(fpisc, "FPISC Permitting Dashboard", "Federal permitting reporting (CEQ JSON export)")
    System_Ext(arcgis, "ArcGIS / Federal GIS Services", "Critical habitat, wetlands, EJSCREEN, BLM surface")
    System_Ext(permittec, "PermitTEC v0.1 Corpus", "761 NEPA litigation cases — calibrates risk weights (offline)")
    System_Ext(netatec, "NETATEC v2.0 Corpus", "61,881 NEPA projects — calibrates EIS scoping baselines (offline)")
    System_Ext(idp, "Agency Identity Provider", "PIV/CAC SSO via SAML 2.0")

    Rel(coord, nepa, "Manages reviews, assigns team, reviews risk flags")
    Rel(applicant, nepa, "Submits application, comments, checks status", "Experience Cloud portal")
    Rel(legal, nepa, "Reviews litigation risk scores and tribal escalations")
    Rel(nepa, fpisc, "Exports CEQ-standard JSON payload", "REST API / SFTP")
    Rel(nepa, arcgis, "Proximity checks on project coordinates", "Named Credential HTTPS")
    Rel(nepa, idp, "Staff authentication", "SAML 2.0")
    Rel(permittec, nepa, "Calibration data baked into CMT risk weight records", "offline import")
    Rel(netatec, nepa, "EIS scoping baselines baked into CMT records", "offline import")
```

---

## 2. Data Model — Core CEQ Entities

Entity-relationship diagram for the 9 CEQ standard entities and key supporting objects.

```mermaid
erDiagram
    Program["Program (CEQ Entity 1 — Project)"] {
        string nepa_project_id__c "External ID"
        string nepa_record_owner_agency__c
        string nepa_circuit__c
        string nepa_primary_sector__c
        string nepa_adjacent_statutes__c
        string nepa_agency_performance_tier__c
        number nepa_location_lat__c
        number nepa_location_lon__c
    }

    IndividualApplication["IndividualApplication (CEQ Entity 2 — Process)"] {
        string nepa_review_type__c "CE / EA / EIS"
        string nepa_process_stage__c
        string StatusCode
        number nepa_risk_score__c
        string nepa_risk_tier__c
        number nepa_challenge_risk_delta__c
        boolean nepa_tribal_plaintiff_flag__c
        boolean nepa_scoping_overrun_flag__c
        number nepa_record_completeness__c
    }

    ContentVersion["ContentVersion (CEQ Entity 3 — Documents)"] {
        string nepa_document_type__c
        string nepa_document_status__c
        number nepa_page_count__c
        boolean nepa_public_access__c
        boolean nepa_ai_generated__c
    }

    PublicComplaint["PublicComplaint (CEQ Entity 4 — Comments)"] {
        string nepa_comment_classification__c
        boolean nepa_plaintiff_risk_flag__c
        string nepa_ai_classification__c
        number nepa_ai_confidence__c
    }

    nepa_engagement["nepa_engagement__c (CEQ Entity 5 — Engagement Events)"] {
        string nepa_event_type__c
        boolean nepa_consultation_certified__c
        number nepa_advance_notice_days__c
    }

    ApplicationTimeline["ApplicationTimeline (CEQ Entity 6 — Case Events)"] {
        string Type
        string Status
        string nepa_tier__c
        date StartDate
        date EndDate
    }

    nepa_gis_data["nepa_gis_data__c (CEQ Entity 7 — GIS Data)"] {
        string nepa_format__c
        string nepa_coordinate_system__c
        string nepa_bounding_box__c
        string nepa_access_information__c
    }

    nepa_process_team_member["nepa_process_team_member__c (CEQ Entity 8 — User Roles)"] {
        string nepa_role_type__c
        boolean nepa_active__c
        date nepa_start_date__c
    }

    RegulatoryCode["RegulatoryCode (CEQ Entity 9 — Legal Structure)"] {
        string Name "Citation"
        date EffectiveFrom
        date EffectiveTo
    }

    nepa_litigation["nepa_litigation__c (Litigation Case Registry)"] {
        string nepa_plaintiff_org__c
        string nepa_outcome__c
        string nepa_circuit__c
        string nepa_statutes__c
    }

    Program ||--o{ IndividualApplication : "nepa_related_project__c"
    IndividualApplication ||--o{ ContentVersion : "nepa_process__c"
    IndividualApplication ||--o{ PublicComplaint : "MasterDetail"
    IndividualApplication ||--o{ nepa_engagement : "MasterDetail"
    IndividualApplication ||--o{ ApplicationTimeline : "nepa_related_process__c"
    IndividualApplication ||--o{ nepa_process_team_member : "MasterDetail"
    Program ||--o{ nepa_gis_data : "nepa_program__c"
    nepa_litigation }o--|| Program : "nepa_related_project__c (optional)"
```

---

## 3. Risk Intelligence Pipeline

How a litigation risk score is calculated end-to-end, from record trigger through BRE to write-back.

```mermaid
flowchart TD
    subgraph Triggers["Trigger Conditions (IndividualApplication after-save)"]
        T1["nepa_review_type__c changed"]
        T2["nepa_record_completeness__c changed"]
        T3["nepa_scoping_overrun_flag__c changed"]
    end

    subgraph PreCompute["Pre-computation (NEPA_Litigation_Risk_Scorer Flow)"]
        P1["Get Related Program\n(agency, circuit, sector, statutes)"]
        P2["Get Active Statute Risk Weights\n(NEPA_Statute_Risk_Weight__mdt)"]
        P3["Loop: Statute CONTAINS check\n→ accumulate var_StatutePoints"]
        P4["Compute formula_SectorCircuitKey\n= sector + '|' + circuit"]
        P5["Read nepa_challenge_risk_delta__c\n(from Challenge Predictor)"]
        P6["Evaluate formula_IsExpedited\n(ISPICKVAL Expedited/Emergency)"]
    end

    subgraph BRE["Business Rules Engine\n(NEPA_Litigation_Risk_Scorer Expression Set V2)"]
        B1["Decision Matrix: NEPA_Risk_ReviewType\n→ BaseTypeScore"]
        B2["Decision Matrix: NEPA_Risk_Agency\n→ AgencyPoints\n(e.g. BLM=39, FERC=24)"]
        B3["Decision Matrix: NEPA_Risk_Circuit\n→ CircuitPoints\n(e.g. 10th=43, 9th=36)"]
        B4["Statute Points\n(pre-computed, passed as input)"]
        B5["CompositeScore = BaseTypeScore\n+ AgencyPoints + CircuitPoints\n+ StatutePoints + ChallengeDelta"]
        B6["APA Penalty: if Expedited + completeness < 100\n→ × 1.5 multiplier"]
        B7["AssignRiskTier\n≥58 Very High / ≥45 High\n≥35 Moderate / <35 Low"]
    end

    subgraph WriteBack["Write-back to IndividualApplication"]
        W1["nepa_risk_score__c"]
        W2["nepa_risk_tier__c"]
        W3["nepa_risk_score_factors__c\n(human-readable summary + AI disclosure)"]
        W4["nepa_risk_score_updated__c"]
        W5["nepa_expedited_risk_penalty_applied__c"]
    end

    T1 & T2 & T3 -->|AsyncAfterCommit| P1
    P1 --> P2 --> P3 --> P4 --> P5 --> P6
    P3 -->|var_StatutePoints| B4
    P4 -->|SectorCircuitKey| BRE
    P5 -->|ChallengeDelta| BRE
    P6 -->|IsExpedited| BRE
    P1 -->|AgencyName, CircuitKey| BRE
    B1 & B2 & B3 & B4 --> B5 --> B6 --> B7
    B7 --> W1 & W2 & W3 & W4 & W5

    subgraph ChallengePredictor["Challenge Predictor (parallel flow)"]
        CP1["NEPA_Challenge_Predictor\n(after-save on IA)"]
        CP2["Loop: NEPA_Challenge_Prediction_Rule__mdt\n10 rules — sector, circuit, tribal flag, etc."]
        CP3["Accumulate Risk_Delta__c\n(e.g. Energy×4th=+12, Tribal=+20)"]
        CP4["Write nepa_challenge_risk_delta__c\nand nepa_challenge_prediction_basis__c"]
    end

    CP1 --> CP2 --> CP3 --> CP4 -->|feeds next Risk Scorer run| P5
```

---

## 4. CE Screening and Intake Flow

How a CE application is routed from submission through screening to review type assignment.

```mermaid
flowchart TD
    A["Applicant submits CE application\n(OmniScript NEPA_CE_Intake\nor Screen Flow fallback)"]

    subgraph CEScreeningIP["OmniStudio: CEScreeningIP Integration Procedure"]
        S1["DataRaptor Extract\nnepa_ce_library__c\n(2,105 CE codes, SOSL-searchable)"]
        S2["Query NEPA_CE_Screening_Rule__mdt\n(agency-specific + ALL fallback)"]
        S3["GIS Proximity Check\n→ NEPA_GISProximityIP"]
        S4["Extraordinary circumstances flag?\nnepa_extraordinary_circumstances_flag__c"]
    end

    subgraph BRE_CE["BRE Expression Sets — CE Screener V2"]
        C1["NEPA_CE_Screener_Tier1 DM\n(high-confidence CE codes)"]
        C2["NEPA_CE_Screener_Tier2 DM\n(ambiguous / requires review)"]
        C3["NEPA_CE_Screener_NAICS DM\n(NAICS-sector routing)"]
    end

    subgraph Outcomes["Review Type Assignment"]
        O1["CE — Auto-advance\nconfidence ≥ threshold"]
        O2["CE — Flag for review\nlow confidence or EC flag"]
        O3["EA — Route to EA pathway"]
        O4["EIS — Route to EIS pathway"]
    end

    A --> CEScreeningIP
    S1 & S2 --> BRE_CE
    S3 --> S4
    S4 -->|EC flag = true| O3
    C1 --> O1
    C2 --> O2
    C3 --> O3 & O4

    subgraph CESaveIP["OmniStudio: CESaveIP Integration Procedure"]
        W1["Create / update IndividualApplication\nnepa_review_type__c\nnepa_classification_basis__c\nnepa_ce_code__c"]
        W2["Log audit trail\n(AI confidence, human-readable rationale)"]
    end

    O1 & O2 & O3 & O4 --> CESaveIP
```

---

## 5. Stage Gate and Timeline Architecture

How timeline events, document checks, and consultation gates control stage advancement.

```mermaid
flowchart TD
    subgraph BeforeSave["Before-Save — IndividualApplication"]
        BS1["NEPA_Stage_Gate\n(before-save)"]
        BS2{Document gate\npassed?}
        BS3["NEPA_Stage_Gate_Doc_Check\n(subflow — queries ContentVersion\nvs. NEPA_Required_Document__mdt)"]
        BS4{Tribal consultation\ncertified?}
        BS5["Block stage advance\n(error message names\nmissing condition)"]
        BS6["Allow save"]
    end

    subgraph AfterSave["After-Save — ApplicationTimeline"]
        AS1["ApplicationTimeline status\n→ Completed"]
        AS2["NEPA_Stage_Gate_Orchestrator\n(after-save async)"]
        AS3["Advance IndividualApplication\nnepa_process_stage__c"]
    end

    subgraph SLAMonitor["Scheduled — Daily"]
        SLA1["NEPA_SLA_Escalation_Monitor"]
        SLA2["NEPA_SLA_Due_Date_Setter\n(before-save on ApplicationTimeline)"]
        SLA3["Escalation Task\n+ coordinator notification"]
    end

    subgraph TimelineRisk["After-Save — Timeline Risk"]
        TR1["NEPA_Timeline_Risk_Assessor\n(stage change)"]
        TR2["Get NEPA_Agency_Scoping_Baseline__mdt\n(per-agency EIS baseline)"]
        TR3{Scoping overrun?}
        TR4["nepa_scoping_overrun_flag__c = true\nnepa_projected_scoping_overrun_months__c"]
        TR5["Page count outlier check\n(NEPA_Doc_PageLimit__mdt)\nCE >17pp / EA >200pp → At Risk"]
    end

    BS1 --> BS3 --> BS2
    BS2 -->|No| BS5
    BS2 -->|Yes| BS4
    BS4 -->|EA/EIS + no certified\ntribal consultation| BS5
    BS4 -->|OK| BS6
    AS1 --> AS2 --> AS3
    SLA2 -.->|sets due date| AS1
    SLA1 -->|overdue check| SLA3
    AS3 --> TR1 --> TR2 --> TR3
    TR3 -->|Yes| TR4
    TR4 -->|feeds Risk Scorer| TR4
    TR1 --> TR5
```

---

## 6. Error Handling Architecture

Platform event pattern that guarantees error records survive transaction rollbacks.

```mermaid
sequenceDiagram
    participant Flow as Any Flow (fault path)
    participant Logger as NEPA_Error_Logger (subflow)
    participant Event as NEPA_Error_Event__e (platform event)
    participant Handler as NEPA_Error_Event_Handler
    participant Record as NEPA_Flow_Error__c
    participant Counter as NEPA_FlowError_CountIncrementer

    Flow->>Logger: fault connector fires<br/>(FaultMessage, RecordId, FlowName,<br/>FailedStep, ErrorContext)
    Note over Flow,Logger: Original transaction rolls back here
    Logger->>Event: Publish IMMEDIATELY<br/>(survives rollback)
    Event-->>Handler: async delivery (seconds–minutes)
    Handler->>Handler: validate RunningUserId length
    Handler->>Record: Create NEPA_Flow_Error__c<br/>(error_message, context, user, timestamp)
    Record->>Counter: before-save trigger
    Counter->>Counter: increment nepa_flow_error_count__c<br/>on parent IndividualApplication
```

**Key invariant:** The platform event publish is the only durable side-effect that can survive a rolled-back transaction. All 31 flows wire their fault paths to `NEPA_Error_Logger` using this pattern.

---

## 7. GIS Proximity Check Flow

How project coordinates trigger proximity checks against federal spatial datasets.

```mermaid
flowchart LR
    subgraph Trigger["Trigger"]
        T1["Program: nepa_location_lat__c\nor nepa_location_lon__c changed"]
        T2["NEPA_GIS_Proximity_Check\n(autolaunched subflow)"]
    end

    subgraph Bridge["Apex Bridge (ADR 009)"]
        B1["NepaGISProximityIPInvoker\n@InvocableMethod callout=true"]
    end

    subgraph IP["OmniStudio: NEPA_GISProximityIP"]
        I1["Read NEPA_GIS_Layer__mdt\n(layer registry — 7 layers)"]
        I2["Loop: Named Credential HTTPS\ncall each ArcGIS FeatureServer"]
        I3["Evaluate proximity buffer\n(meters, per-layer config)"]
        I4["DR_Upsert_Detected_Layer\n(nepa_detected_protection_layer__c)"]
    end

    subgraph WriteBack["Write-back to Program"]
        W1["nepa_proximity_result_summary__c"]
        W2["nepa_extraordinary_circumstances_flag__c\n(if any EC-designated layer hit)"]
        W3["nepa_gis_run_timestamp__c"]
    end

    subgraph Layers["Registered GIS Layers (NEPA_GIS_Layer__mdt)"]
        L1["BLM Surface Management"]
        L2["USFWS Critical Habitat"]
        L3["National Wetlands Inventory"]
        L4["EPA EJSCREEN EJ Index"]
        L5["FEMA Flood Zones"]
        L6["USGS Protected Areas"]
        L7["EPA GeoPub Water Bodies"]
    end

    T1 --> T2 --> B1 --> IP
    I1 --> I2
    L1 & L2 & L3 & L4 & L5 & L6 & L7 -.->|configured in CMT| I1
    I2 --> I3 --> I4
    I4 --> W1 & W2 & W3
    W2 -->|feeds| CE_Screener["NEPA_CE_Screener\n(EC flag blocks CE auto-advance)"]
```

---

## 8. Public Comment and Tribal Intelligence Flow

How a public comment is ingested, triaged, flagged for litigation history, and escalated for tribal consultation.

```mermaid
flowchart TD
    A["Comment submitted\n(web form / email / mail)"]

    subgraph Gate["Before-Save Gate"]
        G1["NEPA_Comment_Period_Gate\n(before-save on PublicComplaint)"]
        G2{Comment period\nopen?}
        G3["Reject — period closed\n(error message with close date)"]
    end

    subgraph Triage["AI-Assisted Triage (after-save)"]
        T1["NEPA_Comment_Triage_Save\n(Einstein Prompt Template)"]
        T2["nepa_ai_classification__c\n(read-only staging field)"]
        T3["nepa_ai_confidence__c\nnepa_ai_rationale__c"]
        T4["nepa_comment_classification__c\n(AI default, human-editable)"]
        T5{EJ keywords or\nlow confidence?}
        T6["Create human review Task\n(EJ escalation / low-confidence flag)"]
    end

    subgraph PlaintiffIntel["Plaintiff Intelligence (after-save)"]
        P1["NEPA_Plaintiff_Intelligence\n(PublicComplaint insert)"]
        P2["Query NEPA_Plaintiff_Profile__mdt\n(14 records incl. tribal profiles)"]
        P3{Match found?}
        P4["nepa_plaintiff_risk_flag__c = true\nCreate legal review Task"]
        P5{Is_Tribal_Nation__c\n= true?}
        P6["nepa_tribal_plaintiff_flag__c = true\n+20 risk delta points\nCreate Tribal Liaison Task"]
        P7["Stage Gate blocks EA/EIS advance\nuntil nepa_consultation_certified__c"]
    end

    subgraph Admin["Administrative Record"]
        AR1["All flags, AI outputs, rationale,\nhuman overrides → AR export\n(NEPA_Administrative_Record_Checker)"]
    end

    A --> G1 --> G2
    G2 -->|No| G3
    G2 -->|Yes| T1
    T1 --> T2 --> T3 --> T4
    T4 --> T5
    T5 -->|Yes| T6
    T4 --> P1 --> P2 --> P3
    P3 -->|No match| AR1
    P3 -->|Match| P4 --> P5
    P5 -->|No| AR1
    P5 -->|Yes| P6 --> P7 --> AR1
```

---

## 9. BRE / Decision Engine Layer

How the three Expression Sets and eight Decision Matrices are organized.

```mermaid
flowchart TB
    subgraph ES1["Expression Set: NEPA_CE_Screener V2 (Active)"]
        direction LR
        DM1["DM: NEPA_CE_Screener_NAICS\n(NAICS → review type routing)"]
        DM2["DM: NEPA_CE_Screener_Tier1\n(high-confidence CE codes)"]
        DM3["DM: NEPA_CE_Screener_Tier2\n(ambiguous CE codes)"]
    end

    subgraph ES2["Expression Set: NEPA_Litigation_Risk_Scorer V2 (Active) / V3 (Draft)"]
        direction LR
        DM4["DM: NEPA_Risk_ReviewType\n(review type → base score)"]
        DM5["DM: NEPA_Risk_Agency\n(agency → points\ne.g. BLM=39, FERC=24)"]
        DM6["DM: NEPA_Risk_Circuit\n(circuit → points\ne.g. 10th=43, 9th=36)"]
        DM7["DM: NEPA_Risk_SectorCircuit\n(sector|circuit → win rate + label\n17 cells — V3 only)"]
    end

    subgraph ES3["Expression Set: NEPA_Permit_Coordinator V2 (Active)"]
        direction LR
        DM8["DM: NEPA_Permit_Matrix_BRE\n(sector + review type → permit actions)"]
    end

    subgraph CMT["Custom Metadata (BRE Inputs — not direct DM rows)"]
        C1["NEPA_Statute_Risk_Weight__mdt\n(5 statutes: ESA=10, CWA=4, NHPA=2, NFMA=5, NGA=1)"]
        C2["NEPA_Agency_Scoping_Baseline__mdt\n(11 agencies — NOI→DEIS median months)"]
        C3["NEPA_Challenge_Prediction_Rule__mdt\n(10 rules — accumulable risk deltas)"]
        C4["NEPA_Plaintiff_Profile__mdt\n(14 records — success rates, tribal flag)"]
    end

    subgraph Flows["Invoking Flows"]
        F1["NEPA_CE_Screener\n(after-save)"]
        F2["NEPA_Litigation_Risk_Scorer\n(after-save async)"]
        F3["NEPA_Permit_Coordinator\n(invocable from Agent)"]
    end

    F1 -->|runExpressionSet| ES1
    F2 -->|runExpressionSet| ES2
    F3 -->|runExpressionSet| ES3
    C1 -->|pre-computed loop\nin NEPA_Litigation_Risk_Scorer Flow| ES2
    C2 & C3 & C4 -->|queried in flows\nbefore BRE call| F2
```

---

## 10. Deployment Package Map

What is deployed and in what order.

```mermaid
flowchart TD
    subgraph Phase1["Phase 1 — Schema (deploy first)"]
        S1["Custom Objects\n(15 objects incl. CEQ entities 5–9\nand risk intelligence objects)"]
        S2["Custom Metadata Types\n(16 CMT types)"]
        S3["Custom Metadata Records\n(risk weights, scoping baselines,\nplaintiff profiles, CE rules)"]
        S4["Permission Set\n(NEPA_Permitting — CRUD + FLS)"]
    end

    subgraph Phase2["Phase 2 — Automation"]
        A1["Decision Matrix Definitions\n(8 DMs — schema only)"]
        A2["Decision Matrix Rows\n(CSV upload via DM load workflow\ndecision_matrix_rows/*.csv)"]
        A3["Expression Set Definitions\n(3 ESs — CE Screener V2,\nRisk Scorer V2+V3 Draft,\nPermit Coordinator V2)"]
        A4["Flows (31)\n(deploy as Draft, then activate\nper QUICKSTART.md sequence)"]
    end

    subgraph Phase3["Phase 3 — OmniStudio"]
        O1["DataRaptor Extracts\n(9 DRs for CEQ export +\n3 for CE screening + GIS)"]
        O2["Integration Procedures\n(5 IPs: CEQ Export, CE Screening,\nCE Save, GIS Proximity, AR Export)"]
        O3["OmniScripts\n(NEPA_CE_Intake — 7-step wizard)"]
    end

    subgraph Phase4["Phase 4 — Agentforce"]
        AG1["Einstein Prompt Templates\n(Comment Triage, EIS Section Draft)"]
        AG2["Agentforce Agent\n(NEPA_Comment_Triage)"]
        AG3["Connected App\n(NEPA_CEQExport_API — API access)"]
    end

    subgraph Phase5["Phase 5 — Demo Data"]
        D1["Named Credentials\n(7 GIS endpoints)"]
        D2["Demo data CSVs\n(demo/import_data/*.csv — 23 files)"]
        D3["Post-load Apex scripts\n(polymorphic lookups, GIS assembly,\nflow refresh)"]
    end

    S1 --> S2 --> S3 --> S4
    S4 --> A1 --> A2 --> A3 --> A4
    A4 --> O1 --> O2 --> O3
    O3 --> AG1 --> AG2 --> AG3
    A4 --> D1 --> D2 --> D3

    style Phase1 fill:#e8f4f8,stroke:#2196f3
    style Phase2 fill:#e8f8e8,stroke:#4caf50
    style Phase3 fill:#fff8e8,stroke:#ff9800
    style Phase4 fill:#f8e8f8,stroke:#9c27b0
    style Phase5 fill:#f8f8e8,stroke:#9e9e9e
```

---

*Diagrams render in any Mermaid-compatible viewer including GitHub, GitLab, and VS Code with the Mermaid preview extension.*
