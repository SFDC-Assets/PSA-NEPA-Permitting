/**
 * Post-load script: populate nepa_discipline__c on ServiceResource records.
 *
 * Run AFTER 18_postload_polymorphic.apex (which creates/tags the demo ServiceResource).
 *
 * In a production org with full FSL licensing, each specialist (geologist,
 * hydrologist, wildlife biologist, etc.) would be a separate ServiceResource
 * with their own nepa_discipline__c value. NEPA_Team_Assembly_Orchestrator
 * queries: Get Records on ServiceResource WHERE nepa_discipline__c = {Discipline}
 * AND IsActive = true — returning the specialist whose value matches the
 * NEPA_Layer_Discipline__mdt.Discipline__c for the detected protection layer.
 *
 * Demo constraint: all 7 DEMO_SR_* slots resolve to the same SR record
 * (see 18_postload_polymorphic.apex step 2 — FSL enforces 1 Technician per User).
 * This script sets nepa_discipline__c = 'NEPA Specialist' on the consolidated
 * demo record. In a real org, run the commented multi-discipline block instead.
 *
 * Run via: sf apex run --file demo/import_data/21_postload_discipline.apex --target-org <alias>
 */

// ── Demo org: single consolidated ServiceResource ─────────────────────────────

List<ServiceResource> demoSR = [
    SELECT Id, Name, nepa_discipline__c
    FROM ServiceResource
    WHERE External_ID__c = 'DEMO_SR_001'
    LIMIT 1
];

if (!demoSR.isEmpty()) {
    demoSR[0].nepa_discipline__c = 'NEPA Specialist';
    update demoSR[0];
    System.debug('Demo SR discipline set: ' + demoSR[0].Id + ' → NEPA Specialist');
} else {
    System.debug('WARN: DEMO_SR_001 not found — run 18_postload_polymorphic.apex first.');
}

/*
 * ── Production org: set discipline per named ServiceResource ──────────────────
 *
 * Uncomment and run this block in orgs where each specialist has their own
 * ServiceResource record (full FSL multi-user licensing).
 *
 * Values must exactly match NEPA_Layer_Discipline__mdt.Discipline__c.
 *
Map<String, String> disciplineByName = new Map<String, String>{
    'Kara Kirkpatrick-Kreitinger' => 'NEPA Specialist',
    'Forrest Griggs'              => 'Geologist',
    'Colleen Trese'               => 'Wildlife Biologist (Sage-Grouse)',
    'Marcus Webb'                 => 'Hydrologist',
    'Dana Ruiz'                   => 'Fisheries and Wildlife Biologist (Aquatic)',
    'Trevor Hanks'                => 'Wildlife Biologist (Avian/Big Game)',
    'Priya Nambiar'               => 'Botanist'
};

List<ServiceResource> srList = [
    SELECT Id, Name, nepa_discipline__c
    FROM ServiceResource
    WHERE Name IN :disciplineByName.keySet()
    AND IsActive = true
];

for (ServiceResource sr : srList) {
    sr.nepa_discipline__c = disciplineByName.get(sr.Name);
}

if (!srList.isEmpty()) {
    update srList;
    System.debug('ServiceResource disciplines updated: ' + srList.size());
    for (ServiceResource sr : srList) {
        System.debug('  ' + sr.Name + ' → ' + sr.nepa_discipline__c);
    }
} else {
    System.debug('WARN: No ServiceResource records matched. Verify Name values.');
}
 */

System.debug('Discipline postload complete.');
