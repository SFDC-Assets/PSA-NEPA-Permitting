// Step 2: Create 7 Visit-targeted NEPA_WO_* APTs.
// Run AFTER migrate_apts_step1_delete.apex.
// Idempotent: skips any APT that already exists with the correct TargetEntityType.
// Must insert one at a time — bulk insert fails for Visit+Retail APTs on this org.
// Run: sf apex run --file scripts/migrate_apts_step2_create.apex --target-org NEPA_INNOVATOR

List<Map<String, String>> aptDefs = new List<Map<String, String>>();

Map<String, String> a1 = new Map<String, String>();
a1.put('name', 'NEPA WO Aquatic Milestones');
a1.put('uniqueName', 'NEPA_WO_Aquatic_Milestones');
a1.put('description', 'Field survey milestones for a Fisheries and Wildlife Biologist (Aquatic) Work Order. Covers riparian survey, amphibian presence/absence, and CWA Section 404 memo. Target object: Visit.');
aptDefs.add(a1);

Map<String, String> a2 = new Map<String, String>();
a2.put('name', 'NEPA WO Big Game Milestones');
a2.put('uniqueName', 'NEPA_WO_BigGame_Milestones');
a2.put('description', 'Field survey milestones for a Wildlife Biologist (Big Game) Work Order. Covers shoulder-season assessment, winter range mapping, and pronghorn/elk migration corridor analysis. Target object: Visit.');
aptDefs.add(a2);

Map<String, String> a3 = new Map<String, String>();
a3.put('name', 'NEPA WO Botanical Milestones');
a3.put('uniqueName', 'NEPA_WO_Botanical_Milestones');
a3.put('description', 'Field survey milestones for a Botanist Work Order. Two seasonal site visits (June-July and August) for rare plant detection, plus seed mix approval. Target object: Visit.');
aptDefs.add(a3);

Map<String, String> a4 = new Map<String, String>();
a4.put('name', 'NEPA WO Geology Milestones');
a4.put('uniqueName', 'NEPA_WO_Geology_Milestones');
a4.put('description', 'Field survey milestones for a Geologist Visit triggered by EPA Superfund NPL or contamination-related GIS layer detection. Covers soils assessment, access road erosion review, CERCLA coordination, and reclamation bond memo. Target object: Visit.');
aptDefs.add(a4);

Map<String, String> a5 = new Map<String, String>();
a5.put('name', 'NEPA WO Hydrology Milestones');
a5.put('uniqueName', 'NEPA_WO_Hydrology_Milestones');
a5.put('description', 'Field survey milestones for a hydrologist Visit triggered by NWI Wetlands or other aquatic/riparian GIS layer detection. Covers pre-survey prep, field assessment, CWA/NPDES review, and delineation report. Target object: Visit.');
aptDefs.add(a5);

Map<String, String> a6 = new Map<String, String>();
a6.put('name', 'NEPA WO Migratory Bird Milestones');
a6.put('uniqueName', 'NEPA_WO_MigratoryBird_Milestones');
a6.put('description', 'Field survey milestones for a Wildlife Biologist (Avian) Work Order. Covers spring nesting window survey (April-August), MBTA compliance, and avian collision risk assessment. Target object: Visit.');
aptDefs.add(a6);

Map<String, String> a7 = new Map<String, String>();
a7.put('name', 'NEPA WO Sage-Grouse Milestones');
a7.put('uniqueName', 'NEPA_WO_SageGrouse_Milestones');
a7.put('description', 'Field survey milestones for a Wildlife Biologist (Sage-Grouse) Visit triggered by FWS Critical Habitat detection. Covers lek survey window compliance, ARMPA conformance check, and survey report. Target object: Visit.');
aptDefs.add(a7);

// Build set of UniqueNames that already exist with Visit target (idempotency check)
Set<String> uniqueNames = new Set<String>();
for (Map<String, String> d : aptDefs) {
    uniqueNames.add(d.get('uniqueName'));
}
Set<String> alreadyExists = new Set<String>();
for (ActionPlanTemplate existing : [
    SELECT UniqueName FROM ActionPlanTemplate
    WHERE UniqueName IN :uniqueNames
    AND TargetEntityType = 'Visit'
]) {
    alreadyExists.add(existing.UniqueName);
}

Integer created = 0;
Integer skipped = 0;
for (Map<String, String> d : aptDefs) {
    String uname = d.get('uniqueName');
    if (alreadyExists.contains(uname)) {
        System.debug('SKIP (already exists): ' + uname);
        skipped++;
        continue;
    }
    ActionPlanTemplate t = new ActionPlanTemplate(
        Name = d.get('name'),
        UniqueName = uname,
        TargetEntityType = 'Visit',
        Description = d.get('description'),
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    );
    insert t;
    System.debug('CREATED: ' + uname + ' = ' + t.Id);
    created++;
}
System.debug('Done — created: ' + created + ', skipped: ' + skipped + ' of ' + aptDefs.size());
