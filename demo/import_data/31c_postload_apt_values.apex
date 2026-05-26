// Step 31c: ActionPlanTemplateItemValue — wire ATD IDs + Names (run after 31b)

Map<String, Id> atdIdByName = new Map<String, Id>();
for (AssessmentTaskDefinition x : [SELECT Id, Name FROM AssessmentTaskDefinition WHERE Name IN (
    'Aquatic Species Desktop Review', 'Riparian Survey and Fish Habitat Assessment', 'Amphibian Presence/Absence Survey', 'CWA Section 404 and ESA Section 7 Aquatic Species Memo', 'Big Game Desktop Review — Range and Migration Corridor',
    'Shoulder-Season Big Game Field Assessment', 'Winter Range Mapping and Habitat Fragmentation Analysis', 'Big Game Assessment Report — Final Submission', 'Botanical Desktop Review and Survey Planning', 'Botanical Site Visit 1 — Early Season Survey (June–July)',
    'Botanical Site Visit 2 — Late Season Survey (August)', 'Reclamation Seed Mix Review and Approval', 'Geology and Soils Desktop Review', 'Field Soils Assessment and Access Road Erosion Review', 'CERCLA Coordination and Phase I/II ESA Trigger Assessment',
    'Reclamation Bond Memo and Geology Assessment Report', 'Pre-Survey Desktop Review — Hydrology', 'Wetland and Waterway Field Assessment', 'CWA Section 404/401 and NPDES Permit Review', 'Hydrology Assessment Report — Final Submission',
    'Avian Desktop Review and Raptor Nest Pre-Search', 'Nesting Season Survey — Spring/Summer Window (April–August)', 'MBTA Compliance and BGEPA Applicability Analysis', 'Avian Survey Report and MBTA/BGEPA Compliance Memo', 'Sage-Grouse Desktop Pre-Assessment',
    'Lek Survey — Active Season Window (April 1 – May 15)', 'ARMPA Conformance Check and Waivers Review', 'Sage-Grouse Survey and ARMPA Conformance Report'
)]) { atdIdByName.put(x.Name, x.Id); }

Map<String, Id> itemIdByUnique = new Map<String, Id>();
for (ActionPlanTemplateItem x : [SELECT Id, UniqueName FROM ActionPlanTemplateItem WHERE UniqueName LIKE 'NEPA_Visit_%']) {
    itemIdByUnique.put(x.UniqueName, x.Id);
}

Set<String> existingValKeys = new Set<String>();
for (ActionPlanTemplateItemValue x : [SELECT ActionPlanTemplateItemId, ItemEntityFieldName FROM ActionPlanTemplateItemValue WHERE ActionPlanTemplateItemId IN :itemIdByUnique.values()]) {
    existingValKeys.add(String.valueOf(x.ActionPlanTemplateItemId) + '|' + x.ItemEntityFieldName);
}
List<ActionPlanTemplateItemValue> valsToInsert = new List<ActionPlanTemplateItemValue>();
if (itemIdByUnique.containsKey('NEPA_Visit_Aqua_1_Desktop_BLM') && atdIdByName.containsKey('Aquatic Species Desktop Review')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Aqua_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Aqua_1_Desktop_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Aquatic Species Desktop Review')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Aqua_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Aquatic Species Desktop Review', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Aqua_2_Riparian_BLM') && atdIdByName.containsKey('Riparian Survey and Fish Habitat Assessment')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Aqua_2_Riparian_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Aqua_2_Riparian_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Riparian Survey and Fish Habitat Assessment')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Aqua_2_Riparian_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Riparian Survey and Fish Habitat Assessment', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Aqua_3_Amphibian_BLM') && atdIdByName.containsKey('Amphibian Presence/Absence Survey')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Aqua_3_Amphibian_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Aqua_3_Amphibian_', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Amphibian Presence/Absence Survey')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Aqua_3_Amphibian_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Amphibian Presence/Absence Survey', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Aqua_4_Memo_BLM') && atdIdByName.containsKey('CWA Section 404 and ESA Section 7 Aquatic Species Memo')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Aqua_4_Memo_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Aqua_4_Memo_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('CWA Section 404 and ESA Section 7 Aquatic Species Memo')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Aqua_4_Memo_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='CWA Section 404 and ESA Section 7 Aquatic Species Memo', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_BG_1_Desktop_BLM') && atdIdByName.containsKey('Big Game Desktop Review — Range and Migration Corridor')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_BG_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_BG_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Big Game Desktop Review — Range and Migration Corridor')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_BG_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Big Game Desktop Review — Range and Migration Corridor', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_BG_2_Field_BLM') && atdIdByName.containsKey('Shoulder-Season Big Game Field Assessment')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_BG_2_Field_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_BG_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Shoulder-Season Big Game Field Assessment')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_BG_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Shoulder-Season Big Game Field Assessment', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_BG_3_WinterRange_BLM') && atdIdByName.containsKey('Winter Range Mapping and Habitat Fragmentation Analysis')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_BG_3_WinterRange_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_BG_3_WinterRange_', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Winter Range Mapping and Habitat Fragmentation Analysis')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_BG_3_WinterRange_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Winter Range Mapping and Habitat Fragmentation Analysis', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_BG_4_Report_BLM') && atdIdByName.containsKey('Big Game Assessment Report — Final Submission')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_BG_4_Report_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_BG_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Big Game Assessment Report — Final Submission')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_BG_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Big Game Assessment Report — Final Submission', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bot_1_Desktop_BLM') && atdIdByName.containsKey('Botanical Desktop Review and Survey Planning')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bot_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bot_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Botanical Desktop Review and Survey Planning')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bot_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Botanical Desktop Review and Survey Planning', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bot_2_Visit1_BLM') && atdIdByName.containsKey('Botanical Site Visit 1 — Early Season Survey (June–July)')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bot_2_Visit1_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bot_2_Visit1_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Botanical Site Visit 1 — Early Season Survey (June–July)')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bot_2_Visit1_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Botanical Site Visit 1 — Early Season Survey (June–July)', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bot_3_Visit2_BLM') && atdIdByName.containsKey('Botanical Site Visit 2 — Late Season Survey (August)')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bot_3_Visit2_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bot_3_Visit2_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Botanical Site Visit 2 — Late Season Survey (August)')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bot_3_Visit2_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Botanical Site Visit 2 — Late Season Survey (August)', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bot_4_SeedMix_BLM') && atdIdByName.containsKey('Reclamation Seed Mix Review and Approval')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bot_4_SeedMix_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bot_4_SeedMix_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Reclamation Seed Mix Review and Approval')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bot_4_SeedMix_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Reclamation Seed Mix Review and Approval', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Geo_1_Desktop_BLM') && atdIdByName.containsKey('Geology and Soils Desktop Review')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Geo_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Geo_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Geology and Soils Desktop Review')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Geo_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Geology and Soils Desktop Review', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Geo_2_Field_BLM') && atdIdByName.containsKey('Field Soils Assessment and Access Road Erosion Review')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Geo_2_Field_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Geo_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Field Soils Assessment and Access Road Erosion Review')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Geo_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Field Soils Assessment and Access Road Erosion Review', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Geo_3_CERCLA_BLM') && atdIdByName.containsKey('CERCLA Coordination and Phase I/II ESA Trigger Assessment')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Geo_3_CERCLA_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Geo_3_CERCLA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('CERCLA Coordination and Phase I/II ESA Trigger Assessment')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Geo_3_CERCLA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='CERCLA Coordination and Phase I/II ESA Trigger Assessment', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Geo_4_Report_BLM') && atdIdByName.containsKey('Reclamation Bond Memo and Geology Assessment Report')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Geo_4_Report_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Geo_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Reclamation Bond Memo and Geology Assessment Report')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Geo_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Reclamation Bond Memo and Geology Assessment Report', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Hydro_1_Desktop_BLM') && atdIdByName.containsKey('Pre-Survey Desktop Review — Hydrology')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Hydro_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Hydro_1_Desktop_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Pre-Survey Desktop Review — Hydrology')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Hydro_1_Desktop_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Pre-Survey Desktop Review — Hydrology', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Hydro_2_Field_BLM') && atdIdByName.containsKey('Wetland and Waterway Field Assessment')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Hydro_2_Field_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Hydro_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Wetland and Waterway Field Assessment')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Hydro_2_Field_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Wetland and Waterway Field Assessment', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Hydro_3_CWA_BLM') && atdIdByName.containsKey('CWA Section 404/401 and NPDES Permit Review')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Hydro_3_CWA_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Hydro_3_CWA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('CWA Section 404/401 and NPDES Permit Review')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Hydro_3_CWA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='CWA Section 404/401 and NPDES Permit Review', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Hydro_4_Report_BLM') && atdIdByName.containsKey('Hydrology Assessment Report — Final Submission')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Hydro_4_Report_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Hydro_4_Report_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Hydrology Assessment Report — Final Submission')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Hydro_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Hydrology Assessment Report — Final Submission', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bird_1_Desktop_BLM') && atdIdByName.containsKey('Avian Desktop Review and Raptor Nest Pre-Search')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bird_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bird_1_Desktop_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Avian Desktop Review and Raptor Nest Pre-Search')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bird_1_Desktop_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Avian Desktop Review and Raptor Nest Pre-Search', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bird_2_NestSurvey_BLM') && atdIdByName.containsKey('Nesting Season Survey — Spring/Summer Window (April–August)')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bird_2_NestSurvey_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bird_2_NestSurvey', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Nesting Season Survey — Spring/Summer Window (April–August)')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bird_2_NestSurvey_', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Nesting Season Survey — Spring/Summer Window (April–August)', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bird_3_MBTA_BLM') && atdIdByName.containsKey('MBTA Compliance and BGEPA Applicability Analysis')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bird_3_MBTA_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bird_3_MBTA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('MBTA Compliance and BGEPA Applicability Analysis')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bird_3_MBTA_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='MBTA Compliance and BGEPA Applicability Analysis', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_Bird_4_Report_BLM') && atdIdByName.containsKey('Avian Survey Report and MBTA/BGEPA Compliance Memo')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_Bird_4_Report_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_Bird_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Avian Survey Report and MBTA/BGEPA Compliance Memo')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_Bird_4_Report_BLM', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Avian Survey Report and MBTA/BGEPA Compliance Memo', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_SGrouse_1_Desktop_BLM') && atdIdByName.containsKey('Sage-Grouse Desktop Pre-Assessment')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_SGrouse_1_Desktop_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_SGrouse_1_Desktop', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Sage-Grouse Desktop Pre-Assessment')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_SGrouse_1_Desktop_', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Sage-Grouse Desktop Pre-Assessment', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_SGrouse_2_LekSurvey_BLM') && atdIdByName.containsKey('Lek Survey — Active Season Window (April 1 – May 15)')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_SGrouse_2_LekSurvey_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_SGrouse_2_LekSurv', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Lek Survey — Active Season Window (April 1 – May 15)')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_SGrouse_2_LekSurve', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Lek Survey — Active Season Window (April 1 – May 15)', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_SGrouse_3_ARMPA_BLM') && atdIdByName.containsKey('ARMPA Conformance Check and Waivers Review')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_SGrouse_3_ARMPA_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_SGrouse_3_ARMPA_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('ARMPA Conformance Check and Waivers Review')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_SGrouse_3_ARMPA_BL', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='ARMPA Conformance Check and Waivers Review', IsActive=true));
}
if (itemIdByUnique.containsKey('NEPA_Visit_SGrouse_4_Report_BLM') && atdIdByName.containsKey('Sage-Grouse Survey and ARMPA Conformance Report')) {
    Id iId = itemIdByUnique.get('NEPA_Visit_SGrouse_4_Report_BLM');
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.AssessmentTaskDefinitionId')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='ATD_NEPA_Visit_SGrouse_4_Report_', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.AssessmentTaskDefinitionId', ValueLiteral=String.valueOf(atdIdByName.get('Sage-Grouse Survey and ARMPA Conformance Report')), IsActive=true));
    if (!existingValKeys.contains(String.valueOf(iId)+'|AssessmentTask.Name')) valsToInsert.add(new ActionPlanTemplateItemValue(Name='Nm_NEPA_Visit_SGrouse_4_Report_B', ActionPlanTemplateItemId=iId, ItemEntityFieldName='AssessmentTask.Name', ValueLiteral='Sage-Grouse Survey and ARMPA Conformance Report', IsActive=true));
}
if (!valsToInsert.isEmpty()) insert valsToInsert;
System.debug('ActionPlanTemplateItemValue inserted: ' + valsToInsert.size());

// ─── Publish versions (Draft → Final) ────────────────────────────────────────
// All items and values are inserted; now publish any remaining Draft versions.
List<ActionPlanTemplateVersion> toPublish = new List<ActionPlanTemplateVersion>();
for (ActionPlanTemplateVersion x : [SELECT Id FROM ActionPlanTemplateVersion WHERE ActionPlanTemplateId IN (SELECT Id FROM ActionPlanTemplate WHERE UniqueName LIKE 'NEPA_Visit_%') AND Status = 'Draft']) {
    toPublish.add(new ActionPlanTemplateVersion(Id=x.Id, Status='Final', ActivationDateTime=DateTime.now()));
}
if (!toPublish.isEmpty()) update toPublish;
System.debug('ActionPlanTemplateVersion published: ' + toPublish.size());
System.debug('Step 31c complete — NEPA Visit APTs fully wired and published.');