@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaAgencyPermitServiceTest {

    // ── Mock ──────────────────────────────────────────────────────────────────

    /** Returns a 200 response with a minimal CEQ process payload. */
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'data'    => new Map<String, Object>{
                    'processStatus'        => 'in progress',
                    'processStage'         => 'Draft EIS',
                    'targetCompletionDate' => '2027-06-30',
                    'lastModified'         => '2026-05-01T00:00:00Z'
                }
            }));
            return res;
        }
    }

    /** Returns 404 — process not found at agency. */
    private class NotFoundMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{}');
            return res;
        }
    }

    /** Throws CalloutException to simulate network failure. */
    private class CalloutFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new System.CalloutException('Endpoint unavailable');
        }
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('NEPA-PERM-001', 'Pipeline EIS', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_federal_unique_id__c = 'FUID-PERM-001';
        update ia;

        nepa_required_permit__c p1 = new nepa_required_permit__c(
            nepa_process__c              = ia.Id,
            nepa_permit_type__c          = 'CWA Section 404 Permit',
            nepa_lead_agency__c          = 'USACE',
            nepa_external_federal_id__c  = 'USACE-2026-001',
            nepa_agency_endpoint_key__c  = 'USACE',
            nepa_permit_status__c        = 'Under Review',
            nepa_is_critical_path__c     = true,
            nepa_regulatory_citation__c  = '33 USC 1344'
        );

        nepa_required_permit__c p2 = new nepa_required_permit__c(
            nepa_process__c             = ia.Id,
            nepa_permit_type__c         = 'ESA Section 7 Consultation',
            nepa_lead_agency__c         = 'USFWS',
            nepa_permit_status__c       = 'Not Started',
            nepa_is_critical_path__c    = false
            // intentionally no endpoint key or external ID — tests fallback
        );

        insert new List<nepa_required_permit__c>{ p1, p2 };
    }

    private static Id getProcessId() {
        return [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'FUID-PERM-001' LIMIT 1].Id;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void getPermitStatuses_successCallout_returnsLiveStatus() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<NepaAgencyPermitService.PermitStatusResult> results =
            NepaAgencyPermitService.getPermitStatuses(getProcessId());
        Test.stopTest();

        System.assertEquals(2, results.size());

        NepaAgencyPermitService.PermitStatusResult usaceResult = null;
        for (NepaAgencyPermitService.PermitStatusResult r : results) {
            if (r.leadAgency == 'USACE') { usaceResult = r; }
        }
        System.assertNotEquals(null, usaceResult);
        System.assertEquals(true,          usaceResult.calloutSuccess);
        System.assertEquals('in progress', usaceResult.liveStatus);
        System.assertEquals('Draft EIS',   usaceResult.liveStage);
        System.assertEquals(true,          usaceResult.isCriticalPath);
        System.assertEquals('Under Review', usaceResult.localStatus);
    }

    @IsTest
    static void getPermitStatuses_noEndpointKey_degradesGracefully() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<NepaAgencyPermitService.PermitStatusResult> results =
            NepaAgencyPermitService.getPermitStatuses(getProcessId());
        Test.stopTest();

        NepaAgencyPermitService.PermitStatusResult fwsResult = null;
        for (NepaAgencyPermitService.PermitStatusResult r : results) {
            if (r.leadAgency == 'USFWS') { fwsResult = r; }
        }
        System.assertNotEquals(null, fwsResult);
        System.assertEquals(false, fwsResult.calloutSuccess);
        System.assertNotEquals(null, fwsResult.calloutError);
        System.assertEquals('Not Started', fwsResult.localStatus);
    }

    @IsTest
    static void getPermitStatuses_calloutFails_degradesGracefully() {
        Test.setMock(HttpCalloutMock.class, new CalloutFailMock());

        Test.startTest();
        List<NepaAgencyPermitService.PermitStatusResult> results =
            NepaAgencyPermitService.getPermitStatuses(getProcessId());
        Test.stopTest();

        NepaAgencyPermitService.PermitStatusResult usaceResult = null;
        for (NepaAgencyPermitService.PermitStatusResult r : results) {
            if (r.leadAgency == 'USACE') { usaceResult = r; }
        }
        System.assertNotEquals(null, usaceResult);
        System.assertEquals(false,        usaceResult.calloutSuccess);
        System.assertNotEquals(null,       usaceResult.calloutError);
        System.assertEquals('Under Review', usaceResult.localStatus);
    }

    @IsTest
    static void getPermitStatuses_404Response_setsCalloutError() {
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());

        Test.startTest();
        List<NepaAgencyPermitService.PermitStatusResult> results =
            NepaAgencyPermitService.getPermitStatuses(getProcessId());
        Test.stopTest();

        NepaAgencyPermitService.PermitStatusResult usaceResult = null;
        for (NepaAgencyPermitService.PermitStatusResult r : results) {
            if (r.leadAgency == 'USACE') { usaceResult = r; }
        }
        System.assertNotEquals(null, usaceResult);
        System.assertEquals(false, usaceResult.calloutSuccess);
        System.assert(usaceResult.calloutError.contains('404'));
    }

    @IsTest
    static void getPermitStatuses_emptyPermitList_returnsEmptyList() {
        Program proj = NepaTestFactory.insertProgram('NEPA-PERM-EMPTY', 'Empty Process', 'EPA');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<NepaAgencyPermitService.PermitStatusResult> results =
            NepaAgencyPermitService.getPermitStatuses(ia.Id);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void getPermitStatuses_nullProcessId_throwsAuraHandled() {
        Boolean thrown = false;
        try {
            NepaAgencyPermitService.getPermitStatuses(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }
}
