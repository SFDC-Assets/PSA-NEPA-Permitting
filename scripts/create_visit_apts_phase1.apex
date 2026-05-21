// =============================================================================
// create_visit_apts_phase1.apex  (Phase 1 of 3)
// Creates 7 NEPA Work Order ActionPlanTemplate records (targetEntityType=Visit)
// Run FIRST. After completion, read the debug log for APT IDs and run phase2.
// Run as: sf apex run --file scripts/create_visit_apts_phase1.apex --target-org <alias>
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

if (!existingNames.contains('NEPA_WO_Aquatic_Milestones')) {
    aptsToInsert.add(apt_Aquatic);
} else {
    System.debug('Skipping NEPA_WO_Aquatic_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_BigGame_Milestones')) {
    aptsToInsert.add(apt_BigGame);
} else {
    System.debug('Skipping NEPA_WO_BigGame_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Botanical_Milestones')) {
    aptsToInsert.add(apt_Botanical);
} else {
    System.debug('Skipping NEPA_WO_Botanical_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Geology_Milestones')) {
    aptsToInsert.add(apt_Geology);
} else {
    System.debug('Skipping NEPA_WO_Geology_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_Hydrology_Milestones')) {
    aptsToInsert.add(apt_Hydrology);
} else {
    System.debug('Skipping NEPA_WO_Hydrology_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_MigratoryBird_Milestones')) {
    aptsToInsert.add(apt_MigBird);
} else {
    System.debug('Skipping NEPA_WO_MigratoryBird_Milestones — already exists');
}
if (!existingNames.contains('NEPA_WO_SageGrouse_Milestones')) {
    aptsToInsert.add(apt_SageGrouse);
} else {
    System.debug('Skipping NEPA_WO_SageGrouse_Milestones — already exists');
}

if (aptsToInsert.isEmpty()) {
    System.debug('Done: 0 templates created — all already exist');
    return;
}

insert aptsToInsert;

// ── 3. Debug output: APT IDs for reference in phase 2 ────────────────────────
for (ActionPlanTemplate apt : aptsToInsert) {
    System.debug('APT:' + apt.UniqueName + '=' + apt.Id);
}
System.debug('Done: ' + aptsToInsert.size() + ' templates created — run phase2 next');
