# OmniStudio Backlog — PSA-NEPA Permitting Accelerator

> **Status: Backlog — implementation not successfully completed**
>
> The OmniStudio metadata files described here are present in the repository as design
> artifacts and were not successfully deployed and verified. Do not present them as
> delivered capabilities.

Full component inventories, resumption checklists, and static analysis are in
**[ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail)**.

---

## Quick Status Summary

| Feature | Working Path | Backlog Path |
|---|---|---|
| CE Intake Wizard | `NEPA_CE_Intake` Screen Flow | `NEPA_CEIntake` OmniScript + IPs |
| GIS Proximity | `NEPA_GIS_Proximity_Check` Flow (logic verified; IP end-to-end not verified) | `NEPA_GISProximityIP` IP activation |
| CEQ Full-Graph Export | `NepaCeqFullExportService` Apex REST `POST /nepa/v1/export/project` | `NEPA_CEQExport_Procedure` IP + DataRaptors (abandoned) |
| Pre-App Screening | Flow-based path | `NEPA_PreAppScreeningIP` IP |

## Reference Documents

- [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail) — Full component tables, file paths, resumption steps
- [ARCHITECTURE_DECISIONS.md — ADR 005](ARCHITECTURE_DECISIONS.md#adr-005--phase-2-omnistudio-isolation-strategy) — OmniStudio isolation strategy
- [ARCHITECTURE_DECISIONS.md — ADR 009](ARCHITECTURE_DECISIONS.md#adr-009--apex-bridge-for-flow-to-omniip-invocation) — Apex bridge pattern for IP invocation
- [ARCHITECTURE_DECISIONS.md — ADR 011](ARCHITECTURE_DECISIONS.md#adr-011--omniscript-ce-intake-over-screen-flow) — OmniScript CE Intake rationale
- [GIS-Proximity-Guide.md](GIS-Proximity-Guide.md) — GIS integration architecture notes
- [CE-INTAKE-OMNISCRIPT-SPEC.md](CE-INTAKE-OMNISCRIPT-SPEC.md) — CE intake wizard spec (design intent)
