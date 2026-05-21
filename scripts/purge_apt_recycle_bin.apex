// Purge deleted NEPA_WO_* APTs from recycle bin so their UniqueNames can be reused.
// Run BETWEEN migrate_apts_step1_delete.apex and migrate_apts_step2_create.apex.
List<ActionPlanTemplate> deleted = [
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
    ALL ROWS
];
System.debug('Found (including deleted): ' + deleted.size());
if (!deleted.isEmpty()) {
    Database.emptyRecycleBin(deleted);
    System.debug('Purged from recycle bin: ' + deleted.size());
} else {
    System.debug('Nothing in recycle bin — safe to run step2');
}
