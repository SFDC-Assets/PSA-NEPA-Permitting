// Step 31b_cleanup: Reset broken NEPA Visit APT versions (Final with no ItemValues).
// Run ONLY when 31c fails with "available for template versions in Draft state".
// Sets Final versions to Obsolete then deletes them (cascade removes items).
// After this completes, re-run 31b then 31c.

List<ActionPlanTemplateVersion> finalVs = [SELECT Id FROM ActionPlanTemplateVersion
    WHERE ActionPlanTemplateId IN (SELECT Id FROM ActionPlanTemplate WHERE UniqueName LIKE 'NEPA_Visit_%')
    AND Status = 'Final'];

if (finalVs.isEmpty()) {
    System.debug('No Final versions found. Nothing to clean up.');
} else {
    List<ActionPlanTemplateVersion> toObsolete = new List<ActionPlanTemplateVersion>();
    for (ActionPlanTemplateVersion v : finalVs) toObsolete.add(new ActionPlanTemplateVersion(Id=v.Id, Status='Obsolete'));
    update toObsolete;
    delete toObsolete;
    System.debug('Cleaned up ' + finalVs.size() + ' Final version(s). Re-run 31b then 31c.');
}
