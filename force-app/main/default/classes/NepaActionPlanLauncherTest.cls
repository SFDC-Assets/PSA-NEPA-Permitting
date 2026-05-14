@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class NepaActionPlanLauncherTest {

    // ── Happy path: template not found → error returned (no org template required) ─

    @IsTest
    static void launch_unknownTemplate_returnsErrorMessage() {
        NepaActionPlanLauncher.LaunchRequest req = new NepaActionPlanLauncher.LaunchRequest();
        req.recordId        = UserInfo.getUserId(); // valid Id format; template lookup is what fails
        req.aptDeveloperName = 'DOES_NOT_EXIST_TEMPLATE_XYZ';

        Test.startTest();
        List<NepaActionPlanLauncher.LaunchResult> results =
            NepaActionPlanLauncher.launch(new List<NepaActionPlanLauncher.LaunchRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result for one request');
        NepaActionPlanLauncher.LaunchResult res = results[0];
        System.assertNotEquals(null, res.errorMessage,
            'Unknown template name must produce a non-null errorMessage; got null');
        System.assertEquals(null, res.actionPlanId,
            'actionPlanId must be null when template is not found');
    }

    @IsTest
    static void launch_blankTemplateName_returnsError() {
        NepaActionPlanLauncher.LaunchRequest req = new NepaActionPlanLauncher.LaunchRequest();
        req.recordId         = UserInfo.getUserId();
        req.aptDeveloperName = '';

        Test.startTest();
        List<NepaActionPlanLauncher.LaunchResult> results =
            NepaActionPlanLauncher.launch(new List<NepaActionPlanLauncher.LaunchRequest>{ req });
        Test.stopTest();

        System.assertNotEquals(null, results[0].errorMessage,
            'Blank template name must produce an error message, not a null pointer');
        System.assertEquals(null, results[0].actionPlanId);
    }

    // ── Bulk safety: N requests produce N results, each handled independently ─

    @IsTest
    static void launch_bulkUnknownTemplates_returnsOneResultPerRequest() {
        List<NepaActionPlanLauncher.LaunchRequest> requests = new List<NepaActionPlanLauncher.LaunchRequest>();
        for (Integer i = 0; i < 10; i++) {
            NepaActionPlanLauncher.LaunchRequest req = new NepaActionPlanLauncher.LaunchRequest();
            req.recordId         = UserInfo.getUserId();
            req.aptDeveloperName = 'BULK_MISSING_TEMPLATE_' + i;
            requests.add(req);
        }

        Test.startTest();
        List<NepaActionPlanLauncher.LaunchResult> results =
            NepaActionPlanLauncher.launch(requests);
        Test.stopTest();

        System.assertEquals(10, results.size(), 'Bulk: must return one result per request');
        for (Integer i = 0; i < results.size(); i++) {
            System.assertNotEquals(null, results[i].errorMessage,
                'Each result must have an error message; index ' + i);
        }
    }

    // ── Error isolation: one bad request does not blow up adjacent results ─────

    @IsTest
    static void launch_mixedRequests_errorsIsolatedPerRecord() {
        NepaActionPlanLauncher.LaunchRequest good = new NepaActionPlanLauncher.LaunchRequest();
        good.recordId         = UserInfo.getUserId();
        good.aptDeveloperName = 'MISSING_BUT_VALID_FORMAT';

        NepaActionPlanLauncher.LaunchRequest alsoMissing = new NepaActionPlanLauncher.LaunchRequest();
        alsoMissing.recordId         = UserInfo.getUserId();
        alsoMissing.aptDeveloperName = 'ANOTHER_MISSING_TEMPLATE';

        Test.startTest();
        List<NepaActionPlanLauncher.LaunchResult> results =
            NepaActionPlanLauncher.launch(
                new List<NepaActionPlanLauncher.LaunchRequest>{ good, alsoMissing });
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Must return exactly two results');
        // Both should have errors (templates don't exist), but neither should throw
        for (NepaActionPlanLauncher.LaunchResult res : results) {
            System.assertNotEquals(null, res.errorMessage,
                'Both results must handle the missing template gracefully');
        }
    }
}
