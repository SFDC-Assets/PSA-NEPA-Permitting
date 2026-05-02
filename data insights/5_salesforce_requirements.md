# PSA-NEPA-Permitting-Data-Model: Requirements Specification

## PSS Object Mapping

| CEQ Entity | Salesforce Object | Key Fields Needed | Notes |
|---|---|---|---|
| Project | Program (PSS standard) | Name, Lead_Agency__c, Project_State__c, Project_Circuit__c, Sector__c, Num_Sectors__c | Parent container for all NEPA actions on a single federal undertaking |
| Process (NEPA action lifecycle) | IndividualApplication | Status, Stage__c, NEPA_Pathway__c (CE/EA/EIS), CE_Code__c, Litigation_Risk_Score__c | Carries lifecycle stage/status; one per NEPA determination event |
| NEPA Documents (EA, EIS, CE memo, FONSI, ROD) | ContentVersion (NEPA record type) | Document_Type__c, Total_Pages__c, CE_Category__c, Supplementation_Flag__c | Record type enforces NEPA-specific metadata; version control for drafts |
| Public Comments (scoping, DEIS) | PublicComplaint | Commenter_Organization__c, Comment_Period__c, Substantive_Flag__c | Native PSS intake; feeds Plaintiff_Intelligence flow |
| Public Engagement Events | nepa_engagement__c | Event_Type__c, Event_Date__c, Attendance_Count__c, Tribal_Consultation_Flag__c | Custom; scoping meetings, hearings, tribal consultation sessions |
| Case Events/Milestones | ApplicationTimeline | Milestone_Type__c, Due_Date__c, Completion_Date__c, Stage_Gate__c | PSS standard; supports NEPA_Timeline_Risk_Assessor |
| Litigation | nepa_litigation__c | Case_Citation__c, Plaintiff__c, Circuit__c, Cause_of_Action__c, Outcome__c | Custom; feeds historical training data for risk scoring |

---

## Custom Fields

| Object | API Name | Data Type | Description | Required? |
|---|---|---|---|---|
| Program | Lead_Agency__c | Picklist | Federal lead agency (BLM, DOE, USDA, DHS-CBP, DoD, etc.) | Yes |
| Program | Project_State__c | Picklist | U.S. state where action occurs; drives geographic risk multiplier | Yes |
| Program | Project_Circuit__c | Picklist | Federal judicial circuit (1st–11th, DC, Federal) | Yes |
| Program | Sector__c | Multi-Select Picklist | Energy, Transportation, Agriculture, Military, Realty, Utilities | Yes |
| Program | Num_Sectors__c | Number(2,0) | Count of sectors touched; drives CE complexity flag | Yes |
| IndividualApplication | Project_Type__c | Picklist | Stage 1 rank-2 feature (Oil/Gas, ROW, Grazing, Pipeline, etc.) | Yes |
| IndividualApplication | Sponsor__c | Text(255) | Non-federal applicant/operator (Stage 1 rank-4) | Yes |
| IndividualApplication | Action_Description__c | Long Text Area(32K) | Narrative of proposed action; NLP-scanned for keywords | Yes |
| IndividualApplication | NEPA_Pathway__c | Picklist | CE / EA / EIS determination outcome | No |
| IndividualApplication | CE_Code__c | Picklist | 516 DM 11.9 §, Section 390 EPAct, FLPMA 402(h)(1) code | No |
| IndividualApplication | CE_Category__c | Text(80) | Regulatory citation string | No |
| IndividualApplication | CE_Complexity_Flag__c | Picklist | NORMAL / ELEVATED (≥3 sectors) | No |
| IndividualApplication | Surface_Disturbance_Acres__c | Number(10,2) | For Section 390 (b)(1) eligibility test | No |
| IndividualApplication | Prior_NEPA_Exists__c | Checkbox | Existing NEPA analysis within 5 years | No |
| IndividualApplication | Prior_NEPA_Date__c | Date | Date of prior NEPA document | No |
| IndividualApplication | Total_Pages__c | Number(5,0) | Document length (Stage 1 rank-6) | No |
| IndividualApplication | Litigation_Risk_Score__c | Number(6,2) | Composite output of Risk_Scorer flow | No |
| IndividualApplication | Plaintiff_Risk_Flag__c | Checkbox | TRUE if known repeat-plaintiff commenter detected | No |
| IndividualApplication | Adjacent_Statutes__c | Multi-Select Picklist | ESA, CWA, NHPA, MBTA, FLPMA | No |
| IndividualApplication | Cumulative_Analysis_Complete__c | Checkbox | Stage 4 guardrail for EIS supplementation | No |
| IndividualApplication | Supplementation_Reviewed__c | Checkbox | Stage 4 rank-3 validation | No |
| IndividualApplication | NEPA_Waiver_Invoked__c | Checkbox | Triggers elevated review (Stage 4 rank-2) | No |
| IndividualApplication | Administrative_Record_Complete__c | Checkbox | Stage gate validation | No |
| IndividualApplication | Connected_Actions_Identified__c | Checkbox | 40 CFR 1508.25 compliance | No |
| IndividualApplication | Permit_Coordination_Status__c | Picklist | NOT_STARTED / IN_PROGRESS / COMPLETE | No |
| IndividualApplication | Co_Permits_Required__c | Multi-Select Picklist | Section 404, ESA §7, NHPA §106, ROW grant | No |
| IndividualApplication | Defensibility_Score__c | Number(3,0) | 0–100 computed score from gap checker | No |
| PublicComplaint | Commenter_Organization__c | Text(255) | Organization name; matched against Plaintiff_Profiles__mdt | No |
| PublicComplaint | Substantive_Flag__c | Checkbox | Comment raises substantive NEPA issue | No |
| nepa_engagement__c | Event_Type__c | Picklist | Scoping / Public Hearing / Tribal Consultation | Yes |
| nepa_engagement__c | Tribal_Consultation_Flag__c | Checkbox | Section 106 / E.O. 13175 event | No |
| nepa_litigation__c | Case_Citation__c | Text(255) | Reporter citation | Yes |
| nepa_litigation__c | Cause_of_Action__c | Multi-Select Picklist | Cumulative impacts / Supplementation / Waiver / Segmentation | Yes |
| nepa_litigation__c | Circuit__c | Picklist | Adjudicating circuit | Yes |

---

## Custom Metadata Types

### 1. Agency_Risk_Rates__mdt
**Structure:** `Agency_Name__c` (Text), `Base_Risk_Rate__c` (Number 3,2), `Historical_Case_Count__c` (Number), `Top_Failure_Mode__c` (Text)

| Agency_Name | Base_Risk_Rate | Historical_Case_Count | Top_Failure_Mode |
|---|---|---|---|
| Department of the Interior - Bureau of Land Management | 0.72 | 147 | Cumulative/connected actions |
| Department of Homeland Security - CBP | 0.85 | 12 | Improper NEPA waiver invocation |
| Department of Defense | 0.58 | 34 | Supplementation failure |

### 2. Circuit_Court_Risk_Weights__mdt
**Structure:** `Circuit__c` (Picklist), `Plaintiff_Success_Rate__c` (Number), `Weight_Multiplier__c` (Number 3,2)

| Circuit | Plaintiff_Success_Rate | Weight_Multiplier |
|---|---|---|
| 9th Circuit | 0.48 | 1.40 |
| 10th Circuit | 0.31 | 1.10 |
| DC Circuit | 0.38 | 1.20 |

### 3. Statute_Risk_Weights__mdt
**Structure:** `Statute__c` (Picklist), `Weight__c` (Number), `Typical_Cause_of_Action__c` (Text)

| Statute | Weight | Typical_Cause_of_Action |
|---|---|---|
| ESA | 15 | Section 7 consultation failure |
| CWA | 10 | Section 404 permit inadequacy |
| NHPA | 8 | Section 106 consultation failure |

### 4. CE_Code_Catalog__mdt
**Structure:** `CE_Code__c` (Text), `Regulatory_Authority__c` (Text), `Description__c` (Long Text), `Max_Disturbance_Acres__c` (Number)

| CE_Code | Regulatory_Authority | Description | Max_Disturbance_Acres |
|---|---|---|---|
| 516 DM 11.9 E(9) | 516 DM 11.9 §E(9) | ROW renewal/assignment, no new rights or disturbance | 0 |
| EPAct 390(b)(1) | Section 390 EPAct 2005 | Individual surface disturbance <5 acres w/ prior NEPA | 5 |
| EPAct 390(b)(4) | Section 390 EPAct 2005 | Pipeline placement in approved ROW corridor ≤5 yrs | NULL |

### 5. CE_Screening_Rules__mdt
**Structure:** `Rule_Id__c`, `Project_Type_Match__c`, `Agency_Match__c`, `Condition_Logic__c` (Long Text), `Resulting_CE_Code__c`

| Rule_Id | Project_Type_Match | Agency_Match | Condition_Logic | Resulting_CE_Code |
|---|---|---|---|---|
| CE-001 | Oil & Gas - Drilling | BLM | pad_exists_prior_5yr == TRUE | EPAct 390(b)(2) |
| CE-014 | Pipeline | BLM | in_existing_corridor AND corridor_age<=5yr | EPAct 390(b)(4) |
| CE-022 | ROW Renewal | BLM | no_new_disturbance AND no_new_rights | 516 DM 11.9 E(9) |

### 6. Challenge_Prediction_Rules__mdt
**Structure:** `Rule_Id__c`, `Trigger_Pattern__c`, `Predicted_Cause__c`, `Probability__c`, `Mitigation_Action__c`

| Rule_Id | Trigger_Pattern | Predicted_Cause | Probability | Mitigation_Action |
|---|---|---|---|---|
| CP-001 | EIS relies on prior EIS >3yrs old | Supplementation failure | 0.72 | Trigger supplemental NEPA review |
| CP-002 | Multi-phase project, single NEPA doc | Connected actions failure | 0.65 | Segmentation analysis required |
| CP-003 | Statutory waiver invoked | Waiver challenge | 0.80 | Legal memo required |

### 7. Required_Document_Registry__mdt
**Structure:** `NEPA_Pathway__c`, `Document_Type__c`, `Required__c`, `Stage_Gate__c`

| NEPA_Pathway | Document_Type | Required | Stage_Gate |
|---|---|---|---|
| CE | CE Determination Memo | TRUE | Decision |
| EA | Finding of No Significant Impact (FONSI) | TRUE | Decision |
| EIS | Record of Decision (ROD) | TRUE | Decision |

### 8. Plaintiff_Profiles__mdt
**Structure:** `Organization_Name__c`, `Risk_Tier__c` (LOW/MEDIUM/HIGH/VERY_HIGH), `Prior_Case_Count__c`, `Success_Rate__c`, `Typical_Causes__c`

| Organization_Name | Risk_Tier | Prior_Case_Count | Success_Rate | Typical_Causes |
|---|---|---|---|---|
| WildEarth Guardians | VERY_HIGH | 47 | 0.55 | Cumulative impacts; ESA |
| Center for Biological Diversity | VERY_HIGH | 82 | 0.51 | ESA §7; supplementation |
| Western Watersheds Project | HIGH | 29 | 0.46 | Grazing; sage-grouse |

### 9. State_Geographic_Risk_Weights__mdt
**Structure:** `State__c` (Picklist), `Risk_Multiplier__c` (Number 3,2), `Dominant_Circuit__c`, `Rationale__c`

| State | Risk_Multiplier | Dominant_Circuit | Rationale |
|---|---|---|---|
| California | 1.45 | 9th | High plaintiff density + 9th Circuit forum |
| Oregon | 1.40 | 9th | Sage-grouse habitat + 9th Circuit |
| New Mexico | 1.15 | 10th | Oil & gas density, moderate plaintiff activity |

---

## Flow Logic

### NEPA_Litigation_Risk_Scorer
```
INPUT: IndividualApplication record
DECLARE score = 0

// Agency base
agency_rate = Agency_Risk_Rates__mdt.WHERE(Agency_Name == record.Program.Lead_Agency__c).Base_Risk_Rate__c
score += agency_rate * 100

// Circuit weight
circuit_weight = Circuit_Court_Risk_Weights__mdt.WHERE(Circuit == record.Program.Project_Circuit__c).Weight_Multiplier__c
score += circuit_weight * 10

// Adjacent statutes
FOR EACH statute IN record.Adjacent_Statutes__c:
  statute_weight = Statute_Risk_Weights__mdt.WHERE(Statute == statute).Weight__c
  score += statute_weight

// State multiplier
state_mult = State_Geographic_Risk_Weights__mdt.WHERE(State == record.Program.Project_State__c).Risk_Multiplier__c
score = score * state_mult

// Plaintiff bonus
IF record.Plaintiff_Risk_Flag__c == TRUE:
  score += PLAINTIFF_RISK_BONUS  // constant = 25

SET IndividualApplication.Litigation_Risk_Score__c = score

IF score >= 150: CREATE Task "Legal Defensibility Deep-Dive" ASSIGNED TO Solicitor
```

### NEPA_CE_Screener
```
INPUT: IndividualApplication record

// Sector complexity
IF record.Program.Num_Sectors__c >= 3:
  SET record.CE_Complexity_Flag__c = 'ELEVATED'
  CREATE Task "Senior NEPA Coordinator Review Required"
ELSE:
  SET record.CE_Complexity_Flag__c = 'NORMAL'

eligible_ce_codes = []
disqualifying_conditions = []

FOR EACH rule IN CE_Screening_Rules__mdt:
  IF rule.Project_Type_Match__c == record.Project_Type__c
     AND rule.Agency_Match__c == record.Program.Lead_Agency__c
     AND EVALUATE(rule.Condition_Logic__c, record) == TRUE:
       eligible_ce_codes.ADD(rule.Resulting_CE_Code__c)

// Extraordinary circumstances check
IF record.Surface_Disturbance_Acres__c > 5: disqualifying_conditions.ADD('Exceeds 5-acre threshold')
IF record.Adjacent_Statutes__c CONTAINS 'ESA': disqualifying_conditions.ADD('ESA listed species potentially affected')

IF eligible_ce_codes.SIZE > 0 AND disqualifying_conditions.SIZE == 0:
  SET record.NEPA_Pathway__c = 'CE'
  SET record.CE_Code__c = eligible_ce_codes[0]
ELSE:
  ROUTE TO NEPA_CE_Determination_Router (EA/EIS decision)

RETURN eligible_ce_codes, disqualifying_conditions
```

### NEPA_Plaintiff_Intelligence
```
TRIGGER: AFTER INSERT on PublicComplaint

INPUT: PublicComplaint record
profile = Plaintiff_Profiles__mdt.WHERE(Organization_Name__c == record.Commenter_Organization__c)

IF profile EXISTS AND profile.Risk_Tier__c IN ('MEDIUM', 'HIGH', 'VERY_HIGH'):
  parent_app = record.Related_IndividualApplication
  SET parent_app.Plaintiff_Risk_Flag__c = TRUE
  UPDATE parent_app

  CREATE Task:
    Subject = "Legal Defensibility Review - " + profile.Organization_Name__c + " (" + profile.Risk_Tier__c + ")"
    Priority = 'High'
    AssignedTo = parent_app.NEPA_Coordinator__c
    Description = "Repeat plaintiff commenter identified. Prior cases: " + profile.Prior_Case_Count__c +
                  ". Success rate: " + profile.Success_Rate__c +
                  ". Typical causes: " + profile.Typical_Causes__c

  // Rescore litigation risk
  INVOKE NEPA_Litigation_Risk_Scorer(parent_app)
```

---

## Expression Set Pseudocode

```
RULE SVR-001: Cumulative & Connected Actions Analysis Gate
  TRIGGER: IndividualApplication.NEPA_Pathway__c == 'EIS' AND Stage__c advancing to 'Draft EIS Publication'
  VALIDATE: Cumulative_Analysis_Complete__c == TRUE AND Connected_Actions_Identified__c == TRUE
  ON_FAIL:
    BLOCK_TRANSITION: true
    ERROR_MESSAGE: "Draft EIS cannot be published without documented cumulative impacts analysis (40 CFR 1508.7) and identification of connected/similar actions (40 CFR 1508.25). Complete Cumulative Analysis and Connected Actions sections before advancing."
  REGULATORY_BASIS: 40 CFR 1502.9(c); 40 CFR 1508.25; 40 CFR 1508.7
```

```
RULE SVR-002: NEPA Waiver Statutory Authority Verification
  TRIGGER: IndividualApplication.NEPA_Waiver_Invoked__c == TRUE
  VALIDATE: Waiver_Legal_Memo_Attached__c == TRUE AND Solicitor_Approval_Date__c != NULL
  ON_FAIL:
    BLOCK_TRANSITION: true
    ERROR_MESSAGE: "Any statutory NEPA waiver (e.g., IIRIRA §102(c)) requires a Solicitor's Office legal memo confirming the underlying statutory authority and funding source. Upload memo and record Solicitor approval before proceeding."
  REGULATORY_BASIS: 42 USC 4332(2)(C); IIRIRA Section 102(c); 40 CFR 1501.4
```

```
RULE SVR-003: EIS Supplementation Review Checkpoint
  TRIGGER: IndividualApplication.NEPA_Pathway__c == 'EIS' AND (Prior_NEPA_Date__c older than 3 years OR New_Information_Flag__c == TRUE)
  VALIDATE: Supplementation_Reviewed__c == TRUE AND Supplementation_Decision_Memo__c != NULL
  ON_FAIL:
    BLOCK_TRANSITION: true
    ERROR_MESSAGE: "Prior NEPA analysis exceeds 3 years or new information has been flagged. A supplementation review determination is required under Marsh v. ONRC before the agency may rely on prior analysis. Document decision in Supplementation Memo."
  REGULATORY_BASIS: 40 CFR 1502.9(c)(1)(ii); Marsh v. ONRC, 490 U.S. 360 (1989)
```

```
RULE SVR-004: CE Extraordinary Circumstances Screening
  TRIGGER: IndividualApplication.NEPA_Pathway__c == 'CE'
  VALIDATE: Extraordinary_Circumstances_Screened__c == TRUE AND (ESA_Consultation_Status__c != 'REQUIRED_NOT_COMPLETE')
  ON_FAIL:
    BLOCK_TRANSITION: true
    ERROR_MESSAGE: "CE determinations require documented extraordinary circumstances review per 43 CFR 46.215. Where ESA-listed species may be present, Section 7 consultation must be initiated or concluded before CE is finalized."
  REGULATORY_BASIS: 43 CFR 46.215; 516 DM 2 App. 2; 16 USC 1536(a)(2)
```

```
RULE SVR-005: Administrative Record Completeness at Decision
  TRIGGER: IndividualApplication.Stage__c advancing to 'Decision Issued' (ROD/FONSI/CE Memo)
  VALIDATE: Administrative_Record_Complete__c == TRUE AND Required_Document_Registry fully satisfied for NEPA_Pathway__c
  ON_FAIL:
    BLOCK_TRANSITION: true
    ERROR_MESSAGE: "Decision cannot be issued until the administrative record is certified complete and all required documents for this NEPA pathway are attached (see Required Document Registry). Incomplete records are the leading cause of remand."
  REGULATORY_BASIS: 5 USC 706; 40 CFR 1505.2
```

---

## Agile User Stories

**Story 1: Intake Routing to CE/EA/EIS**
- As a NEPA Coordinator, I want incoming IndividualApplications automatically classified into CE, EA, or EIS pathways using predictive features (project_type, sponsor, sector, lead_agency, description keywords, acreage) so that I can triage workload and avoid misclassification of routine actions.
- Acceptance Criteria:
  - [ ] On IndividualApplication create/update, NEPA_CE_Screener flow evaluates CE_Screening_Rules__mdt and sets NEPA_Pathway