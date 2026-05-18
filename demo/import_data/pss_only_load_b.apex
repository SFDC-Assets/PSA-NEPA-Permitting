// PSS-only load — Part B: ApplicationTimeline (25 milestones) + nepa_engagement__c
// Requires Part A to have run first (needs IDI-38709 to exist)
// Run: sf apex run --file demo/import_data/pss_only_load_b.apex --target-org NEPA_INNOVATOR

Id appId = [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1].Id;

// ─── 4. ApplicationTimeline (25 milestones) ───────────────────────────────────

Map<String, ApplicationTimeline> existingAT = new Map<String, ApplicationTimeline>();
for (ApplicationTimeline at : [SELECT Id, External_ID__c FROM ApplicationTimeline
    WHERE External_ID__c IN ('DEMO_AT_001','DEMO_AT_002','DEMO_AT_003','DEMO_AT_004','DEMO_AT_005',
        'DEMO_AT_006','DEMO_AT_007','DEMO_AT_008','DEMO_AT_009','DEMO_AT_010',
        'DEMO_AT_011','DEMO_AT_012','DEMO_AT_013','DEMO_AT_014','DEMO_AT_015',
        'DEMO_AT_016','DEMO_AT_017','DEMO_AT_018','DEMO_AT_019','DEMO_AT_020',
        'DEMO_AT_021','DEMO_AT_022','DEMO_AT_023','DEMO_AT_024','DEMO_AT_025')]) {
    existingAT.put(at.External_ID__c, at);
}

List<ApplicationTimeline> atRecords = new List<ApplicationTimeline>{
    new ApplicationTimeline(External_ID__c='DEMO_AT_001', nepa_related_process__c=appId, Name='Application Received', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2017,10,18), nepa_end_date__c=Date.newInstance(2017,10,18), nepa_tier__c='Process', nepa_outcome__c='IDI-38709 original application received October 18 2017.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_002', nepa_related_process__c=appId, Name='Pre-Application ID Team Consultation Completed', nepa_event_type__c='Scoping Complete', nepa_start_date__c=Date.newInstance(2019,3,12), nepa_end_date__c=Date.newInstance(2019,3,12), nepa_tier__c='Process', nepa_outcome__c='90-minute ID Team scoping session completed. All seven specialists briefed. Six field work orders generated.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_003', nepa_related_process__c=appId, Name='Lek Survey Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,5), nepa_end_date__c=Date.newInstance(2019,4,5), nepa_tier__c='Assessment', nepa_outcome__c='Greater Sage-Grouse lek survey completed within seasonal window. No active lek within 0.6 miles. PHMA confirmed.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_004', nepa_related_process__c=appId, Name='Botanical Survey Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,5,5), nepa_end_date__c=Date.newInstance(2019,6,10), nepa_tier__c='Assessment', nepa_outcome__c='Two-visit botanical survey completed. No sensitive plant species detected in disturbance area.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_005', nepa_related_process__c=appId, Name='Hydrology and Water Quality Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,25), nepa_end_date__c=Date.newInstance(2019,4,25), nepa_tier__c='Assessment', nepa_outcome__c='Hydrology WO closed. IDWR Water Permit Application task auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_006', nepa_related_process__c=appId, Name='Geology and Soils Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,5,12), nepa_end_date__c=Date.newInstance(2019,5,12), nepa_tier__c='Assessment', nepa_outcome__c='Geology WO closed. EPA NPDES NOI IDG370000 task auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_007', nepa_related_process__c=appId, Name='Wildlife Biological Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,30), nepa_end_date__c=Date.newInstance(2019,4,30), nepa_tier__c='Assessment', nepa_outcome__c='Wildlife survey completed at Jordan Creek trailhead. Sage-grouse population data recorded. ESA Section 7 consultation initiated.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_008', nepa_related_process__c=appId, Name='Tribal Consultation Initiated - NHPA Section 106', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,2,16), nepa_end_date__c=Date.newInstance(2019,2,16), nepa_tier__c='Consultation', nepa_outcome__c='Government-to-government consultation initiated per NHPA Section 106. Letter sent to Shoshone-Paiute Tribes.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_009', nepa_related_process__c=appId, Name='Tribal Consultation Certified Complete', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,3,16), nepa_end_date__c=Date.newInstance(2019,3,16), nepa_tier__c='Consultation', nepa_outcome__c='No historic properties of religious or cultural significance identified. Consultation certified complete.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_010', nepa_related_process__c=appId, Name='Preliminary EA Drafted', nepa_event_type__c='EA Initiated', nepa_start_date__c=Date.newInstance(2019,6,20), nepa_end_date__c=Date.newInstance(2019,6,25), nepa_tier__c='Documentation', nepa_outcome__c='Preliminary EA and unsigned FONSI drafted. 47 pages. Comment period scheduled.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_011', nepa_related_process__c=appId, Name='Public Comment Period Opened', nepa_event_type__c='Comment Period Open', nepa_start_date__c=Date.newInstance(2019,7,1), nepa_end_date__c=Date.newInstance(2019,7,1), nepa_tier__c='Public Engagement', nepa_outcome__c='28-day public comment period opened.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_012', nepa_related_process__c=appId, Name='ICL Comment Received', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,7,15), nepa_end_date__c=Date.newInstance(2019,7,15), nepa_tier__c='Comment', nepa_outcome__c='Idaho Conservation League comment received. Litigation threat flag set. Legal work order auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_013', nepa_related_process__c=appId, Name='OSC Comment Received', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,7,22), nepa_end_date__c=Date.newInstance(2019,7,22), nepa_tier__c='Comment', nepa_outcome__c='Office of Species Conservation comment received. Sage-grouse ARMPA conformance issue raised.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_014', nepa_related_process__c=appId, Name='Shoshone-Paiute Tribes Comment Received', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,7,28), nepa_end_date__c=Date.newInstance(2019,7,28), nepa_tier__c='Comment', nepa_outcome__c='Tribal comment received. Section 106 consultation documentation required.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_015', nepa_related_process__c=appId, Name='Public Comment Period Closed', nepa_event_type__c='Comment Period Closed', nepa_start_date__c=Date.newInstance(2019,7,28), nepa_end_date__c=Date.newInstance(2019,7,28), nepa_tier__c='Public Engagement', nepa_outcome__c='Comment period closed. 3 substantive comments received.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_016', nepa_related_process__c=appId, Name='Comment Response Work Orders Closed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,8,12), nepa_end_date__c=Date.newInstance(2019,8,12), nepa_tier__c='Process', nepa_outcome__c='All comment response work orders closed. ICL response finalized. OSC ARMPA conformance addressed. Tribal Section 106 documentation added.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_017', nepa_related_process__c=appId, Name='EA Revised', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,8,15), nepa_end_date__c=Date.newInstance(2019,8,15), nepa_tier__c='Documentation', nepa_outcome__c='Revised EA published August 15. Comment close to revised EA: 18 days.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_018', nepa_related_process__c=appId, Name='ESA Section 7 Consultation Complete', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,9,15), nepa_end_date__c=Date.newInstance(2019,9,15), nepa_tier__c='Consultation', nepa_outcome__c='USFWS Biological Opinion issued. No jeopardy finding. Incidental Take Statement included.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_019', nepa_related_process__c=appId, Name='Required Document Registry Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,10,20), nepa_end_date__c=Date.newInstance(2019,10,20), nepa_tier__c='Documentation', nepa_outcome__c='All 5 required documents verified green in Required Document Registry.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_020', nepa_related_process__c=appId, Name='Forrest Griggs (Geologist) Sign-Off', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_tier__c='Sign-Off', nepa_outcome__c='Geologist sign-off recorded.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_021', nepa_related_process__c=appId, Name='Colleen Trese (Wildlife Biologist) Sign-Off', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_tier__c='Sign-Off', nepa_outcome__c='Wildlife Biologist sign-off recorded. Same day as geologist — stage gate fires.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_022', nepa_related_process__c=appId, Name='Decision Stage Gate Cleared', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_tier__c='Gate', nepa_outcome__c='All 6 stage gates cleared. Record completeness 100%. Decision package ready.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_023', nepa_related_process__c=appId, Name='Field Manager Signs Decision Record', nepa_event_type__c='FONSI Issued', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_tier__c='Decision', nepa_outcome__c='Field Manager issued FONSI. Decision: Alternative B — Modified Surface Footprint. No significant impact.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_024', nepa_related_process__c=appId, Name='Administrative Record Auto-Generated', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_tier__c='Administrative Record', nepa_outcome__c='Full AR package auto-generated at decision: 6 docs, 3 comments, complete timeline. Locked.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_025', nepa_related_process__c=appId, Name='Applicant Notified', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_tier__c='Process', nepa_outcome__c='Sam Uhler notified of FONSI. Permit conditions and CWA 404/IDWR requirements transmitted.')
};

// For existing records (from prior CSV run), only update the process link — avoid VR on status fields
List<ApplicationTimeline> atInsert = new List<ApplicationTimeline>();
List<ApplicationTimeline> atLinkUpdate = new List<ApplicationTimeline>();
for (ApplicationTimeline at : atRecords) {
    if (existingAT.containsKey(at.External_ID__c)) {
        atLinkUpdate.add(new ApplicationTimeline(Id=existingAT.get(at.External_ID__c).Id, nepa_related_process__c=appId));
    } else { atInsert.add(at); }
}
if (!atInsert.isEmpty()) insert atInsert;
if (!atLinkUpdate.isEmpty()) update atLinkUpdate;
System.debug('ApplicationTimeline inserted=' + atInsert.size() + ' link-updated=' + atLinkUpdate.size());

// ─── 5. nepa_engagement__c ───────────────────────────────────────────────────

Map<String, nepa_engagement__c> existingEng = new Map<String, nepa_engagement__c>();
for (nepa_engagement__c e : [SELECT Id, External_ID__c FROM nepa_engagement__c
    WHERE External_ID__c IN ('DEMO_ENG_001','DEMO_ENG_002','DEMO_ENG_003','DEMO_ENG_004','DEMO_ENG_005')]) {
    existingEng.put(e.External_ID__c, e);
}

List<nepa_engagement__c> engRecords = new List<nepa_engagement__c>{
    new nepa_engagement__c(External_ID__c='DEMO_ENG_001', nepa_process__c=appId,
        nepa_engagement_type__c='Scoping Meeting', nepa_location_format__c='In-Person',
        nepa_start_datetime__c=DateTime.newInstanceGmt(2019,3,12,9,0,0),
        nepa_end_datetime__c=DateTime.newInstanceGmt(2019,3,12,10,30,0),
        nepa_attendance_count__c=7, nepa_translation_services__c=false,
        nepa_notes__c='BLM Owyhee Field Office - 3948 Development Ave Marsing ID 83639. 90-minute ID Team scoping session. Six parallel field work orders generated.'),
    new nepa_engagement__c(External_ID__c='DEMO_ENG_002', nepa_process__c=appId,
        nepa_engagement_type__c='Tribal Consultation', nepa_location_format__c='In-Person',
        nepa_start_datetime__c=DateTime.newInstanceGmt(2019,2,16,0,0,0),
        nepa_end_datetime__c=DateTime.newInstanceGmt(2019,3,16,0,0,0),
        nepa_attendance_count__c=2, nepa_translation_services__c=false,
        nepa_notes__c='Government-to-government consultation per NHPA Section 106. Shoshone-Paiute Tribes. Certified complete March 16 2019.'),
    new nepa_engagement__c(External_ID__c='DEMO_ENG_003', nepa_process__c=appId,
        nepa_engagement_type__c='Comment Solicitation', nepa_location_format__c='In-Person',
        nepa_start_datetime__c=DateTime.newInstanceGmt(2019,7,1,0,0,0),
        nepa_end_datetime__c=DateTime.newInstanceGmt(2019,7,28,0,0,0),
        nepa_attendance_count__c=0, nepa_translation_services__c=false,
        nepa_notes__c='28-day public comment period. ICL and OSC comments received and routed as work orders.'),
    new nepa_engagement__c(External_ID__c='DEMO_ENG_004', nepa_process__c=appId,
        nepa_engagement_type__c='Notice', nepa_location_format__c='Virtual',
        nepa_start_datetime__c=DateTime.newInstanceGmt(2019,4,25,0,0,0),
        nepa_end_datetime__c=DateTime.newInstanceGmt(2019,4,25,0,0,0),
        nepa_attendance_count__c=1, nepa_translation_services__c=false,
        nepa_notes__c='Automated portal notification to Sam Uhler: IDWR Water Permit Application action item triggered.'),
    new nepa_engagement__c(External_ID__c='DEMO_ENG_005', nepa_process__c=appId,
        nepa_engagement_type__c='Notice', nepa_location_format__c='Virtual',
        nepa_start_datetime__c=DateTime.newInstanceGmt(2019,5,12,0,0,0),
        nepa_end_datetime__c=DateTime.newInstanceGmt(2019,5,12,0,0,0),
        nepa_attendance_count__c=1, nepa_translation_services__c=false,
        nepa_notes__c='Automated notification to Sam Uhler: EPA NPDES NOI IDG370000 filing triggered by geologist WO closure.')
};

List<nepa_engagement__c> engInsert = new List<nepa_engagement__c>();
List<nepa_engagement__c> engUpdate = new List<nepa_engagement__c>();
for (nepa_engagement__c e : engRecords) {
    if (existingEng.containsKey(e.External_ID__c)) { e.Id = existingEng.get(e.External_ID__c).Id; engUpdate.add(e); }
    else { engInsert.add(e); }
}
if (!engInsert.isEmpty()) insert engInsert;
if (!engUpdate.isEmpty()) update engUpdate;
System.debug('nepa_engagement__c inserted=' + engInsert.size() + ' updated=' + engUpdate.size());
System.debug('Part B complete.');
