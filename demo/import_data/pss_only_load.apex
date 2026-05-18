/**
 * PSS-only demo data load for NEPA_INNOVATOR (no FSL).
 *
 * Loads: Accounts (5), Program (1), IndividualApplication (1),
 *        ApplicationTimeline (25), nepa_engagement__c (5),
 *        PublicComplaint (3), nepa_litigation__c (2),
 *        nepa_decision_payload__c (1), nepa_ar_export__c (1),
 *        ApplicationTimeline OFD milestones (4)
 *
 * Safe to re-run: all DML is conditional (upsert or existence check).
 *
 * Run via: sf apex run --file demo/import_data/pss_only_load.apex --target-org NEPA_INNOVATOR
 */

// ─── 1. Accounts ─────────────────────────────────────────────────────────────

Map<String, Account> acctByName = new Map<String, Account>();
for (Account a : [
    SELECT Id, Name FROM Account
    WHERE Name IN (
        'BLM Owyhee Field Office',
        'Sam Uhler and David Smith - Carrie Placer Mine',
        'Idaho Conservation League',
        'Office of Species Conservation',
        'Shoshone-Paiute Tribes',
        'U.S. Fish and Wildlife Service',
        'U.S. Army Corps of Engineers'
    )
]) { acctByName.put(a.Name, a); }

List<Account> acctInsert = new List<Account>();
if (!acctByName.containsKey('BLM Owyhee Field Office'))
    acctInsert.add(new Account(Name='BLM Owyhee Field Office', Type='Government',
        BillingStreet='3948 Development Ave', BillingCity='Marsing', BillingState='ID',
        BillingPostalCode='83639', BillingCountry='US', Phone='208-896-5912'));
if (!acctByName.containsKey('Sam Uhler and David Smith - Carrie Placer Mine'))
    acctInsert.add(new Account(Name='Sam Uhler and David Smith - Carrie Placer Mine', Type='Customer',
        BillingCity='Jordan Valley', BillingState='OR', BillingPostalCode='97910'));
if (!acctByName.containsKey('Idaho Conservation League'))
    acctInsert.add(new Account(Name='Idaho Conservation League', Type='Other',
        BillingCity='Boise', BillingState='ID', BillingPostalCode='83701', Phone='208-345-6933'));
if (!acctByName.containsKey('Office of Species Conservation'))
    acctInsert.add(new Account(Name='Office of Species Conservation', Type='Government',
        BillingCity='Boise', BillingState='ID', BillingPostalCode='83720', Phone='208-334-2920'));
if (!acctByName.containsKey('Shoshone-Paiute Tribes'))
    acctInsert.add(new Account(Name='Shoshone-Paiute Tribes', Type='Other',
        BillingCity='Owyhee', BillingState='NV'));
if (!acctByName.containsKey('U.S. Fish and Wildlife Service'))
    acctInsert.add(new Account(Name='U.S. Fish and Wildlife Service', Type='Government',
        BillingCity='Washington', BillingState='DC'));
if (!acctByName.containsKey('U.S. Army Corps of Engineers'))
    acctInsert.add(new Account(Name='U.S. Army Corps of Engineers', Type='Government',
        BillingCity='Washington', BillingState='DC'));
if (!acctInsert.isEmpty()) insert acctInsert;

// Refresh map after insert
for (Account a : [
    SELECT Id, Name FROM Account
    WHERE Name IN (
        'BLM Owyhee Field Office', 'Sam Uhler and David Smith - Carrie Placer Mine',
        'Idaho Conservation League', 'Office of Species Conservation',
        'Shoshone-Paiute Tribes', 'U.S. Fish and Wildlife Service',
        'U.S. Army Corps of Engineers'
    )
]) { acctByName.put(a.Name, a); }

Id blmId      = acctByName.get('BLM Owyhee Field Office').Id;
Id iclId      = acctByName.get('Idaho Conservation League').Id;
Id oscId      = acctByName.get('Office of Species Conservation').Id;
Id tribalId   = acctByName.get('Shoshone-Paiute Tribes').Id;
Id usfwsId    = acctByName.get('U.S. Fish and Wildlife Service').Id;
Id usaceId    = acctByName.get('U.S. Army Corps of Engineers').Id;
System.debug('Accounts ready. BLM=' + blmId);

// ─── 2. Program ──────────────────────────────────────────────────────────────

Id programId;
List<Program> existingProg = [SELECT Id FROM Program WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA' LIMIT 1];
Program prog = existingProg.isEmpty() ? new Program() : existingProg[0];
prog.Name                          = 'Carrie Placer Mine Plan of Operations';
prog.Status                        = 'Active';
prog.StartDate                     = Date.newInstance(2019, 3, 12);
prog.EndDate                       = Date.newInstance(2019, 11, 27);
prog.nepa_project_id__c            = 'DOI-BLM-ID-B030-2019-0014-EA';
prog.nepa_lead_agency__c           = blmId;
prog.nepa_location_text__c         = 'T. 6 S., R. 5 W., Section 28, Jordan Creek watershed, Owyhee County, Idaho';
prog.nepa_primary_sector__c        = 'Agriculture and Natural Resource Management';
prog.nepa_project_type__c          = 'Mineral Extraction - Placer Mining';
prog.nepa_project_description__c   = 'Placer gold mining Plan of Operations on 15 acres of BLM-administered land in T. 6 S. R. 5 W. Section 28 Owyhee County Idaho. Adjacent to Jordan Creek approximately 9 miles southeast of Jordan Valley Oregon.';
prog.nepa_record_owner_agency__c   = 'BLM';
prog.nepa_circuit__c               = '9th';
prog.nepa_location_lat__c          = 42.8701;
prog.nepa_location_lon__c          = -116.9227;
if (existingProg.isEmpty()) { insert prog; } else { update prog; }
programId = prog.Id;
System.debug('Program: ' + programId);

// ─── 3. IndividualApplication ────────────────────────────────────────────────

Id licenseTypeId;
List<RegulatoryAuthorizationType> ratList = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1];
if (ratList.isEmpty()) {
    RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(Name='NEPA Environmental Review', RegulatoryAuthCategory='Permit');
    insert rat;
    licenseTypeId = rat.Id;
} else { licenseTypeId = ratList[0].Id; }

Id appId;
List<IndividualApplication> existingApp = [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1];
IndividualApplication app = existingApp.isEmpty() ? new IndividualApplication() : existingApp[0];
app.LicenseTypeId                           = licenseTypeId;
app.Category                                = 'License';
app.Status                                  = 'Approved';
app.nepa_federal_unique_id__c               = 'IDI-38709';
app.nepa_related_project__c                 = programId;
app.nepa_start_date__c                      = Date.newInstance(2019, 3, 12);
app.nepa_completion_date__c                 = Date.newInstance(2019, 11, 27);
app.nepa_review_type__c                     = 'EA';
app.nepa_review_timeline_type__c            = 'Standard';
app.nepa_action_type__c                     = 'Modify Existing';
app.nepa_agency_id__c                       = 'BLM-ID-B030';
app.nepa_process_status__c                  = 'completed';
app.nepa_process_stage__c                   = 'Decision';
app.nepa_process_code__c                    = 'IDI-38709';
app.nepa_decision_document_type__c          = 'FONSI';
app.nepa_submission_complete__c             = true;
app.nepa_description__c                     = 'Sam Uhler and David Smith propose a 5-10 year placer gold mining operation on 15 acres of BLM-administered land adjacent to Jordan Creek in Owyhee County Idaho.';
app.nepa_purpose_need__c                    = 'Authorize placer gold mining on 15 acres of BLM-administered land in Owyhee County Idaho to provide economic benefit to the proponent consistent with FLPMA multiple-use principles.';
app.nepa_disturbance_acres__c               = 15;
app.nepa_extraordinary_circumstances__c     = 'true';
app.nepa_esa_consultation_status__c         = 'Biological Opinion Issued';
app.nepa_co_permits_required__c             = 'CWA Section 404;NHPA Section 106';
app.nepa_regulatory_citation__c             = '43 CFR Part 46; FLPMA Section 302';
app.nepa_public_comment_period_start__c     = Date.newInstance(2019, 7, 1);
app.nepa_public_comment_period_end_date__c  = Date.newInstance(2019, 7, 28);
app.nepa_target_completion_date__c          = Date.newInstance(2019, 12, 31);
app.nepa_record_owner_agency__c             = 'BLM';
app.nepa_data_source_agency__c              = 'BLM';
app.nepa_data_source_system__c              = 'ePlanning';
app.nepa_data_record_version__c             = '1';
app.nepa_risk_score__c                      = 85;
app.nepa_risk_tier__c                       = 'Very High';
app.nepa_plaintiff_risk_flag__c             = true;
app.nepa_tribal_plaintiff_flag__c           = true;
app.nepa_defensibility_score__c             = 91;
app.nepa_total_pages__c                     = 47;
app.nepa_waiver_invoked__c                  = false;
app.nepa_connected_actions_identified__c    = true;
app.nepa_circuit_court__c                   = '9th Circuit';
app.nepa_project_sector__c                  = 'Mining';
app.nepa_cooperating_agencies__c            = 'USFWS; USACE';
app.nepa_litigation_duration_cost__c        = 0.63;
app.nepa_ec_multi_dod__c                    = false;
app.nepa_ec_usace_czma__c                   = false;
app.nepa_process_outcome__c                 = 'FONSI issued. No significant impact found. CWA 404 and IDWR appropriation permits required prior to ground disturbance.';
if (existingApp.isEmpty()) { insert app; } else { update app; }
appId = app.Id;
System.debug('IndividualApplication: ' + appId);

// ─── 4. ApplicationTimeline (25 milestones) ───────────────────────────────────

Map<String, ApplicationTimeline> existingAT = new Map<String, ApplicationTimeline>();
for (ApplicationTimeline at : [SELECT Id, External_ID__c FROM ApplicationTimeline WHERE nepa_related_process__c = :appId]) {
    if (at.External_ID__c != null) existingAT.put(at.External_ID__c, at);
}

List<ApplicationTimeline> atRecords = new List<ApplicationTimeline>{
    new ApplicationTimeline(External_ID__c='DEMO_AT_001', nepa_related_process__c=appId, Name='Application Received', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2017,10,18), nepa_end_date__c=Date.newInstance(2017,10,18), nepa_status__c='Completed', nepa_tier__c='Process', nepa_outcome__c='IDI-38709 original application received October 18 2017.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_002', nepa_related_process__c=appId, Name='Pre-Application ID Team Consultation Completed', nepa_event_type__c='Scoping Complete', nepa_start_date__c=Date.newInstance(2019,3,12), nepa_end_date__c=Date.newInstance(2019,3,12), nepa_status__c='Completed', nepa_tier__c='Process', nepa_outcome__c='90-minute ID Team scoping session completed. All seven specialists briefed. Six field work orders generated.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_003', nepa_related_process__c=appId, Name='Lek Survey Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,5), nepa_end_date__c=Date.newInstance(2019,4,5), nepa_status__c='Completed', nepa_tier__c='Assessment', nepa_outcome__c='Greater Sage-Grouse lek survey completed within seasonal window. No active lek within 0.6 miles. PHMA confirmed.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_004', nepa_related_process__c=appId, Name='Botanical Survey Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,5,5), nepa_end_date__c=Date.newInstance(2019,6,10), nepa_status__c='Completed', nepa_tier__c='Assessment', nepa_outcome__c='Two-visit botanical survey completed. No sensitive plant species detected in disturbance area.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_005', nepa_related_process__c=appId, Name='Hydrology and Water Quality Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,25), nepa_end_date__c=Date.newInstance(2019,4,25), nepa_status__c='Completed', nepa_tier__c='Assessment', nepa_outcome__c='Hydrology WO closed. IDWR Water Permit Application task auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_006', nepa_related_process__c=appId, Name='Geology and Soils Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,5,12), nepa_end_date__c=Date.newInstance(2019,5,12), nepa_status__c='Completed', nepa_tier__c='Assessment', nepa_outcome__c='Geology WO closed. EPA NPDES NOI IDG370000 task auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_007', nepa_related_process__c=appId, Name='Wildlife Biological Assessment Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,4,30), nepa_end_date__c=Date.newInstance(2019,4,30), nepa_status__c='Completed', nepa_tier__c='Assessment', nepa_outcome__c='Wildlife survey completed at Jordan Creek trailhead. Sage-grouse population data recorded. ESA Section 7 consultation initiated.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_008', nepa_related_process__c=appId, Name='Tribal Consultation Initiated - NHPA Section 106', nepa_event_type__c='Tribal Consultation', nepa_start_date__c=Date.newInstance(2019,2,16), nepa_end_date__c=Date.newInstance(2019,2,16), nepa_status__c='Completed', nepa_tier__c='Consultation', nepa_outcome__c='Government-to-government consultation initiated per NHPA Section 106. Letter sent to Shoshone-Paiute Tribes.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_009', nepa_related_process__c=appId, Name='Tribal Consultation Certified Complete', nepa_event_type__c='Tribal Consultation', nepa_start_date__c=Date.newInstance(2019,3,16), nepa_end_date__c=Date.newInstance(2019,3,16), nepa_status__c='Completed', nepa_tier__c='Consultation', nepa_outcome__c='No historic properties of religious or cultural significance identified. Consultation certified complete.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_010', nepa_related_process__c=appId, Name='Preliminary EA Drafted', nepa_event_type__c='Document Drafted', nepa_start_date__c=Date.newInstance(2019,6,20), nepa_end_date__c=Date.newInstance(2019,6,25), nepa_status__c='Completed', nepa_tier__c='Documentation', nepa_outcome__c='Preliminary EA and unsigned FONSI drafted. 47 pages. Comment period scheduled.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_011', nepa_related_process__c=appId, Name='Public Comment Period Opened', nepa_event_type__c='Comment Period Open', nepa_start_date__c=Date.newInstance(2019,7,1), nepa_end_date__c=Date.newInstance(2019,7,1), nepa_status__c='Completed', nepa_tier__c='Public Engagement', nepa_outcome__c='28-day public comment period opened.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_012', nepa_related_process__c=appId, Name='ICL Comment Received', nepa_event_type__c='Comment Received', nepa_start_date__c=Date.newInstance(2019,7,15), nepa_end_date__c=Date.newInstance(2019,7,15), nepa_status__c='Completed', nepa_tier__c='Comment', nepa_outcome__c='Idaho Conservation League comment received. Litigation threat flag set. Legal work order auto-fired.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_013', nepa_related_process__c=appId, Name='OSC Comment Received', nepa_event_type__c='Comment Received', nepa_start_date__c=Date.newInstance(2019,7,22), nepa_end_date__c=Date.newInstance(2019,7,22), nepa_status__c='Completed', nepa_tier__c='Comment', nepa_outcome__c='Office of Species Conservation comment received. Sage-grouse ARMPA conformance issue raised.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_014', nepa_related_process__c=appId, Name='Shoshone-Paiute Tribes Comment Received', nepa_event_type__c='Comment Received', nepa_start_date__c=Date.newInstance(2019,7,28), nepa_end_date__c=Date.newInstance(2019,7,28), nepa_status__c='Completed', nepa_tier__c='Comment', nepa_outcome__c='Tribal comment received. Section 106 consultation documentation required.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_015', nepa_related_process__c=appId, Name='Public Comment Period Closed', nepa_event_type__c='Comment Period Closed', nepa_start_date__c=Date.newInstance(2019,7,28), nepa_end_date__c=Date.newInstance(2019,7,28), nepa_status__c='Completed', nepa_tier__c='Public Engagement', nepa_outcome__c='Comment period closed. 3 substantive comments received.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_016', nepa_related_process__c=appId, Name='Comment Response Work Orders Closed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,8,12), nepa_end_date__c=Date.newInstance(2019,8,12), nepa_status__c='Completed', nepa_tier__c='Process', nepa_outcome__c='All comment response work orders closed. ICL response finalized. OSC ARMPA conformance addressed. Tribal Section 106 documentation added.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_017', nepa_related_process__c=appId, Name='EA Revised', nepa_event_type__c='Document Revised', nepa_start_date__c=Date.newInstance(2019,8,15), nepa_end_date__c=Date.newInstance(2019,8,15), nepa_status__c='Completed', nepa_tier__c='Documentation', nepa_outcome__c='Revised EA published August 15. Comment close to revised EA: 18 days.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_018', nepa_related_process__c=appId, Name='ESA Section 7 Consultation Complete', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,9,15), nepa_end_date__c=Date.newInstance(2019,9,15), nepa_status__c='Completed', nepa_tier__c='Consultation', nepa_outcome__c='USFWS Biological Opinion issued. No jeopardy finding. Incidental Take Statement included.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_019', nepa_related_process__c=appId, Name='Required Document Registry Completed', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,10,20), nepa_end_date__c=Date.newInstance(2019,10,20), nepa_status__c='Completed', nepa_tier__c='Documentation', nepa_outcome__c='All 5 required documents verified green in Required Document Registry.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_020', nepa_related_process__c=appId, Name='Forrest Griggs (Geologist) Sign-Off', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_status__c='Completed', nepa_tier__c='Sign-Off', nepa_outcome__c='Geologist sign-off recorded.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_021', nepa_related_process__c=appId, Name='Colleen Trese (Wildlife Biologist) Sign-Off', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_status__c='Completed', nepa_tier__c='Sign-Off', nepa_outcome__c='Wildlife Biologist sign-off recorded. Same day as geologist — stage gate fires.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_022', nepa_related_process__c=appId, Name='Decision Stage Gate Cleared', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,20), nepa_end_date__c=Date.newInstance(2019,11,20), nepa_status__c='Completed', nepa_tier__c='Gate', nepa_outcome__c='All 6 stage gates cleared. Record completeness 100%. Decision package ready.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_023', nepa_related_process__c=appId, Name='Field Manager Signs Decision Record', nepa_event_type__c='Decision Record', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_status__c='Completed', nepa_tier__c='Decision', nepa_outcome__c='Field Manager issued FONSI. Decision: Alternative B — Modified Surface Footprint. No significant impact.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_024', nepa_related_process__c=appId, Name='Administrative Record Auto-Generated', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_status__c='Completed', nepa_tier__c='Administrative Record', nepa_outcome__c='Full AR package auto-generated at decision: 6 docs, 3 comments, complete timeline. Locked.'),
    new ApplicationTimeline(External_ID__c='DEMO_AT_025', nepa_related_process__c=appId, Name='Applicant Notified', nepa_event_type__c='Other', nepa_start_date__c=Date.newInstance(2019,11,27), nepa_end_date__c=Date.newInstance(2019,11,27), nepa_status__c='Completed', nepa_tier__c='Process', nepa_outcome__c='Sam Uhler notified of FONSI. Permit conditions and CWA 404/IDWR requirements transmitted.')
};

List<ApplicationTimeline> atInsert = new List<ApplicationTimeline>();
List<ApplicationTimeline> atUpdate = new List<ApplicationTimeline>();
for (ApplicationTimeline at : atRecords) {
    if (existingAT.containsKey(at.External_ID__c)) {
        at.Id = existingAT.get(at.External_ID__c).Id;
        atUpdate.add(at);
    } else { atInsert.add(at); }
}
if (!atInsert.isEmpty()) insert atInsert;
if (!atUpdate.isEmpty()) update atUpdate;
System.debug('ApplicationTimeline inserted=' + atInsert.size() + ' updated=' + atUpdate.size());

// ─── 5. nepa_engagement__c ───────────────────────────────────────────────────

Map<String, nepa_engagement__c> existingEng = new Map<String, nepa_engagement__c>();
for (nepa_engagement__c e : [SELECT Id, External_ID__c FROM nepa_engagement__c WHERE nepa_process__c = :appId]) {
    if (e.External_ID__c != null) existingEng.put(e.External_ID__c, e);
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

// ─── 6. PublicComplaint ──────────────────────────────────────────────────────

Map<String, PublicComplaint> existingPC = new Map<String, PublicComplaint>();
for (PublicComplaint pc : [SELECT Id, External_ID__c FROM PublicComplaint WHERE nepa_related_process__c = :appId]) {
    if (pc.External_ID__c != null) existingPC.put(pc.External_ID__c, pc);
}

// PC_001 and PC_002 (not tribal — no validation rule issue; wire process on insert)
List<PublicComplaint> pcRecords = new List<PublicComplaint>();
if (!existingPC.containsKey('DEMO_PC_001')) {
    pcRecords.add(new PublicComplaint(External_ID__c='DEMO_PC_001',
        Subject='ICL Comment - Suction Dredge NEPA Adequacy', Status='Resolved',
        AccountId=iclId, nepa_related_process__c=appId,
        IncidentDate=Date.newInstance(2019,7,15), IsReporterConfidential=false,
        IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,15),
        nepa_comment_body__c='The Idaho Conservation League urges BLM to conduct a thorough NEPA analysis that specifically addresses the cumulative impacts of suction dredge mining on Jordan Creek salmonid habitat and sage-grouse PHMA designation. ICL reserves the right to pursue legal remedies if the EA fails to meet NEPA adequacy standards.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=true,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='Cumulative Impacts; ESA Section 7',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Opposed',
        nepa_organization__c='Idaho Conservation League', Method_of_Submission__c='Online',
        nepa_litigation_threat_basis__c='ICL v. BLM 9th Cir — prior docket; NEPA adequacy + ESA consultation challenge grounds',
        nepa_legal_review_status__c='Assigned to Counsel'));
}
if (!existingPC.containsKey('DEMO_PC_002')) {
    pcRecords.add(new PublicComplaint(External_ID__c='DEMO_PC_002',
        Subject='OSC Comment - Sage-Grouse ARMPA Conformance', Status='Resolved',
        AccountId=oscId, nepa_related_process__c=appId,
        IncidentDate=Date.newInstance(2019,7,22), IsReporterConfidential=false,
        IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,22),
        nepa_comment_body__c='The Office of Species Conservation requests that BLM document specific conformance with the 2015 Greater Sage-Grouse ARMPA for the Idaho/Southwest Montana Sub-Region. The proposed action area falls within Priority Habitat Management Area. OSC requests the EA include a lek survey with a 4-mile buffer analysis and demonstrate that the project conforms with the ARMPA surface disturbance cap.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=false,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='Sage-Grouse ARMPA Conformance',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Concerned',
        nepa_organization__c='Office of Species Conservation', Method_of_Submission__c='Mail',
        nepa_legal_review_status__c='No Review Required'));
}
if (!pcRecords.isEmpty()) insert pcRecords;

// PC_003: tribal — insert without process lookup, then update to wire it
if (!existingPC.containsKey('DEMO_PC_003')) {
    PublicComplaint pc003 = new PublicComplaint(External_ID__c='DEMO_PC_003',
        Subject='Shoshone-Paiute Tribes - Section 106 Consultation Concerns', Status='Resolved',
        AccountId=tribalId, IncidentDate=Date.newInstance(2019,7,28),
        IsReporterConfidential=false, IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,28),
        nepa_comment_body__c='The Shoshone-Paiute Tribes formally request that BLM document the government-to-government consultation process under NHPA Section 106 and EO 13175. The 1.7-mile access road traverses land with documented traditional cultural properties in the Jordan Creek corridor.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=true,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='NHPA Section 106 - Traditional Cultural Properties; Government-to-Government Consultation',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Opposed',
        nepa_organization__c='Shoshone-Paiute Tribes of the Duck Valley Reservation',
        Method_of_Submission__c='Mail',
        nepa_litigation_threat_basis__c='Tribal Nation plaintiff — 87.5% litigation win rate (PermitTEC corpus); consultation failure is highest-risk grounds for NHPA Section 106 challenge',
        nepa_legal_review_status__c='Assigned to Counsel');
    insert pc003;
    update new PublicComplaint(Id=pc003.Id, nepa_related_process__c=appId);
    System.debug('PublicComplaint DEMO_PC_003 inserted and wired.');
}
System.debug('PublicComplaint done.');

// ─── 7. nepa_litigation__c ───────────────────────────────────────────────────

Map<String, nepa_litigation__c> existingLit = new Map<String, nepa_litigation__c>();
for (nepa_litigation__c l : [SELECT Id, External_ID__c FROM nepa_litigation__c WHERE nepa_related_project__c = :programId]) {
    if (l.External_ID__c != null) existingLit.put(l.External_ID__c, l);
}

List<nepa_litigation__c> litRecords = new List<nepa_litigation__c>{
    new nepa_litigation__c(External_ID__c='DEMO_LIT_001', nepa_related_project__c=programId,
        nepa_case_title__c='Idaho Conservation League v. BLM',
        nepa_circuit__c='9th', nepa_court__c='9th Circuit', nepa_plaintiff__c='Idaho Conservation League',
        nepa_defendant__c='BLM', nepa_prevailing_party__c='Defendant',
        nepa_citation__c='No. 17-35706 (9th Cir. 2018)',
        nepa_contested_project_name__c='Suction Dredge General Permit — Owyhee County',
        nepa_ruling_date__c=Date.newInstance(2018,6,12),
        nepa_llm_keywords__c='suction dredge; NEPA adequacy; cumulative impacts; sage-grouse',
        nepa_data_record_version__c='1', nepa_data_source_system__c='CourtListener'),
    new nepa_litigation__c(External_ID__c='DEMO_LIT_002', nepa_related_project__c=programId,
        nepa_case_title__c='Shoshone-Paiute Tribes v. BLM',
        nepa_circuit__c='9th', nepa_court__c='9th Circuit',
        nepa_plaintiff__c='Shoshone-Paiute Tribes',
        nepa_defendant__c='BLM', nepa_prevailing_party__c='Plaintiff',
        nepa_citation__c='No. 15-35408 (9th Cir. 2016)',
        nepa_contested_project_name__c='Duck Valley Reservation — Water Rights EIS',
        nepa_ruling_date__c=Date.newInstance(2016,9,20),
        nepa_llm_keywords__c='NHPA Section 106; tribal consultation; EO 13175; cultural landscape',
        nepa_data_record_version__c='1', nepa_data_source_system__c='CourtListener')
};

List<nepa_litigation__c> litInsert = new List<nepa_litigation__c>();
List<nepa_litigation__c> litUpdate = new List<nepa_litigation__c>();
for (nepa_litigation__c l : litRecords) {
    if (existingLit.containsKey(l.External_ID__c)) { l.Id = existingLit.get(l.External_ID__c).Id; litUpdate.add(l); }
    else { litInsert.add(l); }
}
if (!litInsert.isEmpty()) insert litInsert;
if (!litUpdate.isEmpty()) update litUpdate;
System.debug('nepa_litigation__c inserted=' + litInsert.size() + ' updated=' + litUpdate.size());

// ─── 8. nepa_decision_payload__c ─────────────────────────────────────────────

List<nepa_decision_payload__c> existingDP = [SELECT Id FROM nepa_decision_payload__c WHERE nepa_process__c = :appId LIMIT 1];
if (existingDP.isEmpty()) {
    insert new nepa_decision_payload__c(
        nepa_process__c=appId, nepa_decision_date__c=Date.newInstance(2019,11,27),
        nepa_selected_alternative__c='Alternative B — Modified Surface Footprint',
        nepa_alternatives_considered__c='3',
        nepa_mitigation_measures__c='Seasonal survey windows enforced; stormwater BMP with twice-annual BLM inspection; full reclamation bond; concurrent IDWR water permit; concurrent EPA NPDES permit',
        nepa_rationale__c='No significant impact; 15-acre surface disturbance within EA review scope; extraordinary circumstances addressed; tribal consultation certified complete; defensibility score 91',
        nepa_significant_impacts__c='false',
        nepa_monitoring_requirements__c='Annual reclamation inspection; stormwater compliance report due March 1; gate access log submitted quarterly',
        nepa_is_supplemental__c=false);
    System.debug('nepa_decision_payload__c inserted.');
} else { System.debug('nepa_decision_payload__c already exists.'); }

// ─── 9. nepa_ar_export__c ─────────────────────────────────────────────────────

List<nepa_ar_export__c> existingAR = [SELECT Id FROM nepa_ar_export__c WHERE nepa_process__c = :appId LIMIT 1];
if (existingAR.isEmpty()) {
    insert new nepa_ar_export__c(
        nepa_process__c=appId, nepa_export_status__c='Complete', nepa_export_type__c='Full Package',
        nepa_requested_date__c=Date.newInstance(2019,11,27),
        nepa_completed_date__c=Date.newInstance(2019,11,27),
        nepa_comment_count__c=3, nepa_document_count__c=6,
        nepa_export_download_url__c='https://placeholder.salesforce.com/ar-manifest/IDI-38709');
    System.debug('nepa_ar_export__c inserted.');
} else { System.debug('nepa_ar_export__c already exists.'); }

// ─── 10. OFD Coordination Milestones ─────────────────────────────────────────

Date baseDate = Date.newInstance(2019, 3, 12);
Map<String, ApplicationTimeline> existingOFD = new Map<String, ApplicationTimeline>();
for (ApplicationTimeline at : [SELECT Id, nepa_event_type__c FROM ApplicationTimeline
    WHERE nepa_related_process__c = :appId AND nepa_ofd_track__c != null]) {
    existingOFD.put(at.nepa_event_type__c, at);
}

List<ApplicationTimeline> ofdRecords = new List<ApplicationTimeline>();
if (!existingOFD.containsKey('Scoping Notice Published'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='NEPA_Lead',
        nepa_event_type__c='Scoping Notice Published', nepa_status__c='Completed',
        nepa_target_date__c=baseDate.addDays(45), nepa_completed_date__c=baseDate.addDays(30),
        Name='OFD: Scoping Notice Published'));
if (!existingOFD.containsKey('ESA Section 7 Initiation'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Agency_Consultation',
        nepa_event_type__c='ESA Section 7 Initiation', nepa_coordinating_agency__c=usfwsId,
        nepa_status__c='In Progress', nepa_target_date__c=baseDate.addDays(90),
        Name='OFD: ESA Section 7 Initiation'));
if (!existingOFD.containsKey('USACE Section 404 Pre-Application Meeting'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Permit_Milestone',
        nepa_event_type__c='USACE Section 404 Pre-Application Meeting', nepa_coordinating_agency__c=usaceId,
        nepa_status__c='Scheduled', nepa_target_date__c=baseDate.addDays(120),
        Name='OFD: USACE Section 404 Pre-Application Meeting'));
if (!existingOFD.containsKey('Record of Decision'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Joint_ROD',
        nepa_event_type__c='Record of Decision', nepa_status__c='Pending',
        nepa_target_date__c=baseDate.addDays(243), Name='OFD: Record of Decision'));
if (!ofdRecords.isEmpty()) insert ofdRecords;
System.debug('OFD milestones inserted: ' + ofdRecords.size());

// ─── 11. Flow refresh ─────────────────────────────────────────────────────────

IndividualApplication refreshApp = [SELECT Id, nepa_review_type__c FROM IndividualApplication WHERE Id = :appId LIMIT 1];
String origType = refreshApp.nepa_review_type__c;
update new IndividualApplication(Id=appId, nepa_review_type__c=(origType == 'EA' ? 'EIS' : 'EA'));
update new IndividualApplication(Id=appId, nepa_review_type__c=origType);
System.debug('Flow refresh complete. nepa_review_type__c restored to ' + origType);

System.debug('PSS-only load complete for IDI-38709.');
