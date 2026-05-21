// =============================================================================
// create_visit_apts.apex
// Creates 7 NEPA Work Order ActionPlanTemplate records (targetEntityType=Visit)
// with all ActionPlanTemplateItem and ActionPlanTemplateItemValue child records.
// Run as: sf apex run --file scripts/create_visit_apts.apex --target-org <alias>
// =============================================================================

// ── 1. Skip any APT whose UniqueName already exists ──────────────────────────
Set<String> existingNames = new Set<String>();
for (ActionPlanTemplate existing : [
    SELECT UniqueName
    FROM ActionPlanTemplate
    WHERE UniqueName IN (
        'NEPA_WO_Aquatic_Milestones',
        'NEPA_WO_BigGame_Milestones',
        'NEPA_WO_Botanical_Milestones',
        'NEPA_WO_Geology_Milestones',
        'NEPA_WO_Hydrology_Milestones',
        'NEPA_WO_MigratoryBird_Milestones',
        'NEPA_WO_SageGrouse_Milestones'
    )
]) {
    existingNames.add(existing.UniqueName);
}

// ── 2. Build APT records to insert ───────────────────────────────────────────
List<ActionPlanTemplate> aptsToInsert = new List<ActionPlanTemplate>();

ActionPlanTemplate apt_Aquatic = new ActionPlanTemplate(
    Name = 'NEPA WO Aquatic Milestones',
    UniqueName = 'NEPA_WO_Aquatic_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Fisheries and Wildlife Biologist (Aquatic) Work Order. Covers riparian survey, amphibian presence/absence, and CWA Section 404 memo. Target object: Visit.'
);

ActionPlanTemplate apt_BigGame = new ActionPlanTemplate(
    Name = 'NEPA WO Big Game Milestones',
    UniqueName = 'NEPA_WO_BigGame_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Wildlife Biologist (Big Game) Work Order. Covers shoulder-season assessment, winter range mapping, and pronghorn/elk migration corridor analysis. Target object: Visit.'
);

ActionPlanTemplate apt_Botanical = new ActionPlanTemplate(
    Name = 'NEPA WO Botanical Milestones',
    UniqueName = 'NEPA_WO_Botanical_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Botanist Work Order. Two seasonal site visits (June-July and August) for rare plant detection, plus seed mix approval. Target object: Visit.'
);

ActionPlanTemplate apt_Geology = new ActionPlanTemplate(
    Name = 'NEPA WO Geology Milestones',
    UniqueName = 'NEPA_WO_Geology_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Geologist Visit triggered by EPA Superfund NPL or contamination-related GIS layer detection. Covers soils assessment, access road erosion review, CERCLA coordination, and reclamation bond memo. Target object: Visit.'
);

ActionPlanTemplate apt_Hydrology = new ActionPlanTemplate(
    Name = 'NEPA WO Hydrology Milestones',
    UniqueName = 'NEPA_WO_Hydrology_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a hydrologist Visit triggered by NWI Wetlands or other aquatic/riparian GIS layer detection. Covers pre-survey prep, field assessment, CWA/NPDES review, and delineation report. Target object: Visit.'
);

ActionPlanTemplate apt_MigBird = new ActionPlanTemplate(
    Name = 'NEPA WO Migratory Bird Milestones',
    UniqueName = 'NEPA_WO_MigratoryBird_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Wildlife Biologist (Avian) Work Order. Covers spring nesting window survey (April–August), MBTA compliance, and avian collision risk assessment. Target object: Visit.'
);

ActionPlanTemplate apt_SageGrouse = new ActionPlanTemplate(
    Name = 'NEPA WO Sage-Grouse Milestones',
    UniqueName = 'NEPA_WO_SageGrouse_Milestones',
    TargetEntityType = 'Visit',
    IsAdHocItemCreationEnabled = false,
    Description = 'Field survey milestones for a Wildlife Biologist (Sage-Grouse) Visit triggered by FWS Critical Habitat detection. Covers lek survey window compliance, ARMPA conformance check, and survey report. Target object: Visit.'
);

Map<String, ActionPlanTemplate> aptByUniqueName = new Map<String, ActionPlanTemplate>();

if (!existingNames.contains('NEPA_WO_Aquatic_Milestones')) {
    aptsToInsert.add(apt_Aquatic);
    aptByUniqueName.put('NEPA_WO_Aquatic_Milestones', apt_Aquatic);
} else {
    System.debug('Skipping NEPA_WO_Aquatic_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_BigGame_Milestones')) {
    aptsToInsert.add(apt_BigGame);
    aptByUniqueName.put('NEPA_WO_BigGame_Milestones', apt_BigGame);
} else {
    System.debug('Skipping NEPA_WO_BigGame_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Botanical_Milestones')) {
    aptsToInsert.add(apt_Botanical);
    aptByUniqueName.put('NEPA_WO_Botanical_Milestones', apt_Botanical);
} else {
    System.debug('Skipping NEPA_WO_Botanical_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Geology_Milestones')) {
    aptsToInsert.add(apt_Geology);
    aptByUniqueName.put('NEPA_WO_Geology_Milestones', apt_Geology);
} else {
    System.debug('Skipping NEPA_WO_Geology_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Hydrology_Milestones')) {
    aptsToInsert.add(apt_Hydrology);
    aptByUniqueName.put('NEPA_WO_Hydrology_Milestones', apt_Hydrology);
} else {
    System.debug('Skipping NEPA_WO_Hydrology_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_MigratoryBird_Milestones')) {
    aptsToInsert.add(apt_MigBird);
    aptByUniqueName.put('NEPA_WO_MigratoryBird_Milestones', apt_MigBird);
} else {
    System.debug('Skipping NEPA_WO_MigratoryBird_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_SageGrouse_Milestones')) {
    aptsToInsert.add(apt_SageGrouse);
    aptByUniqueName.put('NEPA_WO_SageGrouse_Milestones', apt_SageGrouse);
} else {
    System.debug('Skipping NEPA_WO_SageGrouse_Milestones — already exists');
}

if (aptsToInsert.isEmpty()) {
    System.debug('Done: 0 templates created — all already exist');
    return;
}

insert aptsToInsert;
Integer createdCount = aptsToInsert.size();

// ── 3. Query auto-created ActionPlanTemplateVersion for each inserted APT ────
Set<Id> aptIds = new Set<Id>();
for (ActionPlanTemplate apt : aptsToInsert) {
    aptIds.add(apt.Id);
}

Map<Id, Id> versionIdByAptId = new Map<Id, Id>();
for (ActionPlanTemplateVersion ver : [
    SELECT Id, ActionPlanTemplateId
    FROM ActionPlanTemplateVersion
    WHERE ActionPlanTemplateId IN :aptIds
]) {
    versionIdByAptId.put(ver.ActionPlanTemplateId, ver.Id);
}

// ── 4. Insert ActionPlanTemplateItem records ──────────────────────────────────
// We track items by their UniqueName so we can attach values afterward.
// Items are only created for APTs that were just inserted.

List<ActionPlanTemplateItem> itemsToInsert = new List<ActionPlanTemplateItem>();

// Helper inner class not available in anon Apex — use a list-of-lists pattern:
// Each sublist corresponds to one APT's items in display order.

// ---------- AQUATIC ----------
if (aptByUniqueName.containsKey('NEPA_WO_Aquatic_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_Aquatic_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Aquatic Species Desktop Review',
        UniqueName = 'NEPA_WO_Aqua_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Riparian Survey and Fish Habitat Assessment',
        UniqueName = 'NEPA_WO_Aqua_2_Riparian'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Amphibian Presence/Absence Survey',
        UniqueName = 'NEPA_WO_Aqua_3_Amphibian'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'CWA Section 404 and ESA Section 7 Memo',
        UniqueName = 'NEPA_WO_Aqua_4_Memo'
    ));
}

// ---------- BIG GAME ----------
if (aptByUniqueName.containsKey('NEPA_WO_BigGame_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_BigGame_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Big Game Desktop Review',
        UniqueName = 'NEPA_WO_BG_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Shoulder-Season Field Assessment',
        UniqueName = 'NEPA_WO_BG_2_Field'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Winter Range Mapping and Fragmentation Analysis',
        UniqueName = 'NEPA_WO_BG_3_WinterRange'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Big Game Assessment Report',
        UniqueName = 'NEPA_WO_BG_4_Report'
    ));
}

// ---------- BOTANICAL ----------
if (aptByUniqueName.containsKey('NEPA_WO_Botanical_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_Botanical_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Botanical Desktop Review and Survey Planning',
        UniqueName = 'NEPA_WO_Bot_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Site Visit 1 — Early Season Survey (June–July)',
        UniqueName = 'NEPA_WO_Bot_2_Visit1'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Site Visit 2 — Late Season Survey (August)',
        UniqueName = 'NEPA_WO_Bot_3_Visit2'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Reclamation Seed Mix Approval',
        UniqueName = 'NEPA_WO_Bot_4_SeedMix'
    ));
}

// ---------- GEOLOGY ----------
if (aptByUniqueName.containsKey('NEPA_WO_Geology_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_Geology_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Geology and Soils Desktop Review',
        UniqueName = 'NEPA_WO_Geo_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Field Soils Assessment and Road Review',
        UniqueName = 'NEPA_WO_Geo_2_Field'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'CERCLA Coordination and Phase I/II Trigger',
        UniqueName = 'NEPA_WO_Geo_3_CERCLA'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Reclamation Bond and Geology Report',
        UniqueName = 'NEPA_WO_Geo_4_Report'
    ));
}

// ---------- HYDROLOGY ----------
if (aptByUniqueName.containsKey('NEPA_WO_Hydrology_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_Hydrology_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Pre-Survey Desktop Review',
        UniqueName = 'NEPA_WO_Hydro_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Wetland and Waterway Field Assessment',
        UniqueName = 'NEPA_WO_Hydro_2_Field'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'CWA Section 404/401 and NPDES Review',
        UniqueName = 'NEPA_WO_Hydro_3_CWA'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Hydrology Assessment Report',
        UniqueName = 'NEPA_WO_Hydro_4_Report'
    ));
}

// ---------- MIGRATORY BIRD ----------
if (aptByUniqueName.containsKey('NEPA_WO_MigratoryBird_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_MigratoryBird_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Avian Desktop Review and Raptor Nest Search',
        UniqueName = 'NEPA_WO_Bird_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Nesting Season Survey — Spring/Summer Window',
        UniqueName = 'NEPA_WO_Bird_2_NestSurvey'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'MBTA Compliance Analysis',
        UniqueName = 'NEPA_WO_Bird_3_MBTA'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Avian Survey Report and MBTA Compliance Memo',
        UniqueName = 'NEPA_WO_Bird_4_Report'
    ));
}

// ---------- SAGE-GROUSE ----------
if (aptByUniqueName.containsKey('NEPA_WO_SageGrouse_Milestones')) {
    Id verId = versionIdByAptId.get(aptByUniqueName.get('NEPA_WO_SageGrouse_Milestones').Id);
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 1,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Sage-Grouse Desktop Pre-Assessment',
        UniqueName = 'NEPA_WO_SGrouse_1_Desktop'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 2,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Lek Survey — Active Season Window',
        UniqueName = 'NEPA_WO_SGrouse_2_LekSurvey'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 3,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'ARMPA Conformance Check',
        UniqueName = 'NEPA_WO_SGrouse_3_ARMPA'
    ));
    itemsToInsert.add(new ActionPlanTemplateItem(
        ActionPlanTemplateVersionId = verId,
        DisplayOrder = 4,
        IsRequired = true,
        ItemEntityType = 'Task',
        Name = 'Sage-Grouse Survey Report',
        UniqueName = 'NEPA_WO_SGrouse_4_Report'
    ));
}

insert itemsToInsert;

// ── 5. Build lookup: UniqueName → ActionPlanTemplateItem.Id ──────────────────
Map<String, Id> itemIdByUniqueName = new Map<String, Id>();
for (ActionPlanTemplateItem item : itemsToInsert) {
    itemIdByUniqueName.put(item.UniqueName, item.Id);
}

// ── 6. Insert ActionPlanTemplateItemValue records ────────────────────────────
List<ActionPlanTemplateItemValue> valuesToInsert = new List<ActionPlanTemplateItemValue>();

// ============================================================
// AQUATIC — 4 items × 3 values each
// ============================================================

// Aquatic Item 1: NEPA_WO_Aqua_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_Aqua_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Aqua_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Aquatic Species Desktop Review'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Query USFWS IPaC, NatureServe, and state Natural Heritage Program for T&E fish, amphibian, and aquatic invertebrate species with confirmed occurrences within the HUC-12 watershed containing the project APE. Review state fish passage barrier databases for context. Pull NHD reaches and classify all water features within 1,000 feet of project footprint as perennial, intermittent, or ephemeral. Identify Section 7 ESA consultation history for the watershed and any applicable BO terms and conditions.'
    ));
}

// Aquatic Item 2: NEPA_WO_Aqua_2_Riparian
if (itemIdByUniqueName.containsKey('NEPA_WO_Aqua_2_Riparian')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Aqua_2_Riparian');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Riparian Survey and Fish Habitat Assessment'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct habitat assessment of all water features within 300 feet of project APE per Proper Functioning Condition (PFC) or Rosgen method. Document channel condition, substrate composition, pool-riffle ratio, riparian vegetation density and composition, bank stability, and stream flow regime. Conduct visual electrofishing or snorkel survey for fish species documentation where flow allows. Sample macroinvertebrates at representative riffles for biotic integrity index. Note any evidence of channelization, culverts requiring fish passage review, or historic channel avulsion.'
    ));
}

// Aquatic Item 3: NEPA_WO_Aqua_3_Amphibian
if (itemIdByUniqueName.containsKey('NEPA_WO_Aqua_3_Amphibian')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Aqua_3_Amphibian');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Amphibian Presence/Absence Survey'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct presence/absence surveys for T&E amphibian species (e.g., boreal toad, Columbia spotted frog, western toad) using visual encounter surveys and call playback where appropriate. Survey all suitable breeding habitat (ponds, slow-water reaches, seeps) within project APE. Conduct three surveys spaced at least 7 days apart during active breeding season. Document water temperature, pH, and presence of chytrid fungus (Bd) if sampling warranted by protocol. Photograph all detections. Note any evidence of livestock trampling or vehicle disturbance at breeding sites.'
    ));
}

// Aquatic Item 4: NEPA_WO_Aqua_4_Memo
if (itemIdByUniqueName.containsKey('NEPA_WO_Aqua_4_Memo')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Aqua_4_Memo');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'CWA Section 404 and ESA Section 7 Aquatic Species Memo'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile riparian survey, fish habitat assessment, and amphibian survey results. Provide CWA Section 404 jurisdictional determination memo documenting waters of the U.S. within APE. Document ESA Section 7 effect determination (no effect / may affect, not likely to adversely affect / may affect, likely to adversely affect) for each aquatic T&E species. If formal Section 7 consultation with USFWS is required, draft the Biological Assessment sections covering project description, species account, effects analysis, and minimization measures. Upload report as ContentVersion. Mark Work Order Status = Completed when report is approved.'
    ));
}

// ============================================================
// BIG GAME — 4 items × 3 values each
// ============================================================

// Big Game Item 1: NEPA_WO_BG_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_BG_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_BG_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Big Game Desktop Review — Range and Migration Corridor'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'Normal'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Query state wildlife agency GIS portal and BLM for mapped big game winter range, crucial winter range, production (fawning/calving) habitat, and migration corridors within 2 miles of project APE. Species of concern: mule deer, pronghorn, elk, bighorn sheep (as applicable to project region). Review state agency management plans, habitat objectives, and density standards for the applicable game management unit. Identify any mapped priority migration corridors (e.g., Wyoming Migration Initiative, Wyoming Range mule deer corridor) overlapping project footprint. Compile historical telemetry data if available from state agency coordination.'
    ));
}

// Big Game Item 2: NEPA_WO_BG_2_Field
if (itemIdByUniqueName.containsKey('NEPA_WO_BG_2_Field')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_BG_2_Field');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Shoulder-Season Big Game Field Assessment'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'Normal'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct field reconnaissance of project APE during shoulder season (April–May or September–October) to document habitat quality, forage species composition, cover, and evidence of big game use (tracks, pellets, rubs, wallows, trails). Map any topographic features that concentrate or funnel migration (drainages, ridgelines, fence crossings). Document existing infrastructure (fences, roads, pipelines) and assess permeability to big game movement. Note any livestock grazing impacts to forage base or water sources used by big game. GPS all significant observations.'
    ));
}

// Big Game Item 3: NEPA_WO_BG_3_WinterRange
if (itemIdByUniqueName.containsKey('NEPA_WO_BG_3_WinterRange')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_BG_3_WinterRange');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Winter Range Mapping and Habitat Fragmentation Analysis'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'Normal'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Overlay project footprint with state-mapped crucial winter range and production habitat polygons. Calculate acres of each habitat type directly impacted versus acres disturbed within each habitat category. Assess edge effects and effective habitat loss using species-specific disturbance buffer distances (e.g., 0.25-mile noise buffer for mule deer wintering habitat). Evaluate cumulative fragmentation effect with existing infrastructure. Identify fence modification recommendations (wildlife-friendly fence standards: 42-inch max height, smooth bottom wire, 12-inch gap at base). Document proposed crossing structures or migration permeability enhancements.'
    ));
}

// Big Game Item 4: NEPA_WO_BG_4_Report
if (itemIdByUniqueName.containsKey('NEPA_WO_BG_4_Report')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_BG_4_Report');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Big Game Assessment Report — Final Submission'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'Normal'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile desktop review, field assessment, winter range mapping, fragmentation analysis, and mitigation recommendations into big game wildlife report. Include state agency coordination letters or concurrences where obtained. Recommend project conditions: seasonal timing restrictions (winter no-disturbance window if applicable), fence modification requirements, reclamation forage species, weed control requirements affecting forage base. Upload report as ContentVersion linked to Work Order and NEPA IndividualApplication. Mark Work Order Status = Completed when report is approved by NEPA lead.'
    ));
}

// ============================================================
// BOTANICAL — 4 items × 3 values each
// ============================================================

// Botanical Item 1: NEPA_WO_Bot_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_Bot_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bot_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Botanical Desktop Review and Survey Planning'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Query USDA PLANTS database, state Natural Heritage Program, and BLM sensitive species list for all T&E and BLM sensitive plant species with documented occurrences within 5 miles of project APE. Review herbarium records and state/federal GIS occurrence layers. Identify peak bloom windows for each species requiring detection surveys. Pull USGS topo and aerial imagery to map suitable habitat patches within APE. Prepare species-specific survey protocols and field data forms.'
    ));
}

// Botanical Item 2: NEPA_WO_Bot_2_Visit1
if (itemIdByUniqueName.containsKey('NEPA_WO_Bot_2_Visit1')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bot_2_Visit1');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Botanical Site Visit 1 — Early Season Survey (June–July)'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct early-season floristic survey of entire APE plus 50-foot buffer. Survey all suitable habitat patches for early-blooming T&E and BLM sensitive species. Use 100% coverage transect methodology for high-potential habitat; modified-Whittaker or targeted search for lower-potential areas. Document all occurrences with GPS coordinates, population size, phenological stage, and condition. Photograph representative individuals. Note general vegetation community composition for each habitat patch.'
    ));
}

// Botanical Item 3: NEPA_WO_Bot_3_Visit2
if (itemIdByUniqueName.containsKey('NEPA_WO_Bot_3_Visit2')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bot_3_Visit2');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Botanical Site Visit 2 — Late Season Survey (August)'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct late-season floristic survey targeting late-blooming species not detectable in June-July survey. Re-survey any high-potential habitat patches with negative results from Visit 1 to confirm absence. Document any changes in population condition since Visit 1. Collect voucher specimens for any unidentified individuals requiring taxonomic confirmation. Update GPS data and population size estimates. Photograph all new detections.'
    ));
}

// Botanical Item 4: NEPA_WO_Bot_4_SeedMix
if (itemIdByUniqueName.containsKey('NEPA_WO_Bot_4_SeedMix')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bot_4_SeedMix');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Reclamation Seed Mix Review and Approval'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Develop native seed mix appropriate to plant communities documented in survey. Use only locally adapted, weed-free seed from certified sources. Avoid invasive or noxious weed species. Specify seeding rates (lbs PLS/acre) for each species component. Verify mix against BLM state office approved seed lists and habitat type. Document measures to control cheatgrass (Bromus tectorum) and other annual invasives during reclamation. Upload seed mix memo as ContentVersion. Mark Work Order Status = Completed when report and seed mix are approved by NEPA lead.'
    ));
}

// ============================================================
// GEOLOGY — 4 items × 3 values each
// ============================================================

// Geology Item 1: NEPA_WO_Geo_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_Geo_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Geo_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Geology and Soils Desktop Review'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Review EPA Superfund NPL hit data and site Record of Decision (ROD) if available on EPA CERCLIS. Pull NRCS Web Soil Survey data for project APE — document all map units, erodibility (K-factor), and limitations for proposed land use. Review state geological survey maps for bedrock depth, fault zones, and groundwater vulnerability. Identify any prior Phase I or Phase II ESA reports for the parcel from regulatory agency records. Document CERCLA institutional controls applicable to project footprint.'
    ));
}

// Geology Item 2: NEPA_WO_Geo_2_Field
if (itemIdByUniqueName.containsKey('NEPA_WO_Geo_2_Field')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Geo_2_Field');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Field Soils Assessment and Access Road Erosion Review'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct field reconnaissance of project APE. Excavate soil pits to characterize texture, structure, organic matter, and presence of contamination indicators. Photograph and describe all access road crossings — note slope, drainage structures, cut/fill configuration, and erosion potential. Collect soil samples for laboratory analysis if visual contamination indicators are present. GPS all sample locations. Assess caliche, hardpan, or high-sodium soils that may affect reclamation seed establishment.'
    ));
}

// Geology Item 3: NEPA_WO_Geo_3_CERCLA
if (itemIdByUniqueName.containsKey('NEPA_WO_Geo_3_CERCLA')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Geo_3_CERCLA');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'CERCLA Coordination and Phase I/II ESA Trigger Assessment'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Determine if project activities disturb CERCLA-regulated media or require EPA/state oversight notification under the NPL site ROD. Evaluate whether Phase I ESA triggers apply under ASTM E1527-21 (all appropriate inquiries). If contamination indicators were found in field assessment, document Phase II ESA scope and timeline. Coordinate with EPA or state cleanup program if remediation oversight applies. Document any CERCLA contribution protections needed for federal land status.'
    ));
}

// Geology Item 4: NEPA_WO_Geo_4_Report
if (itemIdByUniqueName.containsKey('NEPA_WO_Geo_4_Report')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Geo_4_Report');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Reclamation Bond Memo and Geology Assessment Report'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile soils assessment, road erosion risk findings, CERCLA coordination memo, and Phase I/II trigger determination into geology report. Provide reclamation bond cost estimate per applicable state or federal bond schedule, including topsoil salvage, revegetation, and contamination contingency costs. Upload report as ContentVersion linked to Work Order and NEPA IndividualApplication. Recommend reclamation seed mix appropriate to soil type. Mark Work Order Status = Completed when report is approved.'
    ));
}

// ============================================================
// HYDROLOGY — 4 items × 3 values each
// ============================================================

// Hydrology Item 1: NEPA_WO_Hydro_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_Hydro_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Hydro_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Pre-Survey Desktop Review — Hydrology'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Review NWI Wetlands layer detection output, USGS NHD flowlines, and project-area topo maps. Identify all water features within 300 feet of the project footprint. Compile jurisdictional determination history for the APE. Request hydric soils data from NRCS Web Soil Survey. Document any prior Section 404/401 permits for the parcel.'
    ));
}

// Hydrology Item 2: NEPA_WO_Hydro_2_Field
if (itemIdByUniqueName.containsKey('NEPA_WO_Hydro_2_Field')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Hydro_2_Field');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Wetland and Waterway Field Assessment'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct field-based wetland delineation per the Corps of Engineers Wetland Delineation Manual (1987) and applicable regional supplement. Document hydrology indicators, hydric soils, and hydrophytic vegetation. GPS-mark all wetland boundaries, OHWM, and ephemeral/intermittent channel crossings. Photograph and complete data forms for each sample point. Note any evidence of prior disturbance or fill.'
    ));
}

// Hydrology Item 3: NEPA_WO_Hydro_3_CWA
if (itemIdByUniqueName.containsKey('NEPA_WO_Hydro_3_CWA')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Hydro_3_CWA');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'CWA Section 404/401 and NPDES Permit Review'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Determine whether project activities require CWA Section 404 individual or nationwide permit (NWP). Document applicable NWP conditions and general conditions checklist. Evaluate need for 401 Water Quality Certification from state agency. Assess stormwater discharge triggers for NPDES Construction General Permit (CGP) coverage. Identify any ACOE pre-construction notification (PCN) requirements.'
    ));
}

// Hydrology Item 4: NEPA_WO_Hydro_4_Report
if (itemIdByUniqueName.containsKey('NEPA_WO_Hydro_4_Report')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Hydro_4_Report');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Hydrology Assessment Report — Final Submission'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile wetland delineation report, CWA jurisdictional determination summary, permit triggers matrix, and recommended mitigation or avoidance measures. Upload final report as ContentVersion linked to this Work Order and to the NEPA IndividualApplication. Confirm Section 7 USFWS coordination needs for any aquatic T&E species. Mark Work Order Status = Completed when report is approved by NEPA lead.'
    ));
}

// ============================================================
// MIGRATORY BIRD — 4 items × 3 values each
// ============================================================

// Migratory Bird Item 1: NEPA_WO_Bird_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_Bird_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bird_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Avian Desktop Review and Raptor Nest Pre-Search'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Query eBird, GBIF, USFWS IPaC, and state Natural Heritage Program for T&E and MBTA-protected avian species with confirmed occurrences within 5 miles of project APE. Pull BLM raptor nest database and state raptor nesting surveys for golden eagle, bald eagle, ferruginous hawk, and prairie falcon within 0.5-mile radius. Review USFWS Eagle Conservation Plan for wind/transmission projects if applicable. Identify species-specific survey protocols and MBTA-compliant no-disturbance buffer distances during nesting season. Document project intersection with Important Bird Areas (IBAs) or Partners in Flight priority habitats.'
    ));
}

// Migratory Bird Item 2: NEPA_WO_Bird_2_NestSurvey
if (itemIdByUniqueName.containsKey('NEPA_WO_Bird_2_NestSurvey')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bird_2_NestSurvey');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Nesting Season Survey — Spring/Summer Window (April–August)'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct comprehensive nesting bird survey of project APE plus 100-foot buffer during peak nesting window (April 15 – August 15). Use point count method (5-minute, 50-meter radius, unlimited distance) at systematically placed stations. Conduct separate raptor nest surveys via circular transects at 0.5-mile radius using binoculars and spotting scope. Document all active nests with GPS coordinates, species, stage of nesting, and distance to project features. Photograph nests from maximum safe distance. Note grassland nesting species (mountain plover, long-billed curlew, burrowing owl) in appropriate habitats.'
    ));
}

// Migratory Bird Item 3: NEPA_WO_Bird_3_MBTA
if (itemIdByUniqueName.containsKey('NEPA_WO_Bird_3_MBTA')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bird_3_MBTA');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'MBTA Compliance and BGEPA Applicability Analysis'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Document proposed construction and operational activities that could result in incidental take under MBTA (including vegetation clearing, ground disturbance, powerline installation). Identify take-avoidance measures: construction timing windows avoiding active nests, pre-construction nest sweeps, raptor nest buffer distances. Assess Bald and Golden Eagle Protection Act (BGEPA) applicability for any eagle nests within 0.5 miles of project components. Document Eagle Take Permit applicability if avoidance is not achievable. Identify species requiring individual USFWS coordination letters. Note: clearing within 300 feet of active raptor nests without incidental take authorization is prohibited under BGEPA.'
    ));
}

// Migratory Bird Item 4: NEPA_WO_Bird_4_Report
if (itemIdByUniqueName.containsKey('NEPA_WO_Bird_4_Report')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_Bird_4_Report');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Avian Survey Report and MBTA/BGEPA Compliance Memo'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile nesting survey results, raptor nest map, MBTA compliance analysis, BGEPA applicability determination, and recommended avoidance/minimization measures into final avian report. Document species-specific buffer distances, construction timing restrictions, and pre-construction sweep requirements to be included in project conditions of approval. Upload report as ContentVersion linked to Work Order and NEPA IndividualApplication. Mark Work Order Status = Completed when report is approved by NEPA lead.'
    ));
}

// ============================================================
// SAGE-GROUSE — 4 items × 3 values each
// ============================================================

// Sage-Grouse Item 1: NEPA_WO_SGrouse_1_Desktop
if (itemIdByUniqueName.containsKey('NEPA_WO_SGrouse_1_Desktop')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_SGrouse_1_Desktop');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Sage-Grouse Desktop Pre-Assessment'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Review USFWS Critical Habitat designation maps and FWS Critical Habitat layer GIS hit data. Determine applicable GRSG Management Plan category (Core Area, Important Habitat, General Habitat) and applicable ARMPA sub-object thresholds. Identify any known lek locations within 4 miles via BLM lek database. Determine if lek survey season (April 1 – May 15 for active leks) timing permits field survey this cycle or requires scheduling for next season window.'
    ));
}

// Sage-Grouse Item 2: NEPA_WO_SGrouse_2_LekSurvey
if (itemIdByUniqueName.containsKey('NEPA_WO_SGrouse_2_LekSurvey')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_SGrouse_2_LekSurvey');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Lek Survey — Active Season Window (April 1 – May 15)'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Conduct dawn lek count surveys per Wyoming/state protocol (minimum 3 visits during peak display: 30 min before to 1 hr after sunrise). Record male attendance, strutting ground activity, and female presence. GPS all lek center points. Photograph strutting males if possible without disturbing display. Document buffer distance from proposed project footprint to nearest active lek center. Note: if survey window has closed, document in work order and schedule for next April-May window.'
    ));
}

// Sage-Grouse Item 3: NEPA_WO_SGrouse_3_ARMPA
if (itemIdByUniqueName.containsKey('NEPA_WO_SGrouse_3_ARMPA')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_SGrouse_3_ARMPA');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'ARMPA Conformance Check and Waivers Review'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Map project footprint against ARMPA habitat category. Apply applicable ARMPA stipulations: seasonal timing restrictions (April 1 – June 30 no-surface-disturbance), density caps for surface disturbance, powerline height restrictions in core habitat. Document any applicable waivers, exceptions, or modifications. Evaluate cumulative surface disturbance against Wyoming or applicable state lek buffer and Core Area caps. Record conformant/non-conformant determination with citation.'
    ));
}

// Sage-Grouse Item 4: NEPA_WO_SGrouse_4_Report
if (itemIdByUniqueName.containsKey('NEPA_WO_SGrouse_4_Report')) {
    Id itemId = itemIdByUniqueName.get('NEPA_WO_SGrouse_4_Report');
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Subject',
        ItemEntityType = 'Task',
        ValueLiteral = 'Sage-Grouse Survey and ARMPA Conformance Report'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Priority',
        ItemEntityType = 'Task',
        ValueLiteral = 'High'
    ));
    valuesToInsert.add(new ActionPlanTemplateItemValue(
        ActionPlanTemplateItemId = itemId,
        ItemEntityFieldName = 'Description',
        ItemEntityType = 'Task',
        ValueLiteral = 'Compile lek survey results, ARMPA conformance determination, seasonal timing restriction analysis, and recommended avoidance/mitigation measures into a single report. Upload to ContentVersion linked to the Work Order and NEPA IndividualApplication. Coordinate BLM/USFWS review if non-conformance waivers are required. Mark Work Order Status = Completed when report is approved by NEPA lead.'
    ));
}

insert valuesToInsert;

System.debug('Done: ' + createdCount + ' templates created');
