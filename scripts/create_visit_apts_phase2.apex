// =============================================================================
// create_visit_apts_phase2.apex  (Phase 2 of 3)
// Inserts 28 ActionPlanTemplateItem records (4 items × 7 templates).
// Prerequisite: run phase1 first so the 7 APTs exist in the org.
// Run as: sf apex run --file scripts/create_visit_apts_phase2.apex --target-org <alias>
// =============================================================================

// ── 1. Query the 7 APTs by UniqueName ────────────────────────────────────────
Map<String, Id> aptIdByUniqueName = new Map<String, Id>();
for (ActionPlanTemplate apt : [
    SELECT Id, UniqueName
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
    aptIdByUniqueName.put(apt.UniqueName, apt.Id);
}

if (aptIdByUniqueName.isEmpty()) {
    System.debug('ERROR: No APTs found — run phase1 first');
    return;
}

// ── 2. Query auto-created ActionPlanTemplateVersion for each APT ─────────────
Map<Id, Id> versionIdByAptId = new Map<Id, Id>();
for (ActionPlanTemplateVersion ver : [
    SELECT Id, ActionPlanTemplateId
    FROM ActionPlanTemplateVersion
    WHERE ActionPlanTemplateId IN :aptIdByUniqueName.values()
]) {
    versionIdByAptId.put(ver.ActionPlanTemplateId, ver.Id);
}

// ── 3. Skip any ActionPlanTemplateItem whose UniqueName already exists ────────
Set<String> existingItemNames = new Set<String>();
for (ActionPlanTemplateItem existing : [
    SELECT UniqueName
    FROM ActionPlanTemplateItem
    WHERE UniqueName IN (
        'NEPA_WO_Aqua_1_Desktop',
        'NEPA_WO_Aqua_2_Riparian',
        'NEPA_WO_Aqua_3_Amphibian',
        'NEPA_WO_Aqua_4_Memo',
        'NEPA_WO_BG_1_Desktop',
        'NEPA_WO_BG_2_Field',
        'NEPA_WO_BG_3_WinterRange',
        'NEPA_WO_BG_4_Report',
        'NEPA_WO_Bot_1_Desktop',
        'NEPA_WO_Bot_2_Visit1',
        'NEPA_WO_Bot_3_Visit2',
        'NEPA_WO_Bot_4_SeedMix',
        'NEPA_WO_Geo_1_Desktop',
        'NEPA_WO_Geo_2_Field',
        'NEPA_WO_Geo_3_CERCLA',
        'NEPA_WO_Geo_4_Report',
        'NEPA_WO_Hydro_1_Desktop',
        'NEPA_WO_Hydro_2_Field',
        'NEPA_WO_Hydro_3_CWA',
        'NEPA_WO_Hydro_4_Report',
        'NEPA_WO_Bird_1_Desktop',
        'NEPA_WO_Bird_2_NestSurvey',
        'NEPA_WO_Bird_3_MBTA',
        'NEPA_WO_Bird_4_Report',
        'NEPA_WO_SGrouse_1_Desktop',
        'NEPA_WO_SGrouse_2_LekSurvey',
        'NEPA_WO_SGrouse_3_ARMPA',
        'NEPA_WO_SGrouse_4_Report'
    )
]) {
    existingItemNames.add(existing.UniqueName);
}

// ── 4. Insert ActionPlanTemplateItem records ──────────────────────────────────
List<ActionPlanTemplateItem> itemsToInsert = new List<ActionPlanTemplateItem>();

// ---------- AQUATIC ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_Aquatic_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_Aquatic_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_Aqua_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Aquatic Species Desktop Review',
            UniqueName = 'NEPA_WO_Aqua_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Aqua_2_Riparian')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Riparian Survey and Fish Habitat Assessment',
            UniqueName = 'NEPA_WO_Aqua_2_Riparian'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Aqua_3_Amphibian')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Amphibian Presence/Absence Survey',
            UniqueName = 'NEPA_WO_Aqua_3_Amphibian'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Aqua_4_Memo')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'CWA Section 404 and ESA Section 7 Memo',
            UniqueName = 'NEPA_WO_Aqua_4_Memo'
        ));
    }
}

// ---------- BIG GAME ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_BigGame_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_BigGame_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_BG_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Big Game Desktop Review',
            UniqueName = 'NEPA_WO_BG_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_BG_2_Field')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Shoulder-Season Field Assessment',
            UniqueName = 'NEPA_WO_BG_2_Field'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_BG_3_WinterRange')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Winter Range Mapping and Fragmentation Analysis',
            UniqueName = 'NEPA_WO_BG_3_WinterRange'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_BG_4_Report')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Big Game Assessment Report',
            UniqueName = 'NEPA_WO_BG_4_Report'
        ));
    }
}

// ---------- BOTANICAL ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_Botanical_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_Botanical_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_Bot_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Botanical Desktop Review and Survey Planning',
            UniqueName = 'NEPA_WO_Bot_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bot_2_Visit1')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Site Visit 1 — Early Season Survey (June–July)',
            UniqueName = 'NEPA_WO_Bot_2_Visit1'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bot_3_Visit2')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Site Visit 2 — Late Season Survey (August)',
            UniqueName = 'NEPA_WO_Bot_3_Visit2'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bot_4_SeedMix')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Reclamation Seed Mix Approval',
            UniqueName = 'NEPA_WO_Bot_4_SeedMix'
        ));
    }
}

// ---------- GEOLOGY ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_Geology_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_Geology_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_Geo_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Geology and Soils Desktop Review',
            UniqueName = 'NEPA_WO_Geo_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Geo_2_Field')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Field Soils Assessment and Road Review',
            UniqueName = 'NEPA_WO_Geo_2_Field'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Geo_3_CERCLA')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'CERCLA Coordination and Phase I/II Trigger',
            UniqueName = 'NEPA_WO_Geo_3_CERCLA'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Geo_4_Report')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Reclamation Bond and Geology Report',
            UniqueName = 'NEPA_WO_Geo_4_Report'
        ));
    }
}

// ---------- HYDROLOGY ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_Hydrology_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_Hydrology_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_Hydro_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Pre-Survey Desktop Review',
            UniqueName = 'NEPA_WO_Hydro_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Hydro_2_Field')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Wetland and Waterway Field Assessment',
            UniqueName = 'NEPA_WO_Hydro_2_Field'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Hydro_3_CWA')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'CWA Section 404/401 and NPDES Review',
            UniqueName = 'NEPA_WO_Hydro_3_CWA'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Hydro_4_Report')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Hydrology Assessment Report',
            UniqueName = 'NEPA_WO_Hydro_4_Report'
        ));
    }
}

// ---------- MIGRATORY BIRD ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_MigratoryBird_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_MigratoryBird_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_Bird_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Avian Desktop Review and Raptor Nest Search',
            UniqueName = 'NEPA_WO_Bird_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bird_2_NestSurvey')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Nesting Season Survey — Spring/Summer Window',
            UniqueName = 'NEPA_WO_Bird_2_NestSurvey'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bird_3_MBTA')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'MBTA Compliance Analysis',
            UniqueName = 'NEPA_WO_Bird_3_MBTA'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_Bird_4_Report')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Avian Survey Report and MBTA Compliance Memo',
            UniqueName = 'NEPA_WO_Bird_4_Report'
        ));
    }
}

// ---------- SAGE-GROUSE ----------
if (aptIdByUniqueName.containsKey('NEPA_WO_SageGrouse_Milestones')) {
    Id verId = versionIdByAptId.get(aptIdByUniqueName.get('NEPA_WO_SageGrouse_Milestones'));
    if (!existingItemNames.contains('NEPA_WO_SGrouse_1_Desktop')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 1,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Sage-Grouse Desktop Pre-Assessment',
            UniqueName = 'NEPA_WO_SGrouse_1_Desktop'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_SGrouse_2_LekSurvey')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 2,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Lek Survey — Active Season Window',
            UniqueName = 'NEPA_WO_SGrouse_2_LekSurvey'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_SGrouse_3_ARMPA')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 3,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'ARMPA Conformance Check',
            UniqueName = 'NEPA_WO_SGrouse_3_ARMPA'
        ));
    }
    if (!existingItemNames.contains('NEPA_WO_SGrouse_4_Report')) {
        itemsToInsert.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = verId,
            DisplayOrder = 4,
            IsRequired = true,
            ItemEntityType = 'Task',
            Name = 'Sage-Grouse Survey Report',
            UniqueName = 'NEPA_WO_SGrouse_4_Report'
        ));
    }
}

if (itemsToInsert.isEmpty()) {
    System.debug('Done: 0 items created — all already exist');
    return;
}

insert itemsToInsert;

// ── 5. Debug output: item IDs for reference in phase 3 ───────────────────────
for (ActionPlanTemplateItem item : itemsToInsert) {
    System.debug('ITEM:' + item.UniqueName + '=' + item.Id);
}
System.debug('Done: ' + itemsToInsert.size() + ' items created — run phase3 next');
