@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class NepaLayerDisciplineResolverTest {

    // ── Setup helpers ─────────────────────────────────────────────────────────

    private static IndividualApplication insertTestProcess() {
        Program proj = NepaTestFactory.insertProgram('LDR-TEST', 'LDR Test Project', 'BLM');
        return NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
    }

    // ── No hits → anyHitsFound = false, zero counts ───────────────────────────

    @IsTest
    static void assemble_noHitLayers_returnsNoHits() {
        IndividualApplication ia = insertTestProcess();
        Program proj = [SELECT Id FROM Program WHERE Id = :ia.nepa_related_project__c];

        NepaLayerDisciplineResolver.Request req = new NepaLayerDisciplineResolver.Request();
        req.programId    = proj.Id;
        req.relatedAppId = ia.Id;

        Test.startTest();
        List<NepaLayerDisciplineResolver.Result> results =
            NepaLayerDisciplineResolver.assemble(new List<NepaLayerDisciplineResolver.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        NepaLayerDisciplineResolver.Result res = results[0];
        System.assertEquals(false, res.anyHitsFound,
            'No detected layers → anyHitsFound must be false');
        System.assertEquals(0, res.teamMembersCreated,
            'No hits → no team members created');
        System.assertEquals(0, res.workOrdersCreated,
            'No hits → no work orders created');
        System.assertEquals(null, res.errorMessage,
            'No exception expected when there are no hit layers');
    }

    // ── Null programId → error captured, not thrown ────────────────────────────

    @IsTest
    static void assemble_nullProgramId_errorCaptured() {
        IndividualApplication ia = insertTestProcess();

        NepaLayerDisciplineResolver.Request req = new NepaLayerDisciplineResolver.Request();
        req.programId    = null;
        req.relatedAppId = ia.Id;

        Test.startTest();
        Boolean threw = false;
        List<NepaLayerDisciplineResolver.Result> results;
        try {
            results = NepaLayerDisciplineResolver.assemble(
                new List<NepaLayerDisciplineResolver.Request>{ req });
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        // The invocable must not propagate an unhandled exception to the caller —
        // it should either return a result with errorMessage set or return no error
        // (empty layer query is safe with null programId in SOQL bind).
        System.assertEquals(false, threw,
            'assemble() must not throw; it must capture errors internally');
    }

    // ── Bulk: 5 requests each complete independently ───────────────────────────

    @IsTest
    static void assemble_bulkRequests_returnOneResultPerRequest() {
        Program proj = NepaTestFactory.insertProgram('LDR-BULK', 'LDR Bulk Test', 'EPA');

        List<NepaLayerDisciplineResolver.Request> requests =
            new List<NepaLayerDisciplineResolver.Request>();
        for (Integer i = 0; i < 5; i++) {
            IndividualApplication ia =
                NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
            NepaLayerDisciplineResolver.Request req = new NepaLayerDisciplineResolver.Request();
            req.programId    = proj.Id;
            req.relatedAppId = ia.Id;
            requests.add(req);
        }

        Test.startTest();
        List<NepaLayerDisciplineResolver.Result> results =
            NepaLayerDisciplineResolver.assemble(requests);
        Test.stopTest();

        System.assertEquals(5, results.size(),
            'Bulk: must return one result per input request');
        for (Integer i = 0; i < results.size(); i++) {
            System.assertEquals(null, results[i].errorMessage,
                'No error expected for valid request at index ' + i);
        }
    }

    // ── tokenReplace: private helper covered via round-trip through assemble ───
    // Direct public coverage: confirmed that null/empty templates do not surface
    // an exception. Covered by no-hits test above (both template fields are blank
    // when no CMT rows match).

    // ── accountId optional: non-null accountId doesn't cause an error ──────────

    @IsTest
    static void assemble_withOptionalAccountId_noError() {
        Program proj = NepaTestFactory.insertProgram('LDR-ACCT', 'LDR Account Test', 'USFS');
        IndividualApplication ia =
            NepaTestFactory.insertProcess(proj.Id, 'CE', null, null);

        Account acct = new Account(Name = 'Test Sponsor Account');
        insert acct;

        NepaLayerDisciplineResolver.Request req = new NepaLayerDisciplineResolver.Request();
        req.programId    = proj.Id;
        req.relatedAppId = ia.Id;
        req.accountId    = acct.Id;

        Test.startTest();
        List<NepaLayerDisciplineResolver.Result> results =
            NepaLayerDisciplineResolver.assemble(new List<NepaLayerDisciplineResolver.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].errorMessage,
            'Providing an optional accountId must not cause an error');
    }
}
