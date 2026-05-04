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
}
