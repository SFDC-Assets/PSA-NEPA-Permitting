// Step 30: Wire Scene 7-C (BiOp reinitiation trigger) demo state.
//
// The NEPA_BiOp_Reinitiation_Checker flow fires when a Visit's
// nepa_reinit_*__c checkbox is checked AND the parent IA has
// nepa_has_active_biop__c = TRUE. It creates an ESA Coordinator Task
// and adds +12 to IndividualApplication.nepa_challenge_risk_delta__c.
//
// This script:
//   1. Finds the auto-generated Critical Habitat / Species Survey Visit (step 22)
//      and sets nepa_reinit_new_species_listing__c = TRUE — this is the field
//      the biologist checks in the demo ("new Greater Sage-Grouse critical
//      habitat designation triggers reinitiation under 50 CFR §402.16(a)(1)").
//      The flow fires async; the Task and risk delta appear after ~10 seconds.
//   2. Pre-seeds the ESA Coordinator Task as a fallback in case the flow
//      did not fire (e.g., nepa_has_active_biop__c was not yet TRUE at visit
//      update time, or the flow faulted). If the Task already exists (flow ran),
//      the insert is skipped.
//   3. Updates IndividualApplication.nepa_challenge_risk_delta__c from 0 to 12
//      if the flow did not already set it.
//
// Run AFTER 29_scene7_inspection_visits.apex.
// Run via: sf apex run --file demo/import_data/30_scene7_biop_reinit.apex --target-org <alias>

IndividualApplication ia = [
    SELECT Id, nepa_has_active_biop__c, nepa_challenge_risk_delta__c
    FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
];

// ─── 1. Set reinitiation trigger on the Critical Habitat / Species Survey Visit ──
Visit speciesVisit = null;
for (Visit v : [
    SELECT Id, Subject, nepa_reinit_new_species_listing__c
    FROM Visit
    WHERE nepa_process__c = :ia.Id
    AND nepa_auto_generated__c = true
    AND Subject LIKE '%Critical Habitat%'
    ORDER BY CreatedDate ASC LIMIT 1
]) {
    speciesVisit = v;
}

if (speciesVisit == null) {
    // Fall back to any auto-generated Visit if the discipline-specific one isn't found
    speciesVisit = [
        SELECT Id, Subject, nepa_reinit_new_species_listing__c
        FROM Visit
        WHERE nepa_process__c = :ia.Id
        AND nepa_auto_generated__c = true
        ORDER BY CreatedDate ASC LIMIT 1
    ];
}

if (!speciesVisit.nepa_reinit_new_species_listing__c) {
    // Updating this fires NEPA_BiOp_Reinitiation_Checker async (IA has nepa_has_active_biop__c = TRUE)
    update new Visit(Id = speciesVisit.Id, nepa_reinit_new_species_listing__c = true);
    System.debug('nepa_reinit_new_species_listing__c set TRUE on Visit: ' + speciesVisit.Subject);
    System.debug('NEPA_BiOp_Reinitiation_Checker queued async — ESA Task and risk delta +12 will appear in ~10s');
} else {
    System.debug('nepa_reinit_new_species_listing__c already TRUE on Visit: ' + speciesVisit.Subject);
}

// ─── 2. Pre-seed ESA Coordinator Task (fallback if flow did not fire) ─────────
List<Task> existingTask = [
    SELECT Id FROM Task
    WHERE WhatId = :ia.Id
    AND Subject = 'ESA §7 Reinitiation Required — Review BiOp Compliance'
    LIMIT 1
];

if (existingTask.isEmpty()) {
    // Flow hasn't fired yet (async) — insert the task directly as a fallback.
    // If the flow fires afterward, it will insert a duplicate; the cleanup command handles both.
    insert new Task(
        Subject     = 'ESA §7 Reinitiation Required — Review BiOp Compliance',
        WhatId      = ia.Id,
        Priority    = 'High',
        Status      = 'Not Started',
        ActivityDate = Date.today().addDays(3),
        Description = 'New species listing or critical habitat designation detected during field survey ' +
                      '(Greater Sage-Grouse PHMA — Jordan Creek vicinity). Reinitiation of ESA §7 ' +
                      'consultation required under 50 CFR §402.16(a)(1). Coordinate with USFWS within ' +
                      '3 business days. Source: NEPA_BiOp_Reinitiation_Checker (auto-generated).'
    );
    System.debug('ESA Coordinator Task pre-seeded (flow fallback).');
} else {
    System.debug('ESA Coordinator Task already exists (flow ran) — skipped.');
}

// ─── 3. Set nepa_challenge_risk_delta__c = 12 if flow did not update it ───────
if (ia.nepa_challenge_risk_delta__c == null || ia.nepa_challenge_risk_delta__c == 0) {
    update new IndividualApplication(Id = ia.Id, nepa_challenge_risk_delta__c = 12);
    System.debug('nepa_challenge_risk_delta__c set to 12 (flow fallback).');
} else {
    System.debug('nepa_challenge_risk_delta__c already = ' + ia.nepa_challenge_risk_delta__c + ' (flow ran) — skipped.');
}

System.debug('Step 30 complete.');
System.debug('Verify ESA Task: SELECT Subject, Priority, ActivityDate FROM Task WHERE WhatId = \'' + ia.Id + '\' AND Subject LIKE \'ESA%\'');
System.debug('Verify risk delta: SELECT nepa_challenge_risk_delta__c FROM IndividualApplication WHERE Id = \'' + ia.Id + '\''
);