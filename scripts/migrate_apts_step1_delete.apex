// Step 1: Delete the 7 WorkOrder-targeted NEPA_WO_* APTs.
// Run BEFORE migrate_apts_step2_create.apex.
// Safe: verified no live ActionPlan records reference these versions.
// Run: sf apex run --file scripts/migrate_apts_step1_delete.apex --target-org NEPA_INNOVATOR

List<ActionPlanTemplate> oldApts = [
    SELECT Id, UniqueName, TargetEntityType
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
    AND TargetEntityType = 'WorkOrder'
];

if (oldApts.isEmpty()) {
    System.debug('Nothing to delete — no WorkOrder APTs found with these names.');
} else {
    delete oldApts;
    System.debug('Deleted ' + oldApts.size() + ' WorkOrder-targeted APTs. Run step2 next.');
}
