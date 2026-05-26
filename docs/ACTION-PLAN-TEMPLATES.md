# NEPA Action Plan Templates

46 Action Plan Templates across `IndividualApplication` (NEPA process) and `Visit` (discipline field survey) objects.

- **IndividualApplication APTs (39):** Deployed as metadata via Phase 8b of `scripts/deploy.sh`. Launched at runtime by `NEPA_ActionPlan_Launcher` flow when `nepa_process_stage__c` transitions to Determination or Coordination, using `NEPA_ActionPlan_Config__mdt` to select the matching template.
- **Visit APTs (7):** Shell metadata deployed via Phase 8b, but `ActionPlanType='Retail'` and `AssessmentTaskDefinition` wiring cannot be set via metadata at API v62.0. Fully populated by Apex post-load scripts `31a_postload_atd.apex` → `31b_postload_apt.apex` → `31c_postload_apt_values.apex` (run as part of `load-demo-data.sh`). Launched at runtime by `NepaVisitActionPlanLauncher` Apex trigger handler via `NEPA_Layer_Discipline__mdt` discipline → APT routing.

## Task Source Methodology

Task subjects, descriptions, and sequencing are derived from:

- **40 CFR 1500–1508** (CEQ NEPA regulations) — statutory milestone structure for scoping, draft/final EA/EIS, and ROD/FONSI phases
- **CEQ NEPA Permitting Data and Technology Standard v1.2 (2025)** — stage gate definitions and completion criteria
- **PermitTEC v0.1 litigation corpus (PNNL 2025)** — 761 NEPA litigation cases; litigation guardrail tasks at Draft and Decision phases are placed at stages with highest challenge frequency per sector
- **Agency NEPA procedures** — lead agency task sequencing per 43 CFR 46 (DOI/BLM), 36 CFR 220 (USFS), 23 CFR 771 (FHWA), BOEM 30 CFR 585, NRC 10 CFR 51, and equivalent agency NEPA handbooks
- **EIS likelihood percentages** in each template description are drawn from NEPATEC 2.0 (61,881 NEPA project records, 1988–2024)

Each sector-specific template (CE/EA/EIS × sector) expands the generic process milestone tasks with agency-specific coordination requirements, cooperating agency notifications, and CFR citation checkpoints relevant to that sector.

---

## Process Milestone Templates (3)

Generic review-type templates assigned when no sector-specific template matches. Provide the minimum required task set for each review class.

| Unique Name | Label | Tasks | Target Object | Description |
|---|---|---|---|---|
| `NEPA_CE_Process_Milestones` | NEPA CE Process Milestones | 4 | IndividualApplication | Standard CE milestone tasks. Target: 30 days from receipt to CE determination. |
| `NEPA_EA_Process_Milestones` | NEPA EA Process Milestones | 6 | IndividualApplication | Standard EA milestone tasks. Includes escalation trigger to EIS if significant impacts found. |
| `NEPA_EIS_Process_Milestones` | NEPA EIS Process Milestones | 10 | IndividualApplication | Standard EIS milestone tasks with ActivityDate offsets relative to action plan creation. |

---

## CE Sector Templates (12)

16 tasks each. Tasks cover: intake classification, screening validation, extraordinary circumstances check, agency notification, determination document preparation, supervisor approval, and record closure.

| Unique Name | Label | Lead Agencies | EIS Likelihood |
|---|---|---|---|
| `NEPA_CE_Agriculture_PublicLands` | NEPA CE - Agriculture and Public Lands | BLM, USFS, USFWS, NOAA-NMFS | 15–90% |
| `NEPA_CE_Energy_Hydro_Transmission` | NEPA CE - Energy - Hydropower and Transmission | FERC, BLM, WAPA, BPA, RUS, DOE | 70–80% |
| `NEPA_CE_Energy_Nuclear_Waste` | NEPA CE - Energy - Nuclear and Radiological Waste | NRC, DOE, DOE/NNSA | 65–95% |
| `NEPA_CE_Energy_Offshore` | NEPA CE - Energy - Offshore Oil and Gas | BOEM, BSEE | 95% |
| `NEPA_CE_Energy_OilGas_Land_Coal` | NEPA CE - Energy - Oil, Gas (Land) and Coal | BLM, OSMRE | 25–90% |
| `NEPA_CE_Energy_Pipeline_LNG` | NEPA CE - Energy - Pipeline and LNG | FERC/DOE, PHMSA | 60–85% |
| `NEPA_CE_Energy_Renewables_Solar_Geo` | NEPA CE - Energy - Renewables (Solar and Geothermal) | BLM | 70–75% |
| `NEPA_CE_Materials_Mining` | NEPA CE - Materials - Mining (Metals and Non-Metallic) | BLM | 35–85% |
| `NEPA_CE_Military_Urban_Regulatory` | NEPA CE - Military, Urban Development, and Regulatory Actions | DoD, GSA, DOE, NSF, NIH | 25–80% |
| `NEPA_CE_Transportation_Land` | NEPA CE - Transportation - Land (Highway, Rail, Aviation) | FHWA, FRA, STB, FAA | 55–75% |
| `NEPA_CE_Transportation_Water` | NEPA CE - Transportation - Water (Ports and Bridges) | USACE, USCG, FHWA | 50–70% |
| `NEPA_CE_Water_Resources` | NEPA CE - Water Resources and Waste Management | BOR, USACE, DOE/BLM | 30–70% |

---

## EA Sector Templates (12)

22–32 tasks each (varies by cooperating agency complexity). Tasks cover: scoping, public notice, alternatives analysis, Draft EA preparation and comment period, FONSI or EIS escalation decision, Final EA, and record closure. Litigation guardrail tasks embedded at Draft and FONSI decision phases.

| Unique Name | Label | Tasks | Lead Agencies | EIS Likelihood |
|---|---|---|---|---|
| `NEPA_EA_Agriculture_PublicLands` | NEPA EA - Agriculture and Public Lands | 32 | BLM, USFS, USFWS, NOAA-NMFS | 15–90% |
| `NEPA_EA_Energy_Hydro_Transmission` | NEPA EA - Energy - Hydropower and Transmission | 26 | FERC, BLM, WAPA, BPA, RUS, DOE | 70–80% |
| `NEPA_EA_Energy_Nuclear_Waste` | NEPA EA - Energy - Nuclear and Radiological Waste | 26 | NRC, DOE, DOE/NNSA | 65–95% |
| `NEPA_EA_Energy_Offshore` | NEPA EA - Energy - Offshore Oil and Gas | 22 | BOEM, BSEE | 95% |
| `NEPA_EA_Energy_OilGas_Land_Coal` | NEPA EA - Energy - Oil, Gas (Land) and Coal | 24 | BLM, OSMRE | 25–90% |
| `NEPA_EA_Energy_Pipeline_LNG` | NEPA EA - Energy - Pipeline and LNG | 26 | FERC/DOE, PHMSA | 60–85% |
| `NEPA_EA_Energy_Renewables_Solar_Geo` | NEPA EA - Energy - Renewables (Solar and Geothermal) | 26 | BLM | 70–75% |
| `NEPA_EA_Materials_Mining` | NEPA EA - Materials - Mining (Metals and Non-Metallic) | 25 | BLM | 35–85% |
| `NEPA_EA_Military_Urban_Regulatory` | NEPA EA - Military, Urban Development, and Regulatory Actions | 32 | DoD, GSA, DOE, NSF, NIH | 25–80% |
| `NEPA_EA_Transportation_Land` | NEPA EA - Transportation - Land (Highway, Rail, Aviation) | 28 | FHWA, FRA, STB, FAA | 55–75% |
| `NEPA_EA_Transportation_Water` | NEPA EA - Transportation - Water (Ports and Bridges) | 26 | USACE, USCG, FHWA | 50–70% |
| `NEPA_EA_Water_Resources` | NEPA EA - Water Resources and Waste Management | 28 | BOR, USACE, DOE/BLM | 30–70% |

---

## EIS Sector Templates (10)

29–38 tasks each. Tasks cover: Notice of Intent (NOI), scoping period, alternatives development, Draft EIS preparation, 45-day public comment period, response to comments, Final EIS, 30-day waiting period, Record of Decision (ROD), and monitoring plan. Litigation guardrail tasks at Draft EIS and ROD phases reflect the highest-frequency challenge points in the PermitTEC corpus.

| Unique Name | Label | Tasks | Lead Agencies | EIS Likelihood |
|---|---|---|---|---|
| `NEPA_EIS_Agriculture_PublicLands` | NEPA EIS - Agriculture and Public Lands | 38 | BLM, USFS, USFWS, NOAA-NMFS | 15–90% |
| `NEPA_EIS_Energy_Hydro_Transmission` | NEPA EIS - Energy - Hydropower and Transmission | 33 | FERC, BLM, WAPA, BPA, RUS, DOE | 70–80% |
| `NEPA_EIS_Energy_Nuclear_Waste` | NEPA EIS - Energy - Nuclear and Radiological Waste | 33 | NRC, DOE, DOE/NNSA | 65–95% |
| `NEPA_EIS_Energy_Offshore` | NEPA EIS - Energy - Offshore Oil and Gas | 29 | BOEM, BSEE | 95% |
| `NEPA_EIS_Energy_OilGas_Land_Coal` | NEPA EIS - Energy - Oil, Gas (Land) and Coal | 30 | BLM, OSMRE | 25–90% |
| `NEPA_EIS_Energy_Pipeline_LNG` | NEPA EIS - Energy - Pipeline and LNG | 33 | FERC/DOE, PHMSA | 60–85% |
| `NEPA_EIS_Energy_Renewables_Solar_Geo` | NEPA EIS - Energy - Renewables (Solar and Geothermal) | 33 | BLM | 70–75% |
| `NEPA_EIS_Materials_Mining` | NEPA EIS - Materials - Mining (Metals and Non-Metallic) | 32 | BLM | 35–85% |
| `NEPA_EIS_Military_Urban_Regulatory` | NEPA EIS - Military, Urban Development, and Regulatory Actions | 38 | DoD, GSA, DOE, NSF, NIH | 25–80% |
| `NEPA_EIS_Transportation_Land` | NEPA EIS - Transportation - Land (Highway, Rail, Aviation) | 34 | FHWA, FRA, STB, FAA | 55–75% |
| `NEPA_EIS_Transportation_Water` | NEPA EIS - Transportation - Water (Ports and Bridges) | 33 | USACE, USCG, FHWA | 50–70% |
| `NEPA_EIS_Water_Resources` | NEPA EIS - Water Resources and Waste Management | 34 | BOR, USACE, DOE/BLM | 30–70% |

---

## Visit Discipline Milestone Templates (7)

4 items each. Assigned to `Visit` records auto-created by `NepaLayerDisciplineResolver` when GIS proximity detection flags a resource-specific extraordinary circumstance. Items use `itemEntityType=AssessmentTask` with `TaskType=InspectionChecklist` and are wired to `AssessmentTaskDefinition` records, aligning with the PSS Assessment Execution pattern for field surveys. Items cover desktop review, field assessment window compliance, agency coordination memo, and final report upload.

**Deploy note:** `ActionPlanType='Retail'` and `AssessmentTaskDefinitionId` item values are not settable via metadata at API v62.0. The shell APT XML deploys via Phase 8b; full population requires the `31a` → `31b` → `31c` Apex post-load sequence.

| Unique Name | Label | Trigger | Cooperating Agencies |
|---|---|---|---|
| `NEPA_Visit_Aquatic_Milestones_BLM` | NEPA Visit Aquatic Milestones | NHD / riparian GIS layer | USFWS, NOAA-NMFS, USACE |
| `NEPA_Visit_BigGame_Milestones_BLM` | NEPA Visit Big Game Milestones | State Wildlife Agency critical habitat | State Wildlife Agency, BLM, USFS |
| `NEPA_Visit_Botanical_Milestones_BLM` | NEPA Visit Botanical Milestones | FWS Critical Habitat / rare plant GIS | USFWS, BLM |
| `NEPA_Visit_Geology_Milestones_BLM` | NEPA Visit Geology Milestones | EPA Superfund NPL / contamination GIS layer | EPA, USACE |
| `NEPA_Visit_Hydrology_Milestones_BLM` | NEPA Visit Hydrology Milestones | NWI Wetlands / aquatic GIS layer | USACE, EPA, USFWS |
| `NEPA_Visit_MigratoryBird_Milestones_BLM` | NEPA Visit Migratory Bird Milestones | MBTA / avian habitat GIS layer | USFWS |
| `NEPA_Visit_SageGrouse_Milestones_BLM` | NEPA Visit Sage-Grouse Milestones | FWS Critical Habitat (Sage-Grouse) | USFWS, BLM |

---

## Summary

| Category | Templates | Total Tasks |
|---|---|---|
| Process Milestones (CE/EA/EIS) | 3 | 20 |
| CE Sector | 12 | 192 |
| EA Sector | 12 | 311 |
| EIS Sector | 12 | 385 |
| Visit Discipline | 7 | 28 |
| **Total** | **46** | **936** |
