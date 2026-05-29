// Provenance backfill for CEQ Data Standard v1.2 compliance.
// Sets data_record_version, data_source_agency, data_source_system, and record_owner_agency
// on Carrie Placer Mine records (IDI-38709) that pre-date the v1.2 provenance field additions.
// Run after the full demo import sequence is complete.

final String FUID = 'IDI-38709';
final String OWNER_AGENCY = 'Bureau of Land Management';
final String SOURCE_AGENCY = 'Bureau of Land Management';
final String SOURCE_SYSTEM = 'nepadata/samples';
final String DATA_VERSION  = '1.2';
final DateTime NOW = DateTime.now();

// ── Program ───────────────────────────────────────────────────────────────────
List<Program> programs = [
    SELECT Id FROM Program WHERE nepa_project_id__c = 'IDI-38709' LIMIT 1
];
if (!programs.isEmpty()) {
    Program p = programs[0];
    p.nepa_record_owner_agency__c  = OWNER_AGENCY;
    p.nepa_data_source_agency__c   = SOURCE_AGENCY;
    p.nepa_data_source_system__c   = SOURCE_SYSTEM;
    p.nepa_data_record_version__c  = DATA_VERSION;
    p.nepa_retrieved_timestamp__c  = NOW;
    update p;
    System.debug('Program provenance set: ' + p.Id);
}

// ── IndividualApplication ─────────────────────────────────────────────────────
List<IndividualApplication> processes = [
    SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = :FUID LIMIT 1
];
if (!processes.isEmpty()) {
    IndividualApplication ia = processes[0];
    ia.nepa_record_owner_agency__c  = OWNER_AGENCY;
    ia.nepa_data_source_agency__c   = SOURCE_AGENCY;
    ia.nepa_data_source_system__c   = SOURCE_SYSTEM;
    ia.nepa_data_record_version__c  = DATA_VERSION;
    ia.nepa_retrieved_timestamp__c  = NOW;
    update ia;
    System.debug('IndividualApplication provenance set: ' + ia.Id);

    Id processId = ia.Id;

    // ── ContentVersion ────────────────────────────────────────────────────────
    List<ContentVersion> docs = [
        SELECT Id FROM ContentVersion WHERE nepa_process__c = :processId AND IsLatest = true
    ];
    for (ContentVersion cv : docs) {
        cv.nepa_record_owner_agency__c  = OWNER_AGENCY;
        cv.nepa_data_source_agency__c   = SOURCE_AGENCY;
        cv.nepa_data_source_system__c   = SOURCE_SYSTEM;
        cv.nepa_data_record_version__c  = DATA_VERSION;
        cv.nepa_retrieved_timestamp__c  = NOW;
    }
    if (!docs.isEmpty()) {
        update docs;
        System.debug('ContentVersion provenance set: ' + docs.size() + ' records');
    }

    // ── PublicComplaint ───────────────────────────────────────────────────────
    List<PublicComplaint> comments = [
        SELECT Id FROM PublicComplaint WHERE nepa_related_process__c = :processId
    ];
    for (PublicComplaint pc : comments) {
        pc.nepa_record_owner_agency__c  = OWNER_AGENCY;
        pc.nepa_data_source_agency__c   = SOURCE_AGENCY;
        pc.nepa_data_source_system__c   = SOURCE_SYSTEM;
        pc.nepa_data_record_version__c  = DATA_VERSION;
        pc.nepa_retrieved_timestamp__c  = NOW;
    }
    if (!comments.isEmpty()) {
        update comments;
        System.debug('PublicComplaint provenance set: ' + comments.size() + ' records');
    }

    // ── nepa_engagement__c ────────────────────────────────────────────────────
    List<nepa_engagement__c> engagements = [
        SELECT Id FROM nepa_engagement__c WHERE nepa_process__c = :processId
    ];
    for (nepa_engagement__c eng : engagements) {
        eng.nepa_record_owner_agency__c  = OWNER_AGENCY;
        eng.nepa_data_source_agency__c   = SOURCE_AGENCY;
        eng.nepa_data_source_system__c   = SOURCE_SYSTEM;
        eng.nepa_data_record_version__c  = DATA_VERSION;
        eng.nepa_retrieved_timestamp__c  = NOW;
    }
    if (!engagements.isEmpty()) {
        update engagements;
        System.debug('nepa_engagement__c provenance set: ' + engagements.size() + ' records');
    }

    // ── ApplicationTimeline ───────────────────────────────────────────────────
    List<ApplicationTimeline> events = [
        SELECT Id FROM ApplicationTimeline WHERE nepa_related_process__c = :processId
    ];
    for (ApplicationTimeline evt : events) {
        evt.nepa_record_owner_agency__c  = OWNER_AGENCY;
        evt.nepa_data_source_agency__c   = SOURCE_AGENCY;
        evt.nepa_data_source_system__c   = SOURCE_SYSTEM;
        evt.nepa_data_record_version__c  = DATA_VERSION;
        evt.nepa_retrieved_timestamp__c  = NOW;
    }
    if (!events.isEmpty()) {
        update events;
        System.debug('ApplicationTimeline provenance set: ' + events.size() + ' records');
    }
}

System.debug('Provenance backfill complete for ' + FUID);
