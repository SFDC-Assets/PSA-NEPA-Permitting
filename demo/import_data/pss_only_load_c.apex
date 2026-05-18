// PSS-only load -- Part C: PublicComplaint, nepa_litigation__c, nepa_decision_payload__c,
//                          nepa_ar_export__c, OFD milestones, Flow refresh
// Requires Part A to have run first.
// Run: sf apex run --file demo/import_data/pss_only_load_c.apex --target-org NEPA_INNOVATOR

IndividualApplication appRec = [SELECT Id, nepa_related_project__c FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1];
Id appId     = appRec.Id;
Id programId = appRec.nepa_related_project__c;
Id iclId     = [SELECT Id FROM Account WHERE Name = 'Idaho Conservation League' LIMIT 1].Id;
Id oscId     = [SELECT Id FROM Account WHERE Name = 'Office of Species Conservation' LIMIT 1].Id;
Id tribalId  = [SELECT Id FROM Account WHERE Name = 'Shoshone-Paiute Tribes' LIMIT 1].Id;
Id usfwsId   = [SELECT Id FROM Account WHERE Name = 'U.S. Fish and Wildlife Service' LIMIT 1].Id;
Id usaceId   = [SELECT Id FROM Account WHERE Name = 'U.S. Army Corps of Engineers' LIMIT 1].Id;

// 6. PublicComplaint
// Dedup by External_ID__c (records may exist unlinked from prior partial runs)
Map<String, PublicComplaint> existingPC = new Map<String, PublicComplaint>();
for (PublicComplaint pc : [SELECT Id, External_ID__c FROM PublicComplaint
    WHERE External_ID__c IN ('DEMO_PC_001','DEMO_PC_002','DEMO_PC_003')]) {
    existingPC.put(pc.External_ID__c, pc);
}

// All PCs: insert without nepa_related_process__c to bypass NEPA_Comment_Period_Closed VR
// (VR fires on ISNEW() when process is set; second DML update wires the link safely)
List<Id> pcIdsToWire = new List<Id>();

if (!existingPC.containsKey('DEMO_PC_001')) {
    PublicComplaint pc001 = new PublicComplaint(External_ID__c='DEMO_PC_001',
        Subject='ICL Comment - Suction Dredge NEPA Adequacy', Status='Resolved',
        AccountId=iclId, IncidentDate=Date.newInstance(2019,7,15),
        IsReporterConfidential=false, IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,15),
        nepa_comment_body__c='The Idaho Conservation League urges BLM to conduct a thorough NEPA analysis addressing cumulative impacts of suction dredge mining on Jordan Creek salmonid habitat and sage-grouse PHMA. ICL reserves the right to pursue legal remedies if the EA fails to meet NEPA adequacy standards.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=true,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='Cumulative Impacts; ESA Section 7',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Opposed',
        nepa_organization__c='Idaho Conservation League', Method_of_Submission__c='Online',
        nepa_litigation_threat_basis__c='ICL v. BLM 9th Cir - prior docket; NEPA adequacy + ESA consultation challenge grounds',
        nepa_legal_review_status__c='Assigned to Counsel');
    insert pc001;
    pcIdsToWire.add(pc001.Id);
}
if (!existingPC.containsKey('DEMO_PC_002')) {
    PublicComplaint pc002 = new PublicComplaint(External_ID__c='DEMO_PC_002',
        Subject='OSC Comment - Sage-Grouse ARMPA Conformance', Status='Resolved',
        AccountId=oscId, IncidentDate=Date.newInstance(2019,7,22),
        IsReporterConfidential=false, IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,22),
        nepa_comment_body__c='The Office of Species Conservation requests BLM document conformance with the 2015 Greater Sage-Grouse ARMPA for the Idaho/Southwest Montana Sub-Region. The proposed action area falls within Priority Habitat Management Area and requires a lek survey with 4-mile buffer analysis.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=false,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='Sage-Grouse ARMPA Conformance',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Neutral',
        nepa_organization__c='Office of Species Conservation', Method_of_Submission__c='Mail',
        nepa_legal_review_status__c='No Action Required');
    insert pc002;
    pcIdsToWire.add(pc002.Id);
}
if (!existingPC.containsKey('DEMO_PC_003')) {
    PublicComplaint pc003 = new PublicComplaint(External_ID__c='DEMO_PC_003',
        Subject='Shoshone-Paiute Tribes - Section 106 Consultation Concerns', Status='Resolved',
        AccountId=tribalId, IncidentDate=Date.newInstance(2019,7,28),
        IsReporterConfidential=false, IsComplainantAuthorized=true, ShouldInclInRegulatoryRpt=false,
        nepa_date_submitted__c=Date.newInstance(2019,7,28),
        nepa_comment_body__c='The Shoshone-Paiute Tribes formally request BLM document the government-to-government consultation under NHPA Section 106 and EO 13175. The 1.7-mile access road traverses land with traditional cultural properties in the Jordan Creek corridor.',
        nepa_is_substantive__c=true, nepa_litigation_threat_flag__c=true,
        nepa_pii_redacted__c=false, nepa_public_source__c=false,
        nepa_requires_human_review__c=true, nepa_human_override__c=false,
        nepa_category__c='NHPA Section 106 - Traditional Cultural Properties; Government-to-Government Consultation',
        nepa_response_status__c='Finalized', nepa_sentiment__c='Opposed',
        nepa_organization__c='Shoshone-Paiute Tribes of the Duck Valley Reservation',
        Method_of_Submission__c='Mail',
        nepa_litigation_threat_basis__c='Tribal Nation plaintiff - 87.5% litigation win rate (PermitTEC corpus); consultation failure grounds for NHPA Section 106 challenge',
        nepa_legal_review_status__c='Assigned to Counsel');
    insert pc003;
    pcIdsToWire.add(pc003.Id);
}

List<PublicComplaint> wireUpdates = new List<PublicComplaint>();
for (Id pid : pcIdsToWire) wireUpdates.add(new PublicComplaint(Id=pid, nepa_related_process__c=appId));
if (!wireUpdates.isEmpty()) update wireUpdates;
System.debug('PublicComplaint inserted=' + pcIdsToWire.size() + ' wired to process.');

// 7. nepa_litigation__c
Map<String, nepa_litigation__c> existingLit = new Map<String, nepa_litigation__c>();
for (nepa_litigation__c l : [SELECT Id, External_ID__c FROM nepa_litigation__c
    WHERE External_ID__c IN ('DEMO_LIT_001','DEMO_LIT_002')]) {
    existingLit.put(l.External_ID__c, l);
}

List<nepa_litigation__c> litRecords = new List<nepa_litigation__c>{
    new nepa_litigation__c(External_ID__c='DEMO_LIT_001', nepa_related_project__c=programId,
        nepa_case_title__c='Idaho Conservation League v. BLM',
        nepa_circuit__c='9th', nepa_court__c='9th Circuit', nepa_plaintiff__c='Idaho Conservation League',
        nepa_defendant__c='BLM', nepa_prevailing_party__c='Agency',
        nepa_citation__c='No. 17-35706 (9th Cir. 2018)',
        nepa_contested_project_name__c='Suction Dredge General Permit - Owyhee County',
        nepa_ruling_date__c=Date.newInstance(2018,6,12),
        nepa_llm_keywords__c='suction dredge; NEPA adequacy; cumulative impacts; sage-grouse',
        nepa_data_record_version__c='1', nepa_data_source_system__c='CourtListener'),
    new nepa_litigation__c(External_ID__c='DEMO_LIT_002', nepa_related_project__c=programId,
        nepa_case_title__c='Shoshone-Paiute Tribes v. BLM',
        nepa_circuit__c='9th', nepa_court__c='9th Circuit',
        nepa_plaintiff__c='Shoshone-Paiute Tribes',
        nepa_defendant__c='BLM', nepa_prevailing_party__c='Challenger',
        nepa_citation__c='No. 15-35408 (9th Cir. 2016)',
        nepa_contested_project_name__c='Duck Valley Reservation - Water Rights EIS',
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

// 8. nepa_decision_payload__c
List<nepa_decision_payload__c> existingDP = [SELECT Id FROM nepa_decision_payload__c WHERE nepa_process__c = :appId LIMIT 1];
if (existingDP.isEmpty()) {
    insert new nepa_decision_payload__c(
        nepa_process__c=appId, nepa_decision_type__c='FONSI',
        nepa_decision_date__c=Date.newInstance(2019,11,27),
        nepa_selected_alternative__c='Alternative B - Modified Surface Footprint',
        nepa_alternatives_considered__c='3',
        nepa_mitigation_measures__c='Seasonal survey windows enforced; stormwater BMP with twice-annual BLM inspection; full reclamation bond; concurrent IDWR water permit; concurrent EPA NPDES permit',
        nepa_rationale__c='No significant impact; 15-acre surface disturbance within EA review scope; extraordinary circumstances addressed; tribal consultation certified complete; defensibility score 91',
        nepa_significant_impacts__c='false',
        nepa_monitoring_requirements__c='Annual reclamation inspection; stormwater compliance report due March 1; gate access log submitted quarterly',
        nepa_is_supplemental__c=false);
    System.debug('nepa_decision_payload__c inserted.');
} else { System.debug('nepa_decision_payload__c already exists.'); }

// 9. nepa_ar_export__c
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

// 10. OFD Coordination Milestones
Date baseDate = Date.newInstance(2019, 3, 12);
Map<String, ApplicationTimeline> existingOFDByName = new Map<String, ApplicationTimeline>();
for (ApplicationTimeline at : [SELECT Id, Name FROM ApplicationTimeline
    WHERE nepa_related_process__c = :appId AND nepa_ofd_track__c != null]) {
    existingOFDByName.put(at.Name, at);
}

List<ApplicationTimeline> ofdRecords = new List<ApplicationTimeline>();
if (!existingOFDByName.containsKey('OFD: Scoping Notice Published'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='NEPA_Lead',
        nepa_event_type__c='Scoping Open',
        nepa_target_date__c=baseDate.addDays(45), nepa_completed_date__c=baseDate.addDays(30),
        Name='OFD: Scoping Notice Published'));
if (!existingOFDByName.containsKey('OFD: ESA Section 7 Initiation'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Agency_Consultation',
        nepa_event_type__c='Other', nepa_coordinating_agency__c=usfwsId,
        nepa_target_date__c=baseDate.addDays(90),
        Name='OFD: ESA Section 7 Initiation'));
if (!existingOFDByName.containsKey('OFD: USACE Section 404 Pre-Application Meeting'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Permit_Milestone',
        nepa_event_type__c='Permit Issued', nepa_coordinating_agency__c=usaceId,
        nepa_target_date__c=baseDate.addDays(120),
        Name='OFD: USACE Section 404 Pre-Application Meeting'));
if (!existingOFDByName.containsKey('OFD: Record of Decision'))
    ofdRecords.add(new ApplicationTimeline(nepa_related_process__c=appId, nepa_ofd_track__c='Joint_ROD',
        nepa_event_type__c='ROD Issued',
        nepa_target_date__c=baseDate.addDays(243), Name='OFD: Record of Decision'));
if (!ofdRecords.isEmpty()) insert ofdRecords;
System.debug('OFD milestones inserted: ' + ofdRecords.size());

// 11. Flow refresh (toggle nepa_process_stage__c to re-fire IsChanged-gated flows)
// Using stage toggle instead of review_type to avoid climate gate VR
IndividualApplication refreshApp = [SELECT Id, nepa_process_stage__c FROM IndividualApplication WHERE Id = :appId LIMIT 1];
String origStage = refreshApp.nepa_process_stage__c;
try {
    update new IndividualApplication(Id=appId, nepa_process_stage__c='Review');
    update new IndividualApplication(Id=appId, nepa_process_stage__c=origStage);
    System.debug('Flow refresh complete. nepa_process_stage__c restored to ' + origStage);
} catch (Exception ex) {
    System.debug('Flow refresh skipped (VR): ' + ex.getMessage());
}

System.debug('PSS-only load Part C complete for IDI-38709.');
