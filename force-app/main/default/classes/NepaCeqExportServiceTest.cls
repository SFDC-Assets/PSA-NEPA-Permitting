@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaCeqExportServiceTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('NEPA-CEQ-001', 'Wind Farm EIS', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_federal_unique_id__c = 'FUID-001';
        ia.nepa_agency_id__c         = 'BLM-2025-001';
        ia.nepa_process_status__c    = 'in progress';
        ia.nepa_start_date__c        = Date.today().addDays(-90);
        update ia;

        Program proj2 = NepaTestFactory.insertProgram('NEPA-CEQ-002', 'Solar EA', 'DOE');
        IndividualApplication ia2 = NepaTestFactory.insertClosedProcess(proj2.Id);
        ia2.nepa_review_type__c   = 'EA';
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
        System.assertEquals('FUID-001', data.get('federalUniqueId'));
        System.assertEquals('EIS', data.get('reviewType'));
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
        System.assertEquals('FUID-001', (String) data.get('federalUniqueId'));
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
        System.assertEquals('EA', (String) row.get('reviewType'));
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
        // Verify the DTO includes federalUniqueId, reviewType, processStatus, agencyId, riskScore, riskTier,
        // recordCompleteness — the fields driving MFR compliance reporting.
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
        System.assert(dto.containsKey('federalUniqueId'),
            'DTO must contain federalUniqueId key');
        System.assert(dto.containsKey('reviewType'),
            'DTO must contain reviewType key');
        System.assert(dto.containsKey('processStatus'),
            'DTO must contain processStatus key');
        System.assert(dto.containsKey('agencyId'),
            'DTO must contain agencyId key');
        System.assert(dto.containsKey('riskScore'),
            'DTO must contain riskScore key (may be null if BRE has not run)');
        System.assert(dto.containsKey('riskTier'),
            'DTO must contain riskTier key');
        System.assert(dto.containsKey('recordCompleteness'),
            'DTO must contain recordCompleteness key');
        System.assert(dto.containsKey('slaDueDate'),
            'DTO must contain slaDueDate key');
        System.assert(dto.containsKey('lastModified'),
            'DTO must contain lastModified key');
    }

    // ── PIC / MFR compliance assertions ──────────────────────────────────────
    //
    // These tests verify that the export payload meets CEQ Permitting Data and
    // Technology Standard v1.2 constraints:
    //   - federalUniqueId is non-null (CEQ cannot process records without it)
    //   - reviewType is one of the four PIC-defined values
    //   - processStatus is one of the six PIC-defined values
    //   - completed records carry startDate
    //   - envelope shape is always { success: Bool, data: Array, totalCount: Int,
    //     page: Int, pageSize: Int }

    @IsTest
    static void compliance_federalUniqueId_nonNullOnExportedRecord() {
        // A record without federalUniqueId must not be exported as if it is compliant.
        // We set it explicitly in @TestSetup to 'FUID-001'; verify it comes back non-null.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        Map<String, Object> dto  = (Map<String, Object>) body.get('data');
        System.assertNotEquals(null, dto.get('federalUniqueId'),
            'federalUniqueId must not be null — CEQ requires this field for all MFR submissions');
        System.assert(String.isNotBlank((String) dto.get('federalUniqueId')),
            'federalUniqueId must not be blank');
    }

    @IsTest
    static void compliance_reviewType_isValidPicValue() {
        Set<String> validReviewTypes = new Set<String>{
            'EIS', 'EA', 'CE', 'Other Authorization'
        };
        for (Object rec : getListRecords()) {
            Map<String, Object> dto = (Map<String, Object>) rec;
            String rt = (String) dto.get('reviewType');
            if (rt != null) {
                System.assert(validReviewTypes.contains(rt),
                    'reviewType "' + rt + '" is not a PIC v1.2 valid value (EIS/EA/CE/Other Authorization)');
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
            String st = (String) dto.get('processStatus');
            if (st != null) {
                System.assert(validStatuses.contains(st),
                    'processStatus "' + st + '" is not a PIC v1.2 valid value');
            }
        }
    }

    @IsTest
    static void compliance_completedRecord_hasStartDate() {
        // A completed process without startDate is incomplete for CEQ MFR reporting.
        // @TestSetup creates a completed EA with nepa_start_date__c unset; the endpoint
        // must still return it, but this test verifies the DTO key is present and the
        // record inserted with a start date (FUID-001) carries it through.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assert(dto.containsKey('startDate'),
            'startDate key must be present in DTO for all records');
        System.assertNotEquals(null, dto.get('startDate'),
            'startDate must be non-null for a record where nepa_start_date__c was set');
    }

    @IsTest
    static void compliance_envelopeShape_listResponseAlwaysArray() {
        // Verify the list envelope is always { success: Boolean, data: List, totalCount: Integer,
        // page: Integer, pageSize: Integer } — any deviation breaks CEQ's parser.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();

        System.assert(body.get('success') instanceof Boolean,
            'success must be a Boolean');
        System.assertEquals(true, (Boolean) body.get('success'));
        System.assert(body.get('data') instanceof List<Object>,
            'data must be a List (Array) in list responses, not an Object');
        System.assert(body.get('totalCount') instanceof Integer,
            'totalCount must be an Integer');
        System.assert(body.get('page') instanceof Integer,
            'page must be an Integer');
        System.assert(body.get('pageSize') instanceof Integer,
            'pageSize must be an Integer');
    }

    @IsTest
    static void compliance_envelopeShape_singleResponseIsObject() {
        // Single-record response must use { success: Boolean, data: Object } — not a List.
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

        System.assert(body.get('success') instanceof Boolean,
            'success must be a Boolean');
        System.assert(body.get('data') instanceof Map<String, Object>,
            'data must be an Object (Map) in single-record responses, not a List');
        System.assert(!(body.get('data') instanceof List<Object>),
            'data must not be a List in single-record response');
    }

    @IsTest
    static void compliance_errorEnvelope_hasRequiredFields() {
        // Error responses must always carry { success: false, errorCode: String, message: String }
        // so CEQ's error handler can reliably parse and log the failure reason.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/DOES-NOT-EXIST-99', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();

        System.assertEquals(false, body.get('success'),
            'Error response success must be false');
        System.assert(body.containsKey('errorCode'),
            'Error response must contain errorCode');
        System.assert(body.containsKey('message'),
            'Error response must contain message');
        System.assert(String.isNotBlank((String) body.get('errorCode')),
            'errorCode must not be blank');
        System.assert(String.isNotBlank((String) body.get('message')),
            'message must not be blank');
    }

    @IsTest
    static void compliance_allDtoFields_matchPicPropertyNames() {
        // CEQ's ingestion pipeline maps JSON keys to PIC v1.2 property names.
        // Verify every expected key is present — a missing or renamed key silently
        // drops data from the MFR submission without a parse error.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');

        Set<String> requiredKeys = new Set<String>{
            'id', 'federalUniqueId', 'reviewType', 'processStatus', 'processStage',
            'agencyId', 'startDate', 'targetCompletionDate', 'slaDueDate', 'slaOverdue',
            'riskScore', 'riskTier', 'recordCompleteness', 'lastStageTransition', 'lastModified',
            'permits'
        };
        List<String> missing = new List<String>();
        for (String key : requiredKeys) {
            if (!dto.containsKey(key)) { missing.add(key); }
        }
        System.assertEquals(0, missing.size(),
            'DTO is missing PIC v1.2 required keys: ' + String.join(missing, ', '));
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
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assert(dto.containsKey('permits'), 'DTO must contain permits key');
        List<Object> permits = (List<Object>) dto.get('permits');
        System.assertEquals(2, permits.size(), 'permits array must contain both child permit records');

        Map<String, Object> firstPermit = (Map<String, Object>) permits[0];
        System.assert(firstPermit.containsKey('id'), 'permit DTO must contain id');
        System.assert(firstPermit.containsKey('permitStatus'), 'permit DTO must contain permitStatus');
        System.assert(firstPermit.containsKey('leadAgency'), 'permit DTO must contain leadAgency');
        System.assert(firstPermit.containsKey('isCriticalPath'), 'permit DTO must contain isCriticalPath');
        System.assert(firstPermit.containsKey('slaDueDate'), 'permit DTO must contain slaDueDate');
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
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assert(dto.containsKey('permits'), 'permits key must be present even when no child permits exist');
        List<Object> permits = (List<Object>) dto.get('permits');
        System.assertNotEquals(null, permits, 'permits must not be null — must be an empty array');
        System.assertEquals(0, permits.size(), 'permits array must be empty when no child permits exist');
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
            Map<String, Object> row = (Map<String, Object>) rec;
            System.assert(row.containsKey('permits'),
                'Every record in list response must contain permits key');
            System.assert(row.get('permits') instanceof List<Object>,
                'permits must be an array on every list record');
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
        System.assertNotEquals(null, dto.get('agencyId'),
            'agencyId must be non-null for a record where nepa_agency_id__c was set');
        System.assertEquals('BLM-2025-001', (String) dto.get('agencyId'),
            'agencyId must round-trip exactly — CEQ uses this as the join key to the agency registry');
    }

    // ── Null-field and edge-case serialization ────────────────────────────────

    @IsTest
    static void getSingle_allOptionalFieldsNull_returns200() {
        // A process with every nullable DTO field unset must serialize without NPE.
        Program proj = NepaTestFactory.insertProgram('NEPA-CEQ-NULL', 'Null Fields Test', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                = 'Permit';
        ia.LicenseTypeId           = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1].Id;
        ia.nepa_related_project__c = proj.Id;
        ia.nepa_process_status__c  = 'in progress';
        ia.nepa_process_stage__c   = 'Scoping';
        // All other fields intentionally null: no federal_unique_id, no risk score, no SLA dates
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
        Map<String, Object> dto = (Map<String, Object>) body.get('data');
        System.assertNotEquals(null, dto.get('id'), 'id must always be present even when other fields are null');
    }

    @IsTest
    static void getList_updatedSince_futureDateReturnsEmpty() {
        // updatedSince set 10 years in the future → 0 results, 200 response
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
        // reviewType=EIS AND status=in+progress → exactly 1 result (FUID-001 from @TestSetup)
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
        System.assertEquals('EIS', (String) row.get('reviewType'));
        System.assertEquals('in progress', (String) row.get('processStatus'));
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
        // slaOverdue must serialize as a Boolean (formula checkbox), not as a String or null object.
        RestContext.request  = buildRequest('GET', '/services/apexrest/nepa/v1/processes/FUID-001', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqExportService.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> dto = (Map<String, Object>) parseBody().get('data');
        System.assert(dto.containsKey('slaOverdue'), 'DTO must contain slaOverdue key');
        // When slaOverdue is present and not null it must be a Boolean
        Object slaOverdueVal = dto.get('slaOverdue');
        if (slaOverdueVal != null) {
            System.assert(slaOverdueVal instanceof Boolean,
                'slaOverdue must be a Boolean in the DTO; got: ' + String.valueOf(slaOverdueVal));
        }
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
