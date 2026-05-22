// Step 28: Insert nepa_required_permit__c records for IDI-38709.
//
// Two permits are needed for Scene 7:
//   DEMO_RP_001 — EPA NPDES General Permit IDG370000 (status = Issued)
//                 Triggers NEPA_Permit_Issued_Schedule_Creator on insert.
//                 Flow queries NEPA_Inspection_Schedule__mdt for 'CWA Section 402 NPDES'
//                 and creates Visit inspection tasks with nepa_trigger_layer__c = Idaho warning.
//   DEMO_RP_002 — CWA Section 404 Permit (status = Pending)
//                 Referenced in IA description and OFD milestone. Shows the permits
//                 related list with a mix of issued vs. pending — the contrast
//                 the demo presenter calls out in Scene 7-A.
//
// Safe to re-run: all DML is conditional on External_ID__c absence.
// Run AFTER 18_postload_polymorphic.apex (IndividualApplication must exist).

IndividualApplication ia = [
    SELECT Id, nepa_state_code__c FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
];

// ─── Check which permits already exist ────────────────────────────────────────
Map<String, Id> existing = new Map<String, Id>();
for (nepa_required_permit__c p : [
    SELECT Id, External_ID__c FROM nepa_required_permit__c
    WHERE External_ID__c IN ('DEMO_RP_001', 'DEMO_RP_002')
]) {
    existing.put(p.External_ID__c, p.Id);
}

List<nepa_required_permit__c> toInsert = new List<nepa_required_permit__c>();

if (!existing.containsKey('DEMO_RP_001')) {
    toInsert.add(new nepa_required_permit__c(
        External_ID__c          = 'DEMO_RP_001',
        nepa_process__c         = ia.Id,
        nepa_permit_type__c     = 'CWA Section 402 NPDES',
        nepa_permit_status__c   = 'Issued',
        nepa_lead_agency__c     = 'EPA',
        nepa_regulatory_citation__c = '33 USC §1342; 40 CFR Part 122',
        nepa_external_federal_id__c = 'IDG370000',
        nepa_is_critical_path__c = true,
        nepa_statutory_deadline_days__c = 90,
        nepa_permit_notes__c    = 'Small Suction Dredge General Permit. Authorized under NPDES General Permit IDG370000. Requires quarterly Discharge Monitoring Reports and annual stormwater compliance inspection. Noncompliance trigger: discharge exceedance or unauthorized discharge.',
        nepa_sla_due_date__c    = Date.today().addDays(90)
    ));
}

if (!existing.containsKey('DEMO_RP_002')) {
    toInsert.add(new nepa_required_permit__c(
        External_ID__c          = 'DEMO_RP_002',
        nepa_process__c         = ia.Id,
        nepa_permit_type__c     = 'CWA Section 404',
        nepa_permit_status__c   = 'Pending',
        nepa_lead_agency__c     = 'USACE',
        nepa_regulatory_citation__c = '33 USC §1344; 33 CFR Part 323',
        nepa_is_critical_path__c = true,
        nepa_statutory_deadline_days__c = 120,
        nepa_permit_notes__c    = 'Nationwide Permit 27 — Aquatic Habitat Restoration. Required for ground disturbance within 50-foot Jordan Creek buffer. Pre-application meeting with USACE Boise District completed (see OFD milestone). Permit application pending at USACE.',
        nepa_sla_due_date__c    = Date.today().addDays(120)
    ));
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('nepa_required_permit__c inserted: ' + toInsert.size());
    for (nepa_required_permit__c p : toInsert) {
        System.debug('  ' + p.External_ID__c + ' — ' + p.nepa_permit_type__c + ' / ' + p.nepa_permit_status__c);
    }
} else {
    System.debug('nepa_required_permit__c: both records already exist — skipped.');
}

System.debug('Step 28 complete. NEPA_Permit_Issued_Schedule_Creator fires async on DEMO_RP_001 insert.');
System.debug('Wait 10-15 seconds then verify: SELECT Subject, nepa_discipline__c, nepa_trigger_layer__c FROM Visit WHERE nepa_auto_generated__c = true AND nepa_process__r.nepa_federal_unique_id__c = \'IDI-38709\'');