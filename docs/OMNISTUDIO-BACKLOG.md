# OmniStudio Backlog — PSA-NEPA Permitting Accelerator

> **Status: Backlog — implementation not successfully completed**
>
> The OmniStudio metadata files described in this document are present in the repository
> but were not successfully deployed and verified during development. These features are
> backlog items. Do not present them as delivered capabilities.

---

## What This Covers

Four features that depend on OmniStudio (OmniScript, DataRaptor Data Mapper, and Integration Procedures) were designed and partially authored but are **not working as deployed**. The metadata files exist in the repository as design artifacts and resumption starting points.

---

## Backlog Features

### F1 — CE Intake Guided Wizard

The CE intake workflow is served by two paths:

| Path | Status |
|---|---|
| Screen Flow: `NEPA_CE_Intake` | **Delivered** — flows, BRE, and Decision Matrix screening work end-to-end |
| OmniScript wizard: `NEPA_CEIntake` | **Backlog** — not verified; requires OmniStudio activation and Integration Procedure activation |

**Backlog OmniStudio components:**

| Component | File | Purpose |
|---|---|---|
| `NEPA_CEIntake` OmniScript | `force-app/main/default/omniScripts/NEPA_CEIntake_OmniScript_1.os-meta.xml` | 7-step guided intake wizard |
| `NEPA_CEScreeningIP` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_CEScreeningIP_Procedure_1.oip-meta.xml` | Calls CE screener flow at step 3→4 |
| `NEPA_CESaveIP` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_CESaveIP_Procedure_1.oip-meta.xml` | Upserts IndividualApplication at submit |
| `NEPA_CEScreeningIPTest` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_CEScreeningIPTest_Procedure_1.oip-meta.xml` | Debug/test version of screening IP |
| `DR_Load_NEPA_Process` DataRaptor | `force-app/main/default/omniDataTransforms/DR_Load_NEPA_Process.json` + `.rpt-meta.xml` | Writes to IndividualApplication |
| `nepaIndustryCodePickerOmni` LWC | `force-app/main/default/lwc/nepaIndustryCodePickerOmni/` | OmniScript custom element — NAICS code picker |
| `nepaSiteLocationPickerOmni` LWC | `force-app/main/default/lwc/nepaSiteLocationPickerOmni/` | OmniScript custom element — ArcGIS map polygon capture |

**What IS delivered for CE screening (no dependency on OmniStudio):**
- BRE Decision Matrices (NAICS Routing, Tier 1, Tier 2) and all Expression Sets
- `NEPA_CE_Screener` autolaunched flow — evaluates 2,105 CE library entries
- `nepa_ce_library__c` custom object with 2,105 CE codes across 79 agencies
- `NEPA_CE_Intake` Screen Flow — alternative intake path without OmniStudio dependency

---

### F2 — GIS Proximity Analysis (OmniIP Path)

The GIS proximity check has two paths:

| Path | Status |
|---|---|
| `NEPA_GIS_Layer__mdt` catalog (15 layers) and `nepa_gis_data__c` object | **Delivered** — schema, metadata, and GIS layer registry are fully deployed |
| Integration Procedure invocation via `NEPA_GISProximityIP` | **Backlog** — the Apex bridge class and Integration Procedure have not been successfully end-to-end tested |

**Backlog OmniStudio components:**

| Component | File | Purpose |
|---|---|---|
| `NEPA_GISProximityIP` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_GISProximityIP_Procedure_1.oip-meta.xml` | Calls GIS services, writes results to nepa_gis_data__c |
| `DR_Extract_GIS_Layers` DataRaptor | `force-app/main/default/omniDataTransforms/DR_Extract_GIS_Layers.json` + `.rpt-meta.xml` | Reads active GIS layers |
| `DR_Load_GIS_Results` DataRaptor | `force-app/main/default/omniDataTransforms/DR_Load_GIS_Results.json` + `.rpt-meta.xml` | Writes GIS results |
| `DR_Upsert_Detected_Layer` DataRaptor | `force-app/main/default/omniDataTransforms/DR_Upsert_Detected_Layer.json` + `.rpt-meta.xml` | Upserts detected protection layer records |
| `NepaGISProximityIPInvoker.cls` Apex bridge | `force-app/main/default/classes/NepaGISProximityIPInvoker.cls` | `@InvocableMethod` called from flow; invokes the IP |

**Design note (ADR 009):** The Apex bridge pattern is architecturally correct — Flow `<subflows>` cannot call OmniIntegrationProcedures directly. The bridge class calls `omnistudio.IntegrationProcedureService.invokeMethod()`. The pattern is sound; what was not successfully completed was the end-to-end activation and verification.

---

### F3 — CEQ Data Export via Integration Procedure

The CEQ REST export API has three layers:

| Path | Status |
|---|---|
| `NepaCeqExportService.cls` — process-level export | **Delivered** — Apex-based export covering all 13 entities via REST endpoint `GET /services/apexrest/nepa/v1/processes/{id}` |
| `NepaCeqFullExportService.cls` — full project graph export | **Delivered** — Apex-based full-graph export producing the complete CEQ v1.2 nested payload via `POST /services/apexrest/nepa/v1/export/project` |
| `NEPA_CEQExport_Procedure` Integration Procedure + Extract DataRaptors | **Backlog / Abandoned** — the OmniStudio-based export path was not successfully deployed; a "valid bundle name" error endemic to the org's OmniStudio platform configuration is unresolvable. The DR JSON files are present as design artifacts. The Apex services above are the working export paths. |

**Backlog OmniStudio components (abandoned — Apex services replace these):**

| Component | File | Purpose |
|---|---|---|
| `NEPA_CEQExport_Procedure` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_CEQExport_Procedure_1.oip-meta.xml` | Orchestrates all 10 DataRaptor Extracts |
| `DR_Extract_NEPA_Process` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_Process.json` + `.rpt-meta.xml` | Extracts Process (IndividualApplication) |
| `DR_Extract_NEPA_Project` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_Project.json` + `.rpt-meta.xml` | Extracts Project (Program) |
| `DR_Extract_NEPA_Document` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_Document.json` + `.rpt-meta.xml` | Extracts Documents (ContentVersion) |
| `DR_Extract_NEPA_CaseEvent` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_CaseEvent.json` + `.rpt-meta.xml` | Extracts Case Events (ApplicationTimeline) |
| `DR_Extract_NEPA_Comment` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_Comment.json` + `.rpt-meta.xml` | Extracts Comments (PublicComplaint) |
| `DR_Extract_NEPA_EngagementEvent` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_EngagementEvent.json` + `.rpt-meta.xml` | Extracts Engagement Events (nepa_engagement__c) |
| `DR_Extract_NEPA_LegalStructure` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_LegalStructure.json` + `.rpt-meta.xml` | Extracts Legal Structure (RegulatoryCode) |
| `DR_Extract_NEPA_RequiredPermit` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_RequiredPermit.json` + `.rpt-meta.xml` | Extracts Required Permits (implemented in Apex full-graph service) |
| `DR_Extract_NEPA_TeamMember` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_TeamMember.json` + `.rpt-meta.xml` | Extracts Team Members |
| `DR_Extract_NEPA_GISData` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_GISData.json` + `.rpt-meta.xml` | Extracts GIS Data |
| `DR_Extract_NEPA_GISDataByProcess` | `force-app/main/default/omniDataTransforms/DR_Extract_NEPA_GISDataByProcess.json` + `.rpt-meta.xml` | Extracts GIS Data filtered by process |

**What IS delivered for CEQ export (no dependency on OmniStudio):**
- `NepaCeqExportService.cls` — Apex service covering all 13 entities; `GET /services/apexrest/nepa/v1/processes/{id}`; used for per-process cross-agency callouts
- `NepaCeqFullExportService.cls` — Apex service producing the complete CEQ v1.2 project graph (Project → Processes → Documents+Comments, Engagement Events, Case Events, Team Members, GIS, Permits); `POST /services/apexrest/nepa/v1/export/project`; bulk-safe (11 SOQL queries, all outside loops); 500-process hard limit
- Full test coverage in `NepaCeqExportServiceTest` (36 tests including 9 PIC v1.2 compliance tests) and `NepaCeqFullExportServiceTest` (13 tests covering schema version, field name compliance, nested comment structure, GIS at project and process level, permit DTOs, and error guard rails)

---

### F4 — Pre-Application Permit Screening

| Component | File | Status |
|---|---|---|
| `NEPA_PreAppScreeningIP` Integration Procedure | `force-app/main/default/omniIntegrationProcedures/NEPA_PreAppScreeningIP_Procedure_1.oip-meta.xml` | **Backlog** — Integration Procedure not verified |
| `DR_Extract_PreApp_PermitMatrix` DataRaptor | `force-app/main/default/omniDataTransforms/DR_Extract_PreApp_PermitMatrix.json` | **Backlog** — DataRaptor not verified |
| `NepaPreAppScreeningController.cls` Apex bridge | `force-app/main/default/classes/NepaPreAppScreeningController.cls` | Authored but IP path unverified |
| `NepaPreAppQualifySectorFlowTest` | `force-app/main/default/classes/NepaPreAppQualifySectorFlowTest.cls` | Test class for the sector qualification flow — delivered |

**What IS delivered for pre-application screening:**
- `NEPA_Permit_Matrix__mdt` — 25 sector/project-type combinations with GIS trigger layers
- `NepaPreAppQualifySectorFlowTest` and `NepaPreAppScreeningControllerTest` cover the Flow-based path
- The `NEPA_Permit_Matrix__mdt` data is fully seeded and queryable

---

## Additional Unverified DataRaptors

The following DataRaptors have no Integration Procedure binding verified and are also backlog:

| Component | File |
|---|---|
| `DR_Extract_CE_LibraryByAgency` | `force-app/main/default/omniDataTransforms/DR_Extract_CE_LibraryByAgency.json` + `.rpt-meta.xml` |
| `DR_Extract_AR_Manifest` (referenced in IP but JSON not found) | Referenced in `NEPA_CEQExport_Procedure` |
| `DRGetBusinessAccounts` | `force-app/main/default/omniDataTransforms/DRGetBusinessAccounts_1.rpt-meta.xml` |
| `PSSFetchDetailsForBusinessAccount` | `force-app/main/default/omniDataTransforms/PSSFetchDetailsForBusinessAccount_1.rpt-meta.xml` |

---

## What Would Be Required to Complete These Features

1. **OmniStudio license confirmed in target org.** OmniStudio is included in PSS but must be installed/activated. Verify via Setup → Installed Packages.
2. **Deploy and manually activate Integration Procedures.** `sf project deploy start` may create `OmniProcess` records but not activate them. Manual activation via Setup → OmniStudio → Integration Procedures is required.
3. **Verify each IP in OmniStudio Designer.** The IP JSON definitions need to be verified against the current OmniStudio package version — the `invokeMethod` API confirmed working (see ADR 009) but the IP step definitions and DataRaptor references may need adjustment.
4. **Test the OmniScript end-to-end.** Element type naming is a known risk (see ADR 011 — "Text Area" not "TextArea"); the deployed OmniScript XML needs to be verified against the current platform's restricted picklist values.
5. **Configure ArcGIS API key** for the `nepaSiteLocationPickerOmni` component.
6. **CEQExport Integration Procedure** — the `permits[]` node is now fully implemented in `NepaCeqFullExportService.cls` via the Apex path. If the OmniStudio IP path is ever resumed, `DR_Extract_NEPA_RequiredPermit` (already authored) would need to be wired into the IP element sequence.

---

## Reference Documents

- `docs/CE-INTAKE-OMNISCRIPT-SPEC.md` — Detailed spec for the CE intake wizard (design intent, not verified delivery)
- `docs/GIS-Proximity-Guide.md` — Architectural notes for GIS Integration Procedure invocation (ADR 009)
- `docs/ARCHITECTURE_DECISIONS.md` — ADR 005 (OmniStudio isolation strategy), ADR 011 (OmniScript CE Intake rationale)
