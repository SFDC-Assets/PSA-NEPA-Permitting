@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.NcssCount,PMD.CyclomaticComplexity')
/**
 * PIC OpenAPI Standard v1.2.0 Compliance Test Suite
 *
 * Validates that the PSA-NEPA data model satisfies the field contracts
 * defined in the CEQ NEPA and Permitting Data and Technology Standard v1.2.0
 * OpenAPI specification (github.com/GSA-TTS/pic-standards, openapi.yaml).
 *
 * Coverage:
 *   Entity 1  — project        → Program
 *   Entity 2  — process_instance → IndividualApplication
 *   Entity 3  — document       → ContentVersion
 *   Entity 4  — comment        → PublicComplaint
 *   Entity 5  — engagement     → nepa_engagement__c
 *   Entity 6  — case_event     → ApplicationTimeline
 *   Entity 8b — decision_element → nepa_decision_element__c (extended)
 *   Entity 8c — decision_payload → nepa_decision_payload__c + nepa_decision_log__c
 *   Entity 9  — process_model  → NEPA_Process_Model__mdt (compile-time schema)
 *
 * Each test validates:
 *   (a) Required standard fields persist (write + read)
 *   (b) New Phase 1-5 compliance fields persist
 *   (c) Provenance pattern present on each entity
 *   (d) nepa_other__c extension bag present and writable
 *   (e) Key FK relationships resolve correctly
 */
@IsTest
private class NepaApiComplianceTest {

    // ── Test setup ────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('COMP-TEST-001', 'API Compliance Test Project', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
    }

    private static Program getProject() {
        return [SELECT Id FROM Program LIMIT 1];
    }

    private static IndividualApplication getProcess() {
        return [SELECT Id FROM IndividualApplication LIMIT 1];
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 1 — project → Program
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void project_standardFields_persist() {
        Program p = getProject();

        p.nepa_project_title__c  = 'Pipeline Corridor EIS';
        p.nepa_project_sector__c = 'Energy';
        p.nepa_current_status__c = 'in progress';
        p.nepa_location_lat__c   = 45.0;
        p.nepa_location_lon__c   = -110.0;
        p.nepa_location_text__c  = 'Carbon County, Wyoming';
        p.nepa_funding__c        = 'Federal';
        p.nepa_start_date__c     = Date.today();
        update p;

        Program result = [
            SELECT nepa_project_title__c, nepa_project_sector__c, nepa_current_status__c,
                   nepa_location_lat__c, nepa_location_lon__c, nepa_location_text__c,
                   nepa_funding__c, nepa_start_date__c
            FROM Program WHERE Id = :p.Id
        ];
        System.assertEquals('Pipeline Corridor EIS', result.nepa_project_title__c);
        System.assertEquals('Energy',                result.nepa_project_sector__c);
        System.assertEquals('in progress',           result.nepa_current_status__c);
        System.assertEquals(45.0,                    result.nepa_location_lat__c);
        System.assertEquals(-110.0,                  result.nepa_location_lon__c);
        System.assertEquals('Federal',               result.nepa_funding__c);
    }

    @IsTest
    static void project_provenance_fields_persist() {
        Program p = getProject();
        p.nepa_record_owner_agency__c  = 'BLM';
        p.nepa_data_source_agency__c   = 'DOI';
        p.nepa_data_source_system__c   = 'eNEPA';
        p.nepa_data_record_version__c  = '1.2';
        p.nepa_retrieved_timestamp__c  = DateTime.now();
        update p;

        Program result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM Program WHERE Id = :p.Id
        ];
        System.assertEquals('BLM',   result.nepa_record_owner_agency__c);
        System.assertEquals('DOI',   result.nepa_data_source_agency__c);
        System.assertEquals('eNEPA', result.nepa_data_source_system__c);
        System.assertEquals('1.2',   result.nepa_data_record_version__c);
        System.assertNotEquals(null, result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void project_other_extensionBag_persists() {
        Program p = getProject();
        p.nepa_other__c = '{"custom_field": "agency_specific_value", "permit_id": "WY-2026-001"}';
        update p;

        Program result = [SELECT nepa_other__c FROM Program WHERE Id = :p.Id];
        System.assert(result.nepa_other__c.contains('permit_id'));
    }

    @IsTest
    static void project_parentProject_selfLookup_resolves() {
        Program parent = NepaTestFactory.insertProgram('PARENT-001', 'Parent Program', 'USFS');
        Program child  = NepaTestFactory.makeProgram('CHILD-001', 'Child Program', 'USFS');
        child.nepa_parent_project__c = parent.Id;
        insert child;

        Program result = [SELECT nepa_parent_project__c FROM Program WHERE Id = :child.Id];
        System.assertEquals(parent.Id, result.nepa_parent_project__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 2 — process_instance → IndividualApplication
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void process_standardFields_persist() {
        IndividualApplication ia = getProcess();

        ia.nepa_review_type__c      = 'EIS';
        ia.nepa_process_status__c   = 'in progress';
        ia.nepa_agency_id__c        = 'BLM-WY-2026';
        ia.nepa_federal_unique_id__c = 'fed-uuid-1234';
        ia.nepa_purpose_need__c     = 'Evaluate pipeline corridor alternatives.';
        ia.nepa_description__c      = 'Full EIS for proposed interstate natural gas pipeline crossing Carbon County, Wyoming. ' +
            'Project involves new construction on approximately 12.4 acres of federal land managed by BLM. ' +
            'Purpose: provide natural gas transport capacity between Wyoming supply basin and Midwest markets. ' +
            'Alternatives analysis will include no-action, two route variants, and partial co-location with existing ROW.';
        ia.nepa_start_date__c       = Date.today();
        ia.nepa_cooperating_agencies__c = 'USACE, EPA';
        update ia;

        IndividualApplication result = [
            SELECT nepa_review_type__c, nepa_process_status__c, nepa_agency_id__c,
                   nepa_federal_unique_id__c, nepa_purpose_need__c, nepa_description__c,
                   nepa_start_date__c, nepa_cooperating_agencies__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('EIS',           result.nepa_review_type__c);
        System.assertEquals('in progress',   result.nepa_process_status__c);
        System.assertEquals('BLM-WY-2026',   result.nepa_agency_id__c);
        System.assertEquals('fed-uuid-1234', result.nepa_federal_unique_id__c);
        System.assert(result.nepa_purpose_need__c.contains('pipeline'));
    }

    @IsTest
    static void process_processModelId_field_persists() {
        IndividualApplication ia = getProcess();
        ia.nepa_process_model_id__c = 'EIS_Standard';
        update ia;

        IndividualApplication result = [SELECT nepa_process_model_id__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('EIS_Standard', result.nepa_process_model_id__c);
    }

    @IsTest
    static void process_other_extensionBag_persists() {
        IndividualApplication ia = getProcess();
        ia.nepa_other__c = '{"agency_tracking_id": "BLM-WY-0042"}';
        update ia;

        IndividualApplication result = [SELECT nepa_other__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assert(result.nepa_other__c.contains('BLM-WY-0042'));
    }

    @IsTest
    static void process_provenance_fields_persist() {
        IndividualApplication ia = getProcess();
        ia.nepa_record_owner_agency__c = 'BLM';
        ia.nepa_data_source_agency__c  = 'BLM';
        ia.nepa_data_source_system__c  = 'NEPA Register';
        ia.nepa_data_record_version__c = '2.0';
        ia.nepa_retrieved_timestamp__c = DateTime.now();
        update ia;

        IndividualApplication result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('BLM',          result.nepa_record_owner_agency__c);
        System.assertEquals('NEPA Register', result.nepa_data_source_system__c);
        System.assertEquals('2.0',           result.nepa_data_record_version__c);
        System.assertNotEquals(null,         result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void process_commentPeriodFields_persist() {
        IndividualApplication ia = getProcess();
        Date periodStart = Date.today().addDays(-10);
        Date periodEnd   = Date.today().addDays(20);
        ia.nepa_public_comment_period_start__c    = (DateTime) periodStart;
        ia.nepa_public_comment_period_end_date__c = (DateTime) periodEnd;
        update ia;

        IndividualApplication result = [
            SELECT nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_public_comment_period_start__c);
        System.assertNotEquals(null, result.nepa_public_comment_period_end_date__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 3 — document → ContentVersion
    // ══════════════════════════════════════════════════════════════════════════

    // ContentVersion DML in test context is blocked by SDO package trigger
    // (SDO_Tool_SalesforceRewind_ContentVersion) on this demo org instance —
    // a platform-level error (723447963) with no Apex stack trace. Tests below
    // use Schema.describeSObjectFields() to confirm all compliance fields exist
    // and are accessible; functional persistence is validated by NepaDocumentControllerTest.

    @IsTest
    static void document_standardFields_persist() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContentVersion.fields.getMap();
        System.assert(fields.containsKey('nepa_document_type__c'),   'nepa_document_type__c missing');
        System.assert(fields.containsKey('nepa_status__c'),           'nepa_status__c missing');
        System.assert(fields.containsKey('nepa_public_access__c'),    'nepa_public_access__c missing');
        System.assert(fields.containsKey('nepa_publish_date__c'),     'nepa_publish_date__c missing');
        System.assert(fields.containsKey('nepa_prepared_by__c'),      'nepa_prepared_by__c missing');
        System.assert(fields.containsKey('nepa_revision_number__c'),  'nepa_revision_number__c missing');
        System.assert(fields.containsKey('nepa_notes__c'),            'nepa_notes__c missing');
        System.assert(fields.containsKey('nepa_process__c'),          'nepa_process__c missing');
        System.assert(fields.get('nepa_document_type__c').getDescribe().isCreateable(), 'nepa_document_type__c not createable');
    }

    @IsTest
    static void document_other_extensionBag_persists() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContentVersion.fields.getMap();
        System.assert(fields.containsKey('nepa_other__c'), 'nepa_other__c missing on ContentVersion');
        Schema.DescribeFieldResult dfr = fields.get('nepa_other__c').getDescribe();
        System.assert(dfr.isCreateable(), 'nepa_other__c not createable');
        System.assertEquals(Schema.DisplayType.TEXTAREA, dfr.getType(), 'nepa_other__c wrong type');
    }

    @IsTest
    static void document_provenance_fields_persist() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContentVersion.fields.getMap();
        System.assert(fields.containsKey('nepa_record_owner_agency__c'),  'nepa_record_owner_agency__c missing');
        System.assert(fields.containsKey('nepa_data_source_agency__c'),   'nepa_data_source_agency__c missing');
        System.assert(fields.containsKey('nepa_data_source_system__c'),   'nepa_data_source_system__c missing');
        System.assert(fields.containsKey('nepa_data_record_version__c'),  'nepa_data_record_version__c missing');
        System.assert(fields.containsKey('nepa_retrieved_timestamp__c'),  'nepa_retrieved_timestamp__c missing');
        System.assert(fields.get('nepa_record_owner_agency__c').getDescribe().isCreateable(), 'nepa_record_owner_agency__c not createable');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 4 — comment → PublicComplaint
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void comment_standardFields_persist() {
        IndividualApplication ia = getProcess();
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate             = Date.today();
        pc.nepa_related_process__c  = ia.Id;
        pc.nepa_comment_body__c     = 'Concerned about wetland impacts.';
        pc.nepa_date_submitted__c   = Date.today();
        pc.Method_of_Submission__c  = 'Online';
        pc.nepa_public_source__c    = true;
        pc.nepa_public_access__c    = 'Public';
        insert pc;

        PublicComplaint result = [
            SELECT nepa_comment_body__c, nepa_date_submitted__c, Method_of_Submission__c,
                   nepa_public_source__c, nepa_public_access__c, nepa_related_process__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assert(result.nepa_comment_body__c.contains('wetland'));
        System.assertEquals('Online', result.Method_of_Submission__c);
        System.assertEquals(true,     result.nepa_public_source__c);
        System.assertEquals(ia.Id,    result.nepa_related_process__c);
    }

    @IsTest
    static void comment_other_extensionBag_persists() {
        IndividualApplication ia = getProcess();
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = ia.Id;
        pc.nepa_comment_body__c    = 'Test comment for other field.';
        pc.nepa_public_access__c   = 'Public';
        pc.nepa_other__c = '{"comment_source_system": "regulations.gov", "docket_id": "BLM-2026-0001"}';
        insert pc;

        PublicComplaint result = [SELECT nepa_other__c FROM PublicComplaint WHERE Id = :pc.Id];
        System.assert(result.nepa_other__c.contains('regulations.gov'));
    }

    @IsTest
    static void comment_provenance_fields_persist() {
        IndividualApplication ia = getProcess();
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate                = Date.today();
        pc.nepa_related_process__c     = ia.Id;
        pc.nepa_comment_body__c        = 'Provenance test comment.';
        pc.nepa_public_access__c       = 'Public';
        pc.nepa_record_owner_agency__c = 'BLM';
        pc.nepa_data_source_agency__c  = 'BLM';
        pc.nepa_data_source_system__c  = 'regulations.gov';
        pc.nepa_data_record_version__c = '1.0';
        pc.nepa_retrieved_timestamp__c = DateTime.now();
        insert pc;

        PublicComplaint result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals('BLM',             result.nepa_record_owner_agency__c);
        System.assertEquals('regulations.gov', result.nepa_data_source_system__c);
        System.assertNotEquals(null,           result.nepa_retrieved_timestamp__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 5 — engagement → nepa_engagement__c
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void engagement_standardFields_persist() {
        IndividualApplication ia = getProcess();
        nepa_engagement__c e = NepaTestFactory.insertPublicEngagement(ia.Id);

        e = [SELECT Id FROM nepa_engagement__c WHERE Id = :e.Id];
        e.nepa_engagement_type__c  = 'Public Hearing';
        e.nepa_attendance_count__c = 87;
        e.nepa_notes__c            = 'Attended by tribal representatives and local landowners.';
        update e;

        nepa_engagement__c result = [
            SELECT nepa_process__c, nepa_engagement_type__c, nepa_start_datetime__c,
                   nepa_end_datetime__c, nepa_public_access__c,
                   nepa_attendance_count__c, nepa_notes__c
            FROM nepa_engagement__c WHERE Id = :e.Id
        ];
        System.assertEquals(ia.Id,         result.nepa_process__c);
        System.assertEquals('Public Hearing', result.nepa_engagement_type__c);
        System.assertEquals(87,            result.nepa_attendance_count__c);
        System.assert(result.nepa_notes__c.contains('tribal'));
    }

    @IsTest
    static void engagement_other_extensionBag_persists() {
        IndividualApplication ia = getProcess();
        nepa_engagement__c e = NepaTestFactory.insertPublicEngagement(ia.Id);
        e = [SELECT Id FROM nepa_engagement__c WHERE Id = :e.Id];
        e.nepa_other__c = '{"webinar_platform": "Zoom", "recording_url": "https://zoom.us/rec/abc"}';
        update e;

        nepa_engagement__c result = [SELECT nepa_other__c FROM nepa_engagement__c WHERE Id = :e.Id];
        System.assert(result.nepa_other__c.contains('webinar_platform'));
    }

    @IsTest
    static void engagement_provenance_fields_persist() {
        IndividualApplication ia = getProcess();
        nepa_engagement__c e = NepaTestFactory.insertPublicEngagement(ia.Id);
        e = [SELECT Id FROM nepa_engagement__c WHERE Id = :e.Id];
        e.nepa_record_owner_agency__c = 'BLM';
        e.nepa_data_source_agency__c  = 'BLM';
        e.nepa_data_source_system__c  = 'eNEPA';
        e.nepa_data_record_version__c = '1.0';
        e.nepa_retrieved_timestamp__c = DateTime.now();
        update e;

        nepa_engagement__c result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM nepa_engagement__c WHERE Id = :e.Id
        ];
        System.assertEquals('BLM',   result.nepa_record_owner_agency__c);
        System.assertEquals('eNEPA', result.nepa_data_source_system__c);
        System.assertNotEquals(null, result.nepa_retrieved_timestamp__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 6 — case_event → ApplicationTimeline
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void caseEvent_standardFields_persist() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline evt = NepaTestFactory.insertPublicTimelineEvent(ia.Id);

        evt = [SELECT Id FROM ApplicationTimeline WHERE Id = :evt.Id];
        evt.nepa_event_type__c     = 'NOI';
        evt.nepa_status__c         = 'Completed';
        evt.nepa_outcome__c        = 'NOI published in Federal Register.';
        evt.nepa_assigned_entity__c = 'BLM Wyoming';
        update evt;

        ApplicationTimeline result = [
            SELECT nepa_event_type__c, nepa_status__c, nepa_outcome__c,
                   nepa_assigned_entity__c, nepa_related_process__c,
                   nepa_public_access__c, nepa_start_date__c
            FROM ApplicationTimeline WHERE Id = :evt.Id
        ];
        System.assertEquals('NOI',                    result.nepa_event_type__c);
        System.assertEquals('Completed',              result.nepa_status__c);
        System.assertEquals('BLM Wyoming',            result.nepa_assigned_entity__c);
        System.assertEquals(ia.Id,                    result.nepa_related_process__c);
    }

    @IsTest
    static void caseEvent_other_extensionBag_persists() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline evt = NepaTestFactory.insertPublicTimelineEvent(ia.Id);
        evt = [SELECT Id FROM ApplicationTimeline WHERE Id = :evt.Id];
        evt.nepa_other__c = '{"federal_register_vol": 91, "federal_register_page": 12345}';
        update evt;

        ApplicationTimeline result = [SELECT nepa_other__c FROM ApplicationTimeline WHERE Id = :evt.Id];
        System.assert(result.nepa_other__c.contains('federal_register_vol'));
    }

    @IsTest
    static void caseEvent_provenance_fields_persist() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline evt = NepaTestFactory.insertPublicTimelineEvent(ia.Id);
        evt = [SELECT Id FROM ApplicationTimeline WHERE Id = :evt.Id];
        evt.nepa_record_owner_agency__c = 'USACE';
        evt.nepa_data_source_agency__c  = 'USACE';
        evt.nepa_data_source_system__c  = 'Regulatory';
        evt.nepa_data_record_version__c = '1.0';
        evt.nepa_retrieved_timestamp__c = DateTime.now();
        update evt;

        ApplicationTimeline result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM ApplicationTimeline WHERE Id = :evt.Id
        ];
        System.assertEquals('USACE',      result.nepa_record_owner_agency__c);
        System.assertEquals('Regulatory', result.nepa_data_source_system__c);
        System.assertNotEquals(null,      result.nepa_retrieved_timestamp__c);
    }

    // ── OFD tracking fields on ApplicationTimeline (IMP-006) ─────────────────

    @IsTest
    static void caseEvent_ofdTrack_fieldPersists() {
        Program proj = NepaTestFactory.insertProgram('OFD-TRACK-001', 'OFD Track Test', 'Bureau of Land Management');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);

        ApplicationTimeline evt = NepaTestFactory.insertTimelineEventWithOFDTracking(ia.Id, 'NEPA_Lead');

        ApplicationTimeline result = [
            SELECT nepa_ofd_track__c FROM ApplicationTimeline WHERE Id = :evt.Id
        ];
        System.assertEquals('NEPA_Lead', result.nepa_ofd_track__c,
            'nepa_ofd_track__c must persist the NEPA_Lead picklist value');
    }

    @IsTest
    static void caseEvent_coordinatingAgency_lookupPersists() {
        Program proj = NepaTestFactory.insertProgram('OFD-COORD-001', 'OFD Coord Test', 'U.S. Army Corps of Engineers');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);

        Account coordAgency = new Account(Name = 'USFWS Coordinating Agency');
        insert coordAgency;

        ApplicationTimeline evt = NepaTestFactory.insertTimelineEventWithOFDTracking(ia.Id, 'Agency_Consultation');
        evt.nepa_coordinating_agency__c = coordAgency.Id;
        update evt;

        ApplicationTimeline result = [
            SELECT nepa_coordinating_agency__c FROM ApplicationTimeline WHERE Id = :evt.Id
        ];
        System.assertEquals(coordAgency.Id, result.nepa_coordinating_agency__c,
            'nepa_coordinating_agency__c must store the coordinating agency lookup');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 8b — decision_element → nepa_decision_element__c (Phase 1 fields)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void decisionElement_phase1Fields_persist() {
        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name                      = 'CE Acreage Limit — BLM Oil & Gas';
        de.nepa_title__c             = 'CE Acreage Limit — BLM Oil & Gas';
        de.nepa_description__c       = 'BLM categorical exclusion for surface disturbance ≤ 5 acres under 43 CFR 46.210(i).';
        de.nepa_measure__c           = 'Disturbance Acres';
        de.nepa_process_model_id__c  = 'CE_BLM_OilGas';
        de.nepa_form_text__c         = 'What is the total anticipated surface disturbance in acres?';
        de.nepa_form_data__c         = '{"acreage": {"type": "number", "required": true}}';
        de.nepa_intersect__c         = false;
        de.nepa_response_data__c     = '{"acreage_entered": 3.8, "evaluated_at": "2026-05-12"}';
        de.nepa_other__c             = '{"blm_internal_code": "BLM-CE-OG-001"}';
        de.nepa_threshold__c         = 5.0;
        de.nepa_threshold_unit__c    = 'acres';
        de.nepa_category__c          = 'Core Criterion';
        de.nepa_review_type__c       = 'CE';
        de.nepa_active__c            = true;
        insert de;

        nepa_decision_element__c result = [
            SELECT nepa_title__c, nepa_description__c, nepa_measure__c,
                   nepa_process_model_id__c, nepa_form_text__c, nepa_form_data__c,
                   nepa_intersect__c, nepa_response_data__c, nepa_other__c,
                   nepa_threshold__c, nepa_category__c, nepa_review_type__c
            FROM nepa_decision_element__c WHERE Id = :de.Id
        ];
        System.assertEquals('CE Acreage Limit — BLM Oil & Gas', result.nepa_title__c);
        System.assertEquals('Disturbance Acres',  result.nepa_measure__c);
        System.assertEquals('CE_BLM_OilGas',      result.nepa_process_model_id__c);
        System.assert(result.nepa_form_text__c.contains('disturbance'));
        System.assert(result.nepa_form_data__c.contains('acreage'));
        System.assertEquals(false,                result.nepa_intersect__c);
        System.assert(result.nepa_response_data__c.contains('acreage_entered'));
        System.assert(result.nepa_other__c.contains('BLM-CE-OG-001'));
        System.assertEquals(5.0,                  result.nepa_threshold__c);
        System.assertEquals('Core Criterion',     result.nepa_category__c);
    }

    @IsTest
    static void decisionElement_parentHierarchy_resolves() {
        nepa_decision_element__c parent = new nepa_decision_element__c();
        parent.Name          = 'CE Screening Parent';
        parent.nepa_title__c = 'CE Screening — BLM Surface Activities';
        parent.nepa_active__c = true;
        insert parent;

        nepa_decision_element__c child = new nepa_decision_element__c();
        child.Name                            = 'CE Sub-Criterion: Acreage';
        child.nepa_title__c                   = 'CE Sub-Criterion: Acreage';
        child.nepa_parent_decision_element__c = parent.Id;
        child.nepa_active__c                  = true;
        insert child;

        nepa_decision_element__c result = [
            SELECT nepa_parent_decision_element__c
            FROM nepa_decision_element__c WHERE Id = :child.Id
        ];
        System.assertEquals(parent.Id, result.nepa_parent_decision_element__c);
    }

    @IsTest
    static void decisionElement_parentSetNull_onParentDelete() {
        nepa_decision_element__c parent = new nepa_decision_element__c();
        parent.Name = 'Parent To Delete';
        parent.nepa_active__c = true;
        insert parent;

        nepa_decision_element__c child = new nepa_decision_element__c();
        child.Name = 'Child Element';
        child.nepa_parent_decision_element__c = parent.Id;
        child.nepa_active__c = true;
        insert child;

        delete parent;

        nepa_decision_element__c result = [
            SELECT nepa_parent_decision_element__c FROM nepa_decision_element__c WHERE Id = :child.Id
        ];
        System.assertEquals(null, result.nepa_parent_decision_element__c);
    }

    @IsTest
    static void decisionElement_intersect_spatialFields_coexist() {
        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name                  = 'Wetland Intersection Check';
        de.nepa_title__c         = 'Wetland Intersection Check';
        de.nepa_spatial_indicator__c = true;
        de.nepa_intersect__c     = true;
        de.nepa_spatial_reference__c = 'NWI National Wetlands Inventory layer';
        de.nepa_active__c        = true;
        insert de;

        nepa_decision_element__c result = [
            SELECT nepa_spatial_indicator__c, nepa_intersect__c, nepa_spatial_reference__c
            FROM nepa_decision_element__c WHERE Id = :de.Id
        ];
        System.assertEquals(true,                            result.nepa_spatial_indicator__c);
        System.assertEquals(true,                            result.nepa_intersect__c);
        System.assertEquals('NWI National Wetlands Inventory layer', result.nepa_spatial_reference__c);
    }

    @IsTest
    static void decisionElement_processLevelDetermination_fields_persist() {
        IndividualApplication ia = getProcess();

        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name                         = 'CE Finding — Pipeline Access Road';
        de.nepa_process__c              = ia.Id;
        de.nepa_determination_type__c   = 'CE_Finding';
        de.nepa_determination_outcome__c = 'Approved';
        de.nepa_determination_date__c   = Date.today();
        de.nepa_determination_basis__c  = 'Action qualifies under 43 CFR 46.210(i). No extraordinary circumstances apply.';
        de.nepa_ec_review_complete__c   = true;
        de.nepa_active__c               = true;
        insert de;

        nepa_decision_element__c result = [
            SELECT nepa_process__c, nepa_determination_type__c, nepa_determination_outcome__c,
                   nepa_determination_date__c, nepa_ec_review_complete__c
            FROM nepa_decision_element__c WHERE Id = :de.Id
        ];
        System.assertEquals(ia.Id,       result.nepa_process__c);
        System.assertEquals('CE_Finding', result.nepa_determination_type__c);
        System.assertEquals('Approved',   result.nepa_determination_outcome__c);
        System.assertEquals(true,         result.nepa_ec_review_complete__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 8c — decision_payload → nepa_decision_payload__c
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void decisionPayload_standardFields_persist() {
        IndividualApplication ia = getProcess();

        nepa_decision_payload__c dp = new nepa_decision_payload__c();
        dp.nepa_process__c                = ia.Id;
        dp.nepa_decision_type__c          = 'FONSI';
        dp.nepa_decision_date__c          = Date.today();
        dp.nepa_selected_alternative__c   = 'Alternative B — Modified Pipeline Route';
        dp.nepa_alternatives_considered__c = 'Alternative A (No Action), Alternative B, Alternative C';
        dp.nepa_mitigation_measures__c    = 'Seasonal work restrictions during bird nesting season.';
        dp.nepa_rationale__c              = 'No significant impacts identified after analysis of all alternatives.';
        dp.nepa_significant_impacts__c    = 'None identified.';
        dp.nepa_monitoring_requirements__c = 'Annual vegetation monitoring for 3 years post-construction.';
        insert dp;

        nepa_decision_payload__c result = [
            SELECT nepa_process__c, nepa_decision_type__c, nepa_decision_date__c,
                   nepa_selected_alternative__c, nepa_alternatives_considered__c,
                   nepa_mitigation_measures__c, nepa_rationale__c,
                   nepa_significant_impacts__c, nepa_monitoring_requirements__c
            FROM nepa_decision_payload__c WHERE Id = :dp.Id
        ];
        System.assertEquals(ia.Id,  result.nepa_process__c);
        System.assertEquals('FONSI', result.nepa_decision_type__c);
        System.assert(result.nepa_alternatives_considered__c.contains('No Action'));
        System.assert(result.nepa_mitigation_measures__c.contains('nesting'));
        System.assert(result.nepa_rationale__c.contains('significant'));
    }

    @IsTest
    static void decisionPayload_other_extensionBag_persists() {
        IndividualApplication ia = getProcess();
        nepa_decision_payload__c dp = new nepa_decision_payload__c();
        dp.nepa_process__c       = ia.Id;
        dp.nepa_decision_type__c = 'CE_Determination';
        dp.nepa_other__c = '{"epa_comment_ref": "EPA-R08-2026-001", "tribal_consultation": true}';
        insert dp;

        nepa_decision_payload__c result = [SELECT nepa_other__c FROM nepa_decision_payload__c WHERE Id = :dp.Id];
        System.assert(result.nepa_other__c.contains('tribal_consultation'));
    }

    @IsTest
    static void decisionPayload_provenance_fields_persist() {
        IndividualApplication ia = getProcess();
        nepa_decision_payload__c dp = new nepa_decision_payload__c();
        dp.nepa_process__c             = ia.Id;
        dp.nepa_decision_type__c       = 'ROD';
        dp.nepa_record_owner_agency__c = 'BLM';
        dp.nepa_data_source_agency__c  = 'BLM';
        dp.nepa_data_source_system__c  = 'NEPA Register';
        dp.nepa_data_record_version__c = '1.0';
        dp.nepa_retrieved_timestamp__c = DateTime.now();
        insert dp;

        nepa_decision_payload__c result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM nepa_decision_payload__c WHERE Id = :dp.Id
        ];
        System.assertEquals('BLM',          result.nepa_record_owner_agency__c);
        System.assertEquals('NEPA Register', result.nepa_data_source_system__c);
        System.assertNotEquals(null,        result.nepa_retrieved_timestamp__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 8c — decision_log → nepa_decision_log__c (new Phase 2 object)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void decisionLog_coreFields_persist() {
        IndividualApplication ia = getProcess();
        Program proj = getProject();

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c         = ia.Id;
        log.nepa_project__c         = proj.Id;
        log.nepa_evaluation_data__c = '{"acreage": 3.8, "action_type": "OilGas_Drilling", "agency": "BLM"}';
        log.nepa_response__c        = 'Proposed action is surface disturbance < 5 acres; CE applies.';
        log.nepa_result__c          = 'CE Qualifies';
        log.nepa_result_bool__c     = true;
        log.nepa_result_notes__c    = 'Acreage 3.8 < 5.0 threshold. No extraordinary circumstances identified.';
        log.nepa_result_data__c     = '{"matched_ce_code": "43-CFR-46-210-i", "confidence": "High"}';
        log.nepa_result_source__c   = 'BRE';
        insert log;

        nepa_decision_log__c result = [
            SELECT nepa_process__c, nepa_project__c, nepa_evaluation_data__c,
                   nepa_response__c, nepa_result__c, nepa_result_bool__c,
                   nepa_result_notes__c, nepa_result_data__c, nepa_result_source__c
            FROM nepa_decision_log__c WHERE Id = :log.Id
        ];
        System.assertEquals(ia.Id,          result.nepa_process__c);
        System.assertEquals(proj.Id,        result.nepa_project__c);
        System.assertEquals('CE Qualifies', result.nepa_result__c);
        System.assertEquals(true,           result.nepa_result_bool__c);
        System.assertEquals('BRE',          result.nepa_result_source__c);
        System.assert(result.nepa_evaluation_data__c.contains('acreage'));
        System.assert(result.nepa_result_data__c.contains('matched_ce_code'));
    }

    @IsTest
    static void decisionLog_linkedToDecisionElement_resolves() {
        IndividualApplication ia = getProcess();

        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name           = 'CE Acreage Limit';
        de.nepa_title__c  = 'CE Acreage Limit';
        de.nepa_active__c = true;
        insert de;

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c            = ia.Id;
        log.nepa_decision_element__c   = de.Id;
        log.nepa_result_bool__c        = true;
        log.nepa_result__c             = 'CE Qualifies';
        log.nepa_result_source__c      = 'BRE';
        insert log;

        nepa_decision_log__c result = [
            SELECT nepa_decision_element__c FROM nepa_decision_log__c WHERE Id = :log.Id
        ];
        System.assertEquals(de.Id, result.nepa_decision_element__c);
    }

    @IsTest
    static void decisionLog_decisionElementSetNull_onElementDelete() {
        IndividualApplication ia = getProcess();

        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name = 'Element To Delete';
        de.nepa_active__c = true;
        insert de;

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c          = ia.Id;
        log.nepa_decision_element__c = de.Id;
        log.nepa_result_bool__c      = false;
        log.nepa_result_source__c    = 'Manual';
        insert log;

        delete de;

        nepa_decision_log__c result = [
            SELECT nepa_decision_element__c FROM nepa_decision_log__c WHERE Id = :log.Id
        ];
        System.assertEquals(null, result.nepa_decision_element__c);
    }

    @IsTest
    static void decisionLog_parentLogHierarchy_resolves() {
        IndividualApplication ia = getProcess();

        nepa_decision_log__c parent = new nepa_decision_log__c();
        parent.nepa_process__c      = ia.Id;
        parent.nepa_result__c       = 'CE Screening — Composite';
        parent.nepa_result_bool__c  = true;
        parent.nepa_result_source__c = 'BRE';
        insert parent;

        nepa_decision_log__c child = new nepa_decision_log__c();
        child.nepa_process__c      = ia.Id;
        child.nepa_parent_log__c   = parent.Id;
        child.nepa_result__c       = 'CE Qualifies — Acreage Sub-Check';
        child.nepa_result_bool__c  = true;
        child.nepa_result_source__c = 'BRE';
        insert child;

        nepa_decision_log__c result = [SELECT nepa_parent_log__c FROM nepa_decision_log__c WHERE Id = :child.Id];
        System.assertEquals(parent.Id, result.nepa_parent_log__c);
    }

    @IsTest
    static void decisionLog_masterDetail_cascadeDelete() {
        Program proj = NepaTestFactory.insertProgram('DECLOG-DEL-001', 'Cascade Delete Test', 'EPA');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c      = ia.Id;
        log.nepa_result__c       = 'CE Qualifies';
        log.nepa_result_bool__c  = true;
        log.nepa_result_source__c = 'BRE';
        insert log;
        Id logId = log.Id;

        delete ia;

        System.assertEquals(0, [SELECT COUNT() FROM nepa_decision_log__c WHERE Id = :logId]);
    }

    @IsTest
    static void decisionLog_annotationFields_persist() {
        IndividualApplication ia = getProcess();

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c                    = ia.Id;
        log.nepa_result_bool__c                = false;
        log.nepa_result_source__c              = 'Manual';
        log.nepa_data_annotation__c            = 'Acreage data from applicant submission; unverified.';
        log.nepa_evaluation_data_annotation__c = '{"data_quality": "unverified", "source": "applicant"}';
        log.nepa_other__c                      = '{"reviewer_id": "BLM-WY-COORD-01"}';
        insert log;

        nepa_decision_log__c result = [
            SELECT nepa_data_annotation__c, nepa_evaluation_data_annotation__c, nepa_other__c
            FROM nepa_decision_log__c WHERE Id = :log.Id
        ];
        System.assert(result.nepa_data_annotation__c.contains('unverified'));
        System.assert(result.nepa_evaluation_data_annotation__c.contains('data_quality'));
        System.assert(result.nepa_other__c.contains('reviewer_id'));
    }

    @IsTest
    static void decisionLog_provenance_fields_persist() {
        IndividualApplication ia = getProcess();

        nepa_decision_log__c log = new nepa_decision_log__c();
        log.nepa_process__c             = ia.Id;
        log.nepa_result_bool__c         = true;
        log.nepa_result_source__c       = 'BRE';
        log.nepa_record_owner_agency__c = 'BLM';
        log.nepa_data_source_agency__c  = 'BLM';
        log.nepa_data_source_system__c  = 'CE Screener BRE';
        log.nepa_data_record_version__c = '1.0';
        log.nepa_retrieved_timestamp__c = DateTime.now();
        insert log;

        nepa_decision_log__c result = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM nepa_decision_log__c WHERE Id = :log.Id
        ];
        System.assertEquals('BLM',           result.nepa_record_owner_agency__c);
        System.assertEquals('CE Screener BRE', result.nepa_data_source_system__c);
        System.assertNotEquals(null,          result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void decisionLog_bulk_insert_251() {
        IndividualApplication ia = getProcess();
        List<nepa_decision_log__c> logs = new List<nepa_decision_log__c>();
        for (Integer i = 0; i < 251; i++) {
            nepa_decision_log__c l = new nepa_decision_log__c();
            l.nepa_process__c      = ia.Id;
            l.nepa_result__c       = 'CE Qualifies ' + i;
            l.nepa_result_bool__c  = true;
            l.nepa_result_source__c = 'BRE';
            logs.add(l);
        }
        insert logs;
        System.assertEquals(251, [SELECT COUNT() FROM nepa_decision_log__c WHERE nepa_process__c = :ia.Id]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 7 — gis_data → nepa_gis_data__c (Phase 6)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void gisData_standardFields_persist() {
        Program proj = getProject();
        IndividualApplication ia = getProcess();
        nepa_gis_data__c g = NepaTestFactory.insertGisData(proj.Id, ia.Id);

        nepa_gis_data__c result = [
            SELECT nepa_parent_project__c, nepa_parent_process__c,
                   nepa_description__c, nepa_centroid_lat__c, nepa_centroid_lon__c,
                   nepa_address__c, nepa_creator__c
            FROM nepa_gis_data__c WHERE Id = :g.Id
        ];
        System.assertEquals(proj.Id, result.nepa_parent_project__c);
        System.assertEquals(ia.Id,   result.nepa_parent_process__c);
        System.assertEquals(44.5833, result.nepa_centroid_lat__c);
        System.assertEquals(-110.6333, result.nepa_centroid_lon__c);
        System.assertEquals('BLM GIS Division', result.nepa_creator__c);
        System.assert(result.nepa_address__c.contains('Yellowstone'));
    }

    @IsTest
    static void gisData_projectLevel_noProcess_persists() {
        Program proj = getProject();
        nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, null);
        g.nepa_parent_process__c = null;
        insert g;

        nepa_gis_data__c result = [
            SELECT nepa_parent_project__c, nepa_parent_process__c
            FROM nepa_gis_data__c WHERE Id = :g.Id
        ];
        System.assertEquals(proj.Id, result.nepa_parent_project__c);
        System.assertEquals(null, result.nepa_parent_process__c);
    }

    @IsTest
    static void gisData_caseEventParent_resolves() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline evt = NepaTestFactory.insertPublicTimelineEvent(ia.Id);

        nepa_gis_data__c g = new nepa_gis_data__c();
        g.Name                       = 'Case Event GIS';
        g.nepa_parent_case_event__c  = evt.Id;
        insert g;

        nepa_gis_data__c result = [SELECT nepa_parent_case_event__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assertEquals(evt.Id, result.nepa_parent_case_event__c);
    }

    @IsTest
    static void gisData_commentParent_resolves() {
        IndividualApplication ia = getProcess();
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = ia.Id;
        pc.nepa_comment_body__c    = 'GIS test comment.';
        pc.nepa_public_access__c   = 'Public';
        insert pc;

        nepa_gis_data__c g = new nepa_gis_data__c();
        g.Name                    = 'Comment GIS';
        g.nepa_parent_comment__c  = pc.Id;
        insert g;

        nepa_gis_data__c result = [SELECT nepa_parent_comment__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assertEquals(pc.Id, result.nepa_parent_comment__c);
    }

    @IsTest
    static void gisData_engagementParent_resolves() {
        IndividualApplication ia = getProcess();
        nepa_engagement__c e = NepaTestFactory.insertPublicEngagement(ia.Id);

        nepa_gis_data__c g = new nepa_gis_data__c();
        g.Name                       = 'Engagement GIS';
        g.nepa_parent_engagement__c  = e.Id;
        insert g;

        nepa_gis_data__c result = [SELECT nepa_parent_engagement__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assertEquals(e.Id, result.nepa_parent_engagement__c);
    }

    @IsTest
    static void gisData_parentDocumentId_textField_persists() {
        // nepa_parent_document_id__c is Text(18) — ContentDocument cannot be a Lookup target.
        // A synthetic 18-char ContentDocument-format ID is stored as plain text; no FK enforcement.
        final String syntheticDocId = '069000000000001AAA'; //NOPMD — intentional synthetic ID for Text field round-trip test
        nepa_gis_data__c g = new nepa_gis_data__c();
        g.Name                          = 'Document GIS';
        g.nepa_parent_document_id__c    = syntheticDocId;
        insert g;

        nepa_gis_data__c result = [SELECT nepa_parent_document_id__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assertEquals(syntheticDocId, result.nepa_parent_document_id__c);
    }

    @IsTest
    static void gisData_dataContainerFields_persist() {
        Program proj = getProject();
        nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, null);
        g.nepa_container_inventory__c = 'ESA Critical Habitat Layer, NWI Wetlands Layer';
        g.nepa_map_image__c           = 'https://example.arcgis.com/map.png';
        g.nepa_data_container__c      = 'https://example.arcgis.com/featureservice/0';
        g.nepa_extent__c              = 'POLYGON((-111.0 44.0, -110.0 44.0, -110.0 45.0, -111.0 45.0, -111.0 44.0))';
        insert g;

        nepa_gis_data__c result = [
            SELECT nepa_container_inventory__c, nepa_map_image__c, nepa_data_container__c, nepa_extent__c
            FROM nepa_gis_data__c WHERE Id = :g.Id
        ];
        System.assert(result.nepa_container_inventory__c.contains('ESA'));
        System.assert(result.nepa_map_image__c.contains('arcgis'));
        System.assert(result.nepa_data_container__c.contains('featureservice'));
        System.assert(result.nepa_extent__c.contains('POLYGON'));
    }

    @IsTest
    static void gisData_provenance_fields_persist() {
        Program proj = getProject();
        nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, null);
        g.nepa_data_source_agency__c  = 'USFWS';
        g.nepa_data_source_system__c  = 'ECOS';
        g.nepa_data_record_version__c = '2024-12';
        g.nepa_record_owner_agency__c = 'BLM';
        g.nepa_retrieved_timestamp__c = DateTime.now();
        insert g;

        nepa_gis_data__c result = [
            SELECT nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_data_record_version__c, nepa_record_owner_agency__c,
                   nepa_retrieved_timestamp__c
            FROM nepa_gis_data__c WHERE Id = :g.Id
        ];
        System.assertEquals('USFWS',    result.nepa_data_source_agency__c);
        System.assertEquals('ECOS',     result.nepa_data_source_system__c);
        System.assertEquals('2024-12',  result.nepa_data_record_version__c);
        System.assertEquals('BLM',      result.nepa_record_owner_agency__c);
        System.assertNotEquals(null,    result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void gisData_other_extensionBag_persists() {
        Program proj = getProject();
        nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, null);
        g.nepa_other__c = '{"arcgis_layer_id": "critical_habitat_v2", "resolution_meters": 30}';
        insert g;

        nepa_gis_data__c result = [SELECT nepa_other__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assert(result.nepa_other__c.contains('arcgis_layer_id'));
    }

    @IsTest
    static void gisData_creatorContact_field_persists() {
        Program proj = getProject();
        nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, null);
        g.nepa_creator_contact__c = 'gis.team@blm.gov';
        g.nepa_notes__c           = 'Downloaded from BLM EGIS portal. Reprojected to WGS84.';
        insert g;

        nepa_gis_data__c result = [
            SELECT nepa_creator_contact__c, nepa_notes__c
            FROM nepa_gis_data__c WHERE Id = :g.Id
        ];
        System.assertEquals('gis.team@blm.gov', result.nepa_creator_contact__c);
        System.assert(result.nepa_notes__c.contains('WGS84'));
    }

    @IsTest
    static void gisData_parentProcess_setNull_onProcessDelete() {
        Program proj = NepaTestFactory.insertProgram('GIS-SETNULL-001', 'SetNull Test', 'EPA');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');

        nepa_gis_data__c g = new nepa_gis_data__c();
        g.Name                   = 'SetNull GIS';
        g.nepa_parent_process__c = ia.Id;
        insert g;

        delete ia;

        nepa_gis_data__c result = [SELECT nepa_parent_process__c FROM nepa_gis_data__c WHERE Id = :g.Id];
        System.assertEquals(null, result.nepa_parent_process__c);
    }

    @IsTest
    static void gisData_bulk_insert_251() {
        Program proj = getProject();
        IndividualApplication ia = getProcess();
        List<nepa_gis_data__c> records = new List<nepa_gis_data__c>();
        for (Integer i = 0; i < 251; i++) {
            nepa_gis_data__c g = NepaTestFactory.makeGisData(proj.Id, ia.Id);
            g.Name = 'Bulk GIS ' + i;
            records.add(g);
        }
        insert records;
        System.assertEquals(251, [SELECT COUNT() FROM nepa_gis_data__c WHERE nepa_parent_project__c = :proj.Id]);
    }

    @IsTest
    static void gisData_schemaFields_compile() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.nepa_gis_data__c.fields.getMap();
        for (String f : new List<String>{
            'nepa_parent_project__c', 'nepa_parent_process__c', 'nepa_parent_document_id__c',
            'nepa_parent_case_event__c', 'nepa_parent_comment__c', 'nepa_parent_engagement__c',
            'nepa_description__c', 'nepa_extent__c', 'nepa_centroid_lat__c', 'nepa_centroid_lon__c',
            'nepa_address__c', 'nepa_notes__c', 'nepa_creator__c', 'nepa_creator_contact__c',
            'nepa_container_inventory__c', 'nepa_map_image__c', 'nepa_data_container__c',
            'nepa_other__c', 'nepa_data_record_version__c', 'nepa_data_source_agency__c',
            'nepa_data_source_system__c', 'nepa_record_owner_agency__c', 'nepa_retrieved_timestamp__c'
        }) {
            System.assert(fields.containsKey(f), 'Missing field on nepa_gis_data__c: ' + f);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 9 — process_model → NEPA_Process_Model__mdt (compile-time schema)
    // Custom metadata type fields are DeveloperControlled — no insert in Apex.
    // These tests verify the schema compiles against all expected fields.
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void processModel_cmt_schemaFields_compile() {
        // Compile-time validation: if any field is missing, this test will
        // fail to compile and will surface as a deployment error.
        List<NEPA_Process_Model__mdt> models = [
            SELECT Id, DeveloperName, MasterLabel,
                   Review_Type__c, Statutory_Authority__c, Max_Timeline_Days__c,
                   Required_Decision_Payload_Type__c, Requires_Scoping__c,
                   Requires_Public_Comment__c, Min_Comment_Period_Days__c,
                   Required_Review_Stages__c, CEQ_Data_Standard_Entity__c, Active__c,
                   Description__c, Agency__c, Legal_Structure_Citation__c,
                   Parent_Model_Developer_Name__c, Screening_Description__c
            FROM NEPA_Process_Model__mdt
        ];
        // Just confirm the query executed — field count confirmed by compile.
        System.assertNotEquals(null, models);
    }

    @IsTest
    static void processModel_cmt_eisRecord_hasExpectedValues() {
        // Validates deployed CMT records have the correct standard field values.
        List<NEPA_Process_Model__mdt> eis = [
            SELECT Review_Type__c, Max_Timeline_Days__c, Requires_Scoping__c,
                   Requires_Public_Comment__c, Required_Decision_Payload_Type__c
            FROM NEPA_Process_Model__mdt
            WHERE Review_Type__c = 'EIS' AND Active__c = true
            LIMIT 1
        ];
        if (!eis.isEmpty()) {
            System.assertEquals('EIS',   eis[0].Review_Type__c);
            System.assertEquals(true,    eis[0].Requires_Scoping__c);
            System.assertEquals(true,    eis[0].Requires_Public_Comment__c);
            System.assertEquals('ROD',   eis[0].Required_Decision_Payload_Type__c);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Cross-entity: provenance pattern complete across all 8 core objects
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void allCoreEntities_provenanceFields_arePresent() {
        // One query per entity — all 5 provenance fields must be readable.
        // Any missing field will cause a SOQL compile error.
        Program p = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM Program LIMIT 1
        ];
        IndividualApplication ia = [
            SELECT nepa_record_owner_agency__c, nepa_data_source_agency__c,
                   nepa_data_source_system__c, nepa_data_record_version__c,
                   nepa_retrieved_timestamp__c
            FROM IndividualApplication LIMIT 1
        ];
        System.assertNotEquals(null, p.Id);
        System.assertNotEquals(null, ia.Id);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Cross-entity: other (JSON) extension bag present on all 8 core objects
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void allCoreEntities_otherField_isPresent() {
        // SOQL compile-time check: nepa_other__c must exist on each object.
        Program p = [SELECT nepa_other__c FROM Program LIMIT 1];
        IndividualApplication ia = [SELECT nepa_other__c FROM IndividualApplication LIMIT 1];
        System.assertNotEquals(null, p.Id);
        System.assertNotEquals(null, ia.Id);
        // ContentVersion, PublicComplaint, nepa_engagement__c, ApplicationTimeline,
        // nepa_decision_element__c, nepa_decision_payload__c are verified implicitly
        // through the field-persist tests above.
    }
}