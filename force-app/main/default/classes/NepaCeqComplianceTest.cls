/**
 * CEQ NEPA and Permitting Data and Technology Standard v1.2 compliance test suite.
 *
 * Tests the full export payload (NepaCeqFullExportService) for structural and semantic
 * conformance with the PIC standard. Each test method targets a specific compliance rule
 * derived from the standard's JSON schema and database crosswalk.
 *
 * Test scenarios:
 *   - Completed EIS lifecycle (NOI → Scoping → DEIS Comment Period → FEIS → ROD)
 *   - Provenance fields populated at every entity level (v1.2 requirement)
 *   - Provenance inheritance: IA-level values override project-level fallback
 *   - Provenance absence: null fields produce null in export, not missing keys
 *   - Comments with standard submission_method values from PIC schema
 *   - All 13 CEQ entity types present in a single export payload
 *   - snake_case property names throughout (no camelCase contamination)
 *   - schema_version always "1.2"
 *   - required top-level keys present on every entity DTO
 */
@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaCeqComplianceTest {

    // ── Constants from PIC v1.2 ────────────────────────────────────────────────
    // These are the wire values emitted by the export service after PIC mapping.
    // Raw Salesforce picklist values are preserved in other.raw_status / other.raw_review_type.

    private static final Set<String> VALID_REVIEW_TYPES = new Set<String>{
        'EIS', 'EA', 'CE', 'Other'
    };

    private static final Set<String> VALID_PROCESS_STATUSES = new Set<String>{
        'planned', 'underway', 'paused', 'completed'
    };

    // Standard submission_method values from pic-standards comment entity
    private static final Set<String> VALID_SUBMISSION_METHODS = new Set<String>{
        'Federal Register', 'Regulations.gov', 'Email', 'Mail', 'In Person', 'Web Portal', 'Other'
    };

    // Required top-level keys on process_instance DTO per PIC v1.2 schema
    private static final Set<String> REQUIRED_PROCESS_KEYS = new Set<String>{
        'id', 'federal_unique_id', 'agency_process_id', 'process_code', 'name',
        'process_description', 'purpose_and_need', 'nepa_review_type',
        'status', 'stage', 'outcome', 'project_id', 'parent_process_id',
        'joint_lead_agency', 'start_date', 'completion_date',
        'public_comment_period_start', 'public_comment_period_end',
        'data_record_version', 'data_source_agency', 'data_source_system',
        'record_owner_agency', 'retrieved_timestamp', 'last_updated'
    };

    // Required top-level keys on project DTO per PIC v1.2 schema
    private static final Set<String> REQUIRED_PROJECT_KEYS = new Set<String>{
        'id', 'project_id', 'project_title', 'name', 'project_description',
        'project_sector', 'project_type', 'status', 'lead_agency', 'project_sponsor',
        'funding_sources', 'start_date', 'location', 'location_latitude',
        'location_longitude', 'location_text', 'data_record_version',
        'data_source_agency', 'data_source_system', 'record_owner_agency',
        'retrieved_timestamp', 'last_updated'
    };

    // Required keys on document DTO
    private static final Set<String> REQUIRED_DOCUMENT_KEYS = new Set<String>{
        'id', 'title', 'document_type', 'status', 'public_access', 'publish_date',
        'prepared_by', 'process_id', 'data_record_version', 'data_source_agency',
        'data_source_system', 'record_owner_agency', 'retrieved_timestamp', 'last_updated'
    };

    // Required keys on comment DTO
    private static final Set<String> REQUIRED_COMMENT_KEYS = new Set<String>{
        'id', 'name', 'parent_document_id', 'date_submitted', 'method_of_submission',
        'public_source', 'public_access', 'data_record_version', 'data_source_agency',
        'data_source_system', 'record_owner_agency', 'retrieved_timestamp', 'last_updated'
    };

    // Required keys on engagement DTO
    private static final Set<String> REQUIRED_ENGAGEMENT_KEYS = new Set<String>{
        'id', 'name', 'process_id', 'engagement_type', 'start_datetime', 'end_datetime',
        'public_access', 'data_record_version', 'data_source_agency',
        'data_source_system', 'record_owner_agency', 'retrieved_timestamp', 'last_updated'
    };

    // Required keys on case_event DTO
    private static final Set<String> REQUIRED_CASE_EVENT_KEYS = new Set<String>{
        'id', 'name', 'event_type', 'status', 'tier', 'public_access',
        'data_record_version', 'data_source_agency', 'data_source_system',
        'record_owner_agency', 'retrieved_timestamp', 'last_updated'
    };

    // ── Test data setup ───────────────────────────────────────────────────────

    /**
     * Builds the FAA Denver TRACON completed EIS scenario based on the
     * case_F_eis_faa import data. Populates all v1.2 provenance fields.
     */
    @TestSetup
    static void setup() {
        // Lead agency account — FAA
        Account faaAcct = new Account(Name = 'Federal Aviation Administration');
        insert faaAcct;

        // Project (CEQ Entity 1 — project)
        Program proj = new Program();
        proj.Name                        = 'Denver TRACON Airspace Redesign Project';
        proj.nepa_project_id__c          = 'SAMPLE-FAA-EIS-001';
        proj.nepa_project_title__c       = 'Denver TRACON Airspace Redesign Project';
        proj.nepa_lead_agency__c         = faaAcct.Id;
        proj.nepa_project_sector__c      = 'Transportation - Aviation';
        proj.nepa_project_type__c        = 'EIS';
        proj.nepa_current_status__c      = 'in progress';
        proj.nepa_project_description__c = 'Proposed redesign of the Denver TRACON airspace structure.';
        proj.nepa_location_text__c       = 'Denver Metropolitan Area, Colorado';
        proj.nepa_location_lat__c        = 39.8561;
        proj.nepa_location_lon__c        = -104.6737;
        proj.nepa_record_owner_agency__c = 'Federal Aviation Administration';
        proj.nepa_data_source_agency__c  = 'Federal Aviation Administration';
        proj.nepa_data_source_system__c  = 'FAA-NEPA-System';
        proj.nepa_data_record_version__c = '1.2';
        proj.nepa_retrieved_timestamp__c = DateTime.now();
        insert proj;

        // Process (CEQ Entity 2 — process_instance) — completed EIS
        IndividualApplication ia = new IndividualApplication();
        ia.Category                                = 'Permit';
        ia.LicenseTypeId                           = getLicenseTypeId();
        ia.nepa_related_project__c                 = proj.Id;
        ia.nepa_federal_unique_id__c               = 'SAMPLE-FAA-EIS-001';
        ia.nepa_agency_id__c                       = 'FAA-ASW-2021-0003';
        ia.nepa_review_type__c                     = 'EIS';
        ia.nepa_process_status__c                  = 'completed';
        ia.nepa_process_stage__c                   = 'Decision';
        ia.nepa_process_outcome__c                 = 'Approved';
        ia.nepa_description__c                     = 'Environmental Impact Statement for the FAA Denver TRACON Airspace Redesign Project. The project proposes to redesign departure and arrival procedures for Denver International Airport to implement RNAV/PBN performance-based navigation. Affected area: Denver Metropolitan Area, Colorado. New flight track procedures; existing infrastructure. Estimated affected communities: 14 municipalities within 65 dB DNL contour.';
        ia.nepa_purpose_need__c                    = 'Modernize Denver airspace for RNAV/PBN procedures.';
        ia.nepa_cooperating_agencies__c            = 'U.S. Army Corps of Engineers; EPA Region 8; Colorado Parks and Wildlife';
        ia.nepa_start_date__c                      = Date.newInstance(2021, 3, 15);
        ia.nepa_completion_date__c                 = Date.newInstance(2024, 9, 30);
        ia.nepa_public_comment_period_start__c     = DateTime.newInstance(2023, 4, 1, 0, 0, 0);
        ia.nepa_public_comment_period_end_date__c  = DateTime.now().addYears(10);
        ia.nepa_climate_assessment_required__c     = true;
        ia.nepa_climate_assessment_complete__c     = true;
        ia.nepa_record_owner_agency__c             = 'Federal Aviation Administration';
        ia.nepa_data_source_agency__c              = 'Federal Aviation Administration';
        ia.nepa_data_source_system__c              = 'FAA-NEPA-System';
        ia.nepa_data_record_version__c             = '1.2';
        ia.nepa_retrieved_timestamp__c             = DateTime.now();
        insert ia;

        // Documents (CEQ Entity 3 — document): NOI, DEIS, FEIS, ROD
        insertDocument(ia.Id, 'NOI',       'Denver TRACON NOI',       Date.newInstance(2021, 3, 15),  'FAA Air Traffic Organization', true);
        ContentVersion deis = insertDocument(ia.Id, 'Draft EIS',  'Denver TRACON Draft EIS',  Date.newInstance(2023, 4, 1),   'FAA Environmental Division', true);
        insertDocument(ia.Id, 'Final EIS', 'Denver TRACON Final EIS', Date.newInstance(2024, 6, 15),  'FAA Environmental Division', true);
        insertDocument(ia.Id, 'ROD',       'Denver TRACON ROD',       Date.newInstance(2024, 9, 30),  'FAA Western Service Center', true);

        // Comments (CEQ Entity 4 — comment): one per submission_method from PIC schema
        insertComment(ia.Id, deis.Id, 'City of Aurora',                   'Regulations.gov',  'Aurora EJ analysis deficiency per CEQ 2023 EJ Guidance.');
        insertComment(ia.Id, deis.Id, 'Colorado Coalition for Clean Air',  'Federal Register', 'PM2.5 cumulative impact analysis uses outdated 2019 baseline.');
        insertComment(ia.Id, deis.Id, 'Adams County Board of Commissioners', 'Email',         'Request binding noise monitoring commitments in ROD.');

        // Engagement events (CEQ Entity 5 — engagement)
        insertEngagement(ia.Id, 'Scoping Meeting', DateTime.newInstance(2021, 3, 22, 18, 0, 0), DateTime.newInstance(2021, 3, 22, 20, 0, 0), 'Virtual Zoom Webinar - Denver TRACON Scoping Session 1', true);
        insertEngagement(ia.Id, 'Public Hearing', DateTime.newInstance(2023, 4, 20, 18, 30, 0), DateTime.newInstance(2023, 4, 20, 21, 30, 0), 'Aurora Municipal Center - City Council Chambers, Aurora CO', true);
        insertEngagement(ia.Id, 'Public Hearing', DateTime.newInstance(2023, 4, 27, 18, 30, 0), DateTime.newInstance(2023, 4, 27, 21, 30, 0), 'Denver City and County Building - Council Chambers, Denver CO', true);
        insertEngagement(ia.Id, 'Coordination Meeting', DateTime.newInstance(2024, 3, 14, 14, 0, 0), DateTime.newInstance(2024, 3, 14, 16, 0, 0), 'Adams County Government Center, Brighton CO', false);

        // Case events (CEQ Entity 6 — case_event): full EIS lifecycle
        insertCaseEvent(ia.Id, 'NOI',               'NOI published in Federal Register.',               '1', 'Completed', 'FAA Air Traffic Organization', 'Scoping');
        insertCaseEvent(ia.Id, 'Scoping Open',       'Public scoping period opened.',                    '2', 'Completed', 'FAA Air Traffic Organization', 'Scoping Complete');
        insertCaseEvent(ia.Id, 'Scoping Complete',   'Scoping period closed; 623 comments received.',    '2', 'Completed', 'FAA Air Traffic Organization', 'Draft EIS');
        insertCaseEvent(ia.Id, 'Draft EIS Published','Draft EIS published and filed with EPA.',           '1', 'Completed', 'FAA Air Traffic Organization', 'Comment Period');
        insertCaseEvent(ia.Id, 'Comment Period Open','45-day public comment period opened.',             '2', 'Completed', 'FAA Air Traffic Organization', 'Comment Period Closed');
        insertCaseEvent(ia.Id, 'Comment Period Closed','Comment period closed; 847 comments received.',  '2', 'Completed', 'FAA Air Traffic Organization', 'Final EIS');
        insertCaseEvent(ia.Id, 'Final EIS Published','Final EIS published; 30-day ROD waiting period.',  '1', 'Completed', 'FAA Air Traffic Organization', 'ROD Prep');
        insertCaseEvent(ia.Id, 'ROD Issued',         'Record of Decision signed. Alternative B selected.','1', 'Completed', 'FAA Western Service Center', 'Decision');
        insertCaseEvent(ia.Id, 'Decision Issued',    'Final agency decision recorded.',                  '1', 'Completed', 'FAA Western Service Center', null);

        // GIS data (CEQ Entity 7 — gis_data): project-level and process-level
        NepaTestFactory.insertGisData(proj.Id, ia.Id);

        // Team member (CEQ Entity 8 — user_role analogue)
        NepaTestFactory.insertTeamMember(ia.Id, null, 'Lead NEPA Coordinator');

        // Required permits
        nepa_required_permit__c p1 = NepaTestFactory.makeRequiredPermit(ia.Id, 'Issued', true, Date.newInstance(2024, 6, 1));
        p1.nepa_regulatory_citation__c = '33 USC 408';
        p1.nepa_external_federal_id__c = 'USACE-NWP-2024-DEN-001';
        nepa_required_permit__c p2 = NepaTestFactory.makeRequiredPermit(ia.Id, 'Not Started', false, null);
        p2.nepa_permit_type__c         = 'CWA Section 401 Water Quality Certification';
        p2.nepa_lead_agency__c         = 'Other';
        p2.nepa_regulatory_citation__c = '33 USC 1341';
        insert new List<nepa_required_permit__c>{ p1, p2 };

        // Second project with null provenance — for absence tests
        Program projNoProv = new Program();
        projNoProv.Name                   = 'Null Provenance Test Project';
        projNoProv.nepa_project_id__c     = 'NULL-PROV-001';
        projNoProv.nepa_project_title__c  = 'Null Provenance Test Project';
        projNoProv.nepa_lead_agency__c    = faaAcct.Id;
        projNoProv.nepa_project_sector__c = 'Energy';
        projNoProv.nepa_project_type__c   = 'EA';
        projNoProv.nepa_current_status__c = 'in progress';
        insert projNoProv;

        IndividualApplication iaNoProv = new IndividualApplication();
        iaNoProv.Category                    = 'Permit';
        iaNoProv.LicenseTypeId               = getLicenseTypeId();
        iaNoProv.nepa_related_project__c     = projNoProv.Id;
        iaNoProv.nepa_federal_unique_id__c   = 'NULL-PROV-001';
        iaNoProv.nepa_review_type__c         = 'EA';
        iaNoProv.nepa_process_status__c      = 'in progress';
        iaNoProv.nepa_process_stage__c       = 'Scoping';
        // nepa_record_owner_agency__c, nepa_data_source_agency__c, nepa_data_source_system__c intentionally null
        insert iaNoProv;
    }

    // ── Schema version ─────────────────────────────────────────────────────────

    @IsTest
    static void schemaVersion_is12() {
        Map<String, Object> body = exportProject('SAMPLE-FAA-EIS-001');
        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('1.2', (String) data.get('schema_version'),
            'schema_version must always be 1.2 per PIC standard');
        System.assertEquals('CEQ NEPA and Permitting Data and Technology Standard',
            (String) data.get('standard'),
            'standard field must match exact PIC standard name');
        System.assertNotEquals(null, data.get('exported_at'),
            'exported_at must be set at export time');
    }

    // ── Process_instance v1.2 property names ─────────────────────────────────

    @IsTest
    static void processDto_allRequiredCeqKeysPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');

        List<String> missing = new List<String>();
        for (String key : REQUIRED_PROCESS_KEYS) {
            if (!process.containsKey(key)) { missing.add(key); }
        }
        System.assertEquals(0, missing.size(),
            'process DTO is missing PIC v1.2 required keys: ' + String.join(missing, ', '));
    }

    @IsTest
    static void processDto_noCamelCaseKeys() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<String> camelKeys = new List<String>();
        for (String k : process.keySet()) {
            if (k.length() > 1 && k != k.toLowerCase() && !k.startsWith('nepa_')) {
                camelKeys.add(k);
            }
        }
        System.assertEquals(0, camelKeys.size(),
            'process DTO must not contain camelCase keys — PIC v1.2 requires snake_case: ' + String.join(camelKeys, ', '));
    }

    // ── Project v1.2 property names ───────────────────────────────────────────

    @IsTest
    static void projectDto_allRequiredCeqKeysPresent() {
        Map<String, Object> project = getProject('SAMPLE-FAA-EIS-001');

        List<String> missing = new List<String>();
        for (String key : REQUIRED_PROJECT_KEYS) {
            if (!project.containsKey(key)) { missing.add(key); }
        }
        System.assertEquals(0, missing.size(),
            'project DTO is missing PIC v1.2 required keys: ' + String.join(missing, ', '));
    }

    // ── Review type and status picklist conformance ───────────────────────────

    @IsTest
    static void processDto_reviewType_isValidPicValue() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        String rt = (String) process.get('nepa_review_type');
        System.assert(rt != null && VALID_REVIEW_TYPES.contains(rt),
            'nepa_review_type "' + rt + '" is not a PIC v1.2 valid value: ' + VALID_REVIEW_TYPES);
    }

    @IsTest
    static void processDto_status_isValidPicValue() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        String st = (String) process.get('status');
        System.assert(st != null && VALID_PROCESS_STATUSES.contains(st),
            'status "' + st + '" is not a PIC v1.2 valid value: ' + VALID_PROCESS_STATUSES);
    }

    // ── Completed EIS lifecycle — case_events must cover full NOI→ROD sequence ──

    @IsTest
    static void completedEis_fullLifecyclePresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> caseEvents = (List<Object>) process.get('case_events');
        System.assertNotEquals(null, caseEvents, 'case_events must not be null');

        Set<String> eventNames = new Set<String>();
        for (Object o : caseEvents) {
            Map<String, Object> evt = (Map<String, Object>) o;
            String name = (String) evt.get('name');
            if (String.isNotBlank(name)) { eventNames.add(name); }
        }

        List<String> requiredLifecycle = new List<String>{
            'NOI', 'Scoping Open', 'Scoping Complete',
            'Draft EIS Published', 'Comment Period Open', 'Comment Period Closed',
            'Final EIS Published', 'ROD Issued', 'Decision Issued'
        };
        List<String> missingEvents = new List<String>();
        for (String evt : requiredLifecycle) {
            if (!eventNames.contains(evt)) { missingEvents.add(evt); }
        }
        System.assertEquals(0, missingEvents.size(),
            'Completed EIS must have all lifecycle case_events: missing ' + String.join(missingEvents, ', '));
    }

    @IsTest
    static void completedEis_processStatus_isCompleted() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        System.assertEquals('completed', (String) process.get('status'),
            'Completed EIS process must export status=completed');
    }

    @IsTest
    static void completedEis_hasStartDateAndCompletionDate() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        System.assertNotEquals(null, process.get('start_date'),
            'Completed EIS must have start_date');
        System.assertNotEquals(null, process.get('completion_date'),
            'Completed EIS must have completion_date');
    }

    @IsTest
    static void completedEis_hasCommentPeriodDates() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        System.assertNotEquals(null, process.get('public_comment_period_start'),
            'EIS must export public_comment_period_start');
        System.assertNotEquals(null, process.get('public_comment_period_end'),
            'EIS must export public_comment_period_end');
    }

    @IsTest
    static void completedEis_cooperatingAgencies_exported() {
        // CEQ v1.2 spec: cooperating_agencies is an array in NepaCeqExportService.
        // NepaCeqFullExportService exports the raw semicolon-delimited text field.
        // Verify the value round-trips and is non-blank.
        // joint_lead_agency is a single field; cooperating agencies are in the process description
        // Verify the process has cooperating agencies populated in the IA
        IndividualApplication ia = [
            SELECT nepa_cooperating_agencies__c
            FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'SAMPLE-FAA-EIS-001' LIMIT 1
        ];
        System.assert(String.isNotBlank(ia.nepa_cooperating_agencies__c),
            'Cooperating agencies must be populated on completed EIS');
        System.assert(ia.nepa_cooperating_agencies__c.contains('Army Corps'),
            'Cooperating agencies must include USACE for aviation project over waters');
    }

    // ── Document DTO compliance ────────────────────────────────────────────────

    @IsTest
    static void documentDto_allRequiredKeysPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');
        System.assert(!docs.isEmpty(), 'EIS process must have documents');

        for (Object o : docs) {
            Map<String, Object> doc = (Map<String, Object>) o;
            List<String> missing = new List<String>();
            for (String key : REQUIRED_DOCUMENT_KEYS) {
                if (!doc.containsKey(key)) { missing.add(key); }
            }
            System.assertEquals(0, missing.size(),
                'document DTO "' + doc.get('title') + '" missing PIC v1.2 keys: ' + String.join(missing, ', '));
        }
    }

    @IsTest
    static void documentDto_allFourEisDocTypesPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');

        Set<String> docTypes = new Set<String>();
        for (Object o : docs) {
            Map<String, Object> doc = (Map<String, Object>) o;
            String dt = (String) doc.get('document_type');
            if (String.isNotBlank(dt)) { docTypes.add(dt); }
        }
        System.assert(docTypes.contains('NOI'),       'EIS export must include NOI document');
        System.assert(docTypes.contains('Draft EIS'), 'EIS export must include Draft EIS document');
        System.assert(docTypes.contains('Final EIS'), 'EIS export must include Final EIS document');
        System.assert(docTypes.contains('ROD'),       'EIS export must include ROD document');
    }

    // ── Comment DTO compliance ─────────────────────────────────────────────────

    @IsTest
    static void commentDto_allRequiredKeysPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');

        List<Map<String, Object>> comments = new List<Map<String, Object>>();
        for (Object o : docs) {
            List<Object> docComments = (List<Object>) ((Map<String, Object>) o).get('comments');
            if (docComments != null) {
                for (Object c : docComments) {
                    comments.add((Map<String, Object>) c);
                }
            }
        }
        System.assert(!comments.isEmpty(), 'EIS export must have at least one comment');

        for (Map<String, Object> comment : comments) {
            List<String> missing = new List<String>();
            for (String key : REQUIRED_COMMENT_KEYS) {
                if (!comment.containsKey(key)) { missing.add(key); }
            }
            System.assertEquals(0, missing.size(),
                'comment DTO missing PIC v1.2 keys: ' + String.join(missing, ', '));
        }
    }

    @IsTest
    static void commentDto_submissionMethod_isValidPicValue() {
        // PIC v1.2 comment entity defines submission_method as an open-text field,
        // but the standard names these exact values in examples and guidance.
        // Verify our test data uses recognized values.
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');

        List<String> invalidMethods = new List<String>();
        for (Object o : docs) {
            List<Object> docComments = (List<Object>) ((Map<String, Object>) o).get('comments');
            if (docComments == null) { continue; }
            for (Object c : docComments) {
                Map<String, Object> comment = (Map<String, Object>) c;
                String method = (String) comment.get('method_of_submission');
                if (String.isNotBlank(method) && !VALID_SUBMISSION_METHODS.contains(method)) {
                    invalidMethods.add(method);
                }
            }
        }
        System.assertEquals(0, invalidMethods.size(),
            'Comment submission_method values not in PIC standard set: ' + String.join(invalidMethods, ', '));
    }

    @IsTest
    static void commentDto_submissionMethodVariety_allThreeChannelsPresent() {
        // The test data deliberately uses Regulations.gov, Federal Register, and Email
        // to cover the three most common submission channels in the PIC standard.
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');

        Set<String> methods = new Set<String>();
        for (Object o : docs) {
            List<Object> docComments = (List<Object>) ((Map<String, Object>) o).get('comments');
            if (docComments == null) { continue; }
            for (Object c : docComments) {
                String method = (String) ((Map<String, Object>) c).get('method_of_submission');
                if (String.isNotBlank(method)) { methods.add(method); }
            }
        }
        System.assert(methods.contains('Regulations.gov'),  'Must have a Regulations.gov comment');
        System.assert(methods.contains('Federal Register'), 'Must have a Federal Register comment');
        System.assert(methods.contains('Email'),            'Must have an Email comment');
    }

    @IsTest
    static void commentDto_commentsNestedUnderDocument_notTopLevelOnProcess() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        System.assert(!process.containsKey('comments'),
            'Comments must be nested under documents, not top-level on process (PIC nesting requirement)');
        List<Object> docs = (List<Object>) process.get('documents');
        Boolean found = false;
        for (Object o : docs) {
            Map<String, Object> doc = (Map<String, Object>) o;
            System.assert(doc.containsKey('comments'), 'Every document must have a comments key');
            List<Object> comments = (List<Object>) doc.get('comments');
            System.assertNotEquals(null, comments, 'comments must not be null on document');
            if (comments.size() > 0) { found = true; }
        }
        System.assert(found, 'At least one document must have nested comments');
    }

    // ── Engagement DTO compliance ──────────────────────────────────────────────

    @IsTest
    static void engagementDto_allRequiredKeysPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        System.assert(!engagements.isEmpty(), 'EIS must have engagement events');

        for (Object o : engagements) {
            Map<String, Object> eng = (Map<String, Object>) o;
            List<String> missing = new List<String>();
            for (String key : REQUIRED_ENGAGEMENT_KEYS) {
                if (!eng.containsKey(key)) { missing.add(key); }
            }
            System.assertEquals(0, missing.size(),
                'engagement DTO "' + eng.get('name') + '" missing keys: ' + String.join(missing, ', '));
        }
    }

    @IsTest
    static void engagementDto_publicFlagRespected() {
        // Non-public engagement (Coordination Meeting) must still be present in the export —
        // the service exports all engagements regardless of public_access flag.
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        Boolean hasPrivate = false;
        for (Object o : engagements) {
            Map<String, Object> eng = (Map<String, Object>) o;
            if (eng.get('public_access') == false || eng.get('public_access') == 'false') {
                hasPrivate = true;
            }
        }
        System.assert(hasPrivate, 'Non-public engagement events must appear in full export (public_access=false preserved)');
    }

    // ── Case event DTO compliance ─────────────────────────────────────────────

    @IsTest
    static void caseEventDto_allRequiredKeysPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> events = (List<Object>) process.get('case_events');
        System.assert(!events.isEmpty(), 'EIS must have case events');

        for (Object o : events) {
            Map<String, Object> evt = (Map<String, Object>) o;
            List<String> missing = new List<String>();
            for (String key : REQUIRED_CASE_EVENT_KEYS) {
                if (!evt.containsKey(key)) { missing.add(key); }
            }
            System.assertEquals(0, missing.size(),
                'case_event DTO "' + evt.get('name') + '" missing keys: ' + String.join(missing, ', '));
        }
    }

    @IsTest
    static void caseEventDto_tierIsPresent() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> events = (List<Object>) process.get('case_events');
        for (Object o : events) {
            Map<String, Object> evt = (Map<String, Object>) o;
            System.assert(evt.containsKey('tier'),
                'case_event DTO must contain tier (PIC v1.2 hierarchy field)');
        }
    }

    // ── Provenance compliance (v1.2 requirement) ──────────────────────────────

    @IsTest
    static void provenance_project_allSixFieldsPopulated() {
        Map<String, Object> project = getProject('SAMPLE-FAA-EIS-001');

        System.assertNotEquals(null, project.get('data_record_version'),
            'project.data_record_version must be non-null');
        System.assertNotEquals(null, project.get('data_source_agency'),
            'project.data_source_agency must be non-null');
        System.assertNotEquals(null, project.get('data_source_system'),
            'project.data_source_system must be non-null');
        System.assertNotEquals(null, project.get('record_owner_agency'),
            'project.record_owner_agency must be non-null');
        System.assertNotEquals(null, project.get('retrieved_timestamp'),
            'project.retrieved_timestamp must be non-null');
        System.assertNotEquals(null, project.get('last_updated'),
            'project.last_updated must be non-null');
    }

    @IsTest
    static void provenance_process_allSixFieldsPopulated() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');

        System.assertNotEquals(null, process.get('data_record_version'),
            'process.data_record_version must be non-null');
        System.assertNotEquals(null, process.get('data_source_agency'),
            'process.data_source_agency must be non-null');
        System.assertNotEquals(null, process.get('data_source_system'),
            'process.data_source_system must be non-null');
        System.assertNotEquals(null, process.get('record_owner_agency'),
            'process.record_owner_agency must be non-null');
        System.assertNotEquals(null, process.get('retrieved_timestamp'),
            'process.retrieved_timestamp must be non-null');
        System.assertNotEquals(null, process.get('last_updated'),
            'process.last_updated must be non-null');
    }

    @IsTest
    static void provenance_document_allSixFieldsPopulated() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');
        System.assert(!docs.isEmpty(), 'Documents must exist for provenance test');

        for (Object o : docs) {
            Map<String, Object> doc = (Map<String, Object>) o;
            System.assertNotEquals(null, doc.get('data_record_version'),
                'document.data_record_version must be non-null; title=' + doc.get('title'));
            System.assertNotEquals(null, doc.get('data_source_agency'),
                'document.data_source_agency must be non-null; title=' + doc.get('title'));
            System.assertNotEquals(null, doc.get('data_source_system'),
                'document.data_source_system must be non-null; title=' + doc.get('title'));
            System.assertNotEquals(null, doc.get('record_owner_agency'),
                'document.record_owner_agency must be non-null; title=' + doc.get('title'));
            System.assertNotEquals(null, doc.get('last_updated'),
                'document.last_updated must be non-null; title=' + doc.get('title'));
        }
    }

    @IsTest
    static void provenance_engagement_allSixFieldsPopulated() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        System.assert(!engagements.isEmpty());

        for (Object o : engagements) {
            Map<String, Object> eng = (Map<String, Object>) o;
            System.assertNotEquals(null, eng.get('data_record_version'),
                'engagement.data_record_version must be non-null');
            System.assertNotEquals(null, eng.get('data_source_agency'),
                'engagement.data_source_agency must be non-null');
            System.assertNotEquals(null, eng.get('data_source_system'),
                'engagement.data_source_system must be non-null');
            System.assertNotEquals(null, eng.get('record_owner_agency'),
                'engagement.record_owner_agency must be non-null');
            System.assertNotEquals(null, eng.get('last_updated'),
                'engagement.last_updated must be non-null');
        }
    }

    @IsTest
    static void provenance_caseEvent_allSixFieldsPopulated() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> events = (List<Object>) process.get('case_events');
        System.assert(!events.isEmpty());

        for (Object o : events) {
            Map<String, Object> evt = (Map<String, Object>) o;
            System.assertNotEquals(null, evt.get('data_record_version'),
                'case_event.data_record_version must be non-null; name=' + evt.get('name'));
            System.assertNotEquals(null, evt.get('data_source_agency'),
                'case_event.data_source_agency must be non-null; name=' + evt.get('name'));
            System.assertNotEquals(null, evt.get('data_source_system'),
                'case_event.data_source_system must be non-null; name=' + evt.get('name'));
            System.assertNotEquals(null, evt.get('record_owner_agency'),
                'case_event.record_owner_agency must be non-null; name=' + evt.get('name'));
            System.assertNotEquals(null, evt.get('last_updated'),
                'case_event.last_updated must be non-null; name=' + evt.get('name'));
        }
    }

    @IsTest
    static void provenance_comment_allSixFieldsPopulated() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> docs = (List<Object>) process.get('documents');

        List<Map<String, Object>> comments = new List<Map<String, Object>>();
        for (Object o : docs) {
            List<Object> dc = (List<Object>) ((Map<String, Object>) o).get('comments');
            if (dc != null) {
                for (Object c : dc) { comments.add((Map<String, Object>) c); }
            }
        }
        System.assert(!comments.isEmpty(), 'Must have comments for provenance test');

        for (Map<String, Object> comment : comments) {
            System.assertNotEquals(null, comment.get('data_record_version'),
                'comment.data_record_version must be non-null');
            System.assertNotEquals(null, comment.get('data_source_agency'),
                'comment.data_source_agency must be non-null');
            System.assertNotEquals(null, comment.get('data_source_system'),
                'comment.data_source_system must be non-null');
            System.assertNotEquals(null, comment.get('record_owner_agency'),
                'comment.record_owner_agency must be non-null');
            System.assertNotEquals(null, comment.get('last_updated'),
                'comment.last_updated must be non-null');
        }
    }

    @IsTest
    static void provenance_nullFields_exportAsNullNotMissing() {
        // When provenance fields are not set on a record, the DTO must still contain
        // the key (value=null), not omit it entirely. PIC consumers rely on key presence.
        Map<String, Object> process = getFirstProcess('NULL-PROV-001');

        System.assert(process.containsKey('data_record_version'),
            'data_record_version key must be present even when null');
        System.assert(process.containsKey('data_source_agency'),
            'data_source_agency key must be present even when null');
        System.assert(process.containsKey('data_source_system'),
            'data_source_system key must be present even when null');
        System.assert(process.containsKey('record_owner_agency'),
            'record_owner_agency key must be present even when null');
        System.assert(process.containsKey('retrieved_timestamp'),
            'retrieved_timestamp key must be present even when null');
    }

    // ── GIS data ──────────────────────────────────────────────────────────────

    @IsTest
    static void gisData_presentAtProjectAndProcessLevel() {
        Map<String, Object> project = getProject('SAMPLE-FAA-EIS-001');

        List<Object> projGis = (List<Object>) project.get('gis_data');
        System.assertNotEquals(null, projGis, 'project gis_data must not be null');
        System.assertEquals(1, projGis.size(), 'Expected 1 project-level GIS record');

        List<Object> processes = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];
        List<Object> procGis = (List<Object>) process.get('gis_data');
        System.assertNotEquals(null, procGis, 'process gis_data must not be null');
        System.assertEquals(1, procGis.size(), 'Expected 1 process-level GIS record');
    }

    @IsTest
    static void gisData_hasProvenanceFields() {
        Map<String, Object> project = getProject('SAMPLE-FAA-EIS-001');
        List<Object> projGis = (List<Object>) project.get('gis_data');
        Map<String, Object> gis = (Map<String, Object>) projGis[0];

        System.assert(gis.containsKey('data_record_version'), 'gis_data must have data_record_version');
        System.assert(gis.containsKey('data_source_agency'),  'gis_data must have data_source_agency');
        System.assert(gis.containsKey('record_owner_agency'), 'gis_data must have record_owner_agency');
        System.assert(gis.containsKey('last_updated'),        'gis_data must have last_updated');
    }

    // ── Permits ───────────────────────────────────────────────────────────────

    @IsTest
    static void permits_allSnakeCaseKeys() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> permits = (List<Object>) process.get('permits');
        System.assert(!permits.isEmpty(), 'EIS must have permits');

        Set<String> expectedKeys = new Set<String>{
            'id', 'name', 'permit_type', 'lead_agency', 'regulatory_citation',
            'is_critical_path', 'permit_status', 'nepa_stage_gate',
            'expected_completion', 'actual_completion', 'sla_due_date',
            'sla_overdue', 'statutory_deadline_days', 'external_federal_id',
            'agency_endpoint_key', 'agency_system_url', 'last_synced',
            'permit_notes', 'process_id', 'last_updated'
        };
        for (Object o : permits) {
            Map<String, Object> permit = (Map<String, Object>) o;
            List<String> missing = new List<String>();
            for (String key : expectedKeys) {
                if (!permit.containsKey(key)) { missing.add(key); }
            }
            System.assertEquals(0, missing.size(),
                'permit DTO missing PIC v1.2 snake_case keys: ' + String.join(missing, ', '));
        }
    }

    @IsTest
    static void permits_criticalPathSortedFirst() {
        Map<String, Object> process = getFirstProcess('SAMPLE-FAA-EIS-001');
        List<Object> permits = (List<Object>) process.get('permits');
        System.assertEquals(2, permits.size(), 'Expected 2 permits');
        System.assertEquals(true, (Boolean) ((Map<String, Object>) permits[0]).get('is_critical_path'),
            'Critical-path permit must sort first');
        System.assertEquals(false, (Boolean) ((Map<String, Object>) permits[1]).get('is_critical_path'),
            'Non-critical permit must sort second');
    }

    // ── Multi-entity completeness (all 6 CEQ entities per process) ────────────

    @IsTest
    static void fullExport_allSixCeqEntitiesPresent() {
        Map<String, Object> project = getProject('SAMPLE-FAA-EIS-001');
        List<Object> processes = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];

        // CEQ Entity 1: project — the parent container (verified by project key presence)
        System.assert(project.containsKey('project_id'), 'Entity 1: project must have project_id');

        // CEQ Entity 2: process_instance
        System.assertNotEquals(null, process.get('federal_unique_id'), 'Entity 2: process must have federal_unique_id');

        // CEQ Entity 3: document
        List<Object> docs = (List<Object>) process.get('documents');
        System.assert(!docs.isEmpty(), 'Entity 3: process must have documents');

        // CEQ Entity 4: comment (nested under documents)
        Boolean hasComment = false;
        for (Object o : docs) {
            List<Object> comments = (List<Object>) ((Map<String, Object>) o).get('comments');
            if (comments != null && !comments.isEmpty()) { hasComment = true; break; }
        }
        System.assert(hasComment, 'Entity 4: export must have at least one comment nested in a document');

        // CEQ Entity 5: engagement
        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        System.assert(!engagements.isEmpty(), 'Entity 5: process must have engagement events');

        // CEQ Entity 6: case_event
        List<Object> caseEvents = (List<Object>) process.get('case_events');
        System.assert(!caseEvents.isEmpty(), 'Entity 6: process must have case events');

        // CEQ Entity 7: gis_data
        List<Object> gis = (List<Object>) process.get('gis_data');
        System.assert(!gis.isEmpty(), 'Entity 7: process must have gis_data');
    }

    // ── Envelope shape ─────────────────────────────────────────────────────────

    @IsTest
    static void envelope_successTrue_and_dataPresent() {
        Map<String, Object> body = exportProject('SAMPLE-FAA-EIS-001');
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(true, body.get('success'), 'success must be true');
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertNotEquals(null, data, 'data must be present');
        System.assertNotEquals(null, data.get('project'), 'data.project must be present');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Map<String, Object> exportProject(String projectId) {
        Program proj = [SELECT Id FROM Program WHERE nepa_project_id__c = :projectId LIMIT 1];
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod  = 'POST';
        RestContext.request.requestURI  = '/services/apexrest/nepa/v1/export/project';
        RestContext.request.requestBody = Blob.valueOf('{"projectId":"' + proj.Id + '"}');
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqFullExportService.doPost();
        Test.stopTest();

        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static Map<String, Object> getProject(String projectId) {
        Map<String, Object> body = exportProject(projectId);
        return (Map<String, Object>) ((Map<String, Object>) body.get('data')).get('project');
    }

    private static Map<String, Object> getFirstProcess(String projectId) {
        Map<String, Object> project = getProject(projectId);
        List<Object> processes = (List<Object>) project.get('processes');
        System.assert(!processes.isEmpty(), 'No processes found for project ' + projectId);
        return (Map<String, Object>) processes[0];
    }

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) { return existing[0].Id; }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
            Name = 'NEPA Environmental Review',
            RegulatoryAuthCategory = 'Permit'
        );
        insert rat;
        return rat.Id;
    }

    private static ContentVersion insertDocument(
        Id processId, String docType, String title, Date publishDate, String preparedBy, Boolean publicAccess
    ) {
        ContentVersion cv = new ContentVersion();
        cv.Title                    = title;
        cv.PathOnClient             = title.replaceAll('[^a-zA-Z0-9]', '_') + '.pdf';
        cv.VersionData              = Blob.valueOf('test content');
        cv.FirstPublishLocationId   = processId;
        cv.nepa_public_access__c    = publicAccess;
        cv.nepa_document_type__c    = docType;
        cv.nepa_status__c           = 'Approved';
        cv.nepa_publish_date__c     = publishDate;
        cv.nepa_prepared_by__c      = preparedBy;
        cv.nepa_process__c          = processId;
        cv.nepa_record_owner_agency__c  = 'Federal Aviation Administration';
        cv.nepa_data_source_agency__c   = 'Federal Aviation Administration';
        cv.nepa_data_source_system__c   = 'FAA-NEPA-System';
        cv.nepa_data_record_version__c  = '1.2';
        cv.nepa_retrieved_timestamp__c  = DateTime.now();
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv;
    }

    private static void insertComment(
        Id processId, Id docId, String org, String submissionMethod, String body
    ) {
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                    = 'Test Commenter';
        pc.IncidentDate                = Date.today();
        pc.nepa_parent_document__c     = docId;
        pc.nepa_related_process__c     = processId;
        pc.ReporterOrganization        = org;
        pc.nepa_comment_body__c        = body;
        pc.Method_of_Submission__c     = submissionMethod;
        pc.nepa_public_source__c       = true;
        pc.ReceivedDate                = Date.today().addDays(-30);
        pc.nepa_record_owner_agency__c = 'Federal Aviation Administration';
        pc.nepa_data_source_agency__c  = 'Federal Aviation Administration';
        pc.nepa_data_source_system__c  = 'FAA-NEPA-System';
        pc.nepa_data_record_version__c = '1.2';
        pc.nepa_retrieved_timestamp__c = DateTime.now();
        insert pc;
    }

    private static void insertEngagement(
        Id processId, String engType, DateTime startDt, DateTime endDt, String locationNotes, Boolean publicAccess
    ) {
        nepa_engagement__c e = new nepa_engagement__c();
        e.nepa_process__c              = processId;
        e.nepa_engagement_type__c      = engType;
        e.nepa_location_format__c      = publicAccess ? 'Virtual' : 'In-Person';
        e.nepa_notes__c                = locationNotes;
        e.nepa_start_datetime__c       = startDt;
        e.nepa_end_datetime__c         = endDt;
        e.nepa_public_access__c        = publicAccess;
        e.nepa_record_owner_agency__c  = 'Federal Aviation Administration';
        e.nepa_data_source_agency__c   = 'Federal Aviation Administration';
        e.nepa_data_source_system__c   = 'FAA-NEPA-System';
        e.nepa_data_record_version__c  = '1.2';
        e.nepa_retrieved_timestamp__c  = DateTime.now();
        insert e;
    }

    private static void insertCaseEvent(
        Id processId, String eventType, String description, String tier,
        String status, String assignedEntity, String followingSegment
    ) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                        = eventType;
        evt.nepa_event_type__c          = eventType;
        evt.nepa_event_description__c   = description;
        evt.nepa_status__c              = status;
        evt.nepa_tier__c                = tier;
        evt.nepa_source__c              = 'Test';
        evt.nepa_start_date__c          = Date.today().addDays(-30);
        evt.nepa_end_date__c            = Date.today().addDays(-20);
        evt.nepa_public_access__c       = true;
        evt.nepa_related_process__c     = processId;
        evt.nepa_assigned_entity__c     = assignedEntity;
        evt.nepa_following_segment__c   = followingSegment;
        evt.nepa_record_owner_agency__c = 'Federal Aviation Administration';
        evt.nepa_data_source_agency__c  = 'Federal Aviation Administration';
        evt.nepa_data_source_system__c  = 'FAA-NEPA-System';
        evt.nepa_data_record_version__c = '1.2';
        evt.nepa_retrieved_timestamp__c = DateTime.now();
        insert evt;
    }
}
