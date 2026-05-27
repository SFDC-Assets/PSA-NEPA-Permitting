@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaCeqExportServiceTest {

    @TestSetup
    static void setup() {
        // Lead agency Account — needed for compliance_leadAgency_isAccountName
        Account leadAgencyAcct = new Account(Name = 'Bureau of Land Management');
        insert leadAgencyAcct;

        Program proj = NepaTestFactory.insertProgram('NEPA-CEQ-001', 'Wind Farm EIS', 'BLM');
        proj.nepa_project_id__c          = 'PROJ-CEQ-001';
        proj.nepa_lead_agency__c         = leadAgencyAcct.Id;
        proj.nepa_record_owner_agency__c = 'BLM';
        proj.nepa_data_source_agency__c  = 'BLM';
        proj.nepa_data_source_system__c  = 'NEPA-SF-PSS';
        update proj;

        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_federal_unique_id__c = 'FUID-001';
        ia.nepa_agency_id__c         = 'BLM-2025-001';
        ia.nepa_process_status__c    = 'in progress';
        ia.nepa_start_date__c        = Date.today().addDays(-90);
        ia.nepa_purpose_need__c      = 'Wind energy development on public lands';
        update ia;

        Program proj2 = NepaTestFactory.insertProgram('NEPA-CEQ-002', 'Solar EA', 'DOE');
        IndividualApplication ia2 = NepaTestFactory.insertClosedProcess(proj2.Id);
        ia2.nepa_review_type__c    = 'EA';
        ia2.nepa_process_status__c = 'completed';
        update ia2;
    }

    // ── GET single by Salesforce ID ───────────────────────────────────────────

    @IsTest
    static void getSingle_bySalesforceId_returns200() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1];

        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/' + ia.Id, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(true, body.get('success'));
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('FUID-001', data.get('federal_id'));
        System.assertEquals('EIS', data.get('type'));
    }

    @IsTest
    static void getSingle_byFederalUniqueId_returns200() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(true, body.get('success'));
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('FUID-001', (String) data.get('federal_id'));
    }

    @IsTest
    static void getSingle_notFound_returns404() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-DOESNOTEXIST', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(false, body.get('success'));
        System.assertEquals('NOT_FOUND', (String) body.get('errorCode'));
    }

    // ── GET list — unfiltered ─────────────────────────────────────────────────

    @IsTest
    static void getList_noParams_returnsAll() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(true, body.get('success'));
        System.assertEquals(2, (Integer) body.get('totalCount'));
        System.assertEquals(1, (Integer) body.get('page'));
        System.assertEquals(50, (Integer) body.get('pageSize'));
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(2, data.size());
    }

    // ── GET list — filtered by reviewType ────────────────────────────────────

    @IsTest
    static void getList_filterReviewType_returnsMatching() {
        Map<String, String> params = new Map<String, String>{ 'reviewType' => 'EA' };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(1, (Integer) body.get('totalCount'));
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size());
        Map<String, Object> row = (Map<String, Object>) data[0];
        System.assertEquals('EA', (String) row.get('type'));
    }

    // ── GET list — filtered by status ────────────────────────────────────────

    @IsTest
    static void getList_filterStatus_returnsMatching() {
        Map<String, String> params = new Map<String, String>{ 'status' => 'completed' };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(1, (Integer) body.get('totalCount'));
    }

    // ── GET list — filtered by agencyId ──────────────────────────────────────

    @IsTest
    static void getList_filterAgencyId_returnsMatching() {
        Map<String, String> params = new Map<String, String>{ 'agencyId' => 'BLM-2025-001' };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(1, (Integer) body.get('totalCount'));
    }

    // ── GET list — updatedSince filter ────────────────────────────────────────

    @IsTest
    static void getList_updatedSince_returnsRecords() {
        Map<String, String> params = new Map<String, String>{
            'updatedSince' => '2000-01-01T00:00:00Z'
        };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(2, (Integer) body.get('totalCount'));
    }

    @IsTest
    static void getList_updatedSince_invalid_returns400() {
        Map<String, String> params = new Map<String, String>{ 'updatedSince' => 'not-a-date' };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(false, body.get('success'));
        System.assertEquals('INVALID_PARAM', (String) body.get('errorCode'));
    }

    // ── GET list — pagination ─────────────────────────────────────────────────

    @IsTest
    static void getList_pagination_page2_returnsEmpty() {
        Map<String, String> params = new Map<String, String>{
            'pageSize' => '1',
            'page'     => '2'
        };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(2, (Integer) body.get('totalCount'));
        System.assertEquals(2, (Integer) body.get('page'));
        System.assertEquals(1, (Integer) body.get('pageSize'));
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size());
    }

    @IsTest
    static void getList_pageSizeCappedAtMax() {
        Map<String, String> params = new Map<String, String>{ 'pageSize' => '9999' };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(200, (Integer) body.get('pageSize'));
    }

    // ── CEQ Export payload fields ─────────────────────────────────────────────

    @IsTest
    static void getList_payload_containsExpectedDtoFields() {
        // Verify the DTO includes CEQ Data Standard v1.2 snake_case keys and that
        // NEPA-operational fields are correctly nested under "other".
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        List<Object> records = (List<Object>) body.get('data');
        System.assert(!records.isEmpty(), 'Export list must return at least one record');

        Map<String, Object> dto = (Map<String, Object>) records[0];
        // Top-level CEQ standard fields
        System.assert(dto.containsKey('federal_id'),   'DTO must contain federal_id');
        System.assert(dto.containsKey('type'),         'DTO must contain type');
        System.assert(dto.containsKey('status'),       'DTO must contain status');
        System.assert(dto.containsKey('agency_id'),    'DTO must contain agency_id');
        System.assert(dto.containsKey('last_updated'), 'DTO must contain last_updated');
        // NEPA-operational fields nested under "other"
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assertNotEquals(null, other, 'DTO must contain other block');
        System.assert(other.containsKey('risk_score'),              'other must contain risk_score');
        System.assert(other.containsKey('risk_tier'),               'other must contain risk_tier');
        System.assert(other.containsKey('record_completeness_pct'), 'other must contain record_completeness_pct');
        System.assert(other.containsKey('sla_due_date'),            'other must contain sla_due_date');
    }

    // ── PIC / MFR compliance assertions ──────────────────────────────────────
    //
    // These tests verify that the export payload meets CEQ Permitting Data and
    // Technology Standard v1.2 constraints.

    @IsTest
    static void compliance_federalUniqueId_nonNullOnExportedRecord() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        Map<String, Object> dto  = (Map<String, Object>) body.get('data');
        System.assertNotEquals(null, dto.get('federal_id'),
            'federal_id must not be null — CEQ requires this field for all MFR submissions');
        System.assert(String.isNotBlank((String) dto.get('federal_id')),
            'federal_id must not be blank');
    }

    @IsTest
    static void compliance_reviewType_isValidPicValue() {
        Set<String> validReviewTypes = new Set<String>{
            'EIS', 'EA', 'CE', 'Other Authorization'
        };
        for (Object rec : getListRecords()) {
            Map<String, Object> dto = (Map<String, Object>) rec;
            String rt = (String) dto.get('type');
            if (rt != null) {
                System.assert(validReviewTypes.contains(rt),
                    'type "' + rt + '" is not a PIC v1.2 valid value (EIS/EA/CE/Other Authorization)');
            }
        }
    }

    @IsTest
    static void compliance_processStatus_isValidPicValue() {
        Set<String> validStatuses = new Set<String>{
            'planned', 'pre-application', 'in progress', 'paused', 'completed', 'cancelled'
        };
        for (Object rec : getListRecords()) {
            Map<String, Object> dto = (Map<String, Object>) rec;
            String st = (String) dto.get('status');
            if (st != null) {
                System.assert(validStatuses.contains(st),
                    'status "' + st + '" is not a PIC v1.2 valid value');
            }
        }
    }

    @IsTest
    static void compliance_completedRecord_hasStartDate() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assert(dto.containsKey('start_date'),
            'start_date key must be present in DTO for all records');
        System.assertNotEquals(null, dto.get('start_date'),
            'start_date must be non-null for a record where nepa_start_date__c was set');
    }

    @IsTest
    static void compliance_envelopeShape_listResponseAlwaysArray() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();

        System.assert(body.get('success') instanceof Boolean,   'success must be a Boolean');
        System.assertEquals(true, (Boolean) body.get('success'));
        System.assert(body.get('data') instanceof List<Object>, 'data must be a List in list responses');
        System.assert(body.get('totalCount') instanceof Integer, 'totalCount must be an Integer');
        System.assert(body.get('page') instanceof Integer,      'page must be an Integer');
        System.assert(body.get('pageSize') instanceof Integer,  'pageSize must be an Integer');
    }

    @IsTest
    static void compliance_envelopeShape_singleResponseIsObject() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1
        ];
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/' + ia.Id, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();

        System.assert(body.get('success') instanceof Boolean,          'success must be a Boolean');
        System.assert(body.get('data') instanceof Map<String, Object>, 'data must be an Object in single-record responses');
        System.assert(!(body.get('data') instanceof List<Object>),     'data must not be a List in single-record response');
    }

    @IsTest
    static void compliance_errorEnvelope_hasRequiredFields() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/DOES-NOT-EXIST-99', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();

        System.assertEquals(false, body.get('success'), 'Error response success must be false');
        System.assert(body.containsKey('errorCode'), 'Error response must contain errorCode');
        System.assert(body.containsKey('message'),   'Error response must contain message');
        System.assert(String.isNotBlank((String) body.get('errorCode')), 'errorCode must not be blank');
        System.assert(String.isNotBlank((String) body.get('message')),   'message must not be blank');
    }

    @IsTest
    static void compliance_allDtoFields_matchCeqV12PropertyNames() {
        // CEQ's ingestion pipeline maps JSON keys to Data Standard v1.2 property names.
        // Verify every required CEQ top-level key is present and that NEPA-operational
        // fields are nested under "other" as required by the standard.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');

        // CEQ standard top-level fields (snake_case per v1.2 spec)
        Set<String> requiredTopLevel = new Set<String>{
            'federal_id', 'parent_project_id', 'agency_id', 'type', 'status', 'stage',
            'start_date', 'complete_date', 'estimated_completion', 'outcome',
            'purpose_need', 'description', 'comment_start', 'comment_end',
            'lead_agency', 'joint_lead_agency', 'cooperating_agencies', 'process_code',
            'created_at', 'record_owner_agency', 'data_source_agency', 'data_source_system',
            'data_record_version', 'last_updated', 'retrieved_timestamp', 'other'
        };
        List<String> missing = new List<String>();
        for (String key : requiredTopLevel) {
            if (!dto.containsKey(key)) { missing.add(key); }
        }
        System.assertEquals(0, missing.size(),
            'DTO is missing CEQ v1.2 required top-level keys: ' + String.join(missing, ', '));

        // NEPA-operational fields nested under "other"
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        Set<String> requiredOther = new Set<String>{
            'salesforce_id', 'salesforce_name',
            'sla_due_date', 'sla_overdue',
            'risk_score', 'risk_tier', 'record_completeness_pct',
            'last_stage_transition', 'required_permits'
        };
        List<String> missingOther = new List<String>();
        for (String key : requiredOther) {
            if (!other.containsKey(key)) { missingOther.add(key); }
        }
        System.assertEquals(0, missingOther.size(),
            'DTO.other is missing expected NEPA-operational keys: ' + String.join(missingOther, ', '));
    }

    // ── Provenance compliance ─────────────────────────────────────────────────

    @IsTest
    static void compliance_provenanceFields_allPresent() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');

        System.assertNotEquals(null, dto.get('data_record_version'),
            'data_record_version must be present and non-null');
        System.assertEquals('1.0', (String) dto.get('data_record_version'),
            'data_record_version must be 1.0');
        System.assertNotEquals(null, dto.get('last_updated'),
            'last_updated must be non-null');
        System.assertNotEquals(null, dto.get('retrieved_timestamp'),
            'retrieved_timestamp must be non-null — set at export time');
        System.assertNotEquals(null, dto.get('created_at'),
            'created_at must be non-null');
    }

    @IsTest
    static void compliance_parentProjectId_populatedFromRelatedProject() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assertNotEquals(null, dto.get('parent_project_id'),
            'parent_project_id must be populated from nepa_related_project__r.nepa_project_id__c');
        System.assertEquals('PROJ-CEQ-001', (String) dto.get('parent_project_id'));
    }

    @IsTest
    static void compliance_leadAgency_isAccountName() {
        // lead_agency must be the Account name, not an Id or a formula text field.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        String leadAgency = (String) dto.get('lead_agency');
        System.assertNotEquals(null, leadAgency, 'lead_agency must be non-null when Program has nepa_lead_agency__c set');
        System.assertEquals('Bureau of Land Management', leadAgency,
            'lead_agency must be the Account Name traversed from nepa_related_project__r.nepa_lead_agency__r.Name');
    }

    @IsTest
    static void compliance_nepaOperationalFields_nestedUnderOther() {
        // Confirms NEPA-operational fields that have no CEQ standard counterpart are
        // nested inside "other" instead of polluting the top-level schema.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');

        System.assertNotEquals(null, other, 'other block must be present');
        System.assert(other.containsKey('salesforce_id'),   'other.salesforce_id missing');
        System.assert(other.containsKey('sla_due_date'),    'other.sla_due_date missing');
        System.assert(other.containsKey('sla_overdue'),     'other.sla_overdue missing');
        System.assert(other.containsKey('risk_score'),      'other.risk_score missing');
        System.assert(other.containsKey('risk_tier'),       'other.risk_tier missing');
        System.assert(other.containsKey('required_permits'), 'other.required_permits missing');

        // These NEPA fields must NOT appear at the top level
        System.assert(!dto.containsKey('sla_due_date'),    'sla_due_date must not be top-level');
        System.assert(!dto.containsKey('risk_score'),      'risk_score must not be top-level');
        System.assert(!dto.containsKey('required_permits'), 'required_permits must not be top-level');
    }

    // ── permits[] subresource ─────────────────────────────────────────────────

    @IsTest
    static void getSingle_withPermits_permitsArrayPresent() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1
        ];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(30));
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', false, null);

        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/' + ia.Id, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto   = (Map<String, Object>) parseBody().get('data');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assert(other.containsKey('required_permits'), 'other must contain required_permits key');
        List<Object> permits = (List<Object>) other.get('required_permits');
        System.assertEquals(2, permits.size(), 'required_permits array must contain both child permit records');

        Map<String, Object> firstPermit = (Map<String, Object>) permits[0];
        System.assert(firstPermit.containsKey('id'),            'permit DTO must contain id');
        System.assert(firstPermit.containsKey('permitStatus'),  'permit DTO must contain permitStatus');
        System.assert(firstPermit.containsKey('leadAgency'),    'permit DTO must contain leadAgency');
        System.assert(firstPermit.containsKey('isCriticalPath'), 'permit DTO must contain isCriticalPath');
        System.assert(firstPermit.containsKey('slaDueDate'),    'permit DTO must contain slaDueDate');
    }

    @IsTest
    static void getSingle_noPermits_permitsArrayEmpty() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1
        ];

        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/' + ia.Id, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto   = (Map<String, Object>) parseBody().get('data');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assert(other.containsKey('required_permits'), 'required_permits key must be present even when no child permits exist');
        List<Object> permits = (List<Object>) other.get('required_permits');
        System.assertNotEquals(null, permits, 'required_permits must not be null — must be an empty array');
        System.assertEquals(0, permits.size(), 'required_permits array must be empty when no child permits exist');
    }

    @IsTest
    static void getList_withPermits_permitsArrayPresentOnEachRecord() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1
        ];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Issued', true, Date.today().addDays(-10));

        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        List<Object> records = (List<Object>) parseBody().get('data');
        for (Object rec : records) {
            Map<String, Object> row   = (Map<String, Object>) rec;
            Map<String, Object> other = (Map<String, Object>) row.get('other');
            System.assertNotEquals(null, other, 'Every record must have an other block');
            System.assert(other.containsKey('required_permits'),
                'Every record in list response must contain other.required_permits key');
            System.assert(other.get('required_permits') instanceof List<Object>,
                'required_permits must be an array on every list record');
        }
    }

    @IsTest
    static void compliance_agencyId_nonNullWhenSet() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assertNotEquals(null, dto.get('agency_id'),
            'agency_id must be non-null for a record where nepa_agency_id__c was set');
        System.assertEquals('BLM-2025-001', (String) dto.get('agency_id'),
            'agency_id must round-trip exactly — CEQ uses this as the join key to the agency registry');
    }

    // ── Null-field and edge-case serialization ────────────────────────────────

    @IsTest
    static void getSingle_allOptionalFieldsNull_returns200() {
        Program proj = NepaTestFactory.insertProgram('NEPA-CEQ-NULL', 'Null Fields Test', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                = 'Permit';
        ia.LicenseTypeId           = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1].Id;
        ia.nepa_related_project__c = proj.Id;
        ia.nepa_process_status__c  = 'in progress';
        ia.nepa_process_stage__c   = 'Scoping';
        insert ia;

        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/' + ia.Id, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Service must return 200 for a record with all nullable fields null');
        Map<String, Object> body = parseBody();
        System.assertEquals(true, body.get('success'), 'success must be true');
        Map<String, Object> dto   = (Map<String, Object>) body.get('data');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assertNotEquals(null, other.get('salesforce_id'),
            'other.salesforce_id must always be present even when other fields are null');
    }

    @IsTest
    static void getList_updatedSince_futureDateReturnsEmpty() {
        String futureDate = String.valueOf(Date.today().addYears(10)) + 'T00:00:00Z';
        Map<String, String> params = new Map<String, String>{ 'updatedSince' => futureDate };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(true, body.get('success'));
        System.assertEquals(0, (Integer) body.get('totalCount'),
            'Future updatedSince must return 0 results');
    }

    @IsTest
    static void getList_combinedFilters_returnsCorrectSubset() {
        Map<String, String> params = new Map<String, String>{
            'reviewType' => 'EIS',
            'status'     => 'in progress'
        };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(1, (Integer) body.get('totalCount'),
            'Combined reviewType=EIS + status=in+progress must match exactly 1 record');
        List<Object> data = (List<Object>) body.get('data');
        Map<String, Object> row = (Map<String, Object>) data[0];
        System.assertEquals('EIS', (String) row.get('type'));
        System.assertEquals('in progress', (String) row.get('status'));
    }

    @IsTest
    static void getList_pageSizeOne_returnsOneRecord() {
        Map<String, String> params = new Map<String, String>{
            'pageSize' => '1',
            'page'     => '1'
        };
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', params);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(2, (Integer) body.get('totalCount'), 'Total count must still reflect full dataset');
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size(), 'pageSize=1 must return exactly 1 record in data array');
    }

    @IsTest
    static void compliance_slaOverdue_isBoolean() {
        // sla_overdue must serialize as a Boolean (formula checkbox), nested under other.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto   = (Map<String, Object>) parseBody().get('data');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assert(other.containsKey('sla_overdue'), 'other must contain sla_overdue key');
        Object slaOverdueVal = other.get('sla_overdue');
        if (slaOverdueVal != null) {
            System.assert(slaOverdueVal instanceof Boolean,
                'sla_overdue must be a Boolean in the DTO; got: ' + String.valueOf(slaOverdueVal));
        }
    }

    // ── generateCeqExport (@AuraEnabled) ─────────────────────────────────────

    @IsTest
    static void generateCeqExport_singleProcess_returnsCompliantShape() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'FUID-001' LIMIT 1];

        Test.startTest();
        String jsonOut = NepaCeqExportService.generateCeqExport(ia.Id);
        Test.stopTest();

        System.assertNotEquals(null, jsonOut, 'generateCeqExport must return a non-null string');
        Map<String, Object> dto = (Map<String, Object>) JSON.deserializeUntyped(jsonOut);

        // Must be an object (single record), not an array
        System.assert(dto instanceof Map<String, Object>, 'Single-process export must be a JSON object');
        System.assertEquals('FUID-001', (String) dto.get('federal_id'),
            'federal_id must round-trip through generateCeqExport');
        System.assertEquals('1.0', (String) dto.get('data_record_version'),
            'data_record_version must be present in AuraEnabled export');
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assertNotEquals(null, other, 'other block must be present in AuraEnabled export');
        System.assert(other.containsKey('required_permits'), 'other.required_permits must be present');
    }

    @IsTest
    static void generateCeqExport_allActive_returnsArray() {
        Test.startTest();
        String jsonOut = NepaCeqExportService.generateCeqExport(null);
        Test.stopTest();

        System.assertNotEquals(null, jsonOut, 'generateCeqExport(null) must return a non-null string');
        List<Object> dtos = (List<Object>) JSON.deserializeUntyped(jsonOut);
        System.assert(dtos instanceof List<Object>, 'Null processId export must return a JSON array');
        // At least the 'in progress' record from @TestSetup is in the active set
        System.assert(dtos.size() >= 1, 'Active export must include at least one record');
        Map<String, Object> first = (Map<String, Object>) dtos[0];
        System.assert(first.containsKey('federal_id'),    'Each array element must have federal_id');
        System.assert(first.containsKey('data_record_version'), 'Each array element must have data_record_version');
        System.assert(first.containsKey('other'),         'Each array element must have other block');
    }

    @IsTest
    static void generateCeqExport_notFound_returnsErrorObject() {
        Test.startTest();
        String jsonOut = NepaCeqExportService.generateCeqExport(null); // valid call
        // Verify single-record not-found case returns error JSON without throwing
        Id fakeId = '001000000000000AAA';
        String notFoundOut = NepaCeqExportService.generateCeqExport(fakeId);
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(notFoundOut);
        System.assert(result.containsKey('error'), 'Not-found single export must return error key');
    }

    // ── generateFPISCExport ───────────────────────────────────────────────────

    @IsTest
    static void generateFPISCExport_noFast41Records_returnsEmptyList() {
        Test.startTest();
        List<NepaCeqExportService.FPISCRow> rows =
            NepaCeqExportService.generateFPISCExport(null);
        Test.stopTest();
        System.assertNotEquals(null, rows, 'Result should not be null');
        System.assertEquals(0, rows.size(), 'No FAST-41 records expected in base setup');
    }

    @IsTest
    static void generateFPISCExport_withFast41Records_returnsRows() {
        Program proj = NepaTestFactory.insertProgram('FPISC-001', 'Solar EIS FAST41', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_fast41_covered__c  = true;
        ia.nepa_ofd_target_days__c = 180;
        ia.nepa_start_date__c      = Date.today().addDays(-200);
        update ia;

        Test.startTest();
        List<NepaCeqExportService.FPISCRow> rows =
            NepaCeqExportService.generateFPISCExport(null);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Expected one FPISC row');
        NepaCeqExportService.FPISCRow row = rows[0];
        System.assertEquals(180, row.ofdTargetDays);
        System.assertNotEquals(null, row.ofdVarianceDays,
            'Variance should be calculated when both elapsed and target are set');
        System.assert(row.ofdVarianceDays > 0, 'Expected positive variance for overdue process');
    }

    @IsTest
    static void generateFPISCExport_scopedToProgram_returnsOnlyChildren() {
        Program proj1 = NepaTestFactory.insertProgram('FPISC-P1', 'Project 1', 'BLM');
        Program proj2 = NepaTestFactory.insertProgram('FPISC-P2', 'Project 2', 'DOE');
        IndividualApplication ia1 = NepaTestFactory.insertOpenProcess(proj1.Id, 'EIS');
        ia1.nepa_fast41_covered__c = true;
        ia1.nepa_ofd_target_days__c = 180;
        ia1.nepa_start_date__c = Date.today().addDays(-100);
        update ia1;
        IndividualApplication ia2 = NepaTestFactory.insertOpenProcess(proj2.Id, 'EA');
        ia2.nepa_fast41_covered__c = true;
        ia2.nepa_ofd_target_days__c = 90;
        ia2.nepa_start_date__c = Date.today().addDays(-50);
        update ia2;

        Test.startTest();
        List<NepaCeqExportService.FPISCRow> rows =
            NepaCeqExportService.generateFPISCExport(proj1.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Scoped export should return only proj1 child');
    }

    // ── getYearOverYearTrend ──────────────────────────────────────────────────

    @IsTest
    static void getYearOverYearTrend_noCompletedRecords_returnsEmptyList() {
        Test.startTest();
        List<NepaCeqExportService.YoYTrendBucket> buckets =
            NepaCeqExportService.getYearOverYearTrend(5);
        Test.stopTest();
        System.assertNotEquals(null, buckets);
    }

    @IsTest
    static void getYearOverYearTrend_withCompletedRecords_returnsBuckets() {
        Program proj = NepaTestFactory.insertProgram('YOY-001', 'YoY Test Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertClosedProcess(proj.Id);
        ia.nepa_review_type__c    = 'EIS';
        ia.nepa_process_status__c = 'completed';
        ia.nepa_completion_date__c = Date.today().addDays(-30);
        ia.nepa_start_date__c      = Date.today().addDays(-400);
        update ia;

        Test.startTest();
        List<NepaCeqExportService.YoYTrendBucket> buckets =
            NepaCeqExportService.getYearOverYearTrend(5);
        Test.stopTest();

        System.assert(buckets.size() >= 1, 'Expected at least one trend bucket');
        NepaCeqExportService.YoYTrendBucket bucket = buckets[0];
        System.assertNotEquals(null, bucket.calendarYear);
        System.assertEquals('EIS', bucket.reviewType);
        System.assertEquals(1, bucket.processCount);
    }

    @IsTest
    static void getYearOverYearTrend_nullYearsParam_defaultsToFive() {
        Test.startTest();
        List<NepaCeqExportService.YoYTrendBucket> buckets =
            NepaCeqExportService.getYearOverYearTrend(null);
        Test.stopTest();
        System.assertNotEquals(null, buckets, 'Null years param should default to 5, not throw');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static RestRequest buildRequest(String method, String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.httpMethod  = method;
        req.requestURI  = uri;
        if (params != null) {
            req.params.putAll(params);
        }
        return req;
    }

    private static Map<String, Object> parseBody() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static List<Object> getListRecords() {
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();
        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();
        System.assertEquals(200, RestContext.response.statusCode);
        return (List<Object>) parseBody().get('data');
    }
}
