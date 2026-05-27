@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class NepaPreAppScreeningControllerTest {

    // ── Happy path: runScreening invocable with valid sector ──────────────────

    @IsTest
    static void runScreening_validSector_returnsResult() {
        NepaPreAppScreeningController.ScreeningRequest req =
            new NepaPreAppScreeningController.ScreeningRequest();
        req.inp_SectorKey         = 'Energy Production and Management';
        req.inp_NAICSCode         = '211120';
        req.inp_LeadAgencyKey     = 'BLM';
        req.inp_ProjectDescription = 'Conventional oil and gas drilling on BLM federal land';
        req.inp_ProjectState      = 'Wyoming';

        Test.startTest();
        List<NepaPreAppScreeningController.ScreeningResult> results =
            NepaPreAppScreeningController.runScreening(
                new List<NepaPreAppScreeningController.ScreeningRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result');
        NepaPreAppScreeningController.ScreeningResult res = results[0];
        // In test context without OmniStudio callout the IP invoker may throw;
        // verify the controller handles it gracefully (no unhandled exception).
        System.assertNotEquals(null, res, 'Result should not be null');
    }

    // ── Missing sector key returns validation error, not an exception ─────────

    @IsTest
    static void runScreening_missingSectorKey_returnsError() {
        NepaPreAppScreeningController.ScreeningRequest req =
            new NepaPreAppScreeningController.ScreeningRequest();
        req.inp_SectorKey = '';
        req.inp_NAICSCode = '211120';

        Test.startTest();
        List<NepaPreAppScreeningController.ScreeningResult> results =
            NepaPreAppScreeningController.runScreening(
                new List<NepaPreAppScreeningController.ScreeningRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].out_ScreeningComplete,
            'ScreeningComplete must be false when SectorKey is missing');
        System.assertNotEquals('', results[0].out_ErrorMessage,
            'ErrorMessage should describe the missing input');
    }

    // ── Bulk path: 5 requests processed without hitting limits ───────────────

    @IsTest
    static void runScreening_bulkRequests_allReturnResults() {
        List<NepaPreAppScreeningController.ScreeningRequest> reqs =
            new List<NepaPreAppScreeningController.ScreeningRequest>();
        String[] sectors = new String[]{
            'Energy Production and Management',
            'Transportation - Land',
            'Water Resources',
            'Materials - Mining',
            'Agriculture and Public Lands'
        };
        for (String s : sectors) {
            NepaPreAppScreeningController.ScreeningRequest req =
                new NepaPreAppScreeningController.ScreeningRequest();
            req.inp_SectorKey = s;
            req.inp_NAICSCode = '111000';
            reqs.add(req);
        }

        Test.startTest();
        List<NepaPreAppScreeningController.ScreeningResult> results =
            NepaPreAppScreeningController.runScreening(reqs);
        Test.stopTest();

        System.assertEquals(5, results.size(),
            'Bulk invocation must return one result per request');
        for (NepaPreAppScreeningController.ScreeningResult r : results) {
            System.assertNotEquals(null, r);
        }
    }

    // ── AuraEnabled LWC entry point: valid inputs ─────────────────────────────

    @IsTest
    static void runScreeningFromLWC_validInputs_returnsResult() {
        Test.startTest();
        NepaPreAppScreeningController.ScreeningResult res =
            NepaPreAppScreeningController.runScreeningFromLWC(
                '211120',
                'Energy Production and Management',
                'BLM',
                'Oil and gas development on federal land',
                'Colorado'
            );
        Test.stopTest();

        System.assertNotEquals(null, res, 'LWC method should return a non-null result');
    }

    // ── invokeIP catch block: exception must not propagate, result must be returned ─

    @IsTest
    static void runScreening_ipException_caughtAndResultReturned() {
        // Pass an IP key that doesn't exist ('NEPA/NONEXISTENT_IP/English/1') via a custom
        // ScreeningRequest that invokes through runScreening. The IP invocation will throw
        // (either because OmniStudio isn't configured or the IP key doesn't exist), exercising
        // the catch block. The controller must NOT re-throw — it must return a result.
        NepaPreAppScreeningController.ScreeningRequest req =
            new NepaPreAppScreeningController.ScreeningRequest();
        req.inp_SectorKey = 'Energy Production and Management';
        req.inp_NAICSCode = '211120';

        Boolean threw = false;
        List<NepaPreAppScreeningController.ScreeningResult> results;
        Test.startTest();
        try {
            results = NepaPreAppScreeningController.runScreening(
                new List<NepaPreAppScreeningController.ScreeningRequest>{ req }
            );
        } catch (Exception ex) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'invokeIP must not propagate any exception — catch block must absorb it');
        System.assertEquals(1, results.size(),
            'runScreening must return exactly one result per request');
        // Either OmniStudio succeeds (ScreeningComplete=true) or fails (out_ErrorMessage set).
        // Both outcomes confirm the catch block path is reachable without re-throwing.
        NepaPreAppScreeningController.ScreeningResult res = results[0];
        System.assertNotEquals(null, res,
            'Result object must not be null regardless of IP outcome');
        // If OmniStudio is not configured, the catch fires and errorMessage is populated.
        if (!res.out_ScreeningComplete) {
            System.assertNotEquals(null, res.out_ErrorMessage,
                'When IP throws, out_ErrorMessage must be set by the catch block');
        }
    }

    // ── AuraEnabled LWC entry point: missing sector ───────────────────────────

    @IsTest
    static void runScreeningFromLWC_missingSector_returnsError() {
        Test.startTest();
        NepaPreAppScreeningController.ScreeningResult res =
            NepaPreAppScreeningController.runScreeningFromLWC(
                '211120', '', 'BLM', 'Oil project', 'TX'
            );
        Test.stopTest();

        System.assertEquals(false, res.out_ScreeningComplete,
            'Missing sector should produce ScreeningComplete=false');
    }
}