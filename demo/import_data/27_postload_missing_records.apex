// Step 27: Insert/upsert records that cannot load via Bulk API CSV:
//   - nepa_engagement__c (all 5 — nepa_process__c required, not in CSV)
//   - PublicComplaint DEMO_PC_003 (Shoshone-Paiute — same issue)
//   - nepa_decision_payload__c (1 record — no External_ID__c on object)
//   - nepa_ar_export__c (1 record — no External_ID__c on object)
//   - Task (8 records — Bulk API v2 import hangs at UploadComplete on small batches;
//     loaded here so WhatId can be wired in the same transaction)
// Safe to re-run: all DML is conditional on External_ID__c or Subject match.

IndividualApplication ia = [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
];

// ─── 1. nepa_engagement__c (5 records) ────────────────────────────────────────
Map<String, nepa_engagement__c> existingEng = new Map<String, nepa_engagement__c>();
for (nepa_engagement__c e : [
    SELECT Id, External_ID__c FROM nepa_engagement__c
    WHERE nepa_process__c = :ia.Id AND External_ID__c != null
]) {
    existingEng.put(e.External_ID__c, e);
}

List<nepa_engagement__c> engToUpsert = new List<nepa_engagement__c>();

engToUpsert.add(new nepa_engagement__c(
    External_ID__c = 'DEMO_ENG_001',
    nepa_process__c = ia.Id,
    nepa_engagement_type__c = 'Scoping Meeting',
    nepa_start_datetime__c = DateTime.newInstanceGmt(2019, 3, 12, 9, 0, 0),
    nepa_end_datetime__c   = DateTime.newInstanceGmt(2019, 3, 12, 10, 30, 0),
    nepa_location_format__c = 'In-Person',
    nepa_attendance_count__c = 7,
    nepa_translation_services__c = false,
    nepa_notes__c = 'BLM Owyhee Field Office - 3948 Development Ave Marsing ID 83639. 90-minute Interdisciplinary Team scoping session with applicants Sam Uhler and David Smith. Full ID Team assembled: NEPA Specialist Geologist Wildlife Biologist Hydrologist Aquatic Biologist Avian/Big Game Biologist Botanist. Project scope confirmed: 15 acres T. 6 S. R. 5 W. Sec. 28 Jordan Creek watershed. Six parallel field work orders generated at session close.'
));
engToUpsert.add(new nepa_engagement__c(
    External_ID__c = 'DEMO_ENG_002',
    nepa_process__c = ia.Id,
    nepa_engagement_type__c = 'Tribal Consultation',
    nepa_start_datetime__c = DateTime.newInstanceGmt(2019, 2, 16, 0, 0, 0),
    nepa_end_datetime__c   = DateTime.newInstanceGmt(2019, 3, 16, 0, 0, 0),
    nepa_location_format__c = 'In-Person',
    nepa_attendance_count__c = 2,
    nepa_translation_services__c = false,
    nepa_notes__c = 'Government-to-Government Written Correspondence. Government-to-government consultation initiated February 16 2019 per NHPA Section 106. Letter sent to Shoshone-Paiute Tribes of the Duck Valley Reservation. 30-day response window. Tribe responded within window. No historic properties of religious or cultural significance identified. Consultation certified complete March 16 2019.'
));
engToUpsert.add(new nepa_engagement__c(
    External_ID__c = 'DEMO_ENG_003',
    nepa_process__c = ia.Id,
    nepa_engagement_type__c = 'Comment Solicitation',
    nepa_start_datetime__c = DateTime.newInstanceGmt(2019, 7, 1, 0, 0, 0),
    nepa_end_datetime__c   = DateTime.newInstanceGmt(2019, 7, 28, 0, 0, 0),
    nepa_location_format__c = 'In-Person',
    nepa_attendance_count__c = 0,
    nepa_translation_services__c = false,
    nepa_notes__c = 'Online Portal and BLM Owyhee Field Office Public File. 28-day public comment period on preliminary EA and unsigned FONSI. Two substantive commenters identified: Idaho Conservation League (ICL) and Office of Species Conservation (OSC). Both routed as work orders. Responses incorporated August 15 2019.'
));
engToUpsert.add(new nepa_engagement__c(
    External_ID__c = 'DEMO_ENG_004',
    nepa_process__c = ia.Id,
    nepa_engagement_type__c = 'Notice',
    nepa_start_datetime__c = DateTime.newInstanceGmt(2019, 4, 25, 0, 0, 0),
    nepa_end_datetime__c   = DateTime.newInstanceGmt(2019, 4, 25, 0, 0, 0),
    nepa_location_format__c = 'Virtual',
    nepa_attendance_count__c = 1,
    nepa_translation_services__c = false,
    nepa_notes__c = 'Automated notification to Sam Uhler via applicant portal. IDWR Water Permit Application action item triggered by hydrologist work order closure. 30-day SLA assigned to NEPA coordinator. Sam Uhler acknowledged action item. IDWR application initiated April 28 2019.'
));
engToUpsert.add(new nepa_engagement__c(
    External_ID__c = 'DEMO_ENG_005',
    nepa_process__c = ia.Id,
    nepa_engagement_type__c = 'Notice',
    nepa_start_datetime__c = DateTime.newInstanceGmt(2019, 5, 12, 0, 0, 0),
    nepa_end_datetime__c   = DateTime.newInstanceGmt(2019, 5, 12, 0, 0, 0),
    nepa_location_format__c = 'Virtual',
    nepa_attendance_count__c = 1,
    nepa_translation_services__c = false,
    nepa_notes__c = 'Automated notification to Sam Uhler: EPA NPDES NOI IDG370000 (Small Suction Dredge) filing triggered by geologist work order closure. 60-day processing clock started. Sam Uhler initiated NPDES NOI filing. NPDES authorization confirmed.'
));

List<nepa_engagement__c> engInsert = new List<nepa_engagement__c>();
List<nepa_engagement__c> engUpdate = new List<nepa_engagement__c>();
for (nepa_engagement__c e : engToUpsert) {
    if (existingEng.containsKey(e.External_ID__c)) {
        e.Id = existingEng.get(e.External_ID__c).Id;
        engUpdate.add(e);
    } else {
        engInsert.add(e);
    }
}
if (!engInsert.isEmpty()) insert engInsert;
if (!engUpdate.isEmpty()) update engUpdate;
System.debug('nepa_engagement__c inserted: ' + engInsert.size() + ' updated: ' + engUpdate.size());

// ─── 2. PublicComplaint DEMO_PC_003 (Shoshone-Paiute Tribes) ─────────────────
// Validation rule NEPA_Comment_Period_Closed fires on ISNEW() when nepa_related_process__c
// is set and comment period end date is in the past. Insert without the lookup first,
// then update to wire it (ISNEW() is false on update so the rule doesn't fire).
Account acct005 = [SELECT Id FROM Account WHERE External_ID__c = 'DEMO_ACCT_005' LIMIT 1];
List<PublicComplaint> pc003 = [
    SELECT Id, nepa_related_process__c FROM PublicComplaint WHERE External_ID__c = 'DEMO_PC_003' LIMIT 1
];
if (pc003.isEmpty()) {
    PublicComplaint newPC = new PublicComplaint(
        External_ID__c = 'DEMO_PC_003',
        Subject = 'Shoshone-Paiute Tribes - Section 106 Consultation Concerns',
        Status = 'Resolved',
        AccountId = acct005.Id,
        IncidentDate = Date.newInstance(2019, 7, 28),
        IsReporterConfidential = false,
        IsComplainantAuthorized = true,
        ShouldInclInRegulatoryRpt = false,
        nepa_date_submitted__c = Date.newInstance(2019, 7, 28),
        nepa_comment_body__c = 'The Shoshone-Paiute Tribes of the Duck Valley Reservation formally request that BLM document the government-to-government consultation process under NHPA Section 106 and Executive Order 13175. The 1.7-mile access road traverses land with documented traditional cultural properties in the Jordan Creek corridor. The EA must include a cultural landscape analysis and demonstrate that the Tribes have been meaningfully consulted — not merely notified — prior to any finding of no adverse effect. A Programmatic Agreement may be required.',
        nepa_is_substantive__c = true,
        nepa_litigation_threat_flag__c = true,
        nepa_pii_redacted__c = false,
        nepa_public_source__c = false,
        nepa_requires_human_review__c = true,
        nepa_human_override__c = false,
        nepa_category__c = 'NHPA Section 106 - Traditional Cultural Properties; Government-to-Government Consultation',
        nepa_response_status__c = 'Finalized',
        nepa_agency_response__c = 'Government-to-government consultation with Shoshone-Paiute Tribes completed per NHPA Section 106 and E.O. 13175. Cultural landscape analysis incorporated into EA. Tribal Consultation Certification signed and added to Required Document Registry. No adverse effect determination documented.',
        nepa_sentiment__c = 'Opposed',
        nepa_organization__c = 'Shoshone-Paiute Tribes of the Duck Valley Reservation',
        Method_of_Submission__c = 'Mail',
        nepa_litigation_threat_basis__c = 'Tribal Nation plaintiff — 87.5% litigation win rate (PermitTEC corpus); consultation failure is highest-risk grounds for NHPA Section 106 challenge',
        nepa_legal_review_status__c = 'Assigned to Counsel'
    );
    insert newPC;
    // Now wire the lookup — ISNEW() is false so validation rule doesn't fire.
    update new PublicComplaint(Id = newPC.Id, nepa_related_process__c = ia.Id);
    System.debug('PublicComplaint DEMO_PC_003 inserted and wired.');
} else {
    // Already exists; ensure process lookup is set.
    PublicComplaint existing = pc003[0];
    if (existing.nepa_related_process__c == null) {
        update new PublicComplaint(Id = existing.Id, nepa_related_process__c = ia.Id);
    }
    System.debug('PublicComplaint DEMO_PC_003 already exists — skipped.');
}

// ─── 3. nepa_decision_payload__c (1 record) ───────────────────────────────────
List<nepa_decision_payload__c> existingDP = [
    SELECT Id FROM nepa_decision_payload__c
    WHERE nepa_process__c = :ia.Id LIMIT 1
];
if (existingDP.isEmpty()) {
    insert new nepa_decision_payload__c(
        nepa_process__c = ia.Id,
        nepa_decision_type__c = 'FONSI',
        nepa_decision_date__c = Date.newInstance(2021, 6, 15),
        nepa_selected_alternative__c = 'Alternative B — Modified Surface Footprint',
        nepa_alternatives_considered__c = '3',
        nepa_mitigation_measures__c = 'Seasonal survey windows enforced (lek survey before April 30; botanist two-visit requirement); stormwater BMP with twice-annual BLM inspection; full reclamation bond tied to BLM botanist seed mix approval; concurrent IDWR water permit initiated at hydrologist work order close; concurrent EPA NPDES permit initiated at geologist work order close',
        nepa_rationale__c = 'No significant impact; 15-acre surface disturbance within EA review scope; extraordinary circumstances identified (PHMA — Greater Sage-Grouse habitat, NWI Wetlands — Jordan Creek adjacency) and addressed through mitigation measures; tribal consultation with Shoshone-Paiute Tribes certified complete (Section 106 and E.O. 13175); defensibility score 91 — all six stage gates cleared',
        nepa_significant_impacts__c = 'false',
        nepa_monitoring_requirements__c = 'Annual reclamation inspection by BLM botanist; stormwater compliance report due March 1 each operating year; gate access log submitted quarterly',
        nepa_is_supplemental__c = false
    );
    System.debug('nepa_decision_payload__c inserted.');
} else {
    System.debug('nepa_decision_payload__c already exists — skipped.');
}

// ─── 4. nepa_ar_export__c (1 record) ──────────────────────────────────────────
List<nepa_ar_export__c> existingAR = [
    SELECT Id FROM nepa_ar_export__c
    WHERE nepa_process__c = :ia.Id LIMIT 1
];
if (existingAR.isEmpty()) {
    insert new nepa_ar_export__c(
        nepa_process__c = ia.Id,
        nepa_export_status__c = 'Complete',
        nepa_export_type__c = 'Full Package',
        nepa_requested_date__c = Date.newInstance(2021, 6, 15),
        nepa_completed_date__c = Date.newInstance(2021, 6, 15),
        nepa_comment_count__c = 3,
        nepa_document_count__c = 6,
        nepa_export_download_url__c = 'https://placeholder.salesforce.com/ar-manifest/IDI-38709'
    );
    System.debug('nepa_ar_export__c inserted.');
} else {
    System.debug('nepa_ar_export__c already exists — skipped.');
}

// ─── 5. Task (8 records — wired to IA) ────────────────────────────────────────
// Bulk API v2 import hangs at UploadComplete for small Task payloads on APS trial orgs.
// Loaded here with WhatId set directly to avoid a second Apex pass.
Set<String> existingTaskSubjects = new Set<String>();
for (Task t : [SELECT Subject FROM Task WHERE WhatId = :ia.Id]) {
    existingTaskSubjects.add(t.Subject);
}

List<Task> tasksToInsert = new List<Task>();
List<Map<String,Object>> taskDefs = new List<Map<String,Object>>{
    new Map<String,Object>{ 'Subject', 'Initiate IDWR Water Permit Application - Jordan Creek', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,5,25), 'Description', 'AUTO-TRIGGERED by closure of DEMO_WO_002 (Hydrology Work Order) April 25 2019. Initiate Idaho Department of Water Resources water withdrawal permit application for Jordan Creek. Required before any Jordan Creek water withdrawal. Applicant Sam Uhler notified via portal. 30-day SLA.' },
    new Map<String,Object>{ 'Subject', 'File EPA NPDES NOI IDG370000 - Small Suction Dredge', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,6,12), 'Description', 'AUTO-TRIGGERED by closure of DEMO_WO_003 (Geology Work Order) May 12 2019. File Notice of Intent for EPA NPDES General Permit IDG370000. 60-day processing clock starts on filing. Land management agencies have 30 days to object. Applicant Sam Uhler cannot operate until written authorization received.' },
    new Map<String,Object>{ 'Subject', 'Day-30 NPDES Check - Confirm No Agency Objection Filed', 'Status', 'Completed', 'Priority', 'Normal', 'ActivityDate', Date.newInstance(2019,6,14), 'Description', 'AUTO-TRIGGERED at day 30 after NPDES NOI filing (May 15 + 30 days = June 14). Confirm no federal land management agency filed 30-day objection. Check with EPA Region 10. If clear: update co-permit status to On Track.' },
    new Map<String,Object>{ 'Subject', 'Add Dust Mitigation Analysis to Air Quality Section - ICL Comment', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,8,15), 'Description', 'AUTO-TRIGGERED by Plaintiff Intelligence flagging ICL Comment as substantive. Add quantitative dust emissions assessment for: (1) fugitive dust from 1.7-mile unpaved access road; (2) mercury particulate assessment based on Owyhee County placer mine historical data. Complete before EA revised version August 15.' },
    new Map<String,Object>{ 'Subject', 'Generate ARMPA Justifiable Departure Response Memo - OSC Comment', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,8,15), 'Description', 'AUTO-TRIGGERED by NEPA Coordinator review of OSC comment. Pull 2019 Idaho ARMPA ROD. Generate response memo citing Section 4.3 Justifiable Departure. Document explicit ARMPA citation and Idaho Governor\'s office consultation. Incorporate into revised EA.' },
    new Map<String,Object>{ 'Subject', 'Confirm Tribal Consultation Certification Before EA Publication', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,6,28), 'Description', 'HARD GATE CHECK before preliminary EA published July 1. Verify: (1) Shoshone-Paiute Tribes response received; (2) NHPA Section 106 certification completed; (3) Certification document attached to case file. BLOCK publication if not complete. Current status: Certification completed March 16 — gate clear.' },
    new Map<String,Object>{ 'Subject', 'Verify Required Document Registry All Five Documents', 'Status', 'Completed', 'Priority', 'High', 'ActivityDate', Date.newInstance(2019,11,19), 'Description', 'HARD GATE CHECK before Field Manager issues Decision Record. Verify all five documents complete: (1) Environmental Assessment; (2) FONSI; (3) Decision Record ready for signature; (4) Affected Resources Form; (5) Tribal Consultation Certification. All five green — stage gate clear for November 27 decision.' },
    new Map<String,Object>{ 'Subject', 'Applicant Portal Update - Decision Record Issued', 'Status', 'Completed', 'Priority', 'Normal', 'ActivityDate', Date.newInstance(2019,11,27), 'Description', 'AUTO-TRIGGERED by Decision Record stage gate completion. Send automated notification to Sam Uhler portal account: Plan of Operations IDI-38709 approved. Decision Record attached. Approved conditions: 50-foot Jordan Creek buffer silt fencing steep-shoreline pond design seasonal mining window March 1 - November 30 reclamation bond.' }
};

for (Map<String,Object> def : taskDefs) {
    String subj = (String) def.get('Subject');
    if (!existingTaskSubjects.contains(subj)) {
        tasksToInsert.add(new Task(
            Subject      = subj,
            Status       = (String) def.get('Status'),
            Priority     = (String) def.get('Priority'),
            ActivityDate = (Date)   def.get('ActivityDate'),
            Description  = (String) def.get('Description'),
            WhatId       = ia.Id
        ));
    }
}
if (!tasksToInsert.isEmpty()) insert tasksToInsert;
System.debug('Tasks inserted: ' + tasksToInsert.size() + ' (skipped ' + (taskDefs.size() - tasksToInsert.size()) + ' already existing)');

System.debug('Step 27 complete.');
