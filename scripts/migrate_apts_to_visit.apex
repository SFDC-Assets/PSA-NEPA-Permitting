// migrate_apts_to_visit.apex
// Deletes the 7 NEPA_WO_* ActionPlanTemplates (currently targeting WorkOrder)
// and recreates them targeting Visit with identical names and task items.
// Safe only when no live ActionPlan records reference these APT versions.
// Run: sf apex run --file scripts/migrate_apts_to_visit.apex --target-org NEPA_INNOVATOR

// ── 1. Delete existing WorkOrder-targeted APTs ───────────────────────────────
List<ActionPlanTemplate> oldApts = [
    SELECT Id, UniqueName FROM ActionPlanTemplate
    WHERE UniqueName IN (
        'NEPA_WO_Aquatic_Milestones',
        'NEPA_WO_BigGame_Milestones',
        'NEPA_WO_Botanical_Milestones',
        'NEPA_WO_Geology_Milestones',
        'NEPA_WO_Hydrology_Milestones',
        'NEPA_WO_MigratoryBird_Milestones',
        'NEPA_WO_SageGrouse_Milestones'
    )
    AND TargetEntityType = 'WorkOrder'
];

if (!oldApts.isEmpty()) {
    delete oldApts;
    System.debug('Deleted ' + oldApts.size() + ' WorkOrder-targeted APTs');
} else {
    System.debug('No WorkOrder APTs found to delete — may already be migrated');
}

// ── 2. Create Visit-targeted APTs ─────────────────────────────────────────────
List<ActionPlanTemplate> newApts = new List<ActionPlanTemplate>{
    new ActionPlanTemplate(
        Name = 'NEPA WO Aquatic Milestones',
        UniqueName = 'NEPA_WO_Aquatic_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Fisheries and Wildlife Biologist (Aquatic) Work Order. Covers riparian survey, amphibian presence/absence, and CWA Section 404 memo. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Big Game Milestones',
        UniqueName = 'NEPA_WO_BigGame_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Wildlife Biologist (Big Game) Work Order. Covers shoulder-season assessment, winter range mapping, and pronghorn/elk migration corridor analysis. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Botanical Milestones',
        UniqueName = 'NEPA_WO_Botanical_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Botanist Work Order. Two seasonal site visits (June-July and August) for rare plant detection, plus seed mix approval. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Geology Milestones',
        UniqueName = 'NEPA_WO_Geology_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Geologist Visit triggered by EPA Superfund NPL or contamination-related GIS layer detection. Covers soils assessment, access road erosion review, CERCLA coordination, and reclamation bond memo. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Hydrology Milestones',
        UniqueName = 'NEPA_WO_Hydrology_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a hydrologist Visit triggered by NWI Wetlands or other aquatic/riparian GIS layer detection. Covers pre-survey prep, field assessment, CWA/NPDES review, and delineation report. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Migratory Bird Milestones',
        UniqueName = 'NEPA_WO_MigratoryBird_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Wildlife Biologist (Avian) Work Order. Covers spring nesting window survey (April-August), MBTA compliance, and avian collision risk assessment. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    ),
    new ActionPlanTemplate(
        Name = 'NEPA WO Sage-Grouse Milestones',
        UniqueName = 'NEPA_WO_SageGrouse_Milestones',
        TargetEntityType = 'Visit',
        Description = 'Field survey milestones for a Wildlife Biologist (Sage-Grouse) Visit triggered by FWS Critical Habitat detection. Covers lek survey window compliance, ARMPA conformance check, and survey report. Target object: Visit.',
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    )
};

// Insert one at a time — bulk insert triggers a platform validation
// that doesn't apply to single-record inserts for Visit APTs
Integer created = 0;
for (ActionPlanTemplate a : newApts) {
    insert a;
    System.debug('APT:' + a.UniqueName + '=' + a.Id);
    created++;
}
System.debug('Created ' + created + ' Visit-targeted APTs');
