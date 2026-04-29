# PSA-NEPA-Permitting-Data-Model

Salesforce PSS-based NEPA permitting data model aligned to CEQ NEPA and Permitting Data and Technology Standard v1.2 (May 30 / August 18, 2025).

## Project Context

- **6 CEQ entities:** Program (Project), IndividualApplication (Process), ContentVersion (Documents), PublicComplaint (Comments), nepa_engagement__c (Public Engagement Events), ApplicationTimeline (Case Events)
- **nepa_litigation__c:** Custom object mapping PermitTEC v0.1 litigation cases (761 NEPA cases, PNNL 2025)
- **Phase 1 Risk Intelligence:** Litigation risk scoring, challenge prediction, defensibility gap detection — all Flow-based with custom metadata weight tables pre-seeded from PermitTEC corpus
- **Automation preference:** Flows over Apex. Use before-save for same-record updates; after-save async for related-record work and subflow calls
- **API version:** 62.0

## Skill Imports

@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-metadata/SKILL.md
@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-flow/SKILL.md
@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-permissions/SKILL.md
@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-deploy/SKILL.md
@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-data/SKILL.md
@/Users/shannon.schupbach/claude-projects/sf-skills-main/skills/sf-testing/SKILL.md
