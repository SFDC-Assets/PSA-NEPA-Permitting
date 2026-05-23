// Step 29: Pre-seed 4 NPDES inspection Visit records for Scene 7-B.
//
// NEPA_Permit_Issued_Schedule_Creator auto-creates these when DEMO_RP_001 is
// inserted in step 28. This script is a safety net for demo environments where
// the async flow may not have completed or was faulted (e.g., missing WorkType
// records). If the flow already ran, this script detects the existing Visits
// by Subject match and skips creation.
//
// Each Visit gets:
//   nepa_trigger_layer__c   — Idaho state risk warning from NEPA_State_Risk_Profile__mdt
//   nepa_state_risk_context__c — full warning text surfaced in the Visit page banner
//   nepa_auto_generated__c  — TRUE (marks these as system-generated)
//   nepa_discipline__c      — 'Environmental Compliance'
//   ContextId               — IndividualApplication (IDI-38709)
//   nepa_process__c         — IndividualApplication.Id
//
// Run AFTER 28_required_permits.apex.
// Run via: sf apex run --file demo/import_data/29_scene7_inspection_visits.apex --target-org <alias>

IndividualApplication ia = [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
];

Id demoLocationId;
for (Schema.Location loc : [SELECT Id FROM Location WHERE Name = 'BLM Owyhee Field Office' LIMIT 1]) {
    demoLocationId = loc.Id;
}
if (demoLocationId == null) {
    Schema.Location loc = new Schema.Location(
        Name = 'BLM Owyhee Field Office',
        LocationType = 'Business Site',
        IsInventoryLocation = false
    );
    insert loc;
    demoLocationId = loc.Id;
}

nepa_required_permit__c npdesPermit = [
    SELECT Id FROM nepa_required_permit__c
    WHERE External_ID__c = 'DEMO_RP_001' LIMIT 1
];

// ─── Idaho state risk context (from NEPA_State_Risk_Profile__mdt InspPriority_ID) ───
String idahoWarning = 'Standard risk state (33.3% challenger win rate). Follow standard monitoring protocol.';
String idahoRiskContext =
    'Idaho (ID) — MEDIUM litigation risk tier. 9th Circuit. ' +
    'Challenger win rate: 33.3%. Risk multiplier: 1.05×. ' +
    'Primary plaintiffs: Western Watersheds Project; Alliance for the Wild Rockies; Friends of the Clearwater. ' +
    'Dominant challenge types: Predator damage management EAs; Forest restoration projects. ' +
    'Inspector guidance: ' + idahoWarning;

// ─── Visit definitions (match NEPA_Inspection_Schedule__mdt for CWA Section 402 NPDES) ─
List<Map<String, Object>> visitDefs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'External_ID__c'      => 'DEMO_INSP_001',
        'instructions'        => 'NPDES Quarterly Discharge Monitoring Report Review',
        'Priority'            => 'High',
        'DueDays'             => 90,
        'InspectionType'      => 'Discharge Monitoring Report (DMR)'
    },
    new Map<String, Object>{
        'External_ID__c'      => 'DEMO_INSP_002',
        'instructions'        => 'NPDES Stormwater Compliance Inspection',
        'Priority'            => 'High',
        'DueDays'             => 180,
        'InspectionType'      => 'Stormwater Compliance'
    },
    new Map<String, Object>{
        'External_ID__c'      => 'DEMO_INSP_003',
        'instructions'        => 'Reclamation Progress Inspection',
        'Priority'            => 'Medium',
        'DueDays'             => 365,
        'InspectionType'      => 'Reclamation Compliance'
    },
    new Map<String, Object>{
        'External_ID__c'      => 'DEMO_INSP_004',
        'instructions'        => 'Wetland Buffer Compliance Inspection — Jordan Creek 50-ft Buffer',
        'Priority'            => 'High',
        'DueDays'             => 120,
        'InspectionType'      => 'Wetland Buffer Compliance'
    }
};

// ─── Check which Visits the flow already created ─────────────────────────────
Set<String> existingInstructions = new Set<String>();
for (Visit v : [
    SELECT InstructionDescription FROM Visit
    WHERE nepa_process__c = :ia.Id
    AND nepa_auto_generated__c = true
    AND InstructionDescription IN (
        'NPDES Quarterly Discharge Monitoring Report Review',
        'NPDES Stormwater Compliance Inspection',
        'Reclamation Progress Inspection',
        'Wetland Buffer Compliance Inspection — Jordan Creek 50-ft Buffer'
    )
]) {
    existingInstructions.add(v.InstructionDescription);
}

List<Visit> toInsert = new List<Visit>();
for (Map<String, Object> def : visitDefs) {
    String instructions = (String) def.get('instructions');
    if (existingInstructions.contains(instructions)) {
        System.debug('Visit already exists — skipping: ' + instructions);
        continue;
    }
    Integer dueDays = (Integer) def.get('DueDays');
    Visit v = new Visit(
        External_ID__c            = (String) def.get('External_ID__c'),
        PlaceId                   = demoLocationId,
        InstructionDescription    = instructions,
        Status                    = 'Planned',
        VisitPriority             = (String) def.get('Priority'),
        PlannedVisitStartTime     = DateTime.now().addDays(dueDays),
        PlannedVisitEndTime       = DateTime.now().addDays(dueDays).addHours(4),
        ContextId                 = ia.Id,
        nepa_process__c           = ia.Id,
        nepa_discipline__c        = 'Environmental Compliance',
        nepa_auto_generated__c    = true,
        nepa_hard_gate__c         = false,
        nepa_state_risk_context__c = idahoRiskContext
    );
    toInsert.add(v);
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inspection Visits inserted: ' + toInsert.size());
    for (Visit v : toInsert) {
        System.debug('  ' + v.InstructionDescription + ' — due +' + ((Integer)((DateTime.now().getTime() - v.PlannedVisitStartTime.getTime()) / -86400000)) + ' days');
    }
} else {
    System.debug('All 4 inspection Visits already exist (flow created them) — skipped.');
}

System.debug('Step 29 complete.');
System.debug('Verify: SELECT InstructionDescription, nepa_discipline__c, nepa_state_risk_context__c, PlannedVisitStartTime FROM Visit WHERE nepa_process__r.nepa_federal_unique_id__c = \'IDI-38709\' AND nepa_auto_generated__c = true');